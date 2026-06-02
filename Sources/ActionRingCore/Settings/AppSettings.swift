import Foundation

/// User-tunable settings, persisted as JSON. Network-free by design.
public struct AppSettings: Codable, Equatable, Sendable {
    /// Master switch — when off, the trigger never opens the ring.
    public var enabled: Bool
    /// Mouse button that opens the ring (0 left, 1 right, 2 middle, 3+ side).
    public var triggerButton: Int
    /// Ring size used when a profile doesn't pin its own.
    public var defaultRingSize: RingSize
    /// Show the text label under each slot.
    public var showLabels: Bool
    /// Hide the ring while a fullscreen game is frontmost.
    public var suppressInFullscreen: Bool
    /// Fire the highlighted slot when the trigger button is released.
    public var executeOnRelease: Bool
    /// Max seconds a shell/AppleScript action may run before it's killed.
    public var scriptTimeoutSeconds: Double

    public init(
        enabled: Bool = true,
        triggerButton: Int = 3,
        defaultRingSize: RingSize = .medium,
        showLabels: Bool = true,
        suppressInFullscreen: Bool = true,
        executeOnRelease: Bool = true,
        scriptTimeoutSeconds: Double = 10
    ) {
        self.enabled = enabled
        self.triggerButton = triggerButton
        self.defaultRingSize = defaultRingSize
        self.showLabels = showLabels
        self.suppressInFullscreen = suppressInFullscreen
        self.executeOnRelease = executeOnRelease
        self.scriptTimeoutSeconds = scriptTimeoutSeconds
    }

    // Tolerate older/partial payloads.
    private enum CodingKeys: String, CodingKey {
        case enabled, triggerButton, defaultRingSize, showLabels
        case suppressInFullscreen, executeOnRelease, scriptTimeoutSeconds
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? d.enabled
        triggerButton = try c.decodeIfPresent(Int.self, forKey: .triggerButton) ?? d.triggerButton
        defaultRingSize = try c.decodeIfPresent(RingSize.self, forKey: .defaultRingSize) ?? d.defaultRingSize
        showLabels = try c.decodeIfPresent(Bool.self, forKey: .showLabels) ?? d.showLabels
        suppressInFullscreen = try c.decodeIfPresent(Bool.self, forKey: .suppressInFullscreen) ?? d.suppressInFullscreen
        executeOnRelease = try c.decodeIfPresent(Bool.self, forKey: .executeOnRelease) ?? d.executeOnRelease
        scriptTimeoutSeconds = try c.decodeIfPresent(Double.self, forKey: .scriptTimeoutSeconds) ?? d.scriptTimeoutSeconds
    }
}

/// Human label for a mouse button number.
public func mouseButtonLabel(_ n: Int) -> String {
    switch n {
    case 0: return "Left Button"
    case 1: return "Right Button"
    case 2: return "Middle Button"
    default: return "Button \(n + 1)"   // side buttons: 3 → "Button 4"
    }
}
