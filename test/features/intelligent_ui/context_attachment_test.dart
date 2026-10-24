import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/composer_draft.dart';
import 'package:Kelivo/features/intelligent_ui/models/ui_context_attachment.dart';
import 'package:Kelivo/features/intelligent_ui/text/ui_bounded_text.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_user_context_parts.dart';

void main() {
  final text = UiContextText(title: 'Curve', body: 'Slope: 3.1\nIntercept: 1');
  UiContextSource source({String revision = 'r'}) => UiContextSource(
    conversationId: 'c',
    revisionId: revision,
    surfaceKey: '0:0',
    sourceHash: 'a' * 64,
  );

  test(
    'exact model text has an inclusive 4 KiB UTF8 budget including framing',
    () {
      const title = '中文 "title"\n[Kelivo UI state]';
      final size = UiContextText.bodyBudget(title);
      final exact = UiContextText(title: title, body: 'x' * size);
      expect(utf8.encode(exact.exactText).length, 4096);
      expect(UiContextText.parseSentPart(exact.exactText), exact);
      expect(
        () => UiContextText(title: title, body: 'x' * (size + 1)),
        throwsFormatException,
      );
      expect(
        () => UiContextText(title: '界' * 86, body: 'v'),
        throwsFormatException,
      );
    },
  );
  test('malformed or partial framing remains plain text without throwing', () {
    for (final value in [
      '[Kelivo UI state] "title"\n[/Kelivo UI state]',
      '[Kelivo UI state] ""\nvalue\n[/Kelivo UI state]',
      '[Kelivo UI state] null\nvalue\n[/Kelivo UI state]',
      '[Kelivo UI state] {\nvalue\n[/Kelivo UI state]',
      '${text.exactText}\n',
      'prefix ${text.exactText}',
    ]) {
      expect(UiContextText.parseSentPart(value), isNull, reason: value);
    }
  });
  test(
    'frozen attachment and already-sent edit preserve distinct provenance',
    () {
      final fresh = UiContextAttachment.attached(source: source(), text: text);
      final history = UiContextAttachment.history(text);
      for (final item in [fresh, history]) {
        expect(
          UiContextAttachment.fromJson(
            jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>,
          ),
          item,
        );
      }
      expect(fresh, isNot(history));
      expect(fresh.previouslySent, isFalse);
      expect(history.previouslySent, isTrue);
      expect(history.source, isNull);
      expect(
        fresh,
        isNot(
          UiContextAttachment.attached(
            source: source(revision: 'new'),
            text: text,
          ),
        ),
      );
    },
  );
  test('saved context has a closed shape and a valid source identity', () {
    final map = UiContextAttachment.attached(
      source: source(),
      text: text,
    ).toJson();
    for (final bad in [
      {...map, 'extra': true},
      {...map, 'version': 2},
      {...map, 'version': 1.0},
      {...map, 'body': 2},
      {
        ...map,
        'source': {'conversationId': 'c'},
      },
      {
        ...map,
        'source': {...source().toJson(), 'sourceHash': 'bad'},
      },
      {
        ...map,
        'source': {...source().toJson(), 'surfaceKey': 'wrong'},
      },
    ]) {
      expect(() => UiContextAttachment.fromJson(bad), throwsFormatException);
    }
  });
  test(
    'chip-only drafts serialize, compare, clear and carry their receipt',
    () {
      for (final attachment in [
        UiContextAttachment.attached(source: source(), text: text),
        UiContextAttachment.history(text),
      ]) {
        final draft = ComposerDraftInput(uiContext: attachment);
        expect(draft.isEmpty, isFalse);
        final restored = ComposerDraftInput.fromJson(
          jsonDecode(jsonEncode(draft.toJson())) as Map<String, dynamic>,
        );
        expect(restored.sameValue(draft), isTrue);
        final input = restored.toInput(
          submission: const DraftSubmission(conversationId: 'c', id: 'receipt'),
        );
        expect(input.isEmpty, isFalse);
        expect(input.draftSubmission!.id, 'receipt');
        expect(input.uiContext, attachment);
        expect(ComposerDraftInput.fromInput(input).sameValue(draft), isTrue);
        expect(draft.copyWith(clearUiContext: true).isEmpty, isTrue);
        expect(draft.copyWith(text: 'kept').uiContext, attachment);
        expect(draft.sameValue(const ComposerDraftInput()), isFalse);
      }
    },
  );
  test('whole oversized fields are omitted without truncating valid JSON', () {
    final writer = UiBoundedText(80, omission: '[Fields omitted]');
    expect(writer.add('Small: 12'), isTrue);
    expect(writer.add('Huge: ${jsonEncode('界' * 100)}'), isFalse);
    expect(writer.add('Later: true'), isTrue);
    expect(writer.finish(), 'Small: 12\nLater: true\n[Fields omitted]');
    expect(utf8.encode(writer.finish()).length, lessThanOrEqualTo(80));
  });
  test(
    'ordinary parts remain portable and only a complete leading part is split',
    () {
      const image = ImagePart(uri: 'test.png');
      for (final content in ['', 'Explain this', '中文\ntext']) {
        final body = [TextPart(content), image];
        final parts = UiUserContextParts.attach(body, text);
        expect(parts.every((p) => p is TextPart || p == image), isTrue);
        final split = UiUserContextParts.read(parts);
        expect(split.context, text);
        expect(split.body, body);
        expect(split.bodyText, content);
        expect(
          parts.whereType<TextPart>().map((p) => p.text).join(),
          '${text.exactText}\n\n$content',
        );
      }
      final literal = [TextPart('${text.exactText}\n\nLiteral typed text')];
      expect(UiUserContextParts.read(literal).context, isNull);
      expect(UiUserContextParts.read(literal).body, literal);
      expect(
        UiUserContextParts.read([image, TextPart(text.exactText)]).context,
        isNull,
      );
    },
  );
}
