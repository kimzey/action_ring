import SwiftUI
import ActionRingCore

@available(macOS 14.0, *)
struct SlotEditorView: View {
    let position: Int
    @State private var draft: RingSlot
    let onSave: (RingSlot) -> Void
    let onClear: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(slot: RingSlot, onSave: @escaping (RingSlot) -> Void, onClear: @escaping () -> Void) {
        self.position = slot.position
        _draft = State(initialValue: slot)
        self.onSave = onSave
        self.onClear = onClear
    }

    private let colors: [SlotColor] = SlotColor.allCases

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Slot \(position + 1)").font(.headline)
                Spacer()
                Button("Clear") { onClear(); dismiss() }
                    .help("Empty this slot")
            }
            .padding()
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("Label").font(.subheadline.bold())
                        TextField("Label", text: $draft.label).textFieldStyle(.roundedBorder)
                    }
                    Group {
                        Text("Icon").font(.subheadline.bold())
                        SymbolPicker(symbol: $draft.icon)
                    }
                    Group {
                        Text("Color").font(.subheadline.bold())
                        HStack(spacing: 8) {
                            ForEach(colors, id: \.self) { c in
                                Circle()
                                    .fill(swatch(c))
                                    .frame(width: 24, height: 24)
                                    .overlay(Circle().stroke(.white, lineWidth: draft.color == c ? 2.5 : 0))
                                    .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 0.5))
                                    .onTapGesture { draft.color = c }
                            }
                        }
                    }
                    Toggle("Enabled", isOn: $draft.isEnabled)
                    Divider()
                    Group {
                        Text("Action").font(.subheadline.bold())
                        ActionEditorView(action: $draft.action)
                    }
                }
                .padding()
            }

            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    if draft.icon.isEmpty { draft.icon = "circle.fill" }
                    onSave(draft); dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 420, height: 640)
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
