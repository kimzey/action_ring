import Foundation
#if canImport(SwiftUI)
import SwiftUI

// MARK: - Wedge shape

/// A donut segment (pie wedge with a hole) between `innerRadius` and the frame's
/// outer radius, spanning [startAngle, endAngle] in SwiftUI screen angles.
@available(macOS 14.0, *)
struct RingWedge: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var innerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        var p = Path()
        p.addArc(center: center, radius: outer, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        p.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        p.closeSubpath()
        return p
    }
}

// MARK: - Ring View

/// Glassmorphic radial menu rendered as highlightable wedges around a glass
/// center. Reads an observable `RingViewModel`; the window updates
/// `selectedSlot` as the cursor moves.
@available(macOS 14.0, *)
public struct RingView: View {

    // `@State` here holds a *reference* to the externally-owned RingViewModel
    // (created and mutated by RingWindow), not a private value copy. Observation
    // tracks property changes on the shared @Observable instance, so updates from
    // the window's poll timer re-render this view. @State just pins the same
    // instance across body re-evaluations; the window never swaps it.
    @State private var model: RingViewModel

    public init(model: RingViewModel) {
        _model = State(initialValue: model)
    }

    private var geo: RingGeometry { model.geometry }
    private var diameter: CGFloat { geo.outerDiameter }
    private var wedgePadding: CGFloat { 7 }

    public var body: some View {
        ZStack {
            backdrop

            ForEach(model.slots) { slot in
                wedge(for: slot)
            }
            .padding(wedgePadding)

            ForEach(model.slots) { slot in
                slotContent(slot).position(viewPosition(for: slot.position))
            }

            center
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(model.isVisible ? 1 : 0.7)
        .opacity(model.isVisible ? 1 : 0)
        .animation(.spring(response: 0.26, dampingFraction: 0.7), value: model.isVisible)
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: model.selectedSlot)
        // Center the ring inside a larger, fully transparent canvas so the
        // drop-shadow fades out instead of being clipped to the window's square.
        .frame(width: geo.canvasDiameter, height: geo.canvasDiameter)
    }

    // MARK: Backdrop

    private var backdrop: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1))
            .overlay(
                Circle()
                    .strokeBorder(.black.opacity(0.25), lineWidth: 1)
                    .blur(radius: 1)
                    .padding(1)
            )
            .shadow(color: .black.opacity(0.4), radius: 28, y: 10)
    }

    // MARK: Wedge

    @ViewBuilder
    private func wedge(for slot: RingSlot) -> some View {
        let isSelected = model.selectedSlot == slot.position
        let accent = color(slot.color)
        let w = Double(geo.slotAngularWidth)
        // Slot i sits at screen-angle -i·w (the view's y-axis is flipped vs. the
        // math convention used for hit-testing). A small angular gap separates
        // adjacent wedges.
        let gap = 0.035
        let centerAngle = -Double(slot.position) * w
        let start = Angle(radians: centerAngle - w / 2 + gap)
        let end = Angle(radians: centerAngle + w / 2 - gap)

        RingWedge(startAngle: start, endAngle: end, innerRadius: geo.deadZoneRadius - wedgePadding + 4)
            .fill(isSelected
                  ? AnyShapeStyle(accent.gradient.opacity(0.95))
                  : AnyShapeStyle(Color.primary.opacity(0.05)))
            .overlay(
                RingWedge(startAngle: start, endAngle: end, innerRadius: geo.deadZoneRadius - wedgePadding + 4)
                    .stroke(isSelected ? accent.opacity(0.9) : .white.opacity(0.08), lineWidth: isSelected ? 2 : 0.75)
            )
            .shadow(color: isSelected ? accent.opacity(0.55) : .clear, radius: 12)
    }

    // MARK: Slot icon + label

    @ViewBuilder
    private func slotContent(_ slot: RingSlot) -> some View {
        let isSelected = model.selectedSlot == slot.position
        let isEmpty = !slot.hasAction

        VStack(spacing: 3) {
            Image(systemName: slot.icon.isEmpty ? "circle.dashed" : slot.icon)
                .font(.system(size: isSelected ? 21 : 18, weight: .medium))
                .foregroundStyle(isSelected ? .white : (isEmpty ? Color.secondary.opacity(0.35) : .primary.opacity(0.9)))

            if model.showLabels && !slot.label.isEmpty {
                Text(slot.label)
                    .font(.system(size: 9.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .scaleEffect(isSelected ? 1.12 : 1)
        .opacity(isEmpty && !isSelected ? 0.5 : 1)
        .shadow(color: .black.opacity(isSelected ? 0.35 : 0), radius: 3)
    }

    // MARK: Center hub

    private var center: some View {
        let selected = model.selected
        return ZStack {
            Circle()
                .fill(.regularMaterial)
                .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
                .frame(width: geo.deadZoneRadius * 2, height: geo.deadZoneRadius * 2)

            VStack(spacing: 2) {
                if let selected, selected.hasAction {
                    Image(systemName: selected.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(color(selected.color))
                    Text(selected.label)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .foregroundStyle(.primary)
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                    if !model.profileName.isEmpty {
                        Text(model.profileName)
                            .font(.system(size: 8.5, weight: .medium))
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(width: geo.deadZoneRadius * 1.8)
            .padding(4)
        }
    }

    // MARK: Geometry → SwiftUI

    /// Convert a center-relative (math, +y up) slot center into the SwiftUI view
    /// coordinate space (origin top-left, +y down).
    private func viewPosition(for index: Int) -> CGPoint {
        let c = geo.slotCenter(for: index)
        let r = diameter / 2
        return CGPoint(x: r + c.x, y: r - c.y)
    }

    private func color(_ c: SlotColor) -> Color {
        switch c {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .gray: return .gray
        case .teal: return .teal
        case .indigo: return .indigo
        }
    }
}
#endif
