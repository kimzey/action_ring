'use strict';
// RingController — port of Controller/RingController.swift. The orchestrator:
// trigger events → gesture state machine → overlay → executor.
//
// Constants are verbatim from the mac build:
//   tapThreshold 0.30s · sticky timeout 6s · preview 4s · poll 120Hz
//
// Gestures:
//   HOLD  — press, drag to a slot, release to fire; release in center cancels.
//   CLICK — quick tap (<0.30s, no slot) opens a sticky ring; second click
//           fires the highlighted slot (center = cancel); auto-cancel at 6s.
//
// expectingTriggerUp pairs suppression: an up is suppressed iff its down was,
// even if the ring closed in between — no dangling up ever reaches the app.

const { screen } = require('electron');
const { RingGeometry } = require('../shared/geometry');
const { renderedSlots } = require('../shared/models');
const { isFullscreenAppActive } = require('./win32/fullscreen');

const TAP_THRESHOLD_MS = 300;
const STICKY_TIMEOUT_MS = 6000;
const PREVIEW_DURATION_MS = 4000;
const POLL_MS = 1000 / 120;

const CLOSED = 'closed';
const HOLDING = 'holding';
const STICKY = 'sticky';

class RingController {
  /**
   * @param {object} deps { store, hook, overlay, contextEngine, executor }
   */
  constructor({ store, hook, overlay, contextEngine, executor }) {
    this.store = store;
    this.hook = hook;
    this.overlay = overlay;
    this.contextEngine = contextEngine;
    this.executor = executor;

    this.state = CLOSED;
    this.openedAt = 0;
    this.expectingTriggerUp = false;
    this.previewMode = false;
    this.pollTimer = null;
    this.previewDismiss = null;
    this.stickyTimeout = null;
    this.lastResult = null;
    this.onActionExecuted = null; // (slot, result) => void

    // The WH_MOUSE_LL hook proc must return its suppress/pass verdict FAST
    // (MSDN: exceed LowLevelHooksTimeout and Windows silently drops the hook).
    // So the fullscreen verdict is precomputed on a cheap timer and read from
    // this cache inside the callback — never queried synchronously there.
    this._fullscreenSuppressed = false;
    this._fullscreenTimer = null;
  }

  get isArmed() { return this.hook.mode !== 'none'; }

  /** @returns {string} the hook mode that ended up active */
  start() {
    this.applySettings();
    this.contextEngine.onProfileChange = (profile) => {
      // Live slot refresh while open (mac parity); geometry sticks until next open.
      if (this.state !== CLOSED || this.previewMode) {
        this.overlay.slots = renderedSlots(profile);
        this.overlay.profileName = profile.name;
        this.overlay._send(this.overlay._fullState());
      }
    };
    this.contextEngine.start();
    this.hook.onTriggerDown = (pt) => this._onTriggerDown(pt);
    this.hook.onTriggerUp = (pt) => this._onTriggerUp(pt);
    this.overlay.ensureWindow(); // pre-create so first open is a fast show
    this._startFullscreenWatch();
    return this.hook.start();
  }

  stop() {
    this.hook.stop();
    this.contextEngine.stop();
    this._stopPolling();
    if (this._fullscreenTimer) { clearInterval(this._fullscreenTimer); this._fullscreenTimer = null; }
    this.state = CLOSED;
    this.previewMode = false;
    this.overlay.hide();
  }

  _startFullscreenWatch() {
    if (this._fullscreenTimer) return;
    const tick = () => {
      try {
        this._fullscreenSuppressed =
          this.store.settings.suppressInFullscreen && isFullscreenAppActive();
      } catch { this._fullscreenSuppressed = false; }
    };
    tick();
    this._fullscreenTimer = setInterval(tick, 250);
  }

  applySettings() {
    const s = this.store.settings;
    this.hook.triggerButton = s.triggerButton;
    this.executor.timeoutSeconds = s.scriptTimeoutSeconds;
    // Propagate showLabels live so toggling it updates an open/next ring (parity).
    this.overlay.showLabels = s.showLabels;
    if (this.state !== CLOSED || this.previewMode) {
      this.overlay._send({ showLabels: s.showLabels });
    }
  }

  // ---- trigger handling (runs synchronously inside the hook callback) ---------

  _onTriggerDown() {
    const s = this.store.settings;
    if (this.state === CLOSED) {
      if (!s.enabled) { this.expectingTriggerUp = false; return 'pass'; }
      if (this._fullscreenSuppressed) { // cached — not queried in the hook proc
        this.expectingTriggerUp = false;
        return 'pass'; // let the game have the click
      }
      // Commit the synchronous state and verdict NOW; do the heavy work (screen
      // query + window show + poll start) on the next tick so the hook proc
      // returns immediately and never trips LowLevelHooksTimeout.
      this.previewMode = false;
      this.state = HOLDING;
      this.openedAt = Date.now();
      this.expectingTriggerUp = true;
      setImmediate(() => {
        if (this.state !== HOLDING) return; // gesture already resolved
        this._showRing(this.contextEngine.currentProfile, screen.getCursorScreenPoint());
        this._startPolling();
      });
      return 'suppress';
    }
    // STICKY second click confirms · HOLDING double-down = missed up: resolve now.
    this.expectingTriggerUp = true;
    setImmediate(() => {
      const selected = this.overlay.updateSelection(screen.getCursorScreenPoint());
      this._finishRing(selected);
    });
    return 'suppress';
  }

  _onTriggerUp() {
    const suppressUp = this.expectingTriggerUp;
    this.expectingTriggerUp = false;
    if (this.state === HOLDING) this._resolveHoldRelease();
    return suppressUp ? 'suppress' : 'pass';
  }

  _resolveHoldRelease() {
    const selected = this.overlay.updateSelection(screen.getCursorScreenPoint());
    if (selected != null) { this._finishRing(selected); return; }
    if (Date.now() - this.openedAt < TAP_THRESHOLD_MS) this._enterSticky();
    else this._finishRing(null);
  }

  _enterSticky() {
    this.state = STICKY;
    if (this.stickyTimeout) clearTimeout(this.stickyTimeout);
    this.stickyTimeout = setTimeout(() => {
      if (this.state === STICKY) this._finishRing(null);
    }, STICKY_TIMEOUT_MS);
  }

  // ---- show / hide -----------------------------------------------------------

  _showRing(profile, at) {
    const geometry = RingGeometry.forSize(profile.ringSize, profile.slotCount);
    this.overlay.apply(geometry);
    this.overlay.show({
      at,
      slots: renderedSlots(profile),
      profileName: profile.name,
      showLabels: this.store.settings.showLabels,
    });
  }

  /** Close + maybe execute. Idempotent. */
  _finishRing(selected) {
    if (this.state === CLOSED && !this.previewMode) return;
    this.state = CLOSED;
    const wasPreview = this.previewMode;
    this.previewMode = false;
    this._stopPolling();
    this.overlay.hide();

    if (wasPreview || !this.store.settings.executeOnRelease || selected == null) return;
    const slot = this.overlay.slots.find((sl) => sl.position === selected);
    if (!slot || slot.action == null) return;
    // Ring is already hidden — execution must not block the UI.
    this.executor.execute(slot.action).then((result) => {
      this.lastResult = result;
      if (!result.ok) console.error(`ActionRing: '${slot.label}' failed: ${result.error}`);
      this.onActionExecuted?.(slot, result);
    });
  }

  // ---- polling (release is NEVER inferred from the poll — only from up) --------

  _startPolling() {
    this._stopPolling();
    this.pollTimer = setInterval(() => {
      if (this.state === CLOSED && !this.previewMode) return;
      this.overlay.updateSelection(screen.getCursorScreenPoint());
    }, POLL_MS);
  }

  /** Stops the poll AND cancels preview/sticky timers (mac parity). */
  _stopPolling() {
    if (this.pollTimer) { clearInterval(this.pollTimer); this.pollTimer = null; }
    if (this.previewDismiss) { clearTimeout(this.previewDismiss); this.previewDismiss = null; }
    if (this.stickyTimeout) { clearTimeout(this.stickyTimeout); this.stickyTimeout = null; }
  }

  // ---- preview (state stays CLOSED; never executes) -----------------------------

  showPreview(durationMs = PREVIEW_DURATION_MS) {
    this.previewMode = true;
    const display = screen.getDisplayNearestPoint(screen.getCursorScreenPoint());
    const { x, y, width, height } = display.workArea;
    const center = { x: Math.round(x + width / 2), y: Math.round(y + height / 2) };
    this._showRing(this.contextEngine.currentProfile, center);
    this._startPolling(); // cancels any prior previewDismiss via _stopPolling
    this.previewDismiss = setTimeout(() => {
      if (this.previewMode) this._finishRing(null);
    }, durationMs);
  }

  // ---- trigger recording ---------------------------------------------------------

  recordTriggerButton(completion) {
    this.hook.onButtonRecorded = (button) => {
      this.store.settings.triggerButton = button;
      this.store.saveSettings();
      this.hook.triggerButton = button;
      completion?.(button);
    };
    this.hook.recording = true;
  }

  cancelRecording() { this.hook.recording = false; }
}

module.exports = {
  RingController,
  TAP_THRESHOLD_MS, STICKY_TIMEOUT_MS, PREVIEW_DURATION_MS, POLL_MS,
};
