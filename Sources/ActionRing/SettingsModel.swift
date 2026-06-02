import Foundation
import SwiftUI
import ActionRingCore

/// Observable bridge between the SwiftUI settings form and the live
/// `RingController`. Each property writes through to the persisted settings and
/// re-applies them immediately.
@available(macOS 14.0, *)
@MainActor
@Observable
final class SettingsModel {

    private let controller: RingController
    private let onChanged: () -> Void

    var enabled: Bool { didSet { commit() } }
    var triggerButton: Int { didSet { commit() } }
    var ringSize: RingSize { didSet { commit() } }
    var showLabels: Bool { didSet { commit() } }
    var suppressInFullscreen: Bool { didSet { commit() } }
    var scriptTimeout: Double { didSet { commit() } }

    /// Transient UI state.
    var isRecording = false
    var recordedHint = ""

    init(controller: RingController, onChanged: @escaping () -> Void) {
        self.controller = controller
        self.onChanged = onChanged
        let s = controller.profileStore.settings
        self.enabled = s.enabled
        self.triggerButton = s.triggerButton
        self.ringSize = s.defaultRingSize
        self.showLabels = s.showLabels
        self.suppressInFullscreen = s.suppressInFullscreen
        self.scriptTimeout = s.scriptTimeoutSeconds
    }

    var accessibilityGranted: Bool { EventTapManager.hasAccessibilityPermissions() }

    var triggerLabel: String { mouseButtonLabel(triggerButton) }

    /// Profiles to display (name + target), resolved through the store.
    var profiles: [RingProfile] { controller.profileStore.allProfilesForDisplay() }

    func startRecording() {
        isRecording = true
        recordedHint = "Press the mouse button you want to use…"
        controller.recordTriggerButton { [weak self] button in
            guard let self else { return }
            self.isRecording = false
            self.triggerButton = button   // commit() persists + applies
            self.recordedHint = "Set to \(mouseButtonLabel(button))"
        }
    }

    func openAccessibility() { EventTapManager.openAccessibilitySettings() }

    func previewRing() { controller.showPreview() }

    private func commit() {
        var s = controller.profileStore.settings
        s.enabled = enabled
        s.triggerButton = triggerButton
        s.defaultRingSize = ringSize
        s.showLabels = showLabels
        s.suppressInFullscreen = suppressInFullscreen
        s.scriptTimeoutSeconds = scriptTimeout
        controller.profileStore.settings = s
        controller.profileStore.saveSettings()
        controller.applySettings()
        onChanged()
    }
}
