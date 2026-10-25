import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/main.dart' as app;
import 'package:Kelivo/shared/widgets/long_message_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

// Explicit Android profile test. Real app, real SQLite worker, real renderer,
// and Android IME; all application directories point at a disposable fixture.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'large database keeps the real home window and composer usable',
    (tester) async {
      final root = await Directory.systemTemp.createTemp('kelivo_home_perf_');
      final originalPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FixturePaths(root.path);
      final database = AppDatabase.open(file: File('${root.path}/kelivo.db'));
      final repository = ChatDatabaseRepository(database);
      await repository.ensureReady();
      try {
        final business = BusinessRepository(database);
        await business.writeMigrationReceipt();
        await business.setPreference('display_new_chat_on_launch_v1', false);
        await database.customStatement('''
WITH RECURSIVE seq(n) AS (VALUES(0) UNION ALL SELECT n+1 FROM seq WHERE n<999)
INSERT INTO conversation_rows(id,title,created_at,updated_at)
SELECT 'home-conv-'||n,'Performance '||n,1,1000-n FROM seq
''');
        await database.customStatement('''
WITH RECURSIVE seq(n) AS (VALUES(0) UNION ALL SELECT n+1 FROM seq WHERE n<99999)
INSERT INTO message_rows(id,conversation_id,role,timestamp,message_order)
SELECT 'home-msg-'||n,'home-conv-0',CASE WHEN n%2=0 THEN 'user' ELSE 'assistant' END,1,n FROM seq
''');
        await database.customStatement(
          '''
INSERT INTO message_part_rows(conversation_id,revision_id,ordinal,kind,payload,created_at,updated_at)
SELECT conversation_id,id,0,'text',CASE WHEN message_order<98000 THEN ? ELSE 'Visible **message** '||message_order END,1,1 FROM message_rows
''',
          ['Historical text. ' * 1024],
        );
        await database.customStatement(
          "INSERT INTO message_rows(id,conversation_id,role,timestamp,message_order,group_id,version) VALUES('home-alternate','home-conv-0','assistant',1,100000,'home-msg-99999',1)",
        );
        await database.customStatement(
          "INSERT INTO message_part_rows(conversation_id,revision_id,ordinal,kind,payload,created_at,updated_at) VALUES('home-conv-0','home-alternate',0,'text','Alternate **complete** answer',1,1)",
        );
        await database.customSelect('PRAGMA wal_checkpoint(TRUNCATE)').get();
      } finally {
        await repository.close();
      }
      final databaseBytes = await File('${root.path}/kelivo.db').length();
      final startup = Stopwatch()..start();
      final frames = <FrameTiming>[];
      void collect(List<FrameTiming> batch) => frames.addAll(batch);
      SchedulerBinding.instance.addTimingsCallback(collect);
      ChatService? service;
      try {
        await app.main();
        MessageListView? view;
        for (var i = 0; i < 300; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          final finder = find.byType(MessageListView);
          if (finder.evaluate().length == 1) {
            view = tester.widget<MessageListView>(finder);
            if (view.messages.isNotEmpty) break;
          }
        }
        expect(view, isNotNull);
        expect(view!.messages.last.id, 'home-alternate');
        final startupMicros = startup.elapsedMicroseconds;
        service = tester.element(find.byType(ChatInputBar)).read<ChatService>();
        expect(service.getAllConversations(), hasLength(1000));
        final originalRead = Stopwatch()..start();
        await view.onVersionChange!('home-msg-99999', 0);
        await tester.pump();
        view = tester.widget<MessageListView>(find.byType(MessageListView));
        expect(view.messages.last.id, 'home-msg-99999');
        expect(view.messages.last.content, 'Visible **message** 99999');
        await view.onVersionChange!('home-msg-99999', 1);
        await tester.pump();
        view = tester.widget<MessageListView>(find.byType(MessageListView));
        expect(view.messages.last.content, 'Alternate **complete** answer');
        final versionMicros = originalRead.elapsedMicroseconds;
        frames.clear();
        int frameTime() => SchedulerBinding
            .instance
            .currentSystemFrameTimeStamp
            .inMicroseconds;
        final pagingStart = frameTime();
        final pageTimes = <int>[];
        for (var i = 0; i < 24; i++) {
          view = tester.widget<MessageListView>(find.byType(MessageListView));
          final watch = Stopwatch()..start();
          expect(await view.onLoadMoreBefore!(), isTrue);
          pageTimes.add(watch.elapsedMicroseconds);
          await tester.pump(const Duration(milliseconds: 30));
        }
        view = tester.widget<MessageListView>(find.byType(MessageListView));
        expect(
          view.messages.length,
          lessThanOrEqualTo(ChatService.defaultLoadedWindowMax),
        );
        final pagingEnd = frameTime();
        for (var i = 0; i < 10; i++) {
          await tester.drag(find.byType(MessageListView), const Offset(0, 400));
          await tester.pump(const Duration(milliseconds: 32));
        }
        final scrollingEnd = frameTime();
        final editor = find.descendant(
          of: find.byType(ChatInputBar),
          matching: find.byType(LongMessageEditor),
        );
        final field = tester.widget<LongMessageEditor>(editor);
        field.focusNode!.requestFocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
        await tester.pump(const Duration(seconds: 1));
        final keyboardInset = View.of(tester.element(editor)).viewInsets.bottom;
        expect(keyboardInset, greaterThan(0));
        final typingStart = frameTime();
        for (var i = 0; i < 30; i++) {
          final value = '性能测试 $i';
          field.controller.value = TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
          );
          field.onChanged?.call(value);
          await tester.pump(const Duration(milliseconds: 40));
        }
        expect(field.controller.text, '性能测试 29');
        final typingEnd = frameTime();
        field.focusNode!.unfocus();
        await tester.pump(const Duration(seconds: 1));
        expect(
          service.debugCachedMessageBytes,
          lessThanOrEqualTo(8 * 1024 * 1024),
        );
        expect(service.debugHasMessageOrderSkeleton('home-conv-0'), isFalse);
        expect(tester.takeException(), isNull);
        final build = frames.map((f) => f.buildDuration.inMicroseconds).toList()
          ..sort();
        final raster =
            frames.map((f) => f.rasterDuration.inMicroseconds).toList()..sort();
        Map<String, int> phase(int start, int end) {
          // Timings arrive in batches. Classify by the frame's own timestamp,
          // which uses the same clock as currentSystemFrameTimeStamp.
          final captured = frames.where((frame) {
            final stamp = frame.timestampInMicroseconds(FramePhase.buildStart);
            return stamp > start && stamp <= end;
          }).toList();
          expect(captured, isNotEmpty);
          final builds =
              captured.map((f) => f.buildDuration.inMicroseconds).toList()
                ..sort();
          final rasters =
              captured.map((f) => f.rasterDuration.inMicroseconds).toList()
                ..sort();
          return {
            'frames': captured.length,
            'buildP95Micros': builds[(builds.length * 0.95).floor()],
            'rasterP95Micros': rasters[(rasters.length * 0.95).floor()],
          };
        }

        pageTimes.sort();
        final result = <String, Object?>{
          'databaseBytes': databaseBytes,
          'conversations': 1000,
          'messages': 100001,
          'startupToWindowMicros': startupMicros,
          'versionRoundTripMicros': versionMicros,
          'pageMedianMicros': pageTimes[pageTimes.length ~/ 2],
          'retainedWindowMessages': view.messages.length,
          'cachedBytes': service.debugCachedMessageBytes,
          'rssBytes': ProcessInfo.currentRss,
          'frames': frames.length,
          'buildP95Micros': build[(build.length * 0.95).floor()],
          'rasterP95Micros': raster[(raster.length * 0.95).floor()],
          'keyboardInsetPx': keyboardInset,
          'phases': {
            'paging': phase(pagingStart, pagingEnd),
            'scrolling': phase(pagingEnd, scrollingEnd),
            'typing': phase(typingStart, typingEnd),
          },
        };
        binding.reportData = {'homeLargeDatabase': result};
        // ignore: avoid_print
        print('LARGE_HOME_RESULT ${jsonEncode(result)}');
      } finally {
        SchedulerBinding.instance.removeTimingsCallback(collect);
        await tester.pumpWidget(const SizedBox.shrink());
        await service?.close();
        PathProviderPlatform.instance = originalPaths;
        // The isolated app may still be closing background services. The test
        // process owns this cache directory; do not delete open SQLite handles.
      }
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

final class _FixturePaths extends PathProviderPlatform {
  _FixturePaths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getApplicationCachePath() async =>
      Directory('$root/cache').create(recursive: true).then((d) => d.path);
  @override
  Future<String?> getTemporaryPath() async =>
      Directory('$root/tmp').create(recursive: true).then((d) => d.path);
}
