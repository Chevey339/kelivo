# Conversation browser tabs

Browser tabs belong to a conversation, independently of whether their native
WebView currently exists. The UI and tools expose the same conversation scope.

## User behavior

- Opening the browser from a new conversation shows the start page without
  creating an empty tab. Opening a URL or pressing New tab creates one.
- Each conversation remembers its selected tab, including across app restarts.
  Closing its last tab returns to the start page, not another conversation.
- The overview defaults to **This chat**. **All tabs** groups saved tabs by
  conversation title. Explicit links to another conversation's page open the
  overview in All tabs so the selected page remains visible.
- After viewing another conversation's page, the browser menu offers **Move to
  this chat** and **Reopen in this chat**. Moving retains the live page and its
  identity; reopening loads the URL in an independent tab. Popup families move
  together. A running native action must settle before its page can move.
- The AI draft action names the owning conversation when it differs from the
  current chat. It still checks both existing permissions and only prepares a
  draft; it does not send a message or run an agent automatically.

## Resource and access rules

- Saved tabs no longer share an eight-tab creation/restoration limit. Existing
  records are not truncated. Entering another conversation allocates no WebView.
- Agent actions may grow a conversation to three tabs. At three or more, the
  agent must reuse a tab with `open` + `tab_id`, or close one before `new_tab`.
  This quota does not restrict the user's explicit New tab action.
- The existing global budget of three native WebViews remains in effect. Hidden
  idle runtimes can be released; visible pages, the selected page, and a running
  agent's page remain protected. If all candidates are protected, allocation
  fails with a resource-busy message rather than preempting a running action.
- Background tool selection and background popups do not change the foreground
  conversation's selected page. Each agent's implicit tab follows its own most
  recently used tab, not another conversation's UI selection.
- `list_tabs` explicitly reports `scope: conversation`. It lists only owned
  tabs and marks the conversation's own selected tab active. The tool cannot
  transfer ownership; handoff is a user action.
- The preview cache retains at most eight bounded thumbnails. Older tabs use
  the existing favicon placeholder; reopening refreshes the thumbnail normally.
- Releasing a runtime preserves the tab record but reloads the page on reuse.
  DOM state, unsaved form edits, and native navigation history are not full
  session snapshots. This is not a claim of lossless page suspension.

## Reference and validation

The separation of conversation pools, agent quota, and process-wide native
budget follows the inspected [OpenMinis implementation at b4c0661](https://github.com/OpenMinis/OpenMinis/blob/b4c0661d5631ebab4d1a2e6f3fd4c805d4030a6c/src/ios/Agent/BrowserUse/BrowserTabPool.swift).
Kelivo keeps its existing three-instance budget and does not adopt Minis'
busy-page preemption. No reference implementation code is copied.

Focused coverage is in `browser_service_test.dart`, `browser_tools_service_test.dart`,
`browser_preview_test.dart`, `browser_page_test.dart`, and `browser_tabs_test.dart`.
These cover scoped selection and persistence, quotas, handoff/ownership, popup
inheritance, protected runtime eviction, bounded previews, and mobile/desktop
scope controls including large text. They do not establish physical-device FPS.
