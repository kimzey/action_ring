import Foundation
import SwiftUI
import ActionRingCore

/// Drives the profile-management UI: lists profiles, toggles them, and persists
/// edits through `ProfileStore`, then refreshes the live ring.
@available(macOS 14.0, *)
@MainActor
@Observable
final class ProfileEditModel {

    let controller: RingController
    /// Bumped after any mutation so SwiftUI re-reads the (value-type) store data.
    private(set) var revision = 0

    init(controller: RingController) { self.controller = controller }

    private var store: ProfileStore { controller.profileStore }

    var profiles: [RingProfile] {
        _ = revision
        return store.allProfilesForDisplay()
    }

    var globalEnabled: Bool {
        get { _ = revision; return store.settings.enabled }
        set {
            store.settings.enabled = newValue
            store.saveSettings()
            controller.applySettings()
            bump()
        }
    }

    /// Apps the user can target (running regular apps), merged with the ones we
    /// already have built-in profiles for, de-duplicated by bundle id.
    func selectableApps() -> [(name: String, bundleId: String)] {
        var byId: [String: String] = [:]
        for app in controller.appDetector.selectableApps() { byId[app.bundleIdentifier] = app.appName }
        for p in store.builtIns { if let id = p.bundleId, byId[id] == nil { byId[id] = p.name } }
        return byId.map { (name: $0.value, bundleId: $0.key) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func setEnabled(_ profile: RingProfile, _ enabled: Bool) {
        store.setEnabled(profile, enabled)
        refresh()
    }

    func editableCopy(of profile: RingProfile) -> RingProfile { store.editableCopy(of: profile) }

    func save(_ profile: RingProfile) {
        store.save(profile)
        refresh()
    }

    func delete(_ profile: RingProfile) {
        store.delete(id: profile.id)
        refresh()
    }

    /// True if this profile is a deletable user profile (not a built-in/default).
    func isUserProfile(_ profile: RingProfile) -> Bool {
        profile.source == .user && store.userProfiles.contains { $0.id == profile.id }
    }

    func category(forBundleId bundleId: String) -> AppCategory {
        controller.appDetector.category(forBundleId: bundleId)
    }

    /// A blank profile targeting an app, prefilled with the default editing ring.
    func newProfile(name: String, bundleId: String) -> RingProfile {
        RingProfile(
            name: name,
            bundleId: bundleId,
            category: category(forBundleId: bundleId),
            slots: RingProfile.createDefault().slots,
            slotCount: 8,
            source: .user
        )
    }

    func preview() { controller.showPreview(duration: 6) }

    private func refresh() {
        controller.contextEngine.refresh()
        bump()
    }

    private func bump() { revision += 1 }
}
