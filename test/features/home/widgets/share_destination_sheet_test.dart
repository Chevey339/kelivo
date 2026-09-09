import '../../../support/business_test_harness.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/features/home/widgets/share_destination_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('search targets an existing conversation and returns its id', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showShareDestinationSheet(
                    context,
                    conversations: [
                      Conversation(id: 'research', title: 'Research'),
                      Conversation(id: 'code', title: 'Code review'),
                    ],
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'code');
    await tester.pump();
    expect(find.text('Research'), findsNothing);
    await tester.tap(find.text('Code review'));
    await tester.pumpAndSettle();
    expect(selected, 'code');
    expect(tester.takeException(), isNull);
  });
}
