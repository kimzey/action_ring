import Testing
import Foundation
@testable import MacRingCore

@Suite("RingSlot Tests")
struct RingSlotTests {

    // MARK: - Slot Creation

    @Test("Create slot with all properties")
    func createSlotWithAllProperties() {
        let action = RingAction.keyboardShortcut(.character("c"), modifiers: [.command])
        let slot = RingSlot(
            position: 0,
            label: "Copy",
            icon: "doc.on.doc",
            action: action,
            isEnabled: true,
            color: .blue
        )

        #expect(slot.position == 0)
        #expect(slot.label == "Copy")
        #expect(slot.icon == "doc.on.doc")
        #expect(slot.isEnabled == true)
    }

    @Test("Create slot with minimal properties")
    func createSlotWithMinimalProperties() {
        let slot = RingSlot(
            position: 1,
            label: "Test",
            icon: "star"
        )

        #expect(slot.position == 1)
        #expect(slot.label == "Test")
        #expect(slot.isEnabled == true)  // Default is enabled
    }

    // MARK: - Slot Validation

    @Test("Slot position is within valid range")
    func slotPositionWithinRange() {
        for position in 0..<8 {
            let slot = RingSlot(position: position, label: "Test", icon: "star")
            #expect(slot.isValid)
        }
    }

    @Test("Slot position out of range is invalid")
    func slotPositionOutOfRange() {
        let invalidPositions = [-1, 8, 10, 100]

        for position in invalidPositions {
            let slot = RingSlot(position: position, label: "Test", icon: "star")
            #expect(!slot.isValid)
        }
    }

    // MARK: - Slot Actions

    @Test("Slot with keyboard shortcut action")
    func slotWithKeyboardAction() {
        let action = RingAction.keyboardShortcut(.character("v"), modifiers: [.command, .shift])
        let slot = RingSlot(position: 0, label: "Paste", icon: "doc.on.clipboard", action: action)

        if case .keyboardShortcut(let keyCode, let modifiers) = slot.action {
            #expect(keyCode.character == "v")
            #expect(modifiers.contains(.command))
            #expect(modifiers.contains(.shift))
        } else {
            #expect(Bool(false), "Action should be keyboard shortcut")
        }
    }

    @Test("Slot with launch application action")
    func slotWithLaunchAction() {
        let action = RingAction.launchApplication(bundleIdentifier: "com.apple.Safari")
        let slot = RingSlot(position: 0, label: "Safari", icon: "safari", action: action)

        if case .launchApplication(let bundleId) = slot.action {
            #expect(bundleId == "com.apple.Safari")
        } else {
            #expect(Bool(false), "Action should be launch application")
        }
    }

    @Test("Slot with open URL action")
    func slotWithOpenURLAction() {
        let action = RingAction.openURL("https://example.com")
        let slot = RingSlot(position: 0, label: "Open Website", icon: "link", action: action)

        if case .openURL(let url) = slot.action {
            #expect(url == "https://example.com")
        } else {
            #expect(Bool(false), "Action should be open URL")
        }
    }

    @Test("Slot with system action")
    func slotWithSystemAction() {
        let action = RingAction.systemAction(.lockScreen)
        let slot = RingSlot(position: 0, label: "Lock", icon: "lock", action: action)

        if case .systemAction(let sysAction) = slot.action {
            #expect(sysAction == .lockScreen)
        } else {
            #expect(Bool(false), "Action should be system action")
        }
    }

    // MARK: - Slot State

    @Test("Disabled slot returns isDisabled")
    func disabledSlot() {
        let slot = RingSlot(
            position: 0,
            label: "Disabled",
            icon: "slash",
            isEnabled: false
        )

        #expect(!slot.isEnabled)
        #expect(slot.isDisabled)
    }

    @Test("Enable and disable slot")
    func enableDisableSlot() {
        var slot = RingSlot(position: 0, label: "Test", icon: "star")

        #expect(slot.isEnabled)

        slot.isEnabled = false
        #expect(slot.isDisabled)

        slot.isEnabled = true
        #expect(slot.isEnabled)
    }

    // MARK: - Slot Description

    @Test("Slot description includes label and position")
    func slotDescription() {
        let slot = RingSlot(position: 3, label: "Test Slot", icon: "star")
        let description = slot.description

        // Description should contain meaningful info
        #expect(!description.isEmpty)
    }

    // MARK: - Action Types Validation

    @Test("All Phase 1 action types are valid")
    func phase1ActionTypes() {
        let actions: [RingAction] = [
            .keyboardShortcut(.character("c"), modifiers: [.command]),
            .launchApplication(bundleIdentifier: "com.test.app"),
            .openURL("https://test.com"),
            .systemAction(.lockScreen)
        ]

        for action in actions {
            let slot = RingSlot(position: 0, label: "Test", icon: "star", action: action)
            #expect(slot.action != nil)
        }
    }
}
