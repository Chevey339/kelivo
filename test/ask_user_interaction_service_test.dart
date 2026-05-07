import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';

void main() {
  group('AskUserInteractionService', () {
    test(
      'normalizes questions and completes with structured answers',
      () async {
        final service = AskUserInteractionService();
        final future = service.requestAnswer(
          toolCallId: 'call_1',
          arguments: const {
            'questions': [
              {
                'id': 'scope',
                'question': 'Choose scope?',
                'type': 'single',
                'options': ['Minimal', 'Complete'],
              },
              {
                'id': 'scope',
                'question': 'Add what?',
                'type': 'multi',
                'options': ['UI', 'Tests', ''],
              },
              {'question': 'Fallback choice?', 'type': 'unknown'},
            ],
          },
        );

        expect(service.pendingRequests.keys, contains('call_1'));
        final request = service.pendingRequests['call_1']!;
        expect(request.questions.map((question) => question.id), const [
          'scope',
          'q2',
          'q3',
        ]);
        expect(request.questions[0].kind, AskUserQuestionKind.single);
        expect(request.questions[1].kind, AskUserQuestionKind.multi);
        expect(request.questions[1].options, const ['UI', 'Tests']);
        expect(request.questions[2].kind, AskUserQuestionKind.single);

        service.answer('call_1', {
          'scope': const AskUserAnswerValue.single(
            value: 'Complete',
            custom: false,
          ),
          'q2': const AskUserAnswerValue.multi(
            value: ['UI', 'Tests'],
            custom: false,
          ),
          'q3': const AskUserAnswerValue.skipped(
            kind: AskUserQuestionKind.single,
          ),
        });

        final result = await future;
        expect(service.pendingRequests, isEmpty);
        final payload =
            jsonDecode(result.toJsonString()) as Map<String, dynamic>;
        expect(payload['type'], 'ask_user_answer');
        expect(payload['answers']['scope']['value'], 'Complete');
        expect(payload['answers']['q2']['value'], const ['UI', 'Tests']);
        expect(payload['answers']['q3']['skipped'], isTrue);
      },
    );

    test('throws for empty questions before creating pending request', () {
      final service = AskUserInteractionService();

      expect(
        () => service.requestAnswer(
          toolCallId: 'call_1',
          arguments: const {'questions': []},
        ),
        throwsA(isA<AskUserInvalidRequestException>()),
      );
      expect(service.pendingRequests, isEmpty);
    });

    test(
      'cancelAll completes pending requests with cancelled result',
      () async {
        final service = AskUserInteractionService();
        final future = service.requestAnswer(
          toolCallId: 'call_1',
          arguments: const {
            'questions': [
              {'id': 'notes', 'question': 'Any notes?', 'type': 'single'},
            ],
          },
        );

        service.cancelAll();

        final result = await future.timeout(const Duration(seconds: 1));
        expect(service.pendingRequests, isEmpty);
        final payload =
            jsonDecode(result.toJsonString()) as Map<String, dynamic>;
        expect(payload['type'], 'tool_error');
        expect(payload['error'], 'cancelled');
        expect(payload['tool'], 'ask_user_input_v0');
      },
    );

    test('keeps choice questions even when options are sparse', () async {
      final service = AskUserInteractionService();
      unawaited(
        service.requestAnswer(
          toolCallId: 'call_1',
          arguments: const {
            'questions': [
              {
                'id': 'scope',
                'question': 'Choose scope?',
                'type': 'single',
                'options': ['Only one'],
              },
            ],
          },
        ),
      );

      expect(
        service.pendingRequests['call_1']!.questions.single.kind,
        AskUserQuestionKind.single,
      );
      service.cancelAll();
    });
  });
}
