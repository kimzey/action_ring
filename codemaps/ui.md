# MacRing -- UI Components Codemap

> **Last Updated:** 2026-02-21
> **Status:** Phase 1 Complete

---

## Overview

The UI layer provides geometry calculations, SwiftUI rendering, floating window management, and menu bar integration for the radial action ring.

---

## File Structure

```
Sources/MacRingCore/UI/
├── RingGeometry.swift         (145 lines)  ✅ COMPLETE
├── RingView/
│   └── RingView.swift         (174 lines)  ✅ COMPLETE
├── RingWindow.swift           (147 lines)  ✅ COMPLETE
└── MenuBarIntegration.swift   (143 lines)  ✅ COMPLETE

Tests/MacRingCoreTests/
└── RingGeometryTests.swift    (252 lines)  ✅ COMPLETE (30 tests)
```

---

## Component Overview

### 1. RingGeometry (Core Math)

**Purpose:** Coordinate transformations, slot selection, area detection

**Key Types:**
```swift
public enum RingSize {
    case small      // 220px diameter
    case medium     // 280px diameter
    case large      // 340px diameter
}

public struct RingGeometry: Equatable, Sendable {
    public let outerDiameter: CGFloat
    public let deadZoneRadius: CGFloat
    public let slotCount: Int  // 4, 6, or 8
}
```

**Key Methods:**
- `selectedSlot(for: CGPoint) -> Int?` - Returns slot index for cursor position
- `slotCenter(for: Int) -> CGPoint` - Returns center point of slot
- `slotAngle(for: Int) -> CGFloat` - Returns angle in radians
- `isInRingArea(point: CGPoint) -> Bool` - Area detection

**Test Coverage:** 30 tests covering:
- Slot angular width (4, 6, 8 configs)
- Dead zone detection
- Slot selection (8 directions)
- RingSize constants

---

### 2. RingView (SwiftUI)

**Purpose:** Declarative SwiftUI view for ring rendering

**Features:**
- 8-slot ring with icons and labels
- Hover and selection states
- Spring animations (appear/dismiss)
- Dead zone visualization
- Color-coded slots

**State:**
```swift
@Binding var selectedSlot: Int?
@Binding var hoveredSlot: Int?
@Binding var isVisible: Bool
```

**Visual Elements:**
- Background ring (stroke)
- Dead zone circle
- Slot backgrounds (50px circles)
- SF Symbol icons (24pt)
- Selection indicator (stroke)
- Hover labels

---

### 3. RingWindow (NSPanel)

**Purpose:** Floating, non-activating window container

**Properties:**
- `NSPanel` with `.borderless` and `.nonactivatingPanel`
- Window level: `.popUpMenu`
- Background: clear, with shadow
- Position: follows cursor

**Methods:**
```swift
public func show(at: CGPoint?)   // Show at cursor position
public func hide()                // Hide and reset state
```

**Mouse Tracking:**
- Monitors `.mouseMoved`, `.leftMouseDragged`, `.rightMouseDragged`
- Updates `selectedSlot` based on cursor position
- Uses `RingGeometry.selectedSlot(for:)` for calculation

---

### 4. MenuBarIntegration

**Purpose:** Menu bar icon and menu

**Features:**
- Status item with SF Symbol icon
- Dropdown menu with actions:
  - Show Ring
  - Open Configurator
  - Help & Documentation
  - Quit MacRing

**Delegate Protocol:**
```swift
public protocol MenuBarDelegate: AnyObject {
    func menuBarDidRequestOpenConfigurator()
    func menuBarDidRequestQuit()
    func menuBarDidToggleRing()
    func menuBarDidRequestHelp()
}
```

**Additional Methods:**
- `showTooltip(_:for:)` - Temporary tooltip
- `updateMenuState(isRingEnabled:)` - Update menu items
- `updateCurrentProfile(_:)` - Show active profile

---

## Coordinate System

```
          +y (up)
           |
           |
   +x ---- 0 ---- -x (left)
           |
           |
          -y (down)

Slot 0: 0 radians (right, +x)
Slot 1: pi/4 (45 deg)
Slot 2: pi/2 (90 deg, up)
...
```

---

## Slot Selection Algorithm

```
1. Calculate distance from center:
   distance = sqrt(x^2 + y^2)

2. Check dead zone:
   if distance <= deadZoneRadius: return nil

3. Calculate angle:
   angle = atan2(y, x)

4. Normalize to [0, 2pi):
   if angle < 0: angle += 2*pi

5. Calculate slot index:
   slot = floor(angle / slotAngularWidth)
   slotAngularWidth = 2*pi / slotCount
```

---

## Performance Metrics

| Metric | Target | Actual |
|--------|--------|--------|
| Slot selection | <5ms | <1ms |
| Slot center calc | <1ms | <1ms |
| Area check | <1ms | <1ms |
| Ring appear | <50ms | TBD |
| Render framerate | 60fps | TBD |

---

## Dependencies

```
RingGeometry.swift
  - Foundation
  - AppKit (conditional, CGPoint extensions)

RingView.swift
  - SwiftUI
  - RingGeometry
  - RingSlot (for slot data)

RingWindow.swift
  - AppKit (NSPanel)
  - SwiftUI (for hosting RingView)
  - RingGeometry

MenuBarIntegration.swift
  - AppKit (NSStatusBar, NSMenu)
```

---

## Planned Components (Not Yet Implemented)

| Component | Purpose | Phase |
|-----------|---------|-------|
| ConfiguratorWindow | Drag-and-drop profile editor | 3 |
| SlotView (standalone) | Reusable slot component | 3 |
| RingViewModel | State management | 2 |
| OnboardingWindow | First-run experience | 7 |

---

## Related Areas

- **Profile**: `RingProfile.slotCount` determines geometry
- **Input**: `EventTapManager` provides cursor position
- **Execution**: Slot selection triggers `ActionExecutor`

---

## Thread Safety

| Component | Thread Model |
|-----------|--------------|
| RingGeometry | Sendable struct (thread-safe) |
| RingView | Main actor only (@MainActor) |
| RingWindow | Main actor only |
| MenuBarIntegration | Main actor only
