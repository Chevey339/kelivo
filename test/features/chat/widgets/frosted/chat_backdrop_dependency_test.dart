import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/widgets/frosted/chat_frosted_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../../support/business_test_harness.dart';

void main() {
  testWidgets('keyboard metrics do not rebuild a static backdrop consumer', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    final assistants = AssistantProvider(
      preferences: createBusinessTestPreferences(),
    );
    await settings.loaded;
    await assistants.loaded;
    addTearDown(settings.dispose);
    addTearDown(assistants.dispose);
    final metrics = ValueNotifier(
      const MediaQueryData(size: Size(400, 800), devicePixelRatio: 3),
    );
    addTearDown(metrics.dispose);
    var builds = 0;
    late ChatBackdropSpec spec;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: assistants),
        ],
        child: MaterialApp(
          home: ValueListenableBuilder<MediaQueryData>(
            valueListenable: metrics,
            child: _SpecProbe(
              onBuild: (value) {
                builds++;
                spec = value;
              },
            ),
            builder: (_, value, child) =>
                MediaQuery(data: value, child: child!),
          ),
        ),
      ),
    );
    final initialBuilds = builds;
    for (var inset = 20.0; inset <= 300; inset += 20) {
      metrics.value = metrics.value.copyWith(
        viewInsets: EdgeInsets.only(bottom: inset),
        padding: const EdgeInsets.only(top: 24),
      );
      await tester.pump();
    }
    expect(builds, initialBuilds);
    expect(spec.logicalSize, const Size(400, 800));
    expect(spec.dpr, 3);

    metrics.value = metrics.value.copyWith(size: const Size(800, 400));
    await tester.pump();
    expect(spec.logicalSize, const Size(800, 400));
    expect(builds, initialBuilds + 1);

    metrics.value = metrics.value.copyWith(devicePixelRatio: 2);
    await tester.pump();
    expect(spec.dpr, 2);
    metrics.value = metrics.value.copyWith(disableAnimations: true);
    await tester.pump();
    expect(builds, initialBuilds + 3);
  });
}

class _SpecProbe extends StatelessWidget {
  const _SpecProbe({required this.onBuild});

  final ValueChanged<ChatBackdropSpec> onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild(ChatBackdropSpec.resolve(context));
    return const SizedBox.shrink();
  }
}
