import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BackupKeychainUnavailable implements Exception {
  const BackupKeychainUnavailable();
}

/// One device-only credential, isolated from server credentials and exports.
/// Android uses the plugin's Keystore-backed cipher. Linux uses the Runner's
/// APPLICATION_ID (com.psyche.kelivo) for its Secret Service schema.
class BackupSecurePasswordStore {
  const BackupSecurePasswordStore({this.namespace});
  final String? namespace;
  String get _key => namespace == null ? key : '$key.$namespace';
  static const key = 'kelivo.backup.encryption_password';
  static const _store = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    // The macOS Runner also ships with ad-hoc signing; its local login
    // keychain does not require a provisioned access group.
    mOptions: MacOsOptions(
      usesDataProtectionKeychain: false,
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // The Linux plugin explicitly asks to unlock a locked default collection.
  // Check the OS lock state before non-interactive reads or startup cleanup.
  Future<void> requireUnlocked() async {
    if (!Platform.isMacOS && !Platform.isLinux) return;
    try {
      if (await const MethodChannel(
            'kelivo/backup_keychain',
          ).invokeMethod<bool>('unlocked') !=
          true) {
        throw const BackupKeychainUnavailable();
      }
    } catch (_) {
      throw const BackupKeychainUnavailable();
    }
  }

  Future<String?> read() async {
    try {
      await requireUnlocked();
      return await _store.read(key: _key);
    } catch (_) {
      throw const BackupKeychainUnavailable();
    }
  }

  Future<void> remember(String password) async {
    try {
      await _store.write(key: _key, value: password);
      if (await read() != password) throw const BackupKeychainUnavailable();
    } catch (_) {
      throw const BackupKeychainUnavailable();
    }
  }

  Future<void> forget() async {
    try {
      await _store.delete(key: _key);
    } catch (_) {
      throw const BackupKeychainUnavailable();
    }
  }
}
