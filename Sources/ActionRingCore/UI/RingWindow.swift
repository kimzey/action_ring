import Foundation
#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import SwiftUI

/// A borderless, non-activating, click-through panel that shows the ring at the
/// cursor. It never steals focus and never receives mouse events itself — the
/// owner tracks the cursor via the event tap + `NSEvent.mouseLocation`.
@available(macOS 14.0, *)
@MainActor
public final class RingWindow: NSPanel {

    public let model: RingViewModel
    private let hostingView: NSHostingView<RingView>

    /// Screen-space (AppKit, +y up) point the ring is centered on.
    public private(set) var center: CGPoint = .zero

    public init(model: RingViewModel) {
        self.model = model
        self.hostingView = NSHostingView(rootView: RingView(model: model))

        let d = model.geometry.canvasDiameter   // ring + transparent shadow margin
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: d, height: d),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .popUpMenu
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false                 // shadow is drawn by SwiftUI
        ignoresMouseEvents = true          // fully click-through
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        hostingView.frame = NSRect(x: 0, y: 0, width: d, height: d)
        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView
    }

    // Borderless panels normally can't be key; allow it defensively (we never
    // activate, but this avoids edge cases on some macOS versions).
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }

    // MARK: Show / update / hide

    /// Resize for a (possibly new) geometry, e.g. when the profile's ring size
    /// differs from the last one shown.
    public func apply(geometry: RingGeometry) {
        guard geometry != model.geometry else { return }
        model.geometry = geometry
        let d = geometry.canvasDiameter
        setContentSize(NSSize(width: d, height: d))
        hostingView.frame = NSRect(x: 0, y: 0, width: d, height: d)
    }

    /// Show centered on a screen-space point (AppKit coordinates).
    public func show(at point: CGPoint) {
        center = point
        let d = model.geometry.canvasDiameter
        setFrameOrigin(NSPoint(x: point.x - d / 2, y: point.y - d / 2))
        model.selectedSlot = nil
        model.isVisible = true
        orderFrontRegardless()
    }

    /// Update the highlighted slot from the current cursor screen position.
    /// Returns the resolved slot index (nil = dead-zone / cancel).
    @discardableResult
    public func updateSelection(cursor: CGPoint) -> Int? {
        let relative = CGPoint(x: cursor.x - center.x, y: cursor.y - center.y)
        let resolved = model.geometry.selectableSlot(for: relative, in: model.slots)
        if resolved != model.selectedSlot { model.selectedSlot = resolved }
        return resolved
    }

    public func hide() {
        model.isVisible = false
        // Defer the actual ordering-out slightly so the dismiss animation plays.
        let deadline = DispatchTime.now() + 0.12
        DispatchQueue.main.asyncAfter(deadline: deadline) { [weak self] in
            guard let self, self.model.isVisible == false else { return }
            self.orderOut(nil)
            self.model.selectedSlot = nil
        }
    }
}
#endif
