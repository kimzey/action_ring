# Context Layer Codemap

**Last Updated:** 2025-02-21

## Overview

The Context layer provides app-aware profile switching. It detects which application is currently focused and automatically switches to the appropriate ring profile. The layer consists of three main components: AppDetector, ContextEngine, and FullscreenDetector.

## Public Types

### AppDetector
```swift
public struct RunningApp: Sendable
    - bundleIdentifier: String
    - appName: String
    - processIdentifier: pid_t

public final class AppDetector
    - focusedAppBundleId() async -> String?
    - focusedAppName() async -> String?
    - category(forBundleId: String) -> AppCategory
    - runningApps() async -> [RunningApp]
    - startMonitoring(callback: @escaping (String?) -> Void) async -> UUID
    - stopMonitoring(token: UUID) async
    - startMonitoringFullscreen(callback: @escaping (Bool) -> Void) async -> UUID
    - isCurrentAppFullscreen() async -> Bool
```

### ContextEngine
```swift
public protocol ProfileProvider: Sendable
    - profile(forBundleId: String) async -> RingProfile?
    - profile(forCategory: AppCategory) async -> RingProfile?
    - default() async -> RingProfile?

public final class ContextEngine: Sendable
    - currentBundleId() async -> String?
    - category(forBundleId: String) -> AppCategory
    - profileForBundleId(_:profileManager:) async -> RingProfile?
    - handleAppSwitch(bundleId:profileManager:) async -> RingProfile?
    - startMonitoring(callback:) async -> UUID
    - stopMonitoring(token: UUID) async
    - startMonitoringAppSwitches(profileManager:callback:) async -> UUID
```

### FullscreenDetector
```swift
public enum AppType: Equatable, Sendable
    - game, browser, media, ide, terminal, productivity, other

public struct FullscreenWindowInfo: Sendable
    - bundleId: String
    - appName: String
    - bounds: CGRect
    - appType: AppType

public final class FullscreenDetector
    - isFullscreenActive: Bool { async get }
    - fullscreenApps: [String] { async get }
    - checkFullscreen(_ windows: [[String: Any]]) async -> Bool
    - listFullscreenApps(_ windows: [[String: Any]]) async -> [String]
    - appType(forBundleId: String) async -> AppType
    - addToBlacklist(_ bundleId: String) async
    - removeFromBlacklist(_ bundleId: String) async
    - clearBlacklist() async
    - addToWhitelist(_ bundleId: String) async
    - removeFromWhitelist(_ bundleId: String) async
```

## Dependencies

### Internal Dependencies
```
AppDetector
  -> (none, standalone)

ContextEngine
  -> AppDetector
  -> RingProfile (via ProfileProvider protocol)

FullscreenDetector
  -> AppDetector (for category mapping only)
```

### External Dependencies
- **Foundation:** Core types, async/await
- **AppKit:** NSWorkspace, NSRunningApplication
- **CoreGraphics:** CGRect, CGWindowListCopyWindowInfo

## App Category Mappings

### Supported Categories
| Category | Description | Example Apps |
|----------|-------------|--------------|
| `.ide` | Integrated Development Environments | VS Code, Xcode, IntelliJ |
| `.browser` | Web Browsers | Safari, Chrome, Firefox |
| `.design` | Design & Creative Tools | Figma, Photoshop, Sketch |
| `.productivity` | Office & Productivity | Notes, Word, Excel |
| `.communication` | Messaging & Communication | Slack, Discord, Zoom |
| `.media` | Media Players | Spotify, VLC, Apple Music |
| `.development` | Development Tools | GitHub Desktop, Postman |
| `.terminal` | Terminal Emulators | Terminal, iTerm2, Warp |
| `.other` | Uncategorized | Finder, System Preferences |

### Mapped Bundle IDs (150+)

**IDEs (15+):** com.apple.dt.Xcode, com.microsoft.VSCode, com.jetbrains.intellij, com.sublimetext.4, io.vscode, org.eclipse.ide

**Browsers (10+):** com.apple.Safari, com.google.Chrome, org.mozilla.firefox, com.microsoft.edgemac, com.brave.Browser, org.torproject.torbrowser

**Design (15+):** com.figma.Desktop, com.adobe.Photoshop, com.adobe.Illustrator, com.sketch.sketch, com.blenderfoundation.blender

**Productivity (10+):** com.microsoft.Word, com.apple.iWork.Pages, notion.id, xyz.obsidian.Obsidian, com.apple.Notes

**Communication (8+):** us.zoom.Zoom, com.hnc.Discord, com.slack.Slack, org.telegram.TelegramDesktop

**Media (5+):** com.spotify.client, com.apple.Music, org.videolan.vlc

**Terminal (7+):** com.apple.Terminal, com.googlecode.iterm2, com.warp.Warp-Stable, net.kovidgoyal.kitty

## Key Flows

### Profile Lookup Chain
```
1. Exact Bundle ID Match
   -> profileManager.profile(forBundleId: bundleId)

2. MCP Discovery (Future)
   -> TODO: Query MCP registry

3. Category Fallback
   -> appDetector.category(forBundleId: bundleId)
   -> profileManager.profile(forCategory: category)

4. Default Profile
   -> profileManager.default()
```

### App Switch Detection Flow
```
NSWorkspace.didActivateApplicationNotification
    |
    v
AppDetector.workspaceObserver callback
    |
    v
AppDetector.monitoringCallbacks (all registered)
    |
    v
ContextEngine.handleAppSwitch
    |
    v
[Debounce Check] -> Is same app? Skip
    |
    v
[Debounce] -> Sleep 500ms (default)
    |
    v
profileForBundleId -> Profile lookup chain
    |
    v
ContextEngine.profileChangeCallbacks
```

### Fullscreen Detection Flow
```
CGWindowListCopyWindowInfo
    |
    v
FullscreenDetector.detectFullscreenWindows
    |
    v
Filter: Skip blacklisted, check isOnscreen
    |
    v
Check bounds: == screen bounds (10px tolerance)
    |
    v
Classify: Game pattern or AppDetector category
    |
    v
Update state & notify callbacks
```

## ProfileProvider Protocol

The `ProfileProvider` protocol enables dependency injection for profile lookup. `RingProfile` conforms to this protocol, allowing direct profile-to-profile matching:

```swift
extension RingProfile: ProfileProvider {
    func profile(forBundleId bundleId: String) async -> RingProfile? {
        if self.bundleId == bundleId { return self }
        return nil
    }

    func profile(forCategory category: AppCategory) async -> RingProfile? {
        if self.category == category && self.bundleId == nil { return self }
        return nil
    }

    func default() async -> RingProfile? {
        if self.isDefault { return self }
        return nil
    }
}
```

## State Management

### ContextEngine.State (Actor)
```swift
actor State {
    var currentBundleId: String?
    var lastSwitchTime: Date?
    var pendingBundleId: String?
    var monitoringCallbacks: [UUID: ProfileChangeCallback]
    var debounceTask: Task<Void, Never>?
}
```

### FullscreenDetector.State (Actor)
```swift
actor State {
    var isFullscreenActive: Bool
    var fullscreenApps: Set<String>
    var blacklist: Set<String>
    var whitelist: Set<String>
    var monitoringCallbacks: [UUID: FullscreenChangeCallback]
    var lastCheckTime: Date?
}
```

## Callback Management

Both AppDetector and FullscreenDetector use UUID-based callback registration:

```swift
// Start monitoring
let token = await appDetector.startMonitoring { bundleId in
    print("Switched to: \(bundleId ?? "unknown")")
}

// Stop monitoring
await appDetector.stopMonitoring(token: token)

// Stop all
await appDetector.stopMonitoring()
```

## Constants

- **Debounce Interval:** 500ms (configurable via ContextEngine init)
- **Fullscreen Tolerance:** 10 pixels
- **Game Bundle Patterns:** 15+ patterns (Steam, Blizzard, Epic, Ubisoft, etc.)
- **Media Blacklist:** VLC, QuickTime, Apple TV, Netflix

## Related Areas

- [profile.md](profile.md) - Profile data models and built-in profiles
- [architecture.md](architecture.md) - Overall architecture and layer relationships
- [ui.md](ui.md) - UI components that consume context changes
