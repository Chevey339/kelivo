import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/chat/widgets/select_copy_sheet.dart';
import 'package:Kelivo/features/chat/pages/select_copy_page.dart';
import 'package:Kelivo/desktop/select_copy_dialog.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_runtime_registry.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import '../../support/business_test_harness.dart';

const _body = r'''ui 1 catalog "kelivo.native/1"
$a: number = 2
root = Column(children=[slider,result])
slider = Slider(label="Slope",bind=$a,min=0,max=10)
result = Metric(label="Result",value=$a*2)
''';
const _source = 'Conclusion\n\n```kelivo-ui\n$_body```';
void main() {
  for (final surface in ['sheet', 'page', 'dialog', 'message']) {
    testWidgets(
      '$surface copies frozen semantic state and offers source explicitly',
      (tester) async {
        final message = ChatMessage(
          id: 'r',
          conversationId: 'c',
          role: 'assistant',
          content: _source,
        )..hydrateGenerationState(GenerationRunState.completed);
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
        final service = ChatService();
        final stop = service.registerGenUiSnapshotReader(
          registry.captureCopySnapshots,
        );
        String? clipboard;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
        addTearDown(() async {
          AppSnackBarManager().dismissAll();
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox.shrink());
          messenger.setMockMethodCallHandler(SystemChannels.platform, null);
          stop();
          registry.dispose();
          service.dispose();
        });
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<ChatService>.value(value: service),
              ChangeNotifierProvider(
                create: (_) =>
                    SettingsProvider(createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider(
                create: (_) =>
                    UserProvider(preferences: createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider(
                create: (_) => AssistantProvider(
                  preferences: createBusinessTestPreferences(),
                ),
              ),
              ChangeNotifierProvider(
                create: (_) =>
                    TtsProvider(preferences: createBusinessTestPreferences()),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                body: UiRuntimeScope(
                  registry: registry,
                  child: Builder(
                    builder: (context) => surface == 'message'
                        ? SingleChildScrollView(
                            child: ChatMessageWidget(message: message),
                          )
                        : TextButton(
                            onPressed: () {
                              if (surface == 'sheet') {
                                showSelectCopySheet(context, message: message);
                              }
                              if (surface == 'dialog') {
                                showSelectCopyDesktopDialog(
                                  context,
                                  message: message,
                                );
                              }
                              if (surface == 'page') {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        SelectCopyPage(message: message),
                                  ),
                                );
                              }
                            },
                            child: const Text('Open'),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (surface == 'message') {
          final copy = find.byWidgetPredicate(
            (w) => w is IosIconButton && w.icon == LucideIcons.copy,
          );
          await tester.tap(copy.first);
        } else {
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          entry.controller.setInputs({'a': 9}, token: entry.controller.token);
          await tester.tap(find.text('Copy All'));
        }
        await tester.pumpAndSettle();
        expect(clipboard, contains('Slope: 7'));
        expect(clipboard, contains('Result: 14'));
        expect(clipboard, isNot(contains('root =')));
        if (surface != 'message') {
          AppSnackBarManager().dismissAll();
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Copy source / Markdown'));
          await tester.pumpAndSettle();
          expect(clipboard, _source);
        }
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(
        surface == 'dialog' || surface == 'message'
            ? TargetPlatform.macOS
            : TargetPlatform.android,
      ),
    );
  }
}
