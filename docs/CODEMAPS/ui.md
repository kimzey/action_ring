# UI Layer Codemap

**Last Updated:** 2025-02-21

## Overview

The UI layer provides the visual interface for MacRing. It consists of a SwiftUI-based ring view, a floating panel window, menu bar integration, and trigonometric calculations for ring geometry.

## Public Types

### RingView
```swift
@available(macOS 14.0, *)
public struct RingView: View
    let geometry: RingGeometry
    let slots: [RingSlot]
    @Binding var selectedSlot: Int?
    @Binding var hoveredSlot: Int?
    @Binding var isVisible: Bool
```

### RingWindow
```swift
@available(macOS 14.0, *)
public final class RingWindow: NSPanel
    init(geometry: RingGeometry, slots: [RingSlot])
    var selectedSlot: Int?
    var hoveredSlot: Int?

    func show(at point: CGPoint? = nil)
    func hide()
```

### MenuBarIntegration
```swift
public final class MenuBarIntegration
    init()
    weak var delegate: MenuBarDelegate?

    func setIcon(_ image: NSImage)
    func setTitle(_ title: String)
    func showTooltip(_ message: String, for duration: TimeInterval = 2.0)
    func updateMenuState(isRingEnabled: Bool)
    func updateCurrentProfile(_ profileName: String)
    func hide()
    func show()

    var isVisible: Bool { get set }
```

### MenuBarDelegate
```swift
public protocol MenuBarDelegate: AnyObject
    func menuBarDidRequestOpenConfigurator()
    func menuBarDidRequestQuit()
    func menuBarDidToggleRing()
    func menuBarDidRequestHelp()
```

### RingGeometry
```swift
public struct RingGeometry: Equatable, Sendable
    let outerDiameter: CGFloat
    let deadZoneRadius: CGFloat
    let slotCount: Int

    init(outerDiameter: CGFloat, deadZoneRadius: CGFloat, slotCount: Int)
    init(size: RingSize, slotCount: Int)

    var outerRadius: CGFloat
    var slotAngularWidth: CGFloat

    func selectedSlot(for point: CGPoint) -> Int?
    func slotAngle(for index: Int) -> CGFloat
    func slotCenter(for index: Int) -> CGPoint
    func isInRingArea(point: CGPoint) -> Bool
```

### RingSize
```swift
public enum RingSize
    case small       // 220px diameter
    case medium      // 280px diameter
    case large       // 340px diameter

    var outerDiameter: CGFloat
    var defaultDeadZoneRadius: CGFloat
```

## Dependencies

### Internal Dependencies
```
RingView
  -> RingGeometry
  -> RingSlot
  -> RingAction (indirect via RingSlot)

RingWindow
  -> RingView
  -> RingGeometry
  -> RingSlot

MenuBarIntegration
  -> (none, standalone)

RingGeometry
  -> (none, standalone)
```

### External Dependencies
- **SwiftUI:** RingView, bindings, animations (macOS 14.0+)
- **AppKit:** NSPanel, NSStatusItem, NSMenu, NSImage, NSEvent
- **Foundation:** CGPoint, CGFloat, trigonometric functions

## Ring Geometry

### Size Specifications

| Size | Outer Diameter | Dead Zone Radius |
|------|----------------|------------------|
| Small | 220px | 30px |
| Medium | 280px | 35px |
| Large | 340px | 40px |

### Slot Angular Width

```
slotAngularWidth = 2 * pi / slotCount

4 slots: 90 degrees (pi/2 radians)
6 slots: 60 degrees (pi/3 radians)
8 slots: 45 degrees (pi/4 radians)
```

### Slot Selection Algorithm

```swift
func selectedSlot(for point: CGPoint) -> Int? {
    // Calculate distance from center
    let distance = sqrt(point.x * point.x + point.y * point.y)

    // Check if in dead zone
    if distance <= deadZoneRadius {
        return nil
    }

    // Calculate angle and normalize to [0, 2pi)
    let angle = atan2(point.y, point.x)
    let normalizedAngle = angle < 0 ? angle + 2 * CGFloat.pi : angle

    // Calculate slot index
    let slotIndex = Int(normalizedAngle / slotAngularWidth)

    return min(slotIndex, slotCount - 1)
}
```

### Slot Center Calculation

```swift
func slotCenter(for index: Int) -> CGPoint {
    let angle = slotAngle(for: index)
    let midRadius = (deadZoneRadius + outerRadius) / 2

    return CGPoint(
        x: midRadius * cos(angle),
        y: midRadius * sin(angle)
    )
}
```

## Ring View Components

### Visual Elements
```
┌─────────────────────────────────────┐
│         Ring View Structure         │
│                                     │
│        (Outer Ring Circle)          │
│         .stroke(blue, 2)            │
│                                     │
│      ┌─────────────┐                │
│      │  Dead Zone  │  .fill(black)  │
│      │    (35px)   │  .opacity(0.1) │
│      └─────────────┘                │
│                                     │
│   ●  ●  ●  ●  ●  ●  ●  ●           │
│   (Slot Views - 8 total)            │
│   - Circle background (50px)        │
│   - SF Symbol icon (24px)           │
│   - Selection ring (55px, when sel) │
│   - Label tooltip (on hover)        │
└─────────────────────────────────────┘
```

### Slot View Properties

| Property | Value |
|----------|-------|
| Background Color | White opacity 0.9 |
| Background Size | 50x50 points |
| Icon Size | 24 points |
| Selection Stroke | Blue opacity 0.6, 3pt |
| Selection Size | 55x55 points |
| Label Font | Caption |
| Label Padding | 4 points |
| Label Background | Black opacity 0.8 |

### Animations

| Property | Animation |
|----------|-----------|
| Visibility | Spring (response: 0.3s, damping: 0.7) |
| Scale Effect | `isVisible ? 1 : 0.5` |
| Selection Scale | EaseInOut (0.1s) |

## Ring Window Properties

### Window Configuration

| Property | Value |
|----------|-------|
| Base Class | NSPanel |
| Style Mask | .borderless, .nonactivatingPanel |
| Window Level | .popUpMenu |
| Background | Clear (transparent) |
| Opaque | false |
| Shadow | true |
| Collection Behavior | .canJoinAllSpaces, .fullScreenAuxiliary |
| Movable | false |

### Mouse Tracking

The window tracks mouse movement to update slot selection:

```swift
eventMonitor = NSEvent.addLocalMonitorForEvents(
    matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
) { event in
    // Convert screen to window coordinates
    // Calculate position relative to ring center
    // Update selectedSlot via geometry.selectedSlot
    return event
}
```

### Show/Hide Behavior

```swift
func show(at point: CGPoint? = nil) {
    // Center ring on cursor (or provided point)
    let x = position.x - (frame.width / 2)
    let y = position.y - (frame.height / 2)
    setFrameOrigin(NSPoint(x: x, y: y))

    // Make visible
    isVisible = true
    orderFrontRegardless()
}

func hide() {
    // Reset state
    isVisible = false
    selectedSlot = nil
    hoveredSlot = nil

    // Hide window
    orderOut(nil)
}
```

## Menu Bar Integration

### Menu Structure

```
MacRing [Icon]
├── MacRing - [Profile Name]
├── ─────────────────────────────
├── Show Ring (Hold Button)      [check state]
├── ─────────────────────────────
├── Open Configurator…           Cmd+Shift+
├── ─────────────────────────────
├── Help & Documentation         ?
├── ─────────────────────────────
└── Quit MacRing                 Cmd+Q
```

### Icon Configuration

- **Default Symbol:** `circle.circle` (SF Symbol)
- **Template:** true (respects system appearance)
- **Size:** NSStatusItem.variableLength

### Delegate Callbacks

| Method | Trigger |
|--------|---------|
| `menuBarDidRequestOpenConfigurator()` | "Open Configurator" clicked |
| `menuBarDidRequestQuit()` | "Quit MacRing" clicked |
| `menuBarDidToggleRing()` | "Show Ring" clicked |
| `menuBarDidRequestHelp()` | "Help & Documentation" clicked |

## CGPoint Extensions

```swift
extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let dx = point.x - x
        let dy = point.y - y
        return sqrt(dx * dx + dy * dy)
    }

    func angle(to point: CGPoint) -> CGFloat {
        atan2(point.y - y, point.x - x)
    }
}
```

## Constants

### Ring Dimensions
- **Small:** 220px diameter, 30px dead zone
- **Medium:** 280px diameter, 35px dead zone
- **Large:** 340px diameter, 40px dead zone

### Visual Constants
- **Slot Background:** 50x50 points
- **Icon Size:** 24 points
- **Selection Ring:** 55x55 points, 3pt stroke
- **Tooltip Duration:** 2.0 seconds

### Animation Constants
- **Visibility Response:** 0.3 seconds
- **Visibility Damping:** 0.7
- **Selection Duration:** 0.1 seconds

## Related Areas

- [profile.md](profile.md) - RingSlot and RingProfile data models
- [context.md](context.md) - Profile updates on app switches
- [architecture.md](architecture.md) - Overall architecture
