'use strict';
// Frontmost-app detection — the Windows analog of the mac AppDetector
// (NSWorkspace.frontmostApplication). Identity key is the executable name
// lowercased, e.g. "code.exe" (Windows' stand-in for a bundle id).
//
// Privacy parity with the mac version: we read the process image path only —
// never window titles or document contents.

const path = require('node:path');
const C = require('./winconst');

const IS_WIN = process.platform === 'win32';

let fns = null;

function ensureBindings() {
  if (!IS_WIN || fns) return !!fns;
  const koffi = require('koffi');
  const user32 = koffi.load('user32.dll');
  const kernel32 = koffi.load('kernel32.dll');
  fns = {
    koffi,
    GetForegroundWindow: user32.func('void *GetForegroundWindow()'),
    GetWindowThreadProcessId: user32.func(
      'uint32 GetWindowThreadProcessId(void *hwnd, _Out_ uint32 *pid)'
    ),
    OpenProcess: kernel32.func('void *OpenProcess(uint32 access, bool inherit, uint32 pid)'),
    CloseHandle: kernel32.func('bool CloseHandle(void *h)'),
    QueryFullProcessImageNameW: kernel32.func(
      'bool QueryFullProcessImageNameW(void *h, uint32 flags, _Out_ char16 *exeName, _Inout_ uint32 *size)'
    ),
    GetWindowLongPtrW: user32.func('intptr_t GetWindowLongPtrW(void *hwnd, int nIndex)'),
    GetWindowRect: user32.func('bool GetWindowRect(void *hwnd, _Out_ AR_RECT *rect)'),
    MonitorFromWindow: user32.func('void *MonitorFromWindow(void *hwnd, uint32 flags)'),
    GetMonitorInfoW: user32.func('bool GetMonitorInfoW(void *hmon, _Inout_ AR_MONITORINFO *mi)'),
    GetClassNameW: user32.func('int GetClassNameW(void *hwnd, _Out_ char16 *name, int max)'),
    IsWindowVisible: user32.func('bool IsWindowVisible(void *hwnd)'),
    GetWindowTextLengthW: user32.func('int GetWindowTextLengthW(void *hwnd)'),
    GetWindow: user32.func('void *GetWindow(void *hwnd, uint32 cmd)'),
    GetWindowLongW: user32.func('int32 GetWindowLongW(void *hwnd, int nIndex)'),
  };
  return true;
}

// RECT/MONITORINFO registered once at module load (koffi types are global).
function registerStructs() {
  if (!IS_WIN) return;
  const koffi = require('koffi');
  koffi.struct('AR_RECT', { left: 'long', top: 'long', right: 'long', bottom: 'long' });
  koffi.struct('AR_MONITORINFO', {
    cbSize: 'uint32',
    rcMonitor: 'AR_RECT',
    rcWork: 'AR_RECT',
    dwFlags: 'uint32',
  });
}
registerStructs();

/** @returns {{ appId: string, exePath: string, hwnd: any } | null} */
function frontmostApp() {
  if (!ensureBindings()) return null;
  const hwnd = fns.GetForegroundWindow();
  if (!hwnd) return null;

  const pidOut = [0];
  fns.GetWindowThreadProcessId(hwnd, pidOut);
  const pid = pidOut[0];
  if (!pid) return null;

  const h = fns.OpenProcess(C.PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
  if (!h) return null;
  try {
    const buf = ['\0'.repeat(1024)];
    const size = [1024];
    if (!fns.QueryFullProcessImageNameW(h, 0, buf, size)) return null;
    const exePath = buf[0];
    const appId = path.basename(exePath).toLowerCase();
    return { appId, exePath, hwnd, pid };
  } finally {
    fns.CloseHandle(h);
  }
}

/** Window metrics used by the fullscreen heuristic. */
function windowMetrics(hwnd) {
  if (!ensureBindings() || !hwnd) return null;
  const rect = {};
  if (!fns.GetWindowRect(hwnd, rect)) return null;

  const style = fns.GetWindowLongPtrW(hwnd, C.GWL_STYLE);
  const hmon = fns.MonitorFromWindow(hwnd, C.MONITOR_DEFAULTTONEAREST);
  const mi = { cbSize: 40, rcMonitor: {}, rcWork: {}, dwFlags: 0 };
  if (!fns.GetMonitorInfoW(hmon, mi)) return null;

  // GetClassNameW returns the copied length (0 on failure). On failure the
  // buffer is undefined, so don't trust a stale class name — clear it.
  const cls = ['\0'.repeat(256)];
  const clsLen = fns.GetClassNameW(hwnd, cls, 256);
  const className = clsLen > 0 ? cls[0].slice(0, clsLen) : '';

  return {
    rect,
    monitor: mi.rcMonitor,
    hasCaption: (Number(style) & C.WS_CAPTION) === C.WS_CAPTION,
    className,
  };
}

/**
 * Enumerate running GUI apps — the Windows analog of AppDetector.selectableApps()
 * (mac: activationPolicy == .regular). Visible top-level windows with a title,
 * de-duplicated by exe, sorted by name. Returns [{ name, appId }].
 */
let enumBindings = null; // koffi types are registered once per process
function ensureEnumBindings() {
  if (enumBindings) return enumBindings;
  const koffi = require('koffi');
  const EnumProc = koffi.proto('bool __stdcall AR_EnumWindowsProc(void *hwnd, intptr_t lParam)');
  const user32 = koffi.load('user32.dll');
  enumBindings = {
    koffi,
    EnumProc,
    enumWindows: user32.func('bool EnumWindows(AR_EnumWindowsProc *cb, intptr_t lParam)'),
  };
  return enumBindings;
}

function enumerateApps() {
  if (!ensureBindings()) return [];
  const { koffi, EnumProc, enumWindows } = ensureEnumBindings();

  const seen = new Map(); // appId → name
  const GWL_EXSTYLE = -20;
  const WS_EX_TOOLWINDOW = 0x00000080;

  const cb = koffi.register((hwnd) => {
    try {
      if (!fns.IsWindowVisible(hwnd)) return true;
      if (fns.GetWindowTextLengthW(hwnd) === 0) return true;
      if (fns.GetWindowLongW(hwnd, GWL_EXSTYLE) & WS_EX_TOOLWINDOW) return true;
      const pidOut = [0];
      fns.GetWindowThreadProcessId(hwnd, pidOut);
      if (!pidOut[0]) return true;
      const h = fns.OpenProcess(C.PROCESS_QUERY_LIMITED_INFORMATION, false, pidOut[0]);
      if (!h) return true;
      try {
        const buf = ['\0'.repeat(1024)];
        const size = [1024];
        if (fns.QueryFullProcessImageNameW(h, 0, buf, size)) {
          const appId = path.basename(buf[0]).toLowerCase();
          if (!seen.has(appId)) {
            const display = path.basename(buf[0]).replace(/\.exe$/i, '');
            seen.set(appId, display.charAt(0).toUpperCase() + display.slice(1));
          }
        }
      } finally {
        fns.CloseHandle(h);
      }
    } catch { /* keep enumerating */ }
    return true;
  }, koffi.pointer(EnumProc));

  try {
    enumWindows(cb, 0);
  } finally {
    koffi.unregister(cb);
  }

  return [...seen.entries()]
    .map(([appId, name]) => ({ name, appId }))
    .sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: 'base' }));
}

module.exports = { frontmostApp, windowMetrics, enumerateApps, available: () => IS_WIN };
