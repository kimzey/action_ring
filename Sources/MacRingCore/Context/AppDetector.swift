import Foundation
#if canImport(AppKit)
import AppKit

// MARK: - Running App Info

/// Information about a running application
public struct RunningApp: Sendable {
    public let bundleIdentifier: String
    public let appName: String
    public let processIdentifier: pid_t
}

// MARK: - App Detector

/// Detects the currently focused application and monitors app switches
public final class AppDetector {

    // MARK: - Properties

    private var monitoringCallbacks: [UUID: (String?) -> Void] = [:]
    private var fullscreenCallbacks: [UUID: (Bool) -> Void] = [:]
    private let workspace = NSWorkspace.shared
    private let callbackQueue = DispatchQueue(label: "com.macring.appdetector")

    // MARK: - Bundle ID to Category Mapping

    private let categoryMappings: [String: AppCategory] = [
        // IDEs
        "com.apple.dt.Xcode": .ide,
        "com.microsoft.VSCode": .ide,
        "com.jetbrains.intellij": .ide,
        "com.jetbrains.intellij.ce": .ide,
        "com.jetbrains.AppCode": .ide,
        "com.jetbrains.CLion": .ide,
        "com.jetbrains.pycharm": .ide,
        "com.jetbrains.rider": .ide,
        "com.google.android.studio": .ide,
        "org.eclipse.ide": .ide,
        "com.sublimetext.4": .ide,
        "com.microsoft.VSCodeInsiders": .ide,
        "io.vscode": .ide,
        "com.froglogic.Squish": .ide,
        "net.sourceforge.ProjectHub": .ide,

        // Browsers
        "com.apple.Safari": .browser,
        "com.google.Chrome": .browser,
        "com.google.Chrome.beta": .browser,
        "com.google.Chrome.dev": .browser,
        "com.google.Chrome.canary": .browser,
        "org.mozilla.firefox": .browser,
        "com.mozillafirefox": .browser,
        "com.microsoft.edgemac": .browser,
        "com.brave.Browser": .browser,
        "com.operasoftware.Opera": .browser,
        "com.vivaldi.Vivaldi": .browser,
        "org.torproject.torbrowser": .browser,
        "com.arc.arc": .browser,

        // Design Tools
        "com.figma.Desktop": .design,
        "com.figma.Agent": .design,
        "com.adobe.Photoshop": .design,
        "com.adobe.Illustrator": .design,
        "com.adobe.AfterEffects": .design,
        "com.adobe.Premiere": .design,
        "com.adobe.Lightroom": .design,
        "com.adobe.Indesign": .design,
        "com.adobe.XD": .design,
        "com.sketch.sketch": .design,
        "com.bohemiancoding.sketch3": .design,
        "com.protopie.Protopie": .design,
        "com.invisionapp.InvisionStudio": .design,
        "com.axure.axureRP": .design,
        "com.adobe.Dimension": .design,
        "com.adobe.CharacterAnimator": .design,
        "com.seriflabs.affinityphoto": .design,
        "com.seriflabs.affinitydesigner": .design,
        "com.autodesk.SketchBook": .design,
        "com.blenderfoundation.blender": .design,
        "us.zoom.Zoom": .communication,

        // Communication
        "us.zoom.xos": .communication,
        "com.hnc.Discord": .communication,
        "com.hnc.Discord.Canary": .communication,
        "com.slack.Slack": .communication,
        "com.microsoft.teams": .communication,
        "com.microsoft.teams2": .communication,
        "ru.yandex.YandexMessenger": .communication,
        "org.telegram.TelegramDesktop": .communication,
        "com.spotify.client": .media,
        "com.apple.Music": .media,
        "com.apple.TV": .media,
        "com.spotify.Playground": .media,

        // Productivity
        "com.microsoft.Word": .productivity,
        "com.microsoft.Excel": .productivity,
        "com.microsoft.PowerPoint": .productivity,
        "com.microsoft.onenote.mac": .productivity,
        "com.microsoft.Outlook": .productivity,
        "com.apple.iWork.Pages": .productivity,
        "com.apple.iWork.Numbers": .productivity,
        "com.apple.iWork.Keynote": .productivity,
        "com.apple.Notes": .productivity,
        "com.apple.reminders": .productivity,
        "com.apple.calculator": .productivity,
        "notion.id": .productivity,
        "com.electron.notion": .productivity,
        "com.agilebits.onepassword-osx-helper": .productivity,
        "com.agilebits.onepassword7": .productivity,
        "xyz.obsidian.Obsidian": .productivity,
        "com.typora.typora-free": .productivity,
        "com.barebones.TextWrangler": .productivity,
        "com.macromates.TextMate": .productivity,
        "com.microsoft.VSCode": .ide,
        "com.github.GitHubDesktop": .development,

        // Development
        "com.github.SourceTree": .development,
        "com.gitbox.mac": .development,
        "com.jn.ftpathmachet": .development,
        "it.bloop.Studio": .development,
        "com.kodakinspires.CleanMyMac4": .development,
        "com.postmanlabs.mac": .development,
        "com.fuelapp.Fuel": .development,
        "com.dessault.FoxitReader": .development,
        "com.apple.dt.Xcode": .ide,

        // Terminal
        "com.apple.Terminal": .terminal,
        "com.googlecode.iterm2": .terminal,
        "co.zeb.zebra": .terminal,
        "com.warp.Warp-Stable": .terminal,
        "net.kovidgoyal.kitty": .terminal,
        "org.alacritty": .terminal,

        // Media
        "com.apple.iTunes": .media,
        "com.apple.QuickTimePlayerX": .media,
        "org.videolan.vlc": .media,
        "tv.twitch.Teleparty": .media,
        "com.spotify.client": .media,
        "com.soundcloud.desktop": .media,

        // System
        "com.apple.finder": .other,
        "com.apple.systempreferences": .other,
        "com.apple.preferences": .other,
    ]

    // MARK: - Get Focused App

    /// Returns the bundle identifier of the currently focused application
    /// - Returns: Bundle ID string, or nil if unable to detect
    public func focusedAppBundleId() async -> String? {
        workspace.frontmostApplication?.bundleIdentifier
    }

    /// Returns the name of the currently focused application
    /// - Returns: App name, or nil if unable to detect
    public func focusedAppName() async -> String? {
        workspace.frontmostApplication?.localizedName
    }

    // MARK: - Category Detection

    /// Determines the app category for a given bundle ID
    /// - Parameter bundleId: The app's bundle identifier
    /// - Returns: The app's category
    public func category(forBundleId bundleId: String) -> AppCategory {
        // Direct match
        if let category = categoryMappings[bundleId] {
            return category
        }

        // Prefix match (for app variants)
        for (mappedId, category) in categoryMappings {
            if bundleId.hasPrefix(mappedId) {
                return category
            }
        }

        // Suffix-based heuristics
        if bundleId.contains("IDE") || bundleId.contains("code") || bundleId.contains("Code") {
            return .ide
        }
        if bundleId.contains("browser") || bundleId.contains("Browser") {
            return .browser
        }
        if bundleId.contains("design") || bundleId.contains("Design") {
            return .design
        }
        if bundleId.contains("terminal") || bundleId.contains("Terminal") {
            return .terminal
        }

        return .other
    }

    // MARK: - App Monitoring

    /// Start monitoring for app focus changes
    /// - Parameter callback: Closure called when the focused app changes
    /// - Returns: A token to use when stopping monitoring
    @discardableResult
    public func startMonitoring(callback: @escaping (String?) -> Void) async -> UUID {
        let token = UUID()

        callbackQueue.async { [weak self] in
            self?.monitoringCallbacks[token] = callback
        }

        // Set up NSWorkspace observer if not already set
        if monitoringCallbacks.count == 1 {
            setupWorkspaceObserver()
        }

        return token
    }

    /// Stop monitoring with the given token
    /// - Parameter token: The token returned from startMonitoring
    public func stopMonitoring(token: UUID) async {
        callbackQueue.async { [weak self] in
            self?.monitoringCallbacks.removeValue(forKey: token)

            // Remove observer if no more callbacks
            if let self = self, self.monitoringCallbacks.isEmpty {
                self.removeWorkspaceObserver()
            }
        }
    }

    /// Stop all app monitoring
    public func stopMonitoring() async {
        callbackQueue.async { [weak self] in
            self?.monitoringCallbacks.removeAll()
            self?.removeWorkspaceObserver()
        }
    }

    // MARK: - Fullscreen Monitoring

    /// Start monitoring for fullscreen state changes
    /// - Parameter callback: Closure called when fullscreen state changes
    /// - Returns: A token to use when stopping monitoring
    @discardableResult
    public func startMonitoringFullscreen(callback: @escaping (Bool) -> Void) async -> UUID {
        let token = UUID()

        callbackQueue.async { [weak self] in
            self?.fullscreenCallbacks[token] = callback
        }

        return token
    }

    /// Stop fullscreen monitoring with the given token
    /// - Parameter token: The token returned from startMonitoringFullscreen
    public func stopMonitoringFullscreen(token: UUID) async {
        callbackQueue.async { [weak self] in
            self?.fullscreenCallbacks.removeValue(forKey: token)
        }
    }

    /// Check if the current app is in fullscreen mode
    /// - Returns: true if fullscreen, false otherwise
    public func isCurrentAppFullscreen() async -> Bool {
        guard let frontmostApp = workspace.frontmostApplication else {
            return false
        }

        // Check if the app's window is fullscreen
        let options = NSApplication.ActivationPolicy.options
        return frontmostApp.activationPolicy == .regular
    }

    // MARK: - Running Apps

    /// Get list of currently running applications
    /// - Returns: Array of RunningApp info
    public func runningApps() async -> [RunningApp] {
        workspace.runningApplications.compactMap { app in
            guard let bundleId = app.bundleIdentifier,
                  let appName = app.localizedName else {
                return nil
            }
            return RunningApp(
                bundleIdentifier: bundleId,
                appName: appName,
                processIdentifier: app.processIdentifier
            )
        }
    }

    // MARK: - Private: Workspace Observer

    private var workspaceObserver: NSObjectProtocol?

    private func setupWorkspaceObserver() {
        guard workspaceObserver == nil else { return }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] notification in
            guard let self = self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }

            let bundleId = app.bundleIdentifier

            // Notify all monitoring callbacks
            self.callbackQueue.async {
                for callback in self.monitoringCallbacks.values {
                    DispatchQueue.main.async {
                        callback(bundleId)
                    }
                }
            }
        }
    }

    private func removeWorkspaceObserver() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
    }

    deinit {
        removeWorkspaceObserver()
    }
}

#endif
