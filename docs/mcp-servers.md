# MacRing — MCP Server Reference

> See `MacRing_PRD_v2.md` §12 and §29 for full detail.
> Registry source: [smithery.ai](https://smithery.ai) — 6,480+ servers as of Feb 2026.

---

## What is MCP?

The **Model Context Protocol** is an open standard (Anthropic, OpenAI, Google DeepMind, Microsoft) that lets AI interact with external tools. MacRing uses MCP to turn ring slots into real tool executions — not just keyboard shortcuts.

**Without MCP:** Ring slot → simulate Cmd+P
**With MCP:** Ring slot → create GitHub PR + post Slack notification + update Jira ticket

---

## Supported Servers (v1.0)

| Server Package | Tools | App Category | Transport |
|----------------|-------|-------------|-----------|
| `@modelcontextprotocol/server-github` | `create_pull_request`, `push`, `list_issues`, `review_pr`, `create_branch` | IDE | stdio |
| `@modelcontextprotocol/server-slack` | `send_message`, `react`, `search`, `list_channels` | Communication | HTTP/SSE |
| `@modelcontextprotocol/server-notion` | `create_page`, `search`, `update_page`, `list_databases` | Productivity | HTTP/SSE |
| `@modelcontextprotocol/server-linear` | `create_issue`, `update_status`, `list_issues`, `assign` | IDE, Productivity | HTTP/SSE |
| `@modelcontextprotocol/server-filesystem` | `read_file`, `write_file`, `list_dir`, `search` | All | stdio |
| `@modelcontextprotocol/server-docker` | `start`, `stop`, `logs`, `list_containers`, `build` | IDE | stdio |
| `@modelcontextprotocol/server-postgres` | `query`, `schema`, `describe_table` | IDE | stdio |
| `@modelcontextprotocol/server-brave-search` | `search` | Browser | HTTP/SSE |
| `@modelcontextprotocol/server-puppeteer` | `navigate`, `screenshot`, `click`, `fill` | Browser | stdio |
| `@modelcontextprotocol/server-memory` | `store`, `retrieve`, `list`, `delete` | All | stdio |

---

## Architecture

```
User presses ring slot
       ↓
MCPActionAdapter (converts RingAction → MCP call format)
       ↓
MCPToolRunner (executes via MCPClient)
       ↓
MCPClient (mcp-swift-sdk wrapper, 3s timeout)
       ↓
    [local server via stdio]   OR   [remote server via HTTP/SSE]
       ↓
Result returned → show notification to user
```

---

## Auto-Discovery Flow

On every app switch, `ContextEngine` triggers MCP discovery:

```
App switch detected (AppDetector)
       ↓
ContextEngine queries MCPRegistry
       ↓
MCPRegistry checks local cache (mcp_tools table, 7-day TTL)
       ↓ (cache miss)
Query smithery.ai for servers matching app category
       ↓
Filter: only servers that are installed locally
       ↓
Merge relevant MCP tools into ring profile
```

---

## Credential Storage

MCP credentials are stored in **Keychain only** — never in plaintext, never in UserDefaults, never logged.

- Each server has a unique Keychain service tag: `macring.mcp.{serverId}`
- `MCPCredentialManager` wraps all Keychain access
- Credentials are displayed masked in UI (show only last 4 chars)
- Delete credential → Keychain entry removed immediately

**Required credentials per server:**

| Server | Credential Type | Keychain Service Tag |
|--------|----------------|---------------------|
| GitHub | Personal Access Token (PAT) | `macring.mcp.github` |
| Slack | Bot Token (`xoxb-...`) | `macring.mcp.slack` |
| Notion | Integration Token | `macring.mcp.notion` |
| Linear | API Key | `macring.mcp.linear` |
| Brave Search | API Key | `macring.mcp.brave-search` |
| Filesystem | None (uses local permissions) | — |
| Docker | None (uses Docker socket) | — |
| PostgreSQL | Connection string | `macring.mcp.postgres` |

---

## MCP Action Types

### Single Tool Call

```swift
struct MCPToolAction: Codable {
    let serverId: String       // e.g., "github"
    let toolName: String       // e.g., "create_pull_request"
    let parameters: [String: String]  // pre-filled params
    let displayName: String    // shown in ring slot
}
```

**Parameter templating** (substituted at execution time):

| Template | Value |
|----------|-------|
| `{currentBranch}` | Current git branch from filesystem server |
| `{activeRepo}` | Current repository from git context |
| `{clipboardText}` | Current clipboard content |
| `{appName}` | Currently focused app name |

### Workflow (Chained Calls)

```swift
struct MCPWorkflowAction: Codable {
    let name: String
    let description: String
    let steps: [MCPWorkflowStep]
}

struct MCPWorkflowStep: Codable {
    let action: MCPToolAction
    let stopOnError: Bool       // default: true
    let outputMapping: [String: String]?  // pass output to next step
}
```

**Example workflow — "Push & Notify":**
1. `github.push` → push current branch
2. `github.create_pull_request` → create PR (uses push output for branch)
3. `slack.send_message` → post PR URL to #dev channel

---

## Error Handling

| Error Condition | Behavior |
|----------------|----------|
| Server not connected | Show "Reconnecting..." → auto-reconnect → retry once |
| Server unreachable | Show "MCP unavailable" notification. Slot shows error badge. |
| Tool not found | Show error notification. Log for debugging. |
| Parameter validation failure | Show error with specific missing/invalid field |
| Timeout (>3s) | Cancel, show "Timed out" notification |
| Auth failure | Show credential setup prompt → MCPSettingsView |
| Workflow step fails | Stop workflow, show which step failed, offer retry |

---

## Installation

### Via MacRing UI (Recommended)
1. Open Settings → MCP tab
2. Click "Browse Servers"
3. Select server → click "Install"
4. MacRing installs via npm and manages the process

### Manual Installation
```bash
# Install server package globally
npm install -g @modelcontextprotocol/server-github

# MacRing discovers it automatically via MCPRegistry scan
```

### Configuration File
User MCP config is stored at `~/.macring/mcp-servers.json`:

```json
{
  "servers": [
    {
      "id": "github",
      "package": "@modelcontextprotocol/server-github",
      "transport": "stdio",
      "enabled": true,
      "autoStart": true,
      "categories": ["IDE"]
    },
    {
      "id": "slack",
      "package": "@modelcontextprotocol/server-slack",
      "transport": "sse",
      "url": "http://localhost:3001",
      "enabled": true,
      "autoStart": false,
      "categories": ["Communication"]
    }
  ]
}
```

---

## Testing MCP Integration

**Mock server for tests:**
```swift
// MacRingTests/Mocks/MockMCPServer.swift
// Implements a local stdio MCP server that returns predictable responses
// Used in: MCPClientTests, MCPToolRunnerTests, MCPIntegrationTests
```

**Test categories:**
- Connection lifecycle (connect, disconnect, reconnect)
- Tool listing (valid schema, empty response, malformed)
- Tool execution (success, auth failure, timeout, invalid params)
- Credential storage isolation (per-server, no cross-contamination)
- Discovery caching (hit, miss, expiry)
- Workflow chaining (success, step failure, output mapping)
