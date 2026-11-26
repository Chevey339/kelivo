import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/media/fal_model_discovery.dart';
import 'package:Kelivo/core/services/media/media_models.dart';
import 'package:Kelivo/features/provider/widgets/fal_model_picker.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/configurable_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';

Map<String, dynamic> _row(String id, String category) => {
  'endpoint_id': id,
  'metadata': {
    'display_name': id.split('/').last,
    'category': category,
    'status': 'active',
  },
};

http.Response _page(List<Object?> rows, {String? next}) => http.Response(
  jsonEncode({'models': rows, 'has_more': next != null, 'next_cursor': next}),
  200,
);

void main() {
  testWidgets(
    'live pages and out-of-order searches only add the chosen endpoint and its schema',
    (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      await tester.runAsync(() => settings.loaded);
      addTearDown(settings.dispose);
      final config = ProviderConfig.defaultsFor(
        'fal',
      ).copyWith(enabled: true, models: ['personal/existing']);
      await settings.setProviderConfig('fal', config);
      const id = 'studio/new-release';
      final stale = Completer<http.Response>();
      final calls = <Uri>[];
      final client = MockClient((request) async {
        final uri = request.url;
        calls.add(uri);
        expect(request.method, 'GET');
        expect(uri.origin, 'https://api.fal.ai');
        expect(request.headers['Authorization'], isNull);
        final query = uri.queryParameters;
        if (query['endpoint_id'] == id) {
          expect(query['expand'], 'openapi-3.0');
          return _page([
            {
              ..._row(id, 'image-to-video'),
              'openapi': {
                'paths': {
                  '/canonical/model/requests/{request_id}': {
                    'get': {
                      'responses': {
                        '200': {
                          'content': {
                            'application/json': {
                              'schema': {
                                'type': 'object',
                                'properties': {
                                  'video': {
                                    'type': 'object',
                                    'properties': {
                                      'url': {'type': 'string'},
                                    },
                                  },
                                },
                              },
                            },
                          },
                        },
                      },
                    },
                  },
                  '/canonical/model': {
                    'post': {
                      'requestBody': {
                        'content': {
                          'application/json': {
                            'schema': {r'$ref': '#/components/schemas/Input'},
                          },
                        },
                      },
                    },
                  },
                },
                'components': {
                  'schemas': {
                    'Input': {
                      'properties': {
                        'start_image_url': {'type': 'string'},
                        'end_image_url': {'type': 'string'},
                        'with_sound': {'type': 'boolean', 'default': false},
                        'duration': {
                          'type': 'string',
                          'enum': ['3', '6'],
                        },
                      },
                      'required': ['start_image_url'],
                    },
                  },
                },
              },
            },
          ]);
        }
        expect(query['status'], 'active');
        if (query['q'] == 'older') return stale.future;
        if (query['q'] == 'new') return _page([_row(id, 'image-to-video')]);
        if (query['cursor'] == 'page-two') {
          return _page([_row('studio/next', 'text-to-image')]);
        }
        return _page([
          _row('fal-ai/flux/schnell', 'text-to-image'),
          _row('fal-ai/nano-banana/edit', 'image-to-image'),
          _row('studio/audio', 'text-to-audio'),
        ], next: 'page-two');
      });
      addTearDown(client.close);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FalModelPicker(
                config: config,
                desktop: false,
                catalog: FalModelDiscovery(client),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      ConfigurableAvatar avatarFor(String id) =>
          tester.widget<ConfigurableAvatar>(
            find.descendant(
              of: find.byKey(ValueKey(id)),
              matching: find.byType(ConfigurableAvatar),
            ),
          );
      expect(
        avatarFor('fal-ai/flux/schnell').fallbackAsset,
        'assets/icons/flux.svg',
      );
      expect(
        avatarFor('fal-ai/nano-banana/edit').fallbackAsset,
        'assets/icons/gemini-color.svg',
      );
      expect(avatarFor('fal-ai/nano-banana/edit').withBackground, isFalse);
      expect(find.byTooltip('Output Modes: Image'), findsNWidgets(2));
      expect(find.byTooltip('Input Modes: Image'), findsOneWidget);
      expect(find.text('studio/audio'), findsNothing);
      await tester.tap(find.text('Load more models'));
      await tester.pumpAndSettle();
      expect(find.text('studio/next'), findsOneWidget);
      final input = find.byType(EditableText);
      await tester.enterText(input, 'older');
      await tester.pump(const Duration(milliseconds: 360));
      await tester.enterText(input, 'new');
      await tester.pump(const Duration(milliseconds: 360));
      await tester.pump();
      stale.complete(_page([_row('studio/obsolete', 'text-to-image')]));
      await tester.pumpAndSettle();
      expect(find.text('studio/obsolete'), findsNothing);
      expect(avatarFor(id).fallbackAsset, isNull);
      expect(avatarFor(id).name, 'new-release');
      expect(find.byTooltip('Output Modes: Video'), findsOneWidget);
      expect(find.byTooltip('Output Modes: Image'), findsNothing);
      expect(settings.getProviderConfig('fal').models, ['personal/existing']);
      expect(
        calls.any((uri) => uri.queryParameters.containsKey('expand')),
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey(id)));
      await tester.pumpAndSettle();
      final restored = ProviderConfig.fromJson(
        settings.getProviderConfig('fal').toJson(),
      );
      expect(restored.models, ['personal/existing', id]);
      expect(
        restored.modelOverrides[id]['falEndpoint'],
        isNot(contains('openapi')),
      );
      final caps = resolveMediaModel(
        restored,
        id,
        MediaMode.video,
      )!.capabilities;
      expect(caps.durations, [3, 6]);
      final sound = caps.platformOptions.singleWhere(
        (p) => p.key == 'with_sound',
      );
      expect(sound.defaultValue, false);
      expect(sound.storageKey, 'fal:with_sound');
      expect(caps.requiresFirstFrame, isTrue);
      expect(caps.maxReferences, 2);
      expect(resolveMediaModel(restored, id, MediaMode.image), isNull);
      await settings.setModelEnabled('fal', id, false);
      await settings.togglePinModel('fal', id);
      await settings.setCreationModel(CreationModelSlot.video, (
        providerKey: 'fal',
        modelId: id,
      ));
      await tester.tap(find.byKey(const ValueKey(id)));
      await tester.pumpAndSettle();
      final removed = settings.getProviderConfig('fal');
      expect(removed.models, ['personal/existing']);
      expect(removed.modelOverrides, isNot(contains(id)));
      expect(removed.disabledModels, isNot(contains(id)));
      expect(settings.isModelPinned('fal', id), isFalse);
      expect(settings.creationModel(CreationModelSlot.video), isNull);
    },
  );
}
