/// 时间占位符替换工具。
///
/// 给 AI 一个稳定协议:在 system prompt 没有任何时间变量的前提下,允许 AI
/// 在写入记忆时插入真实时间,从而让 system message 整体保持字节级稳定,
/// 命中 LLM 服务的 prompt cache。
///
/// 占位符(全部小写,两侧各一个花括号):
/// - `{year}`    4 位年份,例如 `2026`
/// - `{month}`   2 位月份(01-12),例如 `07`
/// - `{day}`     2 位日期(01-31),例如 `13`
/// - `{hour}`    2 位小时(00-23,24 小时制),例如 `06`
/// - `{minute}`  2 位分钟(00-59),例如 `33`
/// - `{second}`  2 位秒(00-59),例如 `58`
/// - `{time}`    完整时间(无秒),格式 `{year}/{month}/{day} {hour}:{minute}`
///               例如 `2026/07/13 06:33`
///
/// 替换规则:
/// - 不区分大小写(但推荐小写,大写占位符也照样替换)
/// - 全部替换,不做上下文区分(用户自己注意别在内容里写 `{time}` 字面量)
/// - 替换只发生在工具调用路径,UI 手动编辑不会触发
library;

/// 把 content 中的时间占位符替换为 [now] 指定的实际时间。
///
/// [now] 默认为 [DateTime.now],单测时可以注入固定时间。
String expandMemoryPlaceholders(String content, [DateTime? now]) {
  final t = now ?? DateTime.now();
  final year = t.year.toString();
  final month = t.month.toString().padLeft(2, '0');
  final day = t.day.toString().padLeft(2, '0');
  final hour = t.hour.toString().padLeft(2, '0');
  final minute = t.minute.toString().padLeft(2, '0');
  final second = t.second.toString().padLeft(2, '0');
  final time = '$year/$month/$day $hour:$minute';

  // 按顺序替换,每个 .replaceAll 独立运行,不会重复命中前面替换结果里的字面量
  return content
      .replaceAll('{year}', year)
      .replaceAll('{month}', month)
      .replaceAll('{day}', day)
      .replaceAll('{hour}', hour)
      .replaceAll('{minute}', minute)
      .replaceAll('{second}', second)
      .replaceAll('{time}', time);
}
