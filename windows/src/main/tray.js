'use strict';
// Tray icon + menu — port of AppDelegate.setupStatusItem/refreshMenu.
// Menu order, labels, and the status-row state machine mirror the mac build;
// the Accessibility items become hook-state items on Windows (no permission
// gate exists, but the hook can still fail → "Re-arm").

const { Tray, Menu, nativeImage } = require('electron');
const { mouseButtonLabel } = require('../shared/models');

/** Draw the ⊕ circle-grid-cross glyph into an RGBA buffer (no asset files). */
function trayIconImage(size = 32) {
  const buf = Buffer.alloc(size * size * 4, 0);
  const c = (size - 1) / 2;
  const rOuter = size * 0.44;
  const stroke = size * 0.09;
  const set = (x, y, a) => {
    if (x < 0 || y < 0 || x >= size || y >= size) return;
    const i = (y * size + x) * 4;
    const alpha = Math.max(buf[i + 3], Math.round(a * 255));
    buf[i] = 255; buf[i + 1] = 255; buf[i + 2] = 255; buf[i + 3] = alpha;
  };
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const d = Math.hypot(x - c, y - c);
      // ring outline
      const ringDist = Math.abs(d - rOuter);
      if (ringDist < stroke) set(x, y, 1 - ringDist / stroke);
      // cross arms (clipped to circle interior)
      if (d < rOuter - stroke * 0.5) {
        const ax = Math.abs(x - c);
        const ay = Math.abs(y - c);
        if (ax < stroke * 0.75) set(x, y, 1 - ax / (stroke * 0.75));
        if (ay < stroke * 0.75) set(x, y, 1 - ay / (stroke * 0.75));
      }
    }
  }
  const img = nativeImage.createFromBuffer(buf, { width: size, height: size });
  img.setTemplateImage(true); // adapts on macOS dev; ignored on Windows
  return img.resize({ width: 16, height: 16 });
}

class TrayController {
  /**
   * @param {object} deps { controller, store, onOpenSettings, onQuit, onReArm }
   */
  constructor({ controller, store, onOpenSettings, onQuit, onReArm }) {
    this.controller = controller;
    this.store = store;
    this.onOpenSettings = onOpenSettings;
    this.onQuit = onQuit;
    this.onReArm = onReArm;
    this.tray = new Tray(trayIconImage());
    this.tray.setToolTip('ActionRing');
    this.tray.on('click', () => this.tray.popUpContextMenu());
    this.refresh();
  }

  statusTitle() {
    const enabled = this.store.settings.enabled;
    const armed = this.controller.isArmed;
    if (!enabled) return '❚❚ Paused';
    if (armed) {
      const suffix = this.controller.hook.canSuppress ? '' : ' (listen-only)';
      return `● Ready — trigger is live${suffix}`;
    }
    return '○ Hook not installed';
  }

  refresh() {
    const enabled = this.store.settings.enabled;
    const armed = this.controller.isArmed;
    const template = [
      { label: this.statusTitle(), enabled: false },
      {
        label: enabled ? 'Pause ActionRing' : 'Resume ActionRing',
        accelerator: undefined,
        click: () => {
          this.store.settings.enabled = !this.store.settings.enabled;
          this.store.saveSettings();
          this.controller.applySettings();
          this.refresh();
        },
      },
      { label: `Trigger: ${mouseButtonLabel(this.store.settings.triggerButton)}`, enabled: false },
      { type: 'separator' },
      { label: 'Preview Ring (move your mouse)', click: () => this.controller.showPreview() },
      { label: 'Settings…', click: () => this.onOpenSettings() },
      ...(armed ? [] : [{ label: 'Re-arm (reinstall mouse hook)', click: () => this.onReArm() }]),
      { type: 'separator' },
      { label: 'Quit ActionRing', click: () => this.onQuit() },
    ];
    this.tray.setContextMenu(Menu.buildFromTemplate(template));
  }

  destroy() { this.tray.destroy(); }
}

module.exports = { TrayController, trayIconImage };
