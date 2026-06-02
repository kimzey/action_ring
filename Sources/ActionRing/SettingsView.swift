import SwiftUI
import ActionRingCore

@available(macOS 14.0, *)
struct SettingsView: View {
    @Bindable var model: SettingsModel
    @Bindable var profileModel: ProfileEditModel

    private let buttonChoices = [0, 1, 2, 3, 4]

    var body: some View {
        TabView {
            general
                .tabItem { Label("General", systemImage: "gearshape") }
            ProfilesView(model: profileModel)
                .tabItem { Label("Profiles", systemImage: "circle.grid.cross") }
        }
        .frame(width: 520, height: 600)
    }

    private var general: some View {
        Form {
            Section {
                Toggle("Enable ActionRing", isOn: $model.enabled)
                Text(model.enabled ? "The trigger opens the ring." : "Paused — the trigger does nothing.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Trigger") {
                Picker("Mouse button", selection: $model.triggerButton) {
                    ForEach(buttonChoices, id: \.self) { Text(mouseButtonLabel($0)).tag($0) }
                }
                HStack {
                    Button(model.isRecording ? "Press a button…" : "Record from mouse…") {
                        model.startRecording()
                    }
                    .disabled(model.isRecording)
                    if !model.recordedHint.isEmpty {
                        Text(model.recordedHint).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text("Side buttons (Button 4 / 5) are the usual choice so left/right clicks keep working.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Ring") {
                Picker("Default size", selection: $model.ringSize) {
                    Text("Small").tag(RingSize.small)
                    Text("Medium").tag(RingSize.medium)
                    Text("Large").tag(RingSize.large)
                }
                Toggle("Show slot labels", isOn: $model.showLabels)
                Toggle("Hide ring in fullscreen games", isOn: $model.suppressInFullscreen)
                Button {
                    model.previewRing()
                } label: { Label("Preview the ring", systemImage: "eye") }
                Text("How to use: hold the trigger then drag to a slot and release — or quick-click to keep the ring open (sticky) and click again to fire. Center = cancel.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Scripts") {
                HStack {
                    Text("Timeout")
                    Spacer()
                    Stepper("\(Int(model.scriptTimeout))s", value: $model.scriptTimeout, in: 1...60, step: 1)
                }
                Text("Shell/AppleScript actions are killed after the timeout. Obvious destructive commands are refused.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Permissions") {
                HStack {
                    Image(systemName: model.accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(model.accessibilityGranted ? .green : .orange)
                    Text(model.accessibilityGranted ? "Accessibility granted" : "Accessibility required")
                    Spacer()
                    if !model.accessibilityGranted {
                        Button("Open…") { model.openAccessibility() }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
