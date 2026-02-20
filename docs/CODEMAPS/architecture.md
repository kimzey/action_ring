# MacRing Architecture Codemap

**Last Updated:** 2025-02-21

## Overview

MacRing follows a layered architecture with clear separation of concerns. The system is designed around three core responsibilities: input capture, context awareness, and action execution.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                            User Interaction                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │ Menu Bar Icon │  │ Ring Window  │  │ Configurator (Future)    │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────────────────────┘  │
└─────────┼──────────────────┼────────────────────────────────────────┘
          │                  │
┌─────────┼──────────────────┼────────────────────────────────────────┐
│         │         Input Layer        │                                │
│  ┌──────▼──────────────────────▼────┐                                │
│  │     EventTapManager              │  CGEventTap-based mouse capture│
│  │  - Brand-agnostic button detect  │  - Accessibility required      │
│  │  - Event suppression/pass-thru   │  - Button 3-4 typical          │
│  └──────┬───────────────────────────┘                                │
└─────────┼────────────────────────────────────────────────────────────┘
          │
┌─────────┼────────────────────────────────────────────────────────────┐
│         │      Context Layer                                          │
│  ┌──────▼──────────────────────────────────┐                         │
│  │     ContextEngine                        │  Profile switching      │
│  │  - App switch detection                 │  - Debounced (500ms)    │
│  │  - Profile lookup chain                 │  - 4-tier fallback      │
│  └──────┬──────────────────────────────────┘                         │
│         │                                                                  │
│  ┌──────▼────────────────────┐  ┌──────────────────────────────────┐  │
│  │   AppDetector              │  │   FullscreenDetector             │  │
│  │  - 150+ app mappings       │  │  - Game detection               │  │
│  │  - 9 categories            │  │  - Blacklist/whitelist           │  │
│  │  - NSWorkspace monitoring  │  │  - CGWindowListCopyWindowInfo   │  │
│  └────────────────────────────┘  └──────────────────────────────────┘  │
└─────────┼────────────────────────────────────────────────────────────┘
          │
┌─────────┼────────────────────────────────────────────────────────────┐
│         │      Profile Layer                                           │
│  ┌──────▼──────────────────────────────────┐                         │
│  │     RingProfile                          │  Profile data model     │
│  │  - 4, 6, or 8 slots                     │  - Codable, Sendable    │
│  │  - Bundle ID or category                │  - Source tracking      │
│  │  - MCP server associations              │  - Timestamps           │
│  └──────┬──────────────────────────────────┘                         │
│         │                                                                  │
│  ┌──────▼──────────────────────────────────┐                         │
│  │     BuiltInProfiles                      │  10 built-in presets   │
│  │  - VS Code, Xcode, Safari               │  - IDE, Browser, etc.  │
│  │  - Finder, Terminal, Notes              │  - Category fallbacks  │
│  └─────────────────────────────────────────┘                         │
└─────────┼────────────────────────────────────────────────────────────┘
          │
┌─────────┼────────────────────────────────────────────────────────────┐
│         │      Execution Layer                                         │
│  ┌──────▼──────────────────────────────────┐                         │
│  │     ActionExecutor                       │  Action dispatcher      │
│  │  - 11 local action types                │  - CGEvent keyboard     │
│  │  - 2 MCP types (stubbed)                │  - NSWorkspace launch   │
│  │  - Workflow nesting support             │  - Process scripts      │
│  └──────┬──────────────────────────────────┘                         │
│         │                                                                  │
│  ┌──────▼──────────────────────────────────┐                         │
│  │     ScriptRunner                         │  Safe script execution  │
│  │  - Shell scripts (via Process)          │  - Timeout (30s default)│
│  │  - AppleScript (via NSAppleScript)      │  - Dangerous pattern    │
│  │  - Batch execution                      │    detection            │
│  └─────────────────────────────────────────┘                         │
└─────────────────────────────────────────────────────────────────────┘
```

## Layer Responsibilities

### Input Layer
- **EventTapManager:** Captures mouse button events via CGEventTap
- Works with any mouse brand (Logitech, Razer, generic, etc.)
- Returns `.passEvent` or `.suppress` for each event

### Context Layer
- **AppDetector:** Detects focused app, maps to categories
- **ContextEngine:** Orchestrates profile switching on app changes
- **FullscreenDetector:** Detects fullscreen apps for behavior adjustment

### Profile Layer
- **RingProfile:** Core profile data model
- **RingSlot:** Individual slot configuration
- **RingAction:** Action type definitions (13 total)
- **BuiltInProfiles:** Predefined profiles for common apps

### Execution Layer
- **ActionExecutor:** Dispatches actions to appropriate handlers
- **ScriptRunner:** Safely executes shell and AppleScripts

### UI Layer
- **RingView:** SwiftUI ring rendering
- **RingWindow:** Floating panel window
- **MenuBarIntegration:** Menu bar icon and menu
- **RingGeometry:** Trigonometric calculations for slot positioning

## Data Flow

### Profile Switch Flow
```
App Switch
  -> NSWorkspace.didActivateApplicationNotification
  -> AppDetector.startMonitoring callback
  -> ContextEngine.handleAppSwitch
  -> Debounce (500ms)
  -> Profile lookup chain:
       1. Exact bundle ID
       2. MCP discovery (future)
       3. Category fallback
       4. Default profile
  -> ContextEngine.notifyProfileChange
  -> UI update
```

### Action Execution Flow
```
User selects slot
  -> RingWindow.selectedSlot update
  -> RingSlot.action retrieval
  -> ActionExecutor.execute
  -> Route to handler:
       - Keyboard: CGEvent keyboard events
       - App launch: NSWorkspace.launchApplication
       - URL: NSWorkspace.open
       - Script: ScriptRunner.runShell/runAppleScript
       - System: Direct CGEvent or NSAppleScript
  -> Return ActionExecutorResult (success/failure)
```

## Threading Model

| Thread | QoS | Components |
|--------|-----|------------|
| Main | .userInteractive | SwiftUI, NSWorkspace observers |
| EventTap | .userInteractive | CGEventTap callback |
| Callback Queue | .userInitiated | AppDetector, ContextEngine, FullscreenDetector |
| Script | .utility | Process execution (ScriptRunner) |

## Dependencies

### External Frameworks
- **AppKit:** NSWorkspace, NSRunningApplication, NSPanel, NSStatusItem
- **CoreGraphics:** CGEventTap, CGEvent, CGEventSource
- **Carbon:** Keyboard event constants
- **SwiftUI:** RingView (macOS 14.0+)

### Internal Dependencies

```
EventTapManager
  -> (none)

AppDetector
  -> (none)

ContextEngine
  -> AppDetector
  -> RingProfile (ProfileProvider protocol)

FullscreenDetector
  -> AppDetector (for category mapping)

ActionExecutor
  -> ScriptRunner
  -> RingAction (all variants)

ScriptRunner
  -> (none)

RingView
  -> RingGeometry
  -> RingSlot

RingWindow
  -> RingView
  -> RingGeometry
  -> RingSlot

MenuBarIntegration
  -> (none)
```

## State Management

### Actor-Based Isolation
- **ContextEngine.State:** Current bundle ID, debounce state, callbacks
- **FullscreenDetector.State:** Fullscreen status, blacklist/whitelist, callbacks

### Thread-Safety Patterns
- All public types conform to `Sendable`
- EventTapManager uses `@unchecked Sendable` (CGEventTap is thread-safe)
- Callbacks use dedicated dispatch queues

## Extension Points

### Future Integrations
1. **AI Layer** (not yet implemented)
   - Claude API for smart suggestions
   - Auto-profile generation

2. **MCP Layer** (not yet implemented)
   - mcp-swift-sdk integration
   - Tool discovery and execution

3. **Database Layer** (not yet implemented)
   - GRDB.swift for profile persistence
   - Vector store for semantic search

4. **Semantic Layer** (not yet implemented)
   - NLEmbedding for behavior patterns
   - k-NN clustering for suggestions
