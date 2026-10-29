import 'package:flutter/foundation.dart';

/// Captured before a menu or input focus change can collapse the selection.
/// Offsets are UTF-16 source offsets in the selected message revision.
@immutable
class SelectionSnapshot {
  const SelectionSnapshot({
    required this.messageId,
    required this.role,
    required this.start,
    required this.end,
    required this.text,
    required this.markdown,
  });
  final String messageId;
  final String role;
  final int start;
  final int end;
  final String text;
  final String markdown;
}
