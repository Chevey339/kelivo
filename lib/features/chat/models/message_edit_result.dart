class MessageEditResult {
  final String content;
  final bool shouldSend;

  /// When true, the edit overwrites the original message content in-place
  /// instead of creating a new version or branch.
  final bool overwrite;

  const MessageEditResult({
    required this.content,
    this.shouldSend = false,
    this.overwrite = false,
  });
}
