import 'package:Kelivo/l10n/app_localizations_en.dart';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/compress_context_options.dart';
import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/chat/context_compression_service.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getApplicationCachePath() async => '$path/cache';
  @override
  Future<String?> getTemporaryPath() async => '$path/tmp';
}

// Run on a device with an isolated application id. All app data uses this
// disposable database; no configured providers or network calls are needed.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('home ignores unrelated changes and refreshes its visible state', (
    tester,
  ) async {
    final root = await Directory.systemTemp.createTemp('home_subscription_');
    final originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    final database = AppDatabase.open(
      file: File('${root.path}/${AppDatabase.databaseFileName}'),
    );
    final repo = ChatDatabaseRepository(database);
    await repo.ensureReady();
    final business = BusinessRepository(database);
    await business.writeMigrationReceipt();
    await business.setPreference('display_new_chat_on_launch_v1', false);
    await database.customStatement(
      "INSERT INTO conversation_rows(id,title,created_at,updated_at) VALUES('home','Current',1,2),('other','Background',1,1)",
    );
    await database.customStatement(
      "INSERT INTO message_rows(id,conversation_id,role,timestamp,message_order) VALUES('m','home','user',1,0)",
    );
    await database.customStatement(
      "INSERT INTO message_part_rows(conversation_id,revision_id,ordinal,kind,payload,created_at,updated_at) VALUES('home','m',0,'text','Message',1,1)",
    );
    await repo.close();
    try {
      await app.main();
      final finder = find.byType(MessageListView);
      for (var i = 0; i < 200 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(finder, findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      final context = tester.element(finder);
      final chat = context.read<ChatService>();
      final settings = context.read<SettingsProvider>();
      MessageListView view() => tester.widget<MessageListView>(finder);

      // Startup finishes provider/draft warmups after the first visible frame.
      // Establish an idle view before testing a service-only notification.
      var previous = view();
      var stablePumps = 0;
      for (var i = 0; i < 60 && stablePumps < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        stablePumps = identical(view(), previous) ? stablePumps + 1 : 0;
        previous = view();
      }
      expect(stablePumps, 5);
      final before = view();
      await chat.updateConversationSummary('other', 'Background summary', 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(identical(view(), before), isTrue);

      await settings.resetSuggestionModel();
      await tester.pump();
      await chat.updateConversationSuggestions('home', ['Follow up']);
      await tester.pump();
      expect(view().suggestions, ['Follow up']);
      await chat.clearConversationSuggestions('home');
      await tester.pump();
      expect(view().suggestions, isEmpty);

      chat.contextCompression.isConversationBusy = (_) => true;
      await chat.contextCompression.start(
        'home',
        CompressionRequest(
          options: const CompressContextOptions(
            mode: CompressContextLimitMode.keepRecent,
            keepUserMessages: 6,
          ),
          model: 'fixture',
          generate: (_, _) async => 'summary',
          quoteMarker: AppLocalizationsEn().selectionQuoteMarker,
        ),
      );
      await tester.pump();
      expect(view().contextTask?.phase, CompressionPhase.waiting);
      await chat.contextCompression.cancel('home');
      await tester.pump();
      expect(view().contextTask?.phase, CompressionPhase.cancelled);
      chat.contextCompression.isConversationBusy = (_) => false;

      await chat.clearConversationContext('home');
      await tester.pump(const Duration(milliseconds: 200));
      final operation = view().contextOperations.single;
      expect(operation.kind, ContextOperationKind.clear);
      await chat.changeContextOperation(
        'home',
        operation.id,
        includeDependents: true,
        expectedState: ContextHistory.operationsFingerprint(
          chat.contextOperationsFor('home'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(view().contextOperations.single.revoked, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      PathProviderPlatform.instance = originalPaths;
    }
  });
}
