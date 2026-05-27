## [2.0.0] - 2026-04-30 - MCP spec compliance + 2025-11-25 alignment

Big-Bang spec normalization. Supports protocol revisions 2024-11-05, 2025-03-26, 2025-06-18, and 2025-11-25 with per-version capability gating. Pairs with mcp_server 2.0.

### Breaking
- **Sampling direction fixed.** `client.createMessage(...)` (which sent a request to the server) is removed. Sampling is server-initiated per spec — register a handler with `client.onSamplingRequest((req) async { ... })` so the host LLM fulfils it.
- **Roots direction fixed.** `client.listRoots()` (which sent a request to the server) is removed. The server requests roots from the client; configure them locally with `client.addRoot(...)` / `client.removeRoot(...)` and read via `client.roots`. Override the default response handler with `client.onListRoots(...)`. `roots/add` and `roots/remove` JSON-RPC methods (non-spec) are deleted.
- **Cancellation is now a notification.** `client.cancelOperation(opId)` (which sent a `cancel` request) is removed; use `client.notifyCancelled(requestId, reason: ...)` which emits the spec `notifications/cancelled` notification.
- **Logging method name corrected.** `setLoggingLevel` now sends `logging/setLevel` (camelCase) per spec — was `logging/set_level`.
- **`client.healthCheck()` removed** — `health/check` is non-spec; expose health via your transport (e.g. an HTTP `/health` endpoint).
- **`onSamplingResponse` listener removed** — the non-spec `sampling/response` notification path is gone, replaced by the standard request/response shape.

### Added
- `client.onSamplingRequest(handler)` — register a host LLM completion handler.
- `client.onElicitationRequest(handler)` — register a user-input handler (spec 2025-06-18 `elicitation/create`).
- `client.onListRoots(handler)` — override the default `roots/list` response.
- `client.notifyCancelled(requestId, {reason})` and `client.notifyProgress(token, progress, {total, message})` — spec notifications.
- `ClientCapabilities.elicitation` flag.
- `McpProtocol.v2025_06_18` and `McpProtocol.v2025_11_25` constants. `defaultVersion` advances to `v2025_11_25`.
- Per-version capability gates: `McpProtocol.supportsBatching` / `supportsElicitation` / `requiresProtocolHeader`.
- Schema: `Tool.title` / `Tool.outputSchema` / `Tool.icons` / `Tool.meta`. `CallToolResult.structuredContent`. `AudioContent`. `ResourceLinkContent`.
- Incoming-request infrastructure routes server-initiated requests to registered handlers and returns a JSON-RPC response with the matching id.

---

## [1.1.1] - 2026-04-28

### Changed
- README cleanup — removed "MCP Family" section, installation block, dev.to articles, and donation links.

---

## 1.1.0

* New Features
  * Deferred Tool Loading support (Progressive Tool Disclosure)
    * `ToolMetadata` - Lightweight tool representation (name + description only)
    * `ToolRegistry` - Cache layer for tool definitions with metadata extraction
    * `ClientToolMetadataExtension` - Extension for easy metadata access
    * Reduces token usage by 60-80% when sending tool definitions to LLMs
    * Zero breaking changes - fully backward compatible, opt-in only

## 1.0.2

* Bug Fixes
  * Added `terminateOnClose` parameter to StreamableHTTP transport configuration
    * Allows controlling whether DELETE request is sent on disconnect
    * Default value is `true` to maintain backward compatibility
    * Set to `false` to allow reconnection after disconnect without server session termination
  * Enhanced session validation and localStorage management
    * Server-side session validation through `hasSession()` check
    * Automatic localStorage cleanup when session ID changes (server restart detection)
    * Proper handling of invalid/expired session IDs
    * Improved reconnection logic for StreamableHTTP transport

## 1.0.1

* Bug Fixes
  * Fixed SSE endpoint parsing issue where endpoint data was incorrectly processed as null
  * Added support for SSE events without explicit event type field
  * Improved compatibility with various SSE server implementations
  * Fixed web platform SSE implementation to match native platform behavior

## 1.0.0

* Breaking Changes and Major Update to 2025-03-26 Protocol
  * Updated to MCP protocol version 2025-03-26 (from 2024-11-05)
  * Complete refactoring for modern Dart 3.8+ patterns
  * Added @immutable annotations throughout models
  * Introduced sealed classes and pattern matching
  * Enhanced type safety with Result<T, E> pattern
  * Backward API compatibility maintained

* New Features
  * Protocol version negotiation support
  * Enhanced Content model with annotations
  * Tool cancellation and progress tracking
  * Improved resource templates
  * Better error handling with typed results
  * Protocol constants centralized in McpProtocol class

* Technical Improvements
  * All models now use const constructors
  * Factory constructors for JSON deserialization
  * Centralized protocol configuration
  * Better numeric type handling in JSON
  * Cleaner API surface with protocol exports

## 0.1.8

* Added
  * Client event monitoring system using Dart's Stream API
    * `onConnect` stream for server connection events
    * `onDisconnect` stream for server disconnection events
    * `onError` stream for error events
  * New models to support event monitoring
    * `ServerInfo` class for connection details
    * `DisconnectReason` enum for disconnect causes
  * Client lifecycle management improvements
    * Added `dispose()` method for proper resource cleanup
    * Enhanced error propagation through dedicated stream
    * Better connection state tracking and reporting

## 0.1.7
## 0.1.6
## 0.1.5

* Bug Fixed

## 0.1.4

* Bug Fixes

## 0.1.3

* Fixed
  * SSE Transport Connection Issues: Fixed critical issue with Server-Sent Events (SSE) connection where the client could not properly process JSON-RPC responses from the server.
    * Improved event stream processing to correctly parse JSON-RPC messages
    * Fixed handling of the endpoint event to establish the message channel
    * Enhanced buffer management for fragmented SSE event data
  * JSON-RPC Message Flow: Corrected the bidirectional communication flow between client and server:
    * Client requests via HTTP POST to message endpoint now properly receive responses
    * Fixed timeout issues by correctly handling asynchronous SSE responses
* Improved
  * Error Handling: Enhanced error reporting and recovery for connection issues
  * Logging: Added more detailed diagnostic logging for easier troubleshooting
  * Stability: More robust message endpoint URL construction and session handling
* Technical Notes
  * Updated SseClientTransport implementation to maintain persistent connections
  * Fixed JSON response type handling for resource templates
  * Improved session management and reconnection logic

## 0.1.2

* New Features
  * Protocol Update: Full support for all features of the 2024-11-05 protocol specification
  * Progress Tracking: Added onProgress method to receive notifications about progress of long-running operations
  * Operation Cancellation: Added cancelOperation method to cancel running operations
  * Server Health Check: Added healthCheck method to check server's health status
  * Resource Template Enhancement: Added getResourceWithTemplate method to access resources using URI templates
  * Tool Execution with Progress Tracking: Added callToolWithTracking method that returns operation IDs
  * Enhanced Resource Update Notifications: Added onResourceContentUpdated method that includes content information
  * Sampling Response Handling: Added onSamplingResponse method to process sampling results
* New Model Classes
  * ServerHealth: Class to hold server health status information
  * PendingOperation: Class for managing ongoing operations
  * ProgressUpdate: Class for operation progress updates
  * CachedResource: Class for resource caching
  * ToolCallTracking: Class to return tool call results and operation IDs together
* Technical Improvements
  * Enhanced protocol version validation
  * Improved error handling and exception messages
  * Added options to colorize logs and include timestamps for easier debugging

## 0.1.1

* Bug fixes

## 0.1.0

* Initial release
* Created Model Context Protocol (MCP) client implementation for Dart
* Features:
  * Connect to MCP servers with standardized protocol support
  * Access data through Resources
  * Execute functionality through Tools
  * Utilize interaction patterns through Prompts
  * Support for Roots management
  * Support for Sampling (LLM text generation)
    * Multiple transport layers:
    * Standard I/O for local process communication
  * Server-Sent Events (SSE) for HTTP-based communication
  * Platform support: Android, iOS, web, Linux, Windows, macOS