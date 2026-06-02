import AppKit
import SwiftUI
import ActionRingCore

/// Menu-bar (accessory) app delegate. Owns the `RingController`, the status
/// item, the settings window, and the accessibility-permission flow.
@available(macOS 14.0, *)
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var controller: RingController!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = RingController()
        controller.onActionExecuted = { slot, result in
            if case .failure(let err) = result {
                NSLog("ActionRing: '\(slot.label)' failed: \(err)")
            }
        }
        setupStatusItem()
        attemptStart()

        // `--preview` shows the ring immediately (no Accessibility needed) so the
        // look + cursor tracking can be verified before wiring the trigger.
        if CommandLine.arguments.contains("--preview") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.controller.showPreview(duration: 10)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
        permissionTimer?.invalidate()
    }

    // MARK: Start / permissions

    private func attemptStart() {
        if EventTapManager.hasAccessibilityPermissions() {
            let ok = controller.start()
            if !ok { showPermissionAlert(armingFailed: true) }
            refreshMenu()
        } else {
            EventTapManager.requestAccessibilityPermissions()
            showPermissionAlert(armingFailed: false)
            // Keep polling — the tap can usually arm once trust is granted.
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if EventTapManager.hasAccessibilityPermissions() {
                        self.permissionTimer?.invalidate()
                        self.permissionTimer = nil
                        _ = self.controller.start()
                        self.refreshMenu()
                    }
                }
            }
        }
    }

    private func showPermissionAlert(armingFailed: Bool) {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Needed"
        alert.informativeText = """
        ActionRing captures your mouse button to show the ring. Enable it under:

        System Settings → Privacy & Security → Accessibility

        Then come back — the ring arms automatically. If it doesn't, quit and reopen ActionRing.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            EventTapManager.openAccessibilitySettings()
        }
    }

    // MARK: Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "circle.grid.cross.fill", accessibilityDescription: "ActionRing")
            button.image?.isTemplate = true
        }
        refreshMenu()
    }

    private func refreshMenu() {
        let menu = NSMenu()

        let granted = EventTapManager.hasAccessibilityPermissions()
        let armed = controller.isArmed
        let enabled = controller.profileStore.settings.enabled
        // "Armed" is the truth: the tap is installed and the trigger works now.
        let statusTitle: String
        if !enabled { statusTitle = "❚❚ Paused" }
        else if armed { statusTitle = "● Ready — trigger is live" }
        else if granted { statusTitle = "▲ Permission OK — click \"Re-arm\"" }
        else { statusTitle = "○ Needs Accessibility" }
        let statusRow = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusRow.isEnabled = false
        menu.addItem(statusRow)

        let masterTitle = enabled ? "Pause ActionRing" : "Resume ActionRing"
        menu.addItem(NSMenuItem(title: masterTitle, action: #selector(toggleEnabled), keyEquivalent: "e"))

        let trigger = NSMenuItem(
            title: "Trigger: \(mouseButtonLabel(controller.profileStore.settings.triggerButton))",
            action: nil, keyEquivalent: ""
        )
        trigger.isEnabled = false
        menu.addItem(trigger)

        menu.addItem(.separator())
        let preview = NSMenuItem(title: "Preview Ring (move your mouse)", action: #selector(previewRing), keyEquivalent: "p")
        menu.addItem(preview)
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        if !armed {
            menu.addItem(NSMenuItem(title: "Re-arm (after granting permission)", action: #selector(reArm), keyEquivalent: "r"))
            menu.addItem(NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibility), keyEquivalent: ""))
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit ActionRing", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items where item.action != nil { item.target = self }
        statusItem.menu = menu
    }

    // MARK: Actions

    @objc private func openAccessibility() { EventTapManager.openAccessibilitySettings() }

    /// Re-attempt arming the event tap without relaunching (useful right after
    /// the user flips the Accessibility toggle).
    @objc private func reArm() {
        permissionTimer?.invalidate(); permissionTimer = nil
        attemptStart()
        if controller.isArmed {
            let a = NSAlert()
            a.messageText = "ActionRing is live"
            a.informativeText = "Hold \(mouseButtonLabel(controller.profileStore.settings.triggerButton)) to open the ring."
            a.runModal()
        }
    }

    @objc private func previewRing() { controller.showPreview() }

    @objc private func toggleEnabled() {
        controller.profileStore.settings.enabled.toggle()
        controller.profileStore.saveSettings()
        controller.applySettings()
        refreshMenu()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func openSettings() {
        if let win = settingsWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let model = SettingsModel(controller: controller, onChanged: { [weak self] in self?.refreshMenu() })
        let profileModel = ProfileEditModel(controller: controller)
        let hosting = NSHostingController(rootView: SettingsView(model: model, profileModel: profileModel))
        let win = NSWindow(contentViewController: hosting)
        win.title = "ActionRing Settings"
        win.styleMask = [.titled, .closable, .miniaturizable]
        win.setContentSize(NSSize(width: 520, height: 600))
        win.isReleasedWhenClosed = false
        win.center()
        settingsWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
