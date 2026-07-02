import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/prompts/title_presets.dart';
import 'package:Kelivo/core/prompts/constants/title_prompts.dart';

void main() {
  group('TitlePresets.detect', () {
    test('returns "standard" for exact defaultTitlePrompt', () {
      expect(TitlePresets.detect(defaultTitlePrompt), 'standard');
    });

    test('returns "standard" for defaultTitlePrompt with trailing whitespace', () {
      expect(TitlePresets.detect('$defaultTitlePrompt\n'), 'standard');
      expect(TitlePresets.detect('  $defaultTitlePrompt  '), 'standard');
    });

    test('returns "emoji" for exact emojiTitlePrompt', () {
      expect(TitlePresets.detect(emojiTitlePrompt), 'emoji');
    });

    test('returns "emoji" for emojiTitlePrompt with trailing whitespace', () {
      expect(TitlePresets.detect('$emojiTitlePrompt\n'), 'emoji');
    });

    test('returns null for custom text that does not match any preset', () {
      expect(TitlePresets.detect('this is a custom prompt'), isNull);
    });

    test('returns null for empty string', () {
      expect(TitlePresets.detect(''), isNull);
    });

    test('returns null for text that almost matches but differs', () {
      final modified = defaultTitlePrompt.replaceFirst(
        'short title',
        'short summary',
      );
      expect(TitlePresets.detect(modified), isNull);
    });

    test('matching is trim-only, not whitespace-collapsed', () {
      final extraSpaces = defaultTitlePrompt.replaceAll('\n\n', '\n\n\n');
      expect(TitlePresets.detect(extraSpaces), isNull);
    });
  });

  group('TitlePresets.byId', () {
    test('returns the standard preset', () {
      final p = TitlePresets.byId('standard');
      expect(p, isNotNull);
      expect(p!.id, 'standard');
      expect(p.prompt, defaultTitlePrompt);
    });

    test('returns the emoji preset', () {
      final p = TitlePresets.byId('emoji');
      expect(p, isNotNull);
      expect(p!.id, 'emoji');
      expect(p.prompt, emojiTitlePrompt);
    });

    test('returns null for unknown id', () {
      expect(TitlePresets.byId('nonexistent'), isNull);
      expect(TitlePresets.byId(''), isNull);
    });
  });

  group('TitlePresets.all', () {
    test('contains exactly two presets', () {
      expect(TitlePresets.all.length, 2);
    });

    test('contains standard and emoji', () {
      final ids = TitlePresets.all.map((p) => p.id).toSet();
      expect(ids, contains('standard'));
      expect(ids, contains('emoji'));
    });
  });
}
