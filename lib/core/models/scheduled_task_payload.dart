/// Private output of a scheduled run. Never enters chat context until published.
class ScheduledTaskPayload {
  const ScheduledTaskPayload({
    required this.text,
    required this.title,
    required this.conversationId,
    required this.messageId,
    required this.contextRevision,
    required this.providerId,
    required this.modelId,
    this.totalTokens,
  });
  final String text,
      title,
      conversationId,
      messageId,
      contextRevision,
      providerId,
      modelId;
  final int? totalTokens;

  Map<String, dynamic> toJson() => {
    'text': text,
    'title': title,
    'conversationId': conversationId,
    'messageId': messageId,
    'contextRevision': contextRevision,
    'providerId': providerId,
    'modelId': modelId,
    'totalTokens': totalTokens,
  };

  factory ScheduledTaskPayload.fromJson(Map<String, dynamic> json) =>
      ScheduledTaskPayload(
        text: json['text'] as String,
        title: json['title'] as String,
        conversationId: json['conversationId'] as String,
        messageId: json['messageId'] as String,
        contextRevision: json['contextRevision'] as String,
        providerId: json['providerId'] as String,
        modelId: json['modelId'] as String,
        totalTokens: json['totalTokens'] as int?,
      );
}
