import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/quote_ref.dart';
import 'package:Kelivo/features/chat/widgets/quote_interaction_scope.dart';
import 'package:Kelivo/features/chat/widgets/quote_source_highlight.dart';
import 'package:Kelivo/utils/source_text_map.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart' show SourceSpan;

class _TrackedMessage extends ChatMessage {
  _TrackedMessage(String body)
    : super(
        id: 'source',
        conversationId: 'chat',
        role: 'assistant',
        content: body,
      );

  int contentReads = 0;

  @override
  String get content {
    contentReads++;
    return super.content;
  }
}

QuoteRef _quote(int start, int end, {String messageId = 'source'}) => QuoteRef(
  id: '$messageId:$start:$end',
  messageId: messageId,
  start: start,
  end: end,
  text: 'quoted source',
  model: null,
  createdAt: DateTime(2026),
);

Future<List<(int, int)>> _project(
  WidgetTester tester,
  ChatMessage message,
  String source, {
  List<QuoteRef>? quotes,
  int? sourceOffset,
  SourceTextMap? sourceMap,
}) async {
  late List<SourceSpan> result;
  Widget child = Builder(
    builder: (context) {
      result = quoteSourceHighlights(
        context,
        message,
        source,
        sourceOffset: sourceOffset,
        sourceMap: sourceMap,
      );
      return const SizedBox.shrink();
    },
  );
  if (quotes != null) {
    final controller = QuoteInteractionController(
      onQuote: (_) async {},
      onJump: (_) async => true,
      sourceExists: (_) async => true,
    )..setDraftQuotes(quotes);
    addTearDown(controller.dispose);
    child = QuoteInteractionScope(controller: controller, child: child);
  }
  await tester.pumpWidget(child);
  return [for (final range in result) (range.start, range.end)];
}

void main() {
  for (final scoped in [false, true]) {
    testWidgets(
      'no matching highlights skip the message body (scope: $scoped)',
      (tester) async {
        final message = _TrackedMessage('before visible after');
        final result = await _project(
          tester,
          message,
          'visible',
          quotes: scoped ? [_quote(0, 5, messageId: 'another-message')] : null,
        );
        expect(result, isEmpty);
        expect(message.contentReads, 0);
      },
    );
  }

  testWidgets('source maps highlight transformed text without a body read', (
    tester,
  ) async {
    final message = _TrackedMessage('The display text was transformed.');
    final result = await _project(
      tester,
      message,
      'shown',
      quotes: [_quote(42, 45), _quote(60, 65)],
      sourceMap: SourceTextMap.replacement(5, const SourceSpan(40, 50)),
    );
    expect(result, [(0, 5)]);
    expect(message.contentReads, 0);
  });

  testWidgets('unmapped highlights search the body and clip to the block', (
    tester,
  ) async {
    final message = _TrackedMessage('before word after');
    final result = await _project(
      tester,
      message,
      'word',
      quotes: [_quote(5, 9), _quote(10, 15), _quote(0, 3)],
    );
    expect(result, [(0, 2), (3, 4)]);
    expect(message.contentReads, 1);
  });

  testWidgets(
    'explicit offsets distinguish repeated text without a body read',
    (tester) async {
      final message = _TrackedMessage('same | same');
      final result = await _project(
        tester,
        message,
        'same',
        quotes: [_quote(0, 4), _quote(7, 11)],
        sourceOffset: 7,
      );
      expect(result, [(0, 4)]);
      expect(message.contentReads, 0);
    },
  );

  testWidgets('unmapped missing display text has no highlight', (tester) async {
    final message = _TrackedMessage('original');
    final result = await _project(
      tester,
      message,
      'missing',
      quotes: [_quote(0, 5)],
    );
    expect(result, isEmpty);
    expect(message.contentReads, 1);
  });
}
