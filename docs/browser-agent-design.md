# Browser Agent implementation references

The in-app browser uses one `browser` tool with explicit actions. It shares the
user-visible WebView session, while tabs remain owned by a conversation. Agent
access requires both the assistant's browser tool switch and the browser's global
Agent switch. Human takeover and native-command timeouts pause only the owning
conversation and invalidate its queued work; only the affected tab stops loading.
Resuming requires a user action. `list_tabs` reads saved tab and pause state even
while commands are paused or draining. After a timeout, `close_tab` can release an
owned tab through the guarded command queue, without resuming the conversation.
Human takeover still blocks closing tabs. Disabling Agent control or changing the
global User-Agent invalidates all conversations' queued work. Page commands are
blocked while a User-Agent update applies to the engines and reloads the visible
page; saved tab state remains readable. Cancelled mutations report an unknown
outcome rather than being retried.

The supplied `deliverable(1)/04_browser_feature/tool_definitions.md` and
`tool_dispatch.md` informed the open → snapshot → action interaction, optional
screenshots, and human takeover. The UI reference is implemented separately.
OpenMinis' `BrowserUseTool.kt`, `BrowserActionGuard.kt`, `BrowserTabOwnershipTest.kt`
and `BrowserPasswordRedactionTest.kt` were inspected for scoped tab ownership,
bounded native waits and password redaction. No OpenMinis code is vendored.

Primary upstream references inspected on 2026-10-14:

- [Microsoft Playwright MCP](https://github.com/microsoft/playwright-mcp): structured
  snapshots and optional vision. Kelivo uses compact visible DOM snapshots to
  avoid requiring a vision model for routine navigation. This is not a complete
  native accessibility tree.
- [Vercel agent-browser](https://github.com/vercel-labs/agent-browser): snapshot
  refs, unique selectors, content provenance and explicit unknown outcomes.
  Kelivo binds refs to one document snapshot and rejects them after DOM mutation.
- [browser-use](https://github.com/browser-use/browser-use): a mature browser
  agent implementation inspected as an alternative. Its Python/CDP runtime is
  not embedded into the mobile app; mobile WebViews remain the browser engine.

`BrowserAutomationScript` supports visible elements in open shadow roots and
same-origin frames. Cross-origin frames and closed shadow roots cannot be
traversed. Click/type/press use DOM APIs and synthetic input events; websites
that require trusted input, permission dialogs, CAPTCHA or native UI need human
control. A script that already started may have acted before cancellation; it
cannot be rolled back by stopping navigation.

Snapshots redact password values. Results are explicitly marked as untrusted
website data. These markers guide the model and do not constitute a sandbox or
prompt injection security boundary. `evaluate` deliberately permits JavaScript
inside the page when browser control is enabled. It has no app bridge or local
filesystem capability provided by this tool.

Screenshot bytes are saved by `McpImageSnapshot` and returned through the existing
typed image metadata. OpenAI, Claude and Gemini continuation/history code reads
the image through `ToolResultContent`, including the existing no-vision behavior.
Arbitrary website text cannot authorize a local file read.

Validation entry points:

```sh
flutter test test/core/services/browser/browser_tools_service_test.dart
KELIVO_PLAYWRIGHT_MODULE=/path/to/playwright node tool/browser_dom_smoke.mjs
```

The latter runs the exact embedded JavaScript in real Chromium against a local
fixture. It validates DOM behavior, not Android/iOS WebView integration or a live
model/provider account.
