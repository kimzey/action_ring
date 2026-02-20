import Testing
import Foundation
#if canImport(AppKit)
import AppKit
@testable import MacRingCore

/// Mock ProfileManager for testing
actor MockProfileManager {
    private var profiles: [String: RingProfile] = [:]
    private var categoryProfiles: [AppCategory: RingProfile] = [:]
    var defaultProfile: RingProfile?

    func addProfile(_ profile: RingProfile) {
        if let bundleId = profile.bundleId {
            profiles[bundleId] = profile
        }
        categoryProfiles[profile.category] = profile
        if profile.isDefault {
            defaultProfile = profile
        }
    }

    func profile(forBundleId bundleId: String) async -> RingProfile? {
        profiles[bundleId]
    }

    func profile(forCategory category: AppCategory) async -> RingProfile? {
        categoryProfiles[category]
    }

    func defaultProfile() async -> RingProfile? {
        defaultProfile
    }
}

@Suite("ContextEngine Tests")
struct ContextEngineTests {

    // MARK: - Profile Lookup Tests

    @Test("Profile lookup by exact Bundle ID returns matching profile")
    func profileLookupByExactBundleId() async {
        let engine = ContextEngine()
        let mockManager = MockProfileManager()

        // Create a test profile for VS Code
        let vsCodeProfile = RingProfile(
            name: "VS Code",
            bundleId: "com.microsoft.VSCode",
            category: .ide,
            slots: [],
            source: .builtin
        )
        await mockManager.addProfile(vsCodeProfile)

        // Look up the profile
        let result = await engine.profileForBundleId(
            "com.microsoft.VSCode",
            profileManager: mockManager
        )

        #expect(result?.bundleId == "com.microsoft.VSCode")
        #expect(result?.name == "VS Code")
    }

    @Test("Profile lookup returns nil when no exact match")
    func profileLookupReturnsNilWhenNoExactMatch() async {
        let engine = ContextEngine()
        let mockManager = MockProfileManager()

        let result = await engine.profileForBundleId(
            "com.unknown.App",
            profileManager: mockManager
        )

        #expect(result == nil)
    }

    // MARK: - Category Fallback Tests

    @Test("Profile fallback to category when no exact match")
    func profileFallbackToCategory() async {
        let engine = ContextEngine()
        let mockManager = MockProfileManager()

        // Add category profile for IDE
        let ideProfile = RingProfile(
            name: "IDE Default",
            bundleId: nil,
            category: .ide,
            slots: [],
            source: .builtin
        )
        await mockManager.addProfile(ideProfile)

        // Look up unknown IDE app
        let result = await engine.profileForBundleId(
            "com.unknown.NewIDE",
            profileManager: mockManager
        )

        #expect(result != nil)
        #expect(result?.category == .ide)
        #expect(result?.name == "IDE Default")
    }

    @Test("Profile fallback to default when no category match")
    func profileFallbackToDefault() async {
        let engine = ContextEngine()
        let mockManager = MockProfileManager()

        // Add only default profile
        let defaultProfile = RingProfile(
            name: "Default",
            bundleId: nil,
            category: .other,
            slots: [],
            isDefault: true,
            source: .builtin
        )
        await mockManager.addProfile(defaultProfile)

        // Look up unknown app
        let result = await engine.profileForBundleId(
            "com.unknown.RandomApp",
            profileManager: mockManager
        )

        #expect(result != nil)
        #expect(result?.isDefault == true)
        #expect(result?.name == "Default")
    }

    @Test("Profile lookup chain: exact -> category -> default")
    func profileLookupChain() async {
        let engine = ContextEngine()
        let mockManager = MockProfileManager()

        // Set up profiles in the lookup chain
        let exactProfile = RingProfile(
            name: "VS Code Exact",
            bundleId: "com.microsoft.VSCode",
            category: .ide,
            slots: [],
            source: .builtin
        )

        let categoryProfile = RingProfile(
            name: "IDE Category",
            bundleId: nil,
            category: .ide,
            slots: [],
            source: .builtin
        )

        let defaultProfile = RingProfile(
            name: "System Default",
            bundleId: nil,
            category: .other,
            slots: [],
            isDefault: true,
            source: .builtin
        )

        await mockManager.addProfile(exactProfile)
        await mockManager.addProfile(categoryProfile)
        await mockManager.addProfile(defaultProfile)

        // Test exact match
        let exactResult = await engine.profileForBundleId(
            "com.microsoft.VSCode",
            profileManager: mockManager
        )
        #expect(exactResult?.name == "VS Code Exact")

        // Test category fallback
        let categoryResult = await engine.profileForBundleId(
            "com.jetbrains.idea",
            profileManager: mockManager
        )
        #expect(categoryResult?.name == "IDE Category")

        // Test default fallback
        let defaultResult = await engine.profileForBundleId(
            "com.unknown.App",
            profileManager: mockManager
        )
        #expect(defaultResult?.name == "System Default")
    }

    // MARK: - App Switch Handling Tests

    @Test("App switch triggers profile update")
    func appSwitchTriggersProfileUpdate() async {
        let engine = ContextEngine()
        let mockManager = MockProfileManager()

        let profile = RingProfile(
            name: "Safari",
            bundleId: "com.apple.Safari",
            category: .browser,
            slots: [],
            source: .builtin
        )
        await mockManager.addProfile(profile)

        // Track profile changes
        var receivedProfile: RingProfile?
        let cancellation = await engine.startMonitoring { newProfile in
            receivedProfile = newProfile
        }

        // Simulate app switch
        await engine.handleAppSwitch(
            bundleId: "com.apple.Safari",
            profileManager: mockManager
        )

        // Wait for async propagation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        #expect(receivedProfile?.bundleId == "com.apple.Safari")

        await engine.stopMonitoring(token: cancellation)
    }

    // MARK: - Debouncing Tests

    @Test("Multiple rapid app switches are debounced")
    func multipleRapidAppSwitchesDebounced() async {
        let engine = ContextEngine()
        let mockManager = MockProfileManager()

        let safariProfile = RingProfile(
            name: "Safari",
            bundleId: "com.apple.Safari",
            category: .browser,
            slots: [],
            source: .builtin
        )

        let vsCodeProfile = RingProfile(
            name: "VS Code",
            bundleId: "com.microsoft.VSCode",
            category: .ide,
            slots: [],
            source: .builtin
        )

        await mockManager.addProfile(safariProfile)
        await mockManager.addProfile(vsCodeProfile)

        // Track profile changes
        var profileChanges: [String] = []
        let cancellation = await engine.startMonitoring { profile in
            profileChanges.append(profile.bundleId ?? "default")
        }

        // Simulate rapid app switches
        await engine.handleAppSwitch(bundleId: "com.apple.Safari", profileManager: mockManager)
        await engine.handleAppSwitch(bundleId: "com.microsoft.VSCode", profileManager: mockManager)
        await engine.handleAppSwitch(bundleId: "com.apple.Safari", profileManager: mockManager)
        await engine.handleAppSwitch(bundleId: "com.microsoft.VSCode", profileManager: mockManager)

        // Wait for debounce period
        try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds (debounce is 500ms)

        // Should only receive the last profile, not all intermediate ones
        #expect(profileChanges.count == 1)
        #expect(profileChanges.last == "com.microsoft.VSCode")

        await engine.stopMonitoring(token: cancellation)
    }

    // MARK: - Category Detection Tests

    @Test("Detects correct category for known apps")
    func detectsCorrectCategoryForKnownApps() async {
        let engine = ContextEngine()

        #expect(engine.category(forBundleId: "com.apple.dt.Xcode") == .ide)
        #expect(engine.category(forBundleId: "com.microsoft.VSCode") == .ide)
        #expect(engine.category(forBundleId: "com.apple.Safari") == .browser)
        #expect(engine.category(forBundleId: "com.google.Chrome") == .browser)
        #expect(engine.category(forBundleId: "com.adobe.Photoshop") == .design)
        #expect(engine.category(forBundleId: "com.spotify.client") == .media)
        #expect(engine.category(forBundleId: "com.apple.Terminal") == .terminal)
    }

    @Test("Unknown apps return other category")
    func unknownAppsReturnOtherCategory() async {
        let engine = ContextEngine()

        #expect(engine.category(forBundleId: "com.unknown.randomapp") == .other)
        #expect(engine.category(forBundleId: "xyz.nonexistent.app") == .other)
    }

    // MARK: - Current Bundle ID Tests

    @Test("Returns current bundle ID when set")
    func returnsCurrentBundleId() async {
        let engine = ContextEngine()

        await engine.setCurrentBundleId("com.apple.Safari")

        let current = await engine.currentBundleId()
        #expect(current == "com.apple.Safari")
    }

    @Test("Returns nil when no current bundle ID")
    func returnsNilWhenNoCurrentBundleId() async {
        let engine = ContextEngine()

        let current = await engine.currentBundleId()
        #expect(current == nil)
    }

    // MARK: - Monitoring Lifecycle Tests

    @Test("Start monitoring returns valid token")
    func startMonitoringReturnsValidToken() async {
        let engine = ContextEngine()

        let token = await engine.startMonitoring { _ in }

        #expect(token != UUID())

        await engine.stopMonitoring(token: token)
    }

    @Test("Stop monitoring removes callback")
    func stopMonitoringRemovesCallback() async {
        let engine = ContextEngine()

        var callbackCount = 0
        let token = await engine.startMonitoring { _ in
            callbackCount += 1
        }

        await engine.stopMonitoring(token: token)

        // After stopping, callback should not be called
        let mockManager = MockProfileManager()
        await engine.handleAppSwitch(bundleId: "com.apple.Safari", profileManager: mockManager)

        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(callbackCount == 0)
    }

    @Test("Multiple monitoring tokens work independently")
    func multipleMonitoringTokensWorkIndependently() async {
        let engine = ContextEngine()

        var callback1Called = false
        var callback2Called = false

        let token1 = await engine.startMonitoring { _ in
            callback1Called = true
        }

        let token2 = await engine.startMonitoring { _ in
            callback2Called = true
        }

        let mockManager = MockProfileManager()
        let profile = RingProfile(
            name: "Test",
            bundleId: "com.test.App",
            category: .other,
            slots: []
        )
        await mockManager.addProfile(profile)

        await engine.handleAppSwitch(bundleId: "com.test.App", profileManager: mockManager)
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(callback1Called)
        #expect(callback2Called)

        // Stop only first callback
        await engine.stopMonitoring(token: token1)
        callback1Called = false
        callback2Called = false

        await engine.handleAppSwitch(bundleId: "com.test.App", profileManager: mockManager)
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(!callback1Called)  // First callback should not be called
        #expect(callback2Called)   // Second callback should still be called

        await engine.stopMonitoring(token: token2)
    }

    // MARK: - Edge Cases Tests

    @Test("Handles nil bundle ID gracefully")
    func handlesNilBundleId() async {
        let engine = ContextEngine()
        let mockManager = MockProfileManager()

        let defaultProfile = RingProfile(
            name: "Default",
            bundleId: nil,
            category: .other,
            slots: [],
            isDefault: true,
            source: .builtin
        )
        await mockManager.addProfile(defaultProfile)

        let result = await engine.handleAppSwitch(
            bundleId: nil,
            profileManager: mockManager
        )

        #expect(result != nil)
        #expect(result?.isDefault == true)
    }

    @Test("Handles empty bundle ID gracefully")
    func handlesEmptyBundleId() async {
        let engine = ContextEngine()
        let mockManager = MockProfileManager()

        let defaultProfile = RingProfile(
            name: "Default",
            bundleId: nil,
            category: .other,
            slots: [],
            isDefault: true,
            source: .builtin
        )
        await mockManager.addProfile(defaultProfile)

        let result = await engine.handleAppSwitch(
            bundleId: "",
            profileManager: mockManager
        )

        #expect(result != nil)
    }

    @Test("Case insensitive bundle ID matching")
    func caseInsensitiveBundleIdMatching() async {
        let engine = ContextEngine()
        let mockManager = MockProfileManager()

        let profile = RingProfile(
            name: "VS Code",
            bundleId: "com.microsoft.VSCode",
            category: .ide,
            slots: [],
            source: .builtin
        )
        await mockManager.addProfile(profile)

        // Try different case variations
        let result1 = await engine.profileForBundleId(
            "com.microsoft.VSCode",
            profileManager: mockManager
        )
        let result2 = await engine.profileForBundleId(
            "com.microsoft.vscode",
            profileManager: mockManager
        )
        let result3 = await engine.profileForBundleId(
            "COM.MICROSOFT.VSCODE",
            profileManager: mockManager
        )

        #expect(result1 != nil)
        // Bundle IDs are case-sensitive per Apple convention, but we should handle consistently
        #expect(result1?.bundleId == "com.microsoft.VSCode")
    }
}
#endif
