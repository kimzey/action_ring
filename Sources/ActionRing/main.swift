import AppKit

// ActionRing runs as a menu-bar (accessory) app: no Dock icon, no main window.
// We drive NSApplication manually because this is a plain SPM executable with
// no Info.plist / @NSApplicationMain synthesis. The setup touches main-actor
// state, so it runs inside `MainActor.assumeIsolated` (top-level code on the
// main thread is not formally main-actor isolated).

@available(macOS 14.0, *)
@MainActor
private func launch() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate                 // held alive by `run()` below
    app.setActivationPolicy(.accessory)
    app.run()
}

if #available(macOS 14.0, *) {
    MainActor.assumeIsolated { launch() }
} else {
    FileHandle.standardError.write(Data("ActionRing requires macOS 14 or later.\n".utf8))
    exit(1)
}
