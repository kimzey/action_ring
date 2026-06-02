import SwiftUI
import ActionRingCore

/// Edits a `RingAction?` by decomposing it into per-type fields and recomposing
/// on change. Covers the common local action types; workflow / MCP are left to
/// JSON editing and shown read-only.
@available(macOS 14.0, *)
struct ActionEditorView: View {
    @Binding var action: RingAction?

    enum Kind: String, CaseIterable, Identifiable {
        case none, keyboardShortcut, launchApplication, openURL, systemAction
        case shellScript, appleScript, shortcutsApp, textSnippet, openFile, advanced
        var id: String { rawValue }
        var label: String {
            switch self {
            case .none: return "Nothing"
            case .keyboardShortcut: return "Keyboard Shortcut"
            case .launchApplication: return "Launch App"
            case .openURL: return "Open URL"
            case .systemAction: return "System Action"
            case .shellScript: return "Shell Script"
            case .appleScript: return "AppleScript"
            case .shortcutsApp: return "Apple Shortcut"
            case .textSnippet: return "Type Text"
            case .openFile: return "Open File/Folder"
            case .advanced: return "Advanced (JSON only)"
            }
        }
    }

    // Decomposed editing state.
    @State private var kind: Kind = .none
    @State private var keyChar = "c"
    @State private var useSpecialKey = false
    @State private var specialKey: SpecialKey = .enter
    @State private var modCommand = true
    @State private var modShift = false
    @State private var modOption = false
    @State private var modControl = false
    @State private var bundleId = ""
    @State private var urlString = "https://"
    @State private var systemAction: SystemAction = .screenshotArea
    @State private var text = ""
    /// Preserves a workflow/MCP action so switching kinds away and back doesn't lose it.
    @State private var advancedAction: RingAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Action", selection: $kind) {
                ForEach(Kind.allCases) { Text($0.label).tag($0) }
            }
            .onChange(of: kind) { _, _ in recompose() }

            switch kind {
            case .none:
                Text("This slot does nothing — it shows greyed out and can't be selected.")
                    .font(.caption).foregroundStyle(.secondary)

            case .keyboardShortcut:
                HStack(spacing: 12) {
                    Toggle("⌘", isOn: $modCommand)
                    Toggle("⇧", isOn: $modShift)
                    Toggle("⌥", isOn: $modOption)
                    Toggle("⌃", isOn: $modControl)
                }
                .toggleStyle(.button)
                .onChange(of: modCommand) { _, _ in recompose() }
                .onChange(of: modShift) { _, _ in recompose() }
                .onChange(of: modOption) { _, _ in recompose() }
                .onChange(of: modControl) { _, _ in recompose() }

                Toggle("Use a named key (arrows, F-keys, Enter…)", isOn: $useSpecialKey)
                    .onChange(of: useSpecialKey) { _, _ in recompose() }
                if useSpecialKey {
                    Picker("Key", selection: $specialKey) {
                        ForEach(SpecialKey.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .onChange(of: specialKey) { _, _ in recompose() }
                } else {
                    TextField("Key (single character)", text: $keyChar)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                        .onChange(of: keyChar) { _, v in
                            // Last char typed wins; collapse any multi-char input.
                            let last = String(v.suffix(1))
                            if last != v { keyChar = last; return }   // corrective set re-fires onChange
                            recompose()
                        }
                }
                Text("Preview: \(action?.description ?? "—")").font(.caption).foregroundStyle(.secondary)

            case .launchApplication:
                TextField("Bundle identifier (e.g. com.apple.Safari)", text: $bundleId)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: bundleId) { _, _ in recompose() }

            case .openURL:
                TextField("URL", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: urlString) { _, _ in recompose() }

            case .systemAction:
                Picker("System action", selection: $systemAction) {
                    ForEach(SystemAction.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .onChange(of: systemAction) { _, _ in recompose() }

            case .shellScript, .appleScript:
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 90)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    .onChange(of: text) { _, _ in recompose() }
                if kind == .shellScript {
                    Text("Runs via /bin/sh with a timeout. Obvious destructive commands are refused.")
                        .font(.caption).foregroundStyle(.secondary)
                }

            case .shortcutsApp:
                TextField("Shortcut name (Apple Shortcuts)", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: text) { _, _ in recompose() }

            case .textSnippet:
                TextField("Text to type", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: text) { _, _ in recompose() }

            case .openFile:
                HStack {
                    TextField("File or folder path", text: $text)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: text) { _, _ in recompose() }
                    Button("Choose…") { chooseFile() }
                }

            case .advanced:
                Text("Workflows and MCP actions aren't editable here yet — edit profiles.json directly.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear { decompose() }
    }

    // MARK: Decompose / recompose

    private func decompose() {
        guard let action else { kind = .none; return }
        switch action {
        case .keyboardShortcut(let key, let mods):
            kind = .keyboardShortcut
            switch key {
            case .character(let ch): useSpecialKey = false; keyChar = String(ch)
            case .special(let s): useSpecialKey = true; specialKey = s
            }
            modCommand = mods.contains(.command); modShift = mods.contains(.shift)
            modOption = mods.contains(.option); modControl = mods.contains(.control)
        case .launchApplication(let id): kind = .launchApplication; bundleId = id
        case .openURL(let u): kind = .openURL; urlString = u
        case .systemAction(let a): kind = .systemAction; systemAction = a
        case .shellScript(let s): kind = .shellScript; text = s
        case .appleScript(let s): kind = .appleScript; text = s
        case .shortcutsApp(let n): kind = .shortcutsApp; text = n
        case .textSnippet(let t): kind = .textSnippet; text = t
        case .openFile(let p): kind = .openFile; text = p
        case .workflow, .mcpToolCall, .mcpWorkflow:
            kind = .advanced
            advancedAction = action   // remember it so kind-switching can't drop it
        }
    }

    private func recompose() {
        switch kind {
        case .none:
            action = nil
        case .keyboardShortcut:
            var mods: [KeyModifier] = []
            if modCommand { mods.append(.command) }
            if modShift { mods.append(.shift) }
            if modOption { mods.append(.option) }
            if modControl { mods.append(.control) }
            // If the field is momentarily empty, keep the previously-set character
            // rather than silently substituting a default.
            let character: Character
            if let f = keyChar.first {
                character = f
            } else if case .keyboardShortcut(.character(let existing), _)? = action {
                character = existing
            } else {
                character = "c"
            }
            let key: KeyCode = useSpecialKey ? .special(specialKey) : .character(character)
            action = .keyboardShortcut(key, modifiers: mods)
        case .launchApplication: action = .launchApplication(bundleIdentifier: bundleId)
        case .openURL: action = .openURL(urlString)
        case .systemAction: action = .systemAction(systemAction)
        case .shellScript: action = .shellScript(text)
        case .appleScript: action = .appleScript(text)
        case .shortcutsApp: action = .shortcutsApp(text)
        case .textSnippet: action = .textSnippet(text)
        case .openFile: action = .openFile(text)
        case .advanced: action = advancedAction   // restore the preserved workflow/MCP action
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            text = url.path
            recompose()
        }
    }
}
