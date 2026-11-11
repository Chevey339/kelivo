import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/composer_draft.dart';
import 'package:Kelivo/core/models/quote_ref.dart';
import 'package:Kelivo/features/chat/controllers/quote_editing_controller.dart';
import 'package:Kelivo/features/chat/widgets/quote_chip.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

QuoteRef quote(int index) => QuoteRef(
  id: 'q$index',
  messageId: 'm$index',
  start: index,
  end: index + 4,
  text: '引文 $index\n第二行',
  model: 'Model',
  createdAt: DateTime.utc(2026, 10, 28),
);

void main() {
  test('quote values match platform values in both comparison directions', () {
    const remote = TextEditingValue(
      text: '${quotePlaceholder}dou',
      selection: TextSelection.collapsed(offset: 4),
      composing: TextRange(start: 1, end: 4),
    );
    final local = QuoteEditingValue(
      text: remote.text,
      selection: remote.selection,
      composing: remote.composing,
      quotes: [quote(1)],
    );
    expect(local == remote, true);
    expect(remote == local, true);
    expect(local.hashCode, remote.hashCode);
    expect(local == remote.copyWith(composing: TextRange.empty), false);
    expect(
      local ==
          remote.copyWith(selection: const TextSelection.collapsed(offset: 1)),
      false,
    );
  });

  test('same-placeholder restoration still updates the quote snapshot', () {
    final c = QuoteEditingController(nativeInputEnabled: false);
    addTearDown(c.dispose);
    c.insertQuote(quote(1));
    final previous = c.value;
    var notifications = 0;
    c.addListener(() => notifications++);
    c.restore(previous, [quote(2)]);
    expect(c.text, previous.text);
    expect(c.quotes, [quote(2)]);
    expect(c.value == previous, false);
    expect(notifications, 1);
    expect(previous.quotes, [quote(1)]);
  });

  testWidgets(
    'quoted IME composition is not echoed back to the platform',
    (tester) async {
      final c = QuoteEditingController(nativeInputEnabled: false);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TextField(maxLines: null, controller: c, autofocus: true),
          ),
        ),
      );
      await tester.pump();
      c.insertQuote(quote(1));
      await tester.pump();
      tester.testTextInput.log.clear();
      for (final (text, composing) in [
        ('d', const TextRange(start: 1, end: 2)),
        ('do', const TextRange(start: 1, end: 3)),
        ('dou', const TextRange(start: 1, end: 4)),
        ('都', TextRange.empty),
        ('都n', const TextRange(start: 2, end: 3)),
        ('都no', const TextRange(start: 2, end: 4)),
        ('都nong', const TextRange(start: 2, end: 6)),
        ("都nong'nong", const TextRange(start: 2, end: 11)),
        ('都弄弄', TextRange.empty),
      ]) {
        final value = TextEditingValue(
          text: '$quotePlaceholder$text',
          selection: TextSelection.collapsed(offset: text.length + 1),
          composing: composing,
        );
        tester.testTextInput.updateEditingValue(value);
        await tester.pump();
        expect(c.text, value.text);
        expect(c.value.composing, composing);
        expect(c.quotes, [quote(1)]);
        expect(
          tester.testTextInput.log.where(
            (call) => call.method == 'TextInput.setEditingState',
          ),
          isEmpty,
          reason: 'An accepted IME update must not reset native state: $text',
        );
      }
      expect(c.text, '$quotePlaceholder都弄弄');
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }),
  );

  test(
    'reasoning snapshots deduplicate by selected text and survive serialization',
    () {
      final controller = QuoteEditingController(nativeInputEnabled: false);
      addTearDown(controller.dispose);
      QuoteRef snapshot(String id, String text) => QuoteRef(
        id: id,
        messageId: 'thinking',
        start: 0,
        end: 0,
        text: text,
        model: 'model',
        createdAt: DateTime(2026),
        hasSourceRange: false,
      );
      final first = snapshot('first', 'first thought');
      final second = snapshot('second', 'second thought');
      expect(controller.insertQuote(first), QuoteInsertion.inserted);
      expect(controller.insertQuote(second), QuoteInsertion.inserted);
      expect(
        controller.insertQuote(snapshot('again', first.text)),
        QuoteInsertion.duplicate,
      );
      expect(controller.quotes, [first, second]);
      final draft = ComposerDraftInput(
        text: controller.text,
        quotes: controller.quotes,
      );
      final restored = ComposerDraftInput.fromJson(draft.toJson());
      expect(restored.sameValue(draft), isTrue);
      expect(restored.quotes.every((quote) => !quote.hasSourceRange), isTrue);
      final bodyQuote = QuoteRef(
        id: 'body',
        messageId: first.messageId,
        start: 0,
        end: 0,
        text: first.text,
        model: first.model,
        createdAt: first.createdAt,
      );
      expect(controller.insertQuote(bodyQuote), QuoteInsertion.inserted);
      expect(first.withMessageId('copied').hasSourceRange, isFalse);
    },
  );

  test(
    'references follow cursor insertion and adjacent backward/forward deletion',
    () {
      final controller = QuoteEditingController(
        nativeInputEnabled: false,
        text: '前后',
      );
      addTearDown(controller.dispose);
      controller.selection = const TextSelection.collapsed(offset: 1);
      controller.insertQuote(quote(1));
      controller.insertQuote(quote(2));
      expect(controller.text, '前\uFFFC\uFFFC后');
      controller.selection = const TextSelection.collapsed(offset: 2);
      controller.value = const TextEditingValue(
        text: '前\uFFFC后',
        selection: TextSelection.collapsed(offset: 1),
      );
      expect(controller.quotes, [quote(2)]);
      controller.value = const TextEditingValue(
        text: '前后',
        selection: TextSelection.collapsed(offset: 1),
      );
      expect(controller.quotes, isEmpty);
    },
  );

  test('range replacement preserves only references outside the range', () {
    final c = QuoteEditingController(nativeInputEnabled: false);
    addTearDown(c.dispose);
    for (var i = 0; i < 3; i++) {
      c.insertQuote(quote(i));
    }
    c.selection = const TextSelection(baseOffset: 0, extentOffset: 2);
    c.value = c.value.copyWith(
      text: '新\uFFFC',
      selection: const TextSelection.collapsed(offset: 1),
    );
    expect(c.quotes, [quote(2)]);
    expect(c.text, '新\uFFFC');
  });

  test(
    'paste cannot introduce object replacement characters; composing survives',
    () {
      final c = QuoteEditingController(nativeInputEnabled: false);
      addTearDown(c.dispose);
      c.insertQuote(quote(1));
      c.value = const TextEditingValue(
        text: '\uFFFC外\uFFFC来',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 1, end: 4),
      );
      expect(c.text, '\uFFFC外来');
      expect(c.quotes, [quote(1)]);
      expect(c.selection.extentOffset, 3);
      expect(c.value.composing, const TextRange(start: 1, end: 3));
    },
  );

  test('duplicate and ten-reference limit do not change the draft', () {
    final c = QuoteEditingController(nativeInputEnabled: false);
    addTearDown(c.dispose);
    for (var i = 0; i < 10; i++) {
      expect(c.insertQuote(quote(i)), QuoteInsertion.inserted);
    }
    expect(c.insertQuote(quote(0)), QuoteInsertion.duplicate);
    expect(c.flashingQuoteId, 'q0');
    expect(c.insertQuote(quote(10)), QuoteInsertion.limit);
    expect(c.quotes.length, 10);
  });

  test(
    'draft and message serialization retain snapshots; request expands all quote lines',
    () {
      final refs = [quote(1), quote(2)];
      const body = '比较 \uFFFC 与 \uFFFC';
      final draft = ComposerDraftInput(text: body, quotes: refs);
      final recovered = ComposerDraftInput.fromJson(draft.toJson());
      expect(recovered.sameValue(draft), isTrue);
      expect(recovered.toInput().quotes, refs);
      final message = ChatMessage(
        role: 'user',
        conversationId: 'c',
        content: body,
        quotes: refs,
      );
      final loaded = ChatMessage.fromJson(message.toJson());
      expect(loaded.content, body);
      expect(loaded.quotes, refs);
      expect(loaded.copyWith(content: '$body?').quotes, refs);
      expect(
        loaded.quotedContent(
          lookupAppLocalizations(const Locale('zh')).selectionQuoteMarker,
        ),
        '> [引用1] 引文 1\n> 第二行\n> [引用2] 引文 2\n> 第二行\n\n比较 [引用1] 与 [引用2]',
      );
    },
  );

  testWidgets(
    'real editable text renders atomic widgets and keyboard deletes one reference',
    (tester) async {
      final c = QuoteEditingController(nativeInputEnabled: false, text: '前后');
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TextField(maxLines: null, controller: c, autofocus: true),
          ),
        ),
      );
      c.selection = const TextSelection.collapsed(offset: 1);
      c.insertQuote(quote(1));
      await tester.pump();
      expect(find.byType(QuoteChip), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(c.selection.baseOffset, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(c.text, '前后');
      expect(c.quotes, isEmpty);
      expect(find.byType(QuoteChip), findsNothing);
    },
  );

  testWidgets('Flutter undo restores quote metadata along with placeholder', (
    tester,
  ) async {
    final c = QuoteEditingController(nativeInputEnabled: false);
    addTearDown(c.dispose);
    final undo = UndoHistoryController();
    addTearDown(undo.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TextField(
            maxLines: null,
            controller: c,
            undoController: undo,
            autofocus: true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    c.insertQuote(quote(1));
    await tester.pump(const Duration(milliseconds: 600));
    c.removeQuote('q1');
    await tester.pump(const Duration(milliseconds: 600));
    undo.undo();
    await tester.pump();
    expect(c.text, '\uFFFC');
    expect(c.quotes, [quote(1)]);
    expect(find.byType(QuoteChip), findsOneWidget);

    // Both edits fit into one undo interval and finish with the same U+FFFC.
    // Their quote snapshots must remain distinguishable from one another.
    c.removeQuote('q1');
    c.insertQuote(quote(2));
    await tester.pump(const Duration(milliseconds: 600));
    expect(c.quotes, [quote(2)]);
    undo.undo();
    await tester.pump();
    expect(c.quotes, [quote(1)]);
    undo.redo();
    await tester.pump();
    expect(c.quotes, [quote(2)]);
  });
}
