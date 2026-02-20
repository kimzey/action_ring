import Foundation
#if canImport(SwiftUI)
import SwiftUI

// MARK: - Ring View

/// SwiftUI view that renders the action ring
@available(macOS 14.0, *)
public struct RingView: View {

    // MARK: - Properties

    /// Geometry configuration for the ring
    let geometry: RingGeometry

    /// Slots to display in the ring
    let slots: [RingSlot]

    /// Currently selected slot index (nil = none)
    @Binding var selectedSlot: Int?

    /// Currently hovered slot index (nil = none)
    @Binding var hoveredSlot: Int?

    /// Whether the ring is currently visible
    @Binding var isVisible: Bool

    // MARK: - Style

    private let ringColor: Color = .blue.opacity(0.3)
    private let selectedColor: Color = .blue.opacity(0.6)
    private let slotBackgroundColor: Color = .white.opacity(0.9)
    private let iconSize: CGFloat = 24

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Background ring
            ringPath
                .stroke(ringColor, lineWidth: 2)

            // Dead zone indicator
            deadZone

            // Slots
            ForEach(Array(slots.enumerated()), id: \.element.position) { index, slot in
                slotView(at: index, slot: slot)
                    .position(slotPosition(at: index))
            }
        }
        .frame(width: geometry.outerDiameter, height: geometry.outerDiameter)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.5)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
    }

    // MARK: - Ring Path

    private var ringPath: some View {
        Circle()
            .frame(width: geometry.outerDiameter, height: geometry.outerDiameter)
    }

    // MARK: - Dead Zone

    private var deadZone: some View {
        Circle()
            .frame(width: geometry.deadZoneRadius * 2, height: geometry.deadZoneRadius * 2)
            .fill(Color.black.opacity(0.1))
    }

    // MARK: - Slot View

    private func slotView(at index: Int, slot: RingSlot) -> some View {
        let isSelected = selectedSlot == index
        let isHovered = hoveredSlot == index

        return ZStack {
            // Slot background
            Circle()
                .fill(slotBackgroundColor)
                .frame(width: 50, height: 50)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

            // Selection indicator
            if isSelected {
                Circle()
                    .stroke(selectedColor, lineWidth: 3)
                    .frame(width: 55, height: 55)
            }

            // Icon
            if let icon = Image(systemName: slot.icon) {
                icon
                    .font(.system(size: iconSize))
                    .foregroundColor(colorForSlot(slot))
            }

            // Label (optional, shown on hover)
            if isHovered {
                Text(slot.label)
                    .font(.caption)
                    .padding(4)
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .offset(y: 35)
            }
        }
        .opacity(slot.isEnabled ? 1 : 0.5)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
    }

    // MARK: - Slot Position

    private func slotPosition(at index: Int) -> CGPoint {
        let center = geometry.slotCenter(for: index)
        let offset = geometry.outerDiameter / 2
        return CGPoint(x: center.x + offset, y: center.y + offset)
    }

    // MARK: - Slot Color

    private func colorForSlot(_ slot: RingSlot) -> Color {
        switch slot.color {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .gray: return .gray
        }
    }
}

// MARK: - Preview

@available(macOS 14.0, *)
#Preview {
    @Previewable @State var selectedSlot: Int? = nil
    @Previewable @State var hoveredSlot: Int? = nil
    @Previewable @State var isVisible = true

    let geometry = RingGeometry(size: .medium, slotCount: 8)
    let slots = [
        RingSlot(position: 0, label: "Copy", icon: "doc.on.doc", action: .keyboardShortcut(.character("c"), modifiers: [.command])),
        RingSlot(position: 1, label: "Paste", icon: "doc.on.clipboard", action: .keyboardShortcut(.character("v"), modifiers: [.command])),
        RingSlot(position: 2, label: "Save", icon: "square.and.arrow.down", action: .keyboardShortcut(.character("s"), modifiers: [.command])),
        RingSlot(position: 3, label: "Undo", icon: "arrow.uturn.backward", action: .keyboardShortcut(.character("z"), modifiers: [.command])),
        RingSlot(position: 4, label: "Redo", icon: "arrow.uturn.forward", action: .keyboardShortcut(.character("z"), modifiers: [.command, .shift])),
        RingSlot(position: 5, label: "Cut", icon: "scissors", action: .keyboardShortcut(.character("x"), modifiers: [.command])),
        RingSlot(position: 6, label: "Select All", icon: "square.and.pencil", action: .keyboardShortcut(.character("a"), modifiers: [.command])),
        RingSlot(position: 7, label: "Close", icon: "xmark", action: .keyboardShortcut(.character("w"), modifiers: [.command])),
    ]

    return RingView(
        geometry: geometry,
        slots: slots,
        selectedSlot: $selectedSlot,
        hoveredSlot: $hoveredSlot,
        isVisible: $isVisible
    )
    .frame(width: 400, height: 400)
}
#endif
