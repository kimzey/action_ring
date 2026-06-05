'use strict';
// KeyCode → Windows virtual-key mapping — the Windows analog of KeyCodeMap.swift.
// mac keycodes are physical-position codes; Windows VKs are by meaning, so we
// map by character semantics (per the port spec). Pure module, unit-testable.

// SpecialKey rawValue → VK
const SPECIAL_VK = {
  enter: 0x0d, // VK_RETURN
  tab: 0x09,
  space: 0x20,
  escape: 0x1b,
  delete: 0x2e, // forward delete → VK_DELETE
  backspace: 0x08, // VK_BACK
  home: 0x24,
  end: 0x23,
  pageUp: 0x21, // VK_PRIOR
  pageDown: 0x22, // VK_NEXT
  leftArrow: 0x25,
  rightArrow: 0x27,
  upArrow: 0x26,
  downArrow: 0x28,
  f1: 0x70, f2: 0x71, f3: 0x72, f4: 0x73, f5: 0x74, f6: 0x75,
  f7: 0x76, f8: 0x77, f9: 0x78, f10: 0x79, f11: 0x7a, f12: 0x7b,
};

// Unshifted character → VK (US layout). Letters/digits use their ASCII VKs.
const CHAR_VK = (() => {
  const m = {};
  for (let c = 97; c <= 122; c++) m[String.fromCharCode(c)] = c - 32; // a-z → VK_A..Z
  for (let c = 48; c <= 57; c++) m[String.fromCharCode(c)] = c; // 0-9
  Object.assign(m, {
    ' ': 0x20,
    ';': 0xba, // VK_OEM_1
    '=': 0xbb, // VK_OEM_PLUS
    ',': 0xbc, // VK_OEM_COMMA
    '-': 0xbd, // VK_OEM_MINUS
    '.': 0xbe, // VK_OEM_PERIOD
    '/': 0xbf, // VK_OEM_2
    '`': 0xc0, // VK_OEM_3
    '[': 0xdb, // VK_OEM_4
    '\\': 0xdc, // VK_OEM_5
    ']': 0xdd, // VK_OEM_6
    "'": 0xde, // VK_OEM_7
  });
  return m;
})();

// Shifted symbol → its unshifted base key (so "!" presses Shift+1).
const SHIFTED_BASE = {
  '!': '1', '@': '2', '#': '3', '$': '4', '%': '5', '^': '6', '&': '7',
  '*': '8', '(': '9', ')': '0', '_': '-', '+': '=', '{': '[', '}': ']',
  '|': '\\', ':': ';', '"': "'", '<': ',', '>': '.', '?': '/', '~': '`',
};

/**
 * Resolve a wire-format KeyCode ({type:'character',character} | {type:'special',special})
 * → { vk, needsShift } | null. null = unmapped (caller falls back to typeText).
 * Parity with KeyCodeMap.resolve: uppercase characters set needsShift.
 */
function resolveKeyCode(keyCode) {
  if (!keyCode || typeof keyCode !== 'object') return null;
  if (keyCode.type === 'special') {
    const vk = SPECIAL_VK[keyCode.special];
    return vk ? { vk, needsShift: false } : null;
  }
  if (keyCode.type === 'character') {
    const ch = String(keyCode.character || '');
    if (ch.length === 0) return null;
    let needsShift = false;
    let base = ch;
    if (ch !== ch.toLowerCase()) { needsShift = true; base = ch.toLowerCase(); }
    else if (SHIFTED_BASE[ch]) { needsShift = true; base = SHIFTED_BASE[ch]; }
    const vk = CHAR_VK[base];
    return vk ? { vk, needsShift } : null;
  }
  return null;
}

module.exports = { SPECIAL_VK, CHAR_VK, SHIFTED_BASE, resolveKeyCode };
