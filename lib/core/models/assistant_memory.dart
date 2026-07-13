class AssistantMemory {
  final int id; // 0 for new (not used in store), >0 persisted
  final String assistantId;
  final String content;

  const AssistantMemory({
    required this.id,
    required this.assistantId,
    required this.content,
  });

  AssistantMemory copyWith({int? id, String? assistantId, String? content}) =>
      AssistantMemory(
        id: id ?? this.id,
        assistantId: assistantId ?? this.assistantId,
        content: content ?? this.content,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'assistantId': assistantId,
    'content': content,
  };

  static AssistantMemory fromJson(Map<String, dynamic> json) => AssistantMemory(
    id: (json['id'] as num?)?.toInt() ?? 0,
    assistantId: (json['assistantId'] ?? '').toString(),
    content: (json['content'] ?? '').toString(),
  );

  /// Build a single XML record, e.g. `<record>\n<id>1</id>\n<content>...</content>\n</record>`.
  static String buildRecordXml(int id, String content) {
    final escaped = content.replaceAll('&', '&amp;').replaceAll('<', '&lt;');
    return '<record>\n<id>$id</id>\n<content>$escaped</content>\n</record>';
  }

  /// Build a full `<memories>` XML block from a list of memories.
  static String buildMemoryXml(List<AssistantMemory> memories) {
    final sb = StringBuffer();
    sb.writeln('<memories>');
    for (final m in memories) {
      sb.writeln(buildRecordXml(m.id, m.content));
    }
    sb.writeln('</memories>');
    return sb.toString();
  }
}
