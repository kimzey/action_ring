import Foundation

// MARK: - Slot Color

/// Visual accent for a ring slot.
public enum SlotColor: String, Codable, Equatable, Sendable, CaseIterable {
    case blue, purple, pink, red, orange, yellow, green, gray, teal, indigo
}

// MARK: - Ring Slot

/// A single slot in the action ring.
public struct RingSlot: Codable, Equatable, Sendable, Identifiable {
    /// Position index (0-based, increasing counter-clockwise from the right).
    public var position: Int
    /// Short display label.
    public var label: String
    /// SF Symbol name for the icon.
    public var icon: String
    /// The action fired when this slot is selected (nil = empty slot).
    public var action: RingAction?
    /// Whether the slot is selectable.
    public var isEnabled: Bool
    /// Visual accent.
    public var color: SlotColor

    /// Stable identity for SwiftUI `ForEach` (position is unique within a ring).
    public var id: Int { position }

    /// Max position supported by any ring size (8-slot ring → 0...7).
    public static let maxPosition = 7

    public init(
        position: Int,
        label: String,
        icon: String,
        action: RingAction? = nil,
        isEnabled: Bool = true,
        color: SlotColor = .blue
    ) {
        self.position = position
        self.label = label
        self.icon = icon
        self.action = action
        self.isEnabled = isEnabled
        self.color = color
    }

    public var isValid: Bool { position >= 0 && position <= Self.maxPosition }
    public var hasAction: Bool { action != nil }

    /// An empty placeholder slot at a position.
    public static func empty(at position: Int) -> RingSlot {
        RingSlot(position: position, label: "", icon: "plus", action: nil, isEnabled: false, color: .gray)
    }
}

extension RingSlot: CustomStringConvertible {
    public var description: String { "Slot \(position): \(label.isEmpty ? "(empty)" : label)" }
}
