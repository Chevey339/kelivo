import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BackupKeychainUnavailable implements Exception {
  const BackupKeychainUnavailable();
}

enum MacBackupAuthorization { locked, denied, cancelled }

class BackupMacKeychainAccessError extends BackupKeychainUnavailable {
  const BackupMacKeychainAccessError(this.reason);
  final MacBackupAuthorization reason;
}

/// One device-only credential, isolated from server credentials and exports.
class BackupSecurePasswordStore {
  const BackupSecurePasswordStore({this.namespace});
  final String? namespace;
  String get _key => namespace == null ? key : '$key.$namespace';
  static const key = 'kelivo.backup.encryption_password';
  static const _channel = MethodChannel('kelivo/backup_keychain');
  static const _store = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // The Linux plugin asks to unlock a locked collection. Unattended work
  // checks first. The Mac native backend suppresses UI in reads and deletes.
  Future<void> requireUnlocked() async {
    if (!Platform.isLinux) return;
    try {
      if (await _channel.invokeMethod<bool>('unlocked') != true) {
        throw const BackupKeychainUnavailable();
      }
    } catch (_) {
      throw const BackupKeychainUnavailable();
    }
  }

  static Future<bool> openMacKeychainAccess() async {
    try {
      return await _channel.invokeMethod<bool>('openKeychainAccess') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<T?> _mac<T>(
    String method, {
    String? password,
    bool newConsent = false,
    bool previousRemovalPending = false,
  }) async {
    try {
      return await _channel.invokeMethod<T>(method, {
        'account': _key,
        if (password != null) 'password': password,
        if (newConsent) 'newConsent': true,
        if (previousRemovalPending) 'previousRemovalPending': true,
      });
    } on PlatformException catch (error) {
      throw switch (error.code) {
        'backup_keychain_locked' => const BackupMacKeychainAccessError(
          MacBackupAuthorization.locked,
        ),
        'backup_keychain_auth' => const BackupMacKeychainAccessError(
          MacBackupAuthorization.denied,
        ),
        'backup_keychain_cancelled' => const BackupMacKeychainAccessError(
          MacBackupAuthorization.cancelled,
        ),
        _ => const BackupKeychainUnavailable(),
      };
    } on MissingPluginException {
      throw const BackupKeychainUnavailable();
    }
  }

  Future<String?> read() async {
    if (Platform.isMacOS) return _mac<String>('read');
    try {
      await requireUnlocked();
      return await _store.read(key: _key);
    } catch (_) {
      throw const BackupKeychainUnavailable();
    }
  }

  Future<void> remember(
    String password, {
    bool newConsent = false,
    bool previousRemovalPending = false,
  }) async {
    if (Platform.isMacOS) {
      return _mac<void>(
        'remember',
        password: password,
        newConsent: newConsent,
        previousRemovalPending: previousRemovalPending,
      );
    }
    try {
      await _store.write(key: _key, value: password);
      if (await read() != password) throw const BackupKeychainUnavailable();
    } catch (_) {
      throw const BackupKeychainUnavailable();
    }
  }

  Future<void> forget() async {
    if (Platform.isMacOS) return _mac<void>('forget');
    try {
      await _store.delete(key: _key);
    } catch (_) {
      throw const BackupKeychainUnavailable();
    }
  }
}
