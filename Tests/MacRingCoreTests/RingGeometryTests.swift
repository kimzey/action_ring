import Testing
import Foundation
@testable import MacRingCore

@Suite("RingGeometry Tests")
struct RingGeometryTests {

    private let defaultGeometry = RingGeometry(
        outerDiameter: 280,
        deadZoneRadius: 35,
        slotCount: 8
    )

    // MARK: - Outer Radius

    @Test("Outer radius is half of diameter")
    func outerRadiusIsHalfDiameter() {
        #expect(defaultGeometry.outerRadius == 140)
    }

    // MARK: - Slot Angular Width

    @Test("Slot angular width for 8 slots")
    func slotAngularWidthFor8Slots() {
        let expected = (2 * CGFloat.pi) / 8
        #expect(abs(defaultGeometry.slotAngularWidth - expected) < 1e-10)
    }

    @Test("Slot angular width for 4 slots")
    func slotAngularWidthFor4Slots() {
        let geo = RingGeometry(outerDiameter: 280, deadZoneRadius: 35, slotCount: 4)
        let expected = (2 * CGFloat.pi) / 4
        #expect(abs(geo.slotAngularWidth - expected) < 1e-10)
    }

    @Test("Slot angular width for 6 slots")
    func slotAngularWidthFor6Slots() {
        let geo = RingGeometry(outerDiameter: 280, deadZoneRadius: 35, slotCount: 6)
        let expected = (2 * CGFloat.pi) / 6
        #expect(abs(geo.slotAngularWidth - expected) < 1e-10)
    }

    // MARK: - Dead Zone

    @Test("Point at origin is dead zone")
    func pointAtOriginIsDeadZone() {
        let result = defaultGeometry.selectedSlot(for: CGPoint(x: 0, y: 0))
        #expect(result == nil, "Center of ring should be dead zone")
    }

    @Test("Point inside dead zone radius returns nil")
    func pointInsideDeadZoneRadiusReturnsNil() {
        // distance = sqrt(800) ~ 28.28 < 35
        let result = defaultGeometry.selectedSlot(for: CGPoint(x: 20, y: 20))
        #expect(result == nil, "Point within dead zone should return nil")
    }

    @Test("Point exactly at dead zone boundary returns nil")
    func pointExactlyAtDeadZoneBoundaryReturnsNil() {
        let result = defaultGeometry.selectedSlot(for: CGPoint(x: 35, y: 0))
        #expect(result == nil, "Point exactly at dead zone boundary should return nil")
    }

    @Test("Point just outside dead zone returns a slot")
    func pointJustOutsideDeadZoneReturnsSlot() {
        let result = defaultGeometry.selectedSlot(for: CGPoint(x: 36, y: 0))
        #expect(result != nil, "Point just outside dead zone should return a slot")
    }

    // MARK: - Outside Ring

    @Test("Point beyond outer radius still returns a slot")
    func pointBeyondOuterRadiusStillReturnsSlot() {
        let result = defaultGeometry.selectedSlot(for: CGPoint(x: 200, y: 0))
        #expect(result != nil, "Point beyond outer radius should still return a slot")
    }

    // MARK: - isInRingArea

    @Test("isInRingArea returns false for dead zone")
    func isInRingAreaReturnsFalseForDeadZone() {
        #expect(!defaultGeometry.isInRingArea(point: CGPoint(x: 0, y: 0)))
    }

    @Test("isInRingArea returns true for valid point")
    func isInRingAreaReturnsTrueForValidPoint() {
        #expect(defaultGeometry.isInRingArea(point: CGPoint(x: 80, y: 0)))
    }

    @Test("isInRingArea returns false for outside ring")
    func isInRingAreaReturnsFalseForOutsideRing() {
        #expect(!defaultGeometry.isInRingArea(point: CGPoint(x: 200, y: 0)))
    }

    // MARK: - Slot Selection (8 slots)

    @Test("Right direction selects slot 0")
    func slotSelectionRightIsSlot0() {
        let result = defaultGeometry.selectedSlot(for: CGPoint(x: 100, y: 0))
        #expect(result == 0)
    }

    @Test("Up-right direction selects slot 1")
    func slotSelectionUpRightIsSlot1() {
        let result = defaultGeometry.selectedSlot(for: CGPoint(x: 70, y: 70))
        #expect(result == 1)
    }

    @Test("Up direction selects slot 2")
    func slotSelectionUpIsSlot2() {
        let result = defaultGeometry.selectedSlot(for: CGPoint(x: 0, y: 100))
        #expect(result == 2)
    }

    @Test("Left direction selects slot 4")
    func slotSelectionLeftIsSlot4() {
        let result = defaultGeometry.selectedSlot(for: CGPoint(x: -100, y: 0))
        #expect(result == 4)
    }

    @Test("Down direction selects slot 6")
    func slotSelectionDownIsSlot6() {
        let result = defaultGeometry.selectedSlot(for: CGPoint(x: 0, y: -100))
        #expect(result == 6)
    }

    @Test("Just below positive x-axis wraps to slot 7")
    func slotSelectionWrapsAround() {
        let result = defaultGeometry.selectedSlot(for: CGPoint(x: 100, y: -10))
        #expect(result == 7)
    }

    // MARK: - Slot Selection (4 slots)

    @Test("4-slot: right selects slot 0")
    func fourSlotSelectionRight() {
        let geo = RingGeometry(outerDiameter: 280, deadZoneRadius: 35, slotCount: 4)
        let result = geo.selectedSlot(for: CGPoint(x: 100, y: 0))
        #expect(result == 0)
    }

    @Test("4-slot: up selects slot 1")
    func fourSlotSelectionUp() {
        let geo = RingGeometry(outerDiameter: 280, deadZoneRadius: 35, slotCount: 4)
        let result = geo.selectedSlot(for: CGPoint(x: 0, y: 100))
        #expect(result == 1)
    }

    @Test("4-slot: left selects slot 2")
    func fourSlotSelectionLeft() {
        let geo = RingGeometry(outerDiameter: 280, deadZoneRadius: 35, slotCount: 4)
        let result = geo.selectedSlot(for: CGPoint(x: -100, y: 0))
        #expect(result == 2)
    }

    @Test("4-slot: down selects slot 3")
    func fourSlotSelectionDown() {
        let geo = RingGeometry(outerDiameter: 280, deadZoneRadius: 35, slotCount: 4)
        let result = geo.selectedSlot(for: CGPoint(x: 0, y: -100))
        #expect(result == 3)
    }

    // MARK: - Slot Angle

    @Test("Slot angle for slot 0 is 0")
    func slotAngleForSlot0() {
        let angle = defaultGeometry.slotAngle(for: 0)
        #expect(abs(angle - 0) < 1e-10)
    }

    @Test("Slot angle for slot 2 is pi/2")
    func slotAngleForSlot2() {
        let expected = CGFloat.pi / 2
        let angle = defaultGeometry.slotAngle(for: 2)
        #expect(abs(angle - expected) < 1e-10)
    }

    @Test("Slot angle for slot 4 is pi")
    func slotAngleForSlot4() {
        let expected = CGFloat.pi
        let angle = defaultGeometry.slotAngle(for: 4)
        #expect(abs(angle - expected) < 1e-10)
    }

    @Test("Slot angle for last slot (7)")
    func slotAngleForLastSlot() {
        let expected = 7 * (2 * CGFloat.pi) / 8
        let angle = defaultGeometry.slotAngle(for: 7)
        #expect(abs(angle - expected) < 1e-10)
    }

    // MARK: - Slot Center

    @Test("Slot center for slot 0 is on positive x-axis")
    func slotCenterForSlot0IsOnPositiveXAxis() {
        let center = defaultGeometry.slotCenter(for: 0)
        let midRadius = (35 + 140) / 2.0
        #expect(abs(center.x - midRadius) < 1e-5)
        #expect(abs(center.y - 0) < 1e-5)
    }

    @Test("Slot center for slot 2 is on positive y-axis")
    func slotCenterForSlot2IsOnPositiveYAxis() {
        let center = defaultGeometry.slotCenter(for: 2)
        let midRadius = (35 + 140) / 2.0
        #expect(abs(center.x - 0) < 1e-5)
        #expect(abs(center.y - midRadius) < 1e-5)
    }

    // MARK: - RingSize Constants

    @Test("RingSize small diameter is 220")
    func ringSizeSmallDiameter() {
        #expect(RingSize.small.outerDiameter == 220)
    }

    @Test("RingSize medium diameter is 280")
    func ringSizeMediumDiameter() {
        #expect(RingSize.medium.outerDiameter == 280)
    }

    @Test("RingSize large diameter is 340")
    func ringSizeLargeDiameter() {
        #expect(RingSize.large.outerDiameter == 340)
    }

    // MARK: - Edge Cases

    @Test("Negative coordinates select correct slot")
    func negativeCoordinatesSelectCorrectSlot() {
        // Angle ~ 225 degrees -> slot 5
        let result = defaultGeometry.selectedSlot(for: CGPoint(x: -70, y: -70))
        #expect(result == 5)
    }

    @Test("Very small distance beyond dead zone")
    func verySmallDistanceBeyondDeadZone() {
        let result = defaultGeometry.selectedSlot(for: CGPoint(x: 35.01, y: 0))
        #expect(result == 0)
    }

    @Test("Boundary point between slots goes to lower slot index")
    func slotBoundaryPointGoesToLowerSlot() {
        // At angle pi/8 exactly, should go to slot 0 (floor behavior)
        let angle = CGFloat.pi / 8
        let distance: CGFloat = 80
        let point = CGPoint(x: distance * cos(angle), y: distance * sin(angle))
        let result = defaultGeometry.selectedSlot(for: point)
        #expect(result == 0, "Boundary point should go to lower slot index")
    }
}
