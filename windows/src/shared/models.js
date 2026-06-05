'use strict';
// Data models + JSON wire format — port of RingProfile.swift / RingSlot.swift /
// RingAction.swift / AppSettings.swift.
//
// The JSON written here is schema-compatible with the macOS app
// (profiles.json / default.json / settings.json):
//   * pretty-printed, alphabetically sorted keys, " : " separator,
//     "/" escaped as "\/" (Swift JSONEncoder parity)
//   * dates as ISO8601 seconds-only UTC ("2024-06-05T00:00:00Z")
//   * nil optionals OMITTED (RingProfile.bundleId, RingSlot.action) — never null
//   * RingAction = single-key object per case; unlabeled payloads use "_0",
//     labeled use the label ("modifiers", "bundleIdentifier")
//   * KeyCode = {"type":"character","character":"c"} | {"type":"special","special":"enter"}

const crypto = require('node:crypto');

// ---- enums (raw values must match Swift) -----------------------------------

const APP_CATEGORIES = ['ide', 'browser', 'design', 'productivity', 'communication', 'media', 'development', 'terminal', 'other'];
const PROFILE_SOURCES = ['builtin', 'user', 'ai', 'community', 'mcp'];
const RING_SIZE_VALUES = ['small', 'medium', 'large'];
const SLOT_COLORS = ['blue', 'purple', 'pink', 'red', 'orange', 'yellow', 'green', 'gray', 'teal', 'indigo'];
const KEY_MODIFIERS = ['command', 'shift', 'option', 'control', 'capsLock', 'function'];
const SPECIAL_KEYS = ['enter', 'tab', 'space', 'escape', 'delete', 'backspace', 'home', 'end', 'pageUp', 'pageDown', 'leftArrow', 'rightArrow', 'upArrow', 'downArrow', 'f1', 'f2', 'f3', 'f4', 'f5', 'f6', 'f7', 'f8', 'f9', 'f10', 'f11', 'f12'];
const SYSTEM_ACTIONS = ['lockScreen', 'screenshot', 'screenshotArea', 'volumeUp', 'volumeDown', 'mute', 'brightnessUp', 'brightnessDown', 'missionControl', 'showDesktop', 'launchpad', 'notificationCenter', 'mediaPlayPause', 'mediaNext', 'mediaPrevious', 'sleep'];
const ACTION_KINDS = ['keyboardShortcut', 'launchApplication', 'openURL', 'systemAction', 'shellScript', 'appleScript', 'shortcutsApp', 'textSnippet', 'openFile', 'workflow', 'mcpToolCall', 'mcpWorkflow'];

const VALID_SLOT_COUNTS = [4, 6, 8];
const MAX_SLOT_POSITION = 7;

// ---- helpers ----------------------------------------------------------------

const uuid = () => crypto.randomUUID().toUpperCase();

/** ISO8601 seconds-only UTC, Swift .iso8601 parity: 2024-06-05T00:00:00Z */
const isoNow = () => new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');

// ---- action constructors (return wire-format objects) ------------------------

const Action = {
  keyboardShortcut(keyCode, modifiers = []) {
    return { keyboardShortcut: { _0: keyCode, modifiers } };
  },
  /** character KeyCode */
  char(ch) { return { type: 'character', character: ch }; },
  /** special KeyCode */
  special(name) { return { type: 'special', special: name }; },
  /** shorthand: character shortcut (mirrors BuiltInProfiles.key) */
  key(ch, mods = []) { return Action.keyboardShortcut(Action.char(ch), mods); },
  skey(name, mods = []) { return Action.keyboardShortcut(Action.special(name), mods); },
  launchApplication(bundleIdentifier) { return { launchApplication: { bundleIdentifier } }; },
  openURL(url) { return { openURL: { _0: url } }; },
  systemAction(name) { return { systemAction: { _0: name } }; },
  shellScript(script) { return { shellScript: { _0: script } }; },
  appleScript(script) { return { appleScript: { _0: script } }; },
  shortcutsApp(name) { return { shortcutsApp: { _0: name } }; },
  textSnippet(text) { return { textSnippet: { _0: text } }; },
  openFile(path) { return { openFile: { _0: path } }; },
  workflow(actions) { return { workflow: { _0: actions } }; },
};

/**
 * Validate + clean a wire-format action coming from an untrusted source
 * (renderer IPC, imported profile pack). Returns a freshly-rebuilt action with
 * only the expected fields/types, or null if it isn't a well-formed action.
 * Guarantees the executor never sees a malformed/poisoned action object.
 */
function sanitizeAction(action) {
  const kind = actionKind(action);
  if (!kind) return null;
  const v = action[kind] || {};
  const str = (x) => (typeof x === 'string' ? x : null);
  switch (kind) {
    case 'keyboardShortcut': {
      const k = v._0;
      if (!k || (k.type !== 'character' && k.type !== 'special')) return null;
      const key = k.type === 'character'
        ? { type: 'character', character: String(k.character ?? '').slice(0, 1) }
        : { type: 'special', special: SPECIAL_KEYS.includes(k.special) ? k.special : null };
      if (key.type === 'special' && key.special == null) return null;
      if (key.type === 'character' && key.character === '') return null;
      const modifiers = Array.isArray(v.modifiers)
        ? v.modifiers.filter((m) => KEY_MODIFIERS.includes(m))
        : [];
      return { keyboardShortcut: { _0: key, modifiers } };
    }
    case 'launchApplication': {
      const id = str(v.bundleIdentifier);
      return id ? { launchApplication: { bundleIdentifier: id } } : null;
    }
    case 'openURL': return str(v._0) ? { openURL: { _0: v._0 } } : null;
    case 'systemAction': return SYSTEM_ACTIONS.includes(v._0) ? { systemAction: { _0: v._0 } } : null;
    case 'shellScript': return str(v._0) != null ? { shellScript: { _0: v._0 } } : null;
    case 'appleScript': return str(v._0) != null ? { appleScript: { _0: v._0 } } : null;
    case 'shortcutsApp': return str(v._0) != null ? { shortcutsApp: { _0: v._0 } } : null;
    case 'textSnippet': return str(v._0) != null ? { textSnippet: { _0: v._0 } } : null;
    case 'openFile': return str(v._0) != null ? { openFile: { _0: v._0 } } : null;
    case 'workflow': {
      const steps = Array.isArray(v._0) ? v._0.map(sanitizeAction).filter(Boolean) : [];
      return { workflow: { _0: steps } };
    }
    case 'mcpToolCall':
    case 'mcpWorkflow':
      // reserved/not executed — preserve structure verbatim for round-trip
      return { [kind]: v };
    default: return null;
  }
}

/** @returns {string|null} the case name of a wire-format action */
function actionKind(action) {
  if (!action || typeof action !== 'object') return null;
  const keys = Object.keys(action);
  if (keys.length !== 1) return null;
  return ACTION_KINDS.includes(keys[0]) ? keys[0] : null;
}

/** Human description, parity with RingAction.description (used in editor UI). */
function describeAction(action) {
  const kind = actionKind(action);
  if (!kind) return '—';
  const v = action[kind];
  switch (kind) {
    case 'keyboardShortcut': {
      const mods = (v.modifiers || []).map((m) => ({ command: 'Ctrl', shift: 'Shift', option: 'Alt', control: 'Ctrl', capsLock: 'Caps', function: 'Fn' }[m] || m));
      const key = v._0?.type === 'character' ? (v._0.character || '?').toUpperCase() : (v._0?.special || '?');
      return [...new Set(mods), key].join('+');
    }
    case 'launchApplication': return `Launch ${v.bundleIdentifier}`;
    case 'openURL': return `Open ${v._0}`;
    case 'systemAction': return `System: ${v._0}`;
    case 'shellScript': return 'Shell script';
    case 'appleScript': return 'AppleScript';
    case 'shortcutsApp': return `Shortcut: ${v._0}`;
    case 'textSnippet': return `Type "${String(v._0).slice(0, 24)}${String(v._0).length > 24 ? '…' : ''}"`;
    case 'openFile': return `Open ${v._0}`;
    case 'workflow': return `Workflow (${(v._0 || []).length} steps)`;
    case 'mcpToolCall': return 'MCP tool (reserved)';
    case 'mcpWorkflow': return 'MCP workflow (reserved)';
    default: return '—';
  }
}

// ---- RingSlot ----------------------------------------------------------------

function makeSlot({ position, label, icon, action = null, isEnabled = true, color = 'blue' }) {
  const slot = { position, label, icon, isEnabled, color };
  if (action != null) slot.action = action;
  return slot;
}

function emptySlot(position) {
  return makeSlot({ position, label: '', icon: 'plus', action: null, isEnabled: false, color: 'gray' });
}

const slotHasAction = (slot) => slot.action != null;

// ---- RingProfile ---------------------------------------------------------------

function makeProfile({ name, bundleId = null, category = 'other', slots = [], slotCount = 8, ringSize = 'medium', isEnabled = true, isDefault = false, mcpServers = [], source = 'user', id = null, createdAt = null, updatedAt = null }) {
  const now = isoNow();
  const p = {
    id: id || uuid(),
    name,
    category,
    slots,
    slotCount,
    ringSize,
    isEnabled,
    isDefault,
    mcpServers,
    createdAt: createdAt || now,
    updatedAt: updatedAt || now,
    source,
  };
  if (bundleId != null) p.bundleId = bundleId;
  return p;
}

/** Lenient decode parity: tolerate missing optional keys; throw on required. */
function normalizeProfile(raw) {
  const required = ['id', 'name', 'category', 'slots', 'slotCount', 'isDefault', 'createdAt', 'updatedAt', 'source'];
  for (const k of required) {
    if (raw[k] === undefined) throw new Error(`profile missing required key: ${k}`);
  }
  // Clamp enums to known raw values (Swift's decoder rejects unknown enum
  // cases; we coerce to a safe default so one bad field can't drop the whole
  // profile, while still never persisting/executing garbage).
  const oneOf = (set, value, fallback) => (set.includes(value) ? value : fallback);
  return makeProfile({
    id: String(raw.id),
    name: String(raw.name),
    bundleId: raw.bundleId != null ? String(raw.bundleId) : null,
    category: oneOf(APP_CATEGORIES, raw.category, 'other'),
    slots: raw.slots.map((s) => makeSlot({
      position: s.position | 0,
      label: s.label ?? '',
      icon: s.icon ?? '',
      action: sanitizeAction(s.action ?? null),
      isEnabled: s.isEnabled ?? true,
      color: oneOf(SLOT_COLORS, s.color, 'blue'),
    })),
    slotCount: VALID_SLOT_COUNTS.includes(raw.slotCount) ? raw.slotCount : 8,
    ringSize: oneOf(RING_SIZE_VALUES, raw.ringSize, 'medium'),
    isEnabled: raw.isEnabled ?? true,
    isDefault: !!raw.isDefault,
    mcpServers: Array.isArray(raw.mcpServers) ? raw.mcpServers.filter((x) => typeof x === 'string') : [],
    createdAt: raw.createdAt,
    updatedAt: raw.updatedAt,
    source: oneOf(PROFILE_SOURCES, raw.source, 'user'),
  });
}

/** For pos 0..slotCount-1: the stored slot at that position, else an empty pad. */
function renderedSlots(profile) {
  const out = [];
  for (let pos = 0; pos < profile.slotCount; pos++) {
    out.push(profile.slots.find((s) => s.position === pos) || emptySlot(pos));
  }
  return out;
}

const touch = (profile) => { profile.updatedAt = isoNow(); };

function addSlot(profile, slot) {
  profile.slots = profile.slots.filter((s) => s.position !== slot.position);
  profile.slots.push(slot);
  profile.slots.sort((a, b) => a.position - b.position);
  touch(profile);
}

function removeSlot(profile, position) {
  profile.slots = profile.slots.filter((s) => s.position !== position);
  touch(profile);
}

const slotAt = (profile, position) => profile.slots.find((s) => s.position === position) || null;

// ---- AppSettings ----------------------------------------------------------------

const DEFAULT_SETTINGS = Object.freeze({
  enabled: true,
  triggerButton: 3,
  defaultRingSize: 'medium',
  showLabels: true,
  suppressInFullscreen: true,
  executeOnRelease: true,
  scriptTimeoutSeconds: 10,
});

function normalizeSettings(raw) {
  const s = { ...DEFAULT_SETTINGS };
  if (raw && typeof raw === 'object') {
    for (const k of Object.keys(DEFAULT_SETTINGS)) {
      if (raw[k] !== undefined) s[k] = raw[k];
    }
  }
  return s;
}

function mouseButtonLabel(n) {
  if (n === 0) return 'Left Button';
  if (n === 1) return 'Right Button';
  if (n === 2) return 'Middle Button';
  return `Button ${n + 1}`;
}

// ---- Swift-JSONEncoder-parity serializer ----------------------------------------
// prettyPrinted + sortedKeys + " : " separator + "\/" escaping, 2-space indent.

function encodeJSONValue(value, indent) {
  const pad = '  '.repeat(indent);
  const padIn = '  '.repeat(indent + 1);
  if (value === null) return 'null';
  const t = typeof value;
  if (t === 'number' || t === 'boolean') return JSON.stringify(value);
  if (t === 'string') return JSON.stringify(value).replace(/\//g, '\\/');
  if (Array.isArray(value)) {
    if (value.length === 0) return '[\n\n' + pad + ']';
    const items = value.map((v) => padIn + encodeJSONValue(v, indent + 1));
    return '[\n' + items.join(',\n') + '\n' + pad + ']';
  }
  if (t === 'object') {
    const keys = Object.keys(value).filter((k) => value[k] !== undefined).sort();
    if (keys.length === 0) return '{\n\n' + pad + '}';
    const items = keys.map((k) => `${padIn}${JSON.stringify(k).replace(/\//g, '\\/')} : ${encodeJSONValue(value[k], indent + 1)}`);
    return '{\n' + items.join(',\n') + '\n' + pad + '}';
  }
  throw new Error(`cannot encode ${t}`);
}

const encodeJSON = (value) => encodeJSONValue(value, 0);

module.exports = {
  APP_CATEGORIES, PROFILE_SOURCES, RING_SIZE_VALUES, SLOT_COLORS, KEY_MODIFIERS,
  SPECIAL_KEYS, SYSTEM_ACTIONS, ACTION_KINDS, VALID_SLOT_COUNTS, MAX_SLOT_POSITION,
  uuid, isoNow, Action, actionKind, sanitizeAction, describeAction,
  makeSlot, emptySlot, slotHasAction,
  makeProfile, normalizeProfile, renderedSlots, touch, addSlot, removeSlot, slotAt,
  DEFAULT_SETTINGS, normalizeSettings, mouseButtonLabel,
  encodeJSON,
};
