import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

import 'markstream_view_test.dart' show host, paragraph;
import 'rich_blocks_test.dart' show tableSource;

Rect bounds(RenderParagraph p) => p.localToGlobal(Offset.zero) & p.size;
bool _knownModel(String word) =>
    const {'gemini', 'mistral'}.contains(word.toLowerCase());
const _direction = ProseDirectionResolver(isKnownName: _knownModel);
final _extensions = MarkstreamExtensions(proseDirection: _direction);

void main() {
  test('Unicode strong characters decide the base direction', () {
    for (final text in [
      '… ۱۲ 中文 שלום',
      'Ａ مرحبا',
      'हिन्दी سلام',
      '\u200eשלום',
    ]) {
      expect(_direction.forText(text), TextDirection.ltr, reason: text);
    }
    for (final text in [
      '🙂 123 (سلام)',
      'َ ١٢٣ العربية',
      '́ • עברית',
      '¿ اردو',
      '🫠 𞤀',
      '\u200fEnglish',
    ]) {
      expect(_direction.forText(text), TextDirection.rtl, reason: text);
    }
    for (final text in ['', '🧑‍💻 123، ١٢٣ ۴۵۶', '\u2066…\u2069']) {
      expect(_direction.forText(text), isNull, reason: text);
    }
  });

  test('a Latin name needs evidence of an unquoted RTL sentence', () {
    for (final text in [
      'Gemini چیه؟',
      'GPT-4o چیه و چطور کار می‌کنه؟',
      'Gemini-2.5 چطور کار می‌کند؟',
      'OpenAI איך אפשר להשתמש בזה?',
      'gemini چیه',
      'Gemini چیه و چطور با `v1beta` کار می‌کنه؟',
      'Gemini چیه با `extremelyLongConfigurationIdentifier`؟',
      'Gemini دربارهٔ «هوش مصنوعی» چه می‌گوید؟',
      'Gemini یہ بہت مفید ہے۔',
      'Gemini איך אפשר להשתמש בזה',
      'Gemini اب؟', // Three out of nine strong characters are RTL.
      'Gemini چیه؟ `parameter`',
      'Gemini چیه؟ 😊',
      'Gemini چه فرقی دارد با ((Gemini) Advanced)؟',
      'Gemini چیه با `a ``` b`؟',
    ]) {
      expect(_direction.forText(text), TextDirection.rtl, reason: text);
    }
    for (final text in [
      'Translate «مرحبا»',
      'Translate «چیه؟»',
      'Translate "שלום לכולם כאן היום"',
      'Translate كيف حالك؟',
      'Translate איך אפשר להשתמש במילים האלה',
      'Is العربية a language؟',
      'Say مرحبا in English؟',
      'Copy كيف حالك؟',
      'COPY كيف حالك؟',
      'Paraphrase كيف حالك؟',
      'Çevir كيف حالك؟',
      'Traduce كيف حالك؟',
      'Gemini مرحبا in English؟',
      'OpenAI مرحبا in English؟',
      'GPT-4o. كيف حالك؟',
      'Translate this سؤال طويل جدا؟',
      'Gemini says سلام و احوال شما چطور است؟',
      'Mistral اب؟', // Exactly 30%, not above the threshold.
      'Hello שלום',
      'Gemini چیه «؟', // Still typing a quotation.
      'Gemini א «ارقام بسیار زیاد در این نمونه»؟',
      'English: كيف حالك اليوم؟',
      'Translate (كيف حالك اليوم؟)',
      'Translate `چیه؟`',
      'https://example.test/كيف/حالك؟',
      '中文 چیه و چطور کار می‌کنه؟',
      'Gemini\nچیه؟',
      'Gemini שלום uses English.',
      'Gemini ؟؟؟',
      '\u200eGemini چیه؟',
    ]) {
      expect(_direction.forText(text), TextDirection.ltr, reason: text);
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
              extensions: _extensions,
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
      await show('**Gemini**', true);
      expect(paragraph('Gemini').textDirection, TextDirection.ltr);
      for (final active in [true, false]) {
        await show('**Ge**mini [چیه](https://example.test/english)؟', active);
        expect(paragraph('Gemini').textDirection, TextDirection.rtl);
        expect(bounds(paragraph('Gemini')).right, closeTo(start + 390, .01));
        expect(paragraph('中文').textDirection, TextDirection.ltr);
      }
      await show('**Translate** «مرحبا»', false);
      expect(paragraph('Translate').textDirection, TextDirection.ltr);
      expect(bounds(paragraph('Translate')).left, start);
      await show('**Is** العربية a language؟', false);
      expect(paragraph('Is').textDirection, TextDirection.ltr);
      await show(
        'Gemini چیه با `extremelyLongConfigurationIdentifier`؟',
        false,
      );
      expect(paragraph('Gemini').textDirection, TextDirection.rtl);
      expect(paragraph('extremelyLong').textDirection, TextDirection.ltr);
      await show('Gemini چیه؟ `parameter`', true);
      expect(paragraph('Gemini').textDirection, TextDirection.rtl);
      expect(paragraph('parameter').textDirection, TextDirection.ltr);
    },
  );

  testWidgets('mixed lists resolve visible content within each item', (
    tester,
  ) async {
    const source =
        '1. **Gemini** چیه و چطور با `v1beta` کار می‌کنه؟\n'
        '2. **Translate** «مرحبا»\n'
        '3. Gemini `چیه؟`\n'
        '4. Gemini\n\n   چیه؟';
    await tester.pumpWidget(
      host(MarkstreamView(source: source, extensions: _extensions)),
    );
    final rtl = paragraph('Gemini چیه');
    expect(
      bounds(paragraph('1.')).left,
      greaterThanOrEqualTo(bounds(rtl).right),
    );
    expect(paragraph('v1beta').textDirection, TextDirection.ltr);
    expect(paragraph('Translate').textDirection, TextDirection.ltr);
    expect(paragraph('3.').textDirection, TextDirection.ltr);
    expect(paragraph('4.').textDirection, TextDirection.ltr);
  });

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
