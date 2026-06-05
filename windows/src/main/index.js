'use strict';
// ActionRing for Windows — app bootstrap (port of main.swift + AppDelegate.swift).
// Tray-only app: no main window, single instance, --preview support.

const path = require('node:path');
const { app, BrowserWindow, ipcMain, dialog } = require('electron');

const { ProfileStore } = require('./profileStore');
const { AppDetector, ContextEngine } = require('./contextEngine');
const { ActionExecutor } = require('./executor');
const { MouseHook } = require('./win32/hook');
const { RingOverlay } = require('./overlay');
const { RingController } = require('./ringController');
const { TrayController } = require('./tray');
const { enumerateApps } = require('./win32/foreground');
const { makeProfile, normalizeProfile, normalizeSettings, renderedSlots, describeAction } = require('../shared/models');
const { createDefaultProfile, categoryForAppId } = require('../shared/builtinProfiles');

// Single instance — the documented mac stale-instance bug class, preempted.
if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  main();
}

function main() {
  let store, controller, tray, settingsWindow = null;
  let quittingForReal = false;
  app.on('before-quit', () => { quittingForReal = true; });

  app.whenReady().then(() => {
    // Hide dock icon during macOS dev runs (tray-only parity).
    if (process.platform === 'darwin' && app.dock) app.dock.hide();

    store = new ProfileStore(path.join(app.getPath('appData'), 'ActionRing'));
    const appDetector = new AppDetector();
    const contextEngine = new ContextEngine(appDetector, store);
    const executor = new ActionExecutor({ timeoutSeconds: store.settings.scriptTimeoutSeconds });
    const hook = new MouseHook();
    hook.on('error', (err) => console.error('ActionRing hook:', err?.message || err));
    hook.triggerButton = store.settings.triggerButton;
    const overlay = new RingOverlay();

    controller = new RingController({ store, hook, overlay, contextEngine, executor });

    const mode = controller.start();
    if (mode === 'none') {
      console.error('ActionRing: no mouse hook available — trigger is dead');
    } else if (mode === 'uiohook') {
      console.warn('ActionRing: LL hook unavailable; listen-only fallback (no suppression)');
    }

    tray = new TrayController({
      controller,
      store,
      onOpenSettings: openSettings,
      onQuit: () => quit(),
      onReArm: () => {
        controller.hook.stop();
        controller.hook.start();
        tray.refresh();
      },
    });

    registerIpc();

    if (process.argv.includes('--preview')) {
      setTimeout(() => controller.showPreview(10_000), 400);
    }

    // Dev aid: --capture <file.png> renders the preview ring, snapshots the
    // overlay's web contents to the file, and exits.
    const captureIdx = process.argv.indexOf('--capture');
    if (captureIdx !== -1) {
      const file = process.argv[captureIdx + 1] || '/tmp/action-ring-capture.png';
      setTimeout(() => controller.showPreview(8000), 400);
      setTimeout(async () => {
        try {
          // force a mid-selection state so the capture shows a highlighted slot
          overlay.selectedSlot = 1;
          overlay._send({ selectedSlot: 1 });
          await new Promise((r) => setTimeout(r, 350));
          const img = await overlay.win.webContents.capturePage();
          require('node:fs').writeFileSync(file, img.toPNG());
          console.log(`captured: ${file}`);
        } catch (err) {
          console.error('capture failed:', err);
        }
        quit();
      }, 1600);
    }
  });

  app.on('second-instance', () => openSettings());
  app.on('window-all-closed', () => { /* tray app — keep running */ });
  app.on('before-quit', () => controller?.stop());

  function quit() {
    controller?.stop();
    tray?.destroy();
    app.quit();
  }

  // ---- settings window (single, reusable, hide-on-close) ----------------------

  function openSettings() {
    if (settingsWindow && !settingsWindow.isDestroyed()) {
      settingsWindow.show();
      settingsWindow.focus();
      return;
    }
    settingsWindow = new BrowserWindow({
      width: 560,
      height: 640,
      resizable: false,
      minimizable: true,
      maximizable: false,
      fullscreenable: false,
      title: 'ActionRing Settings',
      autoHideMenuBar: true,
      webPreferences: {
        preload: path.join(__dirname, '..', 'renderer', 'settings', 'preload.js'),
        contextIsolation: true,
        nodeIntegration: false,
        sandbox: false, // preload requires shared modules
      },
    });
    settingsWindow.loadFile(path.join(__dirname, '..', 'renderer', 'settings', 'settings.html'));
    settingsWindow.on('close', (e) => {
      // hide-on-close parity (isReleasedWhenClosed = false)
      if (!quittingForReal) {
        e.preventDefault();
        settingsWindow.hide();
      }
    });
  }

  // ---- IPC for the settings renderer ------------------------------------------

  function profileRow(p) {
    return { ...p, _isUserProfile: store.isUserProfile(p) };
  }

  // Renderer-supplied profiles are untrusted: rebuild them through
  // normalizeProfile so only the 13 known keys (+ sanitized actions) survive —
  // strips UI metadata like _isUserProfile and rejects malformed actions before
  // anything is persisted or later executed.
  function cleanIncoming(profile) {
    try { return normalizeProfile(profile); }
    catch { return null; }
  }

  function registerIpc() {
    ipcMain.handle('settings:get', () => ({
      settings: store.settings,
      armed: controller.isArmed,
      hookMode: controller.hook.mode,
      canSuppress: controller.hook.canSuppress,
      platform: process.platform,
    }));

    ipcMain.handle('settings:update', (_e, partial) => {
      // Only accept the known settings keys from the renderer — re-normalize so
      // an unexpected key can't be written into settings.json (or worse, into
      // a prototype). normalizeSettings keeps each field's type/default.
      const merged = normalizeSettings({ ...store.settings, ...(partial || {}) });
      store.settings = merged;
      store.saveSettings();
      controller.applySettings();
      tray.refresh();
      return store.settings;
    });

    ipcMain.handle('settings:recordTrigger', () => new Promise((resolve) => {
      controller.recordTriggerButton((button) => {
        tray.refresh();
        resolve(button);
      });
    }));

    ipcMain.handle('settings:cancelRecord', () => controller.cancelRecording());
    ipcMain.handle('settings:preview', (_e, durationMs) => controller.showPreview(durationMs || undefined));

    ipcMain.handle('profiles:list', () => store.allProfilesForDisplay().map(profileRow));

    ipcMain.handle('profiles:save', (_e, profile) => {
      const clean = cleanIncoming(profile);
      if (clean) {
        store.save(clean);
        controller.contextEngine.refresh();
        tray.refresh();
      }
      return store.allProfilesForDisplay().map(profileRow);
    });

    ipcMain.handle('profiles:delete', (_e, id) => {
      store.delete(String(id));
      controller.contextEngine.refresh();
      return store.allProfilesForDisplay().map(profileRow);
    });

    ipcMain.handle('profiles:setEnabled', (_e, profile, enabled) => {
      const clean = cleanIncoming(profile);
      if (clean) {
        store.setEnabled(clean, !!enabled);
        controller.contextEngine.refresh();
      }
      return store.allProfilesForDisplay().map(profileRow);
    });

    ipcMain.handle('profiles:editableCopy', (_e, profile) => store.editableCopy(profile));

    ipcMain.handle('profiles:new', (_e, { name, appId }) => makeProfile({
      name,
      bundleId: appId,
      category: categoryForAppId(appId),
      slots: createDefaultProfile().slots,
      slotCount: 8,
      source: 'user',
    }));

    ipcMain.handle('apps:selectable', () => {
      const running = process.platform === 'win32' ? enumerateApps() : [];
      const merged = new Map(running.map((a) => [a.appId, a]));
      for (const b of store.builtIns) {
        if (b.bundleId && !merged.has(b.bundleId)) {
          merged.set(b.bundleId, { name: b.name, appId: b.bundleId });
        }
      }
      return [...merged.values()].sort((a, b) =>
        a.name.localeCompare(b.name, undefined, { sensitivity: 'base' })
      );
    });

    ipcMain.handle('dialog:chooseFile', async () => {
      const r = await dialog.showOpenDialog(settingsWindow, {
        properties: ['openFile', 'openDirectory'],
      });
      return r.canceled ? null : r.filePaths[0];
    });

    ipcMain.handle('util:describeAction', (_e, action) => describeAction(action));
    ipcMain.handle('util:renderedSlots', (_e, profile) => renderedSlots(profile));
  }
}
