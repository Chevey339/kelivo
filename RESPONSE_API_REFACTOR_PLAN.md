# Responses API 工具调用重构计划

## 问题分析

### 当前实现的问题
1. **只处理一次工具调用**: 当前代码在收到第一次响应的工具调用后,执行工具并发送一次follow-up请求,然后就结束了
2. **无法处理多轮工具调用**: 如果follow-up响应中又包含工具调用,代码无法继续处理,导致无限等待或空响应
3. **conversation构建不完整**: 缺少assistant的function_call消息,导致API无法理解上下文

### rikkahub的正确实现方式

#### 核心架构 (GenerationHandler.kt 87-209行)
```kotlin
for (stepIndex in 0 until maxSteps) {  // maxSteps = 256
    // 1. 发送请求,生成响应
    generateInternal(...)
    
    // 2. 检查最后一条消息是否有工具调用
    val toolCalls = messages.last().getToolCalls()
    if (toolCalls.isEmpty()) {
        break  // 没有工具调用,结束循环
    }
    
    // 3. 执行所有工具
    toolCalls.forEach { toolCall ->
        val result = tool.execute(args)
        results += ToolResult(...)
    }
    
    // 4. 将工具结果添加到messages
    messages = messages + UIMessage(
        role = MessageRole.TOOL,
        parts = results
    )
    
    // 5. 继续下一轮循环
}
```

#### buildMessages函数 (ResponseAPI.kt 223-312行)
```kotlin
fun buildMessages(messages: List<UIMessage>) = buildJsonArray {
    messages
        .filter { it.role != MessageRole.SYSTEM }  // 过滤系统消息
        .forEach { message ->
            if (message.role == MessageRole.TOOL) {
                // TOOL消息转换为function_call_output
                message.getToolResults().forEach { result ->
                    add({
                        "type": "function_call_output",
                        "call_id": result.toolCallId,
                        "output": json.encodeToString(result.content)
                    })
                }
                return@forEach
            }
            
            // 添加普通消息
            add({
                "role": message.role.lowercase(),
                "content": message.content
            })
            
            // 如果消息有工具调用,添加function_call
            message.getToolCalls()
                .takeIf { it.isNotEmpty() }
                ?.forEach { toolCall ->
                    add({
                        "type": "function_call",
                        "call_id": toolCall.toolCallId,
                        "name": toolCall.toolName,
                        "arguments": toolCall.arguments
                    })
                }
        }
}
```

## 修改计划

### 阶段1: 重构数据结构
**文件**: `lib/core/services/api/chat_api_service.dart`
**位置**: 1419-1627行 (当前的工具调用处理代码)

**目标**: 将单次follow-up改为循环结构

**步骤**:
1. 在`if (onToolCall != null && toolAccResp.isNotEmpty)`外层添加for循环
2. 创建`currentMessages`变量来跟踪当前的消息列表
3. 提取系统指令到`systemInstructions`变量

### 阶段2: 实现工具调用循环
**核心逻辑**:
```dart
// 初始化
var currentMessages = <Map<String, dynamic>>[];
String systemInstructions = '';

// 提取系统消息和初始消息
for (final m in messages) {
  if (m['role'] == 'system') {
    systemInstructions += m['content'];
  } else {
    currentMessages.add(m);
  }
}

// 工具调用循环 (最多256次)
for (int stepIndex = 0; stepIndex < 256; stepIndex++) {
  // 检查是否有工具调用
  if (toolAccResp.isEmpty) break;
  
  // 1. 执行工具
  final toolCallMsgs = [];
  final toolOutputs = [];
  toolAccResp.forEach((key, m) => {
    // 执行工具,收集结果
  });
  
  // 2. 构建conversation (像rikkahub的buildMessages)
  final conversation = buildConversation(currentMessages, toolCallMsgs, toolOutputs);
  
  // 3. 发送follow-up请求
  final followUpBody = {
    'model': modelId,
    'input': conversation,
    'stream': true,
    'instructions': systemInstructions,
    'reasoning': {'effort': 'high', 'summary': 'detailed'},
  };
  
  // 4. 处理响应,更新toolAccResp
  toolAccResp.clear();
  await for (final chunk in followUpChunks) {
    // 解析事件,如果有新的工具调用,添加到toolAccResp
  }
  
  // 5. 更新currentMessages
  currentMessages.add({
    'role': 'assistant',
    '__toolCalls': toolCallMsgs,
  });
  
  // 6. 继续循环或结束
}
```

### 阶段3: 实现buildConversation函数
**功能**: 根据当前消息列表、工具调用和工具输出,构建Responses API的input数组

**逻辑**:
```dart
List<Map<String, dynamic>> buildConversation(
  List<Map<String, dynamic>> currentMessages,
  List<Map<String, dynamic>> toolCallMsgs,
  List<Map<String, dynamic>> toolOutputs,
) {
  final conversation = <Map<String, dynamic>>[];
  
  // 1. 添加所有历史消息
  for (final m in currentMessages) {
    if (m['role'] == 'system') continue;
    
    // 添加消息内容
    conversation.add({
      'role': m['role'],
      'content': m['content'] ?? '',
    });
    
    // 如果消息有工具调用,添加function_call
    final toolCalls = m['__toolCalls'] as List?;
    if (toolCalls != null) {
      for (final tc in toolCalls) {
        conversation.add({
          'type': 'function_call',
          'call_id': tc['call_id'],
          'name': tc['name'],
          'arguments': tc['arguments'],
        });
      }
    }
    
    // 如果消息有工具结果,添加function_call_output
    final toolResults = m['__toolResults'] as List?;
    if (toolResults != null) {
      conversation.addAll(toolResults);
    }
  }
  
  // 2. 添加当前工具调用
  for (final tc in toolCallMsgs) {
    conversation.add({
      'type': 'function_call',
      'call_id': tc['__callId'],
      'name': tc['__name'],
      'arguments': jsonEncode(tc['__args']),
    });
  }
  
  // 3. 添加工具输出
  conversation.addAll(toolOutputs);
  
  return conversation;
}
```

### 阶段4: 处理follow-up响应中的工具调用
**关键**: 在follow-up响应处理中,需要处理所有事件类型,包括新的工具调用

**事件类型**:
- `response.output_item.added` → 新工具调用开始
- `response.function_call_arguments.delta` → 工具参数增量
- `response.function_call_arguments.done` → 工具参数完成
- `response.output_text.delta` → 文本输出
- `response.reasoning_summary_text.delta` → 推理内容
- `response.completed` → 响应完成

### 阶段5: 更新消息列表
**在每次循环结束时**:
```dart
// 添加assistant消息(包含工具调用)
currentMessages.add({
  'role': 'assistant',
  'content': '',
  '__toolCalls': toolCallMsgs.map((m) => {
    'call_id': m['__callId'],
    'name': m['__name'],
    'arguments': jsonEncode(m['__args']),
  }).toList(),
  '__toolResults': toolOutputs,
});
```

## 具体修改步骤

### ✅ Step 1: 删除现有的单次follow-up代码
- ✅ 删除1465-1617行的代码
- ✅ 保留1419-1463行的工具执行代码

### ✅ Step 2: 添加循环结构
- ✅ 在1419行之前添加循环初始化代码
- ✅ 将工具执行代码移到循环内部

### ✅ Step 3: 实现conversation构建
- ✅ 在循环内部,每次迭代时构建完整的conversation数组
- ✅ 包含历史消息、工具调用、工具结果
- ✅ 实现了类似rikkahub的buildMessages逻辑

### ✅ Step 4: 处理follow-up响应
- ✅ 在循环内部发送follow-up请求
- ✅ 处理所有事件类型(reasoning, output_text, function_call等)
- ✅ 更新toolAccResp以便下次循环检查

### ✅ Step 5: 更新消息列表
- ✅ 每次循环结束时,将工具调用和结果添加到currentMessages
- ✅ 为下次循环做准备

### ✅ Step 6: 循环终止条件
- ✅ 如果toolAccResp为空,说明没有更多工具调用,跳出循环
- ✅ 如果达到最大迭代次数(256),强制结束

## 修改完成状态

**所有步骤已完成!** ✅

修改位置: `lib/core/services/api/chat_api_service.dart` 第1465-1725行

关键改动:
1. 添加了工具调用循环(最多256次迭代)
2. 实现了currentMessages跟踪机制
3. 实现了conversation构建逻辑(包含历史消息、工具调用、工具结果)
4. 在follow-up响应中正确处理所有事件类型,包括新的工具调用
5. 每次循环后更新currentMessages,保持完整的对话历史
6. 正确的循环终止条件

## 预期效果

修改完成后,工具调用流程应该是:
1. 用户发送"杭州最新天气信息"
2. 第一次响应: 深度思考 → 决定调用search_web工具
3. 执行search_web,获取结果
4. 第二次请求: 发送完整conversation(user message + function_call + function_call_output)
5. 第二次响应: 
   - 如果AI决定继续调用工具 → 执行工具,继续循环
   - 如果AI开始回复 → 输出文本,结束循环
6. 最终用户看到基于搜索结果的完整回复

## 关键注意事项

1. **必须在conversation中包含function_call**: 这是告诉API"工具已经被调用过了"的关键
2. **toolAccResp必须在每次循环开始时清空**: 避免重复执行相同的工具
3. **正确处理所有事件类型**: 特别是follow-up响应中的工具调用事件
4. **保持消息历史**: currentMessages必须累积所有的交互历史
5. **日志记录**: 每个关键步骤都要记录日志,方便调试

