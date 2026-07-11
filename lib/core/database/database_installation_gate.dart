import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../services/backup/restore_durability.dart';
import 'app_database.dart';
import 'chat_database_repository.dart';

final class DatabaseInstallationReceipt {
  const DatabaseInstallationReceipt({
    required this.installationId,
    required this.databaseId,
  });

  static const formatVersion = 1;

  final String installationId;
  final String databaseId;

  Map<String, Object> toJson() => {
    'version': formatVersion,
    'installationId': installationId,
    'databaseId': databaseId,
  };

  static DatabaseInstallationReceipt fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value.length != 3 ||
        value['version'] != formatVersion ||
        value['installationId'] is! String ||
        value['databaseId'] is! String) {
      throw const FormatException('database_installation_receipt');
    }
    final receipt = DatabaseInstallationReceipt(
      installationId: value['installationId'] as String,
      databaseId: value['databaseId'] as String,
    );
    if (!_isUuid(receipt.installationId) || !_isUuid(receipt.databaseId)) {
      throw const FormatException('database_installation_receipt');
    }
    return receipt;
  }
}

final class DatabaseSessionReceipt {
  const DatabaseSessionReceipt({
    required this.installationId,
    required this.databaseId,
    required this.sessionId,
  });

  static const formatVersion = 1;

  final String installationId;
  final String databaseId;
  final String sessionId;

  Map<String, Object> toJson() => {
    'version': formatVersion,
    'installationId': installationId,
    'databaseId': databaseId,
    'sessionId': sessionId,
  };

  static DatabaseSessionReceipt fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value.length != 4 ||
        value['version'] != formatVersion ||
        value['installationId'] is! String ||
        value['databaseId'] is! String ||
        value['sessionId'] is! String) {
      throw const FormatException('database_session_receipt');
    }
    final receipt = DatabaseSessionReceipt(
      installationId: value['installationId'] as String,
      databaseId: value['databaseId'] as String,
      sessionId: value['sessionId'] as String,
    );
    if (!_isUuid(receipt.installationId) ||
        !_isUuid(receipt.databaseId) ||
        !_isUuid(receipt.sessionId)) {
      throw const FormatException('database_session_receipt');
    }
    return receipt;
  }
}

final class DatabaseInstallationGate {
  DatabaseInstallationGate._();

  static const _receiptPrefix = 'database_installation_receipt_';
  static const _receiptSuffix = '.json';
  static const _temporaryFileName = '.database_installation_receipt.tmp';
  static const _sessionFileName = '.database_session_receipt.json';
  static const _sessionTemporaryFileName = '.database_session_receipt.tmp';
  static const _maximumReceiptBytes = 4096;

  static Future<DatabaseInstallationReceipt> ensureReady({
    required Directory appDataDirectory,
    bool allowDatabaseIdentityChange = false,
    RestoreDurability? durability,
  }) async {
    final resolvedDurability = durability ?? RestorePlatformDurability();
    await appDataDirectory.create(recursive: true);
    final databaseFile = File(
      p.join(appDataDirectory.path, AppDatabase.databaseFileName),
    );
    final receipts = await _readReceipts(appDataDirectory);
    final staleSession = await _readSessionReceipt(appDataDirectory);
    final databaseType = await FileSystemEntity.type(
      databaseFile.path,
      followLinks: false,
    );
    if (receipts.isNotEmpty && databaseType == FileSystemEntityType.notFound) {
      throw StateError('database_missing');
    }
    if (databaseType != FileSystemEntityType.notFound &&
        databaseType != FileSystemEntityType.file) {
      throw StateError('database_type');
    }

    late InstalledChatDatabaseInfo info;
    try {
      if (databaseType == FileSystemEntityType.notFound) {
        final repository = ChatDatabaseRepository.open(file: databaseFile);
        try {
          await repository.ensureReady();
        } finally {
          await repository.close();
        }
      } else {
        await ChatDatabaseRepository.migrateInstalledDatabase(databaseFile);
      }

      info = ChatDatabaseRepository.inspectInstalledDatabase(
        databaseFile,
        validateContents: receipts.isEmpty,
      );
    } catch (error) {
      if (databaseType == FileSystemEntityType.file &&
          _requiresAdmissionQuickCheck(error)) {
        ChatDatabaseRepository.inspectUncleanInstalledDatabase(databaseFile);
      }
      rethrow;
    }
    if (info.databaseId == null) {
      if (receipts.isNotEmpty) {
        ChatDatabaseRepository.inspectUncleanInstalledDatabase(databaseFile);
        if (!allowDatabaseIdentityChange) {
          throw StateError('database_identity_missing');
        }
      }
      final databaseId = const Uuid().v4();
      ChatDatabaseRepository.assignInstalledDatabaseIdentity(
        databaseFile,
        databaseId,
      );
      info = ChatDatabaseRepository.inspectInstalledDatabase(databaseFile);
    }
    final databaseId = info.databaseId!;
    final matching = receipts
        .where((entry) => entry.receipt.databaseId == databaseId)
        .toList(growable: false);
    if (matching.length > 1) {
      throw StateError('database_installation_receipt_duplicate');
    }
    if (matching.length == 1) {
      await _recoverUncleanSession(
        databaseFile: databaseFile,
        installationReceipt: matching.single.receipt,
        sessionReceipt: staleSession,
        durability: resolvedDurability,
      );
      await _removeStaleReceipts(
        receipts.where((entry) => entry.file.path != matching.single.file.path),
        durability: resolvedDurability,
      );
      return matching.single.receipt;
    }
    if (receipts.isNotEmpty) {
      ChatDatabaseRepository.inspectUncleanInstalledDatabase(databaseFile);
      if (!allowDatabaseIdentityChange) {
        throw StateError('database_identity_mismatch');
      }
    }
    final installationIds = receipts
        .map((entry) => entry.receipt.installationId)
        .toSet();
    if (installationIds.length > 1) {
      throw StateError('database_installation_identity_mismatch');
    }
    final updated = DatabaseInstallationReceipt(
      installationId: installationIds.firstOrNull ?? const Uuid().v4(),
      databaseId: databaseId,
    );
    final receiptFile = File(
      p.join(
        appDataDirectory.path,
        '$_receiptPrefix${updated.databaseId}$_receiptSuffix',
      ),
    );
    await _publishReceipt(receiptFile, updated, durability: resolvedDurability);
    if (staleSession != null &&
        allowDatabaseIdentityChange &&
        receipts.any(
          (entry) =>
              entry.receipt.installationId == staleSession.installationId &&
              entry.receipt.databaseId == staleSession.databaseId,
        )) {
      if (updated.installationId != staleSession.installationId) {
        throw StateError('database_session_identity_mismatch');
      }
      await _removeSessionReceipt(
        databaseFile.parent,
        durability: resolvedDurability,
      );
    } else {
      await _recoverUncleanSession(
        databaseFile: databaseFile,
        installationReceipt: updated,
        sessionReceipt: staleSession,
        durability: resolvedDurability,
      );
    }
    await _removeStaleReceipts(receipts, durability: resolvedDurability);
    return updated;
  }

  static Future<DatabaseSessionReceipt?> beginSessionIfInstalled({
    required Directory appDataDirectory,
    required String? databaseId,
    RestoreDurability? durability,
  }) async {
    final receipts = await _readReceipts(appDataDirectory);
    if (receipts.isEmpty) return null;
    if (databaseId == null) throw StateError('database_identity_missing');
    final matching = receipts
        .where((entry) => entry.receipt.databaseId == databaseId)
        .toList(growable: false);
    if (matching.length != 1) {
      throw StateError('database_installation_receipt_match');
    }
    final installationReceipt = matching.single.receipt;
    final sessionReceipt = DatabaseSessionReceipt(
      installationId: installationReceipt.installationId,
      databaseId: installationReceipt.databaseId,
      sessionId: const Uuid().v4(),
    );
    await _publishSessionReceipt(
      appDataDirectory,
      sessionReceipt,
      durability: durability ?? RestorePlatformDurability(),
    );
    return sessionReceipt;
  }

  static Future<void> endSession({
    required Directory appDataDirectory,
    required DatabaseSessionReceipt sessionReceipt,
    RestoreDurability? durability,
  }) async {
    final existing = await _readSessionReceipt(appDataDirectory);
    if (existing == null ||
        existing.installationId != sessionReceipt.installationId ||
        existing.databaseId != sessionReceipt.databaseId ||
        existing.sessionId != sessionReceipt.sessionId) {
      throw StateError('database_session_receipt_mismatch');
    }
    await File(p.join(appDataDirectory.path, _sessionFileName)).delete();
    await (durability ?? RestorePlatformDurability()).syncDirectory(
      appDataDirectory,
      fullBarrier: true,
    );
  }

  static Future<DatabaseInstallationReceipt?> read({
    required Directory appDataDirectory,
  }) async {
    final receipts = await _readReceipts(appDataDirectory);
    if (receipts.isEmpty) return null;
    final databaseFile = File(
      p.join(appDataDirectory.path, AppDatabase.databaseFileName),
    );
    if (!await databaseFile.exists()) throw StateError('database_missing');
    final databaseId = ChatDatabaseRepository.inspectInstalledDatabase(
      databaseFile,
    ).databaseId;
    final matching = receipts
        .where((entry) => entry.receipt.databaseId == databaseId)
        .toList(growable: false);
    if (matching.length != 1) {
      throw StateError('database_installation_receipt_match');
    }
    return matching.single.receipt;
  }

  static Future<List<({File file, DatabaseInstallationReceipt receipt})>>
  _readReceipts(Directory directory) async {
    final receipts = <({File file, DatabaseInstallationReceipt receipt})>[];
    await for (final entity in directory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!name.startsWith(_receiptPrefix) || !name.endsWith(_receiptSuffix)) {
        continue;
      }
      if (await FileSystemEntity.type(entity.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('database_installation_receipt_type');
      }
      final file = File(entity.path);
      final receipt = await _readReceipt(file);
      if (name != '$_receiptPrefix${receipt.databaseId}$_receiptSuffix') {
        throw const FormatException('database_installation_receipt_name');
      }
      receipts.add((file: file, receipt: receipt));
    }
    return receipts;
  }

  static Future<DatabaseSessionReceipt?> _readSessionReceipt(
    Directory directory,
  ) async {
    final file = File(p.join(directory.path, _sessionFileName));
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.file) {
      throw StateError('database_session_receipt_type');
    }
    if (await file.length() > _maximumReceiptBytes) {
      throw const FormatException('database_session_receipt');
    }
    return DatabaseSessionReceipt.fromJson(
      jsonDecode(await file.readAsString()),
    );
  }

  static Future<void> _recoverUncleanSession({
    required File databaseFile,
    required DatabaseInstallationReceipt installationReceipt,
    required DatabaseSessionReceipt? sessionReceipt,
    required RestoreDurability durability,
  }) async {
    if (sessionReceipt == null) return;
    if (sessionReceipt.installationId != installationReceipt.installationId ||
        sessionReceipt.databaseId != installationReceipt.databaseId) {
      throw StateError('database_session_identity_mismatch');
    }
    final info = ChatDatabaseRepository.inspectUncleanInstalledDatabase(
      databaseFile,
    );
    if (info.databaseId != installationReceipt.databaseId) {
      throw StateError('database_identity_mismatch');
    }
    await _removeSessionReceipt(databaseFile.parent, durability: durability);
  }

  static Future<void> _removeSessionReceipt(
    Directory directory, {
    required RestoreDurability durability,
  }) async {
    await File(p.join(directory.path, _sessionFileName)).delete();
    await durability.syncDirectory(directory, fullBarrier: true);
  }

  static Future<void> _removeStaleReceipts(
    Iterable<({File file, DatabaseInstallationReceipt receipt})> entries, {
    required RestoreDurability durability,
  }) async {
    Directory? parent;
    for (final entry in entries) {
      await entry.file.delete();
      parent = entry.file.parent;
    }
    if (parent != null) {
      await durability.syncDirectory(parent, fullBarrier: true);
    }
  }

  static Future<DatabaseInstallationReceipt> _readReceipt(File file) async {
    if (await file.length() > _maximumReceiptBytes) {
      throw const FormatException('database_installation_receipt');
    }
    final decoded = jsonDecode(await file.readAsString());
    return DatabaseInstallationReceipt.fromJson(decoded);
  }

  static Future<void> _publishReceipt(
    File target,
    DatabaseInstallationReceipt receipt, {
    required RestoreDurability durability,
  }) async {
    final temporary = File(p.join(target.parent.path, _temporaryFileName));
    if (await FileSystemEntity.type(temporary.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('database_installation_receipt_temporary');
    }
    try {
      await temporary.create(exclusive: true);
      await durability.restrictFile(temporary);
      await temporary.writeAsString(jsonEncode(receipt.toJson()), flush: true);
      await durability.syncFile(temporary, fullBarrier: true);
      if (await target.exists()) {
        throw StateError('database_installation_receipt_collision');
      }
      await durability.renameAndSync(
        source: temporary,
        targetPath: target.path,
      );
      final published = await _readReceipt(target);
      if (published.installationId != receipt.installationId ||
          published.databaseId != receipt.databaseId) {
        throw StateError('database_installation_receipt_publish');
      }
    } finally {
      if (await FileSystemEntity.type(temporary.path, followLinks: false) ==
          FileSystemEntityType.file) {
        await temporary.delete();
        await durability.syncDirectory(target.parent, fullBarrier: true);
      }
    }
  }

  static Future<void> _publishSessionReceipt(
    Directory directory,
    DatabaseSessionReceipt receipt, {
    required RestoreDurability durability,
  }) async {
    final target = File(p.join(directory.path, _sessionFileName));
    final temporary = File(p.join(directory.path, _sessionTemporaryFileName));
    if (await FileSystemEntity.type(target.path, followLinks: false) !=
            FileSystemEntityType.notFound ||
        await FileSystemEntity.type(temporary.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
      throw StateError('database_session_receipt_exists');
    }
    try {
      await temporary.create(exclusive: true);
      await durability.restrictFile(temporary);
      await temporary.writeAsString(jsonEncode(receipt.toJson()), flush: true);
      await durability.syncFile(temporary, fullBarrier: true);
      await durability.renameAndSync(
        source: temporary,
        targetPath: target.path,
      );
      final published = await _readSessionReceipt(directory);
      if (published == null || published.sessionId != receipt.sessionId) {
        throw StateError('database_session_receipt_publish');
      }
    } finally {
      if (await FileSystemEntity.type(temporary.path, followLinks: false) ==
          FileSystemEntityType.file) {
        await temporary.delete();
        await durability.syncDirectory(directory, fullBarrier: true);
      }
    }
  }
}

bool _requiresAdmissionQuickCheck(Object error) {
  if (error is! StateError) return false;
  final code = error.message.toString();
  return code == 'database_corrupt' ||
      code == 'required_tables' ||
      code.startsWith('table_schema:');
}

bool _isUuid(String value) => RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
).hasMatch(value);
