import XCTest
@testable import ActionRingCore

final class ProfileTests: XCTestCase {

    func testRingActionRoundTrips() throws {
        let actions: [RingAction] = [
            .keyboardShortcut(.character("c"), modifiers: [.command]),
            .keyboardShortcut(.special(.f5), modifiers: [.command, .shift]),
            .launchApplication(bundleIdentifier: "com.apple.Safari"),
            .openURL("https://example.com"),
            .systemAction(.screenshotArea),
            .shellScript("echo hi"),
            .textSnippet("hello"),
            .workflow([.systemAction(.mute), .openURL("https://a.b")]),
        ]
        let enc = JSONEncoder()
        let dec = JSONDecoder()
        for a in actions {
            let back = try dec.decode(RingAction.self, from: try enc.encode(a))
            XCTAssertEqual(a, back)
        }
    }

    func testProfileRoundTripsAndToleratesMissingRingSize() throws {
        let p = BuiltInProfiles.vsCode
        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(RingProfile.self, from: data)
        XCTAssertEqual(back.name, "VS Code")
        XCTAssertEqual(back.slots.count, 8)

        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        obj.removeValue(forKey: "ringSize")
        let stripped = try JSONSerialization.data(withJSONObject: obj)
        let decoded = try JSONDecoder().decode(RingProfile.self, from: stripped)
        XCTAssertEqual(decoded.ringSize, .medium)
    }

    func testDefaultProfileIsValidAndFull() {
        let p = RingProfile.createDefault()
        XCTAssertTrue(p.isDefault)
        XCTAssertNil(p.bundleId)
        XCTAssertTrue(p.isValid)
        XCTAssertEqual(p.renderedSlots().count, 8)
    }

    func testRenderedSlotsPadGaps() {
        var p = RingProfile(name: "Sparse", slotCount: 8)
        p.addSlot(RingSlot(position: 0, label: "A", icon: "a.circle", action: .systemAction(.mute)))
        p.addSlot(RingSlot(position: 3, label: "B", icon: "b.circle", action: .systemAction(.mute)))
        let rendered = p.renderedSlots()
        XCTAssertEqual(rendered.count, 8)
        XCTAssertEqual(rendered[0].label, "A")
        XCTAssertFalse(rendered[1].hasAction)
        XCTAssertEqual(rendered[3].label, "B")
    }

    func testBuiltInProfilesHaveUniqueBundleIdsAndValidSlots() {
        let all = BuiltInProfiles.all
        XCTAssertFalse(all.isEmpty)
        let ids = all.compactMap { $0.bundleId }
        XCTAssertEqual(ids.count, Set(ids).count, "duplicate bundle ids in built-ins")
        for p in all {
            XCTAssertTrue(p.isValid, "\(p.name) invalid")
            XCTAssertLessThanOrEqual(p.slots.count, p.slotCount)
        }
    }
}
