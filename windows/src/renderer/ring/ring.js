'use strict';
/* global iconGlyph */
// Ring renderer — geometry math mirrors RingGeometry/RingView:
//   wedge i centered at screen angle -i*w (slot 0 = east, CCW in math space),
//   span [θ - w/2 + gap, θ + w/2 - gap], gap = 0.035 rad,
//   wedge innerR = deadZone - 3, outerR = outerRadius - 7,
//   content at (r + mid·cos(i·w), r - mid·sin(i·w)).

const SVG_NS = 'http://www.w3.org/2000/svg';
const GAP = 0.035;
const SHADOW_MARGIN = 40;

// SlotColor → [accent, darker] (gradient top → bottom)
const COLORS = {
  blue: ['#0A84FF', '#0668CC'], purple: ['#BF5AF2', '#9A41C7'],
  pink: ['#FF375F', '#CC2549'], red: ['#FF453A', '#CC322A'],
  orange: ['#FF9F0A', '#CC7E06'], yellow: ['#FFD60A', '#CCA906'],
  green: ['#30D158', '#23A844'], gray: ['#8E8E93', '#6E6E73'],
  teal: ['#40C8E0', '#2FA0B5'], indigo: ['#5E5CE6', '#4644B8'],
};

const state = {
  geometry: { outerDiameter: 280, deadZoneRadius: 35, slotCount: 8 },
  slots: [],
  profileName: '',
  showLabels: true,
  selectedSlot: null,
  isVisible: false,
};

const container = document.getElementById('ring-container');
const svg = document.getElementById('ring-svg');
const slotLayer = document.getElementById('slot-layer');
const hub = document.getElementById('hub');
const hubIcon = document.getElementById('hub-icon');
const hubLabel = document.getElementById('hub-label');

let wedgeEls = [];
let slotEls = [];

function donutPath(cx, cy, rInner, rOuter, a1, a2) {
  // Angles in screen space (+y down), drawn clockwise from a1 to a2.
  const p = (r, a) => [cx + r * Math.cos(a), cy + r * Math.sin(a)];
  const [x1, y1] = p(rOuter, a1);
  const [x2, y2] = p(rOuter, a2);
  const [x3, y3] = p(rInner, a2);
  const [x4, y4] = p(rInner, a1);
  const large = Math.abs(a2 - a1) > Math.PI ? 1 : 0;
  return [
    `M ${x1} ${y1}`,
    `A ${rOuter} ${rOuter} 0 ${large} 1 ${x2} ${y2}`,
    `L ${x3} ${y3}`,
    `A ${rInner} ${rInner} 0 ${large} 0 ${x4} ${y4}`,
    'Z',
  ].join(' ');
}

function rebuild() {
  const g = state.geometry;
  const outerR = g.outerDiameter / 2;
  const canvas = g.outerDiameter + SHADOW_MARGIN * 2;
  const c = canvas / 2;
  const w = (2 * Math.PI) / g.slotCount;
  const midR = (g.deadZoneRadius + outerR) / 2;

  svg.setAttribute('width', canvas);
  svg.setAttribute('height', canvas);
  svg.setAttribute('viewBox', `0 0 ${canvas} ${canvas}`);
  container.style.width = `${canvas}px`;
  container.style.height = `${canvas}px`;
  svg.innerHTML = '';
  slotLayer.innerHTML = '';
  wedgeEls = [];
  slotEls = [];

  // gradients per color
  const defs = document.createElementNS(SVG_NS, 'defs');
  for (const [name, [light, dark]] of Object.entries(COLORS)) {
    const grad = document.createElementNS(SVG_NS, 'linearGradient');
    grad.id = `grad-${name}`;
    grad.setAttribute('x1', '0'); grad.setAttribute('y1', '0');
    grad.setAttribute('x2', '0'); grad.setAttribute('y2', '1');
    for (const [offset, color] of [['0%', light], ['100%', dark]]) {
      const s = document.createElementNS(SVG_NS, 'stop');
      s.setAttribute('offset', offset);
      s.setAttribute('stop-color', color);
      grad.appendChild(s);
    }
    defs.appendChild(grad);
  }
  svg.appendChild(defs);

  // backdrop
  const backdrop = document.createElementNS(SVG_NS, 'circle');
  backdrop.setAttribute('cx', c); backdrop.setAttribute('cy', c);
  backdrop.setAttribute('r', outerR);
  backdrop.setAttribute('class', 'backdrop');
  svg.appendChild(backdrop);
  const inner = document.createElementNS(SVG_NS, 'circle');
  inner.setAttribute('cx', c); inner.setAttribute('cy', c);
  inner.setAttribute('r', outerR - 1.5);
  inner.setAttribute('class', 'backdrop-inner');
  svg.appendChild(inner);

  // wedges
  const rIn = g.deadZoneRadius - 3;
  const rOut = outerR - 7;
  for (let i = 0; i < g.slotCount; i++) {
    const theta = -i * w; // screen angle (y flipped vs math space)
    const path = document.createElementNS(SVG_NS, 'path');
    path.setAttribute('d', donutPath(c, c, rIn, rOut, theta - w / 2 + GAP, theta + w / 2 - GAP));
    path.setAttribute('class', 'wedge');
    svg.appendChild(path);
    wedgeEls.push(path);
  }

  // slot content
  for (let i = 0; i < g.slotCount; i++) {
    const slot = state.slots.find((s) => s.position === i) || null;
    const el = document.createElement('div');
    el.className = 'slot';
    const x = c + midR * Math.cos(i * w);
    const y = c - midR * Math.sin(i * w); // flip y: math → screen
    el.style.left = `${x}px`;
    el.style.top = `${y}px`;

    const icon = document.createElement('div');
    icon.className = 'slot-icon';
    icon.textContent = iconGlyph(slot && slot.icon ? slot.icon : 'circle.dashed');
    el.appendChild(icon);

    if (state.showLabels && slot && slot.label) {
      const label = document.createElement('div');
      label.className = 'slot-label';
      label.textContent = slot.label;
      el.appendChild(label);
    }
    if (!slot || slot.action == null) el.classList.add('empty');
    slotLayer.appendChild(el);
    slotEls.push(el);
  }

  // hub
  const hubD = g.deadZoneRadius * 2;
  hub.style.width = `${hubD}px`;
  hub.style.height = `${hubD}px`;

  applySelection();
}

function applySelection() {
  const sel = state.selectedSlot;
  wedgeEls.forEach((el, i) => {
    const slot = state.slots.find((s) => s.position === i);
    const color = slot ? slot.color || 'blue' : 'blue';
    if (i === sel) {
      el.classList.add('selected');
      el.style.fill = `url(#grad-${color})`;
      el.style.stroke = COLORS[color] ? COLORS[color][0] : '#0A84FF';
      el.style.filter = `drop-shadow(0 0 12px ${hexA(COLORS[color]?.[0], 0.55)})`;
    } else {
      el.classList.remove('selected');
      el.style.fill = '';
      el.style.stroke = '';
      el.style.filter = '';
    }
  });
  slotEls.forEach((el, i) => el.classList.toggle('selected', i === sel));

  const slot = sel != null ? state.slots.find((s) => s.position === sel) : null;
  if (slot && slot.action != null) {
    hub.classList.add('has-selection');
    hubIcon.textContent = iconGlyph(slot.icon || 'circle.fill');
    hubIcon.style.color = COLORS[slot.color]?.[0] || '#0A84FF';
    hubLabel.textContent = slot.label || '';
  } else {
    hub.classList.remove('has-selection');
    hubIcon.textContent = '✕';
    hubIcon.style.color = '';
    hubLabel.textContent = state.profileName || '';
  }
}

function hexA(hex, alpha) {
  if (!hex) return `rgba(10,132,255,${alpha})`;
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${alpha})`;
}

window.ring.onState((update) => {
  const structural =
    update.geometry !== undefined || update.slots !== undefined ||
    update.showLabels !== undefined || update.profileName !== undefined;
  Object.assign(state, update);
  if (structural) rebuild();
  else if (update.selectedSlot !== undefined) applySelection();
  if (update.isVisible !== undefined) {
    // double-rAF so the entry transition runs even right after display
    if (update.isVisible) {
      requestAnimationFrame(() => requestAnimationFrame(() => container.classList.add('visible')));
    } else {
      container.classList.remove('visible');
    }
  }
});
