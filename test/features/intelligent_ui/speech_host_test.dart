import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/home_page_controller.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_runtime_registry.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import '../../support/business_test_harness.dart';

const _body = r'''ui 1 catalog "kelivo.native/1"
$a: number = 2
root = Column(children=[slider,result,literal])
slider = Slider(label="Slope",bind=$a,min=0,max=10)
result = Metric(label="Result",value=$a*2)
literal = Text(text="-3 `kept` *plain*")
''';

class _Speech extends TtsProvider {
  _Speech() : super(preferences: createBusinessTestPreferences());
  final calls = <(String, bool, bool)>[];
  @override
  bool get isAvailable => true;
  @override
  Future<void> speak(
    String text, {
    bool flush = true,
    bool waitForCompletion = true,
    bool plainText = false,
  }) async {
    calls.add((text, plainText, waitForCompletion));
  }
}

void main() {
  testWidgets(
    'manual and automatic speech use accepted state above the list scope and only latest preparation plays',
    (tester) async {
      final message = ChatMessage(
        id: 'r',
        conversationId: 'c',
        role: 'assistant',
        content: '**Conclusion**\n\n```kelivo-ui\n$_body```',
      )..hydrateGenerationState(GenerationRunState.completed);
      final service = ChatService();
      final registry = UiRuntimeRegistry();
      final entry = registry.obtain(
        'c',
        const UiSurfaceOwner(revisionId: 'r', surfaceKey: '0:0'),
      );
      entry.controller.updateSource(
        _body,
        closed: true,
        generation: UiGenerationStatus.complete,
      );
      entry.controller.setInputs({'a': 7}, token: entry.controller.token);
      final stop = service.registerGenUiSnapshotReader(
        registry.captureCopySnapshots,
      );
      final speech = _Speech();
      final settings = SettingsProvider(createBusinessTestPreferences());
      final assistant = AssistantProvider(
        preferences: createBusinessTestPreferences(),
      );
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ChatService>.value(value: service),
            ChangeNotifierProvider<TtsProvider>.value(value: speech),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<AssistantProvider>.value(value: assistant),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: _Host(key: key),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final controller = key.currentState!.controller;
      await controller.speakMessage(message);
      expect(speech.calls.single.$1, contains('Slope: 7'));
      expect(speech.calls.single.$1, contains('Result: 14'));
      expect(speech.calls.single.$1, contains('-3 `kept` *plain*'));
      expect(speech.calls.single.$1, isNot(contains('root =')));
      expect(speech.calls.single.$2, isTrue);
      expect(speech.calls.single.$3, isTrue);
      await settings.setTtsAutoPlayAssistantReplies(true);
      await controller.debugHandleAssistantMessageFinished(message);
      expect(speech.calls.last.$1, speech.calls.first.$1);
      expect(speech.calls.last.$2, isTrue);
      expect(speech.calls.last.$3, isFalse);
      speech.calls.clear();
      final old = controller.speakMessage(message);
      final newest = controller.speakMessage(
        message.copyWith(content: 'Newest answer'),
      );
      await Future.wait([old, newest]);
      expect(speech.calls, [('Newest answer', false, true)]);
      await tester.pumpWidget(const SizedBox.shrink());
      stop();
      registry.dispose();
      speech.dispose();
      settings.dispose();
      assistant.dispose();
      service.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}

class _Host extends StatefulWidget {
  const _Host({super.key});
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with TickerProviderStateMixin {
  final text = TextEditingController();
  final focus = FocusNode();
  final scroll = ChatAutoFollowScrollController();
  final scaffold = GlobalKey<ScaffoldState>();
  late final HomePageController controller;
  @override
  void initState() {
    super.initState();
    controller = HomePageController(
      context: context,
      vsync: this,
      scaffoldKey: scaffold,
      inputBarKey: GlobalKey(),
      inputFocus: focus,
      inputController: text,
      mediaController: ChatInputBarController(),
      scrollController: scroll,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    text.dispose();
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(key: scaffold, body: const SizedBox());
}
