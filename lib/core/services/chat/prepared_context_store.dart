import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../utils/token_estimator.dart';
import '../logging/context_log_models.dart';

class ContextPreparationIssue {
  const ContextPreparationIssue(this.source, this.reason);
  final ContextSource source;

  /// A safe diagnostic code, never raw exceptions (paths / secrets).
  final String reason;
}

class PreparedContextSnapshot {
  PreparedContextSnapshot({
    required this.generationId,
    required this.context,
    required List<Map<String, dynamic>> tools,
    List<String> nativeTools = const [],
    List<ContextPreparationIssue> issues = const [],
  }) : nativeTools = List.unmodifiable(nativeTools),
       issues = List.unmodifiable(issues),
       toolNames = List.unmodifiable(
         tools
             .map(
               (tool) => ((tool['function'] as Map?)?['name'] ?? '').toString(),
             )
             .where((name) => name.isNotEmpty),
       ),
       toolTokens = tools.isEmpty ? 0 : estimateTokens(jsonEncode(tools));

  final String generationId;
  final ContextLogSnapshot context;
  final List<String> toolNames;
  final int toolTokens;
  final List<String> nativeTools;
  final List<ContextPreparationIssue> issues;
}

/// Session-only, bounded independently of request logging and chat persistence.
class PreparedContextStore extends ChangeNotifier {
  static const capacity = 8;
  final _snapshots = <String, PreparedContextSnapshot>{};

  PreparedContextSnapshot? forConversation(String? id) => _snapshots[id];

  void record(PreparedContextSnapshot snapshot) {
    final id = snapshot.context.conversationId;
    if (id.isEmpty) return;
    final previous = _snapshots[id];
    if (previous != null &&
        previous.context.timestamp.isAfter(snapshot.context.timestamp)) {
      return;
    }
    _snapshots.remove(id);
    _snapshots[id] = snapshot;
    while (_snapshots.length > capacity) {
      _snapshots.remove(_snapshots.keys.first);
    }
    notifyListeners();
  }

  void remove(String id) {
    if (_snapshots.remove(id) != null) notifyListeners();
  }

  void clear() {
    if (_snapshots.isEmpty) return;
    _snapshots.clear();
    notifyListeners();
  }
}
