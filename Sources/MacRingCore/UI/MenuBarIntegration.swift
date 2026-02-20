import Foundation
#if canImport(AppKit)
import AppKit

// MARK: - Menu Bar Delegate

/// Delegate protocol for menu bar actions
public protocol MenuBarDelegate: AnyObject {
    func menuBarDidRequestOpenConfigurator()
    func menuBarDidRequestQuit()
    func menuBarDidToggleRing()
    func menuBarDidRequestHelp()
}

// MARK: - Menu Bar Integration

/// Manages the menu bar icon and menu
public final class MenuBarIntegration {

    // MARK: - Properties

    public weak var delegate: MenuBarDelegate?

    private let statusItem: NSStatusItem
    private var statusBarMenu: NSMenu

    // MARK: - Constants

    private static let statusBarButtonLength: CGFloat = NSStatusItem.variableLength

    // MARK: - Initializer

    public init() {
        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: Self.statusBarButtonLength)

        // Set up menu
        statusBarMenu = NSMenu(title: "MacRing")
        setupMenu()

        // Set icon
        updateIcon()

        // Enable item
        statusItem.isVisible = true
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    // MARK: - Menu Setup

    private func setupMenu() {
        // App info section
        let appNameItem = NSMenuItem(title: "MacRing", action: nil, keyEquivalent: "")
        appNameItem.isEnabled = false
        statusBarMenu.addItem(appNameItem)

        statusBarMenu.addItem(NSMenuItem.separator())

        // Ring control
        let showRingItem = NSMenuItem(
            title: "Show Ring (Hold Button)",
            action: #selector(showRingClicked),
            keyEquivalent: ""
        )
        showRingItem.target = self
        statusBarMenu.addItem(showRingItem)

        statusBarMenu.addItem(NSMenuItem.separator())

        // Configuration
        let configItem = NSMenuItem(
            title: "Open Configurator…",
            action: #selector(openConfigurator),
            keyEquivalent: ","
        )
        configItem.target = self
        configItem.keyEquivalentModifierMask = [.command, .shift]
        statusBarMenu.addItem(configItem)

        statusBarMenu.addItem(NSMenuItem.separator())

        // Help
        let helpItem = NSMenuItem(
            title: "Help & Documentation",
            action: #selector(showHelp),
            keyEquivalent: "?"
        )
        helpItem.target = self
        statusBarMenu.addItem(helpItem)

        statusBarMenu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit MacRing",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        statusBarMenu.addItem(quitItem)

        statusItem.menu = statusBarMenu
    }

    // MARK: - Icon Management

    private func updateIcon() {
        if let button = statusItem.button {
            // Use SF Symbol for ring icon
            button.image = NSImage(systemSymbolName: "circle.circle", accessibilityDescription: "MacRing")
            button.image?.isTemplate = true
        }
    }

    public func setIcon(_ image: NSImage) {
        statusItem.button?.image = image
    }

    public func setTitle(_ title: String) {
        statusItem.button?.title = title
    }

    // MARK: - Menu Actions

    @objc private func showRingClicked() {
        delegate?.menuBarDidToggleRing()
    }

    @objc private func openConfigurator() {
        delegate?.menuBarDidRequestOpenConfigurator()
    }

    @objc private func showHelp() {
        delegate?.menuBarDidRequestHelp()
    }

    @objc private func quit() {
        delegate?.menuBarDidRequestQuit()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Public Methods

    /// Show a tooltip in the menu bar
    public func showTooltip(_ message: String, for duration: TimeInterval = 2.0) {
        guard let button = statusItem.button else { return }

        let originalToolTip = button.toolTip
        button.toolTip = message

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.statusItem.button?.toolTip = originalToolTip
        }
    }

    /// Update the menu items based on app state
    public func updateMenuState(isRingEnabled: Bool) {
        guard let items = statusItem.menu?.items else { return }

        for item in items {
            if item.title == "Show Ring (Hold Button)" {
                item.state = isRingEnabled ? .on : .off
            }
        }
    }

    /// Update profile indicator in menu
    public func updateCurrentProfile(_ profileName: String) {
        guard let items = statusItem.menu?.items else { return }

        // Find and update the app name item or insert profile info
        for (index, item) in items.enumerated() {
            if item.title == "MacRing" {
                item.title = "MacRing - \(profileName)"
                break
            }
        }
    }

    // MARK: - Status Bar

    public var isVisible: Bool {
        get { statusItem.isVisible }
        set { statusItem.isVisible = newValue }
    }

    public func hide() {
        statusItem.isVisible = false
    }

    public func show() {
        statusItem.isVisible = true
    }
}

#endif
