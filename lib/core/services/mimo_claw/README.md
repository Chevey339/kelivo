# MiMo Claw Integration for Kelivo

将小米 MiMo Claw 的完整 Agent 能力接入 Kelivo。

## 架构

```
Kelivo App
  └── MiMoClawProvider
        ├── MiMoClawAuth (小米 SSO 登录)
        │     ├── getLoginUrl() → WebView 登录
        │     ├── extractPhFromCookies() → 提取 ph
        │     ├── validateCookies() → 验证登录态
        │     └── getUserInfo() → 获取用户信息
        │
        └── MiMoClawGateway (WebSocket JSON-RPC)
              ├── connect() → ticket + WS 握手
              ├── sendChatMessage() → 聊天
              ├── abortChat() → 中止
              ├── setSessionModel() → 切换模型
              ├── getChatHistory() → 历史消息
              └── events → 流式事件推送
                    ├── AgentEvent → 流式文本
                    ├── ChatEvent → 增量/最终
                    ├── ToolEvent → 工具调用
                    ├── SessionMessageEvent → 完整消息
                    └── SessionListEvent → 会话列表
```

## 使用流程

```dart
final provider = MiMoClawProvider();

// 1. 获取登录 URL（在 WebView 中加载）
final loginUrl = provider.getLoginUrl();

// 2. 用户登录后，从 WebView 获取 Cookie
final cookies = 'xiaomichatbot_ph=xxx; ...';

// 3. 完成登录（自动连接 Gateway）
final success = await provider.completeLogin(cookies);

// 4. 监听事件
provider.events.listen((event) {
  if (event is AgentEvent) {
    print('Agent: ${event.delta}');
  } else if (event is ToolEvent) {
    print('Tool: ${event.name} - ${event.status}');
  }
});

// 5. 发送消息
await provider.sendMessage('帮我写一个 Hello World');

// 6. 监听连接状态
provider.connectionStateStream.listen((state) {
  print('连接状态: $state');
});
```

## 协议说明

MiMo Claw 使用 OpenClaw JSON-RPC over WebSocket 协议：

1. **认证**: 小米账号 SSO → Cookie (ph) → WS ticket
2. **连接**: WebSocket + JSON-RPC 握手
3. **通信**: 
   - 请求: `{ type: "req", id, method, params }`
   - 响应: `{ type: "res", id, ok, payload }`
   - 事件: `{ type: "event", event, payload }`

## 文件结构

```
lib/core/services/mimo_claw/
  ├── auth.dart        # 小米 SSO 登录服务
  ├── gateway.dart     # WebSocket Gateway 客户端
  ├── provider.dart    # Provider 集成入口
  └── README.md        # 本文档
```
