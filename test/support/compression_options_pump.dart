import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/chat/widgets/compress_context_options_dialog.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

/// Range selection uses a real isolate, which pumpAndSettle's fake clock does
/// not wait for. Wait for the visible loading state instead of a fixed delay.
Future<void> settleCompressionOptions(WidgetTester tester) async {
  await tester.pumpAndSettle();
  for (var i = 0; i < 300; i++) {
    final dialogs = find.byType(CompressContextOptionsDialog);
    if (dialogs.evaluate().isEmpty) return;
    final l10n = AppLocalizations.of(tester.element(dialogs.first))!;
    final loading = find.descendant(
      of: dialogs,
      matching: find.text(l10n.contextLogLoading),
    );
    if (loading.evaluate().isEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pumpAndSettle();
  }
  fail('Compression range did not finish loading');
}
