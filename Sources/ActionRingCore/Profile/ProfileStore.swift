import Foundation

/// Owns the profile database and settings, persists them as JSON, and resolves
/// the active profile via the lookup chain:
///
/// `user(bundleId)` → `builtin(bundleId)` → `user(category)` → `builtin(category)` → `default`
///
/// Used from the main thread (ContextEngine + settings UI); marked
/// `@unchecked Sendable` to satisfy `ProfileProvider` on that contract.
public final class ProfileStore: ProfileProvider, @unchecked Sendable {

    private let store: JSONStore
    private static let profilesFile = "profiles.json"
    private static let defaultFile = "default.json"
    private static let settingsFile = "settings.json"

    public private(set) var userProfiles: [RingProfile]
    public let builtIns: [RingProfile]
    public let categoryDefaults: [AppCategory: RingProfile]
    public private(set) var defaultProfile: RingProfile
    public var settings: AppSettings

    public init(store: JSONStore = JSONStore()) {
        self.store = store
        self.builtIns = BuiltInProfiles.all
        self.categoryDefaults = BuiltInProfiles.categoryDefaults
        self.userProfiles = store.load([RingProfile].self, from: Self.profilesFile) ?? []
        self.defaultProfile = store.load(RingProfile.self, from: Self.defaultFile) ?? .createDefault()
        self.settings = store.load(AppSettings.self, from: Self.settingsFile) ?? AppSettings()
    }

    // MARK: Resolution

    public func resolveProfile(forBundleId bundleId: String?, category: AppCategory) -> RingProfile {
        if let bundleId {
            if let user = userProfiles.first(where: { $0.bundleId == bundleId }) {
                // A user profile overrides the built-in. If the user disabled it,
                // fall through to the category / default chain — the disable was
                // explicit, so don't use the built-in either.
                if user.isEnabled { return user }
            } else if let builtin = builtIns.first(where: { $0.bundleId == bundleId }) {
                return builtin
            }
        }
        if let p = userProfiles.first(where: {
            $0.bundleId == nil && !$0.isDefault && $0.isEnabled && $0.category == category
        }) { return p }
        if let p = categoryDefaults[category] { return p }
        return defaultProfile
    }

    // MARK: Display

    /// All profiles a configuration UI should list: user first, then built-ins
    /// not overridden by a user profile, then the default.
    public func allProfilesForDisplay() -> [RingProfile] {
        let overriddenBundleIds = Set(userProfiles.compactMap { $0.bundleId })
        let visibleBuiltIns = builtIns.filter { builtin in
            guard let id = builtin.bundleId else { return true }
            return !overriddenBundleIds.contains(id)
        }
        return userProfiles + visibleBuiltIns + [defaultProfile]
    }

    // MARK: Mutation

    /// Insert or update a user profile (matched by id), then persist.
    public func upsert(_ profile: RingProfile) {
        var p = profile
        p.touch()
        if let i = userProfiles.firstIndex(where: { $0.id == p.id }) {
            userProfiles[i] = p
        } else {
            userProfiles.append(p)
        }
        persistProfiles()
    }

    public func delete(id: UUID) {
        userProfiles.removeAll { $0.id == id }
        persistProfiles()
    }

    /// Persist an edited profile, routing the universal default to its own file.
    public func save(_ profile: RingProfile) {
        if profile.isDefault { updateDefault(profile) } else { upsert(profile) }
    }

    /// Enable/disable a profile. Built-ins can't be edited in place, so toggling
    /// one materializes an editable user override carrying the new state.
    public func setEnabled(_ profile: RingProfile, _ enabled: Bool) {
        guard !profile.isDefault else { return }   // the default is always on
        // Existing user profile (by id) → update in place.
        if let existing = userProfiles.first(where: { $0.id == profile.id }) {
            var p = existing; p.isEnabled = enabled; upsert(p)
            return
        }
        // A built-in already overridden for the same app → update that override
        // (don't create a second one on repeated toggles).
        if let bundleId = profile.bundleId,
           let existing = userProfiles.first(where: { $0.bundleId == bundleId }) {
            var p = existing; p.isEnabled = enabled; upsert(p)
            return
        }
        // Otherwise materialize a fresh user override carrying the new state.
        var copy = profile
        copy.id = UUID()
        copy.source = .user
        copy.isEnabled = enabled
        upsert(copy)
    }

    /// Returns a user-editable copy of a profile. A built-in becomes a new user
    /// override (fresh id); user profiles and the default are returned as-is.
    public func editableCopy(of profile: RingProfile) -> RingProfile {
        if profile.isDefault { return profile }
        if profile.source == .user, userProfiles.contains(where: { $0.id == profile.id }) {
            return profile
        }
        var copy = profile
        copy.id = UUID()
        copy.source = .user
        return copy
    }

    public func updateDefault(_ profile: RingProfile) {
        var p = profile
        p.isDefault = true
        p.bundleId = nil
        p.touch()
        defaultProfile = p
        store.save(defaultProfile, to: Self.defaultFile)
    }

    public func saveSettings() {
        store.save(settings, to: Self.settingsFile)
    }

    private func persistProfiles() {
        store.save(userProfiles, to: Self.profilesFile)
    }
}
