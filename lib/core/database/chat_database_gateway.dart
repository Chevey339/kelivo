import 'dart:io';

import 'chat_database_repository.dart';

final class ChatDatabaseLease {
  ChatDatabaseLease._(this.repository, this._gateway);

  final ChatDatabaseRepository repository;
  final ChatDatabaseGateway _gateway;
  bool _released = false;

  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _gateway._release(repository);
  }
}

final class ChatDatabaseGateway {
  ChatDatabaseGateway();

  static final ChatDatabaseGateway instance = ChatDatabaseGateway();

  ChatDatabaseRepository? _repository;
  Future<ChatDatabaseRepository>? _opening;
  Future<void>? _closing;
  String? _databasePath;
  int _leaseCount = 0;

  Future<ChatDatabaseLease> acquire(File databaseFile) async {
    await _closing;
    final requestedPath = databaseFile.absolute.path;
    final activePath = _databasePath;
    if (activePath != null && activePath != requestedPath) {
      throw StateError('database_gateway_path_mismatch');
    }

    var repository = _repository;
    if (repository == null) {
      _databasePath = requestedPath;
      final opening = _opening ??= _open(databaseFile);
      try {
        repository = await opening;
      } catch (_) {
        if (identical(_opening, opening)) {
          _opening = null;
          _databasePath = null;
        }
        rethrow;
      }
      if (identical(_opening, opening)) {
        _repository = repository;
        _opening = null;
      }
    }

    _leaseCount++;
    return ChatDatabaseLease._(repository, this);
  }

  Future<ChatDatabaseRepository> _open(File databaseFile) async {
    final repository = ChatDatabaseRepository.open(file: databaseFile);
    try {
      await repository.ensureReady();
      return repository;
    } catch (_) {
      await repository.close();
      rethrow;
    }
  }

  Future<void> _release(ChatDatabaseRepository repository) async {
    if (!identical(repository, _repository) || _leaseCount <= 0) {
      throw StateError('database_gateway_lease');
    }
    _leaseCount--;
    if (_leaseCount != 0) return;

    _repository = null;
    _databasePath = null;
    final closing = repository.close();
    _closing = closing;
    try {
      await closing;
    } finally {
      if (identical(_closing, closing)) _closing = null;
    }
  }
}
