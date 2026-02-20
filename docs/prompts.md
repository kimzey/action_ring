# MacRing — AI Prompt Templates

> All prompts used by `AIPromptBuilder.swift`. Responses must be valid JSON only.
> See `MacRing_PRD_v2.md` §28 for original templates.

---

## Privacy Rule (Applied to ALL Prompts)

**Never include in any prompt:**
- Window titles
- File names / paths
- Document content
- Typed text / passwords
- Raw UI events
- Screen / clipboard content

**Safe to include:**
- App bundle IDs
- Shortcut key combinations (e.g., "Cmd+S")
- Usage frequency counts
- Ring configuration (slot labels + action types)
- Aggregated behavior patterns
- MCP tool names

---

## Model Selection

| Prompt Type | Model | Rationale |
|-------------|-------|-----------|
| Smart Suggestions | `claude-haiku-4-5-20251001` | Low latency, cost-efficient |
| Shortcut Discovery | `claude-haiku-4-5-20251001` | Low latency |
| MCP Tool Selection | `claude-haiku-4-5-20251001` | Low latency |
| Pattern Interpretation | `claude-haiku-4-5-20251001` | Low latency |
| Auto Profile Gen | `claude-sonnet-4-5-20250929` | Quality matters more than speed |
| NL Config | `claude-sonnet-4-5-20250929` | Complex intent parsing |
| Workflow Builder | `claude-sonnet-4-5-20250929` | Multi-step reasoning |

---

## Prompt Templates

### 1. Smart Suggestions (Haiku)

```
SYSTEM:
You are MacRing, a macOS shortcut ring advisor.
Given app usage data, suggest shortcuts to add or promote in the ring.
Return ONLY valid JSON. No explanation text.

USER:
App: {bundleId}
Category: {category}
Current ring slots:
{slotsJSON}
Top unused shortcuts (by frequency):
{unusedShortcuts}
Suggest up to 3 changes. Format:
{
  "suggestions": [
    {
      "slot": 0,
      "label": "...",
      "icon": "...",
      "action": { ... },
      "confidence": 0.9,
      "reason": "..."
    }
  ]
}
```

---

### 2. Auto Profile Generation (Sonnet)

```
SYSTEM:
You are MacRing profile generator. Create an 8-slot ring profile for the given app.
Use common shortcuts for the app category. Return ONLY valid JSON.

USER:
App: {bundleId}
Category: {category}
Common shortcuts for {category} apps: {categoryShortcuts}
Existing user ring configurations (for style reference): {existingProfileSummary}

Generate a profile with exactly 8 slots. Format:
{
  "name": "...",
  "slots": [
    {
      "position": 0,
      "label": "...",
      "icon": "sf_symbol_name",
      "action": {
        "type": "keyboardShortcut",
        "modifiers": ["cmd"],
        "key": "s"
      }
    }
  ]
}
Action types: keyboardShortcut, launchApplication, openURL, systemAction, shellScript, appleScript
```

---

### 3. Natural Language Config (Sonnet)

```
SYSTEM:
You are MacRing config parser. Convert natural language instructions into ring modifications.
Return ONLY valid JSON. If the instruction is ambiguous, ask for clarification in the JSON.

USER:
Current ring for {bundleId}:
{slotsJSON}
User instruction: "{nlInstruction}"

Return the modified slots or a clarification request:
{
  "action": "modify" | "clarify",
  "slots": [ ... ],  // if action == "modify"
  "question": "..."  // if action == "clarify"
}
```

---

### 4. Workflow Builder (Sonnet)

```
SYSTEM:
You are MacRing workflow architect. Convert a natural language workflow description into
a sequence of ring actions. Return ONLY valid JSON.

USER:
App context: {bundleId}
User description: "{workflowDescription}"
Available action types: keyboardShortcut, shellScript, appleScript, mcpToolCall, openURL

Generate a named multi-step workflow:
{
  "name": "...",
  "description": "...",
  "steps": [
    {
      "label": "...",
      "delayAfterMs": 200,
      "action": { ... }
    }
  ]
}
```

---

### 5. MCP Tool Selection (Haiku)

```
SYSTEM:
You are MacRing MCP advisor. Given the app context and available MCP servers,
suggest which MCP tools should appear in the ring.
Return ONLY valid JSON.

USER:
App: {bundleId}
Category: {category}
Available MCP servers: {serverList}
Current ring: {slots}
Suggest up to 3 MCP tools to add. Format:
{
  "suggestions": [
    {
      "serverId": "github",
      "toolName": "create_pull_request",
      "displayName": "Create PR",
      "icon": "arrow.triangle.pull",
      "confidence": 0.85
    }
  ]
}
```

---

### 6. Semantic Pattern Interpretation (Haiku)

```
SYSTEM:
You are MacRing behavior analyst. Given clustered action sequences,
interpret the workflow pattern and suggest a named macro.
Return ONLY valid JSON.

USER:
Cluster of {N} similar sequences:
{representativeSequences}
Avg frequency: {freq}/day
App: {bundleId}

Interpret this pattern and suggest a one-click workflow:
{
  "workflowName": "...",
  "description": "...",
  "suggestedSlotLabel": "...",
  "suggestedIcon": "sf_symbol_name",
  "confidence": 0.8,
  "steps": [ ... ]
}
```

---

## Response Validation Rules

All AI responses must be validated before use:

1. **Must be valid JSON** — parse failure → discard, use fallback
2. **Slot positions** must be 0–7 and unique
3. **Confidence** must be 0.0–1.0; only surface suggestions with confidence ≥ 0.7
4. **Action types** must be one of the 13 defined types
5. **Icon names** must be valid SF Symbol names
6. **Never auto-apply** — always show preview to user first

---

## Offline Fallback Rules

| Prompt Type | Offline Behavior |
|-------------|-----------------|
| Smart Suggestions | Rule-based: surface actions with usage count > threshold (configurable, default: 5) |
| Auto Profile Gen | Load from `shortcut_presets.json` by bundle ID or category |
| NL Config | Disabled entirely — show "AI required" message |
| Workflow Builder | Manual-only mode |
| MCP Tool Selection | Use cached `mcp_tools` table results |
| Pattern Interpretation | Show raw cluster data without interpretation |
