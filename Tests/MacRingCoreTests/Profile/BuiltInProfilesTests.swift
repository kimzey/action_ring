import Testing
import Foundation
@testable import MacRingCore

@Suite("Built-in Profiles Tests")
struct BuiltInProfilesTests {

    // MARK: - Profile Loading Tests

    @Test("All 10 profiles load successfully")
    func allProfilesLoadSuccessfully() async {
        let profiles = BuiltInProfiles.all

        #expect(profiles.count == 10, "Expected 10 built-in profiles, got \(profiles.count)")
    }

    @Test("Each profile has correct bundleId")
    func eachProfileHasCorrectBundleId() async {
        let profiles = BuiltInProfiles.all

        let expectedBundleIds = [
            "com.microsoft.VSCode",
            "com.apple.dt.Xcode",
            "com.apple.Safari",
            "com.apple.finder",
            "com.apple.Terminal",
            "com.apple.Notes",
            "com.apple.MobileSMS",  // Messages
            "com.spotify.client",
            "com.tinyspeck.slackmacgap",
            nil,  // System default
        ]

        for (index, profile) in profiles.enumerated() {
            let expectedId = expectedBundleIds[index]
            #expect(profile.bundleId == expectedId, "Profile \(index) bundleId mismatch")
        }
    }

    @Test("Each profile has correct slot count")
    func eachProfileHasCorrectSlotCount() async {
        let profiles = BuiltInProfiles.all

        for profile in profiles {
            #expect(RingProfile.validSlotCounts.contains(profile.slotCount))
            #expect(profile.slots.count <= profile.slotCount)
        }
    }

    @Test("Each profile has 8 slots (default)")
    func eachProfileHasEightSlots() async {
        let profiles = BuiltInProfiles.all

        for profile in profiles {
            #expect(profile.slotCount == 8, "Profile '\(profile.name)' should have 8 slots")
            #expect(profile.slots.count == 8, "Profile '\(profile.name)' should have 8 slots")
        }
    }

    @Test("Each slot has valid action type")
    func eachSlotHasValidActionType() async {
        let profiles = BuiltInProfiles.all

        for profile in profiles {
            for (index, slot) in profile.slots.enumerated() {
                // Verify action is valid by checking it can be encoded/decoded
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()

                do {
                    let data = try encoder.encode(slot.action)
                    let decoded = try decoder.decode(RingAction.self, from: data)
                    #expect(decoded == slot.action, "Slot \(index) in profile '\(profile.name)' action mismatch")
                } catch {
                    Issue.record("Slot \(index) in profile '\(profile.name)' has invalid action: \(error)")
                }
            }
        }
    }

    @Test("Each slot has valid icon")
    func eachSlotHasValidIcon() async {
        let profiles = BuiltInProfiles.all

        for profile in profiles {
            for slot in profile.slots {
                #expect(!slot.icon.isEmpty, "Slot in profile '\(profile.name)' has empty icon")
                #expect(!slot.icon.contains(" "), "Icon should not contain spaces")
            }
        }
    }

    @Test("All profiles are builtin source")
    func allProfilesAreBuiltinSource() async {
        let profiles = BuiltInProfiles.all

        for profile in profiles {
            #expect(profile.source == .builtin, "Profile '\(profile.name)' should be .builtin source")
        }
    }

    @Test("Default profile is marked as default")
    func defaultProfileIsMarkedAsDefault() async {
        let defaultProfile = BuiltInProfiles.default

        #expect(defaultProfile.isDefault, "Default profile should have isDefault = true")
        #expect(defaultProfile.bundleId == nil, "Default profile should have nil bundleId")
    }

    // MARK: - VS Code Profile Tests

    @Test("VS Code profile has correct shortcuts")
    func vsCodeProfileHasCorrectShortcuts() async {
        let vsCodeProfile = BuiltInProfiles.vsCode

        #expect(vsCodeProfile.bundleId == "com.microsoft.VSCode")
        #expect(vsCodeProfile.name == "VS Code")
        #expect(vsCodeProfile.category == .ide)

        // Check for common VS Code shortcuts
        let hasCommandPalette = vsCodeProfile.slots.contains { slot in
            if case .keyboardShortcut(let key, let modifiers) = slot.action {
                return key == .character("p") && modifiers.contains(.command)
            }
            return false
        }
        #expect(hasCommandPalette, "VS Code profile should have Command+Palette shortcut")
    }

    // MARK: - Xcode Profile Tests

    @Test("Xcode profile has build and run shortcuts")
    func xcodeProfileHasBuildAndRunShortcuts() async {
        let xcodeProfile = BuiltInProfiles.xcode

        #expect(xcodeProfile.bundleId == "com.apple.dt.Xcode")
        #expect(xcodeProfile.name == "Xcode")
        #expect(xcodeProfile.category == .ide)

        // Check for Build (Cmd+B)
        let hasBuild = xcodeProfile.slots.contains { slot in
            if case .keyboardShortcut(let key, let modifiers) = slot.action {
                return key == .character("b") && modifiers.contains(.command)
            }
            return false
        }
        #expect(hasBuild, "Xcode profile should have Build shortcut")

        // Check for Run (Cmd+R)
        let hasRun = xcodeProfile.slots.contains { slot in
            if case .keyboardShortcut(let key, let modifiers) = slot.action {
                return key == .character("r") && modifiers.contains(.command)
            }
            return false
        }
        #expect(hasRun, "Xcode profile should have Run shortcut")
    }

    // MARK: - Safari Profile Tests

    @Test("Safari profile has browser shortcuts")
    func safariProfileHasBrowserShortcuts() async {
        let safariProfile = BuiltInProfiles.safari

        #expect(safariProfile.bundleId == "com.apple.Safari")
        #expect(safariProfile.name == "Safari")
        #expect(safariProfile.category == .browser)

        // Check for address bar (Cmd+L)
        let hasAddressBar = safariProfile.slots.contains { slot in
            if case .keyboardShortcut(let key, let modifiers) = slot.action {
                return key == .character("l") && modifiers.contains(.command)
            }
            return false
        }
        #expect(hasAddressBar, "Safari profile should have address bar shortcut")
    }

    // MARK: - Finder Profile Tests

    @Test("Finder profile has file management shortcuts")
    func finderProfileHasFileManagementShortcuts() async {
        let finderProfile = BuiltInProfiles.finder

        #expect(finderProfile.bundleId == "com.apple.finder")
        #expect(finderProfile.name == "Finder")
        #expect(finderProfile.category == .other)
    }

    // MARK: - Terminal Profile Tests

    @Test("Terminal profile has terminal shortcuts")
    func terminalProfileHasTerminalShortcuts() async {
        let terminalProfile = BuiltInProfiles.terminal

        #expect(terminalProfile.bundleId == "com.apple.Terminal")
        #expect(terminalProfile.name == "Terminal")
        #expect(terminalProfile.category == .terminal)
    }

    // MARK: - Notes Profile Tests

    @Test("Notes profile has productivity shortcuts")
    func notesProfileHasProductivityShortcuts() async {
        let notesProfile = BuiltInProfiles.notes

        #expect(notesProfile.bundleId == "com.apple.Notes")
        #expect(notesProfile.name == "Notes")
        #expect(notesProfile.category == .productivity)
    }

    // MARK: - Messages Profile Tests

    @Test("Messages profile has communication shortcuts")
    func messagesProfileHasCommunicationShortcuts() async {
        let messagesProfile = BuiltInProfiles.messages

        #expect(messagesProfile.bundleId == "com.apple.MobileSMS")
        #expect(messagesProfile.name == "Messages")
        #expect(messagesProfile.category == .communication)
    }

    // MARK: - Music/Spotify Profile Tests

    @Test("Music profile has media shortcuts")
    func musicProfileHasMediaShortcuts() async {
        let musicProfile = BuiltInProfiles.spotify

        #expect(musicProfile.bundleId == "com.spotify.client")
        #expect(musicProfile.name == "Spotify")
        #expect(musicProfile.category == .media)
    }

    // MARK: - Slack Profile Tests

    @Test("Slack profile has communication shortcuts")
    func slackProfileHasCommunicationShortcuts() async {
        let slackProfile = BuiltInProfiles.slack

        #expect(slackProfile.bundleId == "com.tinyspeck.slackmacgap")
        #expect(slackProfile.name == "Slack")
        #expect(slackProfile.category == .communication)
    }

    // MARK: - Profile Lookup Tests

    @Test("Can find profile by bundle ID")
    func canFindProfileByBundleId() async {
        let vsCode = BuiltInProfiles.profile(forBundleId: "com.microsoft.VSCode")
        #expect(vsCode != nil)
        #expect(vsCode?.name == "VS Code")
    }

    @Test("Returns nil for unknown bundle ID")
    func returnsNilForUnknownBundleId() async {
        let unknown = BuiltInProfiles.profile(forBundleId: "com.unknown.app")
        #expect(unknown == nil)
    }

    @Test("Case sensitive bundle ID matching")
    func caseSensitiveBundleIdMatching() async {
        let lowercase = BuiltInProfiles.profile(forBundleId: "com.microsoft.vscode")
        #expect(lowercase == nil, "Bundle ID matching should be case-sensitive")
    }

    // MARK: - Profile Immutability Tests

    @Test("Profiles are immutable (copy on write)")
    func profilesAreImmutable() async {
        let profile1 = BuiltInProfiles.vsCode

        // Modifying a copy should not affect the original
        var profile2 = profile1
        profile2.name = "Modified"

        #expect(profile1.name == "VS Code")
        #expect(profile2.name == "Modified")

        // Other properties should be independent
        profile2.slots[0].label = "Changed"
        #expect(profile1.slots[0].label != "Changed")
    }
}
