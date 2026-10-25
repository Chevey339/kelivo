import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/instruction_injection_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/services/context_usage_service.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/context_usage_ring.dart';

import '../../../support/business_test_harness.dart';

class _RecordingUsage extends ContextUsageService {
  _RecordingUsage({
    required super.chatService,
    required super.settings,
    required super.assistants,
    required super.instructions,
    required super.worldBooks,
  });

  final drafts = <String, String>{};

  @override
  void updateDraft(String conversationId, String text) {
    drafts[conversationId] = text;
    super.updateDraft(conversationId, text);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<
    ({
      SettingsProvider settings,
      AssistantProvider assistants,
      _RecordingUsage usage,
    })
  >
  createProviders() async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    final assistants = AssistantProvider(
      preferences: createBusinessTestPreferences(),
    );
    await settings.loaded;
    await assistants.loaded;
    final instructions = InstructionInjectionProvider(
      preferences: createBusinessTestPreferences(),
    );
    final worldBooks = WorldBookProvider(
      preferences: createBusinessTestPreferences(),
    );
    final usage = _RecordingUsage(
      chatService: ChatService(),
      settings: settings,
      assistants: assistants,
      instructions: instructions,
      worldBooks: worldBooks,
    );
    addTearDown(assistants.dispose);
    addTearDown(settings.dispose);
    addTearDown(instructions.dispose);
    addTearDown(worldBooks.dispose);
    return (settings: settings, assistants: assistants, usage: usage);
  }

  Future<void> pumpBar(
    WidgetTester tester, {
    required SettingsProvider settings,
    required AssistantProvider assistants,
    required ContextUsageService usage,
    required TextEditingController controller,
    required FocusNode focusNode,
    required Size surfaceSize,
    VoidCallback? onOpenContextUsage,
    String? conversationId = 'c1',
  }) {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
          ChangeNotifierProvider<ContextUsageService>(create: (_) => usage),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(size: surfaceSize),
            child: Scaffold(
              body: ChatInputBar(
                controller: controller,
                focusNode: focusNode,
                conversationId: conversationId,
                onOpenContextUsage: onOpenContextUsage,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'composer edits and programmatic clear update the draft contribution',
    (tester) async {
      final providers = await createProviders();
      final controller = TextEditingController(text: 'initial draft');
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      await pumpBar(
        tester,
        settings: providers.settings,
        assistants: providers.assistants,
        usage: providers.usage,
        controller: controller,
        focusNode: focusNode,
        surfaceSize: const Size(1024, 768),
      );
      await tester.pump();
      expect(providers.usage.drafts['c1'], 'initial draft');

      await tester.enterText(find.byType(EditableText).first, 'edited draft');
      await tester.pump();
      expect(providers.usage.drafts['c1'], 'edited draft');

      controller.clear(); // Also the path used when submitting a message.
      await tester.pump();
      expect(providers.usage.drafts['c1'], '');

      controller.text = 'restored after a failed send';
      await tester.pump();
      expect(providers.usage.drafts['c1'], 'restored after a failed send');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('hides the context usage ring on a mobile-width layout', (
    tester,
  ) async {
    final providers = await createProviders();
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await pumpBar(
      tester,
      settings: providers.settings,
      assistants: providers.assistants,
      usage: providers.usage,
      controller: controller,
      focusNode: focusNode,
      surfaceSize: const Size(390, 844),
      onOpenContextUsage: () {},
    );
    await tester.pump();

    expect(find.byType(ContextUsageRing), findsNothing);
  });

  testWidgets('tapping the ring invokes onOpenContextUsage', (tester) async {
    final providers = await createProviders();
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    var opened = 0;
    await pumpBar(
      tester,
      settings: providers.settings,
      assistants: providers.assistants,
      usage: providers.usage,
      controller: controller,
      focusNode: focusNode,
      surfaceSize: const Size(1200, 800),
      onOpenContextUsage: () => opened++,
    );
    await tester.pump();

    expect(find.byType(ContextUsageRing), findsOneWidget);
    await tester.tap(find.byType(ContextUsageRing));
    await tester.pump();

    expect(opened, 1);
  });
}
