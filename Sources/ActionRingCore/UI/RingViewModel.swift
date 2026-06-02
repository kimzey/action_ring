import Foundation
#if canImport(SwiftUI)
import SwiftUI

/// Observable state backing the ring overlay. Mutated by `RingWindow` as the
/// cursor moves; `RingView` re-renders via Observation.
@available(macOS 14.0, *)
@MainActor
@Observable
public final class RingViewModel {
    public var geometry: RingGeometry
    public var slots: [RingSlot]
    public var selectedSlot: Int?
    public var showLabels: Bool
    public var isVisible: Bool
    /// Name of the active profile (shown in the ring center for context).
    public var profileName: String

    public init(
        geometry: RingGeometry,
        slots: [RingSlot] = [],
        selectedSlot: Int? = nil,
        showLabels: Bool = true,
        isVisible: Bool = false,
        profileName: String = ""
    ) {
        self.geometry = geometry
        self.slots = slots
        self.selectedSlot = selectedSlot
        self.showLabels = showLabels
        self.isVisible = isVisible
        self.profileName = profileName
    }

    /// The currently highlighted slot, if any.
    public var selected: RingSlot? {
        guard let i = selectedSlot else { return nil }
        return slots.first { $0.position == i }
    }
}
#endif
