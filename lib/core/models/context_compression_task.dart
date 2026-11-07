import 'compress_context_options.dart';
import 'context_operation.dart';
import 'compression_config.dart';
import 'token_usage.dart';
import 'native_compaction.dart';
import '../services/api/generation/text_generation_result.dart';
import '../services/chat/compression_templates.dart';

typedef CompressionRequestPreview = ({
  String prompt,
  int estimatedRequests,
  int maxRequestAttempts,
});

typedef CompressionBudget = ({int usedTokens, int? contextWindow});

enum CompressionPhase {
  waiting,
  preparing,
  summarizing,
  merging,
  review,
  applying,
  completed,
  failed,
  cancelled,
  interrupted,
}

typedef CompressionGenerate =
    Future<TextGenerationResult> Function(
      String prompt,
      String requestId,
      int maxTokens,
      void Function(TokenUsage) onUsage,
    );

/// Configuration is resolved before dispatch; no page/BuildContext is retained.
class CompressionRequest {
  const CompressionRequest({
    required this.options,
    required this.model,
    this.generate,
    this.compactNative,
    required this.quoteMarker,
    this.contextWindowTokens,
    this.maxOutputTokens,
    this.config = const CompressionConfig(),
    this.template,
    this.locale = 'en',
    this.loadReference,
    this.loadContinuation,
    this.continuation = '',
    this.beforeMessageId,
    this.effectiveMessageIds,
    this.isCancelled,
    this.automatic = false,
    this.ownsContinuation = false,
    this.acceptCandidate,
  }) : assert((generate == null) != (compactNative == null));
  final CompressContextOptions options;
  final String model;
  final String Function(int) quoteMarker;
  final int? contextWindowTokens;
  final CompressionGenerate? generate;
  final Future<NativeCompactionPayload> Function(
    CompressionSelection selection,
    String requestId,
  )?
  compactNative;
  final int? maxOutputTokens;
  final CompressionConfig config;
  final CompressionTemplate? template;
  CompressionTemplate get resolvedTemplate =>
      template ?? builtInCompressionTemplatesForLocale(locale).first;
  final String locale;
  final Future<String> Function(CompressionSelection)? loadReference;
  final String continuation;
  final Future<String> Function(CompressionSelection)? loadContinuation;

  /// An in-turn caller protects this message and everything after it.
  final String? beforeMessageId;

  /// Automatic compaction can only read history present in its live request.
  final Set<String>? effectiveMessageIds;
  final bool Function()? isCancelled;
  final bool automatic;
  final bool ownsContinuation;
  final Future<bool> Function(ContextOperation)? acceptCandidate;
}

class ContextCompressionTask {
  ContextCompressionTask({
    required this.id,
    required this.conversationId,
    required this.options,
    this.request,
    this.phase = CompressionPhase.waiting,
  });
  final String id;
  final String conversationId;
  final CompressContextOptions options;
  CompressionRequest? request;
  CompressionPhase phase;
  DateTime startedAt = DateTime.now();
  String? anchorGroupId;
  CompressionBudget? previousBudget;
  int completedParts = 0;
  int totalParts = 0;
  String? error;
  String summary = '';
  String? resultConversationId;
  ContextOperation? candidate;
  String? sourceFingerprint;
  CompressionBudget? budget;
  int requestAttempts = 0;
  int unknownUsageAttempts = 0;
  TokenUsage? usage;
  final List<String?> finishReasons = [];
  String? referenceFingerprint;
  Map<String, dynamic>? templateSnapshot;
  Map<String, dynamic>? settingsSnapshot;
  bool automatic = false;
  bool ownsContinuation = false;
  bool cancelRequested = false;
  Future<void> Function()? validateReferences;
  String? protectedMessageId;
  Set<String>? effectiveMessageIds;
  DateTime? completedAt;
  bool get active => switch (phase) {
    CompressionPhase.waiting ||
    CompressionPhase.preparing ||
    CompressionPhase.summarizing ||
    CompressionPhase.merging ||
    CompressionPhase.review ||
    CompressionPhase.applying => true,
    _ => false,
  };
  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'options': options.toJson(),
    'phase': phase.name,
    'summary': summary,
    'candidate': candidate?.toJson(),
    'error': error,
    'resultConversationId': resultConversationId,
    'startedAt': startedAt.toIso8601String(),
    'anchorGroupId': anchorGroupId,
    'requestAttempts': requestAttempts,
    'unknownUsageAttempts': unknownUsageAttempts,
    'usage': usage?.toJson(),
    'finishReasons': finishReasons,
    'referenceFingerprint': referenceFingerprint,
    'template': templateSnapshot,
    'settings': settingsSnapshot,
    'automatic': automatic,
    'ownsContinuation': ownsContinuation,
    'protectedMessageId': protectedMessageId,
    'effectiveMessageIds': effectiveMessageIds?.toList(),
    'sourceFingerprint': sourceFingerprint,
    'completedParts': completedParts,
    'totalParts': totalParts,
    'completedAt': completedAt?.toIso8601String(),
  };
}
