class AssistantMemoryDoc {
  final int id; // 0 for new (not used in store), >0 persisted
  final String assistantId;
  final String title;
  final String summary;
  final String content;
  final int updatedAt; // millisecondsSinceEpoch

  const AssistantMemoryDoc({
    required this.id,
    required this.assistantId,
    required this.title,
    required this.summary,
    required this.content,
    required this.updatedAt,
  });

  AssistantMemoryDoc copyWith({
    int? id,
    String? assistantId,
    String? title,
    String? summary,
    String? content,
    int? updatedAt,
  }) => AssistantMemoryDoc(
    id: id ?? this.id,
    assistantId: assistantId ?? this.assistantId,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    content: content ?? this.content,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'assistantId': assistantId,
    'title': title,
    'summary': summary,
    'content': content,
    'updatedAt': updatedAt,
  };

  static AssistantMemoryDoc fromJson(Map<String, dynamic> json) =>
      AssistantMemoryDoc(
        id: (json['id'] as num?)?.toInt() ?? 0,
        assistantId: (json['assistantId'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        summary: (json['summary'] ?? '').toString(),
        content: (json['content'] ?? '').toString(),
        updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      );
}
