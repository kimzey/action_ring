import Testing
import Foundation
@testable import MacRingCore

@Suite("RingProfile Tests")
struct RingProfileTests {

    // MARK: - Profile Creation

    @Test("Create profile with valid properties")
    func createProfileWithValidProperties() {
        let profile = RingProfile(
            id: UUID(),
            name: "Test Profile",
            bundleId: "com.example.app",
            category: .ide,
            slots: [],
            slotCount: 8,
            isDefault: false,
            mcpServers: [],
            createdAt: Date(),
            updatedAt: Date(),
            source: .user
        )

        #expect(profile.name == "Test Profile")
        #expect(profile.bundleId == "com.example.app")
        #expect(profile.slotCount == 8)
        #expect(profile.source == .user)
    }

    @Test("Create profile with minimal required properties")
    func createProfileWithMinimalProperties() {
        let profile = RingProfile(
            name: "Minimal Profile",
            slotCount: 8
        )

        #expect(profile.name == "Minimal Profile")
        #expect(profile.id != UUID())
        #expect(profile.slots.isEmpty)
        #expect(profile.isDefault == false)
        #expect(profile.source == .user)
    }

    @Test("Create default profile")
    func createDefaultProfile() {
        let profile = RingProfile.createDefault()

        #expect(profile.isDefault == true)
        #expect(profile.bundleId == nil)
        #expect(profile.slotCount == 8)
        #expect(profile.slots.count == 8)
    }

    // MARK: - Profile Validation

    @Test("Validate slot count is within allowed range")
    func validateSlotCountRange() {
        let validCounts = [4, 6, 8]

        for count in validCounts {
            let profile = RingProfile(name: "Test", slotCount: count)
            #expect(profile.isValid)
        }
    }

    @Test("Invalid slot count is rejected")
    func invalidSlotCountRejected() {
        let invalidCounts = [0, 1, 3, 5, 7, 9, 10, 12]

        for count in invalidCounts {
            let profile = RingProfile(name: "Test", slotCount: count)
            #expect(!profile.isValid)
        }
    }

    @Test("Profile with slots count matching slotCount is valid")
    func slotsCountMatchesSlotCount() {
        let slots = (0..<8).map { _ in RingSlot(position: 0, label: "Test", icon: "star") }
        let profile = RingProfile(
            name: "Test",
            slots: slots,
            slotCount: 8
        )

        #expect(profile.isValid)
    }

    @Test("Profile with more slots than slotCount is invalid")
    func tooManySlotsIsInvalid() {
        let slots = (0..<10).map { _ in RingSlot(position: 0, label: "Test", icon: "star") }
        let profile = RingProfile(
            name: "Test",
            slots: slots,
            slotCount: 8
        )

        #expect(!profile.isValid)
    }

    // MARK: - Profile Source

    @Test("All profile sources are correctly categorized")
    func profileSourceCategorization() {
        let sources: [ProfileSource] = [.builtin, .user, .ai, .community, .mcp]

        for source in sources {
            let profile = RingProfile(name: "Test", source: source)
            #expect(profile.source == source)
        }
    }

    // MARK: - App Category

    @Test("All app categories are valid")
    func allAppCategoriesValid() {
        let categories: [AppCategory] = [
            .ide, .browser, .design, .productivity, .communication,
            .media, .development, .terminal, .other
        ]

        for category in categories {
            let profile = RingProfile(name: "Test", category: category)
            #expect(profile.category == category)
        }
    }

    // MARK: - MCP Integration

    @Test("Profile can have associated MCP servers")
    func mcpServerAssociation() {
        let servers = ["github", "slack", "notion"]
        let profile = RingProfile(
            name: "Test",
            mcpServers: servers
        )

        #expect(profile.mcpServers.count == 3)
        #expect(profile.mcpServers.contains("github"))
    }

    // MARK: - Profile Updates

    @Test("Updating profile changes updatedAt timestamp")
    func updateProfileChangesTimestamp() {
        let originalDate = Date(timeIntervalSince1970: 1000)
        var profile = RingProfile(
            name: "Original",
            createdAt: originalDate,
            updatedAt: originalDate
        )

        // Simulate a delay
        Thread.sleep(forTimeInterval: 0.01)

        profile.name = "Updated"
        profile.touch()

        #expect(profile.name == "Updated")
        #expect(profile.createdAt == originalDate)
        #expect(profile.updatedAt > originalDate)
    }

    // MARK: - Slot Management

    @Test("Add slot to profile")
    func addSlotToProfile() {
        var profile = RingProfile(name: "Test", slotCount: 8)
        let slot = RingSlot(position: 0, label: "New Slot", icon: "plus")

        profile.addSlot(slot)

        #expect(profile.slots.count == 1)
        #expect(profile.slots.first?.label == "New Slot")
    }

    @Test("Add slot at specific position")
    func addSlotAtSpecificPosition() {
        var profile = RingProfile(name: "Test", slotCount: 4)
        let slot = RingSlot(position: 2, label: "Position 2", icon: "star")

        profile.addSlot(slot)

        #expect(profile.slots.count == 1)
        #expect(profile.slots.first?.position == 2)
    }

    @Test("Remove slot from profile")
    func removeSlotFromProfile() {
        var profile = RingProfile(name: "Test", slotCount: 8)
        let slot = RingSlot(position: 0, label: "Remove Me", icon: "trash")
        profile.addSlot(slot)

        profile.removeSlot(at: 0)

        #expect(profile.slots.isEmpty)
    }

    @Test("Update slot at position")
    func updateSlotAtPosition() {
        var profile = RingProfile(name: "Test", slotCount: 8)
        let slot = RingSlot(position: 0, label: "Original", icon: "star")
        profile.addSlot(slot)

        let updatedSlot = RingSlot(position: 0, label: "Updated", icon: "star.fill")
        profile.updateSlot(at: 0, with: updatedSlot)

        #expect(profile.slots.first?.label == "Updated")
    }

    @Test("Get slot at valid position")
    func getSlotAtValidPosition() {
        var profile = RingProfile(name: "Test", slotCount: 8)
        let slot = RingSlot(position: 3, label: "Test Slot", icon: "star")
        profile.addSlot(slot)

        let retrieved = profile.slotAt(position: 3)

        #expect(retrieved?.label == "Test Slot")
    }

    @Test("Get slot at invalid position returns nil")
    func getSlotAtInvalidPosition() {
        let profile = RingProfile(name: "Test", slotCount: 8)

        let retrieved = profile.slotAt(position: 99)

        #expect(retrieved == nil)
    }
}
