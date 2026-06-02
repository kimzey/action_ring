import SwiftUI
import ActionRingCore

/// Pick a target app (bundle id) for a profile — from running apps and the
/// known built-ins, or by typing a bundle id directly.
@available(macOS 14.0, *)
struct AppPickerView: View {
    let apps: [(name: String, bundleId: String)]
    let onPick: (_ name: String, _ bundleId: String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var manualId = ""

    private var filtered: [(name: String, bundleId: String)] {
        guard !query.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.bundleId.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose an app").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }.padding()
            Divider()

            TextField("Search apps…", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal).padding(.top, 8)

            List(filtered, id: \.bundleId) { app in
                Button {
                    onPick(app.name, app.bundleId); dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(app.name)
                        Text(app.bundleId).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            Divider()
            HStack {
                TextField("…or type a bundle id", text: $manualId)
                    .textFieldStyle(.roundedBorder)
                Button("Use") {
                    let id = manualId.trimmingCharacters(in: .whitespaces)
                    guard !id.isEmpty else { return }
                    onPick(id.split(separator: ".").last.map(String.init)?.capitalized ?? id, id)
                    dismiss()
                }.disabled(manualId.trimmingCharacters(in: .whitespaces).isEmpty)
            }.padding()
        }
        .frame(width: 380, height: 460)
    }
}
