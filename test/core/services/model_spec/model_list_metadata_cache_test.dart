import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/model_spec/model_list_metadata_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ModelListMetadataCache cache;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cache = ModelListMetadataCache();
  });

  test('reads the first valid limit and price on each side', () async {
    final cfg = _cfg('relay');
    final replace = await cache.startRefresh(cfg);
    await replace([
      (
        id: 'top-level',
        json: {
          'context_length': '262144',
          'context_window': 64000,
          'max_output': 0,
          'max_output_tokens': 16384,
          'maxOutput': 4096,
          'pricing': {
            'prompt': '0.0000025',
            'completion': '-0.1',
            'input': 2,
            'output': '5.5',
          },
          'cost': {'input': 12, 'output': 6},
        },
      ),
      (
        id: 'nested',
        json: {
          'context_length': 'abc',
          'context_window': 0,
          'max_context_length': 10.5,
          'max_context_window': -1,
          'max_completion_tokens': 'Infinity',
          'top_provider': {
            'context_length': 128000,
            'max_completion_tokens': '16384',
          },
          'limit': {'context': 64000, 'output': 8192},
        },
      ),
      (
        id: 'lower-priority',
        json: {
          'top_provider': 'invalid',
          'limit': {'context': 256000, 'output': 8192},
          'pricing': {'prompt': 'NaN', 'input': -1, 'completion': 'Infinity'},
          'cost': {'input': 0},
          'inputTokenLimit': 64000,
          'outputTokenLimit': 2048,
        },
      ),
      (
        id: 'google',
        json: {
          'limit': 3,
          'inputTokenLimit': 1023,
          'input_token_limit': 10000000,
          'outputTokenLimit': 10000001,
          'output_token_limit': '1024.0',
        },
      ),
      (
        id: 'nonfinite',
        json: {
          'context_length': double.nan,
          'context_window': double.infinity,
          'max_output': 1024.5,
          'max_output_tokens': true,
          'pricing': {'prompt': '1e308', 'output': double.negativeInfinity},
        },
      ),
    ]);
    expect(cache.lookup(cfg, 'top-level'), (
      contextWindow: 262144,
      maxOutput: 16384,
      pricing: const ModelPricing(input: 2.5, output: 5.5),
    ));
    expect(cache.lookup(cfg, 'nested'), (
      contextWindow: 128000,
      maxOutput: 16384,
      pricing: null,
    ));
    expect(cache.lookup(cfg, 'lower-priority'), (
      contextWindow: 256000,
      maxOutput: 8192,
      pricing: const ModelPricing(input: 0),
    ));
    expect(cache.lookup(cfg, 'google'), (
      contextWindow: 10000000,
      maxOutput: 1024,
      pricing: null,
    ));
    expect(cache.lookup(cfg, 'nonfinite'), isNull);
  });

  test('converts Vercel per-token rates to per-million rates', () async {
    final cfg = _cfg(
      'vercel',
    ).copyWith(baseUrl: 'https://ai-gateway.vercel.sh/v1');
    await (await cache.startRefresh(cfg))([
      (
        id: 'openai/gpt',
        json: {
          'pricing': {'input': '0.0000025', 'output': 0.00001},
        },
      ),
    ]);
    expect(
      cache.lookup(cfg, 'openai/gpt')?.pricing,
      const ModelPricing(input: 2.5, output: 10),
    );
  });

  test(
    'keeps exact IDs separate and replaces only the listed provider',
    () async {
      const id = 'relay/[times] Model';
      const lowercase = 'relay/[times] model';
      const invalidCase = 'relay/[times] mOdel';
      final first = _cfg('first');
      final second = _cfg('second');
      await (await cache.startRefresh(first))([
        (id: ' $id  ', json: {'context_window': 128000}),
        (id: lowercase, json: {'context_window': 64000}),
        (id: invalidCase, json: {'context_window': 0}),
      ]);
      await (await cache.startRefresh(second))([
        (id: id, json: {'context_window': 262144}),
      ]);
      expect(cache.lookup(first, id)?.contextWindow, 128000);
      expect(cache.lookup(first, lowercase)?.contextWindow, 64000);
      expect(cache.lookup(first, invalidCase), isNull);
      expect(cache.lookup(first, id.toUpperCase())?.contextWindow, 128000);
      expect(cache.lookup(first, '[times] Model'), isNull);
      expect(cache.lookup(first, 'Model'), isNull);
      expect(cache.lookup(second, id)?.contextWindow, 262144);

      final beforeReplacement = ModelListMetadataCache();
      await beforeReplacement.ensureLoaded();
      expect(beforeReplacement.lookup(first, invalidCase), isNull);
      expect(beforeReplacement.lookup(first, lowercase)?.contextWindow, 64000);

      final before = cache.version;
      await (await cache.startRefresh(first))([
        (id: 'new-id', json: {'max_output': 4096}),
      ]);
      expect(cache.version, greaterThan(before));
      expect(cache.lookup(first, id), isNull);
      expect(cache.lookup(first, 'new-id')?.maxOutput, 4096);
      expect(cache.lookup(second, id)?.contextWindow, 262144);

      final reloaded = ModelListMetadataCache();
      await reloaded.ensureLoaded();
      expect(reloaded.lookup(first, 'NEW-ID')?.maxOutput, 4096);
      expect(reloaded.lookup(first, id), isNull);
      expect(reloaded.lookup(second, id)?.contextWindow, 262144);
      await reloaded.clearProvider(second.id);

      final afterRemoval = ModelListMetadataCache();
      await afterRemoval.ensureLoaded();
      expect(afterRemoval.lookup(second, id), isNull);
      expect(afterRemoval.lookup(first, 'new-id')?.maxOutput, 4096);
    },
  );

  test(
    'out-of-order responses and deleted providers cannot restore stale metadata',
    () async {
      final cfg = _cfg('relay');
      final earlier = await cache.startRefresh(cfg);
      final later = await cache.startRefresh(cfg);
      await later([
        (id: 'model', json: {'context_window': 262144}),
      ]);
      await earlier([
        (id: 'model', json: {'context_window': 64000}),
      ]);
      expect(cache.lookup(cfg, 'model')?.contextWindow, 262144);

      final beforeRemoval = await cache.startRefresh(cfg);
      await cache.clearProvider(cfg.id);
      await beforeRemoval([
        (id: 'model', json: {'context_window': 64000}),
      ]);
      expect(cache.lookup(cfg, 'model'), isNull);
    },
  );

  test(
    'persisted metadata stays scoped to the original listing endpoint',
    () async {
      final original = _cfg('relay');
      await (await cache.startRefresh(original))([
        (
          id: 'model',
          json: {
            'context_window': 262144,
            'cost': {'input': 1.25},
          },
        ),
      ]);
      final restored = original.copyWith(
        baseUrl: 'https://different.example.com',
      );
      final reloaded = ModelListMetadataCache();
      await reloaded.ensureLoaded();
      expect(reloaded.lookup(restored, 'model'), isNull);
      expect(reloaded.lookup(original, 'model')?.contextWindow, 262144);
      expect(
        reloaded.lookup(original, 'model')?.pricing,
        const ModelPricing(input: 1.25),
      );
    },
  );
}

ProviderConfig _cfg(String id) => ProviderConfig(
  id: id,
  name: id,
  enabled: true,
  apiKey: '',
  baseUrl: 'https://proxy.example.com',
);
