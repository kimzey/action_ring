'use strict';
// Built-in profiles — Windows-native port of BuiltInProfiles.swift.
//
// Same structure as the mac set (21 app profiles + 7 category defaults +
// 1 universal default, all slotCount 8, source "builtin"), with two
// deliberate adaptations:
//   * App identity is the executable name lowercased ("code.exe") instead of
//     a bundle id — stored in the same `bundleId` field.
//   * Shortcuts are the apps' real WINDOWS bindings, encoded with the
//     cross-platform modifier enum: control=Ctrl, option=Alt, shift=Shift.
//     (The executor also maps "command"→Ctrl so mac-authored user profiles
//     still fire something sensible.)
// mac-only apps are swapped for their Windows counterparts:
//   Xcode→Visual Studio · Safari→Edge+Firefox · Terminal/iTerm/Warp→
//   Windows Terminal+Warp · Mail→Outlook · Finder→Explorer · Zoom keeps its
//   Windows Alt-shortcuts.

const { Action, makeSlot, makeProfile, isoNow } = require('./models');

// Built-ins get a stable timestamp so re-launches don't churn (mac built-ins
// are code-defined and never persisted; same here).
const T0 = '2024-01-01T00:00:00Z';

const slot = (position, label, icon, action, color) =>
  makeSlot({ position, label, icon, action, color });

const key = (ch, mods = []) => Action.key(ch, mods);
const skey = (name, mods = []) => Action.skey(name, mods);
const sys = (name) => Action.systemAction(name);

const C = 'control';
const S = 'shift';
const A = 'option'; // Alt

const profile = ({ name, bundleId = null, category, slots }) =>
  makeProfile({
    name, bundleId, category, slots,
    slotCount: 8, source: 'builtin',
    createdAt: T0, updatedAt: T0,
    // Deterministic id derived from name so the list is stable across runs.
    id: stableId(`builtin:${name}`),
  });

function stableId(seed) {
  // UUID-shaped deterministic id (not RFC-random, but unique + stable).
  const crypto = require('node:crypto');
  const h = crypto.createHash('sha1').update(seed).digest('hex').toUpperCase();
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-4${h.slice(13, 16)}-8${h.slice(17, 20)}-${h.slice(20, 32)}`;
}

// ---- shared slot sets --------------------------------------------------------

const browserSlots = [
  slot(0, 'Address Bar', 'location.fill', key('l', [C]), 'blue'),
  slot(1, 'New Tab', 'plus.square', key('t', [C]), 'green'),
  slot(2, 'Reopen Tab', 'arrow.uturn.left.square', key('t', [C, S]), 'teal'),
  slot(3, 'Find', 'magnifyingglass', key('f', [C]), 'indigo'),
  slot(4, 'Back', 'chevron.left', skey('leftArrow', [A]), 'gray'),
  slot(5, 'Forward', 'chevron.right', skey('rightArrow', [A]), 'gray'),
  slot(6, 'Reload', 'arrow.clockwise', key('r', [C]), 'orange'),
  slot(7, 'Close Tab', 'xmark.square', key('w', [C]), 'red'),
];

const terminalSlots = [
  slot(0, 'New Tab', 'plus.square', key('t', [C, S]), 'green'),
  slot(1, 'New Window', 'macwindow.badge.plus', key('n', [C, S]), 'teal'),
  slot(2, 'Split', 'rectangle.split.2x1', key('d', [A, S]), 'blue'),
  slot(3, 'Clear', 'clear', key('l', [C]), 'orange'),
  slot(4, 'Find', 'magnifyingglass', key('f', [C, S]), 'indigo'),
  slot(5, 'Interrupt (^C)', 'stop.circle', key('c', [C]), 'red'),
  slot(6, 'Prev Tab', 'chevron.left', skey('tab', [C, S]), 'gray'),
  slot(7, 'Next Tab', 'chevron.right', skey('tab', [C]), 'gray'),
];

// ---- universal default ---------------------------------------------------------

function createDefaultProfile() {
  return makeProfile({
    name: 'Default',
    bundleId: null,
    category: 'other',
    slotCount: 8,
    isDefault: true,
    source: 'builtin',
    createdAt: T0,
    updatedAt: T0,
    id: stableId('builtin:Default'),
    slots: [
      slot(0, 'Copy', 'doc.on.doc', key('c', [C]), 'blue'),
      slot(1, 'Paste', 'doc.on.clipboard', key('v', [C]), 'green'),
      slot(2, 'Cut', 'scissors', key('x', [C]), 'orange'),
      slot(3, 'Undo', 'arrow.uturn.backward', key('z', [C]), 'purple'),
      slot(4, 'Redo', 'arrow.uturn.forward', key('y', [C]), 'purple'),
      slot(5, 'Save', 'square.and.arrow.down', key('s', [C]), 'teal'),
      slot(6, 'Select All', 'selection.pin.in.out', key('a', [C]), 'indigo'),
      slot(7, 'Screenshot', 'camera.viewfinder', sys('screenshotArea'), 'pink'),
    ],
  });
}

// ---- app profiles ---------------------------------------------------------------

const vsCode = profile({
  name: 'VS Code', bundleId: 'code.exe', category: 'ide',
  slots: [
    slot(0, 'Command Palette', 'command', key('p', [C, S]), 'blue'),
    slot(1, 'Quick Open', 'doc.text.magnifyingglass', key('p', [C]), 'teal'),
    slot(2, 'Find in Files', 'magnifyingglass', key('f', [C, S]), 'indigo'),
    slot(3, 'Toggle Terminal', 'chevron.left.forwardslash.chevron.right', key('`', [C]), 'gray'),
    slot(4, 'Go to File', 'arrow.right.doc.on.clipboard', key('e', [C]), 'green'),
    slot(5, 'Format', 'text.alignleft', key('f', [S, A]), 'orange'),
    slot(6, 'Comment', 'text.bubble', key('/', [C]), 'yellow'),
    slot(7, 'Close Editor', 'xmark.circle', key('w', [C]), 'red'),
  ],
});

const cursor = profile({
  name: 'Cursor', bundleId: 'cursor.exe', category: 'ide',
  slots: [
    slot(0, 'AI Chat', 'sparkles', key('l', [C]), 'purple'),
    slot(1, 'AI Edit', 'wand.and.stars', key('k', [C]), 'pink'),
    slot(2, 'Command Palette', 'command', key('p', [C, S]), 'blue'),
    slot(3, 'Toggle Terminal', 'chevron.left.forwardslash.chevron.right', key('`', [C]), 'gray'),
    slot(4, 'Quick Open', 'doc.text.magnifyingglass', key('p', [C]), 'teal'),
    slot(5, 'Find in Files', 'magnifyingglass', key('f', [C, S]), 'indigo'),
    slot(6, 'Comment', 'text.bubble', key('/', [C]), 'yellow'),
    slot(7, 'Close Editor', 'xmark.circle', key('w', [C]), 'red'),
  ],
});

const visualStudio = profile({
  name: 'Visual Studio', bundleId: 'devenv.exe', category: 'ide',
  slots: [
    slot(0, 'Run', 'play.fill', skey('f5'), 'green'),
    slot(1, 'Build', 'hammer.fill', key('b', [C, S]), 'blue'),
    slot(2, 'Stop', 'stop.fill', skey('f5', [S]), 'red'),
    slot(3, 'Quick Launch', 'sparkles', key('q', [C]), 'teal'),
    slot(4, 'Solution Explorer', 'list.bullet', key('l', [C, A]), 'purple'),
    slot(5, 'Go To All', 'magnifyingglass', key('t', [C]), 'indigo'),
    slot(6, 'Find in Files', 'doc.text.magnifyingglass', key('f', [C, S]), 'orange'),
    slot(7, 'Go to Definition', 'arrow.up.forward.square', skey('f12'), 'yellow'),
  ],
});

const intellij = profile({
  name: 'IntelliJ IDEA', bundleId: 'idea64.exe', category: 'ide',
  slots: [
    slot(0, 'Find Action', 'magnifyingglass', key('a', [C, S]), 'indigo'),
    slot(1, 'Run', 'play.fill', skey('f10', [S]), 'green'),
    slot(2, 'Debug', 'ladybug.fill', skey('f9', [S]), 'red'),
    slot(3, 'Find in Files', 'doc.text.magnifyingglass', key('f', [C, S]), 'orange'),
    slot(4, 'Reformat', 'text.alignleft', key('l', [C, A]), 'teal'),
    slot(5, 'Go to File', 'arrow.right.doc.on.clipboard', key('n', [C, S]), 'blue'),
    slot(6, 'Rename', 'pencil', skey('f6', [S]), 'yellow'),
    slot(7, 'Commit', 'checkmark.seal', key('k', [C]), 'purple'),
  ],
});

const edge = profile({ name: 'Edge', bundleId: 'msedge.exe', category: 'browser', slots: browserSlots });
const chrome = profile({ name: 'Chrome', bundleId: 'chrome.exe', category: 'browser', slots: browserSlots });
const firefox = profile({ name: 'Firefox', bundleId: 'firefox.exe', category: 'browser', slots: browserSlots });

const arc = profile({
  name: 'Arc', bundleId: 'arc.exe', category: 'browser',
  slots: [
    slot(0, 'Address Bar', 'location.fill', key('l', [C]), 'blue'),
    slot(1, 'New Tab', 'plus.square', key('t', [C]), 'green'),
    slot(2, 'Little Arc', 'macwindow.on.rectangle', key('n', [C, A]), 'teal'),
    slot(3, 'Find', 'magnifyingglass', key('f', [C]), 'indigo'),
    slot(4, 'Back', 'chevron.left', skey('leftArrow', [A]), 'gray'),
    slot(5, 'Forward', 'chevron.right', skey('rightArrow', [A]), 'gray'),
    slot(6, 'Reload', 'arrow.clockwise', key('r', [C]), 'orange'),
    slot(7, 'Close Tab', 'xmark.square', key('w', [C]), 'red'),
  ],
});

const figma = profile({
  name: 'Figma', bundleId: 'figma.exe', category: 'design',
  slots: [
    slot(0, 'Frame', 'rectangle.dashed', key('a'), 'blue'),
    slot(1, 'Rectangle', 'rectangle', key('r'), 'teal'),
    slot(2, 'Text', 'textformat', key('t'), 'indigo'),
    slot(3, 'Pen', 'scribble', key('p'), 'purple'),
    slot(4, 'Component', 'square.on.square', key('k', [C, A]), 'pink'),
    slot(5, 'Group', 'square.stack.3d.up', key('g', [C]), 'orange'),
    slot(6, 'Export', 'square.and.arrow.up', key('e', [C, S]), 'green'),
    slot(7, 'Zoom to Fit', 'arrow.up.left.and.arrow.down.right', key('1', [S]), 'yellow'),
  ],
});

const photoshop = profile({
  name: 'Photoshop', bundleId: 'photoshop.exe', category: 'design',
  slots: [
    slot(0, 'Brush', 'paintbrush.pointed.fill', key('b'), 'blue'),
    slot(1, 'Move', 'arrow.up.and.down.and.arrow.left.and.right', key('v'), 'teal'),
    slot(2, 'Marquee', 'rectangle.dashed', key('m'), 'indigo'),
    slot(3, 'Eraser', 'eraser.fill', key('e'), 'orange'),
    slot(4, 'New Layer', 'square.stack.3d.up.badge.a', key('n', [C, S]), 'green'),
    slot(5, 'Deselect', 'rectangle.slash', key('d', [C]), 'gray'),
    slot(6, 'Free Transform', 'crop.rotate', key('t', [C]), 'purple'),
    slot(7, 'Export As', 'square.and.arrow.up', key('w', [C, A, S]), 'pink'),
  ],
});

const windowsTerminal = profile({ name: 'Windows Terminal', bundleId: 'windowsterminal.exe', category: 'terminal', slots: terminalSlots });
const warp = profile({ name: 'Warp', bundleId: 'warp.exe', category: 'terminal', slots: terminalSlots });

const slack = profile({
  name: 'Slack', bundleId: 'slack.exe', category: 'communication',
  slots: [
    slot(0, 'Quick Switcher', 'arrow.left.arrow.right', key('k', [C]), 'blue'),
    slot(1, 'Search', 'magnifyingglass', key('g', [C]), 'indigo'),
    slot(2, 'Unreads', 'envelope.badge', key('a', [C, S]), 'orange'),
    slot(3, 'Threads', 'bubble.left.and.bubble.right', key('t', [C, S]), 'teal'),
    slot(4, 'Mark Read', 'checkmark.circle', skey('escape', [S]), 'green'),
    slot(5, 'Edit Last', 'pencil', skey('upArrow'), 'yellow'),
    slot(6, 'DMs', 'person.2.fill', key('k', [C, S]), 'pink'),
    slot(7, 'Preferences', 'gearshape', key(',', [C]), 'gray'),
  ],
});

const discord = profile({
  name: 'Discord', bundleId: 'discord.exe', category: 'communication',
  slots: [
    slot(0, 'Quick Switch', 'arrow.left.arrow.right', key('k', [C]), 'blue'),
    slot(1, 'Search', 'magnifyingglass', key('f', [C]), 'indigo'),
    slot(2, 'Mute Mic', 'mic.slash.fill', key('m', [C, S]), 'red'),
    slot(3, 'Deafen', 'speaker.slash.fill', key('d', [C, S]), 'orange'),
    slot(4, 'Mark Read', 'checkmark.circle', skey('escape', [S]), 'green'),
    slot(5, 'Prev Channel', 'chevron.up', skey('upArrow', [A]), 'gray'),
    slot(6, 'Next Channel', 'chevron.down', skey('downArrow', [A]), 'gray'),
    slot(7, 'Settings', 'gearshape', key(',', [C]), 'teal'),
  ],
});

const zoom = profile({
  name: 'Zoom', bundleId: 'zoom.exe', category: 'communication',
  slots: [
    slot(0, 'Mute / Unmute', 'mic.slash.fill', key('a', [A]), 'red'),
    slot(1, 'Start / Stop Video', 'video.slash.fill', key('v', [A]), 'orange'),
    slot(2, 'Share Screen', 'rectangle.on.rectangle', key('s', [A, S]), 'blue'),
    slot(3, 'Chat', 'bubble.left.fill', key('h', [A]), 'teal'),
    slot(4, 'Participants', 'person.2.fill', key('u', [A]), 'indigo'),
    slot(5, 'Record', 'record.circle', key('r', [A]), 'pink'),
    slot(6, 'Raise Hand', 'hand.raised.fill', key('y', [A]), 'yellow'),
    slot(7, 'Leave', 'phone.down.fill', key('q', [A]), 'gray'),
  ],
});

const outlook = profile({
  name: 'Outlook', bundleId: 'outlook.exe', category: 'communication',
  slots: [
    slot(0, 'New Message', 'square.and.pencil', key('n', [C]), 'blue'),
    slot(1, 'Reply', 'arrowshape.turn.up.left.fill', key('r', [C]), 'teal'),
    slot(2, 'Reply All', 'arrowshape.turn.up.left.2.fill', key('r', [C, S]), 'indigo'),
    slot(3, 'Forward', 'arrowshape.turn.up.right.fill', key('f', [C]), 'green'),
    slot(4, 'Send', 'paperplane.fill', skey('enter', [C]), 'orange'),
    slot(5, 'Archive', 'archivebox.fill', skey('backspace'), 'gray'),
    slot(6, 'Delete', 'trash.fill', key('d', [C]), 'red'),
    slot(7, 'Search', 'magnifyingglass', key('e', [C]), 'yellow'),
  ],
});

const notion = profile({
  name: 'Notion', bundleId: 'notion.exe', category: 'productivity',
  slots: [
    slot(0, 'Search', 'magnifyingglass', key('p', [C]), 'indigo'),
    slot(1, 'New Page', 'doc.badge.plus', key('n', [C]), 'green'),
    slot(2, 'Quick Find', 'bolt.fill', key('k', [C]), 'yellow'),
    slot(3, 'Bold', 'bold', key('b', [C]), 'gray'),
    slot(4, 'Toggle Sidebar', 'sidebar.left', key('\\', [C]), 'blue'),
    slot(5, 'Back', 'chevron.left', key('[', [C]), 'teal'),
    slot(6, 'Forward', 'chevron.right', key(']', [C]), 'teal'),
    slot(7, 'Dark Mode', 'moon.fill', key('l', [C, S]), 'purple'),
  ],
});

const obsidian = profile({
  name: 'Obsidian', bundleId: 'obsidian.exe', category: 'productivity',
  slots: [
    slot(0, 'Command Palette', 'command', key('p', [C]), 'purple'),
    slot(1, 'Quick Switcher', 'arrow.left.arrow.right', key('o', [C]), 'blue'),
    slot(2, 'Search', 'magnifyingglass', key('f', [C, S]), 'indigo'),
    slot(3, 'New Note', 'doc.badge.plus', key('n', [C]), 'green'),
    slot(4, 'Graph View', 'point.3.connected.trianglepath.dotted', key('g', [C]), 'pink'),
    slot(5, 'Toggle Edit', 'pencil', key('e', [C]), 'orange'),
    slot(6, 'Insert Link', 'link', key('k', [C]), 'teal'),
    slot(7, 'Toggle Sidebar', 'sidebar.left', key('\\', [C]), 'gray'),
  ],
});

const linear = profile({
  name: 'Linear', bundleId: 'linear.exe', category: 'productivity',
  slots: [
    slot(0, 'Command Menu', 'command', key('k', [C]), 'purple'),
    slot(1, 'New Issue', 'plus.square.fill', key('c'), 'green'),
    slot(2, 'Search', 'magnifyingglass', key('/'), 'indigo'),
    slot(3, 'My Issues', 'person.crop.square', key('g'), 'blue'),
    slot(4, 'Assign', 'person.fill.badge.plus', key('a'), 'teal'),
    slot(5, 'Set Status', 'circle.lefthalf.filled', key('s'), 'orange'),
    slot(6, 'Set Priority', 'exclamationmark.triangle', key('p'), 'yellow'),
    slot(7, 'Set Due Date', 'calendar', key('d'), 'pink'),
  ],
});

const explorer = profile({
  name: 'Explorer', bundleId: 'explorer.exe', category: 'other',
  slots: [
    slot(0, 'New Folder', 'folder.badge.plus', key('n', [C, S]), 'blue'),
    slot(1, 'New Window', 'macwindow.badge.plus', key('n', [C]), 'teal'),
    slot(2, 'Properties', 'info.circle', skey('enter', [A]), 'indigo'),
    slot(3, 'Preview Pane', 'eye', key('p', [A]), 'green'),
    slot(4, 'Address Bar', 'arrow.right.to.line', key('d', [A]), 'orange'),
    slot(5, 'Delete', 'trash', skey('delete'), 'red'),
    slot(6, 'Rename', 'pencil', skey('f2'), 'yellow'),
    slot(7, 'Search', 'magnifyingglass', key('f', [C]), 'gray'),
  ],
});

const spotify = profile({
  name: 'Spotify', bundleId: 'spotify.exe', category: 'media',
  slots: [
    slot(0, 'Play/Pause', 'playpause.fill', sys('mediaPlayPause'), 'green'),
    slot(1, 'Next', 'forward.fill', sys('mediaNext'), 'teal'),
    slot(2, 'Previous', 'backward.fill', sys('mediaPrevious'), 'teal'),
    slot(3, 'Volume Up', 'speaker.wave.2.fill', sys('volumeUp'), 'blue'),
    slot(4, 'Volume Down', 'speaker.wave.1.fill', sys('volumeDown'), 'blue'),
    slot(5, 'Mute', 'speaker.slash.fill', sys('mute'), 'gray'),
    slot(6, 'Search', 'magnifyingglass', key('l', [C]), 'indigo'),
    slot(7, 'Like', 'heart.fill', key('b', [A, S]), 'pink'),
  ],
});

// Order parallels BuiltInProfiles.all on mac.
const ALL_BUILTINS = [
  vsCode, cursor, visualStudio, intellij,
  edge, chrome, firefox, arc,
  figma, photoshop,
  windowsTerminal, warp,
  slack, discord, zoom, outlook,
  notion, obsidian, linear,
  explorer, spotify,
];

// 7 category fallbacks (no entry for "other"/"development" — parity with mac).
function categoryDefaults() {
  const cat = (name, category, slots) =>
    makeProfile({
      name, bundleId: null, category, slots, slotCount: 8, source: 'builtin',
      createdAt: T0, updatedAt: T0, id: stableId(`builtin:category:${category}`),
    });
  return {
    ide: cat('IDE', 'ide', vsCode.slots),
    browser: cat('Browser', 'browser', browserSlots),
    terminal: cat('Terminal', 'terminal', terminalSlots),
    design: cat('Design', 'design', figma.slots),
    productivity: cat('Productivity', 'productivity', createDefaultProfile().slots),
    communication: cat('Communication', 'communication', slack.slots),
    media: cat('Media', 'media', spotify.slots),
  };
}

// ---- exe → category mapping (AppDetector parity) ---------------------------------

const APP_CATEGORY_MAP = {
  // ide
  'code.exe': 'ide', 'cursor.exe': 'ide', 'devenv.exe': 'ide', 'idea64.exe': 'ide',
  'pycharm64.exe': 'ide', 'webstorm64.exe': 'ide', 'goland64.exe': 'ide',
  'rider64.exe': 'ide', 'clion64.exe': 'ide', 'sublime_text.exe': 'ide',
  'notepad++.exe': 'ide', 'zed.exe': 'ide', 'windsurf.exe': 'ide',
  // browser
  'chrome.exe': 'browser', 'msedge.exe': 'browser', 'firefox.exe': 'browser',
  'arc.exe': 'browser', 'opera.exe': 'browser', 'brave.exe': 'browser',
  'vivaldi.exe': 'browser', 'zen.exe': 'browser',
  // design
  'figma.exe': 'design', 'photoshop.exe': 'design', 'illustrator.exe': 'design',
  'xd.exe': 'design', 'afdesign.exe': 'design', 'inkscape.exe': 'design',
  // terminal
  'windowsterminal.exe': 'terminal', 'warp.exe': 'terminal', 'wezterm-gui.exe': 'terminal',
  'alacritty.exe': 'terminal', 'cmd.exe': 'terminal', 'powershell.exe': 'terminal',
  'pwsh.exe': 'terminal', 'conemu64.exe': 'terminal', 'tabby.exe': 'terminal',
  // communication
  'slack.exe': 'communication', 'discord.exe': 'communication', 'zoom.exe': 'communication',
  'outlook.exe': 'communication', 'olk.exe': 'communication', 'teams.exe': 'communication',
  'ms-teams.exe': 'communication', 'telegram.exe': 'communication', 'line.exe': 'communication',
  'signal.exe': 'communication',
  // productivity
  'notion.exe': 'productivity', 'obsidian.exe': 'productivity', 'linear.exe': 'productivity',
  'todoist.exe': 'productivity', 'winword.exe': 'productivity', 'excel.exe': 'productivity',
  // media
  'spotify.exe': 'media', 'vlc.exe': 'media', 'wmplayer.exe': 'media', 'itunes.exe': 'media',
};

const categoryForAppId = (appId) => APP_CATEGORY_MAP[(appId || '').toLowerCase()] || 'other';

module.exports = {
  ALL_BUILTINS, categoryDefaults, createDefaultProfile,
  APP_CATEGORY_MAP, categoryForAppId,
  browserSlots, terminalSlots,
};
