import '../../utils/utf16_safe_cut.dart';
import 'context_operation.dart';

/// List data only: no source groups, full summaries or provider payloads.
class ContextOperationSummary {
  const ContextOperationSummary({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.revoked,
    required this.hidden,
    required this.superseded,
    required this.isNative,
    required this.isImportedNative,
    required this.summaryPreview,
  });

  factory ContextOperationSummary.fromOperation(
    ContextOperation operation, {
    required bool hidden,
    required bool superseded,
  }) => ContextOperationSummary(
    id: operation.id,
    kind: operation.kind,
    createdAt: operation.createdAt,
    revoked: operation.revoked,
    hidden: hidden,
    superseded: superseded,
    isNative: operation.isNative,
    isImportedNative: operation.isImportedNative,
    summaryPreview: operation.isNative
        ? ''
        : truncateHeadUtf16Safe(operation.summary, 240),
  );

  final String id;
  final ContextOperationKind kind;
  final DateTime createdAt;
  final bool revoked;
  final bool hidden;
  final bool superseded;
  final bool isNative;
  final bool isImportedNative;
  final String summaryPreview;

  bool get isCompression => kind == ContextOperationKind.compress;
  bool get isFixedStart => kind == ContextOperationKind.start;
}

typedef ContextOperationPage = ({
  List<ContextOperationSummary> items,
  bool hasMore,
  String revision,
});
