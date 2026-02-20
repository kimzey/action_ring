# Execution Layer Codemap

**Last Updated:** 2025-02-21

## Overview

The Execution layer handles action execution. It provides a unified interface for executing 13 different action types, from keyboard shortcuts to shell scripts. The layer consists of two main components: ActionExecutor (action dispatcher) and ScriptRunner (safe script execution).

## Public Types

### ActionExecutor
```swift
public final class ActionExecutor
    - init(scriptOptions: ScriptExecutionOptions = ScriptExecutionOptions())
    - execute(_ action: RingAction) async -> ActionExecutorResult
    - executeWorkflow(_ actions: [RingAction]) async -> ActionExecutorResult
```

### ActionExecutorResult
```swift
public enum ActionExecutorResult: Sendable
    case success
    case failure(ActionExecutorError)

    var isSuccess: Bool
    var isFailure: Bool
```

### ActionExecutorError
```swift
public enum ActionExecutorError: Error, Equatable, Sendable
    case notImplemented
    case appNotFound(bundleId: String)
    case invalidUrl(url: String)
    case executionFailed(reason: String)
    case systemActionNotSupported(action: String)
    case scriptValidationFailed(reason: String)
    case scriptTimeout
```

### ScriptRunner
```swift
public final class ScriptRunner: Sendable
    - init(timeout: TimeInterval = 30, workingDirectory: String?, environment: [String: String]?)
    - runShell(script: String) async -> ScriptResult
    - runAppleScript(script: String) async -> ScriptResult
    - validateShellScript(_ script: String) async -> ScriptValidationResult
    - runBatch(scripts: [String]) async -> [ScriptResult]
```

### ScriptResult
```swift
public struct ScriptResult: Sendable
    let output: String
    let error: String
    let exitCode: Int32
    let didTimeout: Bool
    let duration: TimeInterval

    var isSuccess: Bool
```

### ScriptValidationResult
```swift
public struct ScriptValidationResult: Sendable
    let isValid: Bool
    let error: String
```

### ScriptExecutionOptions
```swift
public struct ScriptExecutionOptions: Sendable
    var timeout: TimeInterval = 30
    var workingDirectory: String?
    var environment: [String: String]?
```

## Dependencies

### Internal Dependencies
```
ActionExecutor
  -> ScriptRunner
  -> RingAction (all 13 variants)

ScriptRunner
  -> (none, standalone)
```

### External Dependencies
- **Foundation:** Process, FileManager, URL
- **AppKit:** NSWorkspace, NSAppleScript, NSRunningApplication
- **CoreGraphics:** CGEvent, CGEventSource (for keyboard events)
- **Carbon:** Virtual key code constants

## Action Type Support

### Local Actions (11)

| Action | Implementation Method |
|--------|----------------------|
| `.keyboardShortcut` | CGEvent keyboard events with modifiers |
| `.launchApplication` | NSWorkspace.launchApplication or activate |
| `.openURL` | NSWorkspace.open(URL) |
| `.systemAction` | Varies by action (CGEvent, NSAppleScript, URLs) |
| `.shellScript` | Process.executableURL = /bin/sh |
| `.appleScript` | NSAppleScript.executeAndReturnError |
| `.shortcutsApp` | NSAppleScript to "Shortcuts Events" |
| `.textSnippet` | CGEvent keyboard events (character-by-character) |
| `.openFile` | NSWorkspace.open(fileURL) |
| `.workflow` | Recursive execute() for nested actions |

### MCP Actions (2 - Not Implemented)
- `.mcpToolCall` - Returns `.failure(.notImplemented)`
- `.mcpWorkflow` - Returns `.failure(.notImplemented)`

## Key Flows

### Keyboard Shortcut Execution
```
ActionExecutor.execute(.keyboardShortcut)
    |
    v
Create CGEventSource(.hidSystemState)
    |
    v
Create keyDown and keyUp CGEvents
    |
    v
Map modifiers to CGEventFlags:
    - .command -> .maskCommand
    - .shift -> .maskShift
    - .option -> .maskAlternate
    - .control -> .maskControl
    |
    v
Map KeyCode to virtual key code:
    - Character: a-z = 0-25, 0-9 = 29-38
    - Special: Enter=36, Tab=48, Space=49, F1-F12 mapped
    |
    v
Post events to .cghidEventTap
    |
    v
Return .success
```

### Shell Script Execution
```
ActionExecutor.execute(.shellScript)
    |
    v
ScriptRunner.validateShellScript
    |
    v
Check dangerous patterns:
    - "rm -rf /" variants
    - "dd if=/dev/zero" variants
    - Fork bomb ":(){ :|:& };:"
    - "chmod 777" combinations
    |
    v
ScriptRunner.runShell
    |
    v
Create Process with:
    - executableURL: /bin/sh
    - arguments: ["-c", script]
    - workingDirectory: (optional)
    - environment: (merged with system)
    |
    v
Set up timeout task (default 30s)
    |
    v
Run process, capture stdout/stderr
    |
    v
Wait for exit or timeout
    |
    v
Return ScriptResult
```

### Application Launch
```
ActionExecutor.execute(.launchApplication)
    |
    v
NSWorkspace.shared.runningApplications
    |
    v
Check if already running:
    - YES -> app.activate(options: [.activateIgnoringOtherApps])
    - NO -> NSWorkspace.launchApplication
    |
    v
Return .success or .appNotFound
```

### System Action Execution

| System Action | Implementation |
|---------------|----------------|
| `.lockScreen` | Open system preferences URL |
| `.screenshot` | CGEvent keyboard (F1) |
| `.volumeUp/.volumeDown` | CGEvent keyboard (Arrow keys) |
| `.mute` | CGEvent keyboard (Shift+M) |
| `.brightnessUp/.brightnessDown` | CGEvent keyboard (Arrow keys) |
| `.missionControl` | CGEvent keyboard (Ctrl+Space) |
| `.showDesktop` | CGEvent keyboard (F11) |
| `.launchpad` | CGEvent keyboard (L) |
| `.sleep` | Open system preferences URL |
| `.restart/.shutdown` | NSAppleScript "System Events" |

## Dangerous Pattern Detection

ScriptRunner blocks scripts containing these patterns:

| Pattern | Reason |
|---------|--------|
| `rm -rf /` | System destruction |
| `rm -Rf ~` | Home directory destruction |
| `rm -rf /usr`, `/bin`, `/sbin`, `/etc`, `/var`, `/System` | Critical directories |
| `dd if=/dev/zero`, `/dev/random`, `/dev/urandom` | Disk wiping |
| `:(){ :|:& };:` | Fork bomb |
| `mv / ~/.` | Root directory move |
| `mkfs`, `format c:`, `del /q /s` | Filesystem destruction |
| `chmod 777` | Insecure permissions (when combined) |

## Virtual Key Code Mapping

### Character Keys
| Range | Mapping |
|-------|---------|
| a-z (97-122) | 0-25 |
| 0-9 (48-57) | 29-38 |

### Special Keys
| Key | Code | Key | Code |
|-----|------|-----|------|
| Enter | 36 | Delete | 51 |
| Tab | 48 | Home | 115 |
| Space | 49 | End | 119 |
| Escape | 53 | Page Up | 116 |
| F1 | 122 | Page Down | 121 |
| F2 | 120 | Left Arrow | 123 |
| F3 | 99 | Right Arrow | 124 |
| F4 | 118 | Up Arrow | 126 |
| F5 | 96 | Down Arrow | 125 |
| F6 | 97 | F7 | 98 |
| F8 | 100 | F9 | 101 |
| F10 | 109 | F11 | 103 |
| F12 | 111 | | |

## Workflow Execution

Workflows execute actions sequentially. If any action fails, execution stops:

```swift
ActionExecutor.executeWorkflow([
    .keyboardShortcut(.character("a"), modifiers: [.command]),  // Select All
    .keyboardShortcut(.character("c"), modifiers: [.command]),  // Copy
    .launchApplication(bundleIdentifier: "com.apple.Notes"),    // Switch app
    .keyboardShortcut(.character("v"), modifiers: [.command]),  // Paste
])
```

Nested workflows are supported (workflow containing workflow).

## Constants

- **Default Script Timeout:** 30 seconds
- **Key Stroke Delay:** 10ms (for textSnippet)
- **CGEvent Source:** `.hidSystemState`
- **CGEvent Tap:** `.cghidEventTap`

## Error Handling

All execution paths return `ActionExecutorResult`:

```swift
switch result {
case .success:
    // Action completed successfully
case .failure(let error):
    switch error {
    case .scriptTimeout:
        // Script ran longer than timeout
    case .appNotFound(let bundleId):
        // Could not find or launch app
    case .invalidUrl(let url):
        // URL parsing failed
    case .executionFailed(let reason):
        // General execution failure
    // ... other cases
    }
}
```

## Related Areas

- [profile.md](profile.md) - RingAction type definitions
- [architecture.md](architecture.md) - Overall architecture
- [context.md](context.md) - Context-aware profile switching
