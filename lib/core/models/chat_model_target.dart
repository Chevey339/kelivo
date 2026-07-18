import 'dart:convert';

/// One concrete provider/model destination used by chat generation.
final class ChatModelTarget {
  const ChatModelTarget({required this.providerKey, required this.modelId});

  final String providerKey;
  final String modelId;

  String get key => '${base64Url.encode(utf8.encode(providerKey))}.$modelId';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'providerKey': providerKey,
    'modelId': modelId,
  };

  factory ChatModelTarget.fromJson(Map<String, dynamic> json) {
    return ChatModelTarget(
      providerKey: (json['providerKey'] ?? '').toString(),
      modelId: (json['modelId'] ?? '').toString(),
    );
  }

  bool get isValid =>
      providerKey.trim().isNotEmpty && modelId.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatModelTarget &&
          providerKey == other.providerKey &&
          modelId == other.modelId;

  @override
  int get hashCode => Object.hash(providerKey, modelId);

  @override
  String toString() => '$providerKey/$modelId';
}

enum MultiModelSelectionScope {
  assistant,
  conversation,
  nextMessage;

  static MultiModelSelectionScope fromStorage(Object? value) {
    final raw = value?.toString();
    return values.firstWhere(
      (scope) => scope.name == raw,
      orElse: () => MultiModelSelectionScope.conversation,
    );
  }
}
