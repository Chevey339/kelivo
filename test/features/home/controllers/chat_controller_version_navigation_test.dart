import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/features/home/controllers/chat_controller.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

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

class _GatedSelectionService extends ChatService {
  Completer<void>? gate;
  final entered = Completer<void>();
  Completer<void>? hydrationGate;
  final hydrationEntered = Completer<void>();
  final hydratedIds = <List<String>>[];

  @override
  Future<List<ChatMessage>> loadMessagesByIds(List<String> ids) async {
    hydratedIds.add(List.of(ids));
    final messages = await super.loadMessagesByIds(ids);
    if (!hydrationEntered.isCompleted) hydrationEntered.complete();
    await hydrationGate?.future;
    return messages;
  }

  @override
  Future<void> setSelectedVersion(
    String conversationId,
    String groupId,
    int version,
  ) async {
    if (!entered.isCompleted) entered.complete();
    await gate?.future;
    await super.setSelectedVersion(conversationId, groupId, version);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform paths;
  late _GatedSelectionService service;
  late ChatController controller;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kelivo_version_nav_');
    paths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    SandboxPathResolver.debugSetDirs(
      docsDir: directory.path,
      supportDir: directory.path,
    );
    service = _GatedSelectionService();
    controller = ChatController(chatService: service);
    await service.init();
  });
  tearDown(() async {
    if (service.gate?.isCompleted == false) service.gate!.complete();
    if (service.hydrationGate?.isCompleted == false) {
      service.hydrationGate!.complete();
    }
    controller.dispose();
    await service.close();
    await Hive.close();
    PathProviderPlatform.instance = paths;
    SandboxPathResolver.debugSetDirs(docsDir: null, supportDir: null);
    await directory.delete(recursive: true);
  });

  for (final temporary in [false, true]) {
    test(
      'deleting the selected version hydrates its survivor ($temporary)',
      () async {
        final conversation = temporary
            ? await service.createDraftConversation(
                title: 'Versions',
                temporary: true,
              )
            : await service.createConversation(title: 'Versions');
        final v0 = await service.addMessage(
          conversationId: conversation.id,
          role: 'assistant',
          content: 'original body',
          reasoningText: 'original reasoning',
          modelId: 'original-model',
          providerId: 'original-provider',
        );
        final v1 = (await service.appendMessageVersion(
          messageId: v0.id,
          content: 'edited body',
        ))!;
        final neighbor = await service.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: 'neighbor',
        );
        await controller.setCurrentConversationAndLoad(
          service.getConversation(conversation.id),
        );
        final versions = controller.groupedMessages[v0.id]!;
        if (!temporary) expect(versions.first.content, isEmpty);
        await service.deleteMessages(
          conversationId: conversation.id,
          messageIds: {v1.id},
          versionSelectionChanges: {v0.id: 0},
        );
        controller.loadVersionSelections();
        expect(
          await controller.refreshTimelineAfterMutation(
            removedRevisionIds: {v1.id},
            survivingVersionsByGroup: {
              v0.id: versions.where((m) => m.id != v1.id).toList(),
            },
          ),
          isTrue,
        );
        final restored = controller.collapsedMessages.first;
        expect(restored.id, v0.id);
        expect(restored.content, 'original body');
        expect(restored.reasoningText, 'original reasoning');
        expect(restored.modelId, 'original-model');
        expect(restored.providerId, 'original-provider');
        expect(controller.collapsedMessages.last.id, neighbor.id);
        expect(controller.totalMessageCount, 2);
        expect(service.hydratedIds, [
          [v0.id],
        ]);
      },
    );
  }

  test(
    'survivor hydration cannot replace a newly opened conversation',
    () async {
      final conversation = await service.createConversation(title: 'Versions');
      final v0 = await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        content: 'original',
      );
      final v1 = (await service.appendMessageVersion(
        messageId: v0.id,
        content: 'edited',
      ))!;
      await controller.setCurrentConversationAndLoad(
        service.getConversation(conversation.id),
      );
      final versions = controller.groupedMessages[v0.id]!;
      await service.deleteMessages(
        conversationId: conversation.id,
        messageIds: {v1.id},
        versionSelectionChanges: {v0.id: 0},
      );
      controller.loadVersionSelections();
      service.hydrationGate = Completer<void>();
      final refresh = controller.refreshTimelineAfterMutation(
        removedRevisionIds: {v1.id},
        survivingVersionsByGroup: {
          v0.id: [versions.first],
        },
      );
      await service.hydrationEntered.future;
      final other = await service.createConversation(title: 'Other');
      final message = await service.addMessage(
        conversationId: other.id,
        role: 'user',
        content: 'other body',
      );
      await controller.setCurrentConversationAndLoad(
        service.getConversation(other.id),
      );
      service.hydrationGate!.complete();
      expect(await refresh, isFalse);
      expect(controller.currentConversation?.id, other.id);
      expect(controller.collapsedMessages.single.id, message.id);
      expect(controller.collapsedMessages.single.content, 'other body');
    },
  );

  test(
    'temporary version choices and cursors resolve the logical group',
    () async {
      final conversation = await service.createDraftConversation(
        title: 'Temporary',
        temporary: true,
      );
      final before = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'before',
      );
      final v0 = await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        content: 'original body',
      );
      final v1 = (await service.appendMessageVersion(
        messageId: v0.id,
        content: 'edited body',
      ))!;
      final after = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'after',
      );
      await controller.setCurrentConversationAndLoad(
        service.getConversation(conversation.id),
      );
      expect(controller.collapsedMessages[1].id, v1.id);
      await controller.setSelectedVersion(v0.id, 0);
      expect(service.getVersionSelections(conversation.id)[v0.id], 0);
      expect(controller.collapsedMessages[1].id, v0.id);
      expect(controller.collapsedMessages[1].content, 'original body');
      expect(
        (await service.loadTimelinePage(
          conversation.id,
          beforeRevisionId: v1.id,
          limit: 1,
        ))!.slots.single.message.id,
        before.id,
      );
      expect(
        (await service.loadTimelinePage(
          conversation.id,
          afterRevisionId: v1.id,
          limit: 1,
        ))!.slots.single.message.id,
        after.id,
      );
      await controller.setSelectedVersion(v0.id, 1);
      expect(controller.collapsedMessages[1].id, v1.id);
      expect(controller.collapsedMessages[1].content, 'edited body');
    },
  );

  test(
    'same-conversation navigation retains a pending version choice',
    () async {
      final conversation = await service.createConversation(title: 'History');
      final ids = <String>[];
      for (var i = 0; i < 100; i++) {
        ids.add(
          (await service.addMessage(
            conversationId: conversation.id,
            role: 'assistant',
            content: 'message $i',
          )).id,
        );
      }
      final v0Id = ids[70];
      final v1 = (await service.appendMessageVersion(
        messageId: v0Id,
        content: 'edited 70',
      ))!;
      await controller.setCurrentConversationAndLoad(
        service.getConversation(conversation.id),
      );
      expect(controller.collapsedMessages.any((m) => m.id == v1.id), isTrue);
      service.gate = Completer<void>();
      final selecting = controller.setSelectedVersion(v0Id, 0);
      await service.entered.future;
      expect(
        await controller.loadUntilMessageVisible(ids[50], pageSize: 30),
        isTrue,
      );
      expect(controller.collapsedMessages.any((m) => m.id == v1.id), isTrue);
      service.gate!.complete();
      await selecting;
      expect(service.getVersionSelections(conversation.id)[v0Id], 0);
      expect(controller.versionSelections[v0Id], 0);
      expect(
        controller.collapsedMessages
            .firstWhere((m) => (m.groupId ?? m.id) == v0Id)
            .id,
        v0Id,
      );
      expect(controller.collapsedMessages.any((m) => m.id == ids[50]), isTrue);
    },
  );
}
