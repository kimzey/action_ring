<!-- Updated: 2025-02-20 -->
# MacRing -- UI Components Codemap

> Status: **Implemented** -- RingGeometry complete with 30 tests

---

## Overview

The UI layer provides geometry calculations for the radial action ring. `RingGeometry` handles coordinate transformations, slot selection, and area detection for the visual ring interface.

---

## File Structure

```
Sources/MacRingCore/UI/
  RingGeometry.swift      -- Complete geometry implementation

Tests/MacRingCoreTests/
  RingGeometryTests.swift -- 30 tests (Swift Testing framework)
```

---

## Core Types

### RingSize

```swift
public enum RingSize {
    case small      // 220px diameter
    case medium     // 280px diameter
    case large      // 340px diameter

    var outerDiameter: CGFloat
    var defaultDeadZoneRadius: CGFloat
}
```

| Size | Diameter | Dead Zone |
|------|----------|-----------|
| small | 220px | 30px |
| medium | 280px | 35px |
| large | 340px | 40px |

---

### RingGeometry

```swift
public struct RingGeometry: Equatable, Sendable {
    public let outerDiameter: CGFloat
    public let deadZoneRadius: CGFloat
    public let slotCount: Int
}
```

**Stored Properties:**
- `outerDiameter: CGFloat` - Total ring size in pixels
- `deadZoneRadius: CGFloat` - Center cancel zone radius
- `slotCount: Int` - Number of slots (4, 6, or 8)

**Computed Properties:**
```swift
public var outerRadius: CGFloat
// Returns: outerDiameter / 2

public var slotAngularWidth: CGFloat
// Returns: (2 * .pi) / CGFloat(slotCount)
```

---

## Key Methods

### Slot Selection

```swift
public func selectedSlot(for point: CGPoint) -> Int?
```

Returns the slot index for a cursor position, or `nil` if in dead zone.

**Algorithm:**
1. Calculate distance from center: `sqrt(x^2 + y^2)`
2. Return `nil` if `distance <= deadZoneRadius`
3. Calculate angle: `atan2(y, x)`
4. Normalize to `[0, 2pi)`: negative angles add `2pi`
5. Return: `floor(angle / slotAngularWidth)`

**Example:** For 8-slot ring at (100, 0):
- distance = 100 > 35 (not dead zone)
- angle = 0
- slot = floor(0 / pi/4) = 0

---

### Slot Geometry

```swift
public func slotAngle(for index: Int) -> CGFloat
// Returns: index * slotAngularWidth (radians)

public func slotCenter(for index: Int) -> CGPoint
// Returns center point at mid-radius between dead zone and outer
```

**Slot Center Calculation:**
```swift
let angle = slotAngle(for: index)
let midRadius = (deadZoneRadius + outerRadius) / 2
return CGPoint(x: midRadius * cos(angle), y: midRadius * sin(angle))
```

---

### Area Detection

```swift
public func isInRingArea(point: CGPoint) -> Bool
```

Returns `true` if point is within the ring (outside dead zone, inside outer radius).

---

## Initializers

```swift
public init(outerDiameter: CGFloat, deadZoneRadius: CGFloat, slotCount: Int)

public init(size: RingSize, slotCount: Int)
// Convenience: uses RingSize defaults
```

---

## CGPoint Extensions

```swift
extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat
    func angle(to point: CGPoint) -> CGFloat
}
```

Available when `canImport(AppKit)` - macOS only.

---

## Test Coverage

| Test Group | Count | Coverage |
|------------|-------|----------|
| Outer radius | 1 | Half-diameter calculation |
| Slot angular width | 3 | 4, 6, 8 slot configurations |
| Dead zone | 4 | Origin, inside, boundary, just-outside |
| Outside ring | 1 | Beyond outer radius still selects |
| isInRingArea | 3 | Dead zone false, valid true, outside false |
| Slot selection (8) | 6 | Right(0), up-right(1), up(2), left(4), down(6), wrap(7) |
| Slot selection (4) | 4 | Right(0), up(1), left(2), down(3) |
| Slot angle | 4 | Slot 0/2/4/7 angles |
| Slot center | 2 | Slot 0 on +x, slot 2 on +y |
| RingSize constants | 3 | small=220, medium=280, large=340 |
| Edge cases | 3 | Negative coords, tiny distance, boundary between slots |

**Total:** 30 tests

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

## Slot Selection Visualization (8-slot)

```
       2     1
      ###   ###
     ##       ##
    #     7     #
    #   (dead)  #
    #     zone   #
     ##       ##
      ###   ###
       3     0
```

---

## Performance Targets

| Metric | Target | Actual |
|--------|--------|--------|
| Slot selection | <5ms | <1ms (simple trig) |
| Slot center | <1ms | <1ms |
| Area check | <1ms | <1ms |

All calculations are O(1) with simple floating-point operations.

---

## Dependencies

```
RingGeometry.swift
  - Foundation
  - AppKit (conditional, for CGPoint extensions)
```

---

## Usage Examples

### Create geometry for 8-slot medium ring
```swift
let geo = RingGeometry(size: .medium, slotCount: 8)
// outerDiameter = 280, deadZoneRadius = 35, slotCount = 8
```

### Find which slot the cursor is over
```swift
if let slot = geo.selectedSlot(for: cursorPoint) {
    print("Cursor over slot \(slot)")
} else {
    print("Cursor in dead zone - cancel")
}
```

### Position a slot icon
```swift
let center = geo.slotCenter(for: 0)
// Place icon at center.x, center.y (mid-radius, right side)
```

### Check if cursor is in valid ring area
```swift
if geo.isInRingArea(point: cursorPoint) {
    // Show selection feedback
}
```

---

## Planned UI Components (Not Yet Implemented)

| Component | Purpose |
|-----------|---------|
| `RingWindow` | NSPanel for floating ring display |
| `RingView` | SwiftUI radial ring view with glassmorphism |
| `SlotView` | Individual slot with icon, label, highlight |
| `RingViewModel` | State management for ring visibility, selection |
| `ConfiguratorWindow` | Drag-and-drop profile editor |
| `MenuBarView` | MenuBarExtra for status and settings |

---

## Related Areas

- **Profile**: `RingProfile.slotCount` determines ring geometry
- **Input**: `EventTapManager` provides cursor position
- **Execution**: Slot selection triggers `ActionExecutor`

---

## Thread Safety

`RingGeometry` is a `Sendable` struct (all stored properties are `Sendable`). Safe to use across actor boundaries for concurrent UI updates.
