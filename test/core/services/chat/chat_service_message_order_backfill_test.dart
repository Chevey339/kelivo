import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/utils/app_directories.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

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

class _SpyChatDatabaseRepository extends ChatDatabaseRepository {
  _SpyChatDatabaseRepository(super.db, {super.databaseFile});

  Object? messageIdsError;
  int getMessageIdsCalls = 0;

  @override
  Future<List<String>> getMessageIds(String conversationId) async {
    getMessageIdsCalls += 1;
    final error = messageIdsError;
    if (error != null) throw error;
    return super.getMessageIds(conversationId);
  }
}

/// Advances a frame then lets queued idle-priority scheduler tasks run.
///
/// Verify neither a post-frame callback nor an idle slot loads full history.
/// A plain microtask drain is not enough. Bare `test()` cases have no
/// WidgetTester pump loop — drive the frame callbacks manually.
Future<void> _flushIdleTasks() async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.scheduleFrame();
  binding.handleBeginFrame(Duration.zero);
  binding.handleDrawFrame();
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final services = <ChatService>[];
  final repositories = <_SpyChatDatabaseRepository>[];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'kelivo_message_order_backfill_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    for (final service in services) {
      await service.close();
    }
    services.clear();
    for (final repository in repositories) {
      await repository.close();
    }
    repositories.clear();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ChatService createService({ChatDatabaseRepository? existingRepository}) {
    final service = ChatService(existingRepository: existingRepository);
    services.add(service);
    return service;
  }

  Future<File> databaseFile() async {
    final appDataDir = await AppDirectories.getAppDataDirectory();
    return File('${appDataDir.path}/${AppDatabase.databaseFileName}');
  }

  Future<_SpyChatDatabaseRepository> openSpyRepository() async {
    final file = await databaseFile();
    final spy = _SpyChatDatabaseRepository(
      AppDatabase.open(file: file),
      databaseFile: file,
    );
    await spy.ensureReady();
    repositories.add(spy);
    return spy;
  }

  Future<(String, List<String>)> seedConversation({
    int messageCount = 5,
  }) async {
    final writer = createService();
    await writer.init();
    final conversation = await writer.createConversation(title: 'Chat');
    final ids = <String>[];
    for (var i = 0; i < messageCount; i++) {
      final message = await writer.addMessage(
        conversationId: conversation.id,
        role: i.isEven ? 'user' : 'assistant',
        content: 'message $i',
      );
      ids.add(message.id);
    }
    await writer.close();
    services.remove(writer);
    return (conversation.id, ids);
  }

  Future<(String, String, List<String>)> seedMultiVersionConversation() async {
    final writer = createService();
    await writer.init();
    final conversation = await writer.createConversation(title: 'Versions');
    final user = await writer.addMessage(
      conversationId: conversation.id,
      role: 'user',
      content: 'prompt',
    );
    final v0 = await writer.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'answer v0',
      groupId: 'answer',
      version: 0,
    );
    final v1 = await writer.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'answer v1',
      groupId: 'answer',
      version: 1,
    );
    await writer.setSelectedVersion(conversation.id, 'answer', 1);
    await writer.close();
    services.remove(writer);
    return (conversation.id, 'answer', [user.id, v0.id, v1.id]);
  }

  group('on-demand history identity', () {
    test('opening and idle time never load the full message order', () async {
      final (id, ids) = await seedConversation(messageCount: 60);
      final spy = await openSpyRepository();
      final service = createService(existingRepository: spy);
      await service.init();
      final page = await service.loadTimelinePage(id, limit: 40);
      await _flushIdleTasks();
      expect(page!.slots.length, 40);
      expect(page.slots.last.message.id, ids.last);
      expect(spy.getMessageIdsCalls, 0);
      expect(service.debugHasMessageOrderSkeleton(id), isFalse);
      expect(await service.getMessageIds(id), ids);
      expect(spy.getMessageIdsCalls, 1);
      expect(service.debugHasMessageOrderSkeleton(id), isFalse);
    });
    test('version groups remain available without an order skeleton', () async {
      final (id, group, ids) = await seedMultiVersionConversation();
      final spy = await openSpyRepository();
      final service = createService(existingRepository: spy);
      await service.init();
      final page = await service.loadTimelinePage(id);
      final versions = await service.loadMessagesForGroups(id, [group]);
      await _flushIdleTasks();
      expect(page!.slots.last.message.id, ids.last);
      expect(versions.map((m) => m.id), ids.skip(1));
      expect(spy.getMessageIdsCalls, 0);
      expect(service.debugHasMessageOrderSkeleton(id), isFalse);
    });
    test(
      'a failed explicit order read does not poison later window reads',
      () async {
        final (id, ids) = await seedConversation();
        final spy = await openSpyRepository()
          ..messageIdsError = StateError('read failed');
        final service = createService(existingRepository: spy);
        await service.init();
        await expectLater(service.getMessageIds(id), throwsStateError);
        final page = await service.loadTimelinePage(id);
        expect(page!.slots.last.message.id, ids.last);
        await _flushIdleTasks();
        expect(spy.getMessageIdsCalls, 1);
        spy.messageIdsError = null;
        expect(await service.getMessageIds(id), ids);
      },
    );
  });
}
