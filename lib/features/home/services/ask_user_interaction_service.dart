import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

class AskUserToolNames {
  const AskUserToolNames._();

  static const String askUser = 'ask_user_input_v0';
}

enum AskUserQuestionKind { single, multi }

class AskUserInvalidRequestException implements Exception {
  const AskUserInvalidRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AskUserQuestion {
  const AskUserQuestion({
    required this.id,
    required this.question,
    required this.kind,
    this.options = const <String>[],
  });

  final String id;
  final String question;
  final AskUserQuestionKind kind;
  final List<String> options;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'question': question,
      'type': kind.name,
      if (options.isNotEmpty) 'options': options,
    };
  }
}

class AskUserAnswerValue {
  const AskUserAnswerValue._({
    required this.kind,
    required this.value,
    required this.custom,
    this.skipped = false,
  });

  const AskUserAnswerValue.single({required String value, required bool custom})
    : this._(kind: AskUserQuestionKind.single, value: value, custom: custom);

  const AskUserAnswerValue.multi({
    required List<String> value,
    required bool custom,
  }) : this._(kind: AskUserQuestionKind.multi, value: value, custom: custom);

  const AskUserAnswerValue.skipped({required AskUserQuestionKind kind})
    : this._(kind: kind, value: '', custom: false, skipped: true);

  final AskUserQuestionKind kind;
  final Object value;
  final bool custom;
  final bool skipped;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': kind.name,
      'value': value,
      'custom': custom,
      'skipped': skipped,
    };
  }
}

class AskUserResult {
  const AskUserResult.answer(this.answers)
    : error = null,
      message = null,
      tool = AskUserToolNames.askUser;
  const AskUserResult.error({
    required this.error,
    required this.message,
    this.tool = AskUserToolNames.askUser,
  }) : answers = const <String, AskUserAnswerValue>{};

  final Map<String, AskUserAnswerValue> answers;
  final String? error;
  final String? message;
  final String tool;

  String toJsonString() {
    if (error != null) {
      return jsonEncode(<String, dynamic>{
        'type': 'tool_error',
        'error': error,
        'message': message ?? '',
        'tool': tool,
      });
    }

    return jsonEncode(<String, dynamic>{
      'type': 'ask_user_answer',
      'answers': answers.map(
        (key, value) => MapEntry<String, dynamic>(key, value.toJson()),
      ),
    });
  }
}

class AskUserRequest {
  AskUserRequest({
    required this.toolCallId,
    required this.questions,
    required Completer<AskUserResult> completer,
  }) : _completer = completer;

  final String toolCallId;
  final List<AskUserQuestion> questions;
  final Completer<AskUserResult> _completer;
}

class AskUserInteractionService extends ChangeNotifier {
  final Map<String, AskUserRequest> _pending = <String, AskUserRequest>{};

  Map<String, AskUserRequest> get pendingRequests => Map.unmodifiable(_pending);

  bool isPending(String toolCallId) => _pending.containsKey(toolCallId);

  Future<AskUserResult> requestAnswer({
    required String toolCallId,
    required Map<String, dynamic> arguments,
  }) {
    final questions = normalizeQuestions(arguments);
    if (questions.isEmpty) {
      throw const AskUserInvalidRequestException(
        'questions must contain at least one question',
      );
    }

    final completer = Completer<AskUserResult>();
    final key = toolCallId.trim().isEmpty
        ? 'ask_user_input_v0_${DateTime.now().microsecondsSinceEpoch}'
        : toolCallId.trim();
    _pending[key] = AskUserRequest(
      toolCallId: key,
      questions: questions,
      completer: completer,
    );
    notifyListeners();
    return completer.future;
  }

  void answer(String toolCallId, Map<String, AskUserAnswerValue> answers) {
    final request = _pending.remove(toolCallId);
    if (request != null && !request._completer.isCompleted) {
      request._completer.complete(AskUserResult.answer(answers));
    }
    notifyListeners();
  }

  void cancelAll() {
    for (final request in _pending.values) {
      if (!request._completer.isCompleted) {
        request._completer.complete(
          const AskUserResult.error(
            error: 'cancelled',
            message: 'Ask user request was cancelled.',
          ),
        );
      }
    }
    _pending.clear();
    notifyListeners();
  }

  static List<AskUserQuestion> normalizeQuestions(
    Map<String, dynamic> arguments,
  ) {
    final rawQuestions = arguments['questions'];
    if (rawQuestions is! List) return const <AskUserQuestion>[];

    final usedIds = <String>{};
    final questions = <AskUserQuestion>[];
    for (final raw in rawQuestions.take(4)) {
      if (raw is! Map) continue;
      final map = raw.cast<String, dynamic>();
      final question = (map['question'] ?? '').toString().trim();
      if (question.isEmpty) continue;

      var id = (map['id'] ?? '').toString().trim();
      if (id.isEmpty || usedIds.contains(id)) {
        id = 'q${questions.length + 1}';
      }
      while (usedIds.contains(id)) {
        id = 'q${questions.length + 1}_${usedIds.length + 1}';
      }
      usedIds.add(id);

      final options = _normalizeOptions(map['options']);
      var kind = _kindFromString((map['type'] ?? '').toString());

      questions.add(
        AskUserQuestion(
          id: id,
          question: question,
          kind: kind,
          options: options,
        ),
      );
    }
    return questions;
  }

  static AskUserQuestionKind _kindFromString(String value) {
    return switch (value.trim().toLowerCase()) {
      'multi' => AskUserQuestionKind.multi,
      _ => AskUserQuestionKind.single,
    };
  }

  static List<String> _normalizeOptions(dynamic rawOptions) {
    if (rawOptions is! List) return const <String>[];
    final out = <String>[];
    for (final raw in rawOptions) {
      final text = raw.toString().trim();
      if (text.isEmpty || out.contains(text)) continue;
      out.add(text);
      if (out.length == 4) break;
    }
    return out;
  }
}
