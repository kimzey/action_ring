'use strict';
// Global mouse-button capture for ActionRing (Windows).
//
// Primary path: a WH_MOUSE_LL low-level hook via koffi. This is the Windows
// equivalent of the mac version's CGEventTap — it can *suppress* the trigger
// button so a side-button "Back" doesn't also fire in the browser.
//
// Fallback path: uiohook-napi (listen-only). Used when the koffi hook cannot
// be installed (or off-Windows during development). No suppression there.
//
// Button numbering follows the mac version's CGEvent numbers so settings.json
// stays schema-compatible across platforms:
//   0 = left · 1 = right · 2 = middle · 3 = button 4 (back/XBUTTON1)
//   4 = button 5 (forward/XBUTTON2)
//
// Interface (mirrors EventTapManager): the owner assigns SYNCHRONOUS callbacks
// that return a verdict, because a WH_MOUSE_LL hook must decide suppress/pass
// before returning — exactly like a CGEventTap callback:
//   hook.onTriggerDown = (pt) => 'suppress' | 'pass'
//   hook.onTriggerUp   = (pt) => 'suppress' | 'pass'
//   hook.onButtonRecorded = (button) => void   (recording mode, press swallowed)
// 'anyButton'/'otherButton' EventEmitter events remain for diagnostics.
//
// Coordinates from the hook are PHYSICAL pixels; the controller reads the
// cursor via Electron's screen API (DIP) instead, so these are advisory.

const { EventEmitter } = require('node:events');
const C = require('./winconst');

const IS_WIN = process.platform === 'win32';

// koffi type + func registration is process-global and throws if a named type
// is registered twice. Register once and cache — start() may run repeatedly
// (tray "Re-Arm" calls stop() then start()), so this MUST be re-entrant.
let _llBindings = null;
function ensureLLBindings() {
  if (_llBindings) return _llBindings;
  const koffi = require('koffi');
  const user32 = koffi.load('user32.dll');
  const POINT = koffi.struct('AR_POINT', { x: 'long', y: 'long' });
  const MSLL = koffi.struct('AR_MSLLHOOKSTRUCT', {
    pt: POINT,
    mouseData: 'uint32',
    flags: 'uint32',
    time: 'uint32',
    dwExtraInfo: 'uintptr_t',
  });
  const HookProc = koffi.proto(
    'intptr_t __stdcall AR_LowLevelMouseProc(int nCode, uintptr_t wParam, AR_MSLLHOOKSTRUCT *lParam)'
  );
  _llBindings = {
    koffi,
    MSLL,
    HookProc,
    SetWindowsHookExW: user32.func(
      'void *SetWindowsHookExW(int idHook, AR_LowLevelMouseProc *lpfn, void *hmod, uint32 dwThreadId)'
    ),
    UnhookWindowsHookEx: user32.func('bool UnhookWindowsHookEx(void *hhk)'),
    CallNextHookEx: user32.func(
      'intptr_t CallNextHookEx(void *hhk, int nCode, uintptr_t wParam, intptr_t lParam)'
    ),
  };
  return _llBindings;
}

// Also process-global; bound once for the watchdog's staleness check.
let _getLastInputInfo = null;
function ensureGetLastInputInfo() {
  if (_getLastInputInfo) return _getLastInputInfo;
  const koffi = require('koffi');
  const user32 = koffi.load('user32.dll');
  koffi.struct('AR_LASTINPUTINFO', { cbSize: 'uint32', dwTime: 'uint32' });
  _getLastInputInfo = user32.func('bool GetLastInputInfo(_Inout_ AR_LASTINPUTINFO *p)');
  return _getLastInputInfo;
}

class MouseHook extends EventEmitter {
  constructor() {
    super();
    this.mode = 'none'; // 'll-hook' | 'uiohook' | 'none'
    this.triggerButton = 3; // mac-style numbering
    this.recording = false; // when true, capture the next press and report it
    this.onTriggerDown = null; // (pt) => 'suppress' | 'pass'
    this.onTriggerUp = null; // (pt) => 'suppress' | 'pass'
    this.onButtonRecorded = null; // (button) => void
    this._hhk = null;
    this._koffi = null;
    this._user32 = null;
    this._cb = null; // registered koffi callback (must stay referenced)
    this._fns = {};
    this._watchdog = null;
    this._uio = null;
    this._gestureActive = false; // trigger currently held (suppress matching up-event)
  }

  // ---- public ---------------------------------------------------------------

  start() {
    if (this.mode !== 'none') return this.mode;
    if (IS_WIN && this._tryStartLLHook()) {
      this.mode = 'll-hook';
    } else if (this._tryStartUiohook()) {
      this.mode = 'uiohook';
    } else {
      this.mode = 'none';
    }
    return this.mode;
  }

  stop() {
    if (this._watchdog) { clearInterval(this._watchdog); this._watchdog = null; }
    if (this._hhk) {
      try { this._fns.UnhookWindowsHookEx(this._hhk); } catch { /* already gone */ }
      this._hhk = null;
    }
    if (this._cb && this._koffi) {
      try { this._koffi.unregister(this._cb); } catch { /* already gone */ }
      this._cb = null;
    }
    if (this._uio) {
      try { this._uio.uIOhook.stop(); } catch { /* already stopped */ }
      this._uio = null;
    }
    this.mode = 'none';
  }

  get canSuppress() { return this.mode === 'll-hook'; }

  // ---- LL hook path -----------------------------------------------------------

  _tryStartLLHook() {
    try {
      // koffi type/func registration is PROCESS-GLOBAL and throws on a duplicate
      // name. start() can run more than once (tray "Re-Arm" = stop()+start()),
      // so the types/funcs must be registered exactly once per process and
      // reused — only the callback + hook handle are recreated each start().
      const b = ensureLLBindings();
      this._koffi = b.koffi;
      this._MSLL = b.MSLL;
      this._fns.SetWindowsHookExW = b.SetWindowsHookExW;
      this._fns.UnhookWindowsHookEx = b.UnhookWindowsHookEx;
      this._fns.CallNextHookEx = b.CallNextHookEx;
      const koffi = b.koffi;
      const HookProc = b.HookProc;

      const self = this;
      this._cb = koffi.register(function (nCode, wParam, lParamPtr) {
        self._sawCallback = true; // liveness mark (single boolean store — negligible)
        // Must return fast — this runs on every global mouse event.
        try {
          if (nCode === C.HC_ACTION && wParam !== C.WM_MOUSEMOVE && wParam !== C.WM_MOUSEWHEEL) {
            const verdict = self._onLLButtonEvent(wParam, lParamPtr);
            if (verdict === 'suppress') return 1;
          }
        } catch (err) {
          // Never let an error stall the hook chain — but surface it, since a
          // throw here means the trigger silently falls through to "pass"
          // (suppression lost) with no other signal.
          self.emit('error', err);
        }
        return self._fns.CallNextHookEx(null, nCode, wParam, koffi.address(lParamPtr));
      }, koffi.pointer(HookProc));

      this._hhk = this._fns.SetWindowsHookExW(C.WH_MOUSE_LL, this._cb, null, 0);
      if (!this._hhk) { this._cleanupKoffi(); return false; }

      // Windows can silently remove an LL hook whose proc exceeds
      // LowLevelHooksTimeout. We can't query liveness, but we CAN detect "the OS
      // is producing mouse events yet none are reaching us" by watching the
      // last-callback timestamp the proc stamps. The watchdog only reinstalls on
      // that evidence (or first run) — it never tears down a hook that's clearly
      // alive. (Heavy work is already deferred out of the proc; this is the
      // belt-and-suspenders recovery.)
      this._watchdog = setInterval(() => this._reinstallIfStale(), 5_000);
      return true;
    } catch (err) {
      this._cleanupKoffi();
      this.emit('error', err);
      return false;
    }
  }

  _cleanupKoffi() {
    if (this._cb && this._koffi) { try { this._koffi.unregister(this._cb); } catch {} }
    this._cb = null;
    this._hhk = null;
  }

  _reinstallIfStale() {
    if (this._gestureActive || this.recording || !this._hhk) return;
    const sawCallback = this._sawCallback;
    this._sawCallback = false;

    // Did the user generate input since the last tick? (GetLastInputInfo.dwTime
    // advances on any input, even moves the hook would relay.)
    const lastInput = this._lastInputTickCount();
    if (lastInput == null) return; // can't tell — never tear down a live hook
    const inputAdvanced = this._prevLastInput != null && lastInput > this._prevLastInput;
    this._prevLastInput = lastInput;

    // Input happened but NO callback fired → the hook was silently dropped.
    if (!inputAdvanced || sawCallback) return;
    try {
      this._fns.UnhookWindowsHookEx(this._hhk);
      this._hhk = this._fns.SetWindowsHookExW(C.WH_MOUSE_LL, this._cb, null, 0);
    } catch { /* keep previous handle; next tick retries */ }
    if (!this._hhk) this.emit('error', new Error('LL hook reinstall failed'));
  }

  _lastInputTickCount() {
    try {
      const info = { cbSize: 8, dwTime: 0 };
      return ensureGetLastInputInfo()(info) ? info.dwTime : null;
    } catch { return null; }
  }

  // Returns 'suppress' | 'pass'
  _onLLButtonEvent(wParam, lParamPtr) {
    const info = this._koffi.decode(lParamPtr, this._MSLL);
    if (info.flags & C.LLMHF_INJECTED) return 'pass'; // ignore our own SendInput etc.

    const decoded = decodeButtonMessage(wParam, info.mouseData);
    if (!decoded) return 'pass';
    const { button, isDown } = decoded;
    const pt = { x: info.pt.x, y: info.pt.y, physical: true };
    return this._dispatch(button, isDown, pt, true);
  }

  /**
   * Shared dispatch for both hook paths.
   * @param {boolean} canSuppress  ll-hook honors verdicts; uiohook cannot
   * @returns {'suppress'|'pass'}
   */
  _dispatch(button, isDown, pt, canSuppress) {
    if (this.recording) {
      // One-shot: the NEXT press of ANY button becomes the candidate, the
      // press is swallowed (where possible), recording auto-ends (mac parity).
      if (isDown) {
        this.recording = false;
        const cb = this.onButtonRecorded;
        if (cb) setImmediate(() => cb(button));
        this.emit('anyButton', button, pt);
        return canSuppress ? 'suppress' : 'pass';
      }
      return 'pass';
    }

    if (button !== this.triggerButton) {
      // Never suppress non-trigger buttons.
      this.emit('otherButton', { button, isDown, ...pt });
      return 'pass';
    }

    this._gestureActive = isDown;
    const verdict = isDown ? this.onTriggerDown?.(pt) : this.onTriggerUp?.(pt);
    return verdict === 'suppress' && canSuppress ? 'suppress' : 'pass';
  }

  // ---- uiohook fallback (listen-only; also the macOS dev path) ---------------

  _tryStartUiohook() {
    try {
      const uio = require('uiohook-napi');
      this._uio = uio;
      const { uIOhook } = uio;

      // uiohook button numbering: 1=left, 2=right, 3=middle, 4=back, 5=forward
      const toMac = (b) => ({ 1: 0, 2: 1, 3: 2, 4: 3, 5: 4 })[b];

      uIOhook.on('mousedown', (e) => {
        const button = toMac(e.button);
        if (button == null) return;
        this._dispatch(button, true, { x: e.x, y: e.y, physical: true }, false);
      });
      uIOhook.on('mouseup', (e) => {
        const button = toMac(e.button);
        if (button == null) return;
        this._dispatch(button, false, { x: e.x, y: e.y, physical: true }, false);
      });
      uIOhook.start();
      return true;
    } catch (err) {
      this._uio = null;
      this.emit('error', err);
      return false;
    }
  }
}

// wParam + mouseData → { button (mac numbering), isDown } | null
function decodeButtonMessage(wParam, mouseData) {
  switch (wParam) {
    case C.WM_LBUTTONDOWN: return { button: 0, isDown: true };
    case C.WM_LBUTTONUP: return { button: 0, isDown: false };
    case C.WM_RBUTTONDOWN: return { button: 1, isDown: true };
    case C.WM_RBUTTONUP: return { button: 1, isDown: false };
    case C.WM_MBUTTONDOWN: return { button: 2, isDown: true };
    case C.WM_MBUTTONUP: return { button: 2, isDown: false };
    case C.WM_XBUTTONDOWN:
    case C.WM_XBUTTONUP: {
      const x = (mouseData >>> 16) & 0xffff;
      const button = x === C.XBUTTON1 ? 3 : x === C.XBUTTON2 ? 4 : null;
      if (button == null) return null;
      return { button, isDown: wParam === C.WM_XBUTTONDOWN };
    }
    default: return null;
  }
}

module.exports = { MouseHook, decodeButtonMessage };
