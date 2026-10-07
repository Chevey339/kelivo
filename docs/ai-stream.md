# Kelivo AI 流

协议无关的流式事件、decoder 契约、轨迹回放，以及如何加一个新 provider。
请求体构造和 vendor heuristics 不在这里——那是各 provider 请求文件和 `providers/openai/openai_request_shaping.dart` 的资产。

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

`runClientToolFollowUps` 在执行每批客户端工具之前发出 `AssistantRoundEnd`。它记录刚结束的模型响应边界及该轮 `reasoning_details`，handler 将其保存为不可见的 `AssistantRoundEndPart`。边界不表示工具已经执行；执行状态仍由对应 `ToolCallPart.content` 是否存在决定。

Chat Completions 历史从有序 parts 重建，每个边界之前的正文、思考和工具调用属于同一响应，调用后紧跟该批结果。连续无正文的工具响应也各自保留；未完成批次不伪造结果，不影响此前已完成批次。普通最终回答只携带最后一轮思考。Claude、Gemini 由各自适配器处理原生回放。

Responses 在每轮返回后发出 `responses_turn` provider artifact，保存原生 output items、响应边界和供应商 call_id 与工具卡片 ID 的对应关系。流式以 `response.output_item.done` 的完整数据为准，保存明文 reasoning 或 `encrypted_content`；终止事件中的精简 output 不覆盖已完成 item。下一次请求按原顺序回放 items，在每轮调用后插入对应的工具结果，正文只发送一次。artifact 限定提供商、Base URL 和上游模型，随消息重载和会话分叉保留；未完成的工具批次及关联原生 reasoning 不回放。改写正文的回复使用当前文本，发送阶段的正则处理只改正文，不重写 reasoning。OpenAI 官方端点请求 `reasoning.encrypted_content`；不向其他兼容端点新增该参数。

支持推理回放的模型和目录回放字段默认使用 `all`，包括没有实际调用工具的历史回答；`toolTurns` 保留为用户可选项，显式配置仍优先。不支持该回放字段的模型继续使用 `none`。这控制客户端回传范围，不会自动修改供应商的 `thinking.keep` 或 `clear_thinking` 等服务端参数。

Claude 经 OpenAI 兼容接口回放时仍使用携带签名的 `reasoning_details`，不会因选择 `all` 而把旧的无签名思考文本当成原生 thinking 回传。

Claude/Messages 每个响应都保存 `claude_turn`，普通轮次也保留完整 thinking、signature 和 redacted_thinking。没有工具卡片时，artifact 随原提供商和模型的普通助手消息进入历史；编辑正文后不恢复旧块。发送时按回放策略过滤历史 thinking，正文和工具结果保留；当前工具循环仍完整回传所需的原生块。存储不受回放选项影响，切换选项不会丢掉已经保存的块。

修改历史、系统提示或工具定义后，若 Claude 返回明确的 conversation-prefix 签名错误，客户端按实际请求中的错误位置，去掉该块及其后的 thinking/redacted_thinking，仅重试一次。`claude_thinking_recovery` 保存失效块的指纹，并累计写入后续回复，重载和分叉后也不重新带回；原始 artifact 不修改，新生成的思考继续正常回放。普通请求不新增 beta 参数，其他签名错误照常报告。带工具的历史回复编辑后以当前正文替换原正文，工具调用和结果保持原位。

上下文消息数限制为软上限，裁剪点回退到保留轮次的用户消息，避免把工具链从中间拆开。已有记录只能按其实际保存的 parts 和 artifact 回放，不能补回过去没有记录的响应边界或 thinking 签名。

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
