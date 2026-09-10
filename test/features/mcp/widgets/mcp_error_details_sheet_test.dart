import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/mcp/widgets/mcp_error_details_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets(
      'long error scrolls with visible actions at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var reconnects = 0;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('Open'),
                  onPressed: () => showFormSheet<void>(
                    context,
                    builder: (_) => McpErrorDetailsSheet(
                      serverName: 'sequential-thinking' * 5,
                      message:
                          '${'npm error EEXIST /root/.npm/_cacache/tmp/afdc7af3\n' * 300}END OF LOG',
                      onReconnect: () => reconnects++,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Close').hitTestable(), findsOneWidget);
        expect(find.text('Reconnect').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Reconnect'));
        expect(reconnects, 1);
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(McpErrorDetailsSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(scroll.position.maxScrollExtent, greaterThan(0));
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -100),
        );
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, greaterThan(0));
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Close').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.byType(McpErrorDetailsSheet), findsNothing);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );
  }
}
