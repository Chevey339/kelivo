import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/backup/widgets/backup_reminder_helpers.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile time picker uses wheel selection', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      int? selectedMinutes;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async {
                      selectedMinutes = await showBackupReminderTimePicker(
                        context,
                        initialMinutes: 23 * 60 + 59,
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Reminder Time'), findsWidgets);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.byKey(const ValueKey('backup-reminder-time-mobile-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('backup-reminder-time-mobile-actions')),
        findsOneWidget,
      );
      expect(find.byType(Divider), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(CupertinoPicker), findsNWidgets(2));
      _expectAllPickersLooping(tester);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(selectedMinutes, 23 * 60 + 59);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mobile time picker cancel returns null', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      int? selectedMinutes = -1;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async {
                      selectedMinutes = await showBackupReminderTimePicker(
                        context,
                        initialMinutes: 0,
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(selectedMinutes, isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('desktop time picker uses wheel selection', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      int? selectedMinutes;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async {
                      selectedMinutes = await showBackupReminderTimePicker(
                        context,
                        initialMinutes: 8 * 60,
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Reminder Time'), findsWidgets);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(CupertinoPicker), findsNWidgets(2));
      _expectAllPickersLooping(tester);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(selectedMinutes, 8 * 60);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('custom days dialog can be cancelled without controller errors', (
    tester,
  ) async {
    int? selectedDays;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    selectedDays = await showBackupReminderCustomDaysDialog(
                      context,
                      initialDays: 7,
                    );
                  },
                  child: const Text('open custom'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open custom'));
    await tester.pumpAndSettle();

    expect(find.text('Custom Frequency'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(selectedDays, isNull);
  });
}

void _expectAllPickersLooping(WidgetTester tester) {
  final pickers = tester.widgetList<CupertinoPicker>(
    find.byType(CupertinoPicker),
  );
  for (final picker in pickers) {
    expect(picker.childDelegate, isA<ListWheelChildLoopingListDelegate>());
  }
}
