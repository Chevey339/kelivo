import '../../../support/business_test_harness.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/widgets/token_detail_popup.dart';
import 'package:Kelivo/features/chat/widgets/token_display_widget.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

class _PricedSettings extends SettingsProvider {
  _PricedSettings() : super(createBusinessTestPreferences());

  @override
  ProviderConfig getProviderConfig(String key, {String? defaultName}) {
    return ProviderConfig(
      id: key,
      enabled: true,
      name: key,
      apiKey: '',
      baseUrl: 'https://api.example.com/v1',
      modelOverrides: {
        'priced-model': const ModelSpecOverride(
          pricing: ModelPricing(input: 1, output: 5, currency: 'USD'),
        ).toJson(),
      },
    );
  }
}

Widget _harness({
  required Widget child,
  SettingsProvider? settings,
  double textScale = 1,
  EdgeInsets? padding,
  EdgeInsets? viewInsets,
}) {
  return ChangeNotifierProvider<SettingsProvider>.value(
    value: settings ?? SettingsProvider(createBusinessTestPreferences()),
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          padding: padding,
          viewInsets: viewInsets,
        ),
        child: child!,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

const _fullStats = TokenDisplayWidget(
  totalTokens: 3000,
  promptTokens: 1000,
  completionTokens: 2000,
  cachedTokens: 100,
  reasoningTokens: 500,
  cacheWriteTokens: 100,
  durationMs: 5000,
  firstTokenMs: 1250,
  providerId: 'openai',
  modelId: 'priced-model',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'iOS popup stays open across repeated window metrics notifications',
    (tester) async {
      final settings = _PricedSettings();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        _harness(
          settings: settings,
          child: const Center(child: _fullStats),
        ),
      );

      await tester.tap(find.byType(TokenDisplayWidget));
      await tester.pump();
      expect(find.byType(TokenDetailPopup), findsOneWidget);

      // iOS can send a metrics notification just after the opening tap,
      // without changing the window geometry.
      tester.binding.handleMetricsChanged();
      await tester.pumpAndSettle();
      expect(find.byType(TokenDetailPopup), findsOneWidget);

      tester.binding.handleMetricsChanged();
      await tester.pumpAndSettle();
      expect(find.byType(TokenDetailPopup), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(TokenDetailPopup), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('open popup adapts to window resize and keyboard insets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 700);
    tester.view.padding = const FakeViewPadding(top: 30, bottom: 20);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
    final settings = _PricedSettings();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      _harness(
        settings: settings,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Align(alignment: Alignment.bottomRight, child: _fullStats),
        ),
      ),
    );
    await tester.tap(find.byType(TokenDisplayWidget));
    await tester.pumpAndSettle();
    final initialPopup = tester.getRect(find.byType(TokenDetailPopup));

    tester.view.physicalSize = const Size(700, 400);
    await tester.pumpAndSettle();
    expect(find.byType(TokenDetailPopup), findsOneWidget);
    final resizedPopup = tester.getRect(find.byType(TokenDetailPopup));
    final resizedAnchor = tester.getRect(find.byType(TokenDisplayWidget));
    expect(resizedPopup, isNot(initialPopup));
    expect(resizedAnchor.top - resizedPopup.bottom, closeTo(8, 0.01));
    expect(resizedPopup.top, greaterThanOrEqualTo(38));
    expect(resizedPopup.bottom, lessThanOrEqualTo(372));
    expect(resizedPopup.left, greaterThanOrEqualTo(8));
    expect(resizedPopup.right, lessThanOrEqualTo(692));

    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();
    expect(find.byType(TokenDetailPopup), findsOneWidget);
    final keyboardPopup = tester.getRect(find.byType(TokenDetailPopup));
    expect(keyboardPopup.top, greaterThanOrEqualTo(38));
    expect(keyboardPopup.bottom, lessThanOrEqualTo(192));
    expect(keyboardPopup.left, greaterThanOrEqualTo(8));
    expect(keyboardPopup.right, lessThanOrEqualTo(692));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('popup updates keyboard bounds without moving its anchor', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 700);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    final settings = _PricedSettings();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      _harness(
        settings: settings,
        child: const Stack(
          children: [Positioned(top: 170, right: 16, child: _fullStats)],
        ),
      ),
    );
    await tester.tap(find.byType(TokenDisplayWidget));
    await tester.pumpAndSettle();
    final anchor = tester.getRect(find.byType(TokenDisplayWidget));
    final beforePopup = tester.getRect(find.byType(TokenDetailPopup));
    expect(beforePopup.bottom, greaterThan(332));

    tester.view.viewInsets = const FakeViewPadding(bottom: 360);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(TokenDisplayWidget)), anchor);
    expect(find.byType(TokenDetailPopup), findsOneWidget);
    final popup = tester.getRect(find.byType(TokenDetailPopup));
    expect(popup.top, greaterThanOrEqualTo(8));
    expect(popup.bottom, lessThanOrEqualTo(332));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'popup follows message layout changes without rebuilding the token label',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final settings = _PricedSettings();
      final imageHeight = ValueNotifier<double>(270);
      addTearDown(settings.dispose);
      addTearDown(imageHeight.dispose);
      await tester.pumpWidget(
        _harness(
          settings: settings,
          textScale: 1.2,
          child: Padding(
            padding: const EdgeInsets.only(top: 30, left: 16, right: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: imageHeight,
                  builder: (_, height, _) =>
                      SizedBox(width: double.infinity, height: height),
                ),
                _fullStats,
              ],
            ),
          ),
        ),
      );
      TestGesture? mouse;
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(find.byType(TokenDisplayWidget)));
        await tester.pump(const Duration(milliseconds: 201));
      } else {
        await tester.tap(find.byType(TokenDisplayWidget));
      }
      await tester.pumpAndSettle();
      final tokenWidget = tester.widget(find.byType(TokenDisplayWidget));
      final beforeAnchor = tester.getRect(find.byType(TokenDisplayWidget));
      final beforePopup = tester.getRect(find.byType(TokenDetailPopup));
      expect(beforeAnchor.top - beforePopup.bottom, closeTo(8, 0.01));

      // Only the preceding image's size changes, as when its bytes load.
      imageHeight.value += 100;
      await tester.pump();
      final afterAnchor = tester.getRect(find.byType(TokenDisplayWidget));
      final afterPopup = tester.getRect(find.byType(TokenDetailPopup));
      expect(tester.widget(find.byType(TokenDisplayWidget)), same(tokenWidget));
      expect(afterAnchor.top - beforeAnchor.top, closeTo(100, 0.01));
      expect(afterPopup.top - beforePopup.top, closeTo(100, 0.01));
      expect(afterAnchor.top - afterPopup.bottom, closeTo(8, 0.01));

      // Moving near the top must also re-evaluate the side and safe bounds.
      imageHeight.value = 0;
      await tester.pump();
      final topAnchor = tester.getRect(find.byType(TokenDisplayWidget));
      final topPopup = tester.getRect(find.byType(TokenDetailPopup));
      expect(topPopup.top - topAnchor.bottom, closeTo(8, 0.01));
      expect(topPopup.top, greaterThanOrEqualTo(8));
      expect(topPopup.bottom, lessThanOrEqualTo(692));
      expect(tester.takeException(), isNull);
      await mouse?.removePointer();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.macOS}),
  );

  testWidgets('full popup with 1.2x text stays inside the viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final settings = _PricedSettings();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      _harness(
        settings: settings,
        textScale: 1.2,
        child: const Stack(
          children: [Positioned(top: 197, right: 16, child: _fullStats)],
        ),
      ),
    );
    await tester.tap(find.byType(TokenDisplayWidget));
    await tester.pumpAndSettle();
    final popup = tester.getRect(find.byType(TokenDetailPopup));
    expect(popup.top, greaterThanOrEqualTo(0));
    expect(popup.bottom, lessThanOrEqualTo(700));
    expect(popup.left, greaterThanOrEqualTo(0));
    expect(popup.right, lessThanOrEqualTo(400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('popup dismisses on outside tap, scroll, and message removal', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final settings = _PricedSettings();
    final scroll = ScrollController();
    addTearDown(settings.dispose);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      _harness(
        settings: settings,
        child: SingleChildScrollView(
          controller: scroll,
          child: const SizedBox(
            height: 1200,
            child: Stack(
              children: [Positioned(top: 300, right: 16, child: _fullStats)],
            ),
          ),
        ),
      ),
    );

    Future<void> openPopup() async {
      await tester.tap(find.byType(TokenDisplayWidget));
      await tester.pumpAndSettle();
      expect(find.byType(TokenDetailPopup), findsOneWidget);
    }

    await openPopup();
    await tester.tapAt(const Offset(20, 650));
    await tester.pumpAndSettle();
    expect(find.byType(TokenDetailPopup), findsNothing);

    await openPopup();
    scroll.jumpTo(50);
    await tester.pumpAndSettle();
    expect(find.byType(TokenDetailPopup), findsNothing);

    await openPopup();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(find.byType(TokenDetailPopup), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (
      size: const Size(400, 400),
      top: 350.0,
      left: false,
      scale: 1.2,
      insets: 0.0,
    ),
    (
      size: const Size(320, 500),
      top: 200.0,
      left: true,
      scale: 2.0,
      insets: 0.0,
    ),
    (
      size: const Size(400, 180),
      top: 70.0,
      left: false,
      scale: 2.0,
      insets: 0.0,
    ),
    (
      size: const Size(400, 700),
      top: 197.0,
      left: false,
      scale: 1.2,
      insets: 280.0,
    ),
  ]) {
    testWidgets(
      'scaled popup fits safe viewport ${scenario.size} with inset ${scenario.insets}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = scenario.size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final settings = _PricedSettings();
        addTearDown(settings.dispose);
        const padding = EdgeInsets.symmetric(vertical: 16);
        await tester.pumpWidget(
          _harness(
            settings: settings,
            textScale: scenario.scale,
            padding: padding,
            viewInsets: EdgeInsets.only(bottom: scenario.insets),
            child: Stack(
              children: [
                Positioned(
                  top: scenario.top,
                  left: scenario.left ? 16 : null,
                  right: scenario.left ? null : 16,
                  child: _fullStats,
                ),
              ],
            ),
          ),
        );
        TestGesture? mouse;
        if (defaultTargetPlatform == TargetPlatform.macOS) {
          mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
          await mouse.addPointer(location: Offset.zero);
          await mouse.moveTo(tester.getCenter(find.byType(TokenDisplayWidget)));
          await tester.pump(const Duration(milliseconds: 201));
        } else {
          await tester.tap(find.byType(TokenDisplayWidget));
        }

        void expectInsideViewport() {
          final popup = tester.getRect(find.byType(TokenDetailPopup));
          expect(popup.top, greaterThanOrEqualTo(padding.top + 8));
          expect(
            popup.bottom,
            lessThanOrEqualTo(
              scenario.size.height - padding.bottom - scenario.insets - 8,
            ),
          );
          expect(popup.left, greaterThanOrEqualTo(8));
          expect(popup.right, lessThanOrEqualTo(scenario.size.width - 8));
        }

        await tester.pump();
        expectInsideViewport();
        await tester.pump(const Duration(milliseconds: 90));
        expectInsideViewport();
        await tester.pumpAndSettle();
        expectInsideViewport();

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
        final popup = tester.getRect(find.byType(TokenDetailPopup));
        final cost = tester.getRect(find.textContaining(r'$'));
        expect(cost.top, greaterThanOrEqualTo(popup.top));
        expect(cost.bottom, lessThanOrEqualTo(popup.bottom));
        expect(tester.takeException(), isNull);
        await mouse?.removePointer();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }),
    );
  }

  testWidgets('shows first-token latency and speed for the whole generation', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      _harness(
        settings: settings,
        child: const TokenDetailPopup(
          completionTokens: 30,
          reasoningTokens: 20,
          totalCompletionTokens: 50,
          durationMs: 5000,
          firstTokenMs: 1250,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('1.25s (first token)'), findsOneWidget);
    expect(find.text('10.0 tok/s'), findsOneWidget);
    expect(find.text('5.0s'), findsOneWidget);
    expect(find.text('30 tokens'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('omits unknown latency and speed without positive duration', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      _harness(
        settings: settings,
        child: const TokenDetailPopup(completionTokens: 30, durationMs: 0),
      ),
    );
    await tester.pump();

    expect(find.textContaining('(first token)'), findsNothing);
    expect(find.textContaining('tok/s'), findsNothing);
    expect(find.text('30 tokens'), findsOneWidget);
  });

  testWidgets(
    'tap or hover opens the popup even with only a zero-ms first token',
    (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        _harness(
          settings: settings,
          child: const Center(
            child: TokenDisplayWidget(totalTokens: 0, firstTokenMs: 0),
          ),
        ),
      );
      await tester.pump();

      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(find.byType(TokenDisplayWidget)));
        await tester.pump(const Duration(milliseconds: 201));
        addTearDown(mouse.removePointer);
      } else {
        await tester.tap(find.byType(TokenDisplayWidget));
      }
      await tester.pumpAndSettle();

      expect(find.text('0.00s (first token)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.macOS}),
  );

  testWidgets('shows reasoning and cache write rows when non-zero', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _harness(
        settings: settings,
        child: const TokenDetailPopup(
          promptTokens: 10,
          completionTokens: 4,
          reasoningTokens: 7,
          cacheWriteTokens: 3,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('7 tokens'), findsOneWidget);
    expect(find.text('3 cache write tokens'), findsOneWidget);
    expect(find.text(r'$0'), findsNothing);
  });

  testWidgets('shows a formatted cost row when the model has pricing', (
    tester,
  ) async {
    final settings = _PricedSettings();
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _harness(
        settings: settings,
        child: const TokenDetailPopup(
          promptTokens: 1000,
          completionTokens: 2000,
          providerId: 'openai',
          modelId: 'priced-model',
        ),
      ),
    );
    await tester.pump();

    expect(find.text(r'$0.011'), findsOneWidget);
  });

  testWidgets('omits the cost row without provider, model, or pricing', (
    tester,
  ) async {
    final settings = _PricedSettings();
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _harness(
        settings: settings,
        child: const TokenDetailPopup(
          promptTokens: 1000,
          completionTokens: 2000,
          providerId: 'openai',
          modelId: 'unknown-model',
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining(r'$'), findsNothing);

    await tester.pumpWidget(
      _harness(
        settings: settings,
        child: const TokenDetailPopup(
          promptTokens: 1000,
          completionTokens: 2000,
          modelId: 'priced-model',
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining(r'$'), findsNothing);
  });
}
