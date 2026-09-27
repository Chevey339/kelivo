import '../../../models/message_part.dart';
import '../../../models/token_usage.dart';

/// One-shot (non-stream) generation result.
///
/// [parts] are already complete and renderable — image URIs must be full
/// `data:` / `http(s):` / `file:` / `kelivo-file:` URLs at the parse source,
/// never raw base64 that a later merge step would prefix.
final class TextGenerationResult {
  const TextGenerationResult({
    required this.parts,
    this.usage,
    this.totalUsage,
    this.finishReason,
    this.reasoningDetails,
  });

  final List<MessagePart> parts;

  /// Latest request, used for context accounting and the default token footer.
  final TokenUsage? usage;

  /// All requests that contributed to this generation, including tool rounds.
  final TokenUsage? totalUsage;
  final String? finishReason;
  final dynamic reasoningDetails;

  String get text => [
    for (final part in parts)
      if (part is TextPart && part.text.isNotEmpty) part.text,
  ].join();
}
