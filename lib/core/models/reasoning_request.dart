import 'package:flutter/foundation.dart';

import 'model_spec.dart';

@immutable
class ReasoningRequest {
  final ReasoningLevel level;
  final int? budgetTokens;

  const ReasoningRequest(this.level, {this.budgetTokens});

  static const ReasoningRequest auto = ReasoningRequest(ReasoningLevel.auto);
  static const ReasoningRequest off = ReasoningRequest(ReasoningLevel.off);

  ReasoningRequest copyWith({ReasoningLevel? level, int? budgetTokens}) {
    return ReasoningRequest(
      level ?? this.level,
      budgetTokens: budgetTokens ?? this.budgetTokens,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'level': level.name, 'budgetTokens': budgetTokens};
  }

  factory ReasoningRequest.fromJson(Map json) {
    final rawLevel = json['level']?.toString().trim() ?? '';
    var level = ReasoningLevel.auto;
    for (final value in ReasoningLevel.values) {
      if (value.name == rawLevel) {
        level = value;
        break;
      }
    }
    final rawBudget = json['budgetTokens'];
    final budgetTokens = switch (rawBudget) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()),
      _ => null,
    };
    return ReasoningRequest(level, budgetTokens: budgetTokens);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ReasoningRequest &&
            runtimeType == other.runtimeType &&
            level == other.level &&
            budgetTokens == other.budgetTokens);
  }

  @override
  int get hashCode => Object.hash(level, budgetTokens);
}
