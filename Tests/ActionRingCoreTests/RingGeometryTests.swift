import XCTest
@testable import ActionRingCore

final class RingGeometryTests: XCTestCase {

    private let geo = RingGeometry(size: .medium, slotCount: 8)

    func testDeadZoneReturnsNil() {
        XCTAssertNil(geo.selectedSlot(for: .zero))
        XCTAssertNil(geo.selectedSlot(for: CGPoint(x: 10, y: 0)))  // inside 35px dead zone
    }

    func testSlotZeroIsCenteredOnTheRight() {
        XCTAssertEqual(geo.selectedSlot(for: CGPoint(x: 100, y: 0)), 0)
        XCTAssertEqual(geo.selectedSlot(for: CGPoint(x: 100, y: 10)), 0)
        XCTAssertEqual(geo.selectedSlot(for: CGPoint(x: 100, y: -10)), 0)
    }

    func testCounterClockwiseProgression() {
        XCTAssertEqual(geo.selectedSlot(for: CGPoint(x: 0, y: 100)), 2)   // up   = 90°
        XCTAssertEqual(geo.selectedSlot(for: CGPoint(x: -100, y: 0)), 4)  // left = 180°
        XCTAssertEqual(geo.selectedSlot(for: CGPoint(x: 0, y: -100)), 6)  // down = 270°
    }

    func testAllSlotIndicesAreInRange() {
        for degrees in stride(from: 0, to: 360, by: 5) {
            let rad = CGFloat(degrees) * .pi / 180
            let p = CGPoint(x: 100 * cos(rad), y: 100 * sin(rad))
            let slot = geo.selectedSlot(for: p)
            XCTAssertNotNil(slot)
            XCTAssertTrue((0..<8).contains(slot ?? -1), "slot \(slot ?? -1) out of range at \(degrees)°")
        }
    }

    func testSlotCentersLieInRingBand() {
        for i in 0..<8 {
            XCTAssertTrue(geo.isInRingArea(point: geo.slotCenter(for: i)), "slot \(i) center not in band")
        }
    }

    func testRingSizes() {
        XCTAssertEqual(RingSize.small.outerDiameter, 220)
        XCTAssertEqual(RingSize.medium.outerDiameter, 280)
        XCTAssertEqual(RingSize.large.outerDiameter, 340)
    }

    func testSelectableSlotRequiresAnAction() {
        let full = BuiltInProfiles.vsCode.slots                       // all 8 have actions
        XCTAssertEqual(geo.selectableSlot(for: CGPoint(x: 100, y: 0), in: full), 0)
        XCTAssertNil(geo.selectableSlot(for: .zero, in: full))         // dead zone

        // Slot 0 empty → pointing right resolves to nil (won't fire).
        var sparse = RingProfile(name: "Sparse", slotCount: 8)
        sparse.addSlot(RingSlot(position: 2, label: "Up", icon: "x", action: .systemAction(.mute)))
        let rendered = sparse.renderedSlots()
        XCTAssertNil(geo.selectableSlot(for: CGPoint(x: 100, y: 0), in: rendered))   // slot 0 empty
        XCTAssertEqual(geo.selectableSlot(for: CGPoint(x: 0, y: 100), in: rendered), 2) // slot 2 has action
    }
}
