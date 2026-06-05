'use strict';
// RingOverlay — port of UI/RingWindow.swift. A pre-created, transparent,
// click-through, non-activating always-on-top window that renders the ring.
//
// mac parity notes:
//  * window size = canvasDiameter² (ring + 40px shadow margin), centered on the
//    cursor; NO screen-edge clamping (the mac build doesn't clamp either).
//  * never receives mouse events (setIgnoreMouseEvents) and never takes focus
//    (focusable:false → WS_EX_NOACTIVATE on Windows) — selection is driven
//    externally by the controller's 120Hz cursor poll.
//  * hide() plays the exit animation, then actually hides 120ms later,
//    guarded against a re-show during the delay.
//  * updateSelection flips the y-delta: Electron screen coords are +y down,
//    the geometry hit-test expects math coords (+y up).

const path = require('node:path');
const { BrowserWindow, screen } = require('electron');
const { RingGeometry } = require('../shared/geometry');

const HIDE_DELAY_MS = 120;
const MAX_CANVAS = 420; // large ring; created at max, resized per profile

class RingOverlay {
  constructor() {
    this.win = null;
    this.geometry = RingGeometry.forSize('medium', 8);
    this.slots = [];
    this.profileName = '';
    this.showLabels = true;
    this.selectedSlot = null;
    this.center = null; // DIP screen point the ring is centered on
    this.visible = false;
    this._hideTimer = null;
    this._ready = false;
    this._pendingState = null;
  }

  /** Pre-create the window so the first show is just a fast reposition+show. */
  ensureWindow() {
    if (this.win && !this.win.isDestroyed()) return this.win;
    this.win = new BrowserWindow({
      width: MAX_CANVAS,
      height: MAX_CANVAS,
      frame: false,
      transparent: true,
      backgroundColor: '#00000000',
      hasShadow: false,
      resizable: false,
      movable: false,
      minimizable: false,
      maximizable: false,
      fullscreenable: false,
      focusable: false,
      skipTaskbar: true,
      alwaysOnTop: true,
      show: false,
      webPreferences: {
        preload: path.join(__dirname, '..', 'renderer', 'ring', 'preload.js'),
        contextIsolation: true,
        nodeIntegration: false,
        sandbox: true,
      },
    });
    this.win.setAlwaysOnTop(true, 'screen-saver');
    this.win.setIgnoreMouseEvents(true);
    this.win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
    this.win.setMenu(null);
    this.win.loadFile(path.join(__dirname, '..', 'renderer', 'ring', 'ring.html'));
    this.win.webContents.on('did-finish-load', () => {
      this._ready = true;
      if (this._pendingState) { this._send(this._pendingState); this._pendingState = null; }
    });
    this.win.on('closed', () => { this.win = null; this._ready = false; });
    return this.win;
  }

  _send(state) {
    if (!this.win || this.win.isDestroyed()) return;
    if (!this._ready) {
      // merge — a partial update must not clobber a queued full state
      this._pendingState = { ...(this._pendingState || {}), ...state };
      return;
    }
    this.win.webContents.send('ring:state', state);
  }

  _fullState() {
    return {
      geometry: {
        outerDiameter: this.geometry.outerDiameter,
        deadZoneRadius: this.geometry.deadZoneRadius,
        slotCount: this.geometry.slotCount,
      },
      slots: this.slots,
      profileName: this.profileName,
      showLabels: this.showLabels,
      selectedSlot: this.selectedSlot,
      isVisible: this.visible,
    };
  }

  /** Resize for a profile's geometry if it changed. */
  apply(geometry) {
    this.geometry = geometry;
    const win = this.ensureWindow();
    const d = geometry.canvasDiameter;
    const [w] = win.getContentSize();
    if (w !== d) win.setContentSize(d, d);
  }

  /**
   * Show the ring centered on a DIP screen point (cursor), populated from the
   * given rendered slots. No screen-edge clamping (mac parity).
   */
  show({ at, slots, profileName, showLabels }) {
    const win = this.ensureWindow();
    if (this._hideTimer) { clearTimeout(this._hideTimer); this._hideTimer = null; }
    this.center = at;
    this.slots = slots;
    this.profileName = profileName;
    this.showLabels = showLabels;
    this.selectedSlot = null;
    this.visible = true;
    const d = this.geometry.canvasDiameter;
    win.setBounds({
      x: Math.round(at.x - d / 2),
      y: Math.round(at.y - d / 2),
      width: d,
      height: d,
    });
    this._send(this._fullState());
    win.showInactive();
  }

  /**
   * Recompute the highlighted slot from a DIP cursor point.
   * Returns the selectable slot index or null (dead zone / empty slot).
   */
  updateSelection(cursor) {
    if (!this.center) return null;
    const relative = {
      x: cursor.x - this.center.x,
      y: this.center.y - cursor.y, // flip: screen +y down → math +y up
    };
    const resolved = this.geometry.selectableSlot(relative, this.slots);
    if (resolved !== this.selectedSlot) {
      this.selectedSlot = resolved;
      this._send({ selectedSlot: resolved });
    }
    return resolved;
  }

  /** Animated dismiss: exit anim now, real hide after 120ms (re-show guarded). */
  hide() {
    if (!this.win || this.win.isDestroyed()) return;
    this.visible = false;
    this.selectedSlot = null;
    this._send({ isVisible: false, selectedSlot: null });
    if (this._hideTimer) clearTimeout(this._hideTimer);
    this._hideTimer = setTimeout(() => {
      this._hideTimer = null;
      if (!this.visible && this.win && !this.win.isDestroyed()) this.win.hide();
    }, HIDE_DELAY_MS);
  }

  destroy() {
    if (this._hideTimer) clearTimeout(this._hideTimer);
    if (this.win && !this.win.isDestroyed()) this.win.destroy();
    this.win = null;
  }
}

/** Cursor position in DIPs (Electron handles per-monitor DPI). */
const cursorPoint = () => screen.getCursorScreenPoint();

module.exports = { RingOverlay, cursorPoint, HIDE_DELAY_MS };
