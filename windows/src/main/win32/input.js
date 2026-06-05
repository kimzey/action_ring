'use strict';
// Keyboard synthesis via SendInput — the Windows analog of the mac version's
// CGEvent keyboard posting. Sends VK + scan code so both regular apps and
// scancode-reading apps (games, some terminals) see the keystroke.
//
// Off-Windows this module loads but every call is a no-op returning false,
// so the rest of the app can run in dev/preview mode on macOS.

const C = require('./winconst');

const IS_WIN = process.platform === 'win32';

let koffi = null;
let SendInput = null;
let MapVirtualKeyW = null;
let INPUT = null;

function ensureBindings() {
  if (!IS_WIN || SendInput) return !!SendInput;
  koffi = require('koffi');
  const user32 = koffi.load('user32.dll');

  const KEYBDINPUT = koffi.struct('AR_KEYBDINPUT', {
    wVk: 'uint16',
    wScan: 'uint16',
    dwFlags: 'uint32',
    time: 'uint32',
    dwExtraInfo: 'uintptr_t',
  });
  const MOUSEINPUT = koffi.struct('AR_MOUSEINPUT', {
    dx: 'long',
    dy: 'long',
    mouseData: 'uint32',
    dwFlags: 'uint32',
    time: 'uint32',
    dwExtraInfo: 'uintptr_t',
  });
  const HARDWAREINPUT = koffi.struct('AR_HARDWAREINPUT', {
    uMsg: 'uint32',
    wParamL: 'uint16',
    wParamH: 'uint16',
  });
  const INPUT_UNION = koffi.union('AR_INPUT_UNION', {
    mi: MOUSEINPUT,
    ki: KEYBDINPUT,
    hi: HARDWAREINPUT,
  });
  INPUT = koffi.struct('AR_INPUT', {
    type: 'uint32',
    u: INPUT_UNION,
  });

  SendInput = user32.func('uint32 SendInput(uint32 cInputs, AR_INPUT *pInputs, int cbSize)');
  MapVirtualKeyW = user32.func('uint32 MapVirtualKeyW(uint32 uCode, uint32 uMapType)');
  return true;
}

// VKs whose scan codes carry the extended-key flag.
const EXTENDED_VKS = new Set([
  0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, // PgUp PgDn End Home arrows
  0x2d, 0x2e, // Insert Delete
  0x5b, 0x5c, // LWin RWin
  0x6f, // Numpad divide
  0xa3, 0xa5, // RControl RAlt
]);

function keyEvent(vk, isUp) {
  const scan = MapVirtualKeyW(vk, C.MAPVK_VK_TO_VSC);
  let flags = isUp ? C.KEYEVENTF_KEYUP : 0;
  if (EXTENDED_VKS.has(vk)) flags |= C.KEYEVENTF_EXTENDEDKEY;
  return {
    type: C.INPUT_KEYBOARD,
    u: { ki: { wVk: vk, wScan: scan, dwFlags: flags, time: 0, dwExtraInfo: 0 } },
  };
}

function unicodeEvent(codeUnit, isUp) {
  return {
    type: C.INPUT_KEYBOARD,
    u: {
      ki: {
        wVk: 0,
        wScan: codeUnit,
        dwFlags: C.KEYEVENTF_UNICODE | (isUp ? C.KEYEVENTF_KEYUP : 0),
        time: 0,
        dwExtraInfo: 0,
      },
    },
  };
}

function send(events) {
  if (!ensureBindings()) return false;
  if (events.length === 0) return true;
  const sent = SendInput(events.length, events, koffi.sizeof(INPUT));
  return sent === events.length;
}

/**
 * Press a keyboard shortcut: modifiers down → key down → key up → modifiers up.
 * @param {number} vk        virtual-key code of the main key
 * @param {object} mods      { ctrl, alt, shift, win } booleans
 */
function sendShortcut(vk, mods = {}) {
  const downMods = [];
  if (mods.ctrl) downMods.push(C.VK_CONTROL);
  if (mods.alt) downMods.push(C.VK_MENU);
  if (mods.shift) downMods.push(C.VK_SHIFT);
  if (mods.win) downMods.push(C.VK_LWIN);

  const events = [];
  for (const m of downMods) events.push(keyEvent(m, false));
  if (vk) events.push(keyEvent(vk, false), keyEvent(vk, true));
  for (const m of [...downMods].reverse()) events.push(keyEvent(m, true));
  return send(events);
}

/** Tap a single key with no modifiers (used for media/volume VKs). */
function tapKey(vk) {
  return send([keyEvent(vk, false), keyEvent(vk, true)]);
}

/** Type a Unicode string via KEYEVENTF_UNICODE (handles emoji/surrogates). */
function typeText(text) {
  const events = [];
  for (let i = 0; i < text.length; i++) {
    const cu = text.charCodeAt(i);
    events.push(unicodeEvent(cu, false), unicodeEvent(cu, true));
  }
  // SendInput in chunks — very long snippets in one call can hit input-queue limits.
  const CHUNK = 64; // 32 down/up pairs
  for (let i = 0; i < events.length; i += CHUNK) {
    if (!send(events.slice(i, i + CHUNK))) return false;
  }
  return true;
}

module.exports = { sendShortcut, tapKey, typeText, available: () => IS_WIN };
