# 2. 增量备份采用会话级过滤（Conversation-Level）而非消息级

- **日期：** 2026-06-22
- **状态：** 已采纳

## 上下文

增量备份的核心需求是按时间范围裁剪导出体积。导出端需要决定裁剪单位。

现有数据模型中：

- `Conversation` 有 `createdAt`（不可变，首次创建时间戳）
- `ChatMessage` 有 `timestamp`（每条消息独立的时间戳）

一个长命会话的 `createdAt` 很可能早于用户选择的 `since` 日期，但其部分消息的 `timestamp` 可能晚于 `since`。

## 决策

采用 **Conversation-level filtering**：导出时只取 `createdAt >= since` 的会话及其所有消息，早于 `since` 创建的会话整条跳过。

## 权衡

### 方案 A：Conversation-Level ✅（已选）

过滤条件：`conversations.where((c) => c.createdAt >= since)`

- **优点：** 实现简单（O(n) 遍历 conversations，不需要遍历消息）；语义明确，用户容易理解「从这个日期开始的对话」
- **优点：** 数据一致性有保障——不会出现「有消息无 Tool Event」的孤立场景
- **缺点：** 长命会话（早于 since 创建但仍在活跃）中的新消息被整条跳过

### 方案 B：Message-Level（待定，已规划为后续 PR）

不跳过会话，导出时每个消息独立过滤：`messages.where((m) => m.timestamp >= since)`

- **优点：** 捕获所有截止日期后的内容，包括长命会话中的新消息
- **缺点：** 产生不完整会话（缺失 cutoff 之前的消息），需要在导出端和恢复端额外处理一致性
- **缺点：** toolEvents/geminiThoughtSigs 可能引用被过滤掉的消息，需要追加清理逻辑

## 影响

- `_exportChatsToFile()` 加一行 `.where()` 过滤即可，零侵入现有主流程
- 设置、导入端、合并逻辑零改动（导出的 chats.json 格式与全量完全一致）
- 恢复端通过 `cuplivo_incr_` 前缀防呆检测，强制走 merge 模式即可
- 已知缺口文档化在 CONTEXT.md 中，方便后续改 Message-Level 时定位

## 附录（2026-07-03）：升级为消息级过滤

会话级过滤的缺点在实际使用中被验证：长命会话中的新消息被整条跳过。
本 ADR 的方案 B（消息级过滤）已于 2026-07-03 实施。

### 新增优化

利用 `Conversation.updatedAt`（每次收到新消息时更新）做快速预检：
- `updatedAt < since` → 无任何活动，直接跳过，无需查询消息
- 将扫描范围从「所有旧会话」缩小到「有活动的旧会话」

### 实现

```dart
// 过滤会话
conversations = conversations.where((c) {
  if (c.createdAt >= since) return true;
  if (c.updatedAt.isBefore(since)) return false;
  final msgs = chatService.getMessages(c.id);
  return msgs.any((m) => m.timestamp >= since);
}).toList();

// 过滤消息（仅对 createdAt < since 的会话）
if (c.createdAt.isBefore(since)) {
  msgs = msgs.where((m) => m.timestamp >= since).toList();
}
```

### 恢复端

零改动。merge 模式按 message ID 去重，已有会话保留旧消息，
新消息通过 `addMessageDirectly` 追加，最终会话完整。
