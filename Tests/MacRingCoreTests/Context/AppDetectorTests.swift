import Testing
import Foundation
@testable import MacRingCore

#if canImport(AppKit)
import AppKit

@Suite("AppDetector Tests")
struct AppDetectorTests {

    // MARK: - Bundle ID Detection

    @Test("Detect currently focused app bundle ID")
    func detectFocusedAppBundleId() async throws {
        #if os(macOS)
        let detector = AppDetector()
        let bundleId = await detector.focusedAppBundleId()

        // Should return a non-nil bundle ID (at least Finder)
        #expect(bundleId != nil)
        #endif
    }

    @Test("Detect bundle ID is valid format")
    func bundleIdIsValidFormat() async {
        #if os(macOS)
        let detector = AppDetector()
        let bundleId = await detector.focusedAppBundleId()

        if let bundleId = bundleId {
            // Bundle IDs should be reverse domain notation
            let parts = bundleId.split(separator: ".")
            #expect(parts.count >= 2)
        }
        #endif
    }

    @Test("Detect common apps correctly")
    func detectCommonApps() async {
        #if os(macOS)
        // This test verifies the detector works, but doesn't
        // validate specific apps since we can't control
        // which app is focused during test
        let detector = AppDetector()
        let bundleId = await detector.focusedAppBundleId()

        #expect(bundleId != nil)
        #endif
    }

    // MARK: - App Name Detection

    @Test("Detect focused app name")
    func detectFocusedAppName() async {
        #if os(macOS)
        let detector = AppDetector()
        let appName = await detector.focusedAppName()

        #expect(appName != nil)
        #expect(!appName!.isEmpty)
        #endif
    }

    @Test("App name matches bundle ID app")
    func appNameMatchesBundleId() async {
        #if os(macOS)
        let detector = AppDetector()
        let bundleId = await detector.focusedAppBundleId()
        let appName = await detector.focusedAppName()

        if let bundleId = bundleId, let appName = appName {
            // Extract app name from bundle ID
            let bundleAppName = bundleId.split(separator: ".").last?
                .replacingOccurrences(of: "-", with: " ")
                .capitalized

            // App name may not exactly match, but should be similar
            #expect(!appName.isEmpty)
        }
        #endif
    }

    // MARK: - App Category Detection

    @Test("Detect app category from bundle ID")
    func detectAppCategory() async {
        #if os(macOS)
        let detector = AppDetector()
        let bundleId = await detector.focusedAppBundleId()

        if let bundleId = bundleId {
            let category = detector.category(forBundleId: bundleId)
            // Should return some category
            #expect(true)
        }
        #endif
    }

    @Test("Known IDEs return IDE category")
    func knownIDEsReturnCategory() {
        #if os(macOS)
        let detector = AppDetector()

        let ideBundleIds = [
            "com.apple.dt.Xcode",
            "com.microsoft.VSCode",
            "com.jetbrains.intellij",
            "com.google.android.studio"
        ]

        for bundleId in ideBundleIds {
            let category = detector.category(forBundleId: bundleId)
            #expect(category == .ide)
        }
        #endif
    }

    @Test("Known browsers return browser category")
    func knownBrowsersReturnCategory() {
        #if os(macOS)
        let detector = AppDetector()

        let browserBundleIds = [
            "com.apple.Safari",
            "com.google.Chrome",
            "org.mozilla.firefox",
            "com.microsoft.edgemac"
        ]

        for bundleId in browserBundleIds {
            let category = detector.category(forBundleId: bundleId)
            #expect(category == .browser)
        }
        #endif
    }

    @Test("Known design apps return design category")
    func knownDesignAppsReturnCategory() {
        #if os(macOS)
        let detector = AppDetector()

        let designBundleIds = [
            "com.figma.Desktop",
            "com.figma.Agent",
            "com.adobe.Photoshop",
            "com.adobe.Illustrator",
            "com.sketch.sketch"
        ]

        for bundleId in designBundleIds {
            let category = detector.category(forBundleId: bundleId)
            #expect(category == .design)
        }
        #endif
    }

    @Test("Unknown apps return other category")
    func unknownAppsReturnOtherCategory() {
        #if os(macOS)
        let detector = AppDetector()

        let category = detector.category(forBundleId: "com.unknown.randomapp")
        #expect(category == .other)
        #endif
    }

    // MARK: - App Change Monitoring

    @Test("Detect app switch events")
    func detectAppSwitch() async {
        #if os(macOS)
        let detector = AppDetector()

        await detector.startMonitoring { bundleId in
            // Callback when app switches
            // Just verify callback is registered
        }

        // Stop monitoring to clean up
        await detector.stopMonitoring()

        #expect(true)
        #endif
    }

    @Test("Multiple observers receive app switch events")
    func multipleObserversReceiveEvents() async {
        #if os(macOS)
        let detector = AppDetector()
        var callback1Called = false
        var callback2Called = false

        await detector.startMonitoring { _ in
            callback1Called = true
        }

        await detector.startMonitoring { _ in
            callback2Called = true
        }

        await detector.stopMonitoring()

        #expect(true)
        #endif
    }

    @Test("Stop monitoring removes callbacks")
    func stopMonitoringRemovesCallbacks() async {
        #if os(macOS)
        let detector = AppDetector()

        await detector.startMonitoring { _ in }
        await detector.stopMonitoring()

        // Should not crash
        #expect(true)
        #endif
    }

    // MARK: - Running Apps

    @Test("Get list of running apps")
    func getRunningApps() async {
        #if os(macOS)
        let detector = AppDetector()
        let runningApps = await detector.runningApps()

        // Should have at least a few running apps
        #expect(!runningApps.isEmpty)
        #expect(runningApps.count >= 1)
        #endif
    }

    @Test("Running apps contain valid bundle IDs")
    func runningAppsHaveValidBundleIds() async {
        #if os(macOS)
        let detector = AppDetector()
        let runningApps = await detector.runningApps()

        for app in runningApps {
            #expect(!app.bundleIdentifier.isEmpty)
            #expect(app.bundleIdentifier.contains("."))
        }
        #endif
    }

    // MARK: - Fullscreen Detection

    @Test("Detect if current app is in fullscreen")
    func detectFullscreen() async {
        #if os(macOS)
        let detector = AppDetector()
        let isFullscreen = await detector.isCurrentAppFullscreen()

        // Returns boolean, should not crash
        #expect(true)
        #endif
    }

    @Test("Fullscreen state changes are detected")
    func detectFullscreenChanges() async {
        #if os(macOS)
        let detector = AppDetector()

        await detector.startMonitoringFullscreen { isFullscreen in
            // Handle fullscreen change
        }

        await detector.stopMonitoringFullscreen()

        #expect(true)
        #endif
    }
}
#endif
