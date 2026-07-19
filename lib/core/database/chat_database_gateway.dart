import 'dart:io';

import 'app_database.dart';
import 'business_repository.dart';
import 'chat_database_observer.dart';
import 'chat_database_repository.dart';

final class ChatDatabaseLease {
  ChatDatabaseLease._(this.repository, this.businessRepository, this._gateway);

  /// Compatibility alias for existing chat-only callers.
  final ChatDatabaseRepository repository;
  ChatDatabaseRepository get chatRepository => repository;
  final BusinessRepository businessRepository;
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
});

final class ChatDatabaseGateway {
  ChatDatabaseGateway({ChatDatabaseObserver? observer})
    : _observer = observer ?? ChatDatabaseObserver.instance;

  static final ChatDatabaseGateway instance = ChatDatabaseGateway();

  _DatabaseRepositories? _repositories;
  Future<_DatabaseRepositories>? _opening;
  Future<void>? _closing;
  String? _databasePath;
  int _leaseCount = 0;
  final ChatDatabaseObserver _observer;

  Future<ChatDatabaseLease> acquire(File databaseFile) async {
    await _closing;
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

    _leaseCount++;
    return ChatDatabaseLease._(repositories.chat, repositories.business, this);
  }

  Future<_DatabaseRepositories> _open(File databaseFile) async {
    return _observer.measure(ChatDatabaseOperation.gatewayOpen, () async {
      final database = AppDatabase.open(file: databaseFile);
      final chatRepository = ChatDatabaseRepository(
        database,
        databaseFile: databaseFile,
        observer: _observer,
      );
      try {
        await chatRepository.ensureReady();
        await chatRepository.validateConnectionContract();
        return (chat: chatRepository, business: BusinessRepository(database));
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
