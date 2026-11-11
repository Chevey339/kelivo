import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/compress_context_options.dart';
import 'package:Kelivo/core/models/compression_config.dart';
import 'package:Kelivo/core/models/context_compression_task.dart';
import 'package:Kelivo/core/services/chat/compression_prompt.dart';
import 'package:Kelivo/core/services/chat/compression_templates.dart';

void main() {
  final chinese = RegExp(r'[\u4e00-\u9fff]');

  test(
    'both catalogs preserve template identity and output language defaults',
    () {
      final zh = builtInCompressionTemplatesForLocale('zh-CN');
      final en = builtInCompressionTemplatesForLocale('en-US');
      expect(en.map((t) => t.id), zh.map((t) => t.id));
      for (var i = 0; i < en.length; i++) {
        expect(en[i].name, zh[i].name);
        expect(en[i].scene, zh[i].scene);
        expect(en[i].builtIn, isTrue);
        expect(en[i].outputLanguage, 'conversation');
        expect(zh[i].outputLanguage, 'conversation');
        expect(chinese.hasMatch(en[i].prompt), isFalse);
        expect(chinese.hasMatch(zh[i].prompt), isTrue);
      }
    },
  );

  for (final locale in [
    'en',
    'en-US',
    'en_GB',
    'fr-FR',
    'zh',
    'zh-Hant',
    'zh_TW',
  ]) {
    test('instructions, update rules and default requests resolve $locale', () {
      final expectsChinese = locale.startsWith('zh');
      for (final template in builtInCompressionTemplatesForLocale(locale)) {
        final prompt = renderCompressionPrompt(
          template: template,
          content: 'New confirmed facts.',
          previousSummary: 'Previous working summary.',
          targetTokens: 1024,
          locale: locale,
        );
        expect(prompt, contains(template.prompt));
        expect(prompt, contains(compressionContractForLocale(locale)));
        expect(prompt, contains(compressionUpdateInstructionForLocale(locale)));
        expect(chinese.hasMatch(prompt), expectsChinese);
        expect(prompt, contains('the main language of the conversation'));
      }
      final request = CompressionRequest(
        options: const CompressContextOptions(
          mode: CompressContextLimitMode.keepRecent,
        ),
        model: 'test',
        generate: (_, _, _, _) => throw StateError('must not call a model'),
        quoteMarker: (i) => '$i',
        locale: locale,
      );
      expect(chinese.hasMatch(request.resolvedTemplate.prompt), expectsChinese);
    });
  }

  test(
    'explicit summary language and custom instructions survive English UI',
    () {
      const template = CompressionTemplate(
        id: 'custom',
        name: 'Custom',
        prompt: '请保留用户自定义的规则。 {content}',
        outputLanguage: 'zh-Hant',
      );
      final prompt = renderCompressionPrompt(
        template: template,
        content: 'Source text',
        locale: 'en-US',
        targetTokens: 2048,
      );
      expect(prompt, contains('请保留用户自定义的规则。'));
      expect(
        prompt,
        contains(
          'Output language (application setting, takes precedence): zh-Hant.',
        ),
      );
      expect(prompt, contains('Source text'));
    },
  );

  test('legacy templates retain control of their output language', () {
    const template = CompressionTemplate(
      id: 'original',
      name: 'Original',
      prompt: 'Original instructions for {locale}',
      outputLanguage: 'legacy',
    );
    for (final locale in ['en-US', 'zh-CN']) {
      final prompt = renderCompressionPrompt(
        template: template,
        content: 'Source text',
        locale: locale,
        targetTokens: 1024,
      );
      expect(prompt, contains('Original instructions for $locale'));
      expect(
        prompt,
        contains(compressionContractForLocale(locale, legacy: true)),
      );
      expect(
        prompt,
        isNot(
          contains('Output language (application setting, takes precedence)'),
        ),
      );
    }
  });
}
