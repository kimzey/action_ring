import Foundation
#if canImport(AppKit)
import AppKit
import CoreGraphics

// MARK: - Fullscreen Detector

/// Detects whether the frontmost app occupies a whole screen (e.g. a borderless
/// fullscreen game), so the ring can be suppressed there.
///
/// Uses `CGWindowListCopyWindowInfo` bounds + owner PID only — it never reads
/// window titles or contents, so no Screen Recording permission is required and
/// the privacy promise holds.
public final class FullscreenDetector: @unchecked Sendable {

    /// Bundle ids that should *always* suppress the ring even if not detected
    /// as fullscreen (e.g. apps with their own radial menus).
    public var blacklist: Set<String> = []
    /// Bundle ids that should *always* allow the ring even when fullscreen.
    public var whitelist: Set<String> = []

    private let workspace = NSWorkspace.shared

    public init() {}

    /// Whether the ring should be hidden for the current frontmost app.
    public func shouldSuppressRing() -> Bool {
        guard let app = workspace.frontmostApplication else { return false }
        let bundleId = app.bundleIdentifier ?? ""
        if whitelist.contains(bundleId) { return false }
        if blacklist.contains(bundleId) { return true }
        return isFullscreen(pid: app.processIdentifier)
    }

    /// True if the given process owns an on-screen, normal-layer window whose
    /// size matches a connected display (within tolerance).
    public func isFullscreen(pid: pid_t) -> Bool {
        let screenSizes = NSScreen.screens.map { $0.frame.size }
        guard !screenSizes.isEmpty else { return false }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        for info in infoList {
            guard
                let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t, ownerPID == pid,
                let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                let w = boundsDict["Width"], let h = boundsDict["Height"]
            else { continue }

            for size in screenSizes where matches(w, size.width) && matches(h, size.height) {
                return true
            }
        }
        return false
    }

    private func matches(_ a: CGFloat, _ b: CGFloat, tolerance: CGFloat = 2) -> Bool {
        abs(a - b) <= tolerance
    }
}

#endif
