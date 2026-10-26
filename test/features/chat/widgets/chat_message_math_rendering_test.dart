import 'dart:ui' as ui;

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/services/tts/tts_playback_models.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/business_test_harness.dart';
import '../../../support/markdown_backdrop_host.dart';

const _prefix = r'''普通文字，==这段应该高亮==，==**这段应该加粗并高亮**==。
行内代码 `==这里应保留等号==`。

```math
\frac{1}{2} + \sqrt{x^2+y^2}
```

> [!NOTE] 这是我的自定义标题
> 这是提示框正文。
> - 第一项
> - 第二项

![SVG测试](data:image/svg+xml,%3Csvg%20xmlns=%22http://www.w3.org/2000/svg%22%20width=%22160%22%20height=%2280%22%3E%3Crect%20width=%22160%22%20height=%2280%22%20rx=%2212%22%20fill=%22%232563eb%22/%3E%3Ccircle%20cx=%2280%22%20cy=%2240%22%20r=%2222%22%20fill=%22white%22/%3E%3C/svg%3E)

''';

String _source(int repeats) =>
    _prefix + List.filled(repeats, r'$x^2+y^2=z^2$').join('\n');

class _IdleTtsProvider extends ChangeNotifier implements TtsProvider {
  @override
  TtsPlaybackState get playbackState => const TtsPlaybackState();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final wallpaper in [false, true]) {
    testWidgets(
      'user and streaming assistant paint every repeated formula, wallpaper=$wallpaper',
      (tester) async {
        tester.view.physicalSize = Size(
          defaultTargetPlatform == TargetPlatform.macOS ? 1000 : 390,
          3000,
        );
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues(const {});
        var assistantText =
            '```math\n'
            r'\frac{1}{2} + \sqrt{x^2+y^2}';
        var streaming = true;
        late StateSetter rebuild;
        const captureKey = ValueKey('messages');
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) =>
                    SettingsProvider(createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider<TtsProvider>(
                create: (_) => _IdleTtsProvider(),
              ),
              ChangeNotifierProvider(
                create: (_) =>
                    UserProvider(preferences: createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider(create: (_) => ToolApprovalService()),
              ChangeNotifierProvider(
                create: (_) => AskUserInteractionService(),
              ),
            ],
            child: MaterialApp(
              theme: wallpaper ? ThemeData.dark() : ThemeData.light(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: RepaintBoundary(
                  key: captureKey,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      rebuild = setState;
                      final messages = SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final role in ['user', 'assistant'])
                              ChatMessageWidget(
                                key: ValueKey(role),
                                message: ChatMessage(
                                  id: role,
                                  role: role,
                                  content: role == 'user'
                                      ? _source(20)
                                      : assistantText,
                                  conversationId: 'math-regression',
                                  isStreaming: role == 'assistant' && streaming,
                                ),
                                showModelIcon: false,
                              ),
                          ],
                        ),
                      );
                      return ColoredBox(
                        color: Theme.of(context).colorScheme.surface,
                        child: wallpaper
                            ? MarkdownWallpaperTestHost(child: messages)
                            : messages,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(Math), findsNWidgets(21));
        expect(tester.takeException(), isNull);

        for (final repeats in [2, 20]) {
          rebuild(() => assistantText = _source(repeats));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));
          final formulas = tester.widgetList<Math>(find.byType(Math)).toList();
          expect(formulas, hasLength(22 + repeats));
          expect(
            formulas.map((math) => math.ast).toSet(),
            hasLength(formulas.length),
          );
          expect(tester.takeException(), isNull);
        }

        rebuild(() => streaming = false);
        await tester.pumpAndSettle();
        expect(find.byType(Math), findsNWidgets(42));

        // Widget counts alone miss blank formulas: each formula's painted box
        // must contain contrasting ink, including both copies of the fence.
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(captureKey),
        );
        final image = boundary.toImageSync();
        final pixels = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        try {
          for (final element in find.byType(Math).evaluate()) {
            final box = element.findRenderObject()! as RenderBox;
            final origin = box.localToGlobal(Offset.zero, ancestor: boundary);
            final rect = origin & box.size;
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.bottom, lessThanOrEqualTo(image.height));
            var inkEdges = 0;
            for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++) {
              int? previous;
              for (var x = rect.left.ceil(); x < rect.right.floor(); x++) {
                final index = (y * image.width + x) * 4;
                final brightness =
                    (pixels!.getUint8(index) +
                        pixels.getUint8(index + 1) +
                        pixels.getUint8(index + 2)) ~/
                    3;
                if (previous != null && (brightness - previous).abs() > 16) {
                  inkEdges++;
                }
                previous = brightness;
              }
            }
            expect(
              inkEdges,
              greaterThan(20),
              reason: 'Formula at $rect must paint visible ink',
            );
          }
        } finally {
          image.dispose();
        }
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.macOS,
        TargetPlatform.android,
      }),
    );
  }
}
