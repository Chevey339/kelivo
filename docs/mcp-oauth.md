# MCP OAuth 接入与排查

HTTP / SSE MCP 使用授权码 + PKCE S256。STDIO 的凭据仍由环境变量提供。

## 配置

编辑服务器，展开 **OAuth 设置**：

- **自动**：复用与当前 issuer、回调地址绑定的动态注册信息；没有可用注册时使用服务端的 `registration_endpoint`。
- **Client ID**：填写在该授权服务器注册的客户端 ID。公共客户端选择 `none`；服务端要求密钥时选择 `client_secret_post` 或 `client_secret_basic`。
- **CIMD**：填写已公开托管的 HTTPS 客户端元数据文档 URL。只有授权服务器明确声明 `client_id_metadata_document_supported` 时才使用它。

本地回调地址通常留空。若服务端注册要求固定地址，可填写 `http://127.0.0.1:端口/路径`、`http://[::1]:端口/路径` 或 `http://localhost:端口/路径`；只监听本机地址。推荐 IP 字面量，端口 `0` 表示由系统分配可用端口。使用固定端口时需确保它未被其他程序占用。

点击 **填入示例** 可将输入框提示的 `http://localhost:0/callback` 填入，再按需修改端口和路径。

默认回调地址：

| 平台 | 回调 |
| --- | --- |
| Android | `psyche.kelivo://mcp-oauth-callback/authorize` |
| iOS | `psyche.kelivo:/oauth/callback/authorize` |
| macOS / Windows / Linux | `http://127.0.0.1:<系统分配端口>/callback` |

移动端也支持显式配置本地 HTTP 回调。授权码只经过本地 HTTP 监听器，随后使用仅含随机 state 的应用回调关闭浏览器并返回 Kelivo。

旧动态注册的回调地址不匹配时会重新注册。已经手动注册旧版回调地址的客户端，需要在服务端更新为上表中的地址，或显式配置其已注册的本地 HTTP 地址。

修改客户端或本地回调配置会清除原 token；改名称会保留登录。切换为“自动”会清除手动客户端配置。注册信息在打开浏览器前保存，因此取消浏览器登录后仍可复用。动态注册信息不跨 issuer 复用；手动 Client ID 与已记录的 issuer 不符时会报错。

## CIMD 文档

Kelivo 不内置未经部署的元数据 URL。下面的文档需要由客户端运营者托管；将 `client_id` 改为文档自身的真实 HTTPS URL，再在 OAuth 设置中填写同一 URL。

```json
{
  "client_id": "https://your-domain.example/kelivo/mcp-client.json",
  "client_name": "Kelivo",
  "client_uri": "https://github.com/Chevey339/kelivo",
  "application_type": "native",
  "redirect_uris": [
    "psyche.kelivo://mcp-oauth-callback/authorize",
    "psyche.kelivo:/oauth/callback/authorize",
    "http://127.0.0.1:3000/callback"
  ],
  "grant_types": ["authorization_code", "refresh_token"],
  "response_types": ["code"],
  "token_endpoint_auth_method": "none"
}
```

回调路径必须匹配。原生应用使用 HTTP loopback IP 地址时，授权服务器应按 RFC 8252 接受可变端口；若服务端限制固定端口，可在 Kelivo 配置文档中注册的完整地址。上面仅是部署示例，不代表该 URL 已发布。

## 发现与回调约束

- 优先使用 `WWW-Authenticate` 给出的 `resource_metadata`，它只指定文档位置；即使是根路径或跨主机的 well-known 地址，也不从该地址反推资源身份。未给出时依次访问自动构造的端点路径和根路径 well-known 地址，此时文档必须描述构造该地址所用的资源。
- `resource` 必须与 MCP 端点同源，并在路径段边界覆盖当前端点。这里沿用 MCP SDK 的资源边界校验，允许端点所属的根资源或父路径；这比 RFC 9728 §3.3 对显式 challenge 要求资源与请求 URL 完全相同的规则更宽，用于支持 Swiggy / Zepto 等根资源配置。
- 授权请求、授权码交换和刷新都使用发现文档中的 `resource`；token 仍绑定到实际配置的 MCP 端点，不能因根资源相同而被复用到另一配置 URL。
- 桌面本地监听器在接收回调前校验随机 state、GET 方法、唯一的 code/error 参数。错误 state、重复参数和已经完成的旧回调不会兑换 token。
- 所有平台在兑换授权码前还会验证回调地址和 `iss`。服务端声明返回 issuer 时，缺少 `iss` 也会被拒绝。

Android 由独立的 `OAuthAuthorizationActivity` 接收浏览器结果，支持 Auth Tab 的浏览器使用 Auth Tab，其余 Custom Tabs 浏览器使用标准 Custom Tabs。先尝试绑定浏览器服务并创建 session，让支持 `KEEP_ALIVE` 的前台浏览器绑定 Kelivo 的服务，维持本地 HTTP 监听器运行。绑定失败、被拒绝、返回空 session 或等待超过 1 秒时，仍直接打开授权页；绑定结果迟到不会重复打开。无法建立 session 的浏览器不保证本地 HTTP 回调保活，本地回调地址通常应留空使用默认应用回调。

绑定跨授权窗口的配置重建保留，并在完成或取消时释放；浏览器服务连接中断本身不取消已经打开的授权页。Flutter 主 Activity 的销毁、授权窗口的配置重建不代表用户取消。用户返回关闭授权窗口时会释放会话，下一次登录可以立即开始。Custom Tabs 的有效回调通过标准 `startActivity` 唤回现有 `singleTask` 主界面；不使用会与该启动模式冲突的 `AppTask.startActivity`。进程死亡后不恢复内存里的 PKCE 会话；孤立回调被拒绝，重新打开应用后可以重新登录。

## 排查

登录时显示发现、注册、等待浏览器、交换 token 和连接阶段，用户可取消。取消不会显示为连接错误，授权失败后仍保留登录入口。详情中的 OAuth 错误包含阶段；资源不匹配时还包含去掉查询参数的端点、元数据位置和资源地址。

- **discovery**：检查 `WWW-Authenticate`、PRM `resource` / `authorization_servers`、授权服务器 `issuer` 和 PKCE S256 声明。
- **registration**：检查客户端注册方式、issuer 绑定、CIMD 能力、回调地址和服务端注册错误。
- **browser**：检查浏览器是否返回应用、state / issuer 验证是否失败、用户是否关闭浏览器或系统是否结束应用进程。
- **token**：检查服务端返回的 OAuth 错误与 HTTP 状态。动态客户端的 `invalid_client` 会使下一次登录重新注册。
- **connecting**：OAuth 可能已完成，但 MCP 初始化或工具列表请求失败；保留 token 以便重连。

报告问题时提供阶段、完整的脱敏错误、系统与浏览器版本。不要提交授权码、state、token、Client secret 或含敏感查询参数的完整授权 URL。

## 验证

```sh
dart analyze --fatal-infos lib test
flutter test --no-pub
cd android
./gradlew :app:testDebugUnitTest --tests 'com.psyche.kelivo.OAuth*Test' -x fetchProot -x compileFlutterBuildDebug
```

回归覆盖根资源发现（含 #1141 的 Swiggy / Zepto 形状）、显式根路径与跨主机元数据位置、自动构造地址的资源身份校验、资源边界、错误回调、取消竞争、注册持久化、CIMD、移动端/桌面配置，以及 Android Activity 重建、关闭授权窗口和有效回调唤回主界面。浏览器回归还覆盖 Custom Tabs / Auth Tab 的实际 session token、保活服务 Intent、绑定与 session 创建被拒绝、绑定超时和迟到连接、空绑定、连接中断，以及绑定期间取消和窗口重建。原生测试使用 Robolectric；这些测试不代替 Android 真机与 Notion、Swiggy、Zepto 账号的完整登录验收。#1132 视频中的失败位置仍需真机日志确认。

2026-10-03 使用实际 `McpOAuthService` 验证了 Swiggy `/im`、Zepto `/mcp` 和 Notion `/mcp` 的公开元数据发现。前两者正确解析为根资源，Notion 保留 `/mcp` 资源。该检查覆盖公开元数据获取及校验；账号授权、token 交换和真机回调仍需使用实际账号验收。

2026-10-05 在独立 Android 36.1 arm64 模拟器、Chrome 134.0.6998.135 上使用 release APK 和真实 Notion 账号完成授权。旧包在有效回调后通过 `AppTask.startActivity` 启动 `singleTask` 主界面，触发系统异常并崩溃；修复包自动返回 Kelivo，显示 Connected 和 Tools 45/45，复测日志无该异常。浏览器服务拒绝绑定的情形由 Robolectric API 28、35 回归覆盖。Chrome Auth Tab 路径由原生单元测试覆盖，本次模拟器实际走的是 Custom Tabs。

同日在 Android 11 / MIUI 13、Via 7.1.0 的测试真机上完成对照。手机原装 APK 的 SHA-256 以 `5b11b5f4` 开头，与旧包完全一致，仍会报 `Could not connect to the browser`。通过 ADB 覆盖安装 SHA-256 以 `3aa02fda` 开头的修复包，保留原数据和默认 Via 浏览器；允许 MIUI 的跨应用打开提示后，真实 Notion 账号登录、授权、回跳和工具加载均成功，最终显示已连接、工具 45/45，复测日志无崩溃或旧浏览器连接错误。两份 APK 均显示 1.3.0（2079），识别测试包时应核对文件名或指纹。

随后恢复可选 browser session，保留拒绝绑定时直接打开的行为。Robolectric API 28、35 共 62 项 OAuth 检查、30 项 Flutter 回调和发现检查、静态分析通过。Android 16 / API 36 模拟器、Chrome 134 上对照了两个 release APK：无 session 的 `b62d12bb` 包没有 `OAuthBrowserService` 绑定；修复后的 `f5a60019` 包出现 Chrome 到该服务的实际绑定。Chrome 授权页保持前台时，约 47 秒内 4 次错误 state 的 HTTP 回调探测均及时返回预期 400，Kelivo 保持非 cached 状态。取消后 HTTP 监听关闭、双向服务绑定释放，再次授权可正常打开 Chrome。这轮未复现旧包冻结卡住，也未重新完成真实账号授权；Via 真机未连接，失败降级由原生回归覆盖。

## 依据

- [MCP 授权规范](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization)、[发现](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/authorization-server-discovery)、[客户端注册](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/client-registration)
- [RFC 9728](https://www.rfc-editor.org/rfc/rfc9728.html)、[RFC 8252](https://www.rfc-editor.org/rfc/rfc8252.html)
- [Android Auth Tab](https://developer.chrome.com/docs/android/custom-tabs/guide-auth-tab)
- [MCP TypeScript SDK 资源边界校验](https://github.com/modelcontextprotocol/typescript-sdk/blob/8aabbdcef6e016978a3132045281dfbd51c69792/packages/core-internal/src/shared/authUtils.ts)、[Cherry Studio 注册存储](https://github.com/CherryHQ/cherry-studio/blob/de623b0cc3d7912f5869e9cd860d26294c7c9270/src/main/ai/mcp/oauth/storage.ts)
