import Foundation

// MARK: - Profile Source

/// Where a profile originated from
public enum ProfileSource: String, Codable, Equatable, Sendable, CaseIterable {
    case builtin   // Built-in preset
    case user      // User-created
    case ai        // AI-generated
    case community // Community-shared
    case mcp       // MCP-provided
}

// MARK: - App Category

/// Application categories for fallback profile matching
public enum AppCategory: String, Codable, Equatable, Sendable, CaseIterable {
    case ide
    case browser
    case design
    case productivity
    case communication
    case media
    case development
    case terminal
    case other
}

// MARK: - Ring Profile

/// A profile containing ring configuration for a specific app or category
public struct RingProfile: Codable, Identifiable, Equatable, Sendable {
    /// Unique identifier
    public var id: UUID

    /// Display name
    public var name: String

    /// App bundle identifier this profile is for (nil for default)
    public var bundleId: String?

    /// App category for fallback matching
    public var category: AppCategory

    /// Slots configured in this ring
    public var slots: [RingSlot]

    /// Number of slots in the ring (4, 6, or 8)
    public var slotCount: Int

    /// Whether this is the default fallback profile
    public var isDefault: Bool

    /// Associated MCP server IDs
    public var mcpServers: [String]

    /// When this profile was created
    public var createdAt: Date

    /// When this profile was last updated
    public var updatedAt: Date

    /// Where this profile came from
    public var source: ProfileSource

    // MARK: - Valid Slot Counts

    public static let validSlotCounts = [4, 6, 8]

    // MARK: - Initializer

    public init(
        id: UUID = UUID(),
        name: String,
        bundleId: String? = nil,
        category: AppCategory = .other,
        slots: [RingSlot] = [],
        slotCount: Int = 8,
        isDefault: Bool = false,
        mcpServers: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        source: ProfileSource = .user
    ) {
        self.id = id
        self.name = name
        self.bundleId = bundleId
        self.category = category
        self.slots = slots
        self.slotCount = slotCount
        self.isDefault = isDefault
        self.mcpServers = mcpServers
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
    }

    // MARK: - Factory Methods

    /// Creates the default fallback profile
    public static func createDefault() -> RingProfile {
        let defaultSlots: [RingSlot] = [
            RingSlot(position: 0, label: "Copy", icon: "doc.on.doc", action: .keyboardShortcut(.character("c"), modifiers: [.command])),
            RingSlot(position: 1, label: "Paste", icon: "doc.on.clipboard", action: .keyboardShortcut(.character("v"), modifiers: [.command])),
            RingSlot(position: 2, label: "Cut", icon: "scissors", action: .keyboardShortcut(.character("x"), modifiers: [.command])),
            RingSlot(position: 3, label: "Undo", icon: "arrow.uturn.backward", action: .keyboardShortcut(.character("z"), modifiers: [.command])),
            RingSlot(position: 4, label: "Redo", icon: "arrow.uturn.forward", action: .keyboardShortcut(.character("z"), modifiers: [.command, .shift])),
            RingSlot(position: 5, label: "Save", icon: "square.and.arrow.down", action: .keyboardShortcut(.character("s"), modifiers: [.command])),
            RingSlot(position: 6, label: "Select All", icon: "square.and.pencil", action: .keyboardShortcut(.character("a"), modifiers: [.command])),
            RingSlot(position: 7, label: "Close", icon: "xmark", action: .keyboardShortcut(.character("w"), modifiers: [.command])),
        ]

        return RingProfile(
            name: "Default",
            bundleId: nil,
            category: .other,
            slots: defaultSlots,
            slotCount: 8,
            isDefault: true,
            source: .builtin
        )
    }

    // MARK: - Validation

    /// Returns true if the profile is in a valid state
    public var isValid: Bool {
        Self.validSlotCounts.contains(slotCount) && slots.count <= slotCount
    }

    // MARK: - Timestamp Updates

    /// Updates the updatedAt timestamp to now
    public mutating func touch() {
        updatedAt = Date()
    }

    // MARK: - Slot Management

    /// Adds a slot to the profile
    public mutating func addSlot(_ slot: RingSlot) {
        // Remove any existing slot at the same position
        slots.removeAll { $0.position == slot.position }
        slots.append(slot)
        touch()
    }

    /// Removes the slot at the given position
    public mutating func removeSlot(at position: Int) {
        slots.removeAll { $0.position == position }
        touch()
    }

    /// Updates the slot at the given position
    public mutating func updateSlot(at position: Int, with slot: RingSlot) {
        if let index = slots.firstIndex(where: { $0.position == position }) {
            slots[index] = slot
            touch()
        }
    }

    /// Returns the slot at the given position, or nil if not found
    public func slotAt(position: Int) -> RingSlot? {
        slots.first { $0.position == position }
    }
}

// MARK: - Ring Profile Description

extension RingProfile: CustomStringConvertible {
    public var description: String {
        if let bundleId = bundleId {
            return "Profile: \(name) (\(bundleId))"
        }
        return "Profile: \(name)"
    }
}
