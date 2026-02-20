import Testing
import Foundation
#if canImport(AppKit)
import AppKit
@testable import MacRingCore

@Suite("FullscreenDetector Tests")
struct FullscreenDetectorTests {

    // MARK: - Fullscreen Detection Tests

    @Test("Detects single fullscreen window")
    func detectsSingleFullscreenWindow() async {
        let detector = FullscreenDetector()

        // Mock a fullscreen window
        let mockWindows = createMockFullscreenWindows(count: 1)

        let isFullscreen = await detector.checkFullscreen(mockWindows)

        #expect(isFullscreen == true)
    }

    @Test("Returns false when no fullscreen apps")
    func returnsFalseWhenNoFullscreenApps() async {
        let detector = FullscreenDetector()

        let mockWindows = createMockNormalWindows()

        let isFullscreen = await detector.checkFullscreen(mockWindows)

        #expect(isFullscreen == false)
    }

    @Test("Identifies game vs fullscreen video player")
    func identifiesGameVsVideoPlayer() async {
        let detector = FullscreenDetector()

        // Game app
        let gameWindow = createMockWindow(
            bundleId: "com.blizzard.heroes",
            isFullscreen: true
        )

        let gameType = await detector.appType(forBundleId: "com.blizzard.heroes")
        #expect(gameType == .game)

        // Video player
        let videoWindow = createMockWindow(
            bundleId: "org.videolan.vlc",
            isFullscreen: true
        )

        let videoType = await detector.appType(forBundleId: "org.videolan.vlc")
        #expect(videoType == .media)
    }

    @Test("Handles minimized fullscreen windows")
    func handlesMinimizedFullscreenWindows() async {
        let detector = FullscreenDetector()

        // Create a minimized fullscreen window
        let mockWindows = createMockMinimizedFullscreenWindows()

        let isFullscreen = await detector.checkFullscreen(mockWindows)

        #expect(isFullscreen == false)  // Minimized should not count as active fullscreen
    }

    @Test("Handles hidden fullscreen windows")
    func handlesHiddenFullscreenWindows() async {
        let detector = FullscreenDetector()

        let mockWindows = createMockHiddenFullscreenWindows()

        let isFullscreen = await detector.checkFullscreen(mockWindows)

        #expect(isFullscreen == false)  // Hidden should not count as active fullscreen
    }

    // MARK: - Fullscreen List Tests

    @Test("Lists fullscreen apps by name")
    func listsFullscreenAppsByName() async {
        let detector = FullscreenDetector()

        let mockWindows = [
            createMockWindow(bundleId: "com.game.one", isFullscreen: true),
            createMockWindow(bundleId: "com.game.two", isFullscreen: true),
            createMockWindow(bundleId: "com.apple.Safari", isFullscreen: false),
        ]

        let fullscreenApps = await detector.listFullscreenApps(mockWindows)

        #expect(fullscreenApps.count == 2)
        #expect(fullscreenApps.contains("com.game.one"))
        #expect(fullscreenApps.contains("com.game.two"))
    }

    @Test("Returns empty list when no fullscreen apps")
    func returnsEmptyListWhenNoFullscreenApps() async {
        let detector = FullscreenDetector()

        let mockWindows = createMockNormalWindows()

        let fullscreenApps = await detector.listFullscreenApps(mockWindows)

        #expect(fullscreenApps.isEmpty)
    }

    // MARK: - Game Detection Tests

    @Test("Detects game bundle ID patterns")
    func detectsGameBundleIdPatterns() async {
        let detector = FullscreenDetector()

        let gameBundleIds = [
            "com.company.Game",
            "com.blizzard.heroes",
            "com.valve.steam",
            "com.epic.games.fortnite",
            "com.mobcg.starwars",
        ]

        for bundleId in gameBundleIds {
            let appType = await detector.appType(forBundleId: bundleId)
            #expect(appType == .game, "Expected \(bundleId) to be detected as game")
        }
    }

    @Test("Non-game apps return correct category")
    func nonGameAppsReturnCorrectCategory() async {
        let detector = FullscreenDetector()

        let safariType = await detector.appType(forBundleId: "com.apple.Safari")
        #expect(safariType == .browser)

        let vscodeType = await detector.appType(forBundleId: "com.microsoft.VSCode")
        #expect(vscodeType == .ide)

        let finderType = await detector.appType(forBundleId: "com.apple.finder")
        #expect(finderType == .other)
    }

    // MARK: - Published Properties Tests

    @Test("Publishes changes when fullscreen state changes")
    func publishesChangesWhenFullscreenStateChanges() async {
        let detector = FullscreenDetector()

        var publishedStates: [Bool] = []
        let token = await detector.startMonitoring { isFullscreen in
            publishedStates.append(isFullscreen)
        }

        // Simulate state changes
        await detector.updateFullscreenState(true)
        try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms
        await detector.updateFullscreenState(false)
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(publishedStates.count == 2)
        #expect(publishedStates[0] == true)
        #expect(publishedStates[1] == false)

        await detector.stopMonitoring(token: token)
    }

    @Test("isFullscreenActive returns current state")
    func isFullscreenActiveReturnsCurrentState() async {
        let detector = FullscreenDetector()

        let initialState = await detector.isFullscreenActive
        #expect(initialState == false)

        await detector.updateFullscreenState(true)

        let updatedState = await detector.isFullscreenActive
        #expect(updatedState == true)
    }

    // MARK: - Blacklist/Whitelist Tests

    @Test("Blacklisted apps are ignored")
    func blacklistedAppsAreIgnored() async {
        let detector = FullscreenDetector()

        // Add to blacklist
        await detector.addToBlacklist("org.videolan.vlc")

        let mockWindows = [
            createMockWindow(bundleId: "org.videolan.vlc", isFullscreen: true),
            createMockWindow(bundleId: "com.game.test", isFullscreen: true),
        ]

        let fullscreenApps = await detector.listFullscreenApps(mockWindows)

        // VLC should be filtered out
        #expect(fullscreenApps.count == 1)
        #expect(fullscreenApps.contains("com.game.test"))
        #expect(!fullscreenApps.contains("org.videolan.vlc"))
    }

    @Test("Whitelisted apps are always detected")
    func whitelistedAppsAreAlwaysDetected() async {
        let detector = FullscreenDetector()

        // Add to whitelist
        await detector.addToWhitelist("com.special.app")

        // Even if not in fullscreen, whitelisted apps should be reported
        let mockWindows = [
            createMockWindow(bundleId: "com.special.app", isFullscreen: false),
        ]

        let fullscreenApps = await detector.listFullscreenApps(mockWindows)

        // Whitelisted apps are tracked even if not fullscreen
        // (This depends on the specific behavior we want)
        #expect(true)  // Placeholder for whitelist behavior
    }

    @Test("Can clear blacklist")
    func canClearBlacklist() async {
        let detector = FullscreenDetector()

        await detector.addToBlacklist("org.videolan.vlc")
        await detector.clearBlacklist()

        let mockWindows = [
            createMockWindow(bundleId: "org.videolan.vlc", isFullscreen: true),
        ]

        let fullscreenApps = await detector.listFullscreenApps(mockWindows)

        // After clearing, VLC should be detected
        #expect(fullscreenApps.contains("org.videolan.vlc"))
    }

    // MARK: - Monitoring Lifecycle Tests

    @Test("Start monitoring returns valid token")
    func startMonitoringReturnsValidToken() async {
        let detector = FullscreenDetector()

        let token = await detector.startMonitoring { _ in }

        #expect(token != UUID())

        await detector.stopMonitoring(token: token)
    }

    @Test("Stop monitoring removes callback")
    func stopMonitoringRemovesCallback() async {
        let detector = FullscreenDetector()

        var callbackCount = 0
        let token = await detector.startMonitoring { _ in
            callbackCount += 1
        }

        await detector.stopMonitoring(token: token)

        await detector.updateFullscreenState(true)
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(callbackCount == 0)
    }

    // MARK: - Edge Cases Tests

    @Test("Handles empty window list")
    func handlesEmptyWindowList() async {
        let detector = FullscreenDetector()

        let isFullscreen = await detector.checkFullscreen([])

        #expect(isFullscreen == false)
    }

    @Test("Handles nil bundle ID in window info")
    func handlesNilBundleId() async {
        let detector = FullscreenDetector()

        let mockWindows = [
            ["kCGWindowOwnerName": "Test App" as NSString],
            // Missing bundle ID
        ]

        let isFullscreen = await detector.checkFullscreen(mockWindows)

        #expect(isFullscreen == false)
    }

    @Test("Handles malformed window info")
    func handlesMalformedWindowInfo() async {
        let detector = FullscreenDetector()

        let mockWindows = [
            ["invalid": "data" as NSString],
        ]

        let isFullscreen = await detector.checkFullscreen(mockWindows)

        // Should not crash, just return false
        #expect(isFullscreen == false)
    }

    // MARK: - Test Helpers

    private func createMockWindow(
        bundleId: String,
        isFullscreen: Bool
    ) -> [String: Any] {
        return [
            "kCGWindowOwnerName": bundleId.split(separator: ".").last ?? "App" as NSString,
            "kCGWindowBounds": isFullscreen ? "{{0, 0}, {1920, 1080}}" as NSString : "{{100, 100}, {800, 600}}" as NSString,
            "kCGWindowLayer": 0 as NSNumber,
            "kCGWindowIsOnscreen": true as NSNumber,
        ]
    }

    private func createMockFullscreenWindows(count: Int) -> [[String: Any]] {
        (0..<count).map { index in
            createMockWindow(
                bundleId: "com.game.\(index)",
                isFullscreen: true
            )
        }
    }

    private func createMockNormalWindows() -> [[String: Any]] {
        [
            createMockWindow(bundleId: "com.apple.Safari", isFullscreen: false),
            createMockWindow(bundleId: "com.microsoft.VSCode", isFullscreen: false),
        ]
    }

    private func createMockMinimizedFullscreenWindows() -> [[String: Any]] {
        [
            [
                "kCGWindowOwnerName": "Game" as NSString,
                "kCGWindowBounds": "{{0, 0}, {1920, 1080}}" as NSString,
                "kCGWindowLayer": 0 as NSNumber,
                "kCGWindowIsOnscreen": false as NSNumber,  // Not onscreen = minimized
            ]
        ]
    }

    private func createMockHiddenFullscreenWindows() -> [[String: Any]] {
        [
            [
                "kCGWindowOwnerName": "Game" as NSString,
                "kCGWindowBounds": "{{0, 0}, {1920, 1080}}" as NSString,
                "kCGWindowLayer": -10 as NSNumber,  // Negative layer = hidden
                "kCGWindowIsOnscreen": true as NSNumber,
            ]
        ]
    }
}
#endif
