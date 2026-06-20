# Phase 0 — 基础准备：详细实施计划

> Phase 0 of Kelivo → Hermes 迁移
> Branch: `feat/hermes-phase-0-foundation` (worktree: `kelivo-phase-0`)
> Status: **in progress**
> Date: 2026-06-20

---

## Phase 0 目标

Hermes 协议 Dart 端最简 PoC，后端管理 UI 就绪，启动 gate 打通。

---

## 交付物清单

| # | 文件 / 目录 | 说明 |
|---|---|---|
| 1 | `lib/hermes/hermes_models.dart` | 所有事件 / RPC 响应 DTO |
| 2 | `lib/hermes/hermes_auth.dart` | `HermesAuth` abstract + `LoopbackAuth` + `GatedAuth` |
| 3 | `lib/hermes/hermes_event_bus.dart` | 事件分发总线 |
| 4 | `lib/hermes/hermes_gateway.dart` | WS JSON-RPC 客户端 |
| 5 | `lib/hermes/hermes_rest_client.dart` | REST 客户端 |
| 6 | `lib/hermes/hermes_config.dart` | 多 backend 列表( Hive 持久化) |
| 7 | `lib/hermes/hermes_profile_scope.dart` | Profile scope 管理 |
| 8 | `lib/hermes/hermes_backend_discovery.dart` | mDNS 局域网发现(bonsoir) |
| 9 | `lib/hermes/hermes_backend_qr.dart` | QR 码解析 |
| 10 | `lib/features/backend/backend_list_page.dart` | 后端列表页 |
| 11 | `lib/features/backend/add_backend_sheet.dart` | 添加后端(3 tab) |
| 12 | `lib/features/backend/backend_detail_sheet.dart` | 后端详情 |
| 13 | `lib/features/connection/connection_gate.dart` | 启动连接 gate |
| 14 | `lib/core/providers/hermes_gateway_provider.dart` | 顶层 HermesGateway Provider |
| 15 | `lib/main.dart` | 启动流程改造 |
| 16 | `test/hermes/hermes_gateway_test.dart` | 单元测试 |
| 17 | `pubspec.yaml` | 新增依赖 |

---

## Step 0.1 — 准备工作 (0.5 天)

**0.1.1** 加依赖到 `pubspec.yaml`:
```yaml
dependencies:
  bonsoir: ^6.0.1
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  web_socket_channel: ^3.0.1

dev_dependencies:
  freezed: ^2.5.7
  json_serializable: ^6.8.0
```

**0.1.2** `flutter pub get`

**0.1.3** 4 个 ARB 加键集（见 § 国际化）

**0.1.4** `flutter gen-l10n` + `flutter analyze` + `flutter test` 验证基线

---

## Step 0.2 — Hermes 核心模型 (0.25 天)

**0.2.1** `lib/hermes/hermes_models.dart`

所有事件 sealed class（对应 `gateway/stream_events.py`）:
- tool: `ToolStart`, `ToolComplete`, `ToolGenerating`
- message: `MessageStart`, `MessageDelta`, `MessageComplete`
- reasoning: `ReasoningDelta`, `ReasoningAvailable`
- gateway: `StatusUpdate`, `ApprovalRequest`, `SessionInfo`, `Error`, `ThinkingDelta`, `GatewayReady`, `SkinChanged`, `GatewayNotice`
- preview: `PreviewRestartProgress`, `PreviewRestartComplete`

RPC 响应模型:
- `RpcResult`: 通用 JSON-RPC 响应
- `SessionInfo`: 会话信息
- `SessionList`: 会话列表
- `SubmitResult`: prompt.submit 返回

后端配置模型:
- `HermesBackend`: id / name / url / authMode / token? / profile? / addedAt / lastConnectedAt / lastError / isActive
- `HermesAuthMode`: enum (loopback | gated)

**0.2.2** 运行 `build_runner`:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Step 0.3 — 鉴权层 (0.25 天)

**0.3.1** `lib/hermes/hermes_auth.dart`

```dart
abstract class HermesAuth {
  Future<Map<String, String>> wsAuthQuery();   // WS connect 时的 query 参数
  Future<Map<String, String>> restAuthHeader(); // REST header
  String? get currentToken;
}

class LoopbackAuth implements HermesAuth {
  // token 静态: WS ?token=<t>, REST Authorization: Bearer <t>
}

class GatedAuth implements HermesAuth {
  // 每次 WS connect 前 POST /api/auth/ws-ticket 拿 ticket
  // WS ?ticket=<t>, REST credentials: include (cookie)
}
```

**0.3.2** 鉴权探测逻辑（在 HermesGateway 内）:
1. 首次连接用 token query param
2. 如果收到 `401` → 自动尝试 gated 模式
3. 成功后缓存 `authMode` 到 `HermesConfig`

---

## Step 0.4 — 事件总线 + Gateway (0.5 天)

**0.4.1** `lib/hermes/hermes_event_bus.dart`

```dart
class HermesEventBus {
  Stream<T> eventsOf<T extends HermesStreamEvent>();
  Stream<HermesStreamEvent> get allEvents;
  void emit(HermesStreamEvent event);
  void dispose();
}
```

**0.4.2** `lib/hermes/hermes_gateway.dart`

核心状态机:
```
Disconnected → Connecting → Authenticating → Ready → [Disconnected on error]
```

关键方法:
- `Future<void> connect(HermesBackend backend)`
- `Future<void> disconnect()`
- `Future<dynamic> sendRpc(String method, [Map<String, dynamic>? params])`
- `Stream<HermesStreamEvent> get events`

重连策略: 指数退避 1s/2s/4s/8s/16s/30s max，永久重试
心跳: 每 25s 发 ping，30s 无响应则断开重连

WS JSON-RPC 协议:
- 请求: `{"jsonrpc": "2.0", "id": "1", "method": "session.list", "params": {}}`
- 事件: `{"jsonrpc": "2.0", "method": "event", "params": {"type": "message.delta", "session_id": "s1", "payload": {"text": "..."}}}`

**0.4.3** `lib/hermes/hermes_rest_client.dart`

封装 Dio，自动注入 auth header，错误处理: 401 → 触发 auth 重试

---

## Step 0.5 — 后端配置与发现 (0.5 天)

**0.5.1** `lib/hermes/hermes_config.dart`

Hive box: `hermes_backends`，TypeId: 100

**0.5.2** `lib/hermes/hermes_backend_discovery.dart` (mDNS)

监听 `_hermes._tcp` 服务，返回 `Stream<List<DiscoveredHermesBackend>>`

**0.5.3** `lib/hermes/hermes_backend_qr.dart`

QR 格式: `kelivo://hermes?<url>&<auth>&<profile?>` 或纯 JSON

---

## Step 0.6 — 后端管理 UI (0.5 天)

**0.6.1** `lib/features/backend/backend_list_page.dart`

- 页面：AppBar + ListView
- 每个 item: `IosCardPress` → 后端名 / URL / 状态指示灯 / 最后连接时间
- FAB: "+ 添加后端"
- 无后端时: 空状态引导页

**0.6.2** `lib/features/backend/add_backend_sheet.dart`

3 个 TabBar tab:
1. **手动输入**: URL + token(密码) + profile + "自动探测" 按钮
2. **扫码**: camera → 扫 QR → 自动填表
3. **局域网**: bonsoir 列表 → 点选 → 自动填

**0.6.3** `lib/features/backend/backend_detail_sheet.dart`

展示: 名称 / URL / 鉴权模式 / profile / 最后连接 / 最后错误
操作: 测试连接 / 重连 / 编辑 / 删除

---

## Step 0.7 — 启动 Gate + main.dart 改造 (0.5 天)

**0.7.1** `lib/features/connection/connection_gate.dart`

3 种状态:
1. **无后端**: 提示"请添加 Hermes 后端" → 跳转 `AddBackendSheet`
2. **重连中**: 进度指示 + "正在连接 {url}"
3. **连接失败**: 错误信息 + 重试按钮

**0.7.2** `lib/core/providers/hermes_gateway_provider.dart`

顶层 `ChangeNotifier`，持有 `HermesGateway` 单例

**0.7.3** `lib/main.dart` 改造

```
SplashScreen → HermesGatewayProvider.init()
     → if backends.isEmpty → AddBackendSheet (强制)
     → else auto-connect active backend
          → if connected → HomePage
          → if failed → ConnectionGate (error state)
```

---

## Step 0.8 — 国际化 (并行)

4 个 ARB 文件新增 `*_backend_*` / `*_connection_*` 键集（详见各 ARB 文件 diff）

---

## Step 0.9 — 单元测试 (0.25 天)

- `test/hermes/hermes_gateway_test.dart`: connect/disconnect/token 鉴权/gated ticket/重连/事件/RPC
- `test/hermes/hermes_config_test.dart`: add/remove/setActive/updateError
- `test/hermes/hermes_auth_test.dart`: LoopbackAuth / GatedAuth

---

## Step 0.10 — 桌面平台验证 (0.25 天)

```bash
flutter run -d macos
flutter run -d windows
flutter run -d linux
flutter build ios --no-codesign --debug
flutter build apk --debug
```

---

## Step 0.11 — PR + 合并

```bash
git add -A
git commit -m "feat(hermes): Phase 0 — Hermes client foundation, backend management, connection gate"
git push -u origin feat/hermes-phase-0-foundation
# → PR review → merge
git worktree remove ../kelivo-phase-0
```

---

## Appendix A — 新增依赖汇总

```yaml
dependencies:
  bonsoir: ^6.0.1
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  web_socket_channel: ^3.0.1

dev_dependencies:
  freezed: ^2.5.7
  json_serializable: ^6.8.0
```

## Appendix B — Hive Type ID 分配

| TypeId | 类 | 用途 |
|---|---|---|
| 100 | `HermesBackendBox` | Hermes 后端配置 |
| 101+ | 预留 | Phase 1+ |

## Appendix C — 风险与缓解

| 风险 | 缓解 |
|---|---|
| bonsoir 在某些 Android 设备需要额外权限 | 检查 `AndroidManifest.xml`，必要时加 `ACCESS_WIFI_STATE`, `ACCESS_FINE_LOCATION` |
| web_socket_channel 某些平台行为不一致 | 用 mock server 测，CI 跑三平台 |
| freezed 生成文件与 build_runner 版本冲突 | 固定 `freezed: ^2.5.7` + `build_runner: ^2.4.0` |
