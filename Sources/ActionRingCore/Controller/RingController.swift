import Foundation
#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import SwiftUI

/// The conductor. Owns every subsystem and wires the core loop:
///
/// `trigger down` → (unless fullscreen) show ring at cursor → `drag` highlights
/// the angular slot → `trigger up` fires the highlighted slot's action (or
/// cancels in the dead zone).
@available(macOS 14.0, *)
@MainActor
public final class RingController {

    public let profileStore: ProfileStore
    public let appDetector: AppDetector
    public let contextEngine: ContextEngine
    public let fullscreenDetector: FullscreenDetector
    public let eventTap: EventTapManager
    private let executor: ActionExecutor

    private let model: RingViewModel
    private var window: RingWindow?

    /// True while the ring is on screen for the current press.
    /// Ring interaction state. Supports two natural gestures:
    ///  • **Hold**: press-and-hold → drag to a slot → release to fire.
    ///  • **Click**: a quick tap opens a *sticky* ring that stays up; move to a
    ///    slot and click again to fire (click in the center to cancel).
    private enum RingState { case closed, holding, sticky }
    private var state: RingState = .closed
    /// When the current ring opened (to tell a quick tap from a deliberate hold).
    private var openedAt = Date.distantPast
    /// A tap shorter than this with no slot selected opens the sticky ring.
    private let tapThreshold: TimeInterval = 0.30

    /// Set when a trigger-down was suppressed, so the matching trigger-up is also
    /// suppressed — even if the poll closed the ring first (which would otherwise
    /// let a dangling up reach the focused app).
    private var expectingTriggerUp = false
    /// Drives cursor tracking + release detection while the ring is open.
    private var pollTimer: Timer?
    /// In preview mode the ring follows the cursor but ignores button state and
    /// never executes; it auto-dismisses on a (cancellable) timer.
    private var previewMode = false
    private var previewDismiss: DispatchWorkItem?
    /// Safety auto-cancel for a sticky ring left open.
    private var stickyTimeout: DispatchWorkItem?

    /// Last action result, surfaced for diagnostics/UI if desired.
    public private(set) var lastResult: ActionExecutorResult?
    public var onActionExecuted: ((RingSlot, ActionExecutorResult) -> Void)?

    /// True only when the event tap is actually installed and listening — i.e.
    /// the trigger button will open the ring right now. This is stronger than
    /// "accessibility granted": the tap can still need a (re)arm after a grant.
    public var isArmed: Bool { eventTap.isEnabled }

    public init(profileStore: ProfileStore = ProfileStore()) {
        self.profileStore = profileStore
        self.appDetector = AppDetector()
        self.contextEngine = ContextEngine(appDetector: appDetector, provider: profileStore)
        self.fullscreenDetector = FullscreenDetector()
        self.eventTap = EventTapManager(triggerButton: profileStore.settings.triggerButton)
        self.executor = ActionExecutor(
            scriptOptions: ScriptExecutionOptions(timeout: profileStore.settings.scriptTimeoutSeconds)
        )

        let initial = contextEngine.currentProfile
        self.model = RingViewModel(
            geometry: RingGeometry(size: initial.ringSize, slotCount: initial.slotCount),
            slots: initial.renderedSlots(),
            showLabels: profileStore.settings.showLabels
        )
    }

    // MARK: Lifecycle

    /// Returns false if accessibility permission is missing (the tap won't arm).
    @discardableResult
    public func start() -> Bool {
        applySettings()

        contextEngine.onProfileChange = { [weak self] profile in
            self?.model.slots = profile.renderedSlots()
        }
        contextEngine.start()

        eventTap.onEvent = { [weak self] event in
            guard let self else { return .passEvent }
            return self.handle(event)
        }
        // Pre-create the overlay so the first ring open is just a (fast) show —
        // keeps the event-tap callback well under its timeout.
        _ = ensureWindow()
        return eventTap.enable()
    }

    public func stop() {
        eventTap.disable()
        contextEngine.stop()
        stopPolling()
        state = .closed
        previewMode = false
        window?.hide()
    }

    /// Re-read settings into the live subsystems (after the settings UI changes).
    public func applySettings() {
        let s = profileStore.settings
        eventTap.triggerButton = s.triggerButton
        model.showLabels = s.showLabels
    }

    // MARK: Core loop

    private func ensureWindow() -> RingWindow {
        if let window { return window }
        let w = RingWindow(model: model)
        window = w
        return w
    }

    private func handle(_ event: MouseTapEvent) -> EventTapAction {
        switch event.phase {
        case .down:
            return onTriggerDown()
        case .drag:
            // We rarely receive drags (the suppressed down stops the OS emitting
            // them); the poll tracks the cursor instead. Suppress any that do
            // arrive while the ring is up so stray button-drags don't reach the app.
            return state == .closed ? .passEvent : .suppress
        case .up:
            return onTriggerUp()
        }
    }

    private func onTriggerDown() -> EventTapAction {
        switch state {
        case .closed:
            // Master switch off, or a fullscreen game / suppressed app is frontmost
            // → let the click through untouched.
            if !profileStore.settings.enabled {
                expectingTriggerUp = false
                return .passEvent
            }
            if profileStore.settings.suppressInFullscreen, fullscreenDetector.shouldSuppressRing() {
                expectingTriggerUp = false
                return .passEvent
            }
            previewMode = false
            showRing(for: contextEngine.currentProfile, at: NSEvent.mouseLocation)
            state = .holding
            openedAt = Date()
            startPolling()
            expectingTriggerUp = true
            return .suppress   // swallow the press so the app's own binding doesn't fire

        case .sticky:
            // Second click confirms: fire the highlighted slot (cancel in center).
            let selected = window?.updateSelection(cursor: NSEvent.mouseLocation)
            finishRing(selecting: selected)
            expectingTriggerUp = true
            return .suppress

        case .holding:
            // A second down while still holding (e.g. a missed up) — resolve now.
            let selected = window?.updateSelection(cursor: NSEvent.mouseLocation)
            finishRing(selecting: selected)
            expectingTriggerUp = true
            return .suppress
        }
    }

    private func onTriggerUp() -> EventTapAction {
        let suppressUp = expectingTriggerUp
        expectingTriggerUp = false
        if state == .holding { resolveHoldRelease() }
        return suppressUp ? .suppress : .passEvent
    }

    /// Interpret a release while holding: fire a selection, or — for a quick tap
    /// with nothing selected — switch to a sticky (stays-open) ring.
    private func resolveHoldRelease() {
        let selected = window?.updateSelection(cursor: NSEvent.mouseLocation)
        if let selected {
            finishRing(selecting: selected)
            return
        }
        if Date().timeIntervalSince(openedAt) < tapThreshold {
            enterSticky()                  // a tap → keep the ring open
        } else {
            finishRing(selecting: nil)     // a deliberate hold in the center → cancel
        }
    }

    private func enterSticky() {
        state = .sticky
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.state == .sticky else { return }
            self.finishRing(selecting: nil)
        }
        stickyTimeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: work)
    }

    private func showRing(for profile: RingProfile, at point: CGPoint) {
        let geometry = RingGeometry(size: profile.ringSize, slotCount: profile.slotCount)
        let w = ensureWindow()
        w.apply(geometry: geometry)
        model.slots = profile.renderedSlots()
        model.profileName = profile.name
        w.show(at: point)
    }

    /// Close the ring and fire `selected`'s action if present. Idempotent.
    private func finishRing(selecting selected: Int?) {
        guard state != .closed || previewMode else { return }
        state = .closed
        let wasPreview = previewMode
        previewMode = false
        stopPolling()
        window?.hide()

        guard
            !wasPreview, profileStore.settings.executeOnRelease,
            let index = selected,
            let slot = model.slots.first(where: { $0.position == index }),
            let action = slot.action
        else { return }

        Task { [weak self] in
            guard let self else { return }
            let result = await self.executor.execute(action)
            self.lastResult = result
            self.onActionExecuted?(slot, result)
        }
    }

    // MARK: Cursor polling (tracks the cursor; release comes from the up event)

    private func startPolling() {
        stopPolling()
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.state != .closed || self.previewMode else { return }
                self.window?.updateSelection(cursor: NSEvent.mouseLocation)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopPolling() {
        pollTimer?.invalidate(); pollTimer = nil
        previewDismiss?.cancel(); previewDismiss = nil
        stickyTimeout?.cancel(); stickyTimeout = nil
    }

    // MARK: Preview (verify the ring without granting Accessibility)

    /// Show the ring centered on the active screen, tracking the cursor, then
    /// auto-dismiss. Lets the user see the ring respond before wiring the trigger.
    public func showPreview(duration: TimeInterval = 4) {
        previewMode = true
        let screen = NSScreen.main ?? NSScreen.screens.first
        let point = screen.map { CGPoint(x: $0.frame.midX, y: $0.frame.midY) } ?? NSEvent.mouseLocation
        showRing(for: contextEngine.currentProfile, at: point)
        startPolling()   // cancels any prior previewDismiss
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.previewMode else { return }
            self.finishRing(selecting: nil)
        }
        previewDismiss = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    // MARK: Button recording (for settings)

    /// Capture the next mouse-button press as the new trigger button.
    public func recordTriggerButton(_ completion: @escaping (Int) -> Void) {
        eventTap.onButtonRecorded = { [weak self] button in
            guard let self else { return }
            self.profileStore.settings.triggerButton = button
            self.profileStore.saveSettings()
            self.eventTap.triggerButton = button
            completion(button)
        }
        eventTap.startRecording()
    }

    public func cancelRecording() { eventTap.stopRecording() }
}
#endif
