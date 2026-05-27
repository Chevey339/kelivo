import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/tts/tts_text_selection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and persists TTS playback settings', () async {
    SharedPreferences.setMockInitialValues(const {
      'tts_auto_play_assistant_replies_v1': true,
      'tts_text_selection_mode_v1': 'quotedOnly',
    });

    final settings = SettingsProvider();
    await _waitUntil(() => settings.ttsAutoPlayAssistantReplies);

    expect(settings.ttsAutoPlayAssistantReplies, isTrue);
    expect(settings.ttsTextSelectionMode, TtsTextSelectionMode.quotedOnly);

    await settings.setTtsTextSelectionMode(TtsTextSelectionMode.nonItalic);
    await settings.setTtsAutoPlayAssistantReplies(false);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tts_text_selection_mode_v1'), 'nonItalic');
    expect(prefs.getBool('tts_auto_play_assistant_replies_v1'), isFalse);
  });

  test('falls back to full text when persisted TTS mode is invalid', () async {
    SharedPreferences.setMockInitialValues(const {
      'tts_auto_play_assistant_replies_v1': true,
      'tts_text_selection_mode_v1': 'unknown-mode',
    });

    final settings = SettingsProvider();
    await _waitUntil(() => settings.ttsAutoPlayAssistantReplies);

    expect(settings.ttsTextSelectionMode, TtsTextSelectionMode.fullText);
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for SettingsProvider condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
