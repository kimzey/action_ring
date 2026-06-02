import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Ring Size

/// Available ring sizes.
public enum RingSize: String, Codable, Sendable, CaseIterable {
    case small
    case medium
    case large

    /// Outer diameter in points.
    public var outerDiameter: CGFloat {
        switch self {
        case .small: return 220
        case .medium: return 280
        case .large: return 340
        }
    }

    /// Default dead-zone radius for this ring size.
    public var defaultDeadZoneRadius: CGFloat {
        switch self {
        case .small: return 30
        case .medium: return 35
        case .large: return 40
        }
    }
}

// MARK: - Ring Geometry

/// Pure geometry for the action ring: maps cursor offset → slot index and
/// computes slot center points. No UIKit/AppKit dependency so it is fully
/// unit-testable and `Sendable`.
public struct RingGeometry: Equatable, Sendable {

    /// Outer diameter of the ring in points.
    public let outerDiameter: CGFloat

    /// Radius of the center dead zone where no slot is selected (cancel region).
    public let deadZoneRadius: CGFloat

    /// Number of slots in the ring (4, 6, or 8).
    public let slotCount: Int

    public init(outerDiameter: CGFloat, deadZoneRadius: CGFloat, slotCount: Int) {
        self.outerDiameter = outerDiameter
        self.deadZoneRadius = deadZoneRadius
        self.slotCount = max(1, slotCount)
    }

    /// Convenience initializer from a `RingSize`.
    public init(size: RingSize, slotCount: Int) {
        self.init(
            outerDiameter: size.outerDiameter,
            deadZoneRadius: size.defaultDeadZoneRadius,
            slotCount: slotCount
        )
    }

    // MARK: Derived

    public var outerRadius: CGFloat { outerDiameter / 2 }

    /// Transparent margin around the ring so the drop-shadow fades out smoothly
    /// instead of being clipped to a hard window-edge rectangle.
    public var shadowMargin: CGFloat { 40 }

    /// Full overlay-window size: the ring plus its shadow margin on every side.
    public var canvasDiameter: CGFloat { outerDiameter + shadowMargin * 2 }

    /// Angular width of each slot in radians.
    public var slotAngularWidth: CGFloat { (2 * .pi) / CGFloat(slotCount) }

    // MARK: Slot selection

    /// Returns the selected slot index for a point expressed **relative to the
    /// ring center** (math convention: +x right, +y up), or `nil` if the point
    /// is within the dead zone.
    ///
    /// Slot 0 is centered to the right (angle 0) and indices increase
    /// counter-clockwise. Each slot spans `[i·w - w/2, i·w + w/2)` so that the
    /// slot is *centered* on its spoke rather than starting at it.
    public func selectedSlot(for point: CGPoint) -> Int? {
        let distance = (point.x * point.x + point.y * point.y).squareRoot()
        guard distance > deadZoneRadius else { return nil }

        let raw = atan2(point.y, point.x)                 // (-π, π]
        let width = slotAngularWidth
        // Shift by half a slot so slot 0 is centered on angle 0, then wrap.
        var shifted = raw + width / 2
        let twoPi = 2 * CGFloat.pi
        shifted = shifted.truncatingRemainder(dividingBy: twoPi)
        if shifted < 0 { shifted += twoPi }

        let index = Int(shifted / width)
        return min(max(index, 0), slotCount - 1)
    }

    // MARK: Slot placement

    /// Angle (radians) of the center spoke of a slot.
    public func slotAngle(for index: Int) -> CGFloat {
        CGFloat(index) * slotAngularWidth
    }

    /// Center point of a slot **relative to the ring center** (math convention).
    public func slotCenter(for index: Int) -> CGPoint {
        let angle = slotAngle(for: index)
        let midRadius = (deadZoneRadius + outerRadius) / 2
        return CGPoint(x: midRadius * cos(angle), y: midRadius * sin(angle))
    }

    /// True if a center-relative point lies in the active ring band.
    public func isInRingArea(point: CGPoint) -> Bool {
        let distance = (point.x * point.x + point.y * point.y).squareRoot()
        return distance > deadZoneRadius && distance <= outerRadius
    }

    /// Returns the slot index under a center-relative point **only** if that slot
    /// exists and has an action; otherwise nil (dead zone / empty / no-action).
    /// This is the single source of truth for "what would fire on release," so it
    /// is pure and unit-tested.
    public func selectableSlot(for point: CGPoint, in slots: [RingSlot]) -> Int? {
        guard let index = selectedSlot(for: point) else { return nil }
        guard let slot = slots.first(where: { $0.position == index }), slot.hasAction else { return nil }
        return index
    }
}
