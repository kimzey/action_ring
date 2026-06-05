'use strict';
// ContextEngine + AppDetector — port of Context/ContextEngine.swift + AppDetector.swift.
//
// Windows has no NSWorkspace activation notification we can reach from Electron,
// so AppDetector polls GetForegroundWindow (cheap — 3 Win32 calls) and emits on
// appId change. ContextEngine then applies the mac engine's exact semantics:
// 250 ms trailing debounce, resolve, emit ONLY when profile.id changes,
// always track currentAppId, refresh() bypasses the debounce.

const { EventEmitter } = require('node:events');
const { frontmostApp, available } = require('./win32/foreground');
const { categoryForAppId } = require('../shared/builtinProfiles');

const FOREGROUND_POLL_MS = 250;
const DEBOUNCE_MS = 250;

class AppDetector extends EventEmitter {
  constructor() {
    super();
    this._timer = null;
    this._lastAppId = undefined; // undefined = never sampled
  }

  /** @returns {string|null} exe name lowercased, e.g. "code.exe" */
  focusedAppId() {
    if (!available()) return null;
    const app = frontmostApp();
    return app ? app.appId : null;
  }

  category(appId) { return categoryForAppId(appId || ''); }

  startMonitoring() {
    if (this._timer) return;
    this._timer = setInterval(() => {
      const appId = this.focusedAppId();
      if (appId !== this._lastAppId) {
        this._lastAppId = appId;
        this.emit('appChanged', appId);
      }
    }, FOREGROUND_POLL_MS);
  }

  stopMonitoring() {
    if (this._timer) { clearInterval(this._timer); this._timer = null; }
  }
}

class ContextEngine {
  /** @param {AppDetector} appDetector @param {{resolveProfile:(id,cat)=>object}} provider */
  constructor(appDetector, provider) {
    this.appDetector = appDetector;
    this.provider = provider;
    this.onProfileChange = null;
    this._debounce = null;
    this._started = false;

    this.currentAppId = appDetector.focusedAppId();
    this.currentProfile = provider.resolveProfile(
      this.currentAppId,
      appDetector.category(this.currentAppId ?? '')
    );
  }

  start() {
    if (this._started) return;
    this._started = true;
    // Prime listeners with the initial profile (mac parity).
    this.onProfileChange?.(this.currentProfile);
    this.appDetector.on('appChanged', this._scheduleResolve);
    this.appDetector.startMonitoring();
  }

  stop() {
    if (!this._started) return;
    this._started = false;
    this.appDetector.off('appChanged', this._scheduleResolve);
    this.appDetector.stopMonitoring();
    if (this._debounce) { clearTimeout(this._debounce); this._debounce = null; }
  }

  /**
   * Force immediate re-resolution — bypasses debounce (used after profile edits).
   * Forces an emit even when the id is unchanged, because editing the active
   * profile in place keeps its id but changes its slots (the change-gate would
   * otherwise swallow the live refresh).
   */
  refresh() {
    this._resolve(this.appDetector.focusedAppId(), true);
  }

  _scheduleResolve = (appId) => {
    if (this._debounce) clearTimeout(this._debounce);
    this._debounce = setTimeout(() => {
      this._debounce = null;
      this._resolve(appId);
    }, DEBOUNCE_MS);
  };

  _resolve(appId, force = false) {
    const category = this.appDetector.category(appId ?? '');
    const profile = this.provider.resolveProfile(appId, category);
    this.currentAppId = appId; // always updated, even when profile unchanged
    if (!force && profile.id === this.currentProfile.id) return; // change-gate
    this.currentProfile = profile;
    this.onProfileChange?.(profile);
  }
}

module.exports = { AppDetector, ContextEngine, DEBOUNCE_MS, FOREGROUND_POLL_MS };
