import Foundation

// MARK: - Profile Source

public enum ProfileSource: String, Codable, Equatable, Sendable, CaseIterable {
    case builtin   // shipped preset
    case user      // user-created / user-edited
    case ai        // AI-generated (future)
    case community // imported/shared (future)
    case mcp       // MCP-provided (future)
}

// MARK: - App Category

/// Coarse app categories used for fallback profile matching.
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

/// Ring configuration for a specific app (by bundle id) or a category fallback.
public struct RingProfile: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    /// Bundle identifier this profile targets (nil for category/default profiles).
    public var bundleId: String?
    public var category: AppCategory
    public var slots: [RingSlot]
    public var slotCount: Int
    public var ringSize: RingSize
    /// Whether this profile is active. A disabled app profile falls back to the
    /// category / default ring instead.
    public var isEnabled: Bool
    /// True for the universal fallback profile (always present, matches everything).
    public var isDefault: Bool
    public var mcpServers: [String]
    public var createdAt: Date
    public var updatedAt: Date
    public var source: ProfileSource

    public static let validSlotCounts = [4, 6, 8]

    public init(
        id: UUID = UUID(),
        name: String,
        bundleId: String? = nil,
        category: AppCategory = .other,
        slots: [RingSlot] = [],
        slotCount: Int = 8,
        ringSize: RingSize = .medium,
        isEnabled: Bool = true,
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
        self.ringSize = ringSize
        self.isEnabled = isEnabled
        self.isDefault = isDefault
        self.mcpServers = mcpServers
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
    }

    // MARK: Codable (tolerate older payloads missing ringSize)

    private enum CodingKeys: String, CodingKey {
        case id, name, bundleId, category, slots, slotCount, ringSize
        case isEnabled, isDefault, mcpServers, createdAt, updatedAt, source
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        bundleId = try c.decodeIfPresent(String.self, forKey: .bundleId)
        category = try c.decode(AppCategory.self, forKey: .category)
        slots = try c.decode([RingSlot].self, forKey: .slots)
        slotCount = try c.decode(Int.self, forKey: .slotCount)
        ringSize = try c.decodeIfPresent(RingSize.self, forKey: .ringSize) ?? .medium
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        isDefault = try c.decode(Bool.self, forKey: .isDefault)
        mcpServers = try c.decodeIfPresent([String].self, forKey: .mcpServers) ?? []
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        source = try c.decode(ProfileSource.self, forKey: .source)
    }

    // MARK: Factory

    /// The universal fallback profile (clipboard + editing essentials).
    public static func createDefault() -> RingProfile {
        RingProfile(
            name: "Default",
            bundleId: nil,
            category: .other,
            slots: [
                RingSlot(position: 0, label: "Copy", icon: "doc.on.doc", action: .keyboardShortcut(.character("c"), modifiers: [.command]), color: .blue),
                RingSlot(position: 1, label: "Paste", icon: "doc.on.clipboard", action: .keyboardShortcut(.character("v"), modifiers: [.command]), color: .green),
                RingSlot(position: 2, label: "Cut", icon: "scissors", action: .keyboardShortcut(.character("x"), modifiers: [.command]), color: .orange),
                RingSlot(position: 3, label: "Undo", icon: "arrow.uturn.backward", action: .keyboardShortcut(.character("z"), modifiers: [.command]), color: .purple),
                RingSlot(position: 4, label: "Redo", icon: "arrow.uturn.forward", action: .keyboardShortcut(.character("z"), modifiers: [.command, .shift]), color: .purple),
                RingSlot(position: 5, label: "Save", icon: "square.and.arrow.down", action: .keyboardShortcut(.character("s"), modifiers: [.command]), color: .teal),
                RingSlot(position: 6, label: "Select All", icon: "selection.pin.in.out", action: .keyboardShortcut(.character("a"), modifiers: [.command]), color: .indigo),
                RingSlot(position: 7, label: "Screenshot", icon: "camera.viewfinder", action: .systemAction(.screenshotArea), color: .pink),
            ],
            slotCount: 8,
            isDefault: true,
            source: .builtin
        )
    }

    // MARK: Validation & mutation

    public var isValid: Bool {
        Self.validSlotCounts.contains(slotCount) && slots.allSatisfy { $0.position < slotCount }
    }

    public mutating func touch() { updatedAt = Date() }

    public mutating func addSlot(_ slot: RingSlot) {
        slots.removeAll { $0.position == slot.position }
        slots.append(slot)
        slots.sort { $0.position < $1.position }
        touch()
    }

    public mutating func removeSlot(at position: Int) {
        slots.removeAll { $0.position == position }
        touch()
    }

    public mutating func updateSlot(at position: Int, with slot: RingSlot) {
        if let i = slots.firstIndex(where: { $0.position == position }) {
            slots[i] = slot
            touch()
        }
    }

    public func slotAt(position: Int) -> RingSlot? {
        slots.first { $0.position == position }
    }

    /// Returns slots padded to `slotCount`, sorted by position, filling gaps with
    /// empty placeholders. Used by the renderer so every spoke has a slot.
    public func renderedSlots() -> [RingSlot] {
        (0..<slotCount).map { pos in
            slotAt(position: pos) ?? RingSlot.empty(at: pos)
        }
    }
}

extension RingProfile: CustomStringConvertible {
    public var description: String {
        bundleId.map { "Profile: \(name) (\($0))" } ?? "Profile: \(name)"
    }
}
