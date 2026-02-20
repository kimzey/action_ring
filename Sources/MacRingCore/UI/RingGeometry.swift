import Foundation
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Ring Size Constants

/// Available ring sizes
public enum RingSize {
    case small
    case medium
    case large

    /// Outer diameter in pixels
    public var outerDiameter: CGFloat {
        switch self {
        case .small: return 220
        case .medium: return 280
        case .large: return 340
        }
    }

    /// Default dead zone radius for this ring size
    public var defaultDeadZoneRadius: CGFloat {
        switch self {
        case .small: return 30
        case .medium: return 35
        case .large: return 40
        }
    }
}

// MARK: - Ring Geometry

/// Handles geometry calculations for the action ring
public struct RingGeometry: Equatable, Sendable {
    /// Outer diameter of the ring in pixels
    public let outerDiameter: CGFloat

    /// Radius of the center dead zone where no slot is selected
    public let deadZoneRadius: CGFloat

    /// Number of slots in the ring (4, 6, or 8)
    public let slotCount: Int

    // MARK: - Initializer

    public init(
        outerDiameter: CGFloat,
        deadZoneRadius: CGFloat,
        slotCount: Int
    ) {
        self.outerDiameter = outerDiameter
        self.deadZoneRadius = deadZoneRadius
        self.slotCount = slotCount
    }

    /// Convenience initializer with RingSize
    public init(size: RingSize, slotCount: Int) {
        self.outerDiameter = size.outerDiameter
        self.deadZoneRadius = size.defaultDeadZoneRadius
        self.slotCount = slotCount
    }

    // MARK: - Computed Properties

    /// Returns the outer radius (half the diameter)
    public var outerRadius: CGFloat {
        outerDiameter / 2
    }

    /// Returns the angular width of each slot in radians
    public var slotAngularWidth: CGFloat {
        (2 * CGFloat.pi) / CGFloat(slotCount)
    }

    // MARK: - Slot Selection

    /// Returns the selected slot index for a point relative to ring center,
    /// or nil if the point is within the dead zone.
    public func selectedSlot(for point: CGPoint) -> Int? {
        // Calculate distance from center
        let distance = sqrt(point.x * point.x + point.y * point.y)

        // Check if in dead zone
        if distance <= deadZoneRadius {
            return nil
        }

        // Calculate angle and normalize to [0, 2π)
        let angle = atan2(point.y, point.x)
        let normalizedAngle = angle < 0 ? angle + 2 * CGFloat.pi : angle

        // Calculate slot index
        let slotIndex = Int(normalizedAngle / slotAngularWidth)

        return min(slotIndex, slotCount - 1)
    }

    // MARK: - Slot Geometry

    /// Returns the angle in radians for the center of the given slot index.
    public func slotAngle(for index: Int) -> CGFloat {
        CGFloat(index) * slotAngularWidth
    }

    /// Returns the center point of a slot relative to the ring center.
    public func slotCenter(for index: Int) -> CGPoint {
        let angle = slotAngle(for: index)
        let midRadius = (deadZoneRadius + outerRadius) / 2

        return CGPoint(
            x: midRadius * cos(angle),
            y: midRadius * sin(angle)
        )
    }

    // MARK: - Area Detection

    /// Returns true if the given point (relative to center) is within the ring area
    /// (outside dead zone, inside outer radius).
    public func isInRingArea(point: CGPoint) -> Bool {
        let distance = sqrt(point.x * point.x + point.y * point.y)
        return distance > deadZoneRadius && distance <= outerRadius
    }
}

// MARK: - CGPoint Trigonometry Extensions

#if canImport(AppKit)
extension CGPoint {
    /// Calculates distance from this point to another point
    func distance(to point: CGPoint) -> CGFloat {
        let dx = point.x - x
        let dy = point.y - y
        return sqrt(dx * dx + dy * dy)
    }

    /// Returns the angle from this point to another point
    func angle(to point: CGPoint) -> CGFloat {
        atan2(point.y - y, point.x - x)
    }
}
#endif
