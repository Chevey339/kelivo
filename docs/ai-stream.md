# Kelivo AI 流

协议无关的流式事件、decoder 契约、轨迹回放，以及如何加一个新 provider。
请求体构造和 vendor heuristics 不在这里——那是各 provider 请求文件和 `providers/openai/openai_vendor_compat.dart` 的资产。

## 事件语义与生命周期

`StreamChunk` 是 provider 无关的密封事件。文本 / 思考 / 图片按 **id** 定位，工具按 vendor tool-call id 定位。交错到达时不要「更新最后一个 part」。

| 系列 | Start | 增量 | 结束 | 备注 |
|---|---|---|---|---|
| 文本 | `TextStart` | `TextDelta` | `TextEnd` | 无 Start 时，handler 在首个 Delta 建 part |
| 思考 | `ReasoningStart` | `ReasoningDelta` | `ReasoningEnd` | `details` 承载 OpenRouter 式 `reasoning_details` 快照 |
| 本地工具 | `ToolCallStart` | `ToolCallDelta` | `ToolCallEnd` | 结果是 `ToolCallResult`（`server: false`） |
| 托管工具 | `ServerToolStart` | `ServerToolInputDelta` | `ServerToolEnd` | 搜索 / 代码执行；`server: true` 只留给这条通道 |
| 图片 | `ImageStart` | `ImageDelta` / `ImageSnapshot` | `ImageEnd` | Snapshot 替换，不追加 |
| 收尾 | — | `Usage` / `Annotations` | `Finish` | `Finish` 恰好一次，由 provider 发，decoder 不发 |

`StreamChunkHandler` 每条响应流一个实例，按 id 折成 `List<MessagePart>`。非流式走同一条合并：`generateMessage` → `sendMessageStream(stream: false)` → `handler.handle` → `TextGenerationResult`。`handleResult` 原样收下 parts，不改写图片 URI。

可渲染的图片 URL 在**解析源头**补完（`completeRenderableImageUri`）。合并处不补 `data:` 前缀。

## `StreamChunkDecoder` 契约

四个 decoder：`ClaudeStreamDecoder`、`GoogleStreamDecoder`、`ChatCompletionsStreamDecoder`、`ResponsesStreamDecoder`。

- 不 import `dio` / `http` / `dart:io`。只吃 `SseEvent`，只吐 `StreamChunk`。
- 有状态。每条 HTTP 响应一个实例，不跨流复用。
- `accept` 失败时抛错；`completed` 表示协议侧已结束。
- `onClosed()` 与显式终止事件互相幂等：第二次调用返回空列表。只冲刷未闭合的系列（工具 End、图片 End），**不发 `Finish`**。`Finish` 由 provider 在 `onClosed` 之后发。

Provider 的职责：建请求 → `sse_framing` → `decoder.accept` → 关流时 `onClosed()` → `emitFinish`。多轮工具循环在 `generation/tool_loop_runner.dart`，不在 decoder 里。

## `StreamChunkIds` 的跨轮作用域

`StreamChunkIds(sourceId)` 给同一 HTTP 响应里的系列编号。后续工具轮会 new 一个 decoder。若两轮都用字面量 `'text'`，handler 会把后轮文本并进第一段 `TextPart`。

每轮传不同的 `sourceId`（`'round-0'`、`'round-1'`，或 response id）。同一轮内 `text()` / `reasoning()` 粘住同一个 id；`search()` 每次新 id，避免两次检索并成一条。

## 录轨迹并更新快照

`tool/trace_recorder.dart` 打真实 provider，把 **SSE 分帧之后、解码之前** 的 `id` / `event` / `data` / `retryMillis` 写成 `events.jsonl`。不写 header，不写 API key。key 只从 `tool/traces.yaml` 里的环境变量名读取。

```bash
dart run tool/trace_recorder.dart --list
dart run tool/trace_recorder.dart --case thinking-tools-search --dry-run
dart run tool/trace_recorder.dart --case thinking-tools-search --force
UPDATE_STREAM_TRACES=true flutter test test/features/api/stream_trace_replay_test.dart
```

快照在 `test/fixtures/stream-traces/<provider>/<case>/expected.json`：parts + 工具 + usage；去掉时间戳和随机 id；图片只留 mime + 字节数 + SHA-256。改 decoder 之后先看快照 diff，再决定是否更新。

## 加一个新 provider

1. 新建 `providers/<vendor>/<vendor>_decoder.dart`，实现 `StreamChunkDecoder`。协议知识只进这个文件。
2. 在 `providers/` 下写发送函数：组请求体（可复用现有 heuristics）→ 分帧 → `accept` → `onClosed` → 如有本地工具，交给 `runProviderToolRounds` 或 `runClientToolFollowUps`。
3. 在 `ChatApiService.sendMessageStream` 按 `ProviderKind` 分发。
4. 为该协议录一条轨迹，加上回放测试。非 SSE 的一次性 JSON 见下一节，不要指望现有回放罩住它。

两个 runner 入口不要硬并：Claude / Gemini 的首轮 HTTP 在 `sendRound` 里；OpenAI 的首轮由调用方消费，只有后续轮进 `runClientToolFollowUps`。

## 轨迹回放的盲区

回放只覆盖「已经变成 `SseEvent` 的帧」。下面两类响应**不会**出现在 `events.jsonl` 里，改它们的解析时不要只靠快照变绿。

**非 SSE 的一次性 JSON。** `stream: false` 走 `generateContent` / 整包 Chat Completions JSON / Responses 非流对象，不经 `sse_framing`。`generateMessage` 仍用同一个 handler 合并，但 recorder 录不到这些包。Images API 也是一次 JSON，同样不在轨迹里。

**把图片塞进 `delta` 普通字段的协议。** Chat Completions 的图在 `delta.images` / `delta.image_url` / `message.content[]` 的 `image_url` 里，不是独立的 SSE 事件类型。Images API 的图在 `data[].b64_json`。轨迹若只断言文本和工具，这两种图会漏掉——P3 首批轨迹就是这样漏的。给这类协议补测试时，直接喂 decoder 一个带 `image_url` 的 JSON 帧，或给 Images API 一条 HTTP 级用例；不要假设更新快照能看见它们。
