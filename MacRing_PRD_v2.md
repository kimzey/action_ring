# MacRing — Product Requirements Document (PRD)

> **Version:** 2.0.0  
> **Last Updated:** February 20, 2026  
> **Status:** Draft → Enhanced (post-Logitum analysis)  
> **Author:** Kimzey  
> **Changelog:** v2.0 — Added MCP integration, Three-Tier Intelligence, Semantic Behavior Analysis, Universal Mouse Support, Enhanced Competitive Analysis, Zero-Config philosophy. Inspired by [Logitum Adaptive Ring](https://github.com/mrsladoje/logitum) (HackaTUM 2025 winner).

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Statement](#2-problem-statement)
3. [Product Vision & Goals](#3-product-vision--goals)
4. [Competitive Analysis](#4-competitive-analysis)
5. [Target Users & Personas](#5-target-users--personas)
6. [User Stories & Use Cases](#6-user-stories--use-cases)
7. [Complete Feature Specification](#7-complete-feature-specification)
8. [Three-Tier Intelligence Architecture](#8-three-tier-intelligence-architecture)
9. [System Architecture](#9-system-architecture)
10. [Technology Stack](#10-technology-stack)
11. [AI Integration Deep Dive](#11-ai-integration-deep-dive)
12. [MCP Integration (Model Context Protocol)](#12-mcp-integration)
13. [Semantic Behavior Analysis](#13-semantic-behavior-analysis)
14. [Universal Mouse Support](#14-universal-mouse-support)
15. [Data Models & Database Schema](#15-data-models--database-schema)
16. [UI/UX Design Specification](#16-uiux-design-specification)
17. [Development Phases & Timeline](#17-development-phases--timeline)
18. [API Key & Security](#18-api-key--security)
19. [Performance Requirements](#19-performance-requirements)
20. [Testing Strategy](#20-testing-strategy)
21. [Distribution & Deployment](#21-distribution--deployment)
22. [Risk Analysis & Mitigation](#22-risk-analysis--mitigation)
23. [Future Roadmap](#23-future-roadmap-post-v10)
24. [Cost Analysis & Business Model](#24-cost-analysis--business-model)
25. [Success Metrics & KPIs](#25-success-metrics--kpis)
26. [Appendix A: Project File Structure](#26-appendix-a-project-file-structure)
27. [Appendix B: Built-in Profile Presets](#27-appendix-b-built-in-profile-presets)
28. [Appendix C: AI Prompt Templates](#28-appendix-c-ai-prompt-templates)
29. [Appendix D: MCP Server Registry Examples](#29-appendix-d-mcp-server-registry-examples)
30. [Appendix E: Glossary](#30-appendix-e-glossary)

---

## 1. Executive Summary

**MacRing** is a native macOS application that transforms **any multi-button mouse** into an intelligent, context-aware command hub. When the user presses and holds a designated mouse button, a radial **Action Ring** appears at the cursor position, offering contextual shortcuts that **automatically adapt** to the currently focused application.

### What Makes MacRing Different

| Differentiator | Description |
|----------------|-------------|
| **Universal Mouse** | Works with ANY mouse — Logitech, Razer, Keychron, SteelSeries, Apple Magic Mouse, generic mice. Not locked to one brand. |
| **Three-Tier Intelligence** | Discovery (instant context) → Observation (passive learning) → Adaptation (AI-driven evolution). Inspired by Logitum's architecture but extended with Claude's reasoning. |
| **MCP Integration** | Connects to 6,000+ AI tools via Model Context Protocol — not just keyboard shortcuts, but actual tool execution (Git, Slack, Jira, Notion, etc.) |
| **Claude AI Engine** | Deep reasoning for workflow suggestions, NL configuration, auto-profile generation, and semantic behavior analysis |
| **Zero-Config Design** | Works immediately on launch. AI continuously improves the ring with zero manual setup. |
| **Privacy-First** | All data local. No raw keystrokes sent. 24-hour auto-delete for raw interaction events. User's own API key. |
| **macOS Native** | Built with Swift/SwiftUI. Glassmorphism. 60fps. < 50ms ring appearance. Feels like part of macOS. |

### Key Numbers

| Metric | Target |
|--------|--------|
| Ring appearance latency | < 50ms |
| Built-in app profiles | 50+ apps |
| Supported action types | 13 types (11 local + 2 MCP) |
| MCP tools accessible | 6,000+ (and growing) |
| Mice brands supported | **All** (via CGEventTap) |
| AI suggestion acceptance rate | > 80% |
| Monthly AI cost (avg user) | $0.30–$0.60 |
| Zero-config time to useful ring | < 3 seconds |
| Time to MVP | 5–6 weeks |
| Time to v1.0 | 16–18 weeks |

---

## 2. Problem Statement

### The Pain Points

1. **Shortcut Overload**: Power users work with 5–15 apps daily. Each has its own shortcuts. A study by RescueTime found knowledge workers switch apps **1,100+ times per day**.

2. **Context-Switching Cost**: The average context switch costs **23 minutes** to regain focus (UC Irvine research). Mouse button → ring is < 1 second.

3. **Deep Menu Navigation**: Many frequently-used commands are buried 3–4 levels deep. Finding "Export as PNG" in Figma breaks design flow.

4. **Underutilized Mouse Buttons**: Multi-button mice have 3–12 extra buttons that are either unused or mapped to static, one-size-fits-all functions.

5. **Static Configuration**: Existing tools (Logitech Options+, SteerMouse, BetterTouchTool) let you map buttons to actions, but mappings are **static** — they don't change per app, don't learn behavior, and don't connect to the AI tool ecosystem.

6. **Brand Lock-In**: Logitech Options+ only works with Logitech. Razer Synapse only works with Razer. There is no universal, brand-agnostic solution.

7. **Disconnected Tools**: Even with MCP giving AI access to 6,000+ tools, there's no **physical interface** to access them instantly. Claude Desktop shows ALL tools — overwhelming. Keyboard shortcuts require memorization.

### The Opportunity

```
┌─────────────────────────────────────────────────────────────────┐
│  MARKET GAP: No product combines ALL of these:                 │
│                                                                 │
│  ✅ Physical mouse button trigger (tactile, instant)           │
│  ✅ Context-aware per app (auto-switching)                     │
│  ✅ AI-powered learning (gets smarter over time)               │
│  ✅ MCP integration (6,000+ real tool executions)              │
│  ✅ Universal mouse support (any brand)                        │
│  ✅ Zero configuration (works immediately)                     │
│  ✅ macOS native (not an Electron wrapper)                     │
│                                                                 │
│  MacRing fills this gap.                                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Product Vision & Goals

### Vision Statement

> To create the most intuitive and intelligent shortcut system for macOS — one that eliminates shortcut memorization, replaces menu navigation, adapts to each user's workflow through AI, connects to the entire MCP ecosystem, and works with every mouse on the market.

### Design Philosophy: Zero-Config Intelligence

Inspired by Logitum's "Three Words: Intelligence. Adaptation. Zero Config." — MacRing adopts the same principle but extends it:

```
ZERO CONFIG          = Works out of the box with 50+ app presets
INTELLIGENCE         = Claude AI understands context and intent
ADAPTATION           = Ring evolves based on usage patterns
UNIVERSAL            = Any mouse, any app, any MCP tool
PRIVACY-FIRST        = Your data stays on your machine
```

### Goals & Success Criteria

| Priority | Goal | Metric | Target |
|----------|------|--------|--------|
| **P0** | Ring appears instantly | Instruments | < 50ms |
| **P0** | Context switches for top 50 apps | Detection rate | 100% |
| **P0** | Works with 5+ mouse brands | CGEventTap coverage | Logitech, Razer, Keychron, SteelSeries, generic |
| **P0** | Core ring works offline | Functional test | Pass |
| **P1** | AI suggests relevant shortcuts | Acceptance rate | > 80% |
| **P1** | Zero-config for new apps | Time to ring ready | < 3 seconds |
| **P1** | MCP tools discoverable | Registry query time | < 500ms |
| **P2** | NL config accuracy | Intent recognition | > 90% |
| **P2** | Semantic clustering quality | Silhouette score | > 0.6 |

### Non-Goals (v1.0)

- Windows or Linux support (macOS only for v1.0)
- Trackpad gesture triggers (mouse buttons only)
- Built-in macro recorder with visual GUI (v1.3)
- Voice-activated ring commands
- Cross-device profile sync (v2.0)
- MCP server hosting (we consume, not host)

---

## 4. Competitive Analysis

> **NEW SECTION** — Added after studying Logitum Adaptive Ring and the broader landscape.

### Direct Competitors

| Feature | MacRing | Logitum | Logitech Options+ | BetterTouchTool | SteerMouse | Raycast |
|---------|---------|---------|-------------------|-----------------|------------|---------|
| **Platform** | macOS | Windows | macOS/Win | macOS | macOS | macOS |
| **Mouse Support** | **Any mouse** | Logitech only | Logitech only | Any | Any | N/A |
| **Radial Menu** | ✅ 8-slot ring | ✅ 6-8 ring | ✅ (limited) | ✅ | ❌ | ❌ |
| **Context-Aware** | ✅ Auto per app | ✅ Auto per app | ❌ Manual | ✅ Manual rules | ❌ | ❌ |
| **AI-Powered** | ✅ Claude | ✅ Gemini | ❌ | ❌ | ❌ | ✅ (limited) |
| **MCP Integration** | ✅ 6,000+ tools | ✅ 6,000+ tools | ❌ | ❌ | ❌ | ❌ |
| **Learns Behavior** | ✅ Semantic | ✅ Vector cluster | ❌ | ❌ | ❌ | ❌ |
| **NL Config** | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Zero Config** | ✅ | ✅ | ❌ | ❌ | ❌ | ⚠️ Partial |
| **Offline Mode** | ✅ Full | ❌ Degraded | ✅ | ✅ | ✅ | ❌ |
| **Privacy** | ✅ Local-first | ⚠️ Gemini/Voyage calls | ✅ | ✅ | ✅ | ⚠️ |
| **Price** | Free / $19.99 AI | Free (hackathon) | Free (bundled) | $22 license | $19.99 | $8/mo |
| **Visual Configurator** | ✅ Drag & drop | ❌ (planned) | ✅ | ✅ | ✅ | ❌ |

### Our Advantages Over Logitum

Logitum proved the concept works. MacRing takes it further:

| Logitum Limitation | MacRing Solution |
|-------------------|-----------------|
| **Logitech-only** hardware | **CGEventTap** captures ANY mouse button on macOS |
| **Windows-only** via C# | **Native Swift/SwiftUI** on macOS |
| **Gemini + VoyageAI** (2 API keys) | **Claude-only** (1 key, better reasoning) |
| No visual configurator | **Full drag-and-drop configurator** |
| No natural language config | **"Add screenshot to slot 3"** via Claude |
| Window title tracking (privacy concern) | **Bundle ID only** — no content tracking |
| 24h TTL only | **Configurable** 24h/7d/30d/90d retention |
| No offline support | **Full offline** with rule-based fallback + preset DB |
| Hackathon prototype (36 hours) | **Production-grade** (16-week development) |

### What We Learn From Logitum

| Logitum Innovation | How We Adopt It |
|-------------------|----------------|
| **Three-Tier Intelligence** (Discovery → Observation → Adaptation) | Adopted as core architecture (Section 8) |
| **MCP Integration** for 6,000+ tools | Added as action type + tool discovery (Section 12) |
| **Vector Embeddings** for behavior clustering | Adopted with on-device embeddings (Section 13) |
| **Zero-Config philosophy** | Elevated to design principle |
| **Adaptive Cycle** (use → observe → suggest → update) | Adopted as core AI loop |
| **Frequency threshold** for auto-suggestions | Adopted with configurable thresholds |

---

## 5. Target Users & Personas

### Persona A: Power Developer — "Nat"

| Attribute | Detail |
|-----------|--------|
| **Role** | Full-stack developer |
| **Daily Apps** | VS Code, Terminal, Chrome, Postman, Slack, Notion |
| **Mouse** | Keychron M6 (6 buttons) |
| **Pain** | Different shortcuts in every IDE/tool. Constantly hitting wrong combos. |
| **Desire** | One button → instant access to the right shortcuts + Git/CI tools via MCP |
| **AI Interest** | Smart suggestions, NL config, **MCP: git commit/push/PR directly from ring** |

### Persona B: Creative Professional — "Mint"

| Attribute | Detail |
|-----------|--------|
| **Role** | UI/UX Designer |
| **Daily Apps** | Figma, Photoshop, Illustrator, After Effects, Blender |
| **Mouse** | Logitech MX Master 3S |
| **Pain** | Deep nested menus break creative flow. |
| **Desire** | Instant tool/action access. Auto-generated profiles for design tools. |
| **AI Interest** | Auto-profiles, **MCP: export to Figma/Jira/Linear from ring** |

### Persona C: Productivity Enthusiast — "Park"

| Attribute | Detail |
|-----------|--------|
| **Role** | Project Manager |
| **Daily Apps** | Gmail, Google Docs, Slack, Notion, Zoom, Calendar |
| **Mouse** | Generic Bluetooth mouse (2 side buttons) |
| **Pain** | Can't remember shortcuts. Wants AI to handle everything. |
| **Desire** | Zero-config, smart suggestions, auto-everything. |
| **AI Interest** | Maximum AI. **MCP: Slack message, Notion page, Calendar event from ring** |

### Persona D: Gamer / Streamer — "Kai" *(NEW)*

| Attribute | Detail |
|-----------|--------|
| **Role** | Content creator / gamer |
| **Daily Apps** | OBS, Discord, Steam, Browser |
| **Mouse** | Razer DeathAdder V3 (5 buttons) |
| **Pain** | Existing tools don't support Razer mice with context features. |
| **Desire** | Scene switching, mute/unmute, clip capture — all from mouse ring. |
| **AI Interest** | Low. Wants manual config but values the ring UX. |

---

## 6. User Stories & Use Cases

### Core User Stories

| ID | Story | Priority |
|----|-------|----------|
| US-001 | As a user, I want to press a mouse button to see a radial menu, so I access commands instantly. | P0 |
| US-002 | As a user, I want the ring to auto-switch by app, so I always see relevant commands. | P0 |
| US-003 | As a user, I want this to work with my Razer/Keychron/generic mouse, not just Logitech. | P0 |
| US-004 | As a user, I want to drag-and-drop to customize my ring visually. | P1 |
| US-005 | As a user, I want AI to suggest shortcuts I use frequently but haven't added. | P1 |
| US-006 | As a user, I want auto-generated profiles when I open a new app. | P1 |
| US-007 | As a user, I want to configure the ring with natural language. | P2 |
| US-008 | As a user, I want MCP tools (Git push, Slack message) as ring actions. | P1 |
| US-009 | As a user, I want to describe a workflow and have AI create a macro. | P2 |
| US-010 | As a user, I want the ring disabled in fullscreen games. | P0 |
| US-011 | As a user, I want to export/import/share profiles with my team. | P1 |
| US-012 | As a user, I want MacRing to work fully offline without an API key. | P0 |
| US-013 | As a user, I want to see what data MacRing collects and delete it anytime. | P0 |
| US-014 | As a user, I want the ring to learn that I do "Format → Save → Push" and offer it as one action. | P1 |

### Detailed Use Case: MCP Tool Execution (UC-005) *(NEW)*

```
Precondition: MCP enabled, GitHub MCP server configured
1. User working in VS Code on feature branch
2. User presses mouse button 4 → ring appears
3. Ring slot 7 shows "Git: Push" (MCP action)
4. User selects "Git: Push"
5. ActionExecutor detects MCP action type
6. MCPClient connects to local GitHub MCP server
7. MCP server executes: git push origin feature-branch
8. Ring dismisses, notification: "Pushed to feature-branch ✓"
9. BehaviorTracker logs: MCP action, bundleId, timestamp
```

### Detailed Use Case: Three-Tier Adaptive Cycle (UC-006) *(NEW)*

```
TIER 1 — DISCOVERY (instant):
  User opens Notion → AppDetector fires
  → ProfileManager: Notion profile found (built-in preset)
  → MCPRegistry: discovers Notion MCP server available
  → Ring populates: New Page, Search, Toggle Todo, AI Write + MCP: Create Task
  → Time: < 500ms

TIER 2 — OBSERVATION (passive, over days):
  BehaviorTracker records:
  → User always clicks "New Page" then "Toggle Todo" within 10s
  → User uses keyboard Cmd+K (search) 30x/day but it's not in ring
  → User never clicks "AI Write" slot

TIER 3 — ADAPTATION (intelligent, weekly):
  SemanticAnalyzer processes 7 days of data:
  → Suggest: Replace "AI Write" with "Search (⌘K)" — confidence 0.92
  → Suggest: Create workflow "New Page + Todo Template" — confidence 0.85
  → Suggest: Move "New Page" to slot 0 (most-used) — confidence 0.78
  → Show suggestions in menu bar popover
  → User accepts 2 of 3 → ring updates permanently
```

---

## 7. Complete Feature Specification

### 7.1 The Action Ring (Core UI)

**Priority:** P0 | **Phase:** 1

*(Same as PRD v1 — all ring specs, interaction model, slot selection algorithm, animations, edge cases)*

| Parameter | Value |
|-----------|-------|
| Ring outer diameter | 280px (Medium), S=220, L=340 |
| Dead zone radius | 35px |
| Slot count | 4, 6, or 8 (default: 8) |
| Appear animation | `spring(response: 0.3, dampingFraction: 0.7)` |
| Dismiss animation | `easeOut(duration: 0.1)` |
| Max render latency | < 16ms (60fps) |
| Window type | `NSPanel` (non-activating, floating) |

**Slot Selection Algorithm:**
```
angle = atan2(dy, dx)
angle = (angle + 2π) % (2π)
selectedSlot = floor((angle + slotAngle/2) % (2π) / slotAngle)
```

---

### 7.2 Mouse Button Capture — Universal Support

**Priority:** P0 | **Phase:** 1

> **KEY DIFFERENTIATOR**: Works with ANY mouse, unlike Logitum (Logitech only) or Options+ (Logitech only).

**How:** `CGEventTap` at `kCGHIDEventTap` intercepts ALL HID mouse events regardless of manufacturer. The OS normalizes all USB/Bluetooth mice into standard CGMouseButton events.

**Supported Mice (Tested):**

| Brand | Models | Buttons Available |
|-------|--------|-------------------|
| Logitech | MX Master 3/4, MX Anywhere, G502 | 3–11 buttons |
| Razer | DeathAdder, Basilisk, Viper | 5–11 buttons |
| Keychron | M1, M3, M6 | 3–6 buttons |
| SteelSeries | Aerox, Rival, Prime | 5–6 buttons |
| Apple | Magic Mouse | 0 extra (keyboard trigger only) |
| Generic USB | Any HID-compliant | 2–5 buttons |

**Button Recording Mode:** Press any button → MacRing identifies it → "Use Button 4 as trigger?" → Done.

---

### 7.3 Supported Action Types

| # | Type | Description | Phase | MCP? |
|---|------|-------------|-------|------|
| 1 | Keyboard Shortcut | Simulates key combination | 1 | ❌ |
| 2 | Launch Application | Opens/focuses app | 1 | ❌ |
| 3 | Open URL | Opens URL in browser | 1 | ❌ |
| 4 | System Action | Lock, screenshot, volume, etc. | 1 | ❌ |
| 5 | Shell Script | Runs bash command | 2 | ❌ |
| 6 | AppleScript | Executes AppleScript | 2 | ❌ |
| 7 | Shortcuts.app | Runs Apple Shortcuts | 3 | ❌ |
| 8 | Text Snippet | Types pre-defined text | 3 | ❌ |
| 9 | Open File/Folder | Opens specific path | 3 | ❌ |
| 10 | Workflow (Macro) | Multi-step sequence | 4 | ❌ |
| 11 | Sub-Ring | Opens nested ring | Future | ❌ |
| **12** | **MCP Tool Call** | **Execute any MCP tool** | **4** | **✅** |
| **13** | **MCP Workflow** | **Chain MCP tools** | **4** | **✅** |

---

### 7.4 Context-Aware Profile System

*(Same as PRD v1 + MCP enhancement)*

**Profile Lookup Chain (Enhanced):**
1. **Exact Bundle ID** → user/built-in profile
2. **MCP Discovery** → query registry for app-relevant MCP servers *(NEW)*
3. **App Category** → category fallback profile
4. **Default Profile** → universal fallback

**MCP Enhancement:** When a profile is loaded, MacRing also queries the MCP registry for servers relevant to that app. E.g., opening VS Code → discover GitHub MCP, Docker MCP, Linear MCP. Relevant MCP tools offered as additional ring slots or in a sub-ring.

---

### 7.5 Drag & Drop Configurator Studio

*(Same as PRD v1)*

Split-pane: Left = Action Toolbox (now includes MCP tools) | Right = Interactive Ring Preview

**New MCP Section in Toolbox:**
```
┌──── MCP Tools ──────────┐
│ 🔗 GitHub: Create PR    │
│ 🔗 GitHub: Push Branch  │
│ 🔗 Slack: Send Message  │
│ 🔗 Notion: Create Page  │
│ 🔗 Linear: Create Issue │
│ 🔍 Browse 6,000+ more...│
└─────────────────────────┘
```

---

### 7.6 AI Features (5 + 1 NEW)

| # | Feature | Model | Phase | New? |
|---|---------|-------|-------|------|
| 1 | Smart Suggestions | Haiku | 4 | ❌ |
| 2 | Auto Profile Gen | Sonnet | 4 | ❌ |
| 3 | Natural Language Config | Sonnet | 4 | ❌ |
| 4 | Shortcut Discovery | Haiku | 4 | ❌ |
| 5 | Workflow Builder | Sonnet | 4 | ❌ |
| **6** | **Semantic Behavior Analysis** | **On-device + Haiku** | **4** | **✅ NEW** |

**Feature 6: Semantic Behavior Analysis** *(Inspired by Logitum's vector clustering)*

Rather than just counting shortcut frequency (v1), v2 adds **semantic understanding** of action patterns:

```
RAW DATA:  User does "⌘S → ⌘⇧F → Shell(git add .) → Shell(git commit) → Shell(git push)"
           This happens 3+ times per day

SEMANTIC:  AI interprets this as "code-save-and-deploy workflow"
           Cluster: similar to other users' deploy patterns
           Suggestion: "Create one-click Deploy action?"
```

**Implementation:** On-device embeddings (via Core ML NLEmbedding) + cosine similarity clustering. AI (Haiku) interprets clusters into human-readable suggestions. No raw data sent to API — only aggregated patterns.

---

### 7.7 Ring Appearance Settings

*(Same as PRD v1)*

---

### 7.8 Import & Export System

*(Same as PRD v1 + MCP profiles)*

**New:** Exported profiles can include MCP server references. Importing checks if the MCP server is available locally; if not, offers to install it.

---

### 7.9 Menu Bar Integration

*(Same as PRD v1)*

---

### 7.10 Onboarding Flow (Zero-Config Enhanced)

1. **Welcome** — "MacRing works with any mouse" animation → [Get Started]
2. **Accessibility Permission** — Step-by-step + deep link
3. **Mouse Button Setup** — "Press your trigger button" → records ANY mouse button
4. **Auto-Detection** — MacRing scans installed apps, loads presets, queries MCP → instant ring ready *(NEW: takes < 3 seconds)*
5. **AI Setup (optional)** — API key input. "MacRing works great without AI too."
6. **MCP Setup (optional)** — Discover available MCP servers *(NEW)*
7. **Tutorial** — Interactive practice

---

### 7.11 Usage Analytics Dashboard

*(Same as PRD v1 + semantic insights)*

**New:** Dashboard shows not just frequency but **workflow patterns** discovered by semantic analysis: "Your top workflow: Format → Save → Push (avg 4.2x/day)"

---

## 8. Three-Tier Intelligence Architecture

> **NEW SECTION** — Core architectural concept adapted from Logitum and extended.

MacRing's intelligence operates on three tiers that work together as a continuous adaptive cycle:

```
┌────────────────────────────────────────────────────────────────────┐
│                    🔄 THE ADAPTIVE CYCLE                          │
│                                                                    │
│  ┌─────────────────────────────────────────────┐                  │
│  │  TIER 1: DISCOVERY (Instant, < 500ms)       │                  │
│  │  • App switch → load profile from DB         │                  │
│  │  • Query MCP registry for relevant servers   │                  │
│  │  • AI suggests 6-8 actions (if no profile)   │                  │
│  │  • Ring populates immediately                │                  │
│  └──────────────────┬──────────────────────────┘                  │
│                     ↓                                              │
│  ┌─────────────────────────────────────────────┐                  │
│  │  TIER 2: OBSERVATION (Passive, continuous)   │                  │
│  │  • BehaviorTracker records ring interactions  │                  │
│  │  • KeyboardMonitor tracks shortcuts used      │                  │
│  │  • Stores: action, bundleId, timestamp        │                  │
│  │  • Raw events: configurable TTL (24h default) │                  │
│  │  • Aggregated stats: 90-day retention         │                  │
│  └──────────────────┬──────────────────────────┘                  │
│                     ↓                                              │
│  ┌─────────────────────────────────────────────┐                  │
│  │  TIER 3: ADAPTATION (Intelligent, periodic)  │                  │
│  │  • On-device NLEmbedding for action sequences │                  │
│  │  • Cosine similarity clustering               │                  │
│  │  • Claude Haiku interprets clusters            │                  │
│  │  • Generates suggestions with confidence       │                  │
│  │  • User approves → ring updates permanently    │                  │
│  │  • Frequency: every 6 hours or manual trigger  │                  │
│  └──────────────────┬──────────────────────────┘                  │
│                     ↓                                              │
│            ♻️ Ring gets smarter. Repeat.                           │
└────────────────────────────────────────────────────────────────────┘
```

### Tier Comparison: MacRing vs Logitum

| Aspect | Logitum | MacRing |
|--------|---------|---------|
| **Tier 1 Discovery** | MCP Registry only | Profile DB + MCP Registry + Preset DB |
| **Tier 2 Observation** | Windows UI Automation (window titles, clicks) | BehaviorTracker (shortcuts, ring use only — no window titles) |
| **Tier 3 Adaptation** | Gemini + VoyageAI (cloud) | On-device NLEmbedding + Claude Haiku (privacy) |
| **Raw data retention** | 24h fixed | Configurable: 24h / 7d / 30d |
| **Offline Tier 1** | ❌ Degraded | ✅ Full (preset DB) |
| **Offline Tier 3** | ❌ No adaptation | ✅ Rule-based (frequency threshold) |

---

## 9. System Architecture

### 9.1 High-Level Architecture (Enhanced)

```
┌──────────────────────────────────────────────────────────────────┐
│                       MacRing Application                        │
│                                                                  │
│  PRESENTATION    Ring Window │ Configurator │ MenuBar │ Onboard  │
│  ──────────────────────────────────────────────────────────────  │
│  CORE LOGIC      ContextEngine │ ProfileMgr │ ActionExecutor     │
│                  BehaviorTracker │ SemanticAnalyzer               │
│  ──────────────────────────────────────────────────────────────  │
│  AI SERVICE      Claude Client │ PromptBuilder │ SuggestionMgr   │
│                  ResponseParser │ Cache │ RateLimiter │ TokenMgr  │
│  ──────────────────────────────────────────────────────────────  │
│  MCP LAYER       MCPClient │ MCPRegistry │ MCPToolRunner          │  ← NEW
│                  MCPServerManager │ MCPActionAdapter              │
│  ──────────────────────────────────────────────────────────────  │
│  SEMANTIC        NLEmbeddingEngine │ VectorStore │ Clusterer      │  ← NEW
│                  PatternInterpreter                               │
│  ──────────────────────────────────────────────────────────────  │
│  INPUT           EventTapManager │ NSWorkspace │ KeyboardMonitor  │
│  ──────────────────────────────────────────────────────────────  │
│  STORAGE         SQLite(GRDB) │ Keychain │ UserDefaults │ VecDB  │
│                                                                  │
│                    │ HTTPS                                        │
│              ┌─────┼──────────┐                                   │
│              ▼     ▼          ▼                                   │
│         Claude API  MCP Servers  MCP Registry                    │
│        (Anthropic)  (local/remote) (smithery.ai)                 │
└──────────────────────────────────────────────────────────────────┘
```

### 9.2 Thread Architecture

| Thread | Responsibility | QoS |
|--------|---------------|-----|
| Main | SwiftUI, user interaction | `.userInteractive` |
| EventTap | CGEventTap callback | `.userInteractive` (custom) |
| AI Queue | Claude API calls | `.utility` |
| MCP Queue | MCP tool execution | `.utility` |
| Tracker Queue | Usage recording, DB writes | `.background` |
| Semantic Queue | Embedding generation, clustering | `.background` |

---

## 10. Technology Stack

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| Language | Swift 5.10+ | Native macOS |
| UI | SwiftUI 5.0+ (macOS 14+) | Declarative, vibrancy |
| Input | CGEventTap (Quartz) | Universal mouse capture |
| App Detection | NSWorkspace + Accessibility | Official API |
| Database | SQLite via GRDB.swift 6.x | Fast, WAL mode |
| Vector Store | SQLite + custom BLOB | On-device embeddings |
| Embeddings | Core ML NLEmbedding | On-device, private |
| Keychain | Security.framework | Encrypted key storage |
| Networking | URLSession (async/await) | Built-in |
| AI | Claude API (Anthropic) | Best reasoning |
| MCP | MCP Swift SDK | Tool ecosystem |
| Auto-Update | Sparkle 2.x | Standard macOS |
| Distribution | DMG + Homebrew Cask | Non-App Store |

**New Dependencies (v2):**
- `mcp-swift-sdk` — MCP client implementation
- `NaturalLanguage.framework` — On-device NLEmbedding
- `Accelerate.framework` — Vectorized cosine similarity

---

## 11. AI Integration Deep Dive

### 11.1 Model Selection

| Feature | Model | Cost/Call | Latency |
|---------|-------|----------|---------|
| Smart Suggestions | claude-haiku-4-5-20251001 | ~$0.001 | < 1s |
| Shortcut Discovery | claude-haiku-4-5-20251001 | ~$0.001 | < 1s |
| Pattern Interpretation | claude-haiku-4-5-20251001 | ~$0.002 | < 1s |
| Auto Profile Gen | claude-sonnet-4-5-20250929 | ~$0.005 | 2–3s |
| NL Config | claude-sonnet-4-5-20250929 | ~$0.005 | 1–2s |
| Workflow Builder | claude-sonnet-4-5-20250929 | ~$0.01 | 2–4s |
| MCP Tool Selection | claude-haiku-4-5-20251001 | ~$0.001 | < 1s |

### 11.2 Data Privacy

> **CRITICAL: Stricter than Logitum.**

| Sent to Claude API | Never Sent |
|-------------------|------------|
| App bundle IDs | Window titles (unlike Logitum) |
| Shortcut key combinations | File names/paths |
| Usage frequency counts | Document content |
| Current ring configuration | Typed text/passwords |
| Aggregated behavior patterns | Screen/clipboard content |
| MCP tool names | Raw UI events |

### 11.3 Offline Fallback Matrix

| Feature | Online | Offline |
|---------|--------|---------|
| Ring (core) | ✅ | ✅ |
| Context switching | ✅ | ✅ |
| Configurator | ✅ | ✅ |
| Smart Suggestions | AI analysis | Rule-based (frequency > threshold) |
| Auto Profile | AI generates | Preset DB (50+ apps) |
| NL Config | Claude parses | ❌ Disabled |
| Workflow Builder | AI creates | ❌ Manual only |
| MCP Tools (local) | ✅ | ✅ |
| MCP Tools (remote) | ✅ | ❌ |
| Semantic Analysis | ✅ On-device + Haiku | ✅ On-device only |

---

## 12. MCP Integration (Model Context Protocol)

> **NEW SECTION** — Inspired by Logitum's killer feature.

### 12.1 What is MCP?

The Model Context Protocol is an open standard adopted by Anthropic, OpenAI, Google DeepMind, and Microsoft. It provides a universal way for AI to interact with external tools. As of 2025, there are **6,480+ MCP servers** covering Git, Slack, Notion, Jira, Linear, Docker, AWS, databases, and more.

### 12.2 Why MCP in MacRing?

Without MCP, MacRing can simulate keyboard shortcuts and run scripts. With MCP, MacRing becomes a **universal action interface** — pressing a ring slot can create a GitHub PR, send a Slack message, or create a Jira ticket. This is what Logitum proved: the power of combining a physical radial menu with the MCP ecosystem.

### 12.3 Architecture

```
User presses ring slot → action type = MCP Tool Call
    ↓
MCPActionAdapter wraps the action
    ↓
MCPClient connects to appropriate MCP server
  ├─ Local server (e.g., filesystem, git)  → stdio transport
  └─ Remote server (e.g., Slack, Notion)   → SSE/HTTP transport
    ↓
MCP server executes tool
    ↓
Result returned → notification shown to user
```

### 12.4 MCP Discovery Flow

```
1. User opens app (e.g., VS Code)
2. ContextEngine detects: com.microsoft.VSCode
3. MCPRegistry query: "What MCP servers are relevant for code editing?"
4. Registry returns: GitHub, GitLab, Docker, Linear, Sentry
5. Check locally installed: GitHub ✅, Docker ✅, Linear ❌
6. Available MCP tools added to ring (or sub-ring)
7. Unavailable tools shown grayed with "Install" option
```

### 12.5 MCP Server Management

| Feature | Description |
|---------|-------------|
| **Auto-Discovery** | Query smithery.ai registry on app switch |
| **Local Installation** | `npx @mcp/server-github` or bundled binaries |
| **Server Health** | Heartbeat check, auto-reconnect |
| **Config Storage** | `~/.macring/mcp-servers.json` |
| **Credential Mgmt** | Per-server tokens stored in Keychain |

### 12.6 MCP Action Types

| Action | Example | Transport |
|--------|---------|-----------|
| `mcp_tool_call` | "Create GitHub PR" | stdio/HTTP |
| `mcp_workflow` | "Create PR → Post to Slack → Update Linear" | Chained |
| `mcp_query` | "List open issues" → show in popover | Read-only |

### 12.7 Example MCP Ring (VS Code context)

| Slot | Label | Type | MCP Server |
|------|-------|------|-----------|
| 0 | Run | Keyboard | — |
| 1 | Debug | Keyboard | — |
| 2 | Save | Keyboard | — |
| 3 | Terminal | Keyboard | — |
| 4 | **Git Push** | **MCP** | **github** |
| 5 | **Create PR** | **MCP** | **github** |
| 6 | Find | Keyboard | — |
| 7 | **→ MCP Tools** | **Sub-Ring** | (multiple) |

---

## 13. Semantic Behavior Analysis

> **NEW SECTION** — Inspired by Logitum's VoyageAI + clustering approach, but done on-device for privacy.

### 13.1 Overview

Logitum uses VoyageAI cloud embeddings to cluster user behavior. MacRing achieves the same result **on-device** using Apple's `NLEmbedding` (Core ML), avoiding another API key and keeping all behavioral data local.

### 13.2 Pipeline

```
Raw Action Log (Tier 2)
    ↓
Sequence Extraction: group actions within 30s windows
    ↓
Sequence Encoding: "VS Code: ⌘S → ⌘⇧F → Shell(git push)"
    ↓
NLEmbedding.embedding(for: sequenceString) → [Float] vector (512-dim)
    ↓
Store in vector_store table (SQLite BLOB)
    ↓
Cosine Similarity Clustering (k-NN, k=5)
    ↓
Clusters interpreted by Claude Haiku:
  "Cluster A: Code deployment workflow (Save → Format → Push)"
  "Cluster B: Research workflow (New Tab → Search → Bookmark)"
    ↓
Generate actionable suggestions from clusters
```

### 13.3 Clustering Algorithm

```swift
// Simplified cosine similarity clustering
func findSimilarSequences(to target: [Float], in vectors: [[Float]], k: Int = 5) -> [Int] {
    let similarities = vectors.map { cosineSimilarity(target, $0) }
    return similarities.enumerated()
        .sorted { $0.element > $1.element }
        .prefix(k)
        .map { $0.offset }
}

func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    let dot = zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
    let normA = sqrt(a.reduce(0) { $0 + $1 * $1 })
    let normB = sqrt(b.reduce(0) { $0 + $1 * $1 })
    return dot / (normA * normB)
}
```

### 13.4 Privacy: MacRing vs Logitum

| Aspect | Logitum | MacRing |
|--------|---------|---------|
| Embedding engine | VoyageAI (cloud) | NLEmbedding (on-device) |
| Data sent | Action sequences to VoyageAI | Nothing — all local |
| API keys needed | Gemini + VoyageAI | Claude only (for interpretation) |
| Interpretation | Gemini (cloud) | Haiku (aggregated patterns only) |

---

## 14. Universal Mouse Support

> **NEW SECTION** — Technical deep-dive on why MacRing works with any mouse.

### 14.1 How CGEventTap Works

macOS HID (Human Interface Device) stack normalizes ALL mice:

```
Physical Mouse (USB/Bluetooth)
    ↓
IOKit HID Driver (kernel)
    ↓
Quartz Event Services (user space)
    ↓
CGEvent with:
  - type: .otherMouseDown / .otherMouseUp
  - mouseButton: CGMouseButton (0-31)
  - location: CGPoint
    ↓
CGEventTap intercepts here (regardless of mouse brand)
```

**Key insight:** `CGMouseButton` is a simple integer. Button 3 is button 3 whether it's Logitech, Razer, or a $5 Amazon mouse. MacRing doesn't need vendor-specific drivers.

### 14.2 Button Mapping by Brand

| Button | Logitech MX | Razer Death Adder | Keychron M6 | Generic 5-btn |
|--------|------------|-------------------|-------------|---------------|
| Left | 0 | 0 | 0 | 0 |
| Right | 1 | 1 | 1 | 1 |
| Middle | 2 | 2 | 2 | 2 |
| Side Back | 3 | 3 | 3 | 3 |
| Side Fwd | 4 | 4 | 4 | 4 |
| Extra 1 | 5 (gesture) | 5 (DPI) | 5 | — |
| Extra 2+ | 6-10 | 6-8 | — | — |

### 14.3 Known Edge Cases

| Scenario | Solution |
|----------|----------|
| Apple Magic Mouse (no extra buttons) | Keyboard trigger fallback (e.g., Caps Lock hold) |
| Gaming mice with DPI buttons | Button recording mode identifies them |
| Logitech Options+ conflict | Detect on launch, guide user to disable specific button in Options+ |
| BetterTouchTool conflict | Detect, offer migration guide |

---

## 15. Data Models & Database Schema

### 15.1 Core Models (Swift)

```swift
struct RingProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    var bundleId: String?
    var category: AppCategory?
    var slots: [RingSlot]
    var slotCount: Int
    var isDefault: Bool
    var mcpServers: [String]          // NEW: associated MCP server IDs
    var createdAt: Date
    var updatedAt: Date
    var source: ProfileSource         // .builtin, .user, .ai, .community, .mcp
}

enum RingAction: Codable {
    // ... all 11 from v1 ...
    case mcpToolCall(MCPToolAction)   // NEW
    case mcpWorkflow(MCPWorkflowAction) // NEW
}

struct MCPToolAction: Codable {       // NEW
    let serverId: String              // e.g. "github"
    let toolName: String              // e.g. "create_pull_request"
    let parameters: [String: String]  // pre-filled params
    let displayName: String
}

struct BehaviorSequence: Codable {    // NEW
    let id: UUID
    let actions: [ActionEvent]        // ordered list
    let bundleId: String
    let timestamp: Date
    let embedding: [Float]?           // NLEmbedding vector
    let clusterId: Int?
}
```

### 15.2 Database Tables (Enhanced)

| Table | Purpose | Retention | New? |
|-------|---------|-----------|------|
| `profiles` | Ring profiles with JSON slots | Permanent | ❌ |
| `usage_records` | Action usage history | 90 days | ❌ |
| `ai_suggestions` | Suggestion history | 30 days | ❌ |
| `ai_cache` | Cached AI responses | 7 days | ❌ |
| `triggers` | Button configurations | Permanent | ❌ |
| `shortcut_presets` | Bundled shortcuts | App updates | ❌ |
| **`raw_interactions`** | **Raw action events** | **24h–30d (configurable)** | **✅** |
| **`behavior_sequences`** | **Grouped action sequences** | **90 days** | **✅** |
| **`vector_store`** | **Embedding vectors (BLOB)** | **90 days** | **✅** |
| **`behavior_clusters`** | **Clustered patterns** | **90 days** | **✅** |
| **`mcp_servers`** | **Installed MCP servers** | **Permanent** | **✅** |
| **`mcp_tools`** | **Discovered MCP tools** | **7 days** | **✅** |
| **`mcp_credentials`** | **Server auth tokens (ref to Keychain)** | **Permanent** | **✅** |

---

## 16. UI/UX Design Specification

*(Same as PRD v1 — ring geometry, colors, animations, windows)*

**New additions:**
- MCP action slots show a small 🔗 badge in the corner
- MCP tool browser accessible from configurator toolbox
- Semantic insights tab in analytics dashboard

---

## 17. Development Phases & Timeline

> **Updated: 14 weeks → 18 weeks** (added MCP + Semantic phases)

### Phase 1: Foundation (Weeks 1–3) — Same as v1
Ring appears → select → executes. Universal mouse support. Menu bar.

### Phase 2: Context Awareness (Weeks 4–5) — Same as v1
Auto-switching profiles. 10 presets. Fullscreen detection. **→ MVP**

### Phase 3: Configurator Studio (Weeks 6–8) — Same as v1
Visual drag-and-drop. Settings. Import/export.

### Phase 4: AI Integration (Weeks 9–12) — Same as v1
Smart suggestions, auto-profile, NL config, workflow builder, offline fallback.

### Phase 5: MCP Integration (Weeks 13–15) *(NEW)*

**Week 13:** MCP Swift SDK integration, MCPClient, server lifecycle management, stdio/HTTP transports
**Week 14:** MCPRegistry discovery, MCP action type in ring, MCP tool browser in configurator, credential management
**Week 15:** MCP workflows (chained tools), MCP sub-ring, auto-discovery on app switch, testing with 5+ MCP servers

✅ **Deliverable:** MCP tools executable from ring. Auto-discovery. GitHub, Slack, Notion tested.

### Phase 6: Semantic Analysis (Week 16) *(NEW)*

**Week 16:** NLEmbedding integration, BehaviorSequence extraction, vector storage, cosine similarity clustering, Haiku interpretation of clusters, suggestion generation from clusters

✅ **Deliverable:** On-device behavior analysis. Workflow pattern suggestions.

### Phase 7: Polish & Launch (Weeks 17–18) — Enhanced from v1

**Week 17:** Onboarding (includes MCP setup), testing, performance profiling, accessibility audit
**Week 18:** Code signing, notarization, DMG, Sparkle, Homebrew, landing page, documentation

✅ **Deliverable:** MacRing v1.0 shipped

### Summary Timeline

| Phase | Weeks | Milestone |
|-------|-------|-----------|
| Foundation | 1–3 | Working ring |
| Context | 4–5 | **MVP** |
| Configurator | 6–8 | Visual editor |
| AI | 9–12 | AI features |
| MCP | 13–15 | MCP tools |
| Semantic | 16 | Behavior analysis |
| Polish | 17–18 | **v1.0 Launch** |

---

## 18. API Key & Security

*(Same as PRD v1 + MCP credential security)*

**New: MCP Credentials**
- Each MCP server may require its own auth token (GitHub PAT, Slack Bot Token, etc.)
- All stored in macOS Keychain, tagged per server
- Users manage via Settings → MCP → Servers → Credentials
- Tokens never leave the device (MCP servers run locally or direct HTTPS)

---

## 19. Performance Requirements

| Metric | Target |
|--------|--------|
| Ring appearance | < 50ms |
| Ring framerate | 60fps |
| Slot selection | < 5ms |
| Action execution (local) | < 20ms |
| **MCP tool execution** | **< 3s (network dependent)** |
| App detection | < 10ms |
| **MCP discovery** | **< 500ms** |
| Memory (idle) | < 35MB |
| Memory (ring open) | < 55MB |
| CPU (idle) | < 0.1% |
| **Embedding generation** | **< 200ms per sequence** |
| **Clustering (100 vectors)** | **< 500ms** |
| DB query | < 5ms |

---

## 20. Testing Strategy

*(Same as PRD v1 + MCP and Semantic testing)*

**New Test Categories:**

| Category | Tests |
|----------|-------|
| MCP Integration | Server connection, tool execution, error handling, timeout, retry |
| MCP Discovery | Registry query, relevance matching, cache invalidation |
| Semantic Analysis | Embedding quality, cluster stability, suggestion relevance |
| Universal Mouse | Test with 5+ mouse brands, button recording accuracy |
| Privacy | Verify no window titles sent, TTL enforcement, data deletion |

---

## 21. Distribution & Deployment

*(Same as PRD v1)*

---

## 22. Risk Analysis & Mitigation

*(Enhanced from PRD v1)*

| Risk | Severity | Mitigation |
|------|----------|------------|
| Accessibility permission confusing | High | Step-by-step onboarding with screenshots |
| Conflict with BetterTouchTool/Karabiner | Medium | Auto-detect + migration guide |
| Mouse button IDs vary across brands | Medium | Button recording mode, test 5+ brands |
| AI generates poor profiles | Medium | Preview, undo, confidence score |
| AI cost concerns | Medium | Real-time tracking, "AI optional" messaging |
| macOS update breaks CGEventTap | High | Beta testing, community reports |
| **MCP server instability** | **Medium** | **Heartbeat, auto-reconnect, graceful fallback** |
| **MCP ecosystem changes** | **Low** | **Registry abstraction layer, version pinning** |
| **NLEmbedding quality on-device** | **Medium** | **Fallback to frequency-only analysis** |
| **MCP credential leakage** | **High** | **Keychain storage, per-server isolation** |

---

## 23. Future Roadmap (Post v1.0)

| Version | Feature | Source of Inspiration |
|---------|---------|----------------------|
| v1.1 | Sub-Ring (nested rings) | MacRing v1 |
| v1.1 | Multi-Ring per button (modifier combos) | MacRing v1 |
| v1.2 | Community Profile Marketplace | MacRing v1 + Logitum roadmap |
| v1.2 | **MCP Server Marketplace** | Logitum + MCP ecosystem |
| v1.3 | **Team collaboration (shared profiles)** | Logitum roadmap |
| v1.3 | Macro Recorder | MacRing v1 |
| v1.4 | **Voice control integration** | Logitum roadmap |
| v1.4 | Theming Engine | MacRing v1 |
| v2.0 | **Cross-app workflow automation** | Logitum vision |
| v2.0 | iPad Support | MacRing v1 |
| v2.0 | Cross-Device Sync (iCloud) | MacRing v1 + Logitum roadmap |
| v2.0 | **Windows/Linux port** | Logitum (Windows-first) |
| v2.0 | Plugin SDK for custom action types | Logitum roadmap |

---

## 24. Cost Analysis & Business Model

### Development Costs

| Item | Cost |
|------|------|
| Apple Developer Program | $99/year |
| Domain (macring.app) | $15/year |
| GitHub Pro | $4/month |
| Test mice (5 brands) | ~$500 one-time |
| Claude API (dev + testing) | ~$15/month |
| **Total Year 1** | **~$700** |

### Business Model: Freemium (Recommended)

| Tier | Features | Price |
|------|----------|-------|
| **Free** | Core ring, context switching, configurator, import/export, 50+ presets | $0 |
| **Pro** ($19.99 one-time) | AI features, NL config, workflow builder, semantic analysis | $19.99 |
| **MCP Pack** ($9.99 one-time) | MCP integration, tool discovery, MCP workflows | $9.99 |
| **Bundle** | Pro + MCP | $24.99 |

*Users provide their own API key for Claude. MCP servers are open-source/free.*

---

## 25. Success Metrics & KPIs

### Launch (30 Days)

| Metric | Target |
|--------|--------|
| Downloads | 1,000+ |
| DAU | 300+ |
| Onboarding completion | > 80% |
| Mouse brands successfully used | 5+ |
| Crash rate | < 0.1% |

### Product Quality

| Metric | Target |
|--------|--------|
| Ring latency P99 | < 50ms |
| Context accuracy (top 50 apps) | 100% |
| AI suggestion acceptance | > 80% |
| **MCP tool success rate** | **> 95%** |
| **Semantic suggestion relevance** | **> 70%** |

### Growth (6 Months)

| Metric | Target |
|--------|--------|
| Total downloads | 10,000+ |
| GitHub stars | 500+ |
| Pro conversion | > 15% |
| **MCP Pack conversion** | **> 10%** |
| **MCP servers used per user (avg)** | **3+** |
| Community profiles shared | 100+ |

---

## 26. Appendix A: Project File Structure

```
MacRing/
├── App/
│   ├── MacRingApp.swift
│   └── AppDelegate.swift
├── Core/
│   ├── Input/
│   │   ├── EventTapManager.swift         // Universal mouse capture
│   │   ├── MouseButtonRecorder.swift     // Brand-agnostic recording
│   │   └── KeyboardMonitor.swift
│   ├── Context/
│   │   ├── AppDetector.swift
│   │   ├── ContextEngine.swift
│   │   ├── FullscreenDetector.swift
│   │   └── AppCategoryMap.swift
│   ├── Profile/
│   │   ├── ProfileManager.swift
│   │   ├── RingProfile.swift
│   │   ├── RingSlot.swift
│   │   ├── RingAction.swift              // 13 action types
│   │   ├── MCPToolAction.swift           // NEW
│   │   ├── MCPWorkflowAction.swift       // NEW
│   │   └── BuiltInProfiles.swift
│   └── Execution/
│       ├── ActionExecutor.swift
│       ├── KeyboardSimulator.swift
│       ├── ScriptRunner.swift
│       ├── SystemActionRunner.swift
│       ├── WorkflowRunner.swift
│       └── MCPActionRunner.swift          // NEW
├── AI/
│   ├── AIService.swift
│   ├── AIPromptBuilder.swift
│   ├── AIResponseParser.swift
│   ├── SuggestionManager.swift
│   ├── BehaviorTracker.swift
│   ├── AICache.swift
│   └── TokenTracker.swift
├── MCP/                                    // NEW LAYER
│   ├── MCPClient.swift                    // MCP SDK wrapper
│   ├── MCPRegistry.swift                  // smithery.ai discovery
│   ├── MCPServerManager.swift             // Lifecycle management
│   ├── MCPToolRunner.swift                // Tool execution
│   ├── MCPActionAdapter.swift             // RingAction → MCP call
│   └── MCPCredentialManager.swift         // Keychain per-server
├── Semantic/                               // NEW LAYER
│   ├── NLEmbeddingEngine.swift            // Core ML embeddings
│   ├── VectorStore.swift                  // SQLite BLOB storage
│   ├── SequenceExtractor.swift            // 30s window grouping
│   ├── CosineSimilarity.swift             // Accelerate framework
│   ├── BehaviorClusterer.swift            // k-NN clustering
│   └── PatternInterpreter.swift           // Haiku interpretation
├── UI/
│   ├── Ring/ ... (same as v1)
│   ├── Configurator/
│   │   ├── ... (same as v1)
│   │   └── MCPToolBrowser.swift           // NEW
│   ├── MenuBar/ ... (same as v1)
│   ├── Onboarding/
│   │   ├── ... (same as v1)
│   │   └── MCPSetupView.swift             // NEW
│   └── Settings/
│       ├── ... (same as v1)
│       ├── MCPSettingsView.swift           // NEW
│       └── SemanticInsightsView.swift      // NEW
├── Storage/
│   ├── Database.swift
│   ├── KeychainManager.swift
│   ├── ShortcutDatabase.swift
│   └── VectorDatabase.swift               // NEW
├── Resources/
│   ├── shortcut_presets.json
│   ├── app_categories.json
│   ├── mcp_server_defaults.json           // NEW
│   └── Assets.xcassets
└── Tests/
    ├── MacRingTests/
    │   ├── ... (same as v1)
    │   ├── MCPClientTests.swift            // NEW
    │   ├── SemanticAnalysisTests.swift     // NEW
    │   └── UniversalMouseTests.swift       // NEW
    ├── MacRingIntegrationTests/
    └── MacRingUITests/
```

---

## 27. Appendix B: Built-in Profile Presets

*(Same as PRD v1: VS Code, Chrome, Figma, Finder, Default)*

**New: MCP-Enhanced Presets**

### VS Code + MCP (`com.microsoft.VSCode`)

| Slot | Label | Type | Source |
|------|-------|------|--------|
| 0 | Run | Keyboard ⌃F5 | Built-in |
| 1 | Debug | Keyboard ⌘⇧F5 | Built-in |
| 2 | Save | Keyboard ⌘S | Built-in |
| 3 | Terminal | Keyboard ⌃\` | Built-in |
| 4 | **Git Push** | **MCP** | **github server** |
| 5 | **Create PR** | **MCP** | **github server** |
| 6 | Find | Keyboard ⌘⇧F | Built-in |
| 7 | **→ More MCP** | **Sub-Ring** | Docker, Linear, etc. |

---

## 28. Appendix C: AI Prompt Templates

*(Same as PRD v1 + new MCP and Semantic templates)*

### MCP Tool Suggestion Prompt *(NEW)*

**System:** "You are MacRing MCP advisor. Given the app context and available MCP servers, suggest which MCP tools should appear in the ring. Return ONLY valid JSON."

**User:** "App: {bundleId}\nCategory: {category}\nAvailable MCP servers: {serverList}\nCurrent ring: {slots}\nSuggest up to 3 MCP tools to add."

### Semantic Pattern Interpretation Prompt *(NEW)*

**System:** "You are MacRing behavior analyst. Given clustered action sequences, interpret the workflow pattern and suggest a named macro. Return ONLY valid JSON."

**User:** "Cluster of {N} similar sequences:\n{representativeSequences}\nAvg frequency: {freq}/day\nApp: {bundleId}\nInterpret this pattern and suggest a one-click workflow."

---

## 29. Appendix D: MCP Server Registry Examples

> **NEW APPENDIX** — Common MCP servers MacRing integrates with.

| Server | Tools | Use Case |
|--------|-------|----------|
| `@modelcontextprotocol/server-github` | create_pr, push, list_issues, review | Git workflows |
| `@modelcontextprotocol/server-slack` | send_message, react, search | Team communication |
| `@modelcontextprotocol/server-notion` | create_page, search, update | Knowledge management |
| `@modelcontextprotocol/server-linear` | create_issue, update_status | Project tracking |
| `@modelcontextprotocol/server-filesystem` | read, write, search | File operations |
| `@modelcontextprotocol/server-docker` | start, stop, logs | Container management |
| `@modelcontextprotocol/server-postgres` | query, schema | Database |
| `@modelcontextprotocol/server-brave-search` | search | Web search |
| `@modelcontextprotocol/server-puppeteer` | navigate, screenshot | Browser automation |
| `@modelcontextprotocol/server-memory` | store, retrieve | AI memory |

*Registry: [smithery.ai](https://smithery.ai) — Updated automatically. 6,480+ servers as of Feb 2026.*

---

## 30. Appendix E: Glossary

*(All terms from PRD v1 + new terms)*

| Term | Definition |
|------|-----------|
| **Action Ring** | The circular radial menu activated by trigger button |
| **Slot** | One segment of the ring (max 8) |
| **Dead Zone** | Center cancel area |
| **Trigger** | Mouse button that activates ring |
| **Profile** | Slot configurations for a specific app |
| **Context Switch** | Auto profile change on app focus |
| **Bundle ID** | Apple's app identifier |
| **CGEventTap** | macOS global input interception API |
| **Glassmorphism** | Frosted glass UI style |
| **GRDB** | Swift SQLite library |
| **Sparkle** | macOS auto-update framework |
| **NL Config** | Natural Language Configuration |
| **Sub-Ring** | Nested ring from parent slot |
| **WAL** | Write-Ahead Logging (SQLite) |
| **MCP** | Model Context Protocol — open standard for AI tool interop |
| **MCP Server** | A service exposing tools via MCP (e.g., GitHub, Slack) |
| **MCP Registry** | Directory of available MCP servers (smithery.ai) |
| **Three-Tier Intelligence** | Discovery → Observation → Adaptation architecture |
| **Semantic Analysis** | Understanding action patterns through embeddings |
| **NLEmbedding** | Apple's on-device text embedding (Core ML) |
| **Cosine Similarity** | Measure of vector angle similarity (0–1) |
| **Vector Clustering** | Grouping similar embeddings by proximity |
| **Behavior Sequence** | Ordered list of actions within a time window |
| **Adaptive Cycle** | Continuous loop: use → observe → learn → improve |
| **Zero Config** | Design philosophy: useful immediately, no setup required |

---

> **End of PRD — Version 2.0.0**
>
> *Enhanced after analysis of Logitum Adaptive Ring (HackaTUM 2025).*
> *Key additions: MCP integration, Three-Tier Intelligence, Semantic Behavior Analysis, Universal Mouse Support, Competitive Analysis.*
> *This document is the single source of truth for MacRing v1.0 development.*
