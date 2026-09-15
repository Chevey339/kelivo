# 供应商账号登录

入口：设置 → 供应商 → 添加 → 账号登录。支持 ChatGPT（Codex）、Grok、Kimi Code、Claude。账号登录后会同步可用模型，也可以在账号详情手动同步、刷新用量。

## 登录与请求

| 供应商 | 登录方式 | 聊天与模型 | 额度 |
| --- | --- | --- | --- |
| ChatGPT | 浏览器 PKCE；手机和桌面都可选择设备码 | Codex Responses，固定流式请求 | ChatGPT usage 中的主、副及额外限制窗口、可用状态和已存重置次数 |
| Grok | xAI 设备码 | xAI Responses | Grok CLI 周额度或统一计费月额度 |
| Kimi Code | Kimi 设备码 | 根据模型目录声明选择 Messages 或 Chat Completions | Kimi Code 总体用量及各限制窗口 |
| Claude | 浏览器 PKCE，支持粘贴授权码或完整回调链接 | Anthropic Messages，保留签名思考与工具续轮 | 五小时、周用量、各模型周窗口和额外美元用量 |

ChatGPT 默认使用浏览器授权，保留已注册的 `http://localhost:1455/auth/callback`。手机使用系统授权浏览器和临时本机监听；收到匹配的授权回调后，再通过 Kelivo 原生回调返回应用。授权码只在本机接收，返回应用的 URI 不携带授权码。取消、超时或完成后关闭监听，原生授权会话按标识取消，避免旧请求取消其他授权。

Android 使用带会话的 Custom Tabs，优先使用支持它的默认浏览器；未设置默认浏览器或默认浏览器不支持时，从已安装的 Custom Tabs 浏览器中选择。授权时请求浏览器绑定空的 `OAuthBrowserService`，让本机监听在授权窗口打开期间保持运行；该服务不暴露凭证或应用操作。授权结束时解除客户端连接。首次使用浏览器时须先完成浏览器自身的初始化。

供应商列表只显示一个“登录”按钮。“使用设备码登录”放在浏览器授权等待区域，以及浏览器失败或关闭后；切换时先取消并结束旧请求，再启动设备码流程。设备码登录需先在 ChatGPT 个人安全设置或工作区权限中启用，浏览器授权无需该开关，见 [OpenAI 授权说明](https://learn.chatgpt.com/docs/auth)。

账号凭证与 API Key 一样明文保存在供应商配置中，包含在设置备份、导出和恢复中。供应商分享文本也包含凭证；账号凭证通常超过二维码容量，因此这类分享使用文本。退出登录清除本机该供应商的凭证，保留名称、模型和自定义请求配置。

访问令牌到期前会续期，同一账号的并发续期会合并；服务端首次返回 401 时续期并重试一次。网络故障保留原凭证，明确失效才显示重新登录。聊天失败会保留已有回复并保存账号恢复入口；重新登录成功后，由用户点击原消息的重试按钮再次发送。

请求客户端绑定创建时的登录会话，首次发送、续期和 401 重试都校验该会话；退出或更换账号会取消旧请求，不会把旧对话交给新账号。Kimi 的 OpenAI 协议使用目录声明的思考档位和默认值，在 `thinking.type/effort` 中发送；强制思考模型关闭思考时使用最低支持档位。已有 Kimi 账号可点“同步”更新这部分目录信息。

Kimi OpenAI 思考模型根据供应商和模型目录启用 `reasoning_content` 回传，覆盖 `k3` 等短 ID 及模型别名。流式、非流式的工具续轮和历史 assistant 消息都保留返回的思考内容，遵循 [Kimi 上下文回传要求](https://platform.kimi.ai/docs/guide/use-thinking-models)。

手机和桌面保存模型设置时，保留目录同步的协议、思考模式、强制思考标记、支持档位和默认档位；以保存时的最新目录信息为准。旧版本保存设置已丢失这些字段的账号，可在账号详情点“同步”恢复。

## 代码位置

- `lib/core/models/provider_oauth.dart`：账号凭证、用量窗口和错误类型。
- `lib/core/services/auth/provider_oauth_adapter.dart`：各供应商登录、续期、目录和额度协议。
- `lib/core/services/auth/claude_oauth_adapter.dart`、`claude_oauth_request.dart`：Claude OAuth 协议、请求头、工具名称转换和缓存断点。
- `lib/core/services/auth/provider_oauth_service.dart`：凭证持久化、并发续期、请求鉴权和模型同步。
- `lib/core/services/auth/oauth_callback*.dart`、`oauth_pkce.dart`：与 MCP 共用的回调和 PKCE；原生通道为 `app.oauth`。
- `lib/features/provider/`：移动端账号详情和桌面嵌入详情，共用应用的 iOS 风格控件。

协议参考本地 oh-my-pi。设计原型留在仓库外，未复制到本仓库。

ChatGPT 已逐项对照 OMP 的 `registry/oauth/openai-codex.ts`、`catalog/discovery/codex.ts`、`providers/openai-codex/request-transformer.ts` 和 `usage/openai-codex.ts`：

- 使用相同的客户端 ID、授权 scope、PKCE 和令牌端点；设备码先等待最多 5 秒，再按服务端间隔加 3 秒轮询，最多 120 次，令牌请求超时 15 秒。
- 从 access/id token 读取工作区、邮箱和套餐。允许只有邮箱的账号；续期不把用户 `sub` 当工作区 ID。服务端拒绝会保留经过脱敏的原因。
- 模型使用相同的客户端版本，排除隐藏条目；`supported_in_api: false` 不排除订阅模型。
- Responses 清理所有不支持的采样参数，保留加密推理并修复中断的工具调用记录；按令牌声明传递工作区区域和模型路由信息。会话和缓存标识在工具续轮中保持一致。
- 用量按服务端窗口解析，缺失百分比保持未知，百分比限制在 0–100；显式可用状态优先于百分比推断。已存重置次数用详情接口校准，查询不会消耗重置次数。

Kelivo 保留自己的 `originator` / User-Agent 和界面；手机提供浏览器及 OMP 也支持的设备码流程。聊天使用完整 Responses 的 HTTP 流式传输，未引入 OMP 的可选 WebSocket / Responses Lite、CLI 模型别名或自动额度重置功能。

### Claude

实现对照 [OMP 6f2c14b3](https://github.com/can1357/oh-my-pi/tree/6f2c14b3e4cc065139789da893e4f86f3d72958c) 的 `rules/auth/anthropic.kdl`、`registry/oauth/anthropic.ts`、`providers/anthropic.ts`、`providers/claude-code-fingerprint.ts` 和 `usage/claude.ts`。

- 使用相同的客户端 ID、scope、PKCE、JSON 令牌交换和续期请求；默认本机回调为 `http://localhost:54545/callback`，端口占用时使用可用端口。手机共用现有系统授权浏览器与本机回调桥接。也可粘贴授权码、`code#state` 或完整回调链接；带有 state 时必须匹配本次授权。
- 令牌到期前五分钟续期，初次授权的组织信息在续期时保持不变；设备标识随账号凭证持久化。账号配置、TTL、凭证和组织信息一同备份恢复。
- Messages 使用相同的 Bearer 鉴权、Claude Code 版本、beta 请求头、系统前缀、会话归属和工具名前缀；请求校验值用 XXHash64 计算，英文和 Unicode 样例已与 Bun 独立比对。客户端工具名称在返回时还原，签名思考与服务端工具块保持原样。
- 缓存默认开启且 TTL 为 **1 小时**，账号详情可选择 **5 分钟 / 1 小时**，也可关闭。两端复用现有缓存控件，关闭后保留所选 TTL。自动缓存断点遵循 OMP 的系统、工具和历史消息分配，最多四处；关闭时移除自动缓存断点。
- 额度解析兼容旧窗口和新版 `limits` / `spend`；保留 `is_active: false` 的有效窗口，模型专属窗口耗尽不代表整个账号不可用。额外用量按美元展示，无上限时不编造百分比。短暂错误最多请求三次，429 不自动重试，拒绝原因经过脱敏后显示。

HTTP 压缩使用 Dart 原生传输可解码的 gzip，未声明当前传输不能解码的 br/zstd，也未引入 OMP 的 CLI 配置及凭证轮换池。真实 Claude 账号授权、模型权限和额度须按下列步骤人工复测。

## 手动复测

以下真实账号步骤仍需手动执行。自动测试的模拟响应不能证明账号授权或供应商当前服务可用。

1. 分别登录四个供应商；检查取消、关闭页面、等待超时之后能重新发起登录。Claude 同时检查自动回调和手动粘贴授权码。
2. 登录成功后查看账号详情，检查模型同步、额度百分比和重置时间；与供应商账号页核对。缺失额度应显示不可用，不能显示为已用 0%。
3. 在模型选择器中选取同步模型，发送普通消息；再测试包含一次工具调用的对话。ChatGPT 即使关闭流式选项，也按 Codex 要求走流式传输。
4. Kimi Code 测试模型默认、关闭及调整思考预算的行为，并测试目录中实际提供的不同协议模型。
5. 等待令牌到期后继续对话，确认能够续期。撤销授权后再发消息，确认显示重新登录；恢复登录后应等待手动重试，不能自动重复发送。
6. 导出设置备份，在独立测试数据目录恢复；检查账号仍可同步模型和查询用量。令牌若已被供应商撤销，恢复后应允许重新登录。
7. 手机分别检查浏览器授权自动返回、取消后再次登录、长时间授权及切后台的行为，并检查浏览器失败后仍可使用设备码。桌面检查 ChatGPT 浏览器回调；检查明暗主题、账号长名称、长邮箱和窄窗口。
8. MCP 原生回调抽取为共用代码后，分别复测 iOS、Android 的一次 MCP OAuth 授权及取消。
9. Claude 分别设置 5 分钟、1 小时和关闭缓存；发送连续消息及工具续轮，核对输入缓存用量，重开设置确认 TTL 保留。将额外用量与 Claude 账号页核对，包括未开启额外用量和无上限的情况。

## 自动验证入口

```sh
dart format lib test
dart analyze --fatal-infos lib test
flutter test --no-pub --concurrency=2
```

重点覆盖：设备码轮询和取消、令牌轮换、并发续期、退出时仍在进行的请求、设置备份恢复、Codex/Kimi 请求约束、账号页面布局和失效恢复提示。
