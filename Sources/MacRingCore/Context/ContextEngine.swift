import Foundation
#if canImport(AppKit)
import AppKit

// MARK: - Profile Provider Protocol

/// Protocol for profile lookup operations
public protocol ProfileProvider: Sendable {
    /// Find a profile by exact bundle ID match
    func profile(forBundleId bundleId: String) async -> RingProfile?

    /// Find a profile by category fallback
    func profile(forCategory category: AppCategory) async -> RingProfile?

    /// Get the default profile
    func `default`() async -> RingProfile?
}

// MARK: - Context Engine

/// Orchestrates app-aware profile switching
/// Listens to app switches and publishes profile changes
public final class ContextEngine: Sendable {

    // MARK: - Types

    /// Token for monitoring cancellation
    public struct MonitoringToken: Sendable, Hashable {
        let uuid: UUID
    }

    /// Callback for profile changes
    public typealias ProfileChangeCallback = @Sendable (RingProfile) -> Void

    // MARK: - Properties

    private let appDetector: AppDetector
    private let debounceInterval: TimeInterval

    private actor State {
        var currentBundleId: String?
        var lastSwitchTime: Date?
        var pendingBundleId: String?
        var monitoringCallbacks: [UUID: ProfileChangeCallback] = [:]
        var debounceTask: Task<Void, Never>?

        func setCurrentBundleId(_ bundleId: String?) {
            self.currentBundleId = bundleId
        }

        func setDebounceTask(_ task: Task<Void, Never>?) {
            self.debounceTask = task
        }
    }

    private let state: State
    private let callbackQueue = DispatchQueue(label: "com.macring.contextengine")

    // MARK: - Initializers

    /// Create a new ContextEngine
    /// - Parameters:
    ///   - appDetector: The app detector to use for monitoring app switches
    ///   - debounceInterval: Minimum time between profile updates (default: 500ms)
    public init(
        appDetector: AppDetector = AppDetector(),
        debounceInterval: TimeInterval = 0.5
    ) {
        self.appDetector = appDetector
        self.debounceInterval = debounceInterval
        self.state = State()
    }

    // MARK: - Public API

    /// Returns the current bundle ID
    public func currentBundleId() async -> String? {
        await state.currentBundleId
    }

    /// Sets the current bundle ID (for testing)
    public func setCurrentBundleId(_ bundleId: String) async {
        await state.setCurrentBundleId(bundleId)
    }

    /// Get the category for a given bundle ID
    public func category(forBundleId bundleId: String) -> AppCategory {
        appDetector.category(forBundleId: bundleId)
    }

    /// Find a profile for the given bundle ID using the lookup chain:
    /// 1. Exact Bundle ID match
    /// 2. MCP discovery (future)
    /// 3. App Category fallback
    /// 4. Default profile
    /// - Parameters:
    ///   - bundleId: The app's bundle identifier
    ///   - profileManager: The profile manager to query
    /// - Returns: The matching profile, or nil if no profile found
    public func profileForBundleId(
        _ bundleId: String,
        profileManager: some ProfileProvider
    ) async -> RingProfile? {
        // Skip empty or nil bundle IDs
        guard !bundleId.isEmpty else {
            return await profileManager.default()
        }

        // 1. Try exact bundle ID match
        if let profile = await profileManager.profile(forBundleId: bundleId) {
            return profile
        }

        // 2. MCP discovery - future implementation
        // TODO: Query MCP registry for app-specific tools

        // 3. Try category fallback
        let category = appDetector.category(forBundleId: bundleId)
        if let profile = await profileManager.profile(forCategory: category) {
            return profile
        }

        // 4. Return default profile
        return await profileManager.default()
    }

    /// Handle an app switch event
    /// - Parameters:
    ///   - bundleId: The new focused app's bundle ID (may be nil)
    ///   - profileManager: The profile manager to query
    /// - Returns: The profile that was selected, or nil if none found
    public func handleAppSwitch(
        bundleId: String?,
        profileManager: some ProfileProvider
    ) async -> RingProfile? {
        guard let bundleId = bundleId, !bundleId.isEmpty else {
            // Use default profile for nil/empty bundle IDs
            if let defaultProfile = await profileManager.default() {
                await notifyProfileChange(defaultProfile)
                return defaultProfile
            }
            return nil
        }

        // Check if this is actually a different app
        let currentId = await state.currentBundleId
        if currentId == bundleId {
            // Same app, no need to switch
            return nil
        }

        // Cancel any pending debounce task
        await cancelPendingDebounce()

        // Update current bundle ID immediately
        await state.setCurrentBundleId(bundleId)

        // Create new debounce task
        let task = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))

            // Check if we were cancelled
            guard !Task.isCancelled else { return }

            // Find and notify profile
            if let profile = await profileForBundleId(bundleId, profileManager: profileManager) {
                await notifyProfileChange(profile)
            }
        }

        await state.setDebounceTask(task)

        return nil
    }

    /// Start monitoring for profile changes
    /// - Parameter callback: Closure called when profile changes
    /// - Returns: A token to use when stopping monitoring
    @discardableResult
    public func startMonitoring(
        callback: @escaping ProfileChangeCallback
    ) async -> UUID {
        let uuid = UUID()
        await addCallback(uuid, callback)
        return uuid
    }

    /// Stop monitoring with the given token
    /// - Parameter token: The token returned from startMonitoring
    public func stopMonitoring(token: UUID) async {
        await removeCallback(token)
    }

    /// Start monitoring app switches via NSWorkspace
    /// - Parameters:
    ///   - profileManager: The profile manager to query for profiles
    ///   - callback: Closure called when profile changes
    /// - Returns: A monitoring token
    @discardableResult
    public func startMonitoringAppSwitches(
        profileManager: some ProfileProvider,
        callback: @escaping ProfileChangeCallback
    ) async -> UUID {
        let profileToken = await startMonitoring(callback: callback)

        // Start monitoring app switches
        _ = await appDetector.startMonitoring { [weak self] bundleId in
            guard let self = self else { return }
            await self.handleAppSwitch(bundleId: bundleId, profileManager: profileManager)
        }

        return profileToken
    }

    // MARK: - Private Methods

    private func addCallback(_ uuid: UUID, _ callback: ProfileChangeCallback) async {
        await state.monitoringCallbacks[uuid] = callback
    }

    private func removeCallback(_ uuid: UUID) async {
        await state.monitoringCallbacks.removeValue(forKey: uuid)
    }

    private func cancelPendingDebounce() async {
        if let task = await state.debounceTask {
            task.cancel()
            await state.setDebounceTask(nil)
        }
    }

    private func notifyProfileChange(_ profile: RingProfile) async {
        let callbacks = await state.monitoringCallbacks.values

        callbackQueue.async {
            for callback in callbacks {
                callback(profile)
            }
        }
    }
}

// MARK: - Default Profile Provider

extension RingProfile: ProfileProvider {
    public func profile(forBundleId bundleId: String) async -> RingProfile? {
        if self.bundleId == bundleId {
            return self
        }
        return nil
    }

    public func profile(forCategory category: AppCategory) async -> RingProfile? {
        if self.category == category && self.bundleId == nil {
            return self
        }
        return nil
    }

    public func `default`() async -> RingProfile? {
        if self.isDefault {
            return self
        }
        return nil
    }
}

#endif
