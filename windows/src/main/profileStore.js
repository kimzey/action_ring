'use strict';
// ProfileStore — JSON persistence + lookup, port of ProfileStore.swift/JSONStore.swift.
// Files: profiles.json ([RingProfile]), default.json (RingProfile), settings.json
// (AppSettings) under %APPDATA%/ActionRing — same filenames + schema as macOS.
// Writes are atomic (temp + rename). Parse failures are treated as file-absent.

const fs = require('node:fs');
const path = require('node:path');
const {
  uuid, normalizeProfile, normalizeSettings, touch, encodeJSON, DEFAULT_SETTINGS,
} = require('../shared/models');
const { ALL_BUILTINS, categoryDefaults, createDefaultProfile } = require('../shared/builtinProfiles');
const { resolveProfile, allProfilesForDisplay } = require('../shared/resolution');

const PROFILES_FILE = 'profiles.json';
const DEFAULT_FILE = 'default.json';
const SETTINGS_FILE = 'settings.json';

class ProfileStore {
  /** @param {string} directory  e.g. path.join(app.getPath('appData'), 'ActionRing') */
  constructor(directory) {
    this.directory = directory;
    this.builtIns = ALL_BUILTINS;
    this.categoryDefaults = categoryDefaults();
    this.userProfiles = this._load(PROFILES_FILE, (raw) =>
      Array.isArray(raw) ? raw.map(normalizeProfile) : null
    ) ?? [];
    this.defaultProfile = this._load(DEFAULT_FILE, (raw) => {
      const p = normalizeProfile(raw);
      p.isDefault = true; // the universal fallback is always default (mac parity)
      delete p.bundleId;
      return p;
    }) ?? createDefaultProfile();
    this.settings = this._load(SETTINGS_FILE, normalizeSettings) ?? { ...DEFAULT_SETTINGS };
  }

  // ---- disk layer (JSONStore parity: errors → null, atomic writes) ----------

  _load(name, normalize) {
    try {
      const text = fs.readFileSync(path.join(this.directory, name), 'utf8');
      return normalize(JSON.parse(text));
    } catch {
      return null; // missing/corrupt → caller substitutes default
    }
  }

  _save(name, value) {
    try {
      fs.mkdirSync(this.directory, { recursive: true });
      const target = path.join(this.directory, name);
      const tmp = `${target}.${process.pid}.tmp`;
      fs.writeFileSync(tmp, encodeJSON(value), 'utf8');
      fs.renameSync(tmp, target);
      return true;
    } catch {
      return false;
    }
  }

  persistProfiles() { return this._save(PROFILES_FILE, this.userProfiles); }
  persistDefault() { return this._save(DEFAULT_FILE, this.defaultProfile); }
  saveSettings() { return this._save(SETTINGS_FILE, this.settings); }

  // ---- resolution -------------------------------------------------------------

  resolveProfile(appId, category) {
    return resolveProfile(this, appId, category);
  }

  allProfilesForDisplay() {
    return allProfilesForDisplay(this);
  }

  // ---- mutations (ProfileStore.swift semantics) ---------------------------------

  upsert(profile) {
    const copy = structuredClone(profile);
    touch(copy);
    const i = this.userProfiles.findIndex((p) => p.id === copy.id);
    if (i >= 0) this.userProfiles[i] = copy;
    else this.userProfiles.push(copy);
    this.persistProfiles();
  }

  delete(id) {
    this.userProfiles = this.userProfiles.filter((p) => p.id !== id);
    this.persistProfiles();
  }

  /** Routes the universal default to default.json, everything else to profiles.json. */
  save(profile) {
    if (profile.isDefault) this.updateDefault(profile);
    else this.upsert(profile);
  }

  updateDefault(profile) {
    const copy = structuredClone(profile);
    copy.isDefault = true;
    delete copy.bundleId;
    touch(copy);
    this.defaultProfile = copy;
    this.persistDefault();
  }

  /**
   * Toggling a built-in materializes a user override (new id, source user);
   * repeat toggles update the existing override (de-dup by bundleId).
   * The default profile ignores setEnabled.
   */
  setEnabled(profile, enabled) {
    if (profile.isDefault) return;
    const byId = this.userProfiles.find((p) => p.id === profile.id);
    if (byId) {
      const copy = structuredClone(byId);
      copy.isEnabled = enabled;
      this.upsert(copy);
      return;
    }
    if (profile.bundleId != null) {
      const byBundle = this.userProfiles.find((p) => p.bundleId === profile.bundleId);
      if (byBundle) {
        const copy = structuredClone(byBundle);
        copy.isEnabled = enabled;
        this.upsert(copy);
        return;
      }
    }
    const override = structuredClone(profile);
    override.id = uuid();
    override.source = 'user';
    override.isEnabled = enabled;
    this.upsert(override);
  }

  /** Built-in → fresh user copy (new id); user/default returned as-is. */
  editableCopy(profile) {
    if (profile.isDefault) return structuredClone(profile);
    if (profile.source === 'user' && this.userProfiles.some((p) => p.id === profile.id)) {
      return structuredClone(profile);
    }
    const copy = structuredClone(profile);
    copy.id = uuid();
    copy.source = 'user';
    return copy;
  }

  isUserProfile(profile) {
    return profile.source === 'user' && this.userProfiles.some((p) => p.id === profile.id);
  }
}

module.exports = { ProfileStore, PROFILES_FILE, DEFAULT_FILE, SETTINGS_FILE };
