'use strict';
// RingGeometry — direct port of Sources/ActionRingCore/Geometry/RingGeometry.swift.
// All values in DIP (CSS px @1x). Pure module, unit-tested.
//
// Coordinate conventions (load-bearing — see RingView.swift):
//   * Hit-test math space: +x right, +y UP, angles counter-clockwise.
//     Slot 0 is centered at angle 0 (due east); indices increase CCW.
//   * Screen space (+y down) flips the angle sign: wedge i renders at -i*w.
//   Callers feeding screen deltas into selectedSlot MUST negate dy first.

const RING_SIZES = {
  small: { outerDiameter: 220, deadZoneRadius: 30 },
  medium: { outerDiameter: 280, deadZoneRadius: 35 },
  large: { outerDiameter: 340, deadZoneRadius: 40 },
};

const SHADOW_MARGIN = 40;
const VALID_SLOT_COUNTS = [4, 6, 8];

class RingGeometry {
  /** @param {{outerDiameter:number, deadZoneRadius:number, slotCount:number}} opts */
  constructor({ outerDiameter, deadZoneRadius, slotCount }) {
    this.outerDiameter = outerDiameter;
    this.deadZoneRadius = deadZoneRadius;
    this.slotCount = Math.max(1, slotCount);
  }

  /** @param {'small'|'medium'|'large'} size */
  static forSize(size, slotCount) {
    const s = RING_SIZES[size] || RING_SIZES.medium;
    return new RingGeometry({
      outerDiameter: s.outerDiameter,
      deadZoneRadius: s.deadZoneRadius,
      slotCount,
    });
  }

  get outerRadius() { return this.outerDiameter / 2; }
  get shadowMargin() { return SHADOW_MARGIN; }
  get canvasDiameter() { return this.outerDiameter + SHADOW_MARGIN * 2; }
  get slotAngularWidth() { return (2 * Math.PI) / this.slotCount; }
  get midRadius() { return (this.deadZoneRadius + this.outerRadius) / 2; }

  /** Angle (math space, CCW, radians) of slot i's spoke. */
  slotAngle(index) { return index * this.slotAngularWidth; }

  /** Center of slot i's content, center-relative math coords (+y up). */
  slotCenter(index) {
    const a = this.slotAngle(index);
    return { x: this.midRadius * Math.cos(a), y: this.midRadius * Math.sin(a) };
  }

  /**
   * Hit-test: center-relative MATH point (+y up) → slot index | null.
   * null = dead zone (cancel). Strict: distance must EXCEED deadZoneRadius.
   * No outer cap — selection extends past outerRadius (parity with mac).
   */
  selectedSlot(point) {
    const distance = Math.hypot(point.x, point.y);
    if (distance <= this.deadZoneRadius) return null;
    const w = this.slotAngularWidth;
    let shifted = (Math.atan2(point.y, point.x) + w / 2) % (2 * Math.PI);
    if (shifted < 0) shifted += 2 * Math.PI;
    const index = Math.floor(shifted / w);
    return Math.min(Math.max(index, 0), this.slotCount - 1);
  }

  /** Inside the active band (between dead zone and outer edge)? */
  isInRingArea(point) {
    const distance = Math.hypot(point.x, point.y);
    return distance > this.deadZoneRadius && distance <= this.outerRadius;
  }

  /**
   * Single source of truth for "what fires on release":
   * selectedSlot + a slot exists at that position + slot has an action.
   * Does NOT check isEnabled or outerRadius (parity with mac).
   * @param {{x:number,y:number}} point  center-relative math coords
   * @param {Array<{position:number, action:any}>} slots
   * @returns {number|null}
   */
  selectableSlot(point, slots) {
    const index = this.selectedSlot(point);
    if (index == null) return null;
    const slot = slots.find((s) => s.position === index);
    if (!slot || slot.action == null) return null;
    return index;
  }

  /**
   * Math → view transform for placing slot content inside a diameter×diameter
   * box (origin top-left, +y down): viewPos = (r + c.x, r - c.y).
   */
  viewPosition(index, diameter) {
    const c = this.slotCenter(index);
    const r = diameter / 2;
    return { x: r + c.x, y: r - c.y };
  }
}

module.exports = { RingGeometry, RING_SIZES, SHADOW_MARGIN, VALID_SLOT_COUNTS };
