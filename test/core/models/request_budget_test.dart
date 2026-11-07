import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/request_budget.dart';
import 'package:Kelivo/core/models/image_context.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/utils/image_context_budget_error.dart';
import '../../support/business_test_harness.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

ProviderConfig config() => ProviderConfig(
  id: 'test',
  enabled: true,
  name: 'Test',
  apiKey: '',
  baseUrl: 'https://example.test',
  providerType: ProviderKind.openai,
  requestBudget: const RequestBudgetOverrides(
    totalImageBytes: 64 * RequestBudget.mib,
  ),
  modelOverrides: const {
    'vision': {
      'requestBudget': {'imageCount': 100},
    },
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'provider and model limits inherit independently and survive storage',
    () async {
      final cfg = config();
      final harness = await createBusinessTestHarness(
        initial: {
          'provider_configs_v1': jsonEncode({cfg.id: cfg.toJson()}),
        },
      );
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      addTearDown(settings.dispose);
      final restored = settings.getProviderConfig(cfg.id);
      final budget = restored.requestBudgetForModel('vision');
      expect(budget.totalImageBytes, 64 * RequestBudget.mib);
      expect(budget.imageCount, 100);
      expect(budget.singleImageBytes, 5 * RequestBudget.mib);
      expect(budget.bodyBytes, 28 * RequestBudget.mib);
      expect(restored.requestBudgetForModel('other').imageCount, 24);
      await settings.setProviderConfig(
        cfg.id,
        restored.copyWith(
          requestBudget: const RequestBudgetOverrides(
            bodyBytes: 72 * RequestBudget.mib,
          ),
        ),
      );
      await harness.preferences.load();
      final reloaded = SettingsProvider(harness.preferences);
      await reloaded.loaded;
      addTearDown(reloaded.dispose);
      expect(
        reloaded
            .getProviderConfig(cfg.id)
            .requestBudgetForModel('vision')
            .bodyBytes,
        72 * RequestBudget.mib,
      );
      expect(
        reloaded
            .getProviderConfig(cfg.id)
            .requestBudgetForModel('vision')
            .imageCount,
        100,
      );
    },
  );

  test(
    'Google retains its own defaults; invalid stored limits do not disable checks',
    () {
      final cfg = config().copyWith(
        providerType: ProviderKind.google,
        requestBudget: const RequestBudgetOverrides(),
      );
      final budget = cfg.requestBudgetForModel('other');
      expect(budget.totalImageBytes, 14 * RequestBudget.mib);
      expect(budget.bodyBytes, 20000000);
      final invalid = RequestBudgetOverrides.fromJson({
        'singleImageBytes': -1,
        'imageCount': 0,
        'bodyBytes': 'unlimited',
        'totalImageBytes': 1.5,
      });
      expect(invalid.isEmpty, isTrue);
    },
  );

  test(
    'Chinese diagnostics distinguish body, count and pinned image failures',
    () async {
      final l = await AppLocalizations.delegate.load(const Locale('zh'));
      final body = formatImageContextBudgetError(
        const ImageContextBudgetException(
          kind: ImageContextBudgetKind.requestBody,
          actual: 101,
          limit: 100,
        ),
        l,
      );
      expect(body, contains('本地预检'));
      expect(body, contains('101 字节'));
      expect(body, contains('100 字节'));
      expect(body, contains('工具记录'));
      expect(body, isNot(contains('取消固定')));
      final image = formatImageContextBudgetError(
        const ImageContextBudgetException(
          kind: ImageContextBudgetKind.singleImage,
          actual: 5,
          limit: 4,
          imageIndex: 2,
          pinned: true,
        ),
        l,
      );
      expect(image, contains('第 2 张'));
      expect(image, contains('已固定'));
      expect(image, contains('图片上下文'));
      final count = formatImageContextBudgetError(
        const ImageContextBudgetException(
          kind: ImageContextBudgetKind.imageCount,
          actual: 25,
          limit: 24,
        ),
        l,
      );
      expect(count, contains('25 张'));
      expect(count, isNot(contains('MiB')));
    },
  );
}
