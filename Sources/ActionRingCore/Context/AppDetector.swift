import Foundation
#if canImport(AppKit)
import AppKit

// MARK: - Running App

public struct RunningApp: Sendable, Equatable {
    public let bundleIdentifier: String
    public let appName: String
    public let processIdentifier: pid_t
}

// MARK: - App Detector

/// Detects the focused application and monitors app-switch events.
///
/// Privacy: reads the bundle identifier, process identifier, and localized
/// display name only — never window titles, document paths, keyboard input, or
/// any window/document contents. (`localizedName` is the user-facing app name,
/// which varies by system locale; it is public bundle metadata.)
public final class AppDetector: @unchecked Sendable {

    private let workspace = NSWorkspace.shared
    private var observer: NSObjectProtocol?
    private var callbacks: [UUID: @MainActor (String?) -> Void] = [:]

    public init() {}

    deinit { removeObserver() }

    // MARK: Focused app

    public func focusedAppBundleId() -> String? {
        workspace.frontmostApplication?.bundleIdentifier
    }

    public func focusedAppName() -> String? {
        workspace.frontmostApplication?.localizedName
    }

    // MARK: Category mapping

    /// Maps a bundle id to a coarse category. Bundle ids are unique keys
    /// (deliberately de-duplicated to avoid a dictionary-literal trap), with
    /// heuristic fallbacks for unknown ids.
    public func category(forBundleId bundleId: String) -> AppCategory {
        if let c = Self.categoryMap[bundleId] { return c }
        for (id, c) in Self.categoryMap where bundleId.hasPrefix(id) { return c }

        let lower = bundleId.lowercased()
        if lower.contains("code") || lower.contains("ide") || lower.contains("jetbrains") { return .ide }
        if lower.contains("browser") || lower.contains("chrome") || lower.contains("firefox") { return .browser }
        if lower.contains("term") || lower.contains("iterm") { return .terminal }
        if lower.contains("design") || lower.contains("figma") || lower.contains("sketch") { return .design }
        return .other
    }

    static let categoryMap: [String: AppCategory] = [
        // IDEs / editors
        "com.apple.dt.Xcode": .ide,
        "com.microsoft.VSCode": .ide,
        "com.microsoft.VSCodeInsiders": .ide,
        "com.todesktop.230313mzl4w4u92": .ide,        // Cursor
        "dev.zed.Zed": .ide,
        "com.jetbrains.intellij": .ide,
        "com.jetbrains.intellij.ce": .ide,
        "com.jetbrains.pycharm": .ide,
        "com.jetbrains.WebStorm": .ide,
        "com.jetbrains.goland": .ide,
        "com.jetbrains.CLion": .ide,
        "com.jetbrains.rider": .ide,
        "com.google.android.studio": .ide,
        "com.sublimetext.4": .ide,
        // Browsers
        "com.apple.Safari": .browser,
        "com.google.Chrome": .browser,
        "org.mozilla.firefox": .browser,
        "com.microsoft.edgemac": .browser,
        "com.brave.Browser": .browser,
        "company.thebrowser.Browser": .browser,        // Arc
        "com.operasoftware.Opera": .browser,
        "com.vivaldi.Vivaldi": .browser,
        // Design
        "com.figma.Desktop": .design,
        "com.adobe.Photoshop": .design,
        "com.adobe.Illustrator": .design,
        "com.adobe.AfterEffects": .design,
        "com.bohemiancoding.sketch3": .design,
        "com.seriflabs.affinityphoto2": .design,
        "com.seriflabs.affinitydesigner2": .design,
        "org.blenderfoundation.blender": .design,
        // Communication
        "com.tinyspeck.slackmacgap": .communication,
        "com.hnc.Discord": .communication,
        "com.microsoft.teams2": .communication,
        "us.zoom.xos": .communication,
        "ru.keepcoder.Telegram": .communication,
        "net.whatsapp.WhatsApp": .communication,
        "com.apple.mail": .communication,
        // Productivity
        "com.microsoft.Word": .productivity,
        "com.microsoft.Excel": .productivity,
        "com.microsoft.Powerpoint": .productivity,
        "com.microsoft.Outlook": .productivity,
        "com.apple.iWork.Pages": .productivity,
        "com.apple.iWork.Numbers": .productivity,
        "com.apple.iWork.Keynote": .productivity,
        "com.apple.Notes": .productivity,
        "notion.id": .productivity,
        "md.obsidian": .productivity,
        "com.linear": .productivity,
        // Media
        "com.spotify.client": .media,
        "com.apple.Music": .media,
        "com.apple.TV": .media,
        "org.videolan.vlc": .media,
        "com.colliderli.iina": .media,
        // Development tools
        "com.github.GitHubDesktop": .development,
        "com.sourcetreeapp": .development,
        "com.postmanlabs.mac": .development,
        "com.tinyapp.TablePlus": .development,
        "com.docker.docker": .development,
        // Terminals
        "com.apple.Terminal": .terminal,
        "com.googlecode.iterm2": .terminal,
        "dev.warp.Warp-Stable": .terminal,
        "net.kovidgoyal.kitty": .terminal,
        "org.alacritty": .terminal,
        "com.github.wez.wezterm": .terminal,
        // System
        "com.apple.finder": .other,
        "com.apple.systempreferences": .other,
    ]

    // MARK: Running apps

    public func runningApps() -> [RunningApp] {
        workspace.runningApplications.compactMap { app in
            guard let id = app.bundleIdentifier, let name = app.localizedName else { return nil }
            return RunningApp(bundleIdentifier: id, appName: name, processIdentifier: app.processIdentifier)
        }
    }

    /// Apps a profile can target: currently-running regular apps, de-duplicated
    /// and sorted by name. (Plus any known mapped ids the editor merges in.)
    public func selectableApps() -> [RunningApp] {
        var seen = Set<String>()
        var out: [RunningApp] = []
        for app in workspace.runningApplications where app.activationPolicy == .regular {
            guard let id = app.bundleIdentifier, let name = app.localizedName, !seen.contains(id) else { continue }
            seen.insert(id)
            out.append(RunningApp(bundleIdentifier: id, appName: name, processIdentifier: app.processIdentifier))
        }
        return out.sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }

    // MARK: Monitoring

    /// Begin observing frontmost-app changes. The callback runs on the main actor.
    @discardableResult
    public func startMonitoring(_ callback: @escaping @MainActor (String?) -> Void) -> UUID {
        let token = UUID()
        callbacks[token] = callback
        if observer == nil { installObserver() }
        return token
    }

    public func stopMonitoring(_ token: UUID) {
        callbacks.removeValue(forKey: token)
        if callbacks.isEmpty { removeObserver() }
    }

    private func installObserver() {
        observer = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleId = app?.bundleIdentifier
            // Snapshot to a concrete array: a callback may call stopMonitoring()
            // reentrantly, and iterating the live `.values` view would trap.
            let cbs = Array(self.callbacks.values)
            MainActor.assumeIsolated {
                for cb in cbs { cb(bundleId) }
            }
        }
    }

    private func removeObserver() {
        if let observer {
            workspace.notificationCenter.removeObserver(observer)
            self.observer = nil
        }
    }
}

#endif
