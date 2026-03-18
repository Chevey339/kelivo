import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';

void main() {
  group('markdown horizontal rule pattern', () {
    final hrRegex = RegExp(
      MarkdownWithCodeHighlight.markdownHorizontalRuleLinePattern,
      multiLine: true,
    );

    test('matches dash, star, underscore and em dash separators', () {
      expect(hrRegex.hasMatch('---'), isTrue);
      expect(hrRegex.hasMatch('***'), isTrue);
      expect(hrRegex.hasMatch('___'), isTrue);
      expect(hrRegex.hasMatch('⸻'), isTrue);
    });

    test('does not match list items or emphasis text', () {
      expect(hrRegex.hasMatch('- item'), isFalse);
      expect(hrRegex.hasMatch('***bold***'), isFalse);
      expect(hrRegex.hasMatch('__label__'), isFalse);
    });
  });

  group('markdown preprocessing for horizontal rules', () {
    test(
      'keeps supported horizontal rules after bold labels as block separators',
      () {
        expect(
          MarkdownWithCodeHighlight.preprocessMarkdownForRendering(
            '**作者:** 张三\n---',
            enableMath: false,
            enableDollarLatex: false,
          ),
          '**作者:** 张三\n\n---',
        );
        expect(
          MarkdownWithCodeHighlight.preprocessMarkdownForRendering(
            '**作者:** 张三\n***',
            enableMath: false,
            enableDollarLatex: false,
          ),
          '**作者:** 张三\n\n***',
        );
        expect(
          MarkdownWithCodeHighlight.preprocessMarkdownForRendering(
            '**作者:** 张三\n___',
            enableMath: false,
            enableDollarLatex: false,
          ),
          '**作者:** 张三\n\n___',
        );
      },
    );

    test(
      'does not rewrite emphasis or fenced code blocks containing stars',
      () {
        expect(
          MarkdownWithCodeHighlight.preprocessMarkdownForRendering(
            '***bold***',
            enableMath: false,
            enableDollarLatex: false,
          ),
          '***bold***',
        );
        expect(
          MarkdownWithCodeHighlight.preprocessMarkdownForRendering(
            '```\n***\n```',
            enableMath: false,
            enableDollarLatex: false,
          ),
          '```\n***\n```',
        );
      },
    );
  });
}
