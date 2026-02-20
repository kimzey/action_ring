# MacRing — Testing Guide

> Coverage target: **80% minimum** across all modules.
> Frameworks: XCTest (unit + integration), XCUITest (UI/E2E).

---

## Test Structure

```
Tests/
├── MacRingTests/              - Unit tests (XCTest)
│   ├── Input/
│   │   ├── EventTapManagerTests.swift
│   │   ├── MouseButtonRecorderTests.swift
│   │   └── UniversalMouseTests.swift
│   ├── Context/
│   │   ├── AppDetectorTests.swift
│   │   ├── ContextEngineTests.swift
│   │   └── FullscreenDetectorTests.swift
│   ├── Profile/
│   │   ├── ProfileManagerTests.swift
│   │   └── ProfileImportExportTests.swift
│   ├── Execution/
│   │   ├── ActionExecutorTests.swift
│   │   ├── KeyboardSimulatorTests.swift
│   │   └── WorkflowRunnerTests.swift
│   ├── AI/
│   │   ├── AIServiceTests.swift
│   │   ├── AIPromptBuilderTests.swift
│   │   ├── SuggestionManagerTests.swift
│   │   ├── BehaviorTrackerTests.swift
│   │   ├── NLConfigEngineTests.swift
│   │   └── TokenTrackerTests.swift
│   ├── MCP/
│   │   ├── MCPClientTests.swift
│   │   ├── MCPServerManagerTests.swift
│   │   ├── MCPRegistryTests.swift
│   │   ├── MCPToolRunnerTests.swift
│   │   └── MCPCredentialManagerTests.swift
│   ├── Semantic/
│   │   ├── NLEmbeddingEngineTests.swift
│   │   ├── BehaviorClustererTests.swift
│   │   ├── CosineSimilarityTests.swift
│   │   └── SemanticAnalysisTests.swift
│   └── Storage/
│       ├── DatabaseTests.swift
│       └── KeychainManagerTests.swift
├── MacRingIntegrationTests/   - Integration tests
│   ├── ContextSwitchingIntegrationTests.swift
│   ├── AIIntegrationTests.swift
│   ├── MCPIntegrationTests.swift
│   └── RingViewModelTests.swift
├── MacRingUITests/            - E2E tests (XCUITest)
│   ├── RingAppearanceUITests.swift
│   ├── ConfiguratorUITests.swift
│   ├── OnboardingUITests.swift
│   ├── SettingsUITests.swift
│   └── E2ETests.swift
└── Mocks/
    ├── MockMCPServer.swift    - Local stdio MCP server for tests
    ├── MockURLSession.swift   - For AIService tests
    └── MockDatabase.swift     - In-memory GRDB for isolation
```

---

## Running Tests

```bash
# Run all tests
xcodebuild test -scheme MacRing -destination 'platform=macOS'

# Run single test class
xcodebuild test -scheme MacRing \
  -only-testing MacRingTests/ProfileManagerTests \
  -destination 'platform=macOS'

# Run single test method
xcodebuild test -scheme MacRing \
  -only-testing MacRingTests/ProfileManagerTests/testLookupChainFallsBackToDefault \
  -destination 'platform=macOS'

# Run only unit tests (no UI)
xcodebuild test -scheme MacRing \
  -only-testing MacRingTests \
  -destination 'platform=macOS'

# Run with coverage report
xcodebuild test -scheme MacRing \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES

# Run performance tests only
xcodebuild test -scheme MacRing \
  -only-testing MacRingTests/PerformanceTests \
  -destination 'platform=macOS'
```

---

## Critical Test Categories

### 1. Privacy Tests (CRITICAL — must never fail)

`MacRingTests/AI/AIPromptBuilderTests.swift`

```swift
// Verify no forbidden data ever appears in prompts
func testPromptNeverContainsWindowTitle() {
    // inject mock context with window title
    // verify prompt string does not contain it
}

func testPromptNeverContainsFilePath() { ... }
func testPromptNeverContainsDocumentContent() { ... }
func testPromptNeverContainsTypedText() { ... }
```

These tests must be in CI and block merges if they fail.

---

### 2. Ring Geometry Tests

`MacRingIntegrationTests/RingViewModelTests.swift`

Cover all slot counts and boundary angles:

| Slot Count | Test Cases |
|-----------|-----------|
| 4 slots | 0°, 45°, 90°, 135°, 180°, 225°, 270°, 315°, 360° |
| 6 slots | Boundary angles for 60° segments |
| 8 slots | Boundary angles for 45° segments |
| Dead zone | Points within 35px of center → no slot selected |
| Exact boundaries | Angles exactly on slot boundaries (verify consistent rounding) |

```swift
func testSlotSelectionFor8Slots() {
    let vm = RingViewModel()
    // Slot 0 is at 0° (right)
    XCTAssertEqual(vm.slotAt(dx: 100, dy: 0), 0)
    // Slot 2 is at 90° (down)
    XCTAssertEqual(vm.slotAt(dx: 0, dy: 100), 2)
    // Dead zone
    XCTAssertNil(vm.slotAt(dx: 10, dy: 5))  // within 35px
}
```

---

### 3. Universal Mouse Tests

`MacRingTests/Input/UniversalMouseTests.swift`

Simulate CGEvent for mouse buttons 0–10 across all tested brands:

```swift
func testButtonDetectionForLogitech() {
    // Simulate CGMouseButton(3) (side back on Logitech MX)
    // Verify EventTapManager fires trigger callback
}

func testButtonDetectionForGenericMouse() {
    // Simulate CGMouseButton(4) (side forward, generic)
}

func testAllButtonIndicesDetected() {
    for buttonIndex in 2...10 {
        // Verify each is detectable when set as trigger
    }
}
```

> Additionally: manual testing required with physical mice (Logitech, Razer, Keychron, SteelSeries, generic).

---

### 4. Performance Tests

`MacRingTests/PerformanceTests.swift`

```swift
func testRingAppearanceLatency() {
    measure(metrics: [XCTClockMetric()]) {
        // Trigger ring appearance, measure to first frame
        // Must be < 50ms
    }
}

func testSlotSelectionLatency() {
    measure {
        // 1000 slot selection calculations
        // Must average < 5ms each
    }
}

func testEmbeddingGenerationLatency() {
    measure {
        // Generate embedding for a 10-action sequence
        // Must be < 200ms
    }
}

func testClusteringLatency() {
    measure {
        // Cluster 100 512-dim vectors
        // Must be < 500ms
    }
}
```

---

### 5. MCP Integration Tests

`MacRingIntegrationTests/MCPIntegrationTests.swift`

Uses `MockMCPServer` (local stdio process that returns predictable JSON):

```swift
func testToolExecutionSuccess() async throws {
    let mockServer = MockMCPServer(tools: [
        MockTool(name: "create_pr", returns: ["pr_url": "https://..."])
    ])
    // Start mock server, connect MCPClient, call tool, verify result
}

func testToolExecutionTimeout() async throws {
    let mockServer = MockMCPServer(delay: 4.0)  // exceeds 3s timeout
    // Verify MCPToolRunner returns .timeout error within 3.5s
}

func testCredentialIsolation() throws {
    // Store credential for "github"
    // Verify "slack" credential storage returns nil
    // Verify only "github" Keychain entry exists
}
```

---

### 6. AI Service Tests (Mocked)

`MacRingTests/AI/AIServiceTests.swift`

Uses `MockURLSession` — never makes real API calls in tests:

```swift
func testRetryOn429() async throws {
    let session = MockURLSession(responses: [
        MockResponse(statusCode: 429, delay: 0),
        MockResponse(statusCode: 429, delay: 0),
        MockResponse(statusCode: 200, body: validSuggestionJSON)
    ])
    // Verify 3 attempts, exponential backoff, eventual success
}

func testOfflineFallbackWhenNoConnectivity() async throws {
    // Set NWPathMonitor to offline
    // Verify SuggestionManager returns rule-based suggestions
    // Verify no URLSession calls are made
}
```

---

## Test Data & Fixtures

```
Tests/Fixtures/
├── profiles/
│   ├── valid_profile.json
│   ├── invalid_profile.json    - for import validation tests
│   └── mcp_profile.json        - profile with MCP server refs
├── ai_responses/
│   ├── valid_suggestions.json
│   ├── malformed_response.json - missing required fields
│   └── high_confidence.json    - confidence > 0.9
├── sequences/
│   ├── sample_sequence.json    - 10-action behavior sequence
│   └── cluster_data.json       - 100 pre-computed vectors
└── mcp/
    ├── tool_list.json          - mock server tool catalog
    └── tool_result.json        - mock tool execution result
```

---

## Mock Helpers

### MockMCPServer

Local stdio MCP server that runs in-process during tests. Supports:
- Configurable tool catalog
- Configurable response delays (for timeout testing)
- Configurable error responses
- Call history inspection

### MockURLSession

URLSession subclass that intercepts requests and returns pre-configured responses. Supports:
- Status code sequences (for retry testing)
- Request body inspection (for privacy test assertions)
- Configurable delays

### TestDatabase

In-memory GRDB database with all migrations applied. Supports:
- Snapshot/restore for test isolation
- Pre-populated test data

---

## CI Requirements

The following tests **must pass** before any merge:
- All unit tests in `MacRingTests/`
- All integration tests in `MacRingIntegrationTests/`
- `AIPromptBuilderTests` (privacy gate)
- `KeychainManagerTests` (credential security gate)
- Coverage must be ≥80% for changed files

UI tests run nightly (not on every PR due to speed).
