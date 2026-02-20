import Foundation

// MARK: - Slot Color

/// Visual color for a ring slot
public enum SlotColor: String, Codable, Equatable, Sendable, CaseIterable {
    case blue
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case gray
}

// MARK: - Ring Slot

/// A single slot in the action ring
public struct RingSlot: Codable, Equatable, Sendable {
    /// Position index (0-7 for 8-slot ring)
    public var position: Int

    /// Display label for the slot
    public var label: String

    /// SF Symbol name for the slot icon
    public var icon: String

    /// Action to execute when slot is selected
    public var action: RingAction?

    /// Whether the slot is currently enabled
    public var isEnabled: Bool

    /// Visual color accent for the slot
    public var color: SlotColor

    /// Maximum valid position for any ring size
    public static let maxPosition = 7  // 8 slots

    // MARK: - Initializer

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

    // MARK: - Validation

    /// Returns true if the slot is in a valid state
    public var isValid: Bool {
        position >= 0 && position <= Self.maxPosition
    }

    /// Returns true if the slot is disabled
    public var isDisabled: Bool {
        !isEnabled
    }

    /// Returns true if the slot has an action configured
    public var hasAction: Bool {
        action != nil
    }
}

// MARK: - Ring Slot Description

extension RingSlot: CustomStringConvertible {
    public var description: String {
        "Slot \(position): \(label)"
    }
}
