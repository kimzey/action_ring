import Foundation
#if canImport(AppKit)
import AppKit

// MARK: - Profile Provider

/// Resolves a `RingProfile` for the current context. Implemented by `ProfileStore`.
public protocol ProfileProvider: AnyObject, Sendable {
    /// Best profile for a bundle id, walking: exact id → category → default.
    func resolveProfile(forBundleId bundleId: String?, category: AppCategory) -> RingProfile
}

// MARK: - Context Engine

/// Watches app switches and publishes the resolved `RingProfile` for the
/// frontmost app. Debounces rapid switches so the ring profile doesn't thrash.
@MainActor
public final class ContextEngine {

    private let appDetector: AppDetector
    private weak var provider: ProfileProvider?
    private let debounceInterval: TimeInterval

    private var monitorToken: UUID?
    private var debounceWork: DispatchWorkItem?

    public private(set) var currentBundleId: String?
    public private(set) var currentProfile: RingProfile

    /// Called whenever the active profile changes.
    public var onProfileChange: ((RingProfile) -> Void)?

    public init(
        appDetector: AppDetector,
        provider: ProfileProvider,
        debounceInterval: TimeInterval = 0.25
    ) {
        self.appDetector = appDetector
        self.provider = provider
        self.debounceInterval = debounceInterval
        self.currentProfile = provider.resolveProfile(
            forBundleId: appDetector.focusedAppBundleId(),
            category: appDetector.category(forBundleId: appDetector.focusedAppBundleId() ?? "")
        )
        self.currentBundleId = appDetector.focusedAppBundleId()
    }

    public func start() {
        guard monitorToken == nil else { return }
        // Emit the initial profile so listeners are primed.
        onProfileChange?(currentProfile)
        monitorToken = appDetector.startMonitoring { [weak self] bundleId in
            self?.scheduleResolve(for: bundleId)
        }
    }

    public func stop() {
        if let token = monitorToken { appDetector.stopMonitoring(token) }
        monitorToken = nil
        debounceWork?.cancel()
        debounceWork = nil
    }

    /// Force an immediate re-resolution (e.g. after the user edits a profile).
    public func refresh() {
        resolve(for: appDetector.focusedAppBundleId())
    }

    private func scheduleResolve(for bundleId: String?) {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.resolve(for: bundleId) }
        debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    private func resolve(for bundleId: String?) {
        guard let provider else { return }
        let category = appDetector.category(forBundleId: bundleId ?? "")
        let profile = provider.resolveProfile(forBundleId: bundleId, category: category)
        currentBundleId = bundleId
        guard profile.id != currentProfile.id else { return }
        currentProfile = profile
        onProfileChange?(profile)
    }
}

#endif
