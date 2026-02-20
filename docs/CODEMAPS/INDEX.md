# MacRing Codemap Index

**Last Updated:** 2025-02-21

## Overview

MacRing is a native macOS application that transforms any multi-button mouse into a context-aware radial command ring. The codemaps in this directory document the architectural structure of the Swift implementation.

## Codemap Files

| File | Description |
|------|-------------|
| [architecture.md](architecture.md) | Overall system architecture and layer relationships |
| [context.md](context.md) | Context awareness layer (app detection, profile switching) |
| [execution.md](execution.md) | Action execution layer (keyboard, scripts, system actions) |
| [profile.md](profile.md) | Profile management and built-in presets |
| [ui.md](ui.md) | UI components (ring view, window, menu bar) |

## Quick Reference

### Module Structure

```
Sources/MacRingCore/
├── Context/           # App-aware profile switching
│   ├── AppDetector.swift
│   ├── ContextEngine.swift
│   └── FullscreenDetector.swift
├── Execution/         # Action execution
│   ├── ActionExecutor.swift
│   └── ScriptRunner.swift
├── Input/             # Mouse event capture
│   └── EventTapManager.swift
├── Profile/           # Profile data models
│   ├── RingProfile.swift
│   ├── RingSlot.swift
│   ├── RingAction.swift
│   └── BuiltInProfiles.swift
└── UI/                # SwiftUI interface
    ├── RingView/RingView.swift
    ├── RingWindow.swift
    ├── MenuBarIntegration.swift
    └── RingGeometry.swift
```

### Platform Requirements

- **Minimum macOS:** 14.0+
- **Swift Language:** 5.10+
- **Swift Tools Version:** 6.0

### Key Design Patterns

| Pattern | Usage |
|---------|-------|
| Actor-based isolation | State management in ContextEngine, FullscreenDetector |
- Sendable types | Thread-safe data transfer |
| @unchecked Sendable | EventTapManager (legacy CGEventTap interop) |
| Protocol-oriented | ProfileProvider for dependency injection |

## Development Status

**Phase:** Context Awareness (Weeks 4-5) - MVP Complete

**Completed Components (Phase 1 - Foundation):**
- Core data models (RingProfile, RingSlot, RingAction)
- Event tap mouse capture (brand-agnostic)
- App detection and category mapping (150+ apps)
- Ring geometry calculations
- SwiftUI ring view and window
- Action executor (keyboard, apps, URLs)
- Menu bar integration

**Completed Components (Phase 2 - Context Awareness):**
- ContextEngine for app-aware profile switching
- FullscreenDetector for game mode
- ScriptRunner for shell/AppleScript execution
- 10 built-in profile presets (VS Code, Xcode, Safari, etc.)
- Expanded ActionExecutor with script support

**Planned Components (Phase 3+):**
- AI integration (Claude API)
- MCP client and tool execution
- Semantic analysis (NLEmbedding)
- Database layer (GRDB.swift)
- Configurator UI

## Related Documentation

- [../CLAUDE.md](../CLAUDE.md) - Project overview and build commands
- [../MacRing_PRD_v2.md](../MacRing_PRD_v2.md) - Product requirements document
