import SwiftUI
import ActionRingCore

/// Edit a single profile: its target app, ring size, slot count, enabled state,
/// and each slot. Saving persists through the edit model and refreshes the ring.
@available(macOS 14.0, *)
struct ProfileEditorView: View {
    let model: ProfileEditModel
    @State private var draft: RingProfile
    let isNew: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var editingSlot: RingSlot?
    @State private var pickingApp = false

    init(model: ProfileEditModel, profile: RingProfile, isNew: Bool) {
        self.model = model
        _draft = State(initialValue: profile)
        self.isNew = isNew
    }

    private let slotCounts = [4, 6, 8]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isNew ? "New Profile" : "Edit Profile").font(.headline)
                Spacer()
                Button("Preview") { model.save(draft); model.preview() }
                    .help("Save and show the ring")
            }.padding()
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("Name").font(.subheadline.bold())
                        TextField("Profile name", text: $draft.name).textFieldStyle(.roundedBorder)
                    }
                    if !draft.isDefault {
                        Group {
                            Text("Target app").font(.subheadline.bold())
                            HStack {
                                Text(draft.bundleId ?? "—").foregroundStyle(.secondary).lineLimit(1)
                                Spacer()
                                Button("Choose app…") { pickingApp = true }
                            }
                            Text("Category: \(draft.category.rawValue)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    HStack(spacing: 24) {
                        Picker("Size", selection: $draft.ringSize) {
                            Text("S").tag(RingSize.small); Text("M").tag(RingSize.medium); Text("L").tag(RingSize.large)
                        }.pickerStyle(.segmented).frame(width: 160)
                        Picker("Slots", selection: $draft.slotCount) {
                            ForEach(slotCounts, id: \.self) { Text("\($0)").tag($0) }
                        }.pickerStyle(.segmented).frame(width: 140)
                    }
                    if !draft.isDefault {
                        Toggle("Profile enabled", isOn: $draft.isEnabled)
                    }

                    Divider()
                    Text("Slots — tap to edit").font(.subheadline.bold())
                    slotGrid
                }
                .padding()
            }

            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { model.save(draft); dismiss() }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }.padding()
        }
        .frame(width: 460, height: 600)
        .sheet(item: $editingSlot) { slot in
            SlotEditorView(
                slot: slot,
                onSave: { draft.addSlot($0) },
                onClear: { draft.removeSlot(at: slot.position) }
            )
        }
        .sheet(isPresented: $pickingApp) {
            AppPickerView(apps: model.selectableApps()) { name, bundleId in
                draft.bundleId = bundleId
                draft.category = model.category(forBundleId: bundleId)
                if draft.name.isEmpty || isNew { draft.name = name }
            }
        }
    }

    private var slotGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
            ForEach(0..<draft.slotCount, id: \.self) { pos in
                let slot = draft.slotAt(position: pos) ?? RingSlot.empty(at: pos)
                Button {
                    editingSlot = slot
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: slot.hasAction ? (slot.icon.isEmpty ? "circle.fill" : slot.icon) : "plus")
                            .font(.system(size: 16))
                            .frame(width: 28, height: 28)
                            .foregroundStyle(slot.hasAction ? swatch(slot.color) : Color.secondary)
                            .background(RoundedRectangle(cornerRadius: 7).fill(.quaternary.opacity(0.5)))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(slot.label.isEmpty ? "Empty" : slot.label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(slot.hasAction ? .primary : .secondary)
                            Text(slot.action?.description ?? "tap to add")
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text("\(pos + 1)").font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 9).stroke(.quaternary))
                    .opacity(slot.isEnabled || !slot.hasAction ? 1 : 0.5)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func swatch(_ c: SlotColor) -> Color {
        switch c {
        case .blue: return .blue; case .purple: return .purple; case .pink: return .pink
        case .red: return .red; case .orange: return .orange; case .yellow: return .yellow
        case .green: return .green; case .gray: return .gray; case .teal: return .teal
        case .indigo: return .indigo
        }
    }
}
