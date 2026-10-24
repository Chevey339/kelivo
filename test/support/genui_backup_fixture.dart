import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_source_selection.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_source_hash.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_stream_parser.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/storage/ui_state_repository.dart';
import 'package:Kelivo/utils/app_directories.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

const genUiBackupBody = r'''ui 1 catalog "kelivo.native/1"
$factor: number = 2
root = Column(children=[field,total,items])
field = Slider(label="Factor", bind=$factor, min=0, max=100)
total = Metric(label="Synthetic total", value=$factor * 3)
items = DataTable(data=[{"id":"one","v":1},{"id":"two","v":2}], rowKey="id", columns=[{"key":"id","label":"Item"},{"key":"v","label":"Value"}])
''';
const genUiBackupFence = '```kelivo-ui\n$genUiBackupBody```\n';

class _FixturePaths extends PathProviderPlatform {
  _FixturePaths(this.root);
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

/// A real live database and ChatService, with every filesystem root contained
/// in the caller's disposable directory. Export uses the production snapshot.
final class GenUiBackupFixture {
  GenUiBackupFixture._(
    this.appData,
    this.database,
    this.repository,
    this.chat,
    this.preferences,
    this._previousPaths,
  );
  final Directory appData;
  final AppDatabase database;
  final ChatDatabaseRepository repository;
  final ChatService chat;
  final BusinessPreferences preferences;
  final PathProviderPlatform _previousPaths;
  bool _closed = false;

  DataSync get sync => DataSync(
    chatService: chat,
    businessRepository: BusinessRepository(database),
    businessPreferences: preferences,
  );

  static Future<GenUiBackupFixture> create(
    Directory root, {
    QueryInterceptor? interceptor,
  }) async {
    final previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FixturePaths(root.path);
    SandboxPathResolver.debugSetDirs(docsDir: root.path, supportDir: root.path);
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Kelivo',
      packageName: 'Kelivo',
      version: '1.3.1',
      buildNumber: '80',
      buildSignature: 'synthetic-test',
    );
    final appData = await AppDirectories.getAppDataDirectory();
    if (!p.equals(appData.path, root.path) &&
        !p.isWithin(root.path, appData.path)) {
      throw StateError('Fixture must not access the installed application');
    }
    await appData.create(recursive: true);
    final file = File(p.join(appData.path, AppDatabase.databaseFileName));
    final database = interceptor == null
        ? AppDatabase.open(file: file)
        : AppDatabase(
            NativeDatabase(
              file,
              setup: (connection) {
                // Match the production connection while intercepting real SQL.
                connection.execute('PRAGMA journal_mode = WAL;');
                connection.execute('PRAGMA foreign_keys = ON;');
              },
            ).interceptWith(interceptor),
          );
    final repository = ChatDatabaseRepository(database, databaseFile: file);
    final chat = ChatService(existingRepository: repository);
    await repository.ensureReady();
    await repository.markMigrationComplete();
    await chat.init();
    final preferences = BusinessPreferences(BusinessRepository(database));
    await preferences.load();
    final fixture = GenUiBackupFixture._(
      appData,
      database,
      repository,
      chat,
      preferences,
      previousPaths,
    );
    await fixture._seed();
    return fixture;
  }

  Future<void> _seed() async {
    final at = DateTime.utc(2026, 8, 1);
    final messages = [
      ChatMessage(
        id: 'question',
        conversationId: 'genui-legacy',
        role: 'user',
        content: 'Ordinary message before the interface',
        timestamp: at,
      ),
      for (final version in [0, 1])
        ChatMessage(
          id: 'a$version',
          conversationId: 'genui-legacy',
          role: 'assistant',
          groupId: 'a0',
          version: version,
          timestamp: at,
          content: 'Version $version\n\n$genUiBackupFence',
        ),
    ];
    await repository.putMigrationBatch(
      conversations: [
        Conversation(
          id: 'genui-legacy',
          title: 'Synthetic GenUI backup',
          createdAt: at,
          updatedAt: at,
          messageIds: messages.map((m) => m.id).toList(),
          versionSelections: const {'a0': 1},
        ),
      ],
      messages: [
        for (final (order, message) in messages.indexed)
          (message: message, messageOrder: order),
      ],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );
    for (final id in ['a0', 'a1']) {
      await database
          .into(database.generationRunRows)
          .insert(
            GenerationRunRowsCompanion.insert(
              id: 'run-$id',
              conversationId: 'genui-legacy',
              targetRevisionId: id,
              state: 'completed',
              createdAt: at,
              updatedAt: at,
              terminalAt: Value(at),
            ),
          );
    }
    await accept(revision: 'a0', value: 7, flush: true);
    await accept(revision: 'a1', value: 9, flush: true);
    await repository.rebuildGenUiSearchIndex();
    await accept(value: 15); // This accepted update must be flushed by export.
  }

  Future<UiStateLease> accept({
    String revision = 'a1',
    num value = 15,
    bool flush = false,
  }) async {
    final message = (await repository.getMessage(revision))!;
    final fence = uiEligibleFences(message).single;
    final parsed = UiStreamParser().update(fence.body, closed: true);
    if (parsed.invalid) throw StateError('Invalid synthetic source');
    final snapshot = UiSurfaceSnapshot(
      owner: UiSurfaceOwner(revisionId: revision, surfaceKey: fence.surfaceKey),
      sourceHash: uiSourceHash(parsed.source),
      state: UiSurfaceState.normalize(
        parsed.program,
        inputs: {'factor': value},
        view: const {
          'items': {'sortKey': 'v', 'descending': true, 'filter': 'o'},
        },
      ),
    );
    final lease = repository.genUiStates.attach(
      message.conversationId,
      snapshot.owner,
      snapshot.sourceHash,
    )!;
    if (!repository.genUiStates.accept(lease, snapshot)) {
      throw StateError('Snapshot rejected');
    }
    if (flush) await repository.genUiStates.flush();
    return lease;
  }

  Future<void> closeConnections() async {
    if (_closed) return;
    await chat.close();
    await repository.close();
    _closed = true;
  }

  Future<void> dispose() async {
    await closeConnections();
    chat.dispose();
    PathProviderPlatform.instance = _previousPaths;
    SandboxPathResolver.debugSetDirs(docsDir: null, supportDir: null);
  }
}
