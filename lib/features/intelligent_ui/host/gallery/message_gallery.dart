import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/features/chat/widgets/chat_assistant_background.dart';
import 'package:Kelivo/features/chat/widgets/frosted/chat_frosted_backdrop.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../../catalog/ui_catalog.dart';
import '../../widgets/gallery/chart_gallery.dart';
import '../../widgets/gallery/table_gallery.dart';
import '../ui_host_scope.dart';
import 'web_gallery.dart';

const genUiMessageFixture = r'''ui 1 catalog "kelivo.native/1"
$name: string = "Kelivo"
$amount: number = 3
root = Column(children=[form,total,ask,reset])
form = Form(children=[nameField,amountField])
nameField = TextField(label="Name", bind=$name, required=true)
amountField = Slider(label="Quantity", bind=$amount, min=0, max=10, step=1)
total = Metric(label="Local total", value=$amount * 12, unit="USD")
ask = Button(label="Observe frozen Ask", form=form, action=Ask(text="Explain my selection", context={"name":$name,"quantity":$amount}))
reset = Button(label="Reset locally", action=Reset())
''';

class GenUiMessageGallery extends StatefulWidget {
  const GenUiMessageGallery({super.key, required this.preferences});
  final BusinessPreferences preferences;
  @override
  State<GenUiMessageGallery> createState() => _GenUiMessageGalleryState();
}

class _GenUiMessageGalleryState extends State<GenUiMessageGallery> {
  final _scroll = ScrollController();
  final _list = ListController();
  final _processing = ValueNotifier<String?>(null);
  bool _dark = false, _large = false, _rtl = false;
  int _step = 6, _role = 0, _fixture = 0;
  final _fixtures = [
    'form',
    'web',
    ...genUiChartGallerySources.keys,
    ...genUiTableGallerySources.keys,
  ];
  String _intent = 'Ask is observed locally. No messages are sent.';
  @override
  void dispose() {
    _scroll.dispose();
    _list.dispose();
    _processing.dispose();
    super.dispose();
  }

  ChatMessage _message() {
    final web = _fixtures[_fixture] == 'web';
    final source = web
        ? genUiWebGallerySource
        : _fixture == 0
        ? genUiMessageFixture
        : '${UiCatalog.header}\n${genUiChartGallerySources[_fixtures[_fixture]] ?? genUiTableGallerySources[_fixtures[_fixture]]}\n';
    final lines = source.trimRight().split('\n');
    final count = switch (_step) {
      0 => 1,
      1 => 4,
      2 => 6,
      3 => 7,
      _ => lines.length,
    };
    var text =
        '```${web ? "kelivo-web" : "kelivo-ui"}\n${lines.take(count).join('\n')}\n${_step >= 5 ? "```" : ""}';
    if (_role == 3) text = text.split('\n').map((l) => '> $l').join('\n');
    if (_step == 8) {
      text = web
          ? text.replaceFirst('"version":1', '"version":9')
          : text.replaceFirst('ui 1', 'ui 9');
    }
    text =
        '| Markdown | Native UI |\n| --- | --- |\n'
        '| Shared message backdrop | Interactive content below |\n\n$text';
    final message = ChatMessage(
      id: 'manual-native-$_role-$_fixture',
      conversationId: 'manual-native',
      role: switch (_role) {
        1 => 'user',
        2 => 'tool',
        _ => 'assistant',
      },
      content: text,
      isStreaming: _step < 6,
    );
    message.hydrateGenerationState(switch (_step) {
      7 => GenerationRunState.cancelled,
      >= 6 => GenerationRunState.completed,
      _ => GenerationRunState.streaming,
    });
    return message;
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(widget.preferences),
      ),
      ChangeNotifierProvider(
        create: (_) => AssistantProvider(preferences: widget.preferences),
      ),
      ChangeNotifierProvider(
        create: (_) => UserProvider(preferences: widget.preferences),
      ),
      ChangeNotifierProvider(
        create: (_) => TtsProvider(preferences: widget.preferences),
      ),
      ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
      ChangeNotifierProvider(create: (_) => ToolApprovalService()),
    ],
    child: MaterialApp(
      theme: _dark ? buildDarkTheme(null) : buildLightTheme(null),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(_large ? 1.3 : 1)),
          child: Directionality(
            textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    Wrap(
                      children: [
                        IosTextButton(
                          label: _dark ? 'Dark' : 'Light',
                          onPressed: () => setState(() => _dark = !_dark),
                        ),
                        IosTextButton(
                          label: _large ? '1.3×' : '1×',
                          onPressed: () => setState(() => _large = !_large),
                        ),
                        IosTextButton(
                          label: _rtl ? 'RTL' : 'LTR',
                          onPressed: () => setState(() => _rtl = !_rtl),
                        ),
                        IosTextButton(
                          label: ['Assistant', 'User', 'Tool', 'Quote'][_role],
                          onPressed: () =>
                              setState(() => _role = (_role + 1) % 4),
                        ),
                        IosTextButton(
                          label: 'Phase $_step / 8',
                          onPressed: () =>
                              setState(() => _step = (_step + 1) % 9),
                        ),
                        IosTextButton(
                          label: _fixtures[_fixture],
                          onPressed: () => setState(
                            () => _fixture = (_fixture + 1) % _fixtures.length,
                          ),
                        ),
                        IosTextButton(
                          label: 'Background',
                          onPressed: () async {
                            final provider = context.read<AssistantProvider>();
                            await provider.loaded;
                            if (provider.currentAssistant == null) {
                              await provider.addAssistant(
                                name: 'Native UI preview',
                              );
                            }
                            final assistant = provider.currentAssistant;
                            if (assistant == null) return;
                            await provider.updateAssistant(
                              assistant.copyWith(
                                useGradientBackground:
                                    !assistant.useGradientBackground,
                                gradientBackgroundAnimated: false,
                              ),
                            );
                          },
                        ),
                        IosTextButton(
                          label: 'Bubble style',
                          onPressed: () {
                            final settings = context.read<SettingsProvider>();
                            final styles = ChatMessageBackgroundStyle.values;
                            settings.setChatMessageBackgroundStyle(
                              styles[(styles.indexOf(
                                        settings.chatMessageBackgroundStyle,
                                      ) +
                                      1) %
                                  styles.length],
                            );
                          },
                        ),
                      ],
                    ),
                    Expanded(
                      child: ChatFrostedBackdrop(
                        backdrop: const ChatAssistantBackground(
                          desktop: true,
                          includeSurfaceFill: true,
                        ),
                        child: UiActionsScope(
                          onAsk: (intent) async => setState(
                            () => _intent = jsonEncode(intent.context),
                          ),
                          child: MessageListView(
                            scrollController: _scroll,
                            listController: _list,
                            messages: [_message()],
                            byGroup: const {},
                            versionSelections: const {},
                            reasoning: const {},
                            reasoningSegments: const {},
                            contentSplits: const {},
                            toolParts: const {},
                            translations: const {},
                            selecting: false,
                            selectedItems: const {},
                            dividerPadding: EdgeInsets.zero,
                            processingFilesMessageId: _processing,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _intent,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
