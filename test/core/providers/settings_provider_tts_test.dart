import "../../support/business_test_harness.dart";
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/tts/tts_text_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and persists TTS playback settings', () async {
    final harness = await createBusinessTestHarness(
      initial: const {
        'tts_auto_play_assistant_replies_v1': true,
        'tts_text_selection_mode_v1': 'quotedOnly',
      },
    );

    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;

    expect(settings.ttsAutoPlayAssistantReplies, isTrue);
    expect(settings.ttsTextSelectionMode, TtsTextSelectionMode.quotedOnly);

    await settings.setTtsTextSelectionMode(TtsTextSelectionMode.nonItalic);
    await settings.setTtsAutoPlayAssistantReplies(false);

    expect(
      harness.preferences.getString('tts_text_selection_mode_v1'),
      'nonItalic',
    );
    expect(
      harness.preferences.getBool('tts_auto_play_assistant_replies_v1'),
      isFalse,
    );
  });

  test('falls back to full text when persisted TTS mode is invalid', () async {
    final harness = await createBusinessTestHarness(
      initial: const {
        'tts_auto_play_assistant_replies_v1': true,
        'tts_text_selection_mode_v1': 'unknown-mode',
      },
    );

    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;

    expect(settings.ttsTextSelectionMode, TtsTextSelectionMode.fullText);
  });
}
