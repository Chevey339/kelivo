# Kelivo → Hermes 专用客户端：完全改造计划

> Status: **v1.0 (scope locked)** — 范围、Phase、后端拓扑、鉴权、平台已确认
> Date: 2026-06-20
> 目标: 把 Kelivo 从"独立 LLM 聊天 App"完全改造为"Hermes 专用客户端"。现有 Flutter 架构、UI 组件、视觉风格保留; 业务层全部接 Hermes Backend。

---

## 0. 已锁定的范围决策(2026-06-20)

| # | 决策 | 结论 |
|---|---|---|
| 1 | Phase 范围 | **6 个 Phase 全做** |
| 2 | 后端拓扑 | **同时支持远端 URL + 局域网**(`HermesConfig` 允许多 backend,支持手动 URL / mDNS 发现 / QR 扫码三种添加方式) |
| 3 | 鉴权模式 | **loopback (`?token=`) + gated (`/api/auth/ws-ticket` 一次性 ticket) 都要实现**; 启动时探测 `__HERMES_AUTH_REQUIRED__` 自动切换 |
| 4 | 桌面端 | **macOS / Windows / Linux 三平台都保留并验证**; 同时保留 iOS / Android |

---

## 1. 目标 / 非目标

### 1.1 目标

- Kelivo 启动后**强制要求连接一台运行中的 Hermes 后端**(用户首次配置 backend URL + token)。
- 所有聊天、会话、技能、MCP、Cron、统计、设置、配置**全部走 Hermes**; Kelivo 不再直连 LLM provider,不再自管 provider/assistant 持久化。
- 视觉与交互完全沿用 Kelivo 现有 iOS 风格(`IosIconButton` / `IosCardPress` / `IosTileButton` 等)。
- 改造后产物**仅在 Hermes 后端可用时工作** — 这是有意的产品定位。
- 5 平台全部发布: iOS / Android / macOS / Windows / Linux。

### 1.2 非目标(本项目内不做)

- 不内嵌 Python Hermes 后端(假设外部运行)。
- 不保留 Kelivo 原"直连 LLM" UI 入口(底层 service 文件保留作为 fallback,不删除)。
- 不做 Push Notification 唤醒; 后台长连接策略沿用 Kelivo 现有 `ios_background_generation` / `android_background` 思路(但重做,因为后端是远程)。
- 不做 Hermes 端改动(只读 + 实现对齐)。如发现 Hermes 接口有 bug,单独提 issue。

### 1.2 非目标(本项目内不做)

- 不内嵌 Python Hermes 后端(假设外部运行)。
- 不保留 Kelivo 原"直连 LLM" UI 入口(底层 service 文件保留作为 fallback,不删除)。
- 不做 Push Notification 唤醒; 后台长连接策略沿用 Kelivo 现有 `ios_background_generation` / `android_background` 思路(但重做,因为后端是远程)。
- 不做 Hermes 端改动(只读 + 实现对齐)。如发现 Hermes 接口有 bug,单独提 issue。

---

## 2. 关键设计决策

### 2.1 整体架构

```
┌─────────────────────────────────────────────────────┐
│                 Kelivo UI (Flutter)                  │
│  features/   shared/   theme/   l10n/                │
└──────────────────────┬──────────────────────────────┘
                       │ consumes Hermes state
┌──────────────────────┴──────────────────────────────┐
│  Hermes Provider Layer (改造 core/providers/)       │
│  ChatProvider · SessionProvider · ProfileProvider   │
│  SkillsProvider · McpProvider · SettingsProvider    │
└──────────────────────┬──────────────────────────────┘
                       │ 状态镜像 + 事件订阅
┌──────────────────────┴──────────────────────────────┐
│  Hermes Client Layer (新: lib/hermes/)               │
│  HermesGateway (WS JSON-RPC)                         │
│  HermesRestClient (REST)                             │
│  HermesAuth · HermesEventBus · HermesProfileScope   │
│  HermesModels (DTO)                                  │
└──────────────────────┬──────────────────────────────┘
                       │ WebSocket + HTTPS
┌──────────────────────┴──────────────────────────────┐
│              Hermes Backend (Python)                  │
│  tui_gateway/server.py · hermes_cli/web_server.py    │
└─────────────────────────────────────────────────────┘
```

### 2.2 三条核心原则

1. **Kelivo 不造 LLM 抽象** — 业务层只做"用户输入 → HermesGateway.send('prompt.submit') → 事件流回放给 UI"。
2. **Provider 模式延续** — 每个 Hermes RPC family 对应一个 Provider; EventBus → Provider 状态 → UI。
3. **本地缓存最小化** — Hive 改为 Hermes 状态镜像(用于启动冷启列表渲染、offline 启动); 所有写操作走 Hermes。

### 2.3 与 Hermes 的协议契约

- **WebSocket JSON-RPC 2.0**: `tui_gateway/ws.py` + `tui_gateway/server.py` 的 90+ `@method` 全要 Dart 端实现。
- **REST API**: `hermes_cli/web_server.py` 暴露的 `/api/...` 全要 Dart 端封装。
- **流式事件**: `gateway/stream_events.py` + `tui_gateway/server.py` 的 30+ `_emit(...)` 类型。

### 2.4 后端拓扑 & 鉴权设计(锁定版)

**多 backend 列表 + 当前 backend**:
- `lib/hermes/hermes_config.dart` 内 `List<HermesBackend>` + `String activeBackendId`
- `HermesBackend` 字段: `id / name / url / authMode / token? / profile? / addedAt / lastError / lastConnectedAt`
- Hive 持久化,启动时读;切换 backend 时 disconnect → reconnect

**三种"添加 backend"方式**(新增 `lib/features/backend/**`):
1. **手动 URL + token** — 远端 server,用户填 `https://hermes.example.com` + token
2. **局域网 mDNS 发现** — `package:bonsoir` (Flutter) 监听 `_hermes._tcp` 服务;列出局域网内 hermes 实例;点选即填
3. **QR 码扫描** — 复用 `lib/features/scan/` 的 `qr_scan_page.dart`;扫后端显示的 QR(含 url + token + profile)

**鉴权两种模式都要实现**(`lib/hermes/hermes_auth.dart`):
```
abstract class HermesAuth {
  Future<WsAuthParam> wsAuthQuery();  // 拿到 [name, value] 拼到 ?name=value
  Future<Map<String, String>> restAuthHeader();  // header
}

class LoopbackAuth implements HermesAuth {
  // token 静态,X-Hermes-Session-Token / ?token=<t>
  // REST: Authorization 头
}

class GatedAuth implements HermesAuth {
  // 每次 WS connect 前 POST /api/auth/ws-ticket 拿一次性 ticket(TTL 30s)
  // REST: 走 hermes_session_at cookie(credentials: include)
}
```

**鉴权自动探测**:
- 首次连接成功,服务端 ready 帧带 `skin` payload;同时存一个 `__HERMES_AUTH_REQUIRED__` 标志
- 失败回退:如果 WS 用 token 被拒(`401`),自动切换为 gated 模式(试探 `/api/auth/ws-ticket`)
- 用户在添加 backend 时可手动指定;UI 提供"自动探测"按钮

**Auth 探测时机**:
- 添加 backend 后首次握手探测 → 缓存 `authMode`
- 切换 backend 时重探测
- 启动时读缓存 + 必要时重新探测

---

## 3. 改造范围(分阶段)

每个 Phase 结束都有可验证的交付物,可在合并到主线前先在分支跑通。

### Phase 0 — 基础准备(2-3 天)

**目标**: Hermes 协议在 Dart 端跑通最简 PoC; 后端列表 / 鉴权 / 启动主流程就绪。

**交付物**:
- `lib/hermes/hermes_gateway.dart` — WebSocket JSON-RPC 客户端(连接 / 鉴权 / 重连 / 心跳 / RPC send / event dispatch)
- `lib/hermes/hermes_auth.dart` — `HermesAuth` abstract + `LoopbackAuth` + `GatedAuth`
- `lib/hermes/hermes_models.dart` — 与 Python `gateway/stream_events.py` 字段对齐的 Dart 端 sealed class / freezed
- `lib/hermes/hermes_event_bus.dart` — 事件分发总线
- `lib/hermes/hermes_config.dart` — 多 backend 列表 + 当前 backend(URL / token / profile / authMode)
- `lib/hermes/hermes_rest_client.dart` — REST 客户端(基于 `package:http` 或复用 `dio_http_client.dart`)
- `lib/hermes/hermes_profile_scope.dart` — Profile 切换 scope 管理
- `lib/hermes/hermes_backend_discovery.dart` — mDNS 局域网发现(基于 `bonsoir`)
- `lib/hermes/hermes_backend_qr.dart` — QR 码解析
- `lib/features/backend/**` — 后端管理 UI:
  - `backend_list_page.dart` — 后端列表
  - `add_backend_sheet.dart` — 添加(3 个 tab: 手动 / 扫码 / 局域网)
  - `backend_detail_sheet.dart` — 单个 backend 详情 / 重连 / 删除
- `lib/features/connection/connection_gate.dart` — 启动时连接 gate(未连接 / 重连中 / 已连接)
- `lib/main.dart` — 启动流程改造: 读 config → 尝试连 → 跳 connection_gate 或主页
- 一份 `docs/HERMES_CONTRACT.md`(90+ RPC、30+ event、50+ REST 速查表,带字段映射 camelCase ↔ snake_case)
- 单元测试: connect / disconnect / token 鉴权 / gated ticket 鉴权 / 重连 / 一个示例 RPC (`session.most_recent`)
- **新依赖**: `bonsoir` (mDNS), `freezed` + `freezed_annotation` + `json_serializable` + `json_annotation` (DTO), 已有 `web_socket_channel` (WS), 已有 `qr_code_scanner` (复用)
- **i18n**: 4 个 ARB 文件加 `*_backend_*` 键集
- **桌面平台**:
  - macOS / Windows / Linux: 启动 → connection_gate 验证(用 mock Hermes server)

**验收**:
- `flutter test` 跑通 HermesGateway 单元测试
- 手动连真 Hermes 收到 `gateway.ready` 事件
- 三种添加 backend 方式都能用
- loopback / gated 两种鉴权都能跑通(用 Hermes `--insecure` 与 `OAuth` 模式分别测)
- 桌面三平台 `flutter build` 全部通过
- 启动未连接 → 显示 connection_gate;连上后切到主页

### Phase 1 — 聊天核心(3-5 天)

**目标**: 实时聊天能完整跑通(创建/恢复会话、提交 prompt、收 streaming 事件、中断、分支、压缩、undo、approval/clarify/sudo/secret 弹窗)。

**改造**:
- `lib/core/providers/chat_provider.dart` — 流式生成路径重写,所有 `ChatApiService` 调用替换为 `HermesGateway.send('prompt.submit')`
- `lib/features/home/controllers/stream_controller.dart` — 接入 Hermes event bus(`message.delta` / `message.start` / `message.complete` / `reasoning.delta` / `tool.start` / `tool.complete` / `tool.progress` / `tool.generating` / `thinking.delta` / `reasoning.available` / `background.complete`)
- `lib/features/home/controllers/chat_controller.dart` — 接 `session.interrupt` / `session.branch` / `session.undo` / `session.compress`
- `lib/features/chat/widgets/*` — 保留 UI,信号源从 Provider 改为 HermesEventBus
- `lib/shared/widgets/approval_sheet.dart`(新增) — `approval.request` 弹窗
- `lib/shared/widgets/clarify_sheet.dart`(新增) — `clarify.request` 弹窗
- `lib/shared/widgets/sudo_sheet.dart` / `secret_sheet.dart`(新增) — 同上

**RPC 接入**:
- `session.create` / `session.resume` / `session.most_recent` / `session.close` / `session.title` / `session.delete` / `session.interrupt` / `session.steer` / `session.branch` / `session.compress` / `session.undo` / `session.save` / `session.cwd.set` / `session.status` / `session.history` / `session.usage`
- `prompt.submit` / `prompt.background` / `preview.restart`
- `clarify.respond` / `sudo.respond` / `secret.respond` / `approval.respond`
- `file.attach` / `image.attach` / `image.attach_bytes` / `pdf.attach` / `image.detach` / `clipboard.paste` / `input.detect_drop`
- `delegation.status` / `delegation.pause` / `subagent.interrupt`
- `handoff.request` / `handoff.state` / `handoff.fail`
- `terminal.resize` / `terminal.read.respond`

**Event 订阅**: 全 streaming 事件 + `preview.restart.*` + `browser.progress`

**验收**:
- 集成测试: 启动 Hermes 容器 → Kelivo 连上 → 新建会话 → 聊天 → 切会话 → 中断 → 恢复
- 工具调用 / 思考过程 / 推理过程 UI 完整显示
- 审批 / 澄清 / sudo / secret 弹窗可正常响应

### Phase 2 — 会话管理(2-3 天)

**目标**: 会话列表 / 搜索 / 导出 / 用量 / 积分 / Handoff 状态展示。

**改造**:
- `lib/features/chat/pages/chat_history_page.dart` — 重做,接 `session.list` / `session.search` / `session.delete` / `session.active_list` / `session.activate`
- `lib/features/home/widgets/side_drawer.dart` — 接入 `session.list`,加 Profile 切换入口
- 新增 `lib/features/session/**` — 会话详情 / 状态 / 用量页
- 新增 `lib/features/credits/**` — `credits.view` / `billing.state` / `billing.charge` / `billing.charge_status` / `billing.auto_reload` / `billing.step_up`

**REST 接入**:
- `GET /api/sessions` (分页/搜索) / `GET /api/sessions/{id}/messages` / `GET /api/sessions/{id}/export` / `GET /api/sessions/{id}/latest-descendant` / `POST /api/sessions/prune` / `POST /api/sessions/empty` / `DELETE /api/sessions/empty` / `POST /api/sessions/bulk-delete` / `PATCH /api/sessions/{id}` (rename) / `GET /api/sessions/search` / `GET /api/sessions/stats` / `GET /api/sessions/empty/count`

**RPC 接入**: 上面已列

**验收**:
- 会话列表分页 / 搜索 / 排序
- 会话导出(下载 markdown / 文本)
- Credits / Billing UI 显示与触发
- Handoff 状态实时显示

### Phase 3 — Settings / Profile / Skills / Model(3-4 天)

**目标**: 完整管理 UI(配置、Profile、模型、技能、工具集、Env、字体、主题)。

**改造**:
- `lib/features/settings/pages/settings_page.dart` — 完全重做,改用 Hermes REST
- `lib/features/settings/pages/display_settings_page.dart` — 字体 / 主题走 `/api/dashboard/font` / `/api/dashboard/theme`
- `lib/features/settings/pages/network_proxy_page.dart` — 走 `/api/config` (network.proxy)
- `lib/desktop/setting/**` — desktop setting 各 pane 全部改 Hermes
- `lib/features/provider/pages/providers_page.dart` / `provider_detail_page.dart` — 改 Hermes `/api/providers` (改用 Hermes 端管理 provider)
- `lib/features/assistant/pages/assistant_settings_edit_page.dart` / `*_tab` — 改 Hermes `/api/assistants` (如有对应端点;否则从 Hermes `agent` 模块的 config 拼装)
- 新增 `lib/features/profile/**` — Profile 切换 / 创建 / 克隆 / 删除 / 描述 / 模型设置 / soul
- 新增 `lib/features/skills/**` — Skills 列表 / 启停 / 内容编辑 / Hub 浏览 / 安装
- 新增 `lib/features/toolsets/**` — Toolsets 列表 / 启停 / provider / env
- 新增 `lib/features/dashboard_plugins/**` — 仪表板插件 / 主题 / 字体偏好
- `lib/features/model/pages/default_model_page.dart` — 接 `/api/model/set` / `/api/model/options` / `/api/model/auxiliary`

**RPC 接入**:
- `config.get` / `config.set` / `config.show`
- `model.options` / `model.save_key` / `model.disconnect`
- `tools.list` / `tools.show` / `tools.configure` / `toolsets.list`
- `agents.list` / `plugins.list`
- `cron.manage` (本阶段先暴露入口,实现放 Phase 4)
- `skills.manage` / `skills.reload`
- `commands.catalog` / `complete.path` / `complete.slash`
- `voice.toggle` / `voice.record` / `voice.tts` (本阶段先暴露入口,实现放 Phase 5)
- `browser.manage` (本阶段先暴露入口,实现放 Phase 4)

**REST 接入**:
- `/api/config` / `/api/config/raw` / `/api/config/defaults` / `/api/config/schema`
- `/api/env` / `/api/env/reveal`
- `/api/model/info` / `/api/model/set` / `/api/model/options` / `/api/model/auxiliary`
- `/api/profiles` / `/api/profiles/active` / `/api/profiles/{name}` / `/api/profiles/{name}/description` / `/api/profiles/{name}/describe-auto` / `/api/profiles/{name}/model` / `/api/profiles/{name}/soul` / `/api/profiles/{name}/setup-command`
- `/api/skills` / `/api/skills/toggle` / `/api/skills/content` / `/api/skills/hub/install|uninstall|update|search|sources|preview|scan`
- `/api/tools/toolsets` / `/api/tools/toolsets/{name}` / `/api/tools/toolsets/{name}/config` / `/api/tools/toolsets/{name}/provider` / `/api/tools/toolsets/{name}/env` / `/api/tools/toolsets/{name}/post-setup`
- `/api/dashboard/plugins` / `/api/dashboard/plugins/rescan` / `/api/dashboard/plugins/hub` / `/api/dashboard/agent-plugins/*` / `/api/dashboard/plugin-providers` / `/api/dashboard/plugins/{name}/visibility` / `/api/dashboard/themes` / `/api/dashboard/theme` / `/api/dashboard/font`
- `/api/messaging/platforms` / `/api/messaging/platforms/{id}` / `/api/messaging/platforms/{id}/test` / `/api/messaging/telegram/onboarding/*`
- `/api/providers/oauth/*`

**验收**:
- Profile 切换即时生效(下次开新会话使用新 profile)
- Config 修改写回 `~/.hermes/config.yaml`(后端)
- Skills Hub 可浏览 / 安装 / 卸载 / 扫描
- Model assignment 持久化,下次 session.resume 用新 model

### Phase 4 — MCP / Cron / Webhook / Ops(2-3 天)

**目标**: 后台运维能力(管理员面)。

**改造**:
- `lib/features/mcp/pages/mcp_page.dart` / `*_sheet` — 完全重做,接 Hermes `/api/mcp/*`
- `lib/features/cron/**`(新增) — Cron 任务管理 / 蓝图 / 触发 / 启停
- `lib/features/webhook/**`(新增) — Webhook 启停 / 创建 / 删除
- `lib/features/ops/**`(新增) — Doctor / Security Audit / Backup / Import / Hooks / Checkpoints / Debug Share / Dump / Prompt Size / Config Migrate
- `lib/features/pairing/**`(新增) — 配对管理
- `lib/features/credentials/**`(新增) — 凭证池
- `lib/features/curator/**`(新增) — Curator 状态 / 暂停 / 触发
- `lib/features/portal/**`(新增) — Portal 状态展示
- `lib/features/system/**`(新增) — `/api/system/stats` 展示

**REST 接入**:
- `/api/mcp/servers` / `/api/mcp/servers/{name}` / `/api/mcp/servers/{name}/test` / `/api/mcp/servers/{name}/enabled` / `/api/mcp/catalog` / `/api/mcp/catalog/install`
- `/api/cron/jobs` / `/api/cron/jobs/{id}` / `/api/cron/jobs/{id}/pause` / `/api/cron/jobs/{id}/resume` / `/api/cron/jobs/{id}/trigger` / `/api/cron/blueprints` / `/api/cron/blueprints/instantiate` / `/api/cron/delivery-targets`
- `/api/webhooks` / `/api/webhooks/enable` / `/api/webhooks/{name}` / `/api/webhooks/{name}/enabled`
- `/api/pairing` / `/api/pairing/approve` / `/api/pairing/revoke` / `/api/pairing/clear-pending`
- `/api/credentials/pool` / `/api/credentials/pool/{provider}/{index}`
- `/api/ops/doctor` / `/api/ops/security-audit` / `/api/ops/backup` / `/api/ops/import` / `/api/ops/hooks` / `/api/ops/prompt-size` / `/api/ops/dump` / `/api/ops/config-migrate` / `/api/ops/debug-share` / `/api/ops/checkpoints` / `/api/ops/checkpoints/prune`
- `/api/curator` / `/api/curator/paused` / `/api/curator/run`
- `/api/portal`
- `/api/system/stats`

**RPC 接入**:
- `reload.mcp` / `reload.env`
- `process.list` / `process.kill` / `process.stop`
- `cli.exec` / `command.resolve` / `command.dispatch` / `paste.collapse`
- `browser.manage`
- `shell.exec` (注意:权限审批,走 `approval.request`)

**验收**:
- MCP 服务器 CRUD / 启停 / 测试连通
- Cron 任务创建 / 暂停 / 恢复 / 触发 / 删除
- Ops 操作的启动 → 轮询 → 状态展示 完整流程

### Phase 5 — Stats / Logs / Voice / Memory / Insights / Rollback(2-3 天)

**目标**: 可观测性 + 体验增强。

**改造**:
- `lib/features/stats/pages/stats_page.dart` — 改造,接 `/api/analytics/*`
- `lib/features/settings/pages/log_viewer_page.dart` — 接 `/api/logs`
- `lib/features/voice/**`(新增) — Voice 录音 / 播放 / 状态
- `lib/features/memory/**`(新增) — Memory provider 选择 / 重置
- `lib/features/insights/**`(新增) — `/api/insights`
- `lib/features/rollback/**`(新增) — `/api/rollback/list` / `restore` / `diff`
- `lib/features/world_book/pages/world_book_page.dart` — 改造(走 Hermes,如 Hermes 有对应端点)
- `lib/features/translate/pages/translate_page.dart` — 改造(走 Hermes)
- `lib/features/quick_phrase/**` — 改造(走 Hermes)

**RPC 接入**:
- `voice.toggle` / `voice.record` / `voice.tts` / `voice.transcript` / `voice.status`
- `insights.get`
- `rollback.list` / `rollback.restore` / `rollback.diff`

**REST 接入**:
- `/api/analytics/usage` / `/api/analytics/models`
- `/api/logs`
- `/api/memory` / `/api/memory/provider` / `/api/memory/reset`

**Event 订阅**: `voice.*`

**验收**:
- Stats 图表 / 排行 / 分类
- Log viewer 实时滚动
- Voice 全流程可用
- Memory 重置生效

### Phase 6 — 打磨 / 桌面 / 错误 / 迁移(2-3 天)

**目标**: 桌面壳打磨 / 错误处理 / 数据迁移 / E2E 测试。

**改造**:
- `lib/desktop/desktop_home_page.dart` — 接入 Hermes 启动 / 停止 / 重启 / 更新动作
- `lib/desktop/desktop_tray_controller.dart` — tray 菜单改造,接 Hermes 状态
- `lib/desktop/window_title_bar.dart` — 保持视觉,事件接 Hermes
- `lib/desktop/hotkeys/*` — hotkey 改造,触发 Hermes RPC
- `lib/desktop/setting/*` — desktop settings 全面重接
- `lib/main.dart` — 启动流程:
  1. 读本地 `HermesConfig`(URL / token / active profile)
  2. 尝试连接 Hermes
  3. 失败 → 显示"未连接"页 + 设置入口
  4. 成功 → 进入聊天主页
- 新增 `lib/features/connection/**` — 未连接 / 重连中 / 错误页
- `lib/l10n/**` — 错误消息本地化(4 个 ARB)
- 数据迁移: 现有 Hive 中的数据(Provider / Assistant / 会话)做一次性"导入到 Hermes"流程
- E2E 测试: 关键流程

**验收**:
- 启动连不上 → 显示配置页 / 重连
- 后台 idle 30 min → 自动重连
- 桌面 tray 菜单触发 Hermes 操作
- 全部 471 个现有测试(大量 fail)按计划迁移完成或删除

---

## 4. 关键文件改动总览

### 4.1 新增(顶层 `lib/hermes/` 目录)

```
lib/hermes/
├── hermes_gateway.dart          # WS JSON-RPC 客户端
├── hermes_rest_client.dart      # REST 客户端
├── hermes_auth.dart             # 鉴权(loopback / gated)
├── hermes_event_bus.dart        # 事件分发
├── hermes_models.dart           # DTO / sealed class
├── hermes_config.dart           # 客户端配置
├── hermes_profile_scope.dart    # Profile 切换 scope
├── hermes_session.dart          # 会话状态镜像
├── hermes_logger.dart           # Hermes 专用日志
└── api/
    ├── session_api.dart
    ├── chat_api.dart
    ├── profile_api.dart
    ├── skills_api.dart
    ├── mcp_api.dart
    ├── settings_api.dart
    ├── stats_api.dart
    ├── cron_api.dart
    ├── gateway_api.dart
    ├── ops_api.dart
    ├── analytics_api.dart
    ├── logs_api.dart
    ├── memory_api.dart
    ├── voice_api.dart
    ├── insights_api.dart
    ├── rollback_api.dart
    └── ... (按需)
```

### 4.2 改造

- **核心**:
  - `lib/main.dart` — 启动流程
  - `lib/core/providers/chat_provider.dart` — 流式生成
  - `lib/core/providers/settings_provider.dart` — 全局设置
  - `lib/core/providers/assistant_provider.dart` — 助手
  - `lib/core/providers/mcp_provider.dart` — MCP
  - `lib/core/providers/world_book_provider.dart` — 世界书
  - `lib/core/providers/memory_provider.dart` — 记忆
  - `lib/core/providers/quick_phrase_provider.dart` — 快捷短语
  - `lib/core/providers/instruction_injection*.dart` — 提示注入
  - `lib/core/providers/backup_provider.dart` — 备份(走 Hermes)
  - `lib/core/providers/s3_backup_provider.dart` — 备份(走 Hermes)
  - `lib/core/providers/backup_reminder_provider.dart` — 备份提醒
  - `lib/core/providers/hotkey_provider.dart` — 桌面快捷键
  - `lib/core/providers/tts_provider.dart` — TTS(走 Hermes)
  - `lib/core/providers/user_provider.dart` — 用户
  - `lib/core/providers/tag_provider.dart` — 标签
  - `lib/core/providers/update_provider.dart` — 更新检测
  - `lib/core/providers/model_provider.dart` — 模型
  - `lib/core/services/api/chat_api_service.dart` — **保留作为底层 fallback**,但 UI 不再入口
  - `lib/core/services/chat/chat_service.dart` — 保留但改造为 HermesProxy 模式
  - `lib/core/services/api_key_manager.dart` — 改造(走 Hermes)
  - `lib/core/services/notification_service.dart` — 改造(走 Hermes)
  - `lib/core/services/ios_background_generation.dart` — 改造(走 Hermes)
  - `lib/core/services/android_background.dart` — 改造(走 Hermes)
  - `lib/core/services/haptics.dart` — 保留
  - `lib/core/services/learning_mode_store.dart` — 改造(走 Hermes)

- **聊天**:
  - `lib/features/home/**` — 全部改造
  - `lib/features/chat/**` — 全部改造
  - `lib/features/assistant/**` — 全部改造
  - `lib/features/chat/utils/thinking_tag_parser.dart` — 保留(纯逻辑)

- **Provider/Model/Settings/MCP/Cron/Stats/Backup/Search/Translate/WorldBook/QuickPhrase/InstructionInjection/Scan**:
  - `lib/features/{provider,model,settings,mcp,cron,stats,backup,search,translate,world_book,quick_phrase,instruction_injection,scan}/**` — 按 Phase 改造或新增

- **桌面**:
  - `lib/desktop/desktop_home_page.dart` — 改造
  - `lib/desktop/desktop_settings_page.dart` — 改造
  - `lib/desktop/desktop_tray_controller.dart` — 改造
  - `lib/desktop/window_title_bar.dart` — 保留视觉
  - `lib/desktop/hotkeys/*` — 改造
  - `lib/desktop/setting/*` — 全面改造
  - `lib/desktop/add_provider_dialog.dart` / `model_edit_dialog.dart` / `model_fetch_dialog.dart` — 改造(走 Hermes)
  - `lib/desktop/desktop_chat_page.dart` — 改造
  - `lib/desktop/mcp_servers_popover.dart` / `search_provider_popover.dart` / `world_book_popover.dart` / `quick_phrase_popover.dart` / `reasoning_budget_popover.dart` / `instruction_injection_popover.dart` / `mini_map_popover.dart` — 改造

### 4.3 删除(可选,迁移数据后)

- `lib/core/services/api/providers/{openai,claude_official,google_*,openai_*}.dart` — 保留,但不再被 UI 入口调用
- `lib/core/services/backup/chatbox_importer.dart` / `cherry_importer.dart` / `cherry_direct_backup_reader.dart` — 保留(供一次性数据迁移)
- `lib/core/services/search/providers/*.dart` — 保留(可作为本地搜索 fallback)

### 4.4 保留(不动)

- `lib/shared/widgets/**` — iOS 风格 widget 全部保留
- `lib/shared/dialogs/**` — 保留
- `lib/shared/responsive/**` — 保留
- `lib/shared/pages/webview_page.dart` — 保留
- `lib/shared/animations/**` — 保留
- `lib/theme/**` — 保留
- `lib/icons/**` — 保留
- `lib/utils/**` — 保留(纯函数工具)
- `lib/l10n/**` — 保留,新增错误消息翻译

---

## 5. 风险与缓解

| 风险 | 描述 | 缓解 |
|---|---|---|
| R1 | iOS/Android 后台杀进程 → 长连接断 | 沿用 Kelivo 现有的 `ios_background_generation` / `android_background` 思路,Phase 6 重做;依赖 Hermes 自己的 Live Activity 方案 |
| R2 | Stream event 高频触发 → WebSocket 帧小 → 抖动 | Dart 端 `WebSocket` 配置 TCP_NODELAY;UI 端节流(避免每帧 setState) |
| R3 | 多 Profile 切换 → 重连 / 重订事件 | 集中 `HermesProfileScope` 统一管理;切换时 disconnect → reconnect → 重新 `session.active_list` |
| R4 | 现有 471 个测试大量 fail | 按 Phase 同步迁移/重写测试;测试必须跟着改,不能拖到最后 |
| R5 | Hive 数据如何处理(用户原有会话/Provider) | 提供一次性"导入 Hermes"迁移工具(Phase 6);不主动删除本地数据 |
| R6 | build_runner 重生成 471 个文件 | 减少 Hive 用量,大部分 provider state 改为内存态;只在 config/skin/小集合上用 Hive |
| R7 | Hermes 接口字段命名差异(camelCase vs snake_case) | 在 `HermesModels` 层做映射,不让 snake_case 渗透到 Provider/UI |
| R8 | L10n 同步(4 个 ARB) | 每加一个错误消息,必须 4 个文件同步 |
| R9 | 桌面 tray/hotkey 改动可能影响 macOS/Windows/Linux | 走各平台原生 API,Phase 6 必须三平台都验证 |
| R10 | WebSocket 重连风暴 | 指数退避 + 随机抖动;上限 30s |

---

## 6. 验证标准

### 6.1 每个 Phase 结束

- `flutter analyze` 通过
- `dart format` 已执行
- `flutter test` 通过(对应 Phase 的测试)
- 4 个 ARB 文件同步
- 若涉及 Hive 模型,`dart run build_runner build --delete-conflicting-outputs` 已执行
- 若涉及 `dependencies/**` 或桌面代码,目标平台至少跑一次 `flutter build` / `flutter run`

### 6.2 全量验收(Phase 6 末尾)

- E2E: 启动 Hermes 容器 → Kelivo 连接 → 完整跑通 6 个 Phase 涉及的所有能力
- 三平台构建通过(macOS / Windows / Linux,以及 iOS / Android 至少构建过)
- 全部现有 471 测试按计划迁移/删除
- 桌面: tray / hotkey / window manager 跨平台验证
- 离线 / 重连 / 错误页 UX 友好

---

## 7. 工作量与时间线

| Phase | 工作量 | 累计 |
|---|---|---|
| Phase 0 — 基础准备(契约 + backend 管理 + 鉴权 + 启动 gate) | 2-3 天 | 2-3 天 |
| Phase 1 — 聊天核心 | 3-5 天 | 5-8 天 |
| Phase 2 — 会话管理 | 2-3 天 | 7-11 天 |
| Phase 3 — Settings/Profile/Skills | 3-4 天 | 10-15 天 |
| Phase 4 — MCP/Cron/Webhook/Ops | 2-3 天 | 12-18 天 |
| Phase 5 — Stats/Logs/Voice/Memory | 2-3 天 | 14-21 天 |
| Phase 6 — 打磨/桌面/迁移/E2E | 2-3 天 | 16-24 天 |
| **总计** | **16-24 工作日** | **3-5 周** |

单人执行 ~3-5 周。两人(分工:一人 Phase 1+2+3 偏后端 RPC,一人 Phase 4+5+6 偏管理 UI)可压缩到 2-3 周。

---

## 8. 分支 / Worktree 策略

每个 Phase 独立分支 + worktree,完成并验收后合并回 main。

| 分支 | Worktree 路径 | 范围 |
|---|---|---|
| `feat/hermes-phase-0-foundation` | `../kelivo-phase-0` | Phase 0 全量 |
| `feat/hermes-phase-1-chat` | `../kelivo-phase-1` | Phase 1 全量(基于 phase-0) |
| `feat/hermes-phase-2-sessions` | `../kelivo-phase-2` | Phase 2 全量(基于 phase-1) |
| `feat/hermes-phase-3-settings` | `../kelivo-phase-3` | Phase 3 全量 |
| `feat/hermes-phase-4-ops` | `../kelivo-phase-4` | Phase 4 全量 |
| `feat/hermes-phase-5-observability` | `../kelivo-phase-5` | Phase 5 全量 |
| `feat/hermes-phase-6-polish` | `../kelivo-phase-6` | Phase 6 全量(基于 phase-5) |

每个 Phase 开始前:
1. `git worktree add ../kelivo-phase-N -b feat/hermes-phase-N`
2. 落地 `docs/plans/hermes-phase-N.md`(本文件的 Phase N 详细 step-by-step 拆解)
3. 按 plan 实施
4. 跑验收脚本
5. PR review → 合并 → 删 worktree

---

## 9. 立即可执行 — Phase 0 step-by-step

> 计划已锁定; 等你说"开干"就立即启动。

### 9.1 Phase 0 任务清单(预估 2-3 天)

**Step 0.1 — 准备 (0.5 天)**
- [ ] 创建 worktree `feat/hermes-phase-0-foundation`
- [ ] `docs/plans/hermes-phase-0.md` 落地(从本文件 Phase 0 拆出来)
- [ ] 写 `docs/HERMES_CONTRACT.md` 骨架(从 Python 端 `tui_gateway/server.py` 的 90+ `@method` 反向列出来)
- [ ] 在 `pubspec.yaml` 加依赖: `bonsoir`, `freezed`, `freezed_annotation`, `json_serializable`, `json_annotation`
- [ ] `flutter pub get` 跑通
- [ ] 4 个 ARB 文件新增 `*_backend_*` / `*_connection_*` 键集(占位)
- [ ] `flutter gen-l10n` + `flutter analyze` + `flutter test` 跑通基线

**Step 0.2 — Hermes 客户端骨架 (0.5 天)**
- [ ] `lib/hermes/hermes_models.dart` — 事件 / RPC 响应 / 后端配置 DTO
- [ ] `lib/hermes/hermes_auth.dart` — `HermesAuth` abstract + `LoopbackAuth` + `GatedAuth`
- [ ] `lib/hermes/hermes_event_bus.dart` — 事件分发(Stream + listener)
- [ ] `lib/hermes/hermes_gateway.dart` — WebSocket 连接 / RPC send / event dispatch / 心跳 / 重连
- [ ] 单元测试: `test/hermes/hermes_gateway_test.dart` (mock WS server)

**Step 0.3 — REST 客户端 (0.5 天)**
- [ ] `lib/hermes/hermes_rest_client.dart` — 封装 Dio(复用 `lib/core/services/network/dio_http_client.dart`)
- [ ] 自动注入 auth header(loopback / gated)
- [ ] 错误处理: 401 → 触发 auth 重试
- [ ] 单元测试: 401 / 200 / 网络错误

**Step 0.4 — 后端管理 (0.5-1 天)**
- [ ] `lib/hermes/hermes_config.dart` — `List<HermesBackend>` + `activeBackendId` (Hive 持久化)
- [ ] `lib/hermes/hermes_backend_discovery.dart` — mDNS 局域网发现(`bonsoir`)
- [ ] `lib/hermes/hermes_backend_qr.dart` — QR 码解析(复用 `lib/features/scan/`)
- [ ] `lib/features/backend/backend_list_page.dart` — 后端列表
- [ ] `lib/features/backend/add_backend_sheet.dart` — 添加(3 个 tab: 手动 / 扫码 / 局域网)
- [ ] `lib/features/backend/backend_detail_sheet.dart` — 单个 backend 详情

**Step 0.5 — 启动 gate (0.5 天)**
- [ ] `lib/features/connection/connection_gate.dart` — 未连接 / 重连中 / 错误 三种状态 UI
- [ ] `lib/main.dart` — 启动流程改造
- [ ] `HermesGatewayProvider`(在 `lib/core/providers/` 下) — 顶层 Provider,持有 `HermesGateway` 单例

**Step 0.6 — 桌面 + 测试 (0.5 天)**
- [ ] macOS: `flutter run -d macos` 跑通 → 显示 connection_gate → 添加远端 backend → 连上
- [ ] Windows: `flutter run -d windows` 同样跑通
- [ ] Linux: `flutter run -d linux` 同样跑通
- [ ] 移动端至少 build 一次: `flutter build apk --debug` / `flutter build ios --no-codesign --debug`
- [ ] `flutter test` 全部通过
- [ ] `flutter analyze` 通过
- [ ] `dart format lib/hermes lib/features/backend lib/features/connection` 已执行

**Step 0.7 — PR + 合并**
- [ ] git commit + push
- [ ] PR review
- [ ] 合并到 main,删 worktree
- [ ] 立即开 `feat/hermes-phase-1-chat`

---

## 10. Next Step

立即可执行。给我一句"开干"或"开始 Phase 0"我就:
1. 创建 worktree
2. 写 `docs/plans/hermes-phase-0.md`(本文件 Phase 0 详细 step-by-step)
3. 写 `docs/HERMES_CONTRACT.md` 骨架
4. 加 `pubspec.yaml` 依赖
5. 4 个 ARB 加新键集
6. 跑通基线验证

Phase 0 预计 2-3 天完成验收后,直接开 Phase 1。
