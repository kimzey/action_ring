import Foundation
#if canImport(AppKit)
import AppKit
import CoreGraphics

// MARK: - App Type

/// Classification of application types for fullscreen behavior
public enum AppType: Equatable, Sendable {
    case game
    case browser
    case media
    case ide
    case terminal
    case productivity
    case other
}

// MARK: - Fullscreen Window Info

/// Information about a fullscreen window
public struct FullscreenWindowInfo: Sendable {
    public let bundleId: String
    public let appName: String
    public let bounds: CGRect
    public let appType: AppType
}

// MARK: - Fullscreen Detector

/// Detects fullscreen applications, with special handling for games
public final class FullscreenDetector {

    // MARK: - Types

    /// Token for monitoring cancellation
    public typealias MonitoringToken = UUID

    /// Callback for fullscreen state changes
    public typealias FullscreenChangeCallback = @Sendable (Bool) -> Void

    // MARK: - Properties

    private actor State {
        var isFullscreenActive: Bool = false
        var fullscreenApps: Set<String> = []
        var blacklist: Set<String> = []
        var whitelist: Set<String> = []
        var monitoringCallbacks: [UUID: FullscreenChangeCallback] = [:]
        var lastCheckTime: Date?

        func setIsFullscreen(_ value: Bool) {
            self.isFullscreenActive = value
        }

        func setFullscreenApps(_ apps: Set<String>) {
            self.fullscreenApps = apps
        }

        func addToBlacklist(_ bundleId: String) {
            blacklist.insert(bundleId)
        }

        func removeFromBlacklist(_ bundleId: String) {
            blacklist.remove(bundleId)
        }

        func clearBlacklistSet() {
            blacklist.removeAll()
        }

        func isInBlacklist(_ bundleId: String) -> Bool {
            blacklist.contains(bundleId)
        }

        func addToWhitelist(_ bundleId: String) {
            whitelist.insert(bundleId)
        }

        func removeFromWhitelist(_ bundleId: String) {
            whitelist.remove(bundleId)
        }

        func isInWhitelist(_ bundleId: String) -> Bool {
            whitelist.contains(bundleId)
        }
    }

    private let state: State
    private let callbackQueue = DispatchQueue(label: "com.macring.fullscreendetector")

    // Known game bundle ID patterns
    private let gameBundlePatterns: Set<String> = [
        // Steam games
        "com.valve.steam",
        // Blizzard
        "com.blizzard.",
        "com.blivion.",

        // Epic Games
        "com.epic.games.",
        // Common game publishers
        "com.ubisoft.",
        "com.ea.",
        "com.activision.",
        "com.bethesda.",
        "com.cdprojekt.",
        "com.squareenix.",
        "com.sega.",
        "com.capcom.",
        "com.konami.",
        "com.bandainamco.",

        // Game identifiers in bundle ID
        "Game",
        "game",
    ]

    // Media player bundle IDs (for blacklist by default)
    private let mediaBundleIds: Set<String> = [
        "org.videolan.vlc",
        "com.apple.QuickTimePlayerX",
        "com.apple.TV",
        "com.netflix.Netflix",
        "com.hulu.desktop",
    ]

    // MARK: - Initializers

    public init() {
        self.state = State()
    }

    // MARK: - Public API

    /// Current fullscreen state
    public var isFullscreenActive: Bool {
        get async { await state.isFullscreenActive }
    }

    /// List of currently fullscreen app bundle IDs
    public var fullscreenApps: [String] {
        get async { Array(await state.fullscreenApps).sorted() }
    }

    /// Check if there are any fullscreen windows
    /// - Parameter windows: Window info from CGWindowListCopyWindowInfo
    /// - Returns: true if any fullscreen app is detected
    public func checkFullscreen(_ windows: [[String: Any]]) async -> Bool {
        let detectedApps = await detectFullscreenWindows(windows)

        let hasFullscreen = !detectedApps.isEmpty
        await state.setIsFullscreen(hasFullscreen)
        await state.setFullscreenApps(Set(detectedApps.map(\.bundleId)))

        return hasFullscreen
    }

    /// List all fullscreen apps
    /// - Parameter windows: Window info from CGWindowListCopyWindowInfo
    /// - Returns: Array of fullscreen window info
    public func listFullscreenApps(_ windows: [[String: Any]]) async -> [String] {
        let detectedApps = await detectFullscreenWindows(windows)
        await state.setFullscreenApps(Set(detectedApps.map(\.bundleId)))
        return detectedApps.map(\.bundleId)
    }

    /// Determine the app type for a given bundle ID
    /// - Parameter bundleId: The app's bundle identifier
    /// - Returns: The app type
    public func appType(forBundleId bundleId: String) async -> AppType {
        // Check game patterns first
        if isGameBundleId(bundleId) {
            return .game
        }

        // Check known media players
        if mediaBundleIds.contains(bundleId) {
            return .media
        }

        // Use AppDetector for category mapping
        let detector = AppDetector()
        let category = detector.category(forBundleId: bundleId)

        switch category {
        case .ide:
            return .ide
        case .browser:
            return .browser
        case .terminal:
            return .terminal
        case .productivity:
            return .productivity
        case .media:
            return .media
        default:
            return .other
        }
    }

    /// Update the fullscreen state (for testing/manual updates)
    /// - Parameter isFullscreen: The new fullscreen state
    public func updateFullscreenState(_ isFullscreen: Bool) async {
        let previousState = await state.isFullscreenActive
        await state.setIsFullscreen(isFullscreen)

        // Only notify if state changed
        if previousState != isFullscreen {
            await notifyStateChanged(isFullscreen)
        }
    }

    // MARK: - Blacklist/Whitelist Management

    /// Add a bundle ID to the blacklist (ignored for fullscreen detection)
    /// - Parameter bundleId: The bundle ID to blacklist
    public func addToBlacklist(_ bundleId: String) async {
        await state.addToBlacklist(bundleId)
    }

    /// Remove a bundle ID from the blacklist
    /// - Parameter bundleId: The bundle ID to remove
    public func removeFromBlacklist(_ bundleId: String) async {
        await state.removeFromBlacklist(bundleId)
    }

    /// Clear the entire blacklist
    public func clearBlacklist() async {
        await state.clearBlacklistSet()
    }

    /// Add a bundle ID to the whitelist (always detected)
    /// - Parameter bundleId: The bundle ID to whitelist
    public func addToWhitelist(_ bundleId: String) async {
        await state.addToWhitelist(bundleId)
    }

    /// Remove a bundle ID from the whitelist
    /// - Parameter bundleId: The bundle ID to remove
    public func removeFromWhitelist(_ bundleId: String) async {
        await state.removeFromWhitelist(bundleId)
    }

    // MARK: - Monitoring

    /// Start monitoring for fullscreen state changes
    /// - Parameter callback: Closure called when fullscreen state changes
    /// - Returns: A token to use when stopping monitoring
    @discardableResult
    public func startMonitoring(callback: @escaping FullscreenChangeCallback) async -> UUID {
        let uuid = UUID()
        await addCallback(uuid, callback)
        return uuid
    }

    /// Stop monitoring with the given token
    /// - Parameter token: The token returned from startMonitoring
    public func stopMonitoring(token: UUID) async {
        await removeCallback(token)
    }

    // MARK: - Private Methods

    private func detectFullscreenWindows(_ windows: [[String: Any]]) async -> [FullscreenWindowInfo] {
        var detected: [FullscreenWindowInfo] = []

        // Get screen size for comparison
        guard let mainScreen = NSScreen.main else {
            return []
        }
        let screenBounds = mainScreen.frame

        for windowInfo in windows {
            // Extract bundle ID from window info
            guard let bundleId = windowInfo[kCGWindowOwnerName as String] as? String ?? windowInfo["kCGWindowBundleID"] as? String else {
                continue
            }

            // Skip if blacklisted
            if await state.isInBlacklist(bundleId) {
                continue
            }

            // Check if window is onscreen
            if let isOnscreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool, !isOnscreen {
                continue
            }

            // Check window bounds
            guard let boundsString = windowInfo[kCGWindowBounds as String] as? String else {
                continue
            }

            let bounds = parseBounds(boundsString)
            guard bounds.width > 0, bounds.height > 0 else {
                continue
            }

            // Check if window covers the entire screen (with tolerance)
            let tolerance: CGFloat = 10  // Allow 10px margin
            let isFullscreen =
                abs(bounds.width - screenBounds.width) <= tolerance &&
                abs(bounds.height - screenBounds.height) <= tolerance &&
                abs(bounds.origin.x) <= tolerance &&
                abs(bounds.origin.y) <= tolerance

            if isFullscreen {
                let appType = await appType(forBundleId: bundleId)
                let info = FullscreenWindowInfo(
                    bundleId: bundleId,
                    appName: windowInfo[kCGWindowOwnerName as String] as? String ?? bundleId,
                    bounds: bounds,
                    appType: appType
                )
                detected.append(info)
            }
        }

        return detected
    }

    private func parseBounds(_ string: String) -> CGRect {
        // Format: "{{x, y}, {width, height}}"
        let pattern = #"{{(-?\d+\.?\d*),\s*(-?\d+\.?\d*)},\s*(\d+\.?\d*),\s*(\d+\.?\d*)}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return .zero
        }

        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, range: range) else {
            return .zero
        }

        let x = (string as NSString).substring(with: match.range(at: 1))
        let y = (string as NSString).substring(with: match.range(at: 2))
        let width = (string as NSString).substring(with: match.range(at: 3))
        let height = (string as NSString).substring(with: match.range(at: 4))

        return CGRect(
            x: CGFloat(Double(x) ?? 0),
            y: CGFloat(Double(y) ?? 0),
            width: CGFloat(Double(width) ?? 0),
            height: CGFloat(Double(height) ?? 0)
        )
    }

    private func isGameBundleId(_ bundleId: String) -> Bool {
        // Check exact patterns
        for pattern in gameBundlePatterns {
            if bundleId.hasPrefix(pattern) || bundleId.contains(pattern) {
                return true
            }
        }

        // Check for "game" or "Game" in bundle ID
        let lowercaseId = bundleId.lowercased()
        return lowercaseId.contains("game")
    }

    private func addCallback(_ uuid: UUID, _ callback: @escaping FullscreenChangeCallback) async {
        await state.monitoringCallbacks[uuid] = callback
    }

    private func removeCallback(_ uuid: UUID) async {
        await state.monitoringCallbacks.removeValue(forKey: uuid)
    }

    private func notifyStateChanged(_ isFullscreen: Bool) async {
        let callbacks = await state.monitoringCallbacks.values

        callbackQueue.async {
            for callback in callbacks {
                callback(isFullscreen)
            }
        }
    }
}

#endif
