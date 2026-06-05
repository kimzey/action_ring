'use strict';
// Profile resolution — the exact 5-step chain from ProfileStore.swift.
// Pure function so the edge cases stay unit-testable.

/**
 * resolveProfile — parity with ProfileStore.resolveProfile(forBundleId:category:).
 *
 * 1. If appId given:
 *    a. user profile with matching bundleId: if ENABLED → return it.
 *       If found but DISABLED → skip BOTH it and the built-in (explicit
 *       disable suppresses the app's ring entirely) → fall to category chain.
 *    b. no user profile for that appId → built-in with matching bundleId wins.
 * 2. First user profile with bundleId==null && !isDefault && isEnabled && category match.
 * 3. categoryDefaults[category].
 * 4. defaultProfile.
 *
 * @param {object} p { userProfiles, builtIns, categoryDefaults, defaultProfile }
 * @param {string|null} appId   exe name lowercased (Windows' bundleId)
 * @param {string} category     AppCategory raw value
 */
function resolveProfile({ userProfiles, builtIns, categoryDefaults, defaultProfile }, appId, category) {
  if (appId != null) {
    const user = userProfiles.find((p) => p.bundleId === appId);
    if (user) {
      if (user.isEnabled) return user;
      // disabled user override suppresses the built-in too — fall through
    } else {
      const builtin = builtIns.find((p) => p.bundleId === appId);
      if (builtin) return builtin;
    }
  }
  const catUser = userProfiles.find(
    (p) => p.bundleId == null && !p.isDefault && p.isEnabled && p.category === category
  );
  if (catUser) return catUser;
  if (categoryDefaults[category]) return categoryDefaults[category];
  return defaultProfile;
}

/**
 * allProfilesForDisplay — userProfiles + built-ins not overridden by a user
 * profile with the same bundleId + the default profile last.
 */
function allProfilesForDisplay({ userProfiles, builtIns, defaultProfile }) {
  const overridden = new Set(userProfiles.map((p) => p.bundleId).filter(Boolean));
  const visibleBuiltIns = builtIns.filter((p) => p.bundleId == null || !overridden.has(p.bundleId));
  return [...userProfiles, ...visibleBuiltIns, defaultProfile];
}

module.exports = { resolveProfile, allProfilesForDisplay };
