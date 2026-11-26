import 'package:Kelivo/core/services/backup/backup_secure_password_store.dart';

class TestBackupPasswordStore extends BackupSecurePasswordStore {
  bool? lastNewConsent;
  bool available = true;
  bool readable = true;
  bool cancelAuthorization = false;
  String? value;
  @override
  Future<String?> read() async {
    if (!available || !readable) throw const BackupKeychainUnavailable();
    return value;
  }

  @override
  Future<void> remember(
    String password, {
    bool newConsent = false,
    bool previousRemovalPending = false,
  }) async {
    if (cancelAuthorization) {
      throw const BackupMacKeychainAccessError(
        MacBackupAuthorization.cancelled,
      );
    }
    if (!available) throw const BackupKeychainUnavailable();
    lastNewConsent = newConsent;
    value = password;
  }

  @override
  Future<void> requireUnlocked() async {
    if (!available) throw const BackupKeychainUnavailable();
  }

  @override
  Future<void> forget() async {
    if (!available) throw const BackupKeychainUnavailable();
    value = null;
  }
}
