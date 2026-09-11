import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/chat/widgets/collapsible_user_text.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/l10n/app_localizations_en.dart';

import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const clipKey = ValueKey('collapsible-user-text-clip');
  const toggleKey = ValueKey('collapsible-user-text-toggle');

  const longText =
      'The quick brown fox jumps over the lazy dog. '
      'The quick brown fox jumps over the lazy dog. '
      'The quick brown fox jumps over the lazy dog. '
      'The quick brown fox jumps over the lazy dog. '
      'The quick brown fox jumps over the lazy dog.';

  Future<void> pumpText(
    WidgetTester tester,
    String text, {
    double collapsedHeight = 100,
  }) async {
    final harness = await createBusinessTestHarness();
    addTearDown(harness.close);
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: CollapsibleUserText(
                  collapsedHeight: collapsedHeight,
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('overflowing text is clipped to the collapsed height', (
    tester,
  ) async {
    await pumpText(tester, longText);

    expect(find.byKey(clipKey), findsOneWidget);
    expect(tester.getSize(find.byKey(clipKey)).height, 100);
    expect(find.byKey(toggleKey), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);
  });

  testWidgets('toggle expands to the full height and collapses back', (
    tester,
  ) async {
    await pumpText(tester, longText);

    await tester.tap(find.byKey(toggleKey));
    await tester.pumpAndSettle();

    expect(find.byKey(clipKey), findsNothing);
    expect(find.byType(ShaderMask), findsNothing);
    expect(tester.getSize(find.text(longText)).height, greaterThan(100));

    await tester.tap(find.byKey(toggleKey));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(clipKey)).height, 100);
  });

  testWidgets('content that grows on its own brings the toggle back', (
    tester,
  ) async {
    final harness = await createBusinessTestHarness();
    addTearDown(harness.close);
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: CollapsibleUserText(
                  collapsedHeight: 100,
                  child: _GrowableChild(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Fits at first: no fade, no toggle.
    expect(find.byKey(toggleKey), findsNothing);
    expect(find.byType(ShaderMask), findsNothing);

    // The child expands itself, the way a `<details>` block or an
    // auto-collapsed code block inside the bubble does.
    await tester.tap(find.byKey(const ValueKey('growable-child-summary')));
    await tester.pumpAndSettle();

    // Turning the fade on must not remount the child and undo its expansion.
    expect(
      find.byKey(const ValueKey('growable-child-body:true')),
      findsOneWidget,
    );
    expect(find.byKey(toggleKey), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(tester.getSize(find.byKey(clipKey)).height, 100);
  });

  testWidgets('expanding the message keeps the content subtree alive', (
    tester,
  ) async {
    final harness = await createBusinessTestHarness();
    addTearDown(harness.close);
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: CollapsibleUserText(
                  collapsedHeight: 100,
                  child: _GrowableChild(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('growable-child-summary')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('growable-child-body:true')),
      findsOneWidget,
    );

    // Expanding and collapsing the message reparents the content; its own
    // expansion state has to survive both moves.
    await tester.tap(find.byKey(toggleKey));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('growable-child-body:true')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(toggleKey));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('growable-child-body:true')),
      findsOneWidget,
    );
  });

  testWidgets('text that fits the collapsed height drops the toggle', (
    tester,
  ) async {
    await pumpText(tester, 'short');

    expect(find.byKey(toggleKey), findsNothing);
    expect(find.byType(ShaderMask), findsNothing);
  });

  testWidgets('toggle reports its expanded state to accessibility', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpText(tester, longText);

    expect(
      tester.getSemantics(find.byKey(toggleKey)).flagsCollection.isExpanded,
      Tristate.isFalse,
    );

    await tester.tap(find.byKey(toggleKey));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byKey(toggleKey)).flagsCollection.isExpanded,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  final wideBubbleLongText = List<String>.generate(
    40,
    (index) => 'The quick brown fox jumps over the lazy dog number $index.',
  ).join(' ');

  Future<void> pumpUserMessage(
    WidgetTester tester, {
    required bool collapseEnabled,
    required String content,
  }) async {
    final harness = await createBusinessTestHarness();
    addTearDown(harness.close);
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    await settings.setEnableUserMarkdown(false);
    await settings.setCollapseLongUserMessages(collapseEnabled);
    await settings.setCollapseLongUserMessageChars(100);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider(
            create: (_) => UserProvider(preferences: harness.preferences),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                TtsProvider(preferences: createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider(create: (_) => ToolApprovalService()),
          ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatMessageWidget(
                message: ChatMessage(
                  role: 'user',
                  content: content,
                  conversationId: 'conversation-collapse',
                ),
                showModelIcon: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('long user message collapses only when the setting is on', (
    tester,
  ) async {
    await pumpUserMessage(
      tester,
      collapseEnabled: false,
      content: wideBubbleLongText,
    );
    expect(find.byType(CollapsibleUserText), findsNothing);

    await pumpUserMessage(
      tester,
      collapseEnabled: true,
      content: wideBubbleLongText,
    );
    expect(find.byType(CollapsibleUserText), findsOneWidget);
    expect(find.byKey(toggleKey), findsOneWidget);
  });

  testWidgets('expanding a code block inside the bubble revives the toggle', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final code = List<String>.generate(
      60,
      (index) => 'print("line $index");',
    ).join('\n');

    final harness = await createBusinessTestHarness();
    addTearDown(harness.close);
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    await settings.setAutoCollapseCodeBlock(true);
    await settings.setAutoCollapseCodeBlockLines(2);
    await settings.setCollapseLongUserMessages(true);
    await settings.setCollapseLongUserMessageChars(100);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider(
            create: (_) => UserProvider(preferences: harness.preferences),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                TtsProvider(preferences: createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider(create: (_) => ToolApprovalService()),
          ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatMessageWidget(
                message: ChatMessage(
                  role: 'user',
                  content:
                      'Here is the snippet I am asking about:\n\n'
                      '```dart\n$code\n```',
                  conversationId: 'conversation-code-block',
                ),
                showModelIcon: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The auto-collapsed code block leaves the message short enough to fit.
    expect(find.byType(CollapsibleUserText), findsOneWidget);
    expect(find.byKey(toggleKey), findsNothing);

    await tester.tap(
      find
          .bySemanticsLabel(RegExp(AppLocalizationsEn().codeBlockExpandButton))
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(toggleKey), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(tester.getSize(find.byKey(clipKey)).height, lessThan(210));
    semantics.dispose();
  });

  testWidgets('expanding a <details> block keeps it open and fades the rest', (
    tester,
  ) async {
    final body = List<String>.generate(
      40,
      (index) => 'Detail line $index about the request.',
    ).join('\n\n');

    final harness = await createBusinessTestHarness();
    addTearDown(harness.close);
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    await settings.setCollapseLongUserMessages(true);
    await settings.setCollapseLongUserMessageChars(100);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider(
            create: (_) => UserProvider(preferences: harness.preferences),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                TtsProvider(preferences: createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider(create: (_) => ToolApprovalService()),
          ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatMessageWidget(
                message: ChatMessage(
                  role: 'user',
                  content:
                      'Please look at this:\n\n'
                      '<details>\n<summary>Show details</summary>\n\n'
                      '$body\n\n</details>',
                  conversationId: 'conversation-details',
                ),
                showModelIcon: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The closed <details> leaves the message short enough to fit.
    expect(find.byType(CollapsibleUserText), findsOneWidget);
    expect(find.byKey(const ValueKey('details-expanded')), findsNothing);
    expect(find.byKey(toggleKey), findsNothing);

    await tester.tap(find.text('Show details'));
    await tester.pumpAndSettle();

    // Turning on the fade must not remount the block and snap it shut again.
    expect(find.byKey(const ValueKey('details-expanded')), findsOneWidget);
    expect(find.byKey(toggleKey), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);
  });

  testWidgets('user message below the threshold stays uncollapsed', (
    tester,
  ) async {
    await pumpUserMessage(tester, collapseEnabled: true, content: 'short ask');

    expect(find.byType(CollapsibleUserText), findsNothing);
  });
}

/// Stands in for a collapsed code block inside a message: it grows without the
/// surrounding [CollapsibleUserText] rebuilding.
/// Stands in for a `<details>` block or an auto-collapsed code block inside the
/// bubble: it holds expansion state and grows itself, without the surrounding
/// [CollapsibleUserText] rebuilding. Deliberately carries no key, so losing the
/// element identity shows up as lost state.
class _GrowableChild extends StatefulWidget {
  const _GrowableChild();

  @override
  State<_GrowableChild> createState() => _GrowableChildState();
}

class _GrowableChildState extends State<_GrowableChild> {
  bool _big = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          key: const ValueKey('growable-child-summary'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _big = !_big),
          child: const SizedBox(height: 30),
        ),
        SizedBox(
          key: ValueKey('growable-child-body:$_big'),
          height: _big ? 400 : 30,
        ),
      ],
    );
  }
}
