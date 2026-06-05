'use strict';
// Fullscreen-game detection — the Windows analog of the mac FullscreenDetector
// (which compares CGWindowList bounds against the screen, titles never read).
//
// Two signals, either one suppresses the ring:
//  1. SHQueryUserNotificationState == QUNS_RUNNING_D3D_FULL_SCREEN
//     (exclusive-fullscreen D3D — the canonical "a game owns the screen" API)
//  2. Borderless-fullscreen heuristic: the foreground window has no caption
//     and its rect covers its entire monitor (with a small tolerance), and the
//     window class isn't the desktop/shell.

const C = require('./winconst');
const { frontmostApp, windowMetrics } = require('./foreground');

const IS_WIN = process.platform === 'win32';

let SHQueryUserNotificationState = null;

function ensureBindings() {
  if (!IS_WIN || SHQueryUserNotificationState) return !!SHQueryUserNotificationState;
  const koffi = require('koffi');
  const shell32 = koffi.load('shell32.dll');
  SHQueryUserNotificationState = shell32.func(
    'int32 SHQueryUserNotificationState(_Out_ int32 *state)'
  );
  return true;
}

// Shell/desktop classes that legitimately cover the whole monitor.
const SHELL_CLASSES = new Set(['progman', 'workerw', 'shell_traywnd', 'multitaskingviewframe']);
// Processes that should never be treated as a fullscreen game.
const SHELL_PROCESSES = new Set(['explorer.exe', 'searchhost.exe', 'lockapp.exe']);

const RECT_TOLERANCE = 2; // px slack when comparing window vs monitor bounds

/** @returns {boolean} true when a fullscreen game/presentation is frontmost */
function isFullscreenAppActive() {
  if (!IS_WIN) return false;

  // Signal 1: exclusive D3D fullscreen.
  if (ensureBindings()) {
    const out = [0];
    const hr = SHQueryUserNotificationState(out);
    if (hr === 0 && out[0] === C.QUNS_RUNNING_D3D_FULL_SCREEN) return true;
  }

  // Signal 2: borderless fullscreen heuristic.
  const app = frontmostApp();
  if (!app || SHELL_PROCESSES.has(app.appId)) return false;
  const m = windowMetrics(app.hwnd);
  if (!m || m.hasCaption) return false;
  if (SHELL_CLASSES.has((m.className || '').toLowerCase())) return false;

  const { rect, monitor } = m;
  return (
    rect.left <= monitor.left + RECT_TOLERANCE &&
    rect.top <= monitor.top + RECT_TOLERANCE &&
    rect.right >= monitor.right - RECT_TOLERANCE &&
    rect.bottom >= monitor.bottom - RECT_TOLERANCE
  );
}

module.exports = { isFullscreenAppActive };
