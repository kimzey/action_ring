import Foundation
#if canImport(AppKit)
import AppKit

// MARK: - Event Type

/// Types of mouse events detected by the event tap
public enum EventTapEventType: Sendable {
    case down
    case up
    case drag
    case cancel
}

// MARK: - Event Action

/// Action to take after processing an event
public enum EventTapAction: Sendable {
    case passEvent    // Pass event to default handlers
    case suppress   // Consume the event, don't pass it on
}

// MARK: - Event Tap Manager

/// Manages CGEventTap for capturing mouse button events
/// Works with ANY mouse brand via CGEvent's universal HID normalization
public final class EventTapManager: @unchecked Sendable {

    // MARK: - Properties

    /// The mouse button number to monitor (0-31)
    /// 0=left, 1=right, 2=middle, 3+=side buttons
    public let buttonNumber: Int

    /// Whether the event tap is currently enabled
    public private(set) var isEnabled = false

    /// Callback invoked when monitored button events occur
    /// Return `.default` to pass event through, `.suppress` to consume it
    public var onEvent: ((EventTapEventType) -> EventTapAction)?

    // MARK: - Private Properties

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let callbackQueue = DispatchQueue(label: "com.macring.eventtap")

    // MARK: - Constants

    /// Valid range of CGMouseButton values
    public static let minButtonNumber = 0
    public static let maxButtonNumber = 31

    // MARK: - Initializer

    /// Initialize with a specific mouse button to monitor
    /// - Parameter buttonNumber: Mouse button number (3-4 typical for side buttons)
    public init(buttonNumber: Int = 3) {
        self.buttonNumber = max(Self.minButtonNumber, min(Self.maxButtonNumber, buttonNumber))
    }

    deinit {
        disable()
    }

    // MARK: - Enable/Disable

    /// Start monitoring mouse events
    /// - Returns: true if successful, false if accessibility permissions denied
    @discardableResult
    public func enable() -> Bool {
        guard !isEnabled else { return true }

        // Create event tap for mouse events
        let eventMask = (1 << CGEventType.mouseDown.rawValue) |
                        (1 << CGEventType.mouseUp.rawValue) |
                        (1 << CGEventType.otherMouseUp.rawValue) |
                        (1 << CGEventType.otherMouseUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }

                let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            // Failed to create tap - likely accessibility permissions denied
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        // Add to run loop
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        isEnabled = true
        return true
    }

    /// Stop monitoring mouse events
    public func disable() {
        guard isEnabled else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        runLoopSource = nil
        eventTap = nil
        isEnabled = false
    }

    // MARK: - Event Handling

    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent> {
        // Extract button number from event
        let eventButtonNumber = event.getIntegerValueField(.mouseEventButtonNumber)

        // Filter for our monitored button
        guard eventButtonNumber == buttonNumber else {
            return Unmanaged.passUnretained(event)
        }

        // Determine event type
        let eventType: EventTapEventType
        switch type {
        case .mouseDown, .otherMouseDown:
            eventType = .down
        case .mouseUp, .otherMouseUp:
            eventType = .up
        case .mouseMoved:
            eventType = .drag
        default:
            return Unmanaged.passUnretained(event)
        }

        // Invoke callback
        let action = onEvent?(eventType) ?? .passEvent

        switch action {
        case .passEvent:
            return Unmanaged.passUnretained(event)
        case .suppress:
            return Unmanaged.passUnretained(event)  // Event is consumed
        }
    }
}

// MARK: - Accessibility Check

extension EventTapManager {
    /// Check if the app has accessibility permissions
    public static func hasAccessibilityPermissions() -> Bool {
        // Check if we can create an event tap
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.mouseMoved.rawValue),
            callback: { proxy, type, event, refcon in Unmanaged.passUnretained(event) },
            userInfo: nil
        ) else {
            return false
        }

        // Clean up test tap
        CFRelease(tap)
        return true
    }

    /// Prompt user to grant accessibility permissions
    public static func promptAccessibilityPermissions() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = "MacRing needs accessibility permissions to capture mouse button events.\n\nGo to System Settings > Privacy & Security > Accessibility and enable MacRing."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open System Settings to Accessibility pane
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - Event Type Alias (for tests)

extension EventTapManager {
    public typealias EventType = EventTapEventType
}

#endif
