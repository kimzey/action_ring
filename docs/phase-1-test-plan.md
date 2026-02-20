# Phase 1 Test Suite - TDD RED Phase Summary

## Status: RED (All Tests Failing)

The test suite has been written following TDD principles. All tests are currently failing because the implementation types do not exist yet. This is the expected state before moving to the GREEN phase.

## Test Files Created

### Core Geometry Tests (Existing)
- `Tests/MacRingCoreTests/RingGeometryTests.swift` - 29 tests for ring geometry math

### Profile Tests (New)
- `Tests/MacRingCoreTests/Profile/RingProfileTests.swift` - 30 tests for profile management
- `Tests/MacRingCoreTests/Profile/RingSlotTests.swift` - 20 tests for slot configuration
- `Tests/MacRingCoreTests/Profile/RingActionTests.swift` - 25 tests for action types

### Input Tests (New)
- `Tests/MacRingCoreTests/Input/EventTapManagerTests.swift` - 30 tests for mouse capture
- `Tests/MacRingCoreTests/Input/MouseButtonRecorderTests.swift` - 25 tests for button recording

### Execution Tests (New)
- `Tests/MacRingCoreTests/Execution/ActionExecutorTests.swift` - 30 tests for action execution
- `Tests/MacRingCoreTests/Execution/KeyboardSimulatorTests.swift` - 45 tests for keyboard simulation

## Total Test Count: ~234 tests

---

## Next Steps: TDD GREEN Phase

To implement Phase 1 and make tests pass, create the following files in order:

### 1. Core Types (Profile Layer)

#### `Sources/MacRingCore/Profile/RingAction.swift`
```swift
// All 13 action types
enum RingAction: Codable, Equatable {
    case keyboardShortcut(KeyCode, modifiers: [KeyModifier])
    case launchApplication(bundleIdentifier: String, url: URL?)
    case openURL(String)
    case systemAction(SystemAction)
    case shellScript(String)
    case appleScript(String)
    case shortcutsApp(String)
    case textSnippet(String)
    case openFile(String)
    case workflow([RingAction])
    case subRing(RingProfile)
    case mcpToolCall(MCPToolAction)
    case mcpWorkflow(MCPWorkflowAction)
}

struct KeyCode: Codable, Equatable {
    enum KeyType {
        case character(String)
        case special(SpecialKey)
    }
}

enum SpecialKey {
    case return, tab, space, delete, escape, upArrow, downArrow, leftArrow, rightArrow
    case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12
    case home, end, pageUp, pageDown
}

enum KeyModifier {
    case command, shift, option, control, capsLock, function
}

enum SystemAction {
    case lockScreen, screenshot, volumeUp, volumeDown, mute
    case brightnessUp, brightnessDown, missionControl, showDesktop
    case launchpad, notificationCenter, sleep, restart, shutdown
}

struct MCPToolAction: Codable {
    let serverId: String
    let toolName: String
    let parameters: [String: String]
    let displayName: String
}

struct MCPWorkflowAction: Codable {
    let steps: [MCPToolAction]
    let name: String
    let description: String
}
```

#### `Sources/MacRingCore/Profile/RingSlot.swift`
```swift
struct RingSlot: Codable, Identifiable {
    let id: UUID
    var position: Int
    var label: String
    var icon: String
    var action: RingAction?
    var isEnabled: Bool
    var color: Color?

    var isValid: Bool { ... }
    var isDisabled: Bool { !isEnabled }
}
```

#### `Sources/MacRingCore/Profile/RingProfile.swift`
```swift
struct RingProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    var bundleId: String?
    var category: AppCategory?
    var slots: [RingSlot]
    var slotCount: Int
    var isDefault: Bool
    var mcpServers: [String]
    var createdAt: Date
    var updatedAt: Date
    var source: ProfileSource

    var isValid: Bool { ... }

    static func createDefault() -> RingProfile { ... }
    func touch() { ... }

    mutating func addSlot(_ slot: RingSlot) { ... }
    mutating func removeSlot(at position: Int) { ... }
    mutating func updateSlot(at position: Int, with slot: RingSlot) { ... }
    func slotAt(position: Int) -> RingSlot? { ... }
}

enum AppCategory: String, Codable {
    case ide, browser, design, productivity, communication
    case media, development, terminal, other
}

enum ProfileSource: String, Codable {
    case builtin, user, ai, community, mcp
}
```

### 2. Input Layer

#### `Sources/MacRingCore/Input/EventTapManager.swift`
```swift
final class EventTapManager: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var isEnabled: Bool = false
    @Published var triggerButton: Int = 4
    var triggerButtons: [Int] = [4]
    var isRecording: Bool = false

    // Callbacks
    var onTriggerPressed: (() -> Void)?
    var onTriggerReleased: (() -> Void)?
    var onEventConsumed: (() -> Void)?
    var onEventPassedThrough: (() -> Void)?
    var onButtonRecorded: ((Int) -> Void)?

    func start() async throws { ... }
    func stop() async throws { ... }
    func enable() async throws { ... }
    func disable() async throws { ... }
    func startRecording() async throws { ... }
    func stopRecording() async throws { ... }

    func checkAccessibilityPermission() async -> Bool { ... }
    func requestAccessibilityPermission() async { ... }

    // For testing
    func simulateEvent(button: Int, type: EventType) async { ... }
}
```

#### `Sources/MacRingCore/Input/MouseButtonRecorder.swift`
```swift
final class MouseButtonRecorder: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recordedButton: Int?

    var timeout: Duration = .seconds(30)

    var onRecordingStarted: (() -> Void)?
    var onRecordingStopped: (() -> Void)?
    var onButtonRecorded: ((Int) -> Void)?
    var onRecordingTimedOut: (() -> Void)?

    func start() async throws { ... }
    func stop() async throws { ... }
    func reset() { ... }

    func buttonName(_ button: Int) -> String { ... }
    func isValidButton(_ button: Int) -> Bool { ... }

    // For testing
    func simulateButtonPress(_ button: Int, brand: String? = nil) async { ... }
}
```

### 3. Execution Layer

#### `Sources/MacRingCore/Execution/ActionExecutor.swift`
```swift
enum ActionExecutorError: Error {
    case notImplemented
    case invalidBundleId
    case invalidURL
    case executionFailed(underlying: Error)
}

final class ActionExecutor: ObservableObject {
    var onExecutionStarted: (() -> Void)?
    var onExecutionCompleted: (() -> Void)?
    var onExecutionError: ((Error) -> Void)?

    private(set) var lastExecutedAction: RingAction?
    private(set) var lastExecutionDuration: TimeInterval?

    func execute(_ action: RingAction) async throws { ... }
    func isActionImplemented(_ action: RingAction) async -> Bool { ... }
}
```

#### `Sources/MacRingCore/Execution/KeyboardSimulator.swift`
```swift
final class KeyboardSimulator {
    func pressKey(_ keyCode: KeyCode, modifiers: [KeyModifier]) async throws { ... }
    func keyDown(_ keyCode: KeyCode) async throws { ... }
    func keyUp(_ keyCode: KeyCode) async throws { ... }
    func pressModifierKey(_ modifier: KeyModifier, down: Bool) async throws { ... }
}
```

#### `Sources/MacRingCore/Execution/SystemActionRunner.swift`
```swift
final class SystemActionRunner {
    func execute(_ action: SystemAction) async throws { ... }
}
```

---

## Implementation Order (Dependency-Based)

1. **RingAction.swift** - Core type used everywhere
2. **RingSlot.swift** - Depends on RingAction
3. **RingProfile.swift** - Depends on RingSlot
4. **EventTapManager.swift** - Input capture (independent)
5. **MouseButtonRecorder.swift** - Button recording (independent)
6. **ActionExecutor.swift** - Execution dispatcher (depends on RingAction)
7. **KeyboardSimulator.swift** - Keyboard simulation (independent)
8. **SystemActionRunner.swift** - System actions (independent)
9. **RingGeometry.swift** - Already exists, needs implementation

---

## Running Tests

```bash
# Run all tests (should fail - RED phase)
swift test

# Run specific test suite
swift test --filter RingGeometryTests
swift test --filter RingProfileTests
swift test --filter EventTapManagerTests
swift test --filter ActionExecutorTests

# Run tests with coverage
swift test --enable-code-coverage
```

---

## Expected Test Output (RED Phase)

When running `swift test`, you should see:
- Compilation errors for undefined types
- Runtime errors from `fatalError("not implemented")` in RingGeometry
- 0 passing tests
- 234 failing tests

This confirms the RED phase is complete. The next phase (GREEN) involves implementing the types and methods to make tests pass.
