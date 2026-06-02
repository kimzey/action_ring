import SwiftUI
import ActionRingCore

/// The "Profiles" tab: master switch, the list of profiles with per-profile
/// enable toggles, and entry points to create / edit / delete profiles.
@available(macOS 14.0, *)
struct ProfilesView: View {
    @Bindable var model: ProfileEditModel

    @State private var editing: EditTarget?
    @State private var creating = false

    /// Wraps a profile + whether it's a brand-new one (for the sheet).
    struct EditTarget: Identifiable {
        let id = UUID()
        var profile: RingProfile
        var isNew: Bool
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    Toggle(isOn: $model.globalEnabled) {
                        Label("Enable ActionRing", systemImage: "power")
                    }
                    Text(model.globalEnabled ? "The trigger opens the ring." : "Paused — the trigger does nothing.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("App profiles") {
                    ForEach(model.profiles) { profile in
                        row(profile)
                    }
                }
            }
            Divider()
            HStack {
                Button {
                    creating = true
                } label: { Label("New profile", systemImage: "plus") }
                Spacer()
                Button("Preview ring") { model.preview() }
            }
            .padding(10)
        }
        .sheet(item: $editing) { target in
            ProfileEditorView(model: model, profile: target.profile, isNew: target.isNew)
        }
        .sheet(isPresented: $creating) {
            AppPickerView(apps: model.selectableApps()) { name, bundleId in
                editing = EditTarget(profile: model.newProfile(name: name, bundleId: bundleId), isNew: true)
            }
        }
    }

    @ViewBuilder
    private func row(_ profile: RingProfile) -> some View {
        HStack(spacing: 10) {
            // Enable toggle (the default is always on and can't be disabled).
            if profile.isDefault {
                Image(systemName: "lock.fill").foregroundStyle(.tertiary).frame(width: 34)
            } else {
                Toggle("", isOn: Binding(
                    get: { profile.isEnabled },
                    set: { model.setEnabled(profile, $0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name).font(.system(size: 13, weight: .medium))
                Text(profile.bundleId ?? (profile.isDefault ? "fallback · default" : "fallback · \(profile.category.rawValue)"))
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(profile.source.rawValue)
                .font(.caption2)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(.quaternary))

            Button {
                editing = EditTarget(profile: model.editableCopy(of: profile), isNew: false)
            } label: { Image(systemName: "pencil") }
            .buttonStyle(.borderless)

            if model.isUserProfile(profile) {
                Button(role: .destructive) {
                    model.delete(profile)
                } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
            }
        }
        .opacity(profile.isEnabled ? 1 : 0.55)
    }
}
