import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

import 'markstream_view_test.dart' show host, paragraph;
import 'rich_blocks_test.dart' show tableSource;

Rect bounds(RenderParagraph p) => p.localToGlobal(Offset.zero) & p.size;

void main() {
  test('Unicode strong characters decide the base direction', () {
    for (final text in [
      'Gemini چیه؟',
      '… ۱۲ 中文 שלום',
      'Ａ مرحبا',
      'हिन्दी سلام',
      '\u200eשלום',
    ]) {
      expect(firstStrongDirection(text), TextDirection.ltr, reason: text);
    }
    for (final text in [
      '🙂 123 (سلام)',
      'َ ١٢٣ العربية',
      '́ • עברית',
      '¿ اردو',
      '🫠 𞤀',
      '\u200fEnglish',
    ]) {
      expect(firstStrongDirection(text), TextDirection.rtl, reason: text);
    }
    for (final text in ['', '🧑‍💻 123، ١٢٣ ۴۵۶', '\u2066…\u2069']) {
      expect(firstStrongDirection(text), isNull, reason: text);
    }
  });

  testWidgets(
    'a stream resolves neutral prefixes and keeps completed blocks on their own sides',
    (tester) async {
      const prefix = '中文 Gemini שלום\n\n';
      Future<void> show(String tail, bool streaming) async {
        await tester.pumpWidget(
          host(
            MarkstreamView(
              source: '$prefix$tail',
              streaming: streaming,
              cullToViewport: false,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }

      await show('123', true);
      final initial = paragraph('中文');
      final start = bounds(initial).left;
      expect(initial.textDirection, TextDirection.ltr);
      expect(paragraph('123').textDirection, TextDirection.ltr);
      for (final active in [true, false]) {
        await show('123 **سلام** (Gemini)؟', active);
        final rtl = paragraph('123');
        expect(rtl.textDirection, TextDirection.rtl);
        expect(bounds(rtl).right, closeTo(start + 390, .01));
        expect(bounds(paragraph('中文')).left, start);
      }
      await show('Gemini چیه و چطور کار می‌کنه؟', true);
      expect(paragraph('Gemini').textDirection, TextDirection.ltr);
      expect(bounds(paragraph('Gemini')).left, start);
    },
  );

  testWidgets(
    'markers, quote, heading and table cells follow prose while code and explicit alignments stay independent',
    (tester) async {
      const source =
          '# **عنوان**\n\n> نقل قول\n\n1. [עברית](https://example.test/ltr)\n2. English שלום\n\n`v1beta()` متن\n\n```dart\nprint(1);\n```\n\n| H | L | C | R |\n| --- | :--- | :---: | ---: |\n| خانه | چپ | وسط | راست |';
      await tester.pumpWidget(
        host(const MarkstreamView(source: source, cullToViewport: false)),
      );
      await tester.pumpAndSettle();
      final heading = paragraph('عنوان');
      expect(heading.textDirection, TextDirection.rtl);
      expect(bounds(heading).right, closeTo(390, .01));
      expect(
        Directionality.of(
          tester.element(find.byKey(const ValueKey('markstream-quote'))),
        ),
        TextDirection.rtl,
      );
      expect(paragraph('نقل').textDirection, TextDirection.rtl);
      expect(
        bounds(paragraph('1.')).left,
        greaterThanOrEqualTo(bounds(paragraph('עברית')).right),
      );
      expect(
        bounds(paragraph('2.')).right,
        lessThanOrEqualTo(bounds(paragraph('English')).left),
      );
      expect(paragraph('\uFFFC متن').textDirection, TextDirection.rtl);
      expect(paragraph('v1beta').textDirection, TextDirection.ltr);
      expect(paragraph('print(1)').textDirection, TextDirection.ltr);
      for (final (word, align) in [
        ('خانه', TextAlign.start),
        ('چپ', TextAlign.left),
        ('وسط', TextAlign.center),
        ('راست', TextAlign.right),
      ]) {
        expect(paragraph(word).textDirection, TextDirection.rtl);
        expect(paragraph(word).textAlign, align);
      }
    },
  );

  testWidgets('compact mixed blocks share the measured content width', (
    tester,
  ) async {
    for (final tail in ['سلام', '# سلام', 'سلام `x`', '> سلام']) {
      await tester.pumpWidget(
        host(
          Align(
            alignment: Alignment.topLeft,
            child: MarkstreamView(source: 'Longer English line\n\n$tail'),
          ),
        ),
      );
      final english = bounds(paragraph('Longer'));
      final rtl = bounds(paragraph('سلام'));
      final right = tail.startsWith('>')
          ? tester.getRect(find.byKey(const ValueKey('markstream-quote'))).right
          : rtl.right;
      expect(right, closeTo(english.right, .01), reason: tail);
      expect(english.right, lessThan(390));
      if (tail.startsWith('>')) expect(rtl.right, closeTo(right - 12, .01));
    }
  });

  testWidgets('the first streamed RTL block preserves completed table state', (
    tester,
  ) async {
    final table = tableSource(45);
    Future<void> show(String tail) async {
      await tester.pumpWidget(
        host(
          MarkstreamView(
            source: '$table\n\n$tail',
            streaming: true,
            cullToViewport: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show('123');
    final more = find.text('Show 6 more rows');
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    for (final tail in ['123 English', '123 שלום', 'English again']) {
      await show(tail);
      expect(tester.widget<Table>(find.byType(Table)).children, hasLength(46));
    }
  });

  testWidgets('explicit HTML alignment wins over the paragraph start', (
    tester,
  ) async {
    for (final (tag, close, align) in [
      ('center', 'center', TextAlign.center),
      ('p align="center"', 'p', TextAlign.center),
      ('p align="left"', 'p', TextAlign.left),
      ('p align="right"', 'p', TextAlign.right),
    ]) {
      await tester.pumpWidget(
        host(MarkstreamView(source: '<$tag>وسط</$close>')),
      );
      final rtl = paragraph('وسط');
      expect(rtl.textDirection, TextDirection.rtl);
      expect(rtl.textAlign, align);
      final rect = bounds(rtl);
      if (align == TextAlign.center) expect(rect.center.dx, closeTo(195, .01));
      if (align == TextAlign.left) expect(rect.left, closeTo(0, .01));
      if (align == TextAlign.right) expect(rect.right, closeTo(390, .01));
    }
  });

  testWidgets(
    'in an RTL host Latin is LTR and neutral content inherits the host',
    (tester) async {
      await tester.pumpWidget(
        host(
          const Directionality(
            textDirection: TextDirection.rtl,
            child: MarkstreamView(
              source: 'English שלום\n\n123?!\n\n`x()`',
              cullToViewport: false,
            ),
          ),
        ),
      );
      expect(paragraph('English').textDirection, TextDirection.ltr);
      expect(bounds(paragraph('English')).left, closeTo(0, .01));
      expect(paragraph('123').textDirection, TextDirection.rtl);
      expect(paragraph('x()').textDirection, TextDirection.ltr);
    },
  );
}
