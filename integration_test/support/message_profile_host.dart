import '../../test/support/message_test_services.dart';
export '../../test/support/message_test_services.dart';
import 'package:flutter/material.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';

/// This exact host/fixture is also copied into the archived C01 build snapshot.
/// It imports no GenUI code and uses no production feature flag.
List<ChatMessage> ordinaryProfileMessages() => [
  for (var i = 0; i < 200; i++)
    ChatMessage(
      id: 'ordinary-$i',
      role: i.isEven ? 'user' : 'assistant',
      conversationId: 'ordinary-profile',
      content: i.isEven
          ? 'Example question $i: compare a local calculation with the recorded values.'
          : '''## Example answer $i
This is synthetic history for a repeatable scroll measurement. **Local text** includes an ordinary paragraph and a short list.

- First observation: ${i + 1}
- Second observation: ${i + 2}

| Item | Value |
| --- | ---: |
| Alpha | ${i + 3} |
| Beta | ${i + 4} |

```dart
final sample = ${i + 5};
```
''',
    ),
];

class MessageProfileHost extends StatefulWidget {
  const MessageProfileHost({
    super.key,
    required this.messages,
    required this.services,
  });
  final List<ChatMessage> messages;
  final MessageTestServices services;
  @override
  State<MessageProfileHost> createState() => MessageProfileHostState();
}

class MessageProfileHostState extends State<MessageProfileHost> {
  final scroll = ScrollController();
  final list = ListController();
  final processing = ValueNotifier<String?>(null);
  @override
  void dispose() {
    scroll.dispose();
    list.dispose();
    processing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.services.wrap(
    MaterialApp(
      theme: buildLightTheme(null),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SafeArea(
          child: MessageListView(
            scrollController: scroll,
            listController: list,
            messages: widget.messages,
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
            processingFilesMessageId: processing,
          ),
        ),
      ),
    ),
  );
}
