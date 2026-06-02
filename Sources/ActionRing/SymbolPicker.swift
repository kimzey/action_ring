import SwiftUI

/// Lightweight SF Symbol picker: a free-text field (any symbol name) plus a
/// curated grid of common choices with a live preview.
@available(macOS 14.0, *)
struct SymbolPicker: View {
    @Binding var symbol: String

    private let common: [String] = [
        "doc.on.doc", "doc.on.clipboard", "scissors", "arrow.uturn.backward", "arrow.uturn.forward",
        "square.and.arrow.down", "square.and.arrow.up", "magnifyingglass", "doc.text.magnifyingglass",
        "command", "plus.square", "xmark.square", "xmark.circle", "trash", "pencil", "folder",
        "play.fill", "pause.fill", "stop.fill", "playpause.fill", "forward.fill", "backward.fill",
        "speaker.wave.2.fill", "speaker.slash.fill", "camera.viewfinder", "bolt.fill", "star.fill",
        "heart.fill", "bookmark.fill", "gearshape", "terminal", "hammer.fill", "ladybug.fill",
        "link", "globe", "arrow.clockwise", "chevron.left", "chevron.right", "sidebar.left",
        "rectangle.split.2x1", "text.alignleft", "bold", "list.bullet", "checkmark.circle",
        "bubble.left.fill", "paperplane.fill", "envelope.fill", "calendar", "bell.fill", "lock.fill",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: symbol.isEmpty ? "questionmark" : symbol)
                    .font(.system(size: 18))
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 7).fill(.quaternary))
                TextField("SF Symbol name", text: $symbol)
                    .textFieldStyle(.roundedBorder)
            }
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 6), count: 8), spacing: 6) {
                    ForEach(common, id: \.self) { name in
                        Button { symbol = name } label: {
                            Image(systemName: name)
                                .font(.system(size: 15))
                                .frame(width: 30, height: 30)
                                .background(RoundedRectangle(cornerRadius: 7)
                                    .fill(symbol == name ? Color.accentColor.opacity(0.3) : Color.clear))
                                .overlay(RoundedRectangle(cornerRadius: 7)
                                    .stroke(symbol == name ? Color.accentColor : .clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
            }
            .frame(height: 132)
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.4)))
        }
    }
}
