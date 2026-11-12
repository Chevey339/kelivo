import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/utils/app_directories.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

class StorageImagesFixture {
  StorageImagesFixture._(this.root, this.database, this.previousPaths)
    : preferences = BusinessPreferences(BusinessRepository(database));

  final Directory root;
  final AppDatabase database;
  final BusinessPreferences preferences;
  final PathProviderPlatform previousPaths;

  static Future<StorageImagesFixture> create() async {
    final root = await Directory.systemTemp.createTemp('storage_images_');
    final previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    SandboxPathResolver.debugSetDirs(docsDir: root.path, supportDir: root.path);
    final databaseRoot = await AppDirectories.getAppDataDirectory();
    await databaseRoot.create(recursive: true);
    final database = AppDatabase(
      NativeDatabase(
        File('${databaseRoot.path}/${AppDatabase.databaseFileName}'),
      ),
    );
    final fixture = StorageImagesFixture._(root, database, previousPaths);
    await fixture.preferences.load();
    return fixture;
  }

  Future<File> file(String path, [List<int> bytes = const [1, 2, 3]]) async {
    final file = File('${root.path}/$path');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> assistants(List<Map<String, Object?>> items) =>
      preferences.setString('assistants_v1', jsonEncode(items));

  Future<void> message(List<MessagePart> parts) async {
    final repository = ChatDatabaseRepository(database);
    final conversation = Conversation(title: 'Images');
    await repository.putConversation(conversation);
    await repository.putMessage(
      ChatMessage(
        role: 'assistant',
        conversationId: conversation.id,
        parts: parts,
      ),
    );
  }

  Future<void> dispose() async {
    await database.close();
    PathProviderPlatform.instance = previousPaths;
    SandboxPathResolver.debugSetDirs();
    await root.delete(recursive: true);
  }
}

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getApplicationCachePath() async => '$root/cache';
  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';
}
