import Foundation
import CoreGraphics

// MARK: - Ring Size Constants

enum RingSize {
    case small
    case medium
    case large

    var outerDiameter: CGFloat {
        fatalError("not implemented")
    }
}

// MARK: - Ring Geometry

struct RingGeometry {
    let outerDiameter: CGFloat
    let deadZoneRadius: CGFloat
    let slotCount: Int

    /// Returns the selected slot index for a point relative to ring center,
    /// or nil if the point is within the dead zone.
    func selectedSlot(for point: CGPoint) -> Int? {
        fatalError("not implemented")
    }

    /// Returns the angle in radians for the center of the given slot index.
    func slotAngle(for index: Int) -> CGFloat {
        fatalError("not implemented")
    }

    /// Returns the center point of a slot relative to the ring center.
    func slotCenter(for index: Int) -> CGPoint {
        fatalError("not implemented")
    }

    /// Returns the angular width of each slot in radians.
    var slotAngularWidth: CGFloat {
        fatalError("not implemented")
    }

    /// Returns the outer radius (half the diameter).
    var outerRadius: CGFloat {
        fatalError("not implemented")
    }

    /// Returns true if the given point (relative to center) is within the ring area
    /// (outside dead zone, inside outer radius).
    func isInRingArea(point: CGPoint) -> Bool {
        fatalError("not implemented")
    }
}
