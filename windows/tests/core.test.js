'use strict';
const { test } = require('node:test');
const assert = require('node:assert');

const { RingGeometry, RING_SIZES } = require('../src/shared/geometry');
const {
  Action, makeSlot, makeProfile, emptySlot, normalizeProfile, renderedSlots,
  encodeJSON, isoNow, normalizeSettings, DEFAULT_SETTINGS, mouseButtonLabel,
  actionKind, sanitizeAction, describeAction,
} = require('../src/shared/models');
const { resolveProfile, allProfilesForDisplay } = require('../src/shared/resolution');
const { resolveKeyCode } = require('../src/shared/keymap');
const {
  ALL_BUILTINS, categoryDefaults, createDefaultProfile, categoryForAppId,
} = require('../src/shared/builtinProfiles');
const { validateScript } = require('../src/main/executor');
const { ICONS } = require('../src/renderer/ring/icons');

// ---- geometry --------------------------------------------------------------------

test('ring sizes match the mac spec', () => {
  assert.deepStrictEqual(RING_SIZES.small, { outerDiameter: 220, deadZoneRadius: 30 });
  assert.deepStrictEqual(RING_SIZES.medium, { outerDiameter: 280, deadZoneRadius: 35 });
  assert.deepStrictEqual(RING_SIZES.large, { outerDiameter: 340, deadZoneRadius: 40 });
  const g = RingGeometry.forSize('medium', 8);
  assert.strictEqual(g.canvasDiameter, 360);
  assert.strictEqual(g.outerRadius, 140);
  assert.strictEqual(g.midRadius, 87.5);
});

test('dead zone is strict (<=) and slot 0 is due east', () => {
  const g = RingGeometry.forSize('medium', 8);
  assert.strictEqual(g.selectedSlot({ x: 35, y: 0 }), null); // exactly on radius → nil
  assert.strictEqual(g.selectedSlot({ x: 35.01, y: 0 }), 0); // just outside → slot 0
  assert.strictEqual(g.selectedSlot({ x: 100, y: 0 }), 0);
  assert.strictEqual(g.selectedSlot({ x: 0, y: 100 }), 2); // up (math +y) → slot 2 (CCW)
  assert.strictEqual(g.selectedSlot({ x: -100, y: 0 }), 4);
  assert.strictEqual(g.selectedSlot({ x: 0, y: -100 }), 6);
});

test('slots are centered on their spokes (half-slot shift)', () => {
  const g = RingGeometry.forSize('medium', 8);
  // 22° < 22.5° half-width → still slot 0; 23° → slot 1
  const at = (deg) => ({ x: 100 * Math.cos((deg * Math.PI) / 180), y: 100 * Math.sin((deg * Math.PI) / 180) });
  assert.strictEqual(g.selectedSlot(at(22)), 0);
  assert.strictEqual(g.selectedSlot(at(23)), 1);
  assert.strictEqual(g.selectedSlot(at(-22)), 0); // negative angles wrap
  assert.strictEqual(g.selectedSlot(at(-23)), 7);
});

test('selection has no outer cap; isInRingArea does', () => {
  const g = RingGeometry.forSize('small', 4);
  assert.strictEqual(g.selectedSlot({ x: 10_000, y: 0 }), 0);
  assert.strictEqual(g.isInRingArea({ x: 10_000, y: 0 }), false);
  assert.strictEqual(g.isInRingArea({ x: 100, y: 0 }), true);
});

test('selectableSlot requires an action but ignores isEnabled (mac parity)', () => {
  const g = RingGeometry.forSize('medium', 8);
  const slots = [
    makeSlot({ position: 0, label: 'A', icon: 'plus', action: Action.key('a'), isEnabled: false }),
    makeSlot({ position: 1, label: 'B', icon: 'plus', action: null }),
  ];
  assert.strictEqual(g.selectableSlot({ x: 100, y: 0 }, slots), 0); // disabled but has action → fires
  assert.strictEqual(g.selectableSlot({ x: 70, y: 70 }, slots), null); // slot 1: no action
  assert.strictEqual(g.selectableSlot({ x: 0, y: -100 }, slots), null); // slot 6: missing
});

test('round-trip invariant: slotCenter maps back to its slot for 4/6/8', () => {
  for (const n of [4, 6, 8]) {
    const g = RingGeometry.forSize('large', n);
    for (let i = 0; i < n; i++) {
      assert.strictEqual(g.selectedSlot(g.slotCenter(i)), i, `slotCount=${n} slot=${i}`);
    }
  }
});

test('viewPosition flips y (slot 2 of 8 renders above center)', () => {
  const g = RingGeometry.forSize('medium', 8);
  const p = g.viewPosition(2, g.outerDiameter); // math: straight up
  assert.ok(Math.abs(p.x - 140) < 1e-9);
  assert.ok(p.y < 140); // screen up = smaller y
});

// ---- models / JSON wire format -------------------------------------------------------

test('encodeJSON: sorted keys, " : " separator, escaped slashes, 2-space indent', () => {
  const out = encodeJSON({ b: 1, a: 'x/y' });
  assert.strictEqual(out, '{\n  "a" : "x\\/y",\n  "b" : 1\n}');
});

test('encodeJSON omits undefined keys (nil optionals)', () => {
  const slot = makeSlot({ position: 0, label: '', icon: 'plus', action: null });
  assert.ok(!('action' in slot));
  const out = encodeJSON(slot);
  assert.ok(!out.includes('action'));
});

test('isoNow emits seconds-only UTC (Swift .iso8601 parity)', () => {
  assert.match(isoNow(), /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
});

test('RingAction wire shapes match the Swift synthesized encoding', () => {
  assert.deepStrictEqual(Action.key('c', ['command']), {
    keyboardShortcut: { _0: { type: 'character', character: 'c' }, modifiers: ['command'] },
  });
  assert.deepStrictEqual(Action.launchApplication('x.exe'), {
    launchApplication: { bundleIdentifier: 'x.exe' },
  });
  assert.deepStrictEqual(Action.openURL('https://x.com'), { openURL: { _0: 'https://x.com' } });
  assert.strictEqual(actionKind(Action.systemAction('mute')), 'systemAction');
  assert.strictEqual(actionKind({ bogus: {} }), null);
});

test('normalizeProfile: lenient on optional keys, throws on required', () => {
  const min = {
    id: 'X', name: 'T', category: 'other', slots: [], slotCount: 8,
    isDefault: false, createdAt: '2024-01-01T00:00:00Z', updatedAt: '2024-01-01T00:00:00Z', source: 'user',
  };
  const p = normalizeProfile(min);
  assert.strictEqual(p.ringSize, 'medium');
  assert.strictEqual(p.isEnabled, true);
  assert.deepStrictEqual(p.mcpServers, []);
  assert.ok(!('bundleId' in p));
  assert.throws(() => normalizeProfile({ ...min, name: undefined }));
});

test('renderedSlots pads to slotCount with empty slots', () => {
  const p = makeProfile({ name: 'T', slots: [makeSlot({ position: 3, label: 'x', icon: 'plus', action: Action.key('a') })], slotCount: 6 });
  const r = renderedSlots(p);
  assert.strictEqual(r.length, 6);
  assert.strictEqual(r[3].label, 'x');
  assert.deepStrictEqual(r[0], emptySlot(0));
});

test('settings defaults + lenient normalize + button labels', () => {
  assert.deepStrictEqual(normalizeSettings({}), { ...DEFAULT_SETTINGS });
  assert.strictEqual(normalizeSettings({ triggerButton: 4 }).triggerButton, 4);
  assert.strictEqual(DEFAULT_SETTINGS.triggerButton, 3);
  assert.strictEqual(mouseButtonLabel(3), 'Button 4');
  assert.strictEqual(mouseButtonLabel(0), 'Left Button');
});

// ---- resolution chain -----------------------------------------------------------------

function storeFixture() {
  const builtin = makeProfile({ name: 'B', bundleId: 'code.exe', category: 'ide', source: 'builtin' });
  const catDefault = makeProfile({ name: 'IDE', category: 'ide', source: 'builtin' });
  const def = createDefaultProfile();
  return {
    userProfiles: [],
    builtIns: [builtin],
    categoryDefaults: { ide: catDefault },
    defaultProfile: def,
    _builtin: builtin, _catDefault: catDefault, _def: def,
  };
}

test('resolution: builtin wins when no user override', () => {
  const s = storeFixture();
  assert.strictEqual(resolveProfile(s, 'code.exe', 'ide'), s._builtin);
});

test('resolution: enabled user override wins over builtin', () => {
  const s = storeFixture();
  const user = makeProfile({ name: 'U', bundleId: 'code.exe', category: 'ide', source: 'user' });
  s.userProfiles = [user];
  assert.strictEqual(resolveProfile(s, 'code.exe', 'ide'), user);
});

test('resolution: DISABLED user override suppresses the builtin too', () => {
  const s = storeFixture();
  const user = makeProfile({ name: 'U', bundleId: 'code.exe', category: 'ide', source: 'user', isEnabled: false });
  s.userProfiles = [user];
  // falls to category default, NOT the builtin
  assert.strictEqual(resolveProfile(s, 'code.exe', 'ide'), s._catDefault);
});

test('resolution: user category profile beats category default', () => {
  const s = storeFixture();
  const catUser = makeProfile({ name: 'MyIDE', category: 'ide', source: 'user' });
  s.userProfiles = [catUser];
  assert.strictEqual(resolveProfile(s, 'unknown.exe', 'ide'), catUser);
});

test('resolution: unknown category falls to default profile', () => {
  const s = storeFixture();
  assert.strictEqual(resolveProfile(s, 'unknown.exe', 'other'), s._def);
  assert.strictEqual(resolveProfile(s, null, 'other'), s._def);
});

test('allProfilesForDisplay hides overridden builtins, default last', () => {
  const s = storeFixture();
  const user = makeProfile({ name: 'U', bundleId: 'code.exe', category: 'ide', source: 'user' });
  s.userProfiles = [user];
  const all = allProfilesForDisplay(s);
  assert.deepStrictEqual(all, [user, s._def]);
});

// ---- keymap ---------------------------------------------------------------------------

test('keymap: letters, digits, punctuation', () => {
  assert.deepStrictEqual(resolveKeyCode({ type: 'character', character: 'c' }), { vk: 0x43, needsShift: false });
  assert.deepStrictEqual(resolveKeyCode({ type: 'character', character: '1' }), { vk: 0x31, needsShift: false });
  assert.deepStrictEqual(resolveKeyCode({ type: 'character', character: '`' }), { vk: 0xc0, needsShift: false });
  assert.deepStrictEqual(resolveKeyCode({ type: 'character', character: '/' }), { vk: 0xbf, needsShift: false });
});

test('keymap: uppercase and shifted symbols set needsShift', () => {
  assert.deepStrictEqual(resolveKeyCode({ type: 'character', character: 'C' }), { vk: 0x43, needsShift: true });
  assert.deepStrictEqual(resolveKeyCode({ type: 'character', character: '!' }), { vk: 0x31, needsShift: true });
});

test('keymap: special keys and unmapped fallback', () => {
  assert.deepStrictEqual(resolveKeyCode({ type: 'special', special: 'enter' }), { vk: 0x0d, needsShift: false });
  assert.deepStrictEqual(resolveKeyCode({ type: 'special', special: 'f12' }), { vk: 0x7b, needsShift: false });
  assert.strictEqual(resolveKeyCode({ type: 'character', character: 'ก' }), null); // Thai → typeText fallback
  assert.strictEqual(resolveKeyCode({ type: 'special', special: 'nope' }), null);
});

// ---- built-ins --------------------------------------------------------------------------

test('21 built-in profiles, all valid, unique stable ids', () => {
  assert.strictEqual(ALL_BUILTINS.length, 21);
  const ids = new Set();
  for (const p of ALL_BUILTINS) {
    assert.strictEqual(p.slotCount, 8, p.name);
    assert.strictEqual(p.source, 'builtin', p.name);
    assert.strictEqual(p.slots.length, 8, p.name);
    assert.ok(p.bundleId && p.bundleId.endsWith('.exe'), p.name);
    for (const s of p.slots) {
      assert.ok(s.position >= 0 && s.position <= 7, `${p.name} slot ${s.position}`);
      assert.ok(actionKind(s.action), `${p.name}/${s.label} has valid action`);
      assert.ok(describeAction(s.action) !== '—', `${p.name}/${s.label} describable`);
    }
    ids.add(p.id);
  }
  assert.strictEqual(ids.size, 21);
});

test('7 category defaults with null bundleId; no "other"', () => {
  const cats = categoryDefaults();
  assert.deepStrictEqual(
    Object.keys(cats).sort(),
    ['browser', 'communication', 'design', 'ide', 'media', 'productivity', 'terminal']
  );
  for (const p of Object.values(cats)) assert.ok(!('bundleId' in p));
});

test('universal default: 8 slots, isDefault, Copy..Screenshot', () => {
  const d = createDefaultProfile();
  assert.strictEqual(d.isDefault, true);
  assert.strictEqual(d.slots.length, 8);
  assert.deepStrictEqual(d.slots.map((s) => s.label),
    ['Copy', 'Paste', 'Cut', 'Undo', 'Redo', 'Save', 'Select All', 'Screenshot']);
});

test('every built-in icon has a glyph mapping', () => {
  const missing = new Set();
  const check = (p) => p.slots.forEach((s) => { if (!ICONS[s.icon]) missing.add(s.icon); });
  ALL_BUILTINS.forEach(check);
  check(createDefaultProfile());
  assert.deepStrictEqual([...missing], [], `unmapped icons: ${[...missing].join(', ')}`);
});

test('every built-in keyboard shortcut resolves to a VK', () => {
  const bad = [];
  const walk = (p) => p.slots.forEach((s) => {
    if (actionKind(s.action) === 'keyboardShortcut') {
      if (!resolveKeyCode(s.action.keyboardShortcut._0)) bad.push(`${p.name}/${s.label}`);
    }
  });
  ALL_BUILTINS.forEach(walk);
  walk(createDefaultProfile());
  assert.deepStrictEqual(bad, []);
});

test('categoryForAppId mapping + fallback', () => {
  assert.strictEqual(categoryForAppId('code.exe'), 'ide');
  assert.strictEqual(categoryForAppId('CHROME.EXE'), 'browser');
  assert.strictEqual(categoryForAppId('whatever.exe'), 'other');
  assert.strictEqual(categoryForAppId(null), 'other');
});

// ---- win32 input: binding-order invariant ------------------------------------------------
// Regression for "MapVirtualKeyW is not a function": keyEvent() needs the Win32
// funcs bound, but sendShortcut/tapKey built the events BEFORE send() ran
// ensureBindings(). The public fns must ensure bindings up front and, when the
// platform/FFI is unavailable, return false WITHOUT throwing.
test('input.sendShortcut/tapKey/typeText never throw when bindings unavailable', () => {
  const input = require('../src/main/win32/input');
  assert.doesNotThrow(() => {
    const r1 = input.sendShortcut(0x43, { ctrl: true });
    const r2 = input.tapKey(0xaf);
    const r3 = input.typeText('hi');
    // On non-Windows these are all false; the point is no exception is raised.
    if (process.platform !== 'win32') {
      assert.strictEqual(r1, false);
      assert.strictEqual(r2, false);
      assert.strictEqual(r3, false);
    }
  });
});

// ---- hook re-arm: koffi type re-registration must not throw -------------------------------
// Regression for the "Re-Arm permanently downgrades to listen-only" critical:
// start() can run more than once (tray Re-Arm = stop()+start()), and koffi
// throws on duplicate named-type registration. The LL-hook types/funcs must be
// registered once per process, so repeated start()/stop() cycles never throw
// from registration. On non-Windows start() returns 'uiohook'|'none' and never
// touches koffi — the point is the cycle is safe and idempotent.
test('MouseHook start/stop can cycle repeatedly without throwing', () => {
  const { MouseHook } = require('../src/main/win32/hook');
  const hook = new MouseHook();
  assert.doesNotThrow(() => {
    for (let i = 0; i < 3; i++) {
      hook.start();
      hook.stop();
    }
  });
});

// ---- script safety -------------------------------------------------------------------------

// ---- sanitization / hardening (review findings) -------------------------------------

test('sanitizeAction strips unknown kinds and bad payloads', () => {
  assert.strictEqual(sanitizeAction(null), null);
  assert.strictEqual(sanitizeAction({ evilKind: { _0: 'x' } }), null);
  assert.strictEqual(sanitizeAction({ openURL: { _0: 123 } }), null); // non-string
  assert.strictEqual(sanitizeAction({ systemAction: { _0: 'notAReal' } }), null);
  assert.deepStrictEqual(sanitizeAction({ systemAction: { _0: 'mute' } }), { systemAction: { _0: 'mute' } });
});

test('sanitizeAction rebuilds keyboard shortcut with only valid modifiers/key', () => {
  const dirty = { keyboardShortcut: { _0: { type: 'character', character: 'cc', extra: 1 }, modifiers: ['command', 'bogus', 'shift'] } };
  assert.deepStrictEqual(sanitizeAction(dirty), {
    keyboardShortcut: { _0: { type: 'character', character: 'c' }, modifiers: ['command', 'shift'] },
  });
  assert.strictEqual(sanitizeAction({ keyboardShortcut: { _0: { type: 'special', special: 'nope' }, modifiers: [] } }), null);
});

test('normalizeProfile strips UI metadata and sanitizes actions (findings 8/18)', () => {
  const dirty = {
    id: 'X', name: 'T', category: 'ide', slotCount: 8, isDefault: false,
    createdAt: '2024-01-01T00:00:00Z', updatedAt: '2024-01-01T00:00:00Z', source: 'user',
    _isUserProfile: true, __proto__: { polluted: 1 }, ringSize: 'enormous',
    slots: [
      { position: 0, label: 'ok', icon: 'plus', color: 'neon', action: Action.key('a', ['command']) },
      { position: 1, label: 'bad', icon: 'x', action: { evil: {} } },
    ],
  };
  const p = normalizeProfile(dirty);
  assert.ok(!('_isUserProfile' in p));
  assert.strictEqual(p.ringSize, 'medium'); // clamped
  assert.strictEqual(p.slots[0].color, 'blue'); // clamped
  assert.ok(p.slots[0].action); // valid action survives
  assert.ok(!('action' in p.slots[1])); // poisoned action dropped → empty slot
  const json = encodeJSON(p);
  assert.ok(!json.includes('_isUserProfile'));
  assert.ok(!json.includes('polluted'));
});

test('validateScript: denylist + chmod 777 + empty', () => {
  assert.strictEqual(validateScript('echo hi').isValid, true);
  assert.strictEqual(validateScript('').isValid, false);
  assert.strictEqual(validateScript('rm -rf /').isValid, false);
  assert.strictEqual(validateScript('FORMAT C:').isValid, false);
  assert.strictEqual(validateScript('del /s /q c:\\').isValid, false);
  // as aggressive as the mac guardrail ('rm -rf /' blocks any absolute path too)
  assert.strictEqual(validateScript('Remove-Item -Recurse -Force C:\\x').isValid, false);
  assert.strictEqual(validateScript('Remove-Item -Recurse -Force .\\build').isValid, true);
  assert.strictEqual(validateScript('chmod 777 /tmp/x').isValid, false);
  assert.strictEqual(validateScript('diskpart /s evil.txt').isValid, false);
});
