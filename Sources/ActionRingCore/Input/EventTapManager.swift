import Foundation
#if canImport(AppKit)
import AppKit
import ApplicationServices

// MARK: - Tap event

/// A normalized mouse event delivered from the CGEventTap.
public struct MouseTapEvent: Sendable {
    public enum Phase: Sendable { case down, up, drag }
    public let phase: Phase
    /// Mouse button number: 0 = left, 1 = right, 2 = middle, 3+ = side buttons.
    public let button: Int
    public init(phase: Phase, button: Int) {
        self.phase = phase
        self.button = button
    }
}

/// What to do with the underlying OS event after the callback runs.
public enum EventTapAction: Sendable {
    case passEvent   // let it reach the focused app
    case suppress    // consume it (e.g. so a side-button "back" doesn't fire)
}

// MARK: - Event Tap Manager

/// Captures mouse-button events from **any** mouse via `CGEventTap`.
///
/// Works brand-agnostically because `CGEventTap` sees the normalized HID
/// stream, not vendor drivers. The owner sets `onEvent` to react to the
/// configured trigger button (down/up/drag) and returns whether to suppress
/// the OS event. Cursor position is read by the owner via `NSEvent.mouseLocation`
/// when a `.drag`/`.down` arrives, so this type carries no coordinates.
///
/// The tap callback fires on the main run loop, and mutators are called from
/// the main actor, so accesses are already serialized in practice — but because
/// this type is `@unchecked Sendable`, the mutable callback/config fields are
/// guarded by a lock and read via snapshot so the contract is actually sound.
public final class EventTapManager: @unchecked Sendable {

    private let lock = NSLock()
    private var _triggerButton: Int
    private var _onEvent: ((MouseTapEvent) -> EventTapAction)?
    private var _onButtonRecorded: ((Int) -> Void)?
    private var _isRecording = false

    /// The button that opens the ring (0 left, 1 right, 2 middle, 3+ side).
    public var triggerButton: Int {
        get { lock.lock(); defer { lock.unlock() }; return _triggerButton }
        set { lock.lock(); _triggerButton = Self.clamp(newValue); lock.unlock() }
    }

    /// Called on the main thread for trigger-button down/up and any drag while
    /// monitoring. Return `.suppress` to consume the OS event.
    public var onEvent: ((MouseTapEvent) -> EventTapAction)? {
        get { lock.lock(); defer { lock.unlock() }; return _onEvent }
        set { lock.lock(); _onEvent = newValue; lock.unlock() }
    }

    /// When set, the **next** mouse-button press is captured as a trigger-button
    /// candidate (and suppressed), its number reported here, then recording ends.
    public var onButtonRecorded: ((Int) -> Void)? {
        get { lock.lock(); defer { lock.unlock() }; return _onButtonRecorded }
        set { lock.lock(); _onButtonRecorded = newValue; lock.unlock() }
    }

    public var isRecording: Bool {
        lock.lock(); defer { lock.unlock() }; return _isRecording
    }

    public private(set) var isEnabled = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    public static let minButton = 0
    public static let maxButton = 31

    public init(triggerButton: Int = 3) {
        self._triggerButton = Self.clamp(triggerButton)
    }

    deinit { disable() }

    private static func clamp(_ n: Int) -> Int { max(minButton, min(maxButton, n)) }

    // MARK: Lifecycle

    /// Begin capturing. Returns false if accessibility permission is missing.
    @discardableResult
    public func enable() -> Bool {
        guard !isEnabled else { return true }

        let types: [CGEventType] = [
            .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp,
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
        ]
        let mask: CGEventMask = types.reduce(into: 0) { acc, type in
            acc |= (CGEventMask(1) << CGEventMask(type.rawValue))
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isEnabled = true
        return true
    }

    public func disable() {
        guard isEnabled else { return }
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        runLoopSource = nil
        eventTap = nil
        isEnabled = false
    }

    // MARK: Recording

    public func startRecording() { lock.lock(); _isRecording = true; lock.unlock() }
    public func stopRecording() { lock.lock(); _isRecording = false; lock.unlock() }

    // MARK: Callback

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The OS disables a tap that takes too long or on user input; re-arm it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))

        // Snapshot mutable state under the lock; never invoke closures while
        // holding it (avoids reentrancy deadlock if a callback mutates us).
        lock.lock()
        let recording = _isRecording
        let trigger = _triggerButton
        let onEvent = _onEvent
        let onRecorded = _onButtonRecorded
        if recording, type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown {
            _isRecording = false
        }
        lock.unlock()

        // Recording mode: capture the next *press* of any button, then suppress.
        if recording {
            switch type {
            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                DispatchQueue.main.async { onRecorded?(button) }
                return nil   // swallow the press used for recording
            default:
                return Unmanaged.passUnretained(event)
            }
        }

        let phase: MouseTapEvent.Phase
        switch type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            phase = .down
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            phase = .up
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            phase = .drag
        default:
            return Unmanaged.passUnretained(event)
        }

        // Drags are reported regardless of button (the cursor moved while a
        // button is held). The owner decides whether to suppress — e.g. it
        // suppresses *all* drags while the ring is open so stray button-drags
        // don't reach the focused app.
        if phase == .drag {
            let action = onEvent?(MouseTapEvent(phase: .drag, button: button)) ?? .passEvent
            return action == .suppress ? nil : Unmanaged.passUnretained(event)
        }

        // Down/up only matter for the configured trigger button.
        guard button == trigger else { return Unmanaged.passUnretained(event) }

        let action = onEvent?(MouseTapEvent(phase: phase, button: button)) ?? .passEvent
        switch action {
        case .passEvent: return Unmanaged.passUnretained(event)
        case .suppress: return nil
        }
    }
}

// MARK: - Accessibility

extension EventTapManager {
    /// Whether the process is trusted for accessibility (required for event taps).
    public static func hasAccessibilityPermissions() -> Bool {
        AXIsProcessTrusted()
    }

    /// Trigger the system prompt that offers to open the Accessibility pane.
    @discardableResult
    public static func requestAccessibilityPermissions() -> Bool {
        // Literal value of kAXTrustedCheckOptionPrompt — avoids Unmanaged/CFString
        // import ambiguity across SDKs.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Settings → Privacy & Security → Accessibility.
    public static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

#endif
