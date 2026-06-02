import XCTest
@testable import ActionRingCore

final class ProfileStoreTests: XCTestCase {

    private func tempStore() -> ProfileStore {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ActionRingTests-\(UUID().uuidString)", isDirectory: true)
        return ProfileStore(store: JSONStore(directory: dir))
    }

    func testResolutionChain() {
        let store = tempStore()

        let vscode = store.resolveProfile(forBundleId: "com.microsoft.VSCode", category: .ide)
        XCTAssertEqual(vscode.name, "VS Code")

        let unknownIDE = store.resolveProfile(forBundleId: "com.unknown.editor", category: .ide)
        XCTAssertEqual(unknownIDE.category, .ide)
        XCTAssertNil(unknownIDE.bundleId)

        let fallback = store.resolveProfile(forBundleId: "com.unknown.thing", category: .other)
        XCTAssertTrue(fallback.isDefault)
    }

    func testUserProfileOverridesBuiltIn() {
        let store = tempStore()
        var custom = BuiltInProfiles.vsCode
        custom.name = "My VS Code"
        custom.source = .user
        store.upsert(custom)

        let resolved = store.resolveProfile(forBundleId: "com.microsoft.VSCode", category: .ide)
        XCTAssertEqual(resolved.name, "My VS Code")
        XCTAssertEqual(resolved.source, .user)
    }

    func testPersistenceRoundTrip() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ActionRingTests-\(UUID().uuidString)", isDirectory: true)
        let jsonStore = JSONStore(directory: dir)

        let s1 = ProfileStore(store: jsonStore)
        var p = RingProfile(name: "Custom", bundleId: "com.test.app", category: .productivity)
        p.source = .user
        s1.upsert(p)
        s1.settings.triggerButton = 4
        s1.saveSettings()

        let s2 = ProfileStore(store: jsonStore)
        XCTAssertEqual(s2.settings.triggerButton, 4)
        XCTAssertTrue(s2.userProfiles.contains { $0.bundleId == "com.test.app" })

        try? FileManager.default.removeItem(at: dir)
    }
}
