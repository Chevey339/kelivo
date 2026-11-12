import 'dart:io';

import 'package:Kelivo/core/providers/local_snapshot_provider.dart';
import 'package:Kelivo/core/services/backup/local_copy_catalog.dart';
import 'package:Kelivo/core/services/backup/local_snapshot_settings.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/backup/pages/local_snapshots_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';

class _CopiesProvider extends LocalSnapshotProvider {
  _CopiesProvider(Directory root, BusinessTestHarness business, this.entries)
    : super(
        appDataDirectory: root,
        chatService: ChatService(),
        businessRepository: business.repository,
        businessPreferences: business.preferences,
        autoLoad: false,
      );

  final List<LocalCopy> entries;
  final List<LocalCopy> deleted = [];
  bool busy = false;

  void showBusyCopy(LocalCopy copy) {
    entries[0] = copy;
    busy = true;
    notifyListeners();
  }

  @override
  List<LocalCopy> get copies => entries;

  @override
  bool get working => busy;

  @override
  LocalSnapshotSettings get settings =>
      const LocalSnapshotSettings(enabled: false);

  @override
  Future<void> refresh() async {}

  @override
  Future<void> delete(LocalCopy copy) async {
    deleted.add(copy);
    entries.remove(copy);
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late BusinessTestHarness business;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('local_snapshots_page_');
    business = await createBusinessTestHarness();
  });
  tearDown(() => root.delete(recursive: true));

  LocalCopy retained({required bool canDelete}) => LocalCopy(
    kind: LocalCopyKind.displaced,
    id: 'retained',
    file: File('${root.path}/Documents/kelivo.db'),
    createdAt: DateTime(2026, 10, 28),
    bytes: 1700000000,
    discovered: true,
    canDelete: canDelete,
  );

  Future<AppLocalizations> pump(WidgetTester tester, _CopiesProvider vm) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<LocalSnapshotProvider>.value(
        value: vm,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LocalSnapshotsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(LocalSnapshotsPage)),
    )!;
  }

  for (final width in [390.0, 1000.0]) {
    testWidgets('retained deletion requires confirmation at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final copy = retained(canDelete: true);
      final vm = _CopiesProvider(root, business, [copy]);
      addTearDown(vm.dispose);
      final l10n = await pump(tester, vm);
      final delete = find.text(l10n.localSnapshotActionDelete);
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();

      expect(find.text(l10n.localSnapshotDeleteTitle), findsOneWidget);
      expect(
        find.textContaining(l10n.localSnapshotDeleteLastWarning),
        findsOneWidget,
      );
      expect(vm.deleted, isEmpty);
      await tester.tap(find.text(l10n.backupPageCancel));
      await tester.pumpAndSettle();
      expect(vm.deleted, isEmpty);
      expect(find.text(copy.file.path), findsOneWidget);

      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(delete.last);
      await tester.pumpAndSettle();
      expect(vm.deleted, [copy]);
      expect(find.text(copy.file.path), findsNothing);
      expect(tester.takeException(), isNull);
      // Let the success toast finish before disposing its navigator.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('unverified copies hide delete and busy copies disable actions', (
    tester,
  ) async {
    final vm = _CopiesProvider(root, business, [retained(canDelete: false)]);
    addTearDown(vm.dispose);
    final l10n = await pump(tester, vm);
    expect(find.text(l10n.localSnapshotActionDelete), findsNothing);
    vm.showBusyCopy(retained(canDelete: true));
    await tester.pump();
    for (final label in [
      l10n.localSnapshotActionRestore,
      l10n.localSnapshotActionExport,
      l10n.localSnapshotActionDelete,
    ]) {
      final button = tester.widget<IosTileButton>(
        find.widgetWithText(IosTileButton, label),
      );
      expect(button.enabled, isFalse);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
