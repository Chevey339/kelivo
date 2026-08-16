# Kelivo AI 流式协议重构计划

参考实现：rikkahub（/Users/psyche/tmp/llmclient/rikkahub） `refactor/ai-stream`（已合入 master，合并提交 `4b9ff1a9`，起点提交 `a7ffbcd8`）。

---

## 一、rikkahub 做了什么

按提交顺序，它的重构分成四件事，彼此可独立落地：

**1. 用 provider 无关的流式事件替换「OpenAI choices 形状」的 chunk**（`a7ffbcd8`）

新增 `ai/ui/StreamChunk.kt`：一个 sealed class，事件带 **id** 和 **生命周期边界**：

```
TextStart/TextDelta/TextEnd
ReasoningStart/ReasoningDelta/ReasoningEnd   (带 metadata、reasoningType)
ToolCallStart/ToolCallDelta/ToolCallEnd
ServerToolStart/ServerToolInputDelta/ServerToolInputEnd/ServerToolEnd
ImageStart/ImageDelta/ImageSnapshot/ImageEnd
Annotations / Usage / Finish
```

`Provider.streamText` 返回 `Flow<StreamChunk>`；非流式路径返回 `TextGenerationResult`（一条完整
`UIMessage` + usage + finishReason），由 `handleTextGenerationResult` 合并。

**2. 把「chunk → 消息」的合并逻辑抽成独立有状态对象**（`ai/ui/StreamChunkHandler.kt`）

`StreamChunkHandler` 持有 `id -> parts 下标` 的映射（text/reasoning/image 各一张表，tool 用
`toolCallId` 直接定位）。`handle(messages, chunk)` 返回新的消息列表。要点：

- 文本、思考、图片**交错到达**时不再「更新最后一个 part」，而是按 id 精确定位；
- 容忍 provider 不发 `Start`：首次收到 `Delta` 就地建 part；
- `Finish` 负责收尾（补 `finishedAt`、结束未闭合的 reasoning、清空索引）；
- 每条响应流一个实例，不复用。

**3. 把流式解码从传输层剥离**（`13c3376a`）

新增 `provider/stream/`：

```kotlin
data class SseEvent(id, event, data, retryMillis)          // 与 HTTP 客户端无关
interface StreamChunkDecoder {
    fun accept(event: SseEvent): DecodeResult              // DecodeResult(chunks, completed)
    fun onClosed(): List<StreamChunk>                      // 与显式终止事件互相幂等
}
```

四个解码器（`ClaudeStreamDecoder` 198 行、`GoogleStreamDecoder` 200 行、
`ChatCompletionsStreamDecoder` 258 行、`ResponseApiStreamDecoder` 347 行）**不依赖 OkHttp**，
Provider 只负责建请求 + 把 SSE 帧喂给 decoder + 关流时调 `onClosed()`。

**4. 真实轨迹回放测试**（`f0b27b3c`、`13c3376a` 及后续）

- `trace-cli/`：一个独立 Bun CLI，按 `traces.yml` 打真实 provider，把 **SSE 分帧之后、解码之前**
  的 `id/event/data` 写成 `events.jsonl`（不记录 header/API key）；
- `ai/src/test/resources/stream-traces/generated/{claude,google,openai-chat,openai-responses}/*`：
  每个目录 `events.jsonl` + `expected.json`（语义快照，剔除时间戳/随机 id；图片只记
  mime + 字节数 + SHA-256）；
- `StreamTraceReplayTest`：离线回放 → decoder → handler → 快照比对 + 手写语义断言
  （并发工具调用 id 不重复、`Finish` 恰好一次、思考签名逐字保留……）；
- `UPDATE_STREAM_TRACE_SNAPSHOTS=true` 重新生成快照。

后续提交基本都是在这套骨架上补协议细节（OpenRouter `reasoning_details` 限定回传、
并发工具调用回传顺序、Responses `incomplete/failed`、Gemini 图片 mime 丢失等）——
**说明这套结构确实把「协议细节」收敛到了单文件里**。

---

## 二、Kelivo 现状与差距

| 维度 | rikkahub（重构后） | Kelivo（现在） |
|---|---|---|
| 流事件模型 | 15+ 种带 id 的生命周期事件 | `ChatStreamChunk{content, reasoning, reasoningDetails, isDone, totalTokens, usage, toolCalls, toolResults}` 一个扁平袋子 |
| 事件产生点 | 4 个 decoder，共 ~1000 行 | **93 处 `yield ChatStreamChunk(...)`**，散在 `openai_common.dart`(4667 行)、`google_common.dart`(1837)、`claude_official.dart`(1116)、`google_vertex.dart`(1029) |
| SSE 分帧 | 一处，`SseEvent` | 每个分支各写一遍 `transform(utf8.decoder)` + 手工 buffer/`split('\n')`/`substring(5)`，至少 8 处 |
| 传输耦合 | decoder 无 HTTP 依赖 | 解析逻辑与 `http.Client`/dio/取消令牌/重试写在同一个 `async*` 里 |
| 图片 | `ImageStart/Delta/Snapshot/End` | 拼进 markdown 文本里的 `data:image` base64，下游靠 `hasInlineBase64` + `inlineBase64TailProbe` 探测 |
| 交错顺序 | part 由 id 定位 | 下游用 `contentSplitOffsets` / `reasoningCountAtSplit` / `toolCountAtSplit` 三个平行数组做下标算术还原顺序 |
| 工具轮次 | 在 provider 之上的 orchestrator | **多轮工具循环写在协议层内部**（`openai_common.dart` 里 3~4 处近乎重复的 follow-up round 实现） |
| server tool | 一等公民 | 伪装成 `ToolResultInfo(id: 'builtin_search')` |
| 测试 | 真实轨迹离线回放 + 语义快照 | 每个用例起一个本地 `HttpServer` 手写 SSE 字面量；无真实 vendor 数据 |

Kelivo 已经有 `MessagePart` sealed class（text/reasoning/tool_call/image/file），
**持久化模型是对的，缺的是流式侧的对应物**——目前流式状态是 `fullContentRaw` 一根大字符串
加三个平行计数数组，最后再反解成 parts。这是当前混乱的根源。

---

## 三、目标架构

```
lib/core/services/api/
  stream/
    stream_chunk.dart          # sealed StreamChunk（事件模型）
    sse_event.dart             # SseEvent
    sse_framing.dart           # Stream<List<int>> -> Stream<SseEvent>，唯一一份分帧实现
    stream_chunk_decoder.dart  # abstract StreamChunkDecoder + DecodeResult
    stream_chunk_handler.dart  # StreamChunk -> List<MessagePart> 合并器
    legacy_chunk_adapter.dart  # StreamChunk -> ChatStreamChunk（迁移期桥接，最后删除）
  providers/
    openai/chat_completions_decoder.dart
    openai/responses_decoder.dart
    claude/claude_decoder.dart
    google/google_decoder.dart
  generation/
    tool_loop_runner.dart      # 多轮工具循环（从协议层上提）
```

约束（照抄 rikkahub 的纪律）：

- decoder **不 import** `dio`/`http`/`dart:io`，只吃 `SseEvent` 吐 `StreamChunk`；
- decoder 有状态、每条流一个实例；`onClosed()` 与显式终止事件产生的 `Finish` 互相幂等；
- 请求体构造（现有的 provider 兼容性 heuristics）**不动**——那部分是 Kelivo 的资产，
  这次重构只碰「响应侧」。

---

## 四、分阶段实施

每个阶段独立可合并、可回滚，主线始终可运行。

### P0 · 事件模型与桥接（无行为变化）

1. 新增 `stream_chunk.dart` / `sse_event.dart` / `stream_chunk_decoder.dart`。
   事件集合直接照抄 rikkahub，**加两项 Kelivo 特有的**：
   - `ReasoningDelta.details`（承载现有 `reasoningDetails` 累积快照）；
   - `ImageSnapshot` 必须有（Gemini/OpenAI Images 部分帧场景现在就靠它）。
2. 新增 `legacy_chunk_adapter.dart`：`Stream<StreamChunk> -> Stream<ChatStreamChunk>`。
   映射规则：`TextDelta -> content`、`ReasoningDelta -> reasoning`、`ToolCallEnd -> toolCalls`、
   `ServerToolEnd -> toolResults`、`Usage/Finish -> usage/isDone`；
   `ImageDelta/Snapshot` 暂时仍拼回 `data:image` 文本（保持下游不变）。
3. 单测：适配器往返、`Finish` 恰好一次。

**验收**：新文件全部有测试，`lib` 其他部分零改动。

### P1 · 统一 SSE 分帧

1. 实现 `sse_framing.dart`：`Stream<List<int>>`（或 `Stream<String>`）→ `Stream<SseEvent>`，
   处理 `id:`/`event:`/`data:`（多行 data 拼接）/`retry:`、CRLF、末帧无换行
   （现有 `test/sse_buffer_flush_test.dart` 覆盖的边界必须继续通过）。
2. 把现有 8 处内联 buffer 循环逐个换成它，**先不动 chunk 产生逻辑**——每处只是把
   「拿到 data 字符串」的方式换掉。
3. 现有 HTTP 级测试全绿即为验收。

**收益**：立刻消掉几百行重复；也是 P2 的前置。

### P2 · 抽出四个 decoder（重头戏）

按风险从低到高逐个协议做，一次一个 Commit：

1. **Claude**（`claude_official.dart`）——协议最规整、事件边界最清晰，先做，作为模板；
2. **Google**（`google_common.dart` + `google_vertex.dart` 共用一个 decoder）；
3. **OpenAI Responses**（`openai_responses.dart` + `openai_common.dart` 内的 responses 分支）；
4. **OpenAI Chat Completions**——最脏，放最后，此时前三个已经把模式固化。

每个协议的做法：

- 新建 `xxx_decoder.dart`，把该协议**所有** `yield ChatStreamChunk(...)` 的判定逻辑搬进
  `accept(SseEvent)`，产出 `StreamChunk`；
- provider 侧只剩：建请求 → `sse_framing` → `decoder.accept` → `decoder.onClosed()`；
- 流出口暂时经 `legacy_chunk_adapter` 转回 `ChatStreamChunk`，**下游一行不改**；
- 该协议已有的兼容性测试（deepseek/kimi/zhipu/siliconflow/openrouter/mimo/gemma4/…）
  必须原样通过——它们是这次重构最重要的安全网。

**验收**：`grep -c 'yield ChatStreamChunk' lib/core/services/api/providers` 降到 0。

### P3 · 轨迹回放测试

1. `tool/trace_recorder.dart`（Dart 写，不引入 Bun）：读 `tool/traces.yaml`，
   打真实 provider，把分帧后的 `SseEvent` 写 `test/fixtures/stream-traces/<provider>/<case>/events.jsonl`。
   **只记 `id/event/data`，绝不记 header 和 key**；key 从环境变量读
   （本机 Gemini key 在 `tmp/geminikey`，不入库）。
2. `expected.json` 语义快照：消息 parts + tool calls + usage + metadata；
   剔除时间戳与随机 id；图片只存 mime + 字节数 + sha256。
3. `test/features/api/stream_trace_replay_test.dart`：离线回放 + 快照比对 +
   手写语义断言（并发工具调用 id 唯一、`Finish` 一次、思考签名逐字保留、
   `ImageSnapshot` 替换而非追加）。
4. `UPDATE_STREAM_TRACES=true flutter test ...` 更新快照。
5. 首批轨迹（对齐 Kelivo 实际用户面）：Claude 官方（思考 + 并发工具 + web_search）、
   Gemini（思考签名 + 图片生成）、OpenAI Responses（server tool + incomplete）、
   DeepSeek/OpenRouter Chat Completions（`reasoning_details` + 并发工具）。

**收益**：以后修某个 vendor 的怪癖，先录一条轨迹，改 decoder，快照 diff 即评审材料。

### P4 · 下游改吃 StreamChunk，拆掉下标算术

1. 实现 `stream_chunk_handler.dart`：维护 `id -> MessagePart 下标`，
   直接产出 `List<MessagePart>`（Kelivo 已有的模型），交错顺序天然正确。
2. `stream_controller.dart` / `chat_actions.dart` 改为消费 `Stream<StreamChunk>`：
   - 删除 `contentSplitOffsets` / `reasoningCountAtSplit` / `toolCountAtSplit` 及
     `ContentSplitData` 的读写路径（持久化侧保留反序列化兼容，读旧数据仍能渲染）；
   - 删除 `hasInlineBase64` / `inlineBase64TailProbe` 探测，图片走 `ImagePart`；
   - `bufferedReasoning` 节流保留（是 UI 需求，不是协议问题）。
3. 删除 `legacy_chunk_adapter.dart` 与 `ChatStreamChunk`。
4. 旧会话回放测试：确保历史 `reasoningSegmentsJson` + `contentSplits` 仍能正确渲染。

**这是唯一有真实 UI 回归风险的阶段**，建议单独一个 commit、单独一轮真机验证
（思考 + 工具 + 图片 + 多轮工具交错的会话各跑一遍）。

### P5 · 上提工具循环 & 统一非流式路径

1. `tool_loop_runner.dart`：`(decoder 产出的 ToolCall 事件) -> 执行工具 -> 追加消息 -> 重发请求`，
   替换 `openai_common.dart` 里 3~4 处重复的 follow-up round 实现。
   provider 层从此**只发一轮请求**。
2. 非流式路径改为返回 `TextGenerationResult`（完整 parts + usage + finishReason），
   由与流式相同的 handler 合并——消掉现在 `stream:false` 与 `stream:true` 两套下游逻辑。
   注意 rikkahub 在这里踩过坑（`c555719e` 之后的 `806f7dd6`：非流式路径图片丢 `data:` 前缀），
   **解析源头就产出完整可渲染 URL**，不要在合并处补前缀。

### P6 · 收尾

- 拆掉 `part of 'chat_api_service.dart'` 的巨型 part 结构，改成正常 import；
  删除 `chat_api_service_shims.dart`（131 行纯转发，是 part 结构的产物）。
- `openai_common.dart` 预期从 4667 行降到 ~1500（只剩请求体构造与 vendor heuristics）。
  **这个数字估错了，见第八节：不要为凑行数去动 heuristics。**
- 补一份 `docs/ai-stream.md`：事件语义、decoder 契约、如何录轨迹、如何加新 provider。

---

## 五、风险与对策

| 风险 | 对策 |
|---|---|
| P2 搬运时漏掉某个 vendor 的偏门分支（93 处 yield，很多是 if 深处的补丁） | 搬运前先 `grep -n 'yield ChatStreamChunk' <file>` 生成清单，逐行打勾；每处注释里保留原始 vendor 名 |
| 现有兼容性靠 HTTP 级测试保障，重构中容易「测试还绿但语义变了」 | P3 的语义断言（不只是快照相等）先于 P4 落地 |
| P4 触及 UI 顺序，回归难自动化 | 单独 commit；先补 `stream_chunk_handler` 的交错单测（text→reasoning→tool→text→image），再动 UI |
| 历史数据格式（`reasoningSegmentsJson` 里的 contentSplits） | 只删写入路径，保留读取兼容；加旧数据渲染测试 |
| 轨迹里混入 key/PII | recorder 只写 `id/event/data`；轨迹入库前人工过一遍；`traces.yaml` 只存 env 变量名 |

## 六、不要照抄的部分

- Kotlin `Flow` / OkHttp `EventSource` 的细节——Dart 侧用 `Stream` + 现有 dio 客户端即可，
  `SseEvent` 这一层抽象才是要点；
- rikkahub 的 `UIMessage`/`UIMessagePart` 全套——Kelivo 已有 `MessagePart`，
  handler 直接产出它，不要引第二套消息模型；
- Bun/TypeScript 的 trace-cli——用 Dart 写在 `tool/` 下，复用 Kelivo 自己的请求体构造代码，
  录出来的轨迹才和真实请求一致。

## 七、建议节奏

P0 + P1 可以一天内合并（纯增量，零风险）。P2 四个协议各一个 commit，是主要工作量。
P3 与 P2 交替进行——每做完一个协议就录该协议的轨迹，趁着上下文还热。
P4 独立一周，含真机验证。P5/P6 属于清理，可以延后但别无限期延后
（`legacy_chunk_adapter` 长期存在会变成新的技术债）。

---

## 八、实际执行与原计划的偏差

落地栈（均合入 `refactor/ai-stream` 的预期顺序）：

| 切片 | PR | 提交 | 与计划的差异 |
|---|---|---|---|
| P0–P4c | — | `e824532b`…`5a9bf8a6` | 按计划：事件、分帧、四个 decoder、轨迹 |
| P4b-2 / 2.5 | — | `a9980f1c` / `ab8f1fd0` | 计划外：handler 影子比对，给 P4 垫安全网 |
| P4b-3 | #891 | `728a686a` | 计划写「P4 一次做完 UI」。实际拆成 render/persist parts，单独真机风险 |
| P4b-4 | #893 | `e9ad1f12` | 删除 adapter / `ChatStreamChunk` / shadow，对应计划 P4.3 |
| P5-1 | #894 | `f520847a` | 工具循环上提。OpenAI 仍是 follow-up 入口，Claude/Gemini 是整轮入口，合不了，runner 里写了原因 |
| P5-2 | #895 | `c830b85a` | `TextGenerationResult` + 共用 handler。`generation/` 清掉协议名 |
| P6 | 本文件 | — | 拆 part、删 shims、`partsHandler`、`docs/ai-stream.md` |

**`openai_common` 的 ~1500 行目标是错的，不要再朝这个数字改。**

P6 原文写「从 4667 降到 ~1500（只剩请求体构造与 vendor heuristics）」。响应侧搬走之后，这个文件停在 ~3000 行，不降反升过十几行。剩下的几乎全是请求体构造和 vendor 兼容性 heuristics（Kimi / Zhipu / LongCat / GPT-5 sampling / OpenRouter Claude cache / built-in search / reasoning knobs）。第三节已经写了「请求体构造不动，这次只碰响应侧」——~1500 是误把响应侧当成了这个文件的大头。

这些 heuristics 没有轨迹测试兜底，是全项目最不该在收尾阶段动的代码。后人不要为了凑行数去拆或「清理」它们。

正确的终点指标：

| 指标 | 状态 |
|---|---|
| `ChatStreamChunk` 不存在 | 是 |
| 协议知识只在 4 个 decoder 里 | 是 |
| 流式/非流式共用一条合并路径 | 是 |
| 多轮工具循环只有一份实现 | 是（两个入口，一种循环） |
| `generation/` 协议无关 | 是 |
| 响应侧从 provider 文件里清空 | 是（claude 1116→717、vertex 1029→674、google_common 1837→1452） |

其它偏差：

- P4 比计划多切了几刀（影子、parts 渲染、删适配器），因为 UI 回归风险不能和协议搬运绑在同一个 PR。
- 轨迹回放罩不住非 SSE 一次性 JSON，也罩不住 Chat Completions / Images API 把图放在普通 `delta` 字段里的路径。见 `docs/ai-stream.md`「轨迹回放的盲区」。
- `StreamingState.shadowHandler` 在影子删除后改名为 `partsHandler`。
