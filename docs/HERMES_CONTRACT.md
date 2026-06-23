# Hermes 协议速查表 — Kelivo Dart 客户端

> 来源: `hermes-agent` (commit `b0e78eee` 对应)
> 用途: Dart 端 HermesGateway / HermesRestClient 实现参考
> 自动生成 from: `tui_gateway/server.py`, `gateway/stream_events.py`, `hermes_cli/web_server.py`

---

## 1. WebSocket JSON-RPC 协议

### 传输
- **URL**: `ws(s)://<host>:<port>/api/ws`
- **格式**: 每行一个 JSON-RPC 2.0 消息，newline-delimited JSON (NDJSON)
- **鉴权**:
  - loopback: `?token=<X-Hermes-Session-Token>`
  - gated: `?ticket=<一次性ticket>` (ticket 由 `POST /api/auth/ws-ticket` 获得)
- **心跳**: 客户端每 25s 发 `{"jsonrpc":"2.0","method":"ping"}`; 30s 无响应视为断线

### 握手
- 服务端连接成功后立即发 `gateway.ready` 事件:
```json
{"jsonrpc":"2.0","method":"event","params":{"type":"gateway.ready","session_id":"","payload":{...}}}
```

### 请求格式
```json
{"jsonrpc":"2.0","id":"1","method":"session.list","params":{}}
```

### 响应格式
```json
{"jsonrpc":"2.0","id":"1","result":{...}}
{"jsonrpc":"2.0","id":"1","error":{"code":-32600,"message":"..."}}
```

### 事件格式
```json
{"jsonrpc":"2.0","method":"event","params":{"type":"message.delta","session_id":"s1","payload":{"text":"Hello"}}}
```

---

## 2. 流式事件 (gateway → client)

> 对应 `gateway/stream_events.py` + `tui_gateway/server.py` 的 `_emit()` 调用

### 2.1 消息类事件

| 事件名 | payload 字段 | 说明 |
|---|---|---|
| `message.start` | — | assistant 消息开始 |
| `message.delta` | `{"text": "..."}` | assistant 文本片段(delta) |
| `message.complete` | `{"text": "..."}` | assistant 消息完成 |
| `reasoning.delta` | `{"text": "..."}` | reasoning 内容片段 |
| `reasoning.available` | — | reasoning 可用 |
| `thinking.delta` | `{"text": "..."}` | thinking 内容片段 |
| `commentary` | `{"text": "..."}` | 中间评论文本 |

### 2.2 Tool 类事件

| 事件名 | payload 字段 | 说明 |
|---|---|---|
| `tool.start` | `{"name": "...", "preview": "...", "args": {...}, "index": 0}` | tool 调用开始 |
| `tool.generating` | `{"name": "..."}` | tool 正在生成 |
| `tool.complete` | `{"name": "...", "duration": 0.5, "ok": true, "open_tool": {...}, "index": 0}` | tool 调用完成 |
| `tool.progress` | `{"name": "...", "text": "..."}` | tool 进行中(用于 preview.restart) |

### 2.3 Gateway 控制类事件

| 事件名 | payload 字段 | 说明 |
|---|---|---|
| `gateway.ready` | `{"skin": {...}}` | 连接就绪 |
| `gateway.notice` | `{"kind": "...", "text": "...", "extra": {...}}` | gateway 通知 |
| `status.update` | `{"kind": "...", "text": "..."}` | 状态更新 |
| `skin.changed` | `{"skin": {...}}` | 皮肤变更 |
| `approval.request` | `{...}` | 审批请求 |
| `session.info` | `{...}` | 会话信息 |
| `error` | `{"message": "..."}` | 错误 |

### 2.4 Preview/Restart 类事件

| 事件名 | payload 字段 | 说明 |
|---|---|---|
| `preview.restart.progress` | `{"task_id": "...", "level": 0, "text": "..."}` | preview 重启进度 |
| `preview.restart.complete` | `{"task_id": "...", "text": "..."}` | preview 重启完成 |

---

## 3. RPC 方法 (client → gateway)

> 对应 `tui_gateway/server.py` 的 `@method("...")` 装饰器

### 3.1 Session 管理

| RPC 方法 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `session.create` | `{prompt?, model?, profile?}` | `SessionInfo` | 创建新会话 |
| `session.list` | `{limit?, cursor?}` | `{sessions: [...]}` | 列出所有会话 |
| `session.most_recent` | — | `SessionInfo` | 最近会话 |
| `session.resume` | `{session_id}` | `SessionInfo` | 恢复会话 |
| `session.active_list` | — | `{sessions: [...]}` | 活跃会话列表 |
| `session.activate` | `{session_id}` | `{ok: true}` | 激活会话 |
| `session.delete` | `{session_id}` | `{ok: true}` | 删除会话 |
| `session.title` | `{session_id, title}` | `{ok: true}` | 设置会话标题 |
| `session.history` | `{session_id, limit?}` | `{messages: [...]}` | 获取历史消息 |
| `session.undo` | `{session_id}` | `{ok: true}` | 撤销上一步 |
| `session.compress` | `{session_id}` | `{ok: true}` | 压缩会话 |
| `session.save` | `{session_id}` | `{ok: true}` | 保存会话 |
| `session.close` | `{session_id}` | `{ok: true}` | 关闭会话 |
| `session.branch` | `{session_id, message?}` | `SessionInfo` | 从当前分支 |
| `session.interrupt` | `{session_id}` | `{ok: true}` | 中断生成 |
| `session.cwd.set` | `{cwd: string}` | `{ok: true}` | 设置工作目录 |
| `session.status` | `{session_id}` | `SessionStatus` | 会话状态 |
| `session.usage` | `{session_id?}` | `{usage: {...}}` | token 使用统计 |

### 3.2 Prompt / 聊天

| RPC 方法 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `prompt.submit` | `{session_id?, prompt, model?, attachments?, stream?: true}` | `{session_id}` | 提交 prompt |
| `prompt.background` | `{session_id?, prompt, model?}` | `{session_id}` | 后台提交 |
| `input.detect_drop` | `{file_paths: [...]}` | `{attachments: [...]}` | 检测拖放文件 |

### 3.3 附件

| RPC 方法 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `file.attach` | `{session_id, path, preview?}` | `AttachmentInfo` | 附件文件 |
| `image.attach` | `{session_id, path, caption?}` | `AttachmentInfo` | 附件图片 |
| `image.attach_bytes` | `{session_id, data_url, caption?}` | `AttachmentInfo` | 附件图片(字节) |
| `pdf.attach` | `{session_id, path, caption?}` | `AttachmentInfo` | 附件 PDF |
| `image.detach` | `{session_id, attachment_id}` | `{ok: true}` | 移除图片 |

### 3.4 Approval / Clarify / Sudo / Secret

| RPC 方法 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `approval.respond` | `{approval_id, response}` | `{ok: true}` | 审批响应 |
| `clarify.respond` | `{clarify_id, response}` | `{ok: true}` | 澄清响应 |
| `sudo.respond` | `{sudo_id, response}` | `{ok: true}` | sudo 响应 |
| `secret.respond` | `{secret_id, response}` | `{ok: true}` | secret 响应 |
| `terminal.read.respond` | `{read_id, response}` | `{ok: true}` | 终端读取响应 |

### 3.5 Config

| RPC 方法 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `config.get` | `{key}` | `{value: ...}` | 获取配置项 |
| `config.set` | `{key, value}` | `{ok: true}` | 设置配置项 |
| `config.show` | — | `{config: {...}}` | 显示全部配置 |

### 3.6 Model

| RPC 方法 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `model.options` | `{profile?}` | `{models: [...]}` | 可用模型列表 |
| `model.save_key` | `{model, api_key}` | `{ok: true}` | 保存 API key |
| `model.disconnect` | `{model}` | `{ok: true}` | 断开模型 |

### 3.7 Skills

| RPC 方法 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `skills.list` | — | `{skills: [...]}` | 列出技能 |
| `skills.manage` | `{skill, action}` | `{ok: true}` | 管理技能 |
| `skills.reload` | `{skill?}` | `{ok: true}` | 重载技能 |

### 3.8 MCP

| RPC 方法 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `tools.list` | `{mcp_server?}` | `{tools: [...]}` | 列出工具 |
| `tools.show` | `{tool}` | `ToolDef` | 工具详情 |
| `tools.configure` | `{mcp_server, config}` | `{ok: true}` | 配置 MCP |
| `toolsets.list` | — | `{toolsets: [...]}` | 列出工具集 |
| `reload.mcp` | `{server?}` | `{ok: true}` | 重载 MCP |

### 3.9 Cron

| RPC 方法 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `cron.manage` | `{job, action}` | `{ok: true}` | 管理定时任务 |

### 3.10 Process

| RPC 方法 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `process.list` | — | `{processes: [...]}` | 列出进程 |
| `process.stop` | `{process_id}` | `{ok: true}` | 停止进程 |
| `process.kill` | `{process_id}` | `{ok: true}` | 杀死进程 |

### 3.11 Handoff / Delegation

| RPC 方法 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `handoff.request` | `{mode, ...}` | `HandoffState` | 请求交接 |
| `handoff.state` | `{handoff_id?}` | `HandoffState` | 交接状态 |
| `handoff.fail` | `{handoff_id, reason}` | `{ok: true}` | 交接失败 |
| `delegation.status` | `{session_id?}` | `DelegationStatus` | 委托状态 |
| `delegation.pause` | `{session_id}` | `{ok: true}` | 暂停委托 |
| `subagent.interrupt` | `{subagent_id}` | `{ok: true}` | 中断子代理 |

### 3.12 Terminal

| RPC 方法 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `terminal.resize` | `{cols, rows}` | `{ok: true}` | resize |
| `preview.restart` | `{session_id}` | `{task_id}` | 重启 preview |

### 3.13 Clipboard / Misc

| RPC 方法 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `clipboard.paste` | `{text}` | `{ok: true}` | 粘贴文本 |
| `voice.toggle` | `{session_id?}` | `{active: bool}` | 语音开关 |
| `voice.record` | `{session_id}` | `{ok: true}` | 开始录音 |
| `voice.tts` | `{text, voice?}` | `{ok: true}` | TTS |

### 3.14 Browser / Plugins / Agents

| RPC 方法 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `browser.manage` | `{action, ...}` | `{ok: true}` | 浏览器管理 |
| `plugins.list` | — | `{plugins: [...]}` | 列出插件 |
| `plugins.manage` | `{plugin, action}` | `{ok: true}` | 管理插件 |
| `agents.list` | — | `{agents: [...]}` | 列出代理 |
| `slash.exec` | `{session_id, command, args?}` | `{ok: true}` | 执行 slash 命令 |
| `complete.path` | `{path}` | `{completions: [...]}` | 路径补全 |
| `complete.slash` | `{session_id, prefix}` | `{completions: [...]}` | slash 补全 |

### 3.15 Rollback

| RPC 方法 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `rollback.list` | `{session_id}` | `{rollbacks: [...]}` | 列出回滚点 |
| `rollback.restore` | `{rollback_id}` | `{ok: true}` | 恢复 |
| `rollback.diff` | `{rollback_id}` | `{diff: ...}` | 回滚差异 |

### 3.16 Insights / Stats / Billing

| RPC 方法 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `insights.get` | `{session_id?}` | `{insights: {...}}` | 洞察数据 |
| `billing.state` | — | `{credits, plan, ...}` | 计费状态 |
| `billing.charge` | `{amount}` | `{ok: true}` | 充值 |
| `billing.charge_status` | `{charge_id}` | `ChargeStatus` | 充值状态 |
| `billing.auto_reload` | `{enabled}` | `{ok: true}` | 自动充值 |
| `billing.step_up` | `{plan}` | `{ok: true}` | 升级套餐 |
| `credits.view` | — | `{credits: ...}` | 查看积分 |

### 3.17 Commands / CLI

| RPC 方法 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `commands.catalog` | — | `{commands: [...]}` | 命令目录 |
| `command.resolve` | `{name}` | `CommandDef` | 解析命令 |
| `command.dispatch` | `{name, args?}` | `{ok: true}` | 分发命令 |
| `cli.exec` | `{command, cwd?}` | `{output: ...}` | 执行 CLI 命令 |

### 3.18 Setup / Status

| RPC 方法 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `setup.status` | — | `SetupStatus` | 安装状态 |
| `setup.runtime_check` | `{check}` | `{ok: true, result: ...}` | 运行时检查 |
| `reload.env` | — | `{ok: true}` | 重载环境变量 |

### 3.19 Misc

| RPC 方法 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `spawn_tree.save` | `{name, tree}` | `{ok: true}` | 保存 spawn tree |
| `spawn_tree.list` | — | `{trees: [...]}` | 列出 spawn trees |
| `spawn_tree.load` | `{name}` | `SpawnTree` | 加载 spawn tree |
| `session.steer` | `{session_id, instruction}` | `{ok: true}` | 引导会话 |
| `paste.collapse` | `{session_id}` | `{ok: true}` | 折叠粘贴 |
| `file.attach` | `{session_id, path}` | `AttachmentInfo` | 附件文件 |

---

## 4. REST API

> 对应 `hermes_cli/web_server.py`

### 4.1 核心

| Method | 路径 | 说明 |
|---|---|---|
| GET | `/api/status` | 系统状态 |
| GET | `/api/system/stats` | 系统统计 |
| GET | `/api/hermes/update/check` | 检查更新 |

### 4.2 会话

| Method | 路径 | 说明 |
|---|---|---|
| GET | `/api/sessions` | 列出所有会话 |
| GET | `/api/sessions/{session_id}` | 获取会话详情 |
| GET | `/api/sessions/{session_id}/messages` | 获取会话消息 |
| GET | `/api/sessions/{session_id}/latest-descendant` | 最新分支 |
| GET | `/api/sessions/{session_id}/export` | 导出会话 |
| GET | `/api/sessions/search` | 搜索会话 |
| DELETE | `/api/sessions/{session_id}` | 删除会话 |
| PATCH | `/api/sessions/{session_id}` | 更新会话 |
| DELETE | `/api/sessions/bulk-delete` | 批量删除 |
| DELETE | `/api/sessions/empty` | 删除空会话 |
| GET | `/api/sessions/empty/count` | 空会话数量 |
| GET | `/api/sessions/stats` | 会话统计 |
| GET | `/api/profiles/sessions` | profile 会话列表 |

### 4.3 配置

| Method | 路径 | 说明 |
|---|---|---|
| GET | `/api/config` | 获取配置 |
| PUT | `/api/config` | 更新配置 |
| GET | `/api/config/defaults` | 默认配置 |
| GET | `/api/config/schema` | 配置 schema |
| GET | `/api/env` | 获取环境变量 |
| PUT | `/api/env` | 更新环境变量 |
| DELETE | `/api/env` | 删除环境变量 |
| POST | `/api/env/reveal` | 揭示环境变量 |
| POST | `/api/providers/validate` | 验证 provider |

### 4.4 模型

| Method | 路径 | 说明 |
|---|---|---|
| GET | `/api/model/info` | 模型信息 |
| GET | `/api/model/options` | 可用模型 |
| GET | `/api/model/recommended-default` | 推荐默认 |
| GET | `/api/model/auxiliary` | 辅助模型 |
| POST | `/api/model/set` | 设置模型 |

### 4.5 MCP / Tools

| Method | 路径 | 说明 |
|---|---|---|
| GET | `/api/mcp/servers` | MCP 服务器列表 |
| POST | `/api/mcp/servers` | 添加 MCP 服务器 |
| PUT | `/api/mcp/servers/{server_id}` | 更新 MCP 服务器 |
| DELETE | `/api/mcp/servers/{server_id}` | 删除 MCP 服务器 |

### 4.6 Cron

| Method | 路径 | 说明 |
|---|---|---|
| GET | `/api/cron/jobs` | 定时任务列表 |
| GET | `/api/cron/jobs/{job_id}` | 任务详情 |
| GET | `/api/cron/jobs/{job_id}/runs` | 任务运行记录 |
| POST | `/api/cron/jobs` | 创建任务 |
| PUT | `/api/cron/jobs/{job_id}` | 更新任务 |
| DELETE | `/api/cron/jobs/{job_id}` | 删除任务 |
| POST | `/api/cron/jobs/{job_id}/pause` | 暂停任务 |
| POST | `/api/cron/jobs/{job_id}/resume` | 恢复任务 |
| POST | `/api/cron/jobs/{job_id}/trigger` | 手动触发 |
| GET | `/api/cron/blueprints` | 任务蓝图 |
| POST | `/api/cron/blueprints/instantiate` | 实例化蓝图 |
| GET | `/api/cron/delivery-targets` | 投递目标 |

### 4.7 Memory

| Method | 路径 | 说明 |
|---|---|---|
| GET | `/api/memory/providers/{name}/config` | Memory provider 配置 |
| PUT | `/api/memory/providers/{name}/config` | 更新 memory 配置 |

### 4.8 文件

| Method | 路径 | 说明 |
|---|---|---|
| GET | `/api/files` | 列出文件 |
| GET | `/api/files/read` | 读文件 |
| GET | `/api/files/download` | 下载文件 |
| POST | `/api/files/upload` | 上传文件 |
| POST | `/api/files/mkdir` | 创建目录 |
| DELETE | `/api/files` | 删除文件 |
| GET | `/api/media` | 媒体文件 |
| GET | `/api/fs/list` | 文件系统列表 |
| GET | `/api/fs/read-text` | 读文本文件 |
| GET | `/api/fs/read-data-url` | 读文件为 data URL |
| GET | `/api/fs/git-root` | git root |
| GET | `/api/fs/default-cwd` | 默认工作目录 |

### 4.9 Billing / Credits

| Method | 路径 | 说明 |
|---|---|---|
| GET | `/api/logs` | 日志 |

### 4.10 Auth (gated 模式专用)

| Method | 路径 | 说明 |
|---|---|---|
| POST | `/api/auth/ws-ticket` | 获取 WebSocket 一次性 ticket |
| POST | `/api/auth/logout` | 登出 |

### 4.11 OAuth / Providers

| Method | 路径 | 说明 |
|---|---|---|
| GET | `/api/providers/oauth` | OAuth provider 列表 |
| DELETE | `/api/providers/oauth/{provider_id}` | 删除 OAuth |
| POST | `/api/providers/oauth/{provider_id}/start` | 开始 OAuth 流程 |
| POST | `/api/providers/oauth/{provider_id}/submit` | 提交 OAuth |
| GET | `/api/providers/oauth/{provider_id}/poll/{session_id}` | OAuth 轮询 |
| DELETE | `/api/providers/oauth/sessions/{session_id}` | 删除 OAuth session |

### 4.12 Ops / Debug

| Method | 路径 | 说明 |
|---|---|---|
| POST | `/api/ops/prompt-size` | 计算 prompt 大小 |
| POST | `/api/ops/dump` | dump 调试信息 |
| POST | `/api/ops/config-migrate` | 配置迁移 |
| POST | `/api/ops/debug-share` | 分享调试信息 |
| POST | `/api/gateway/restart` | 重启 gateway |
| POST | `/api/hermes/update` | 更新 Hermes |
| GET | `/api/actions/{name}/status` | action 状态 |

### 4.13 Curator / Portal

| Method | 路径 | 说明 |
|---|---|---|
| GET | `/api/curator` | curator 状态 |
| PUT | `/api/curator/paused` | 暂停 curator |
| POST | `/api/curator/run` | 运行 curator |
| GET | `/api/portal` | portal 状态 |

### 4.14 Audio

| Method | 路径 | 说明 |
|---|---|---|
| POST | `/api/audio/transcribe` | 语音转文字 |
| GET | `/api/audio/elevenlabs/voices` | ElevenLabs 声音列表 |
| POST | `/api/audio/speak` | TTS |

### 4.15 Messaging (Telegram 等)

| Method | 路径 | 说明 |
|---|---|---|
| GET | `/api/messaging/platforms` | 消息平台列表 |
| PUT | `/api/messaging/platforms/{platform_id}` | 更新平台 |
| POST | `/api/messaging/platforms/{platform_id}/test` | 测试平台 |

---

## 5. Dart ↔ Python 字段映射约定

| Python (snake_case) | Dart (camelCase) | 备注 |
|---|---|---|
| `session_id` | `sessionId` | |
| `profile_name` | `profileName` | |
| `is_active` | `isActive` | |
| `last_connected_at` | `lastConnectedAt` | DateTime |
| `api_key` | `apiKey` | |
| `open_tool` | `openTool` | |
| `token_estimate` | `tokenEstimate` | |
| `cwd` | `cwd` | 保持原样 |
| `task_id` | `taskId` | |

---

## 6. 鉴权流程图

```
Client                    Hermes Server
  |                            |
  |-- WS connect ?token=x ---->|
  |<-- gateway.ready ----------|
  |                            |
  OR                           |
  |                            |
  |-- POST /api/auth/ws-ticket >|
  |<-- {"ticket": "xxx"} ------|
  |-- WS connect ?ticket=xxx -->|
  |<-- gateway.ready ----------|
```
