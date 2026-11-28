import 'dart:convert';

import '../../support/business_test_harness.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/tts/network_tts.dart';
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

  test(
    'migrates legacy TTS index to UUID and survives earlier deletion',
    () async {
      final services = <Map<String, dynamic>>[
        {
          'id': 'first-service',
          'kind': 'openai',
          'enabled': true,
          'name': 'First',
          'apiKey': 'key',
        },
        {
          'id': 'second-service',
          'kind': 'groq',
          'enabled': true,
          'name': 'Second',
          'apiKey': 'key',
        },
      ];
      final harness = await createBusinessTestHarness(
        initial: {
          'tts_services_v1': jsonEncode(services),
          'tts_selected_v1': 1,
        },
      );
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;

      expect(settings.selectedTtsServiceId, 'second-service');
      expect(
        harness.preferences.getString('tts_selected_service_id_v1'),
        'second-service',
      );
      expect(harness.preferences.getInt('tts_selected_v1'), isNull);

      final selected = settings.ttsServices.singleWhere(
        (service) => service.id == 'second-service',
      );
      await settings.setTtsServices(<TtsServiceOptions>[selected]);

      expect(settings.selectedTtsServiceId, 'second-service');
      expect(settings.selectedTtsService?.name, 'Second');
    },
  );

  test('migrates only retired official Gemini voices across reloads', () async {
    const endpoint = 'https://generativelanguage.googleapis.com/v1beta';
    const retired = [
      'gemini-3.1-flash-tts-preview',
      'gemini-2.5-flash-preview-tts',
      'gemini-2.5-pro-preview-tts',
    ];
    const saved = {
      'kind': 'gemini',
      'enabled': false,
      'name': 'My reader',
      'voiceName': 'Puck',
      'apiKey': 'saved-key',
      'extra': 'preserve on write-back',
    };
    final official = [
      for (final (i, model) in retired.indexed)
        {
          ...saved,
          'id': model,
          if (i == 1) 'baseUrl': endpoint,
          if (i == 2)
            'baseUrl': 'https://GENERATIVELANGUAGE.GOOGLEAPIS.COM:443/v1beta/',
          'model': model,
        },
    ];
    final other = [
      for (final url in [
        'https://gateway.example/v1beta',
        'https://generativelanguage.googleapis.com.example/v1beta',
        'https://generativelanguage.googleapis.com:8443/v1beta',
        'https://generativelanguage.googleapis.com/proxy/v1beta',
        '$endpoint?tenant=custom',
      ])
        {...saved, 'id': url, 'baseUrl': url, 'model': retired.first},
      {...saved, 'id': 'gateway-default', 'baseUrl': 'https://gateway.example'},
      {
        ...saved,
        'id': 'explicit',
        'baseUrl': endpoint,
        'model': 'gemini-3.8-flash-tts',
      },
      {'id': 'other-kind', 'kind': 'openai', 'model': 'tts-1', 'extra': true},
    ];
    final harness = await createBusinessTestHarness(
      initial: {
        'tts_services_v1': jsonEncode([...official, ...other]),
        'tts_selected_service_id_v1': retired.last,
      },
    );
    for (var load = 0; load < 2; load++) {
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      expect(settings.selectedTtsServiceId, retired.last);
      final selected = settings.selectedTtsService as GeminiTtsOptions;
      expect(selected.model, 'gemini-3.8-flash-lite-tts');
      expect(selected.voiceName, 'Puck');
      expect(selected.enabled, isFalse);
      final gateway = settings.ttsServices.singleWhere(
        (s) => s.id == 'gateway-default',
      );
      expect((gateway as GeminiTtsOptions).model, retired.first);
      expect(jsonDecode(harness.preferences.getString('tts_services_v1')!), [
        for (final row in official)
          {...row, 'model': 'gemini-3.8-flash-lite-tts'},
        ...other,
      ]);
    }
  });

  test('persists generated UUIDs for legacy TTS rows across reloads', () async {
    final harness = await createBusinessTestHarness(
      initial: {
        'tts_services_v1': jsonEncode(<Map<String, dynamic>>[
          {'kind': 'openai', 'enabled': true, 'name': 'First', 'apiKey': 'key'},
          {'kind': 'groq', 'enabled': true, 'name': 'Second', 'apiKey': 'key'},
        ]),
        'tts_selected_v1': 1,
      },
    );
    final firstLoad = SettingsProvider(harness.preferences);
    await firstLoad.loaded;
    final selectedId = firstLoad.selectedTtsServiceId;

    expect(selectedId, isNotNull);
    expect(firstLoad.selectedTtsService?.name, 'Second');
    final persistedRows =
        jsonDecode(harness.preferences.getString('tts_services_v1')!)
            as List<dynamic>;
    expect(
      persistedRows.every(
        (row) => ((row as Map<String, dynamic>)['id'] as String).isNotEmpty,
      ),
      isTrue,
    );

    final secondLoad = SettingsProvider(harness.preferences);
    await secondLoad.loaded;
    expect(secondLoad.selectedTtsServiceId, selectedId);
    expect(secondLoad.selectedTtsService?.name, 'Second');
  });
}
