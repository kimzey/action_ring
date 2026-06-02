import Foundation
import ActionRingCore

// A tiny, dependency-free invariant checker so the core logic can be verified
// with `swift run ARCheck` where XCTest/Testing aren't installed (CLT-only).
// Mirrors the assertions in Tests/ActionRingCoreTests.

final class Checker {
    var passed = 0
    var failed = 0

    func check(_ name: String, _ condition: @autoclosure () -> Bool) {
        if condition() {
            passed += 1
        } else {
            failed += 1
            print("  ✗ FAIL: \(name)")
        }
    }

    func summary() -> Int32 {
        print("\n\(failed == 0 ? "✅" : "❌")  \(passed) passed, \(failed) failed")
        return failed == 0 ? 0 : 1
    }
}

let c = Checker()

// MARK: Geometry
let geo = RingGeometry(size: .medium, slotCount: 8)
c.check("dead zone → nil", geo.selectedSlot(for: .zero) == nil)
c.check("slot 0 = right", geo.selectedSlot(for: CGPoint(x: 100, y: 0)) == 0)
c.check("slot 2 = up", geo.selectedSlot(for: CGPoint(x: 0, y: 100)) == 2)
c.check("slot 4 = left", geo.selectedSlot(for: CGPoint(x: -100, y: 0)) == 4)
c.check("slot 6 = down", geo.selectedSlot(for: CGPoint(x: 0, y: -100)) == 6)
c.check("all centers in band", (0..<8).allSatisfy { geo.isInRingArea(point: geo.slotCenter(for: $0)) })

// MARK: Selectable-slot (the highlight/fire source of truth)
let fullSlots = BuiltInProfiles.vsCode.slots
c.check("selectable: right → 0", geo.selectableSlot(for: CGPoint(x: 100, y: 0), in: fullSlots) == 0)
c.check("selectable: dead zone → nil", geo.selectableSlot(for: .zero, in: fullSlots) == nil)
var sparse = RingProfile(name: "Sparse", slotCount: 8)
sparse.addSlot(RingSlot(position: 2, label: "Up", icon: "x", action: .systemAction(.mute)))
let sparseSlots = sparse.renderedSlots()
c.check("selectable: empty slot → nil", geo.selectableSlot(for: CGPoint(x: 100, y: 0), in: sparseSlots) == nil)
c.check("selectable: action slot → index", geo.selectableSlot(for: CGPoint(x: 0, y: 100), in: sparseSlots) == 2)

// MARK: KeyCode map (the non-alphabetical ANSI layout)
c.check("a = 0", KeyCodeMap.letters["a"] == 0)
c.check("s = 1", KeyCodeMap.letters["s"] == 1)
c.check("b = 11 (not 1)", KeyCodeMap.letters["b"] == 11)
c.check("digit 6 = 22 (not 24)", KeyCodeMap.digits["6"] == 22)
c.check("uppercase implies shift", KeyCodeMap.resolve(.character("A"))?.needsShift == true)
c.check("off-layout char → nil", KeyCodeMap.resolve(.character("✓")) == nil)

// MARK: Profiles & lookup
c.check("default valid + full", RingProfile.createDefault().isValid && RingProfile.createDefault().renderedSlots().count == 8)
let builtinIds = BuiltInProfiles.all.compactMap { $0.bundleId }
c.check("no duplicate built-in bundle ids", builtinIds.count == Set(builtinIds).count)
c.check("all built-ins valid", BuiltInProfiles.all.allSatisfy { $0.isValid })

let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ARCheck-\(UUID().uuidString)", isDirectory: true)
let store = ProfileStore(store: JSONStore(directory: dir))
c.check("exact match → VS Code", store.resolveProfile(forBundleId: "com.microsoft.VSCode", category: .ide).name == "VS Code")
c.check("unknown IDE → category fallback", store.resolveProfile(forBundleId: "com.x.y", category: .ide).bundleId == nil)
c.check("unknown other → default", store.resolveProfile(forBundleId: "com.x.y", category: .other).isDefault)

// Persistence round-trip
store.settings.triggerButton = 4
store.saveSettings()
let store2 = ProfileStore(store: JSONStore(directory: dir))
c.check("settings persist", store2.settings.triggerButton == 4)
try? FileManager.default.removeItem(at: dir)

// Disabling an app profile falls back to the category default.
let dir2 = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ARCheck-\(UUID().uuidString)", isDirectory: true)
let store3 = ProfileStore(store: JSONStore(directory: dir2))
store3.setEnabled(BuiltInProfiles.vsCode, false)   // materialize a disabled override
let disabledResolve = store3.resolveProfile(forBundleId: "com.microsoft.VSCode", category: .ide)
c.check("disabled app profile → category fallback", disabledResolve.bundleId == nil && disabledResolve.category == .ide)
store3.setEnabled(disabledResolve, true)           // re-enabling a fallback shouldn't crash
try? FileManager.default.removeItem(at: dir2)

// MARK: Codable round-trips
do {
    let actions: [RingAction] = [
        .keyboardShortcut(.character("c"), modifiers: [.command]),
        .keyboardShortcut(.special(.f5), modifiers: [.command, .shift]),
        .systemAction(.screenshotArea),
        .workflow([.systemAction(.mute), .openURL("https://a.b")]),
    ]
    var ok = true
    for a in actions {
        let back = try JSONDecoder().decode(RingAction.self, from: JSONEncoder().encode(a))
        if back != a { ok = false }
    }
    c.check("RingAction Codable round-trips", ok)
} catch {
    c.check("RingAction Codable round-trips", false)
}

// MARK: Async — script safety + execution + MCP stubs
@MainActor func asyncChecks() async {
    let runner = ScriptRunner(timeout: 5)
    c.check("rejects rm -rf /", !runner.validateShellScript("rm -rf /").isValid)
    c.check("rejects fork bomb", !runner.validateShellScript(":(){ :|:& };:").isValid)
    c.check("allows echo", runner.validateShellScript("echo hi").isValid)

    let result = await runner.runShell(script: "echo action-ring")
    c.check("shell captures output", result.isSuccess && result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "action-ring")

    let exec = ActionExecutor()
    let mcp = RingAction.mcpToolCall(MCPToolAction(serverId: "x", toolName: "t", parameters: [:], displayName: "d"))
    let mcpResult = await exec.execute(mcp)
    c.check("MCP → notImplemented", mcpResult == .failure(.notImplemented))
}

await asyncChecks()
exit(c.summary())
