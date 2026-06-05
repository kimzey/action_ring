'use strict';
// SF Symbol name → display glyph (emoji / unicode text).
// Profiles store SF Symbol names verbatim for JSON parity with the mac app;
// this map is render-only. Rendered grayscale to match the glass theme,
// full color when the slot is selected. Unmapped names fall back to '•'.

const ICONS = {
  // editing / clipboard
  'doc.on.doc': '📑', 'doc.on.clipboard': '📋', scissors: '✂️',
  'arrow.uturn.backward': '↶', 'arrow.uturn.forward': '↷',
  'square.and.arrow.down': '💾', 'square.and.arrow.up': '📤',
  'selection.pin.in.out': '⛶', 'camera.viewfinder': '📷',
  // search / navigation
  magnifyingglass: '🔍', 'doc.text.magnifyingglass': '🔎',
  'location.fill': '📍', 'arrow.right.to.line': '⇥',
  'chevron.left': '❮', 'chevron.right': '❯', 'chevron.up': '▲', 'chevron.down': '▼',
  'arrow.clockwise': '⟳', 'arrow.uturn.left.square': '↩',
  'arrow.left.arrow.right': '⇄', 'arrow.up.forward.square': '↗',
  'arrow.up.left.and.arrow.down.right': '⤢',
  'arrow.up.and.down.and.arrow.left.and.right': '✥',
  // dev
  command: '⌘', 'chevron.left.forwardslash.chevron.right': '</>',
  terminal: '>_', 'hammer.fill': '🔨', 'ladybug.fill': '🐞',
  'play.fill': '▶', 'pause.fill': '⏸', 'stop.fill': '■', 'stop.circle': '⏹',
  'checkmark.seal': '✅', 'checkmark.circle': '✓', 'checkmark.diamond.fill': '☑',
  'text.alignleft': '☰', 'text.bubble': '💬', 'list.bullet': '☰',
  'arrow.right.doc.on.clipboard': '📋', 'curlybraces': '{}',
  // windows / panes
  'macwindow.badge.plus': '⊞', 'macwindow.on.rectangle': '⧉',
  'rectangle.split.2x1': '◫', 'sidebar.left': '◧',
  'rectangle.on.rectangle': '🖥️', 'square.on.square': '⧉',
  // design
  'rectangle.dashed': '⬚', rectangle: '▭', textformat: 'T', scribble: '✒️',
  'paintbrush.pointed.fill': '🖌️', 'eraser.fill': '🧽',
  'square.stack.3d.up': '⧈', 'square.stack.3d.up.badge.a': '🗂️',
  'rectangle.slash': '⊘', 'crop.rotate': '◰',
  // comms
  'envelope.badge': '📨', 'envelope.fill': '✉️',
  'bubble.left.and.bubble.right': '🗨️', 'bubble.left.fill': '💬',
  'person.2.fill': '👥', 'person.crop.square': '👤', 'person.fill.badge.plus': '👤',
  'mic.slash.fill': '🎤', 'speaker.slash.fill': '🔇', 'video.slash.fill': '📹',
  'record.circle': '⏺', 'hand.raised.fill': '✋', 'phone.down.fill': '📞',
  'square.and.pencil': '📝', 'arrowshape.turn.up.left.fill': '↩',
  'arrowshape.turn.up.left.2.fill': '«', 'arrowshape.turn.up.right.fill': '↪',
  'paperplane.fill': '➤', 'archivebox.fill': '🗃️',
  // productivity
  'doc.badge.plus': '📄', 'bolt.fill': '⚡', bold: 'B', 'moon.fill': '🌙',
  'point.3.connected.trianglepath.dotted': '🕸️', link: '🔗',
  'plus.square.fill': '✚', 'plus.square': '✚',
  'circle.lefthalf.filled': '◐', 'exclamationmark.triangle': '⚠️', calendar: '📅',
  // files
  'folder.badge.plus': '📁', folder: '📁', 'info.circle': 'ℹ️',
  eye: '👁️', 'eye.slash': '🙈', trash: '🗑️', 'trash.fill': '🗑️', pencil: '✏️',
  // media
  'playpause.fill': '⏯', 'forward.fill': '⏭', 'backward.fill': '⏮',
  'speaker.wave.2.fill': '🔊', 'speaker.wave.1.fill': '🔉',
  'heart.fill': '❤️', 'star.fill': '⭐', 'bookmark.fill': '🔖',
  // misc
  sparkles: '✨', 'wand.and.stars': '🪄', gearshape: '⚙️', globe: '🌐',
  'bell.fill': '🔔', 'lock.fill': '🔒', clear: '🧹',
  'xmark.circle': '✕', 'xmark.square': '✕', xmark: '✕',
  plus: '+', 'circle.fill': '●', 'circle.dashed': '◌', questionmark: '?',
};

// eslint-disable-next-line no-unused-vars
function iconGlyph(name) {
  return ICONS[name] || '•';
}

// Expose for both the ring renderer and the settings renderer.
if (typeof module !== 'undefined') module.exports = { ICONS, iconGlyph };
