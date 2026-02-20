import Foundation
#if canImport(AppKit)
import AppKit
#if canImport(SwiftUI)
import SwiftUI

// MARK: - Ring Window

/// A floating, non-activating panel window that displays the ring
/// at the cursor position when triggered
@available(macOS 14.0, *)
public final class RingWindow: NSPanel {

    // MARK: - Properties

    private let hostingController: NSHostingController<RingView>
    private var eventMonitor: Any?

    // MARK: - State

    public var selectedSlot: Int? {
        didSet {
            hostingController.rootView.selectedSlot = .init(get: { [weak self] in
                self?.selectedSlot
            }, set: { [weak self] in
                self?.selectedSlot = $0
            })
        }
    }

    public var hoveredSlot: Int? {
        didSet {
            hostingController.rootView.hoveredSlot = .init(get: { [weak self] in
                self?.hoveredSlot
            }, set: { [weak self] in
                self?.hoveredSlot = $0
            })
        }
    }

    private var isVisible = false

    // MARK: - Initializer

    public init(geometry: RingGeometry, slots: [RingSlot]) {
        // Create SwiftUI view
        let view = RingView(
            geometry: geometry,
            slots: slots,
            selectedSlot: .init(get: { [weak self] in self?.selectedSlot }, set: { _ in }),
            hoveredSlot: .init(get: { [weak self] in self?.hoveredSlot }, set: { _ in }),
            isVisible: .init(get: { [weak self] in self?.isVisible ?? false }, set: { _ in })
        )

        hostingController = NSHostingController(rootView: view)

        // Initialize panel with non-activating behavior
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: geometry.outerDiameter, height: geometry.outerDiameter),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        setupWindow()
    }

    // MARK: - Window Setup

    private func setupWindow() {
        // Basic properties
        isFloatingPanel = true
        level = .popUpMenu
        isMovableByWindowBackground = false
        isMovable = false
        hidesOnDeactivate = false

        // Appearance
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true

        // Content
        contentViewController = hostingController

        // Prevent window from appearing in dock/mission control
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Track mouse events for slot selection
        setupMouseTracking()
    }

    // MARK: - Show/Hide

    /// Show the ring at the cursor position
    /// - Parameter point: The position to show the ring (default: current cursor position)
    public func show(at point: CGPoint? = nil) {
        let position = point ?? NSEvent.mouseLocation

        // Center the ring on the cursor
        let x = position.x - (frame.width / 2)
        let y = position.y - (frame.height / 2)

        setFrameOrigin(NSPoint(x: x, y: y))

        isVisible = true
        hostingController.rootView.isVisible = true

        orderFrontRegardless()
    }

    /// Hide the ring
    public func hide() {
        isVisible = false
        hostingController.rootView.isVisible = false
        selectedSlot = nil
        hoveredSlot = nil

        orderOut(nil)
    }

    // MARK: - Mouse Tracking

    private func setupMouseTracking() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            guard let self = self,
                  self.isVisible else {
                return event
            }

            // Convert mouse location to window coordinates
            let windowPoint = self.convertScreen(toWindow: event.locationInWindow)
            let viewPoint = self.contentView?.convert(windowPoint, from: nil) ?? .zero

            // Calculate position relative to ring center
            let center = CGPoint(x: self.frame.width / 2, y: self.frame.height / 2)
            let relativePoint = CGPoint(x: viewPoint.x - center.x, y: viewPoint.y - center.y)

            // Update selected slot
            let geometry = self.hostingController.rootView.geometry
            let slot = geometry.selectedSlot(for: relativePoint)

            if slot != self.selectedSlot {
                self.selectedSlot = slot
            }

            return event
        }
    }

    // MARK: - Cleanup

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - RingWindow Tests

#if !os(macOS)
// Placeholder for Windows builds
@available(macOS 14.0, *)
public final class RingWindow {
    public init?(geometry: RingGeometry, slots: [RingSlot]) { return nil }
}
#endif
#endif
#endif
