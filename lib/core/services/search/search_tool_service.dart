import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'search_service.dart';
import '../../providers/settings_provider.dart';

class SearchToolService {
  static const String toolName = 'search_web';
  static const String toolDescription =
      'Search the web for real-time or up-to-date information via the user\'s configured search engine. Returns results with title, URL, snippet, "index" (1-based rank) and "id" (6-char citation id). An optional "answer" summary may be included. See the system prompt for when to use this tool and how to format inline citations.';

  static final RegExp _schemeRe = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:');

  static String _normalizeUrl(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return u;

    // Strip surrounding quotes if the backend returns a JSON-ish value.
    if ((u.startsWith('"') && u.endsWith('"')) ||
        (u.startsWith("'") && u.endsWith("'"))) {
      u = u.substring(1, u.length - 1).trim();
    }
    if (u.isEmpty) return u;

    // Protocol-relative URL (e.g. //example.com/path)
    if (u.startsWith('//')) return 'https:$u';

    // No scheme => default to https.
    if (!_schemeRe.hasMatch(u)) return 'https://$u';
    return u;
  }

  static Map<String, dynamic> getToolDefinition() {
    return {
      'type': 'function',
      'function': {
        'name': toolName,
        'description': toolDescription,
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'The search query to look up online',
            },
          },
          'required': ['query'],
        },
      },
    };
  }

  static Future<String> executeSearch(
    String query,
    SettingsProvider settings,
  ) async {
    try {
      // Get selected search service
      final services = settings.searchServices;
      if (services.isEmpty) {
        return jsonEncode({'error': 'No search services configured'});
      }

      final selectedIndex = settings.searchServiceSelected.clamp(
        0,
        services.length - 1,
      );
      final service = SearchService.getService(services[selectedIndex]);

      // Execute search
      final result = await service.search(
        query: query,
        commonOptions: settings.searchCommonOptions,
        serviceOptions: services[selectedIndex],
      );

      // Add unique IDs to each result item
      final itemsWithIds = result.items.asMap().entries.map((entry) {
        final item = entry.value;
        return SearchResultItem(
          title: item.title,
          url: _normalizeUrl(item.url),
          text: item.text,
          id: const Uuid().v4().substring(0, 6),
          index: entry.key + 1,
        );
      }).toList();

      // Return formatted result
      return jsonEncode({
        if (result.answer != null) 'answer': result.answer,
        'items': itemsWithIds.map((item) => item.toJson()).toList(),
      });
    } catch (e) {
      return jsonEncode({'error': 'Search failed: $e'});
    }
  }

  static String getSystemPrompt() {
    return '''
## search_web 工具使用说明

search_web 是**网络搜索**工具，而非知识检索或文件搜索。**当不确定时，优先搜索，宁搜勿猜。**

### 使用时机（应当搜索）

| 场景 | 示例 |
|------|------|
| 最新新闻、事件、动态 | "今天有什么大新闻？" |
| 实时数据（天气、股价、汇率、体育比分） | "当前比特币价格" |
| 技术文档、API变更、库版本 | "Flutter 3.24 新特性" |
| 产品信息、价格、可用性 | "iPhone 16 多少钱" |
| 查证事实、验证引用 | "确认这个统计数据是否正确" |
| 用户的明确搜索请求 | "帮我搜一下..." |
| 超出训练时间范围的内容 | 任何涉及近期的信息 |

### 不应搜索的场景

| 场景 | 原因 |
|------|------|
| 用户询问主观意见 | "哪部电影更好看" 依赖个人判断 |
| 简单推理或计算 | "3.14 * 7.5 等于多少" |
| 通用常识 | "法国首都是哪里" |
| 关于你自己（你是谁、能力范围等） | 内置知识 |
| 用户个人信息或对话历史中的信息 | 应从对话上下文或记忆中获取 |
| 用户明确要求不要搜索 | 尊重用户意图 |

### 引用格式

- 搜索结果中每个条目带 `index`（序号）和 `id`（唯一标识符），引用格式为：
  `具体的引用内容 [citation](index:id)`
- **引用必须紧跟在相关事实之后**，在标点符号后面，不得延后到回复结尾
- 不得将所有引用集中在回答末尾

### 回答规范

- 使用搜索结果回答时，**不要逐条罗列结果标题和链接**，应组织成自然流畅的段落。
- 在段落叙述中，在每个事实后直接插入对应的引用标记。
- 如果搜索结果的 `answer` 字段（AI摘要）已包含完整回答，可以直接利用该摘要并补充引用。
- ✅ 正确示例：
  - 据最新报道，该事件发生在昨天下午。[citation](1:a1b2c3)
  - 技术文档显示该功能需要版本3.0以上。[citation](2:d4e5f6) 具体配置步骤如下...[citation](3:g7h8i9)
- ❌ 错误示例：
  - 据最新报道，该事件发生在昨天下午。技术文档显示该功能需要版本3.0以上。
    [citation](1:a1b2c3) [citation](2:d4e5f6)
  - 搜索结果如下：第一条...第二条......（逐条罗列是低质量回答）

### 搜索技巧

- 搜索 query 应使用自然语言关键词，而不是完整问句
- 如果第一次搜索没有找到相关信息，尝试换用不同的关键词重新搜索
- 对于需要精确信息的查询（如版本号、API参数），使用精确搜索词
''';
  }
}
