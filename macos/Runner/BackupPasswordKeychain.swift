import Foundation
import Security

/// Stores one backup password in the supplied macOS file-based keychain.
/// Existing credentials use the user's default keychain.
struct BackupPasswordKeychain {
  // Keep the account and service of existing flutter_secure_storage items.
  static let account = "kelivo.backup.encryption_password"
  private static let service = "flutter_secure_storage_service"

  struct Failure: Error {
    let status: OSStatus
    var locked = false

    var code: String {
      if status == errSecUserCanceled { return "backup_keychain_cancelled" }
      if locked { return "backup_keychain_locked" }
      if status == errSecAuthFailed || status == errSecInteractionNotAllowed { return "backup_keychain_auth" }
      return "backup_keychain_unavailable"
    }
  }

  let keychain: () throws -> SecKeychain

  init(keychain: @escaping () throws -> SecKeychain = defaultKeychain) {
    self.keychain = keychain
  }

  private static func defaultKeychain() throws -> SecKeychain {
    var ref: SecKeychain?
    try check(SecKeychainCopyDefault(&ref))
    guard let ref else { throw Failure(status: errSecNoDefaultKeychain) }
    return ref
  }

  private static func check(_ status: OSStatus) throws {
    guard status == errSecSuccess else { throw Failure(status: status) }
  }

  private func isUnlocked(_ keychain: SecKeychain) throws -> Bool {
    var flags: SecKeychainStatus = 0
    try Self.check(SecKeychainGetStatus(keychain, &flags))
    return flags & UInt32(kSecUnlockStateStatus) != 0
  }

  static func validAccount(_ value: String) -> Bool {
    value == account || value.hasPrefix(account + ".")
  }

  private func identity(_ account: String) throws -> [CFString: Any] {
    guard Self.validAccount(account) else {
      throw Failure(status: errSecParam)
    }
    return [kSecClass: kSecClassGenericPassword, kSecAttrService: Self.service, kSecAttrAccount: account]
  }

  private func lookup(_ identity: [CFString: Any], in keychain: SecKeychain) -> [CFString: Any] {
    var query = identity
    query[kSecMatchSearchList] = [keychain]
    return query
  }

  /// File-based keychains do not honor the data-protection keychain's
  /// authentication UI attributes. Restore the previous setting on every exit.
  static func withoutPrompt<T>(_ work: () throws -> T) throws -> T {
    var allowed: DarwinBoolean = false
    try Self.check(SecKeychainGetUserInteractionAllowed(&allowed))
    if allowed.boolValue { try Self.check(SecKeychainSetUserInteractionAllowed(false)) }
    defer { if allowed.boolValue { SecKeychainSetUserInteractionAllowed(true) } }
    return try work()
  }

  func read(_ account: String) throws -> String? {
    try Self.withoutPrompt {
      let target = try keychain()
      guard try isUnlocked(target) else { throw Failure(status: errSecInteractionNotAllowed, locked: true) }
      var query = try lookup(identity(account), in: target)
      query[kSecMatchLimit] = kSecMatchLimitOne
      query[kSecReturnData] = true
      var value: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &value)
      if status == errSecItemNotFound { return nil }
      try Self.check(status)
      guard let data = value as? Data, let password = String(data: data, encoding: .utf8) else {
        throw Failure(status: errSecDecode)
      }
      return password
    }
  }

  /// Called only from an explicit remember/change password action. macOS owns
  /// the unlock dialog. Kelivo never requests the Mac login password itself.
  func remember(_ password: String, account: String) throws {
    let item = try identity(account)
    let target = try keychain()
    if try !isUnlocked(target) {
      let status = SecKeychainUnlock(target, 0, nil, false)
      if status != errSecSuccess { throw Failure(status: status, locked: true) }
    }

    let query = lookup(item, in: target)
    let change: [CFString: Any] = [kSecValueData: Data(password.utf8)]
    var status = SecItemUpdate(query as CFDictionary, change as CFDictionary)
    if status == errSecItemNotFound {
      var insert = item
      insert[kSecUseKeychain] = target
      insert[kSecValueData] = change[kSecValueData]
      status = SecItemAdd(insert as CFDictionary, nil)
      if status == errSecDuplicateItem {
        status = SecItemUpdate(query as CFDictionary, change as CFDictionary)
      }
    }
    try Self.check(status)
    do {
      guard try read(account) == password else { throw Failure(status: errSecDecode) }
    } catch let failure as Failure where failure.status == errSecUserCanceled {
      // The write already committed: this is not a cancelled password change.
      throw Failure(status: errSecAuthFailed)
    }
  }

  func forget(_ account: String) throws {
    try Self.withoutPrompt {
      let target = try keychain()
      guard try isUnlocked(target) else { throw Failure(status: errSecInteractionNotAllowed, locked: true) }
      let query = try lookup(identity(account), in: target)
      let status = SecItemDelete(query as CFDictionary)
      if status != errSecItemNotFound { try Self.check(status) }
    }
  }
}
