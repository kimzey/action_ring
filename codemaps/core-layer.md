# MacRing -- Core Layer Codemap (Business Logic)

> **Last Updated:** 2026-02-21
> **Status:** Phase 1 Complete

---

## Directory Structure

```
Sources/MacRingCore/
├── Profile/                    ✅ COMPLETE
│   ├── RingAction.swift        (283 lines, 13 action types)
│   ├── RingSlot.swift          (85 lines)
│   └── RingProfile.swift       (178 lines)
│
├── Input/                      ✅ COMPLETE
│   └── EventTapManager.swift   (196 lines)
│
├── Context/                    ✅ COMPLETE
│   └── AppDetector.swift       (331 lines)
│
├── Execution/                  ✅ COMPLETE
│   └── ActionExecutor.swift    (315 lines)
│
├── UI/                         ✅ COMPLETE
│   ├── RingGeometry.swift      (145 lines)
│   ├── RingView/
│   │   └── RingView.swift      (174 lines)
│   ├── RingWindow.swift        (147 lines)
│   └── MenuBarIntegration.swift (143 lines)
│
├── App/                        Planned
├── AI/                         Planned
├── MCP/                        Planned
├── Semantic/                   Planned
└── Storage/                    Planned

Tests/MacRingCoreTests/
├── Profile/                    ✅ COMPLETE
│   ├── RingActionTests.swift   (289 lines, 28 tests)
│   ├── RingSlotTests.swift     (169 lines, 23 tests)
│   └── RingProfileTests.swift  (232 lines, 29 tests)
│
├── Input/                      ✅ COMPLETE
│   └── EventTapManagerTests.swift
│
├── Context/                    ✅ COMPLETE
│   └── AppDetectorTests.swift
│
├── Execution/                  ✅ COMPLETE
│   └── ActionExecutorTests.swift
│
└── RingGeometryTests.swift     ✅ COMPLETE (252 lines, 30 tests)
```

---

## Implemented Modules

### 1. Input Layer - EventTapManager

**File:** `Input/EventTapManager.swift` (196 lines)

**Purpose:** Universal mouse button capture via CGEventTap

**Key Types:**
```swift
public enum EventTapEventType: Sendable {
    case down, up, drag, cancel
}

public enum EventTapAction: Sendable {
    case passEvent, suppress
}

public final class EventTapManager: @unchecked Sendable {
    public let buttonNumber: Int     // 0-31 (default: 3)
    public var isEnabled: Bool
    public var onEvent: ((EventTapEventType) -> EventTapAction)?
}
```

**Key Methods:**
- `enable() -> Bool` - Start monitoring (returns false if no accessibility)
- `disable()` - Stop monitoring
- `hasAccessibilityPermissions() -> Bool` - Static check
- `promptAccessibilityPermissions()` - Show system prompt

**Dependencies:** `Foundation`, `AppKit`, `Quartz/CGEvent`

---

### 2. Context Layer - AppDetector

**File:** `Context/AppDetector.swift` (331 lines)

**Purpose:** Detect focused app, determine category, monitor app switches

**Key Types:**
```swift
public struct RunningApp: Sendable {
    let bundleIdentifier: String
    let appName: String
    let processIdentifier: pid_t
}

public final class AppDetector {
    // 100+ bundle ID -> category mappings
    private let categoryMappings: [String: AppCategory]
}
```

**Key Methods:**
- `focusedAppBundleId() async -> String?` - Current app bundle ID
- `focusedAppName() async -> String?` - Current app name
- `category(forBundleId:) -> AppCategory` - Category lookup
- `runningApps() async -> [RunningApp]` - All running apps
- `isCurrentAppFullscreen() async -> Bool` - Fullscreen check

**Monitoring:**
- `startMonitoring(callback: @escaping (String?) -> Void) async -> UUID`
- `startMonitoringFullscreen(callback: @escaping (Bool) -> Void) async -> UUID`
- `stopMonitoring(token: UUID) async`

**Dependencies:** `Foundation`, `AppKit/NSWorkspace`

---

### 3. Execution Layer - ActionExecutor

**File:** `Execution/ActionExecutor.swift` (315 lines)

**Purpose:** Execute all ring action types

**Key Types:**
```swift
public enum ActionExecutorError: Error, Sendable {
    case notImplemented
    case appNotFound(bundleId: String)
    case invalidUrl(url: String)
    case executionFailed(reason: String)
}

public enum ActionExecutorResult: Sendable {
    case success, failure(ActionExecutorError)
}

public final class ActionExecutor {
    public func execute(_ action: RingAction) async -> ActionExecutorResult
}
```

**Supported Actions (Phase 1):**
- `keyboardShortcut` - ✅ CGEvent simulation
- `launchApplication` - ✅ NSWorkspace
- `openURL` - ✅ NSWorkspace
- `systemAction` - ✅ Partial implementation
- `workflow` - ✅ Sequential execution

**Stub Actions (Return notImplemented):**
- `shellScript`, `appleScript`, `shortcutsApp`, `textSnippet`, `openFile`
- `mcpToolCall`, `mcpWorkflow`

**Dependencies:** `Foundation`, `AppKit`, `Carbon`

---

### 4. Profile Layer (Data Models)

**Files:**
- `RingAction.swift` (283 lines) - 13 action types
- `RingSlot.swift` (85 lines) - Slot configuration
- `RingProfile.swift` (178 lines) - Profile container

**See:** [profile.md](profile.md) for detailed documentation

---

## Module Dependencies

```
Input (EventTapManager)
  ├─> notifications ──> Context (AppDetector)
  └─> cursor position ──> UI (RingGeometry)

Context (AppDetector)
  ├─> bundle ID ──> Profile (lookup)
  └─> app info ──> AI (planned)

Profile (RingProfile)
  ├─> slots ──> UI (RingView)
  └─> actions ──> Execution (ActionExecutor)

Execution (ActionExecutor)
  └─> MCP actions ──> MCP (planned)

UI (RingView/RingWindow)
  └─> slot selection ──> Execution (ActionExecutor)
```

---

## Thread Safety

| Module | Thread Model | Notes |
|--------|--------------|-------|
| EventTapManager | `.userInteractive` | CGEventTap callback |
| AppDetector | `.main` | NSWorkspace requires main |
| ActionExecutor | `.utility` | Async execution |
| Profile models | `Sendable` | Value types, thread-safe |

---

## Data Flows

### Ring Trigger → Action Execution
```
EventTapManager (otherMouseDown)
  → RingWindow.show(at: cursorPosition)
  → RingView renders slots
  → User moves to slot (RingGeometry.selectedSlot)
  → EventTapManager (otherMouseUp)
  → ActionExecutor.execute(slot.action)
```

### App Switch → Profile Update (Planned)
```
AppDetector (NSWorkspace notification)
  → ContextEngine.handleAppSwitch(bundleId)
  → ProfileManager.lookup(bundleId) -- 4-step chain
  → MCPRegistry.relevantServers(bundleId)
  → RingView.updateProfile(newProfile)
```

---

## Related Codemaps

- [architecture.md](architecture.md) -- Overall system architecture
- [profile.md](profile.md) -- Profile system details
- [ui.md](ui.md) -- UI components
