import 'dart:io';
import 'package:path/path.dart' as p;
import 'database_installation_gate.dart';

import 'app_database.dart';
import 'business_repository.dart';
import 'chat_database_observer.dart';
import 'chat_database_repository.dart';
import 'extension_entity_store.dart';

final class ChatDatabaseLease {
  ChatDatabaseLease._(
    this.repository,
    this.businessRepository,
    this.extensionEntityStore,
    this._gateway,
  );

  /// Compatibility alias for existing chat-only callers.
  final ChatDatabaseRepository repository;
  ChatDatabaseRepository get chatRepository => repository;
  final BusinessRepository businessRepository;
  final ExtensionEntityStore extensionEntityStore;
  final ChatDatabaseGateway _gateway;
  bool _released = false;

  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _gateway._release(repository, businessRepository);
  }
}

typedef _DatabaseRepositories = ({
  ChatDatabaseRepository chat,
  BusinessRepository business,
  ExtensionEntityStore extensionEntities,
});

final class ChatDatabaseGateway {
  ChatDatabaseGateway({ChatDatabaseObserver? observer})
    : _observer = observer ?? ChatDatabaseObserver.instance;

  static final ChatDatabaseGateway instance = ChatDatabaseGateway();

  _DatabaseRepositories? _repositories;
  Future<_DatabaseRepositories>? _opening;
  Future<void>? _closing;
  Future<void>? _shutdown;
  String? _databasePath;
  int _leaseCount = 0;
  final ChatDatabaseObserver _observer;

  Future<ChatDatabaseLease> acquire(File databaseFile) async {
    if (_shutdown != null) throw StateError('database_gateway_shutdown');
    await _closing;
    if (_shutdown != null) throw StateError('database_gateway_shutdown');
    final requestedPath = databaseFile.absolute.path;
    final activePath = _databasePath;
    if (activePath != null && activePath != requestedPath) {
      throw StateError('database_gateway_path_mismatch');
    }

    var repositories = _repositories;
    if (repositories == null) {
      _databasePath = requestedPath;
      final opening = _opening ??= _open(databaseFile);
      try {
        repositories = await opening;
      } catch (_) {
        if (identical(_opening, opening)) {
          _opening = null;
          _databasePath = null;
        }
        rethrow;
      }
      if (identical(_opening, opening)) {
        _repositories = repositories;
        _opening = null;
      }
    }

    if (_shutdown != null) throw StateError('database_gateway_shutdown');

    _leaseCount++;
    return ChatDatabaseLease._(
      repositories.chat,
      repositories.business,
      repositories.extensionEntities,
      this,
    );
  }

  /// Process exit owns all leases. Wait for admission or an ordinary release,
  /// then close the shared connection once and prevent it from reopening.
  Future<void> shutdown() => _shutdown ??= Future<void>.microtask(() async {
    await _closing;
    final repositories = _repositories ?? await _opening;
    _repositories = null;
    _opening = null;
    _databasePath = null;
    _leaseCount = 0;
    await repositories?.chat.close();
  });

  Future<_DatabaseRepositories> _open(File databaseFile) async {
    return _observer.measure(ChatDatabaseOperation.gatewayOpen, () async {
      final installed =
          p.basename(databaseFile.path) == AppDatabase.databaseFileName;
      if (installed && !await databaseFile.exists()) {
        await DatabaseInstallationGate.ensureReady(
          appDataDirectory: databaseFile.parent,
        );
      }
      final database = AppDatabase.open(
        file: databaseFile,
        requireExisting: installed,
      );
      final chatRepository = ChatDatabaseRepository(
        database,
        databaseFile: databaseFile,
        observer: _observer,
      );
      try {
        await chatRepository.ensureReady();
        await chatRepository.validateConnectionContract();
        return (
          chat: chatRepository,
          business: BusinessRepository(database),
          extensionEntities: ExtensionEntityStore(database),
        );
      } catch (_) {
        await chatRepository.close();
        rethrow;
      }
    });
  }

  Future<void> _release(
    ChatDatabaseRepository chatRepository,
    BusinessRepository businessRepository,
  ) async {
    if (_shutdown != null) {
      await _shutdown;
      return;
    }
    final repositories = _repositories;
    if (repositories == null ||
        !identical(chatRepository, repositories.chat) ||
        !identical(businessRepository, repositories.business) ||
        _leaseCount <= 0) {
      throw StateError('database_gateway_lease');
    }
    _leaseCount--;
    if (_leaseCount != 0) return;

    _repositories = null;
    _databasePath = null;
    final closing = () async {
      await chatRepository.close();
    }();
    _closing = closing;
    try {
      await closing;
    } finally {
      if (identical(_closing, closing)) _closing = null;
    }
  }
}
