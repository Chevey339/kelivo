import CryptoKit
import Darwin
import Foundation
import LocalAuthentication
import Security

/// New authorizations use an app-owned macOS keychain on Macs with a Secure
/// Enclave. Existing login-keychain credentials stay at their original location.
struct MacBackupPasswordStore {
  private let login: BackupPasswordKeychain
  private let root: () throws -> URL
  private let hasSecureEnclave: Bool

  init(login: BackupPasswordKeychain = BackupPasswordKeychain(),
       root: @escaping () throws -> URL = credentialsDirectory,
       hasSecureEnclave: Bool = SecureEnclave.isAvailable) {
    self.login = login
    self.root = root
    self.hasSecureEnclave = hasSecureEnclave
  }

  private static func credentialsDirectory() throws -> URL {
    guard let bundle = Bundle.main.bundleIdentifier else { throw Failure(status: errSecNotAvailable) }
    let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: false)
    return support.appendingPathComponent(bundle).appendingPathComponent("BackupCredentials")
  }

  typealias Failure = BackupPasswordKeychain.Failure

  func remember(_ password: String, account: String, newConsent: Bool, previousRemovalPending: Bool) throws {
    let create = newConsent && hasSecureEnclave
    try withDirectory(account, create: create) { vault in
      guard let vault, try vault.isManaged() || create else {
        return try login.remember(password, account: account)
      }
      do {
        try vault.remember(password, account: account, canCreateKeys: create, previousRemovalPending: previousRemovalPending)
        vault.retryLoginRemoval(account, login: login)
      } catch PrivateKeychain.CreationError.hardwareUnavailable {
        // A virtual Mac can advertise an unusable enclave. A fresh consent
        // can fall back only when no existing private credential is at risk.
        guard newConsent else { throw Failure(status: errSecNotAvailable) }
        try vault.releaseRetiredRoute(account, login: login)
        try login.remember(password, account: account)
      }
    }
  }

  func read(_ account: String) throws -> String? {
    try withDirectory(account, create: false) { vault in
      guard let vault, try vault.isManaged() else { return try login.read(account) }
      let password = try vault.read(account)
      vault.retryLoginRemoval(account, login: login)
      return password
    }
  }

  func forget(_ account: String) throws {
    try withDirectory(account, create: false) { vault in
      guard let vault, try vault.isManaged() else { return try login.forget(account) }
      try vault.forget(account, login: login)
    }
  }

  /// Keep create/read/remove serialized across engines and processes, including
  /// while the private keychain is unlocked. The empty directory is the lock.
  private func withDirectory<T>(_ account: String, create: Bool, _ work: (PrivateKeychain?) throws -> T) throws -> T {
    guard BackupPasswordKeychain.validAccount(account) else { throw Failure(status: errSecParam) }
    let id = SHA256.hash(data: Data(account.utf8)).map { String(format: "%02x", $0) }.joined()
    var url = try root().appendingPathComponent(id, isDirectory: true)
    if create {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true,
                                              attributes: [.posixPermissions: 0o700])
    }
    let fd = open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    if fd < 0 {
      if !create && errno == ENOENT { return try work(nil) }
      throw Failure(status: errSecIO)
    }
    defer { close(fd) }
    var attributes = stat()
    guard fstat(fd, &attributes) == 0, attributes.st_uid == geteuid(),
          fchmod(fd, 0o700) == 0, flock(fd, LOCK_EX) == 0 else { throw Failure(status: errSecIO) }
    defer { flock(fd, LOCK_UN) }
    if create {
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try url.setResourceValues(values)
    }
    return try work(PrivateKeychain(directory: url))
  }
}

private typealias KeychainFailure = BackupPasswordKeychain.Failure

/// Only the enclave's device-bound key representation and the peer's public
/// key are saved. Reconstructing the keychain unlock secret requires an ECDH
/// operation inside this Mac's Secure Enclave. No second user password.
private struct UnlockMaterial: Codable {
  let deviceKey: Data
  let peerPublicKey: Data
  init() throws {
    let context = LAContext()
    context.interactionNotAllowed = true
    deviceKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(authenticationContext: context).dataRepresentation
    peerPublicKey = P256.KeyAgreement.PrivateKey().publicKey.x963Representation
  }

  func unlockSecret(for account: String) throws -> SymmetricKey {
    let context = LAContext()
    context.interactionNotAllowed = true
    let key = try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: deviceKey,
                                                             authenticationContext: context)
    let peer = try P256.KeyAgreement.PublicKey(x963Representation: peerPublicKey)
    let shared = try key.sharedSecretFromKeyAgreement(with: peer)
    return shared.hkdfDerivedSymmetricKey(using: SHA256.self,
      salt: Data("Kelivo local backup keychain v1".utf8), sharedInfo: Data(account.utf8), outputByteCount: 32)
  }
}

private struct PrivateKeychain {
  let directory: URL
  private var database: URL { directory.appendingPathComponent("password.keychain-db") }
  private var handle: URL { directory.appendingPathComponent("device-key.plist") }

  private func present(_ url: URL) throws -> Bool {
    var file = stat()
    guard lstat(url.path, &file) == 0 else {
      if errno == ENOENT { return false }
      throw KeychainFailure(status: errSecIO)
    }
    guard file.st_mode & S_IFMT == S_IFREG, file.st_uid == geteuid(), file.st_nlink == 1 else {
      throw KeychainFailure(status: errSecIO)
    }
    return true
  }

  /// Retain only the route after revocation, so even a repeated forget never
  /// tries to access the login keychain for a private-only credential.
  private struct State: Codable {
    var keys: UnlockMaterial?
    var previousRemovalPending: Bool
  }

  enum CreationError: Error { case hardwareUnavailable }

  func isManaged() throws -> Bool { try present(handle) || present(database) }

  private func state() throws -> State? {
    guard try present(handle) else {
      if try present(database) { throw KeychainFailure(status: errSecDecode) }
      return nil
    }
    return try PropertyListDecoder().decode(State.self, from: Data(contentsOf: handle))
  }

  private func save(_ state: State) throws {
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    try encoder.encode(state).write(to: handle, options: .atomic)
  }

  func remember(_ password: String, account: String, canCreateKeys: Bool, previousRemovalPending: Bool) throws {
    let previous = try state()
    let keys: UnlockMaterial
    let secret: SymmetricKey
    if let existing = previous?.keys {
      keys = existing
      secret = try keys.unlockSecret(for: account)
    } else {
      guard canCreateKeys else { throw CreationError.hardwareUnavailable }
      if previous != nil { try deleteDatabase() } // Finish an interrupted revocation.
      do {
        keys = try UnlockMaterial()
        secret = try keys.unlockSecret(for: account)
      } catch {
        throw CreationError.hardwareUnavailable
      }
      // A killed writer can reopen the same database; no replacement key
      // is ever generated for an existing credential.
      try save(State(keys: keys, previousRemovalPending: previous?.previousRemovalPending ?? previousRemovalPending))
    }
    try access(secret: secret, create: true) { try $0.remember(password, account: account) }
  }

  func read(_ account: String) throws -> String? {
    guard let keys = try state()?.keys, try present(database) else { return nil }
    return try access(secret: keys.unlockSecret(for: account), create: false) { try $0.read(account) }
  }

  private func access<T>(secret: SymmetricKey, create: Bool,
                         _ operation: (BackupPasswordKeychain) throws -> T) throws -> T {
    // Keychain Services requires a canonical UTF-8 passphrase.
    var passphrase = secret.withUnsafeBytes { Data($0).base64EncodedData() }
    defer { passphrase.resetBytes(in: passphrase.startIndex..<passphrase.endIndex) }
    var ref: SecKeychain?
    let status: OSStatus
    if try present(database) {
      status = SecKeychainOpen(database.path, &ref)
    } else {
      guard create else { throw KeychainFailure(status: errSecNotAvailable) }
      status = passphrase.withUnsafeBytes {
        SecKeychainCreate(database.path, UInt32($0.count), $0.baseAddress, false, nil, &ref)
      }
    }
    guard status == errSecSuccess, let ref else { throw KeychainFailure(status: errSecNotAvailable) }
    defer { SecKeychainLock(ref) }
    let unlocked = passphrase.withUnsafeBytes { SecKeychainUnlock(ref, UInt32($0.count), $0.baseAddress, true) }
    guard unlocked == errSecSuccess else { throw KeychainFailure(status: errSecNotAvailable) }
    do {
      return try BackupPasswordKeychain.withoutPrompt { try operation(BackupPasswordKeychain { ref }) }
    } catch is KeychainFailure {
      // The managed store never asks the user to unlock a login keychain.
      throw KeychainFailure(status: errSecNotAvailable)
    }
  }

  /// Only a pending revocation from before enrollment can refer to a login
  /// item. Keep it pending while that keychain is offline.
  func retryLoginRemoval(_ account: String, login: BackupPasswordKeychain) {
    guard var saved = try? state(), saved.previousRemovalPending else { return }
    do {
      try login.forget(account)
      saved.previousRemovalPending = false
      try save(saved)
    } catch { /* Next access or explicit revocation will retry. */ }
  }

  func forget(_ account: String, login: BackupPasswordKeychain) throws {
    var retired = State(keys: nil, previousRemovalPending: (try? state()?.previousRemovalPending) ?? true)
    try save(retired) // Discard access to the secret even when the hardware is unavailable.
    try deleteDatabase()
    if retired.previousRemovalPending {
      try login.forget(account)
      retired.previousRemovalPending = false
      try save(retired)
    }
  }

  func releaseRetiredRoute(_ account: String, login: BackupPasswordKeychain) throws {
    guard let retired = try state() else { return }
    guard retired.keys == nil else { throw KeychainFailure(status: errSecNotAvailable) }
    try deleteDatabase()
    if retired.previousRemovalPending { try login.forget(account) }
    // Now a crash or a subsequent read/forget resolves to the login store.
    try FileManager.default.removeItem(at: handle)
  }

  private func deleteDatabase() throws {
    guard try present(database) else { return }
    var ref: SecKeychain?
    let opened = SecKeychainOpen(database.path, &ref)
    if opened == errSecSuccess, let ref {
      try BackupPasswordKeychain.withoutPrompt {
        let status = SecKeychainDelete(ref)
        guard status == errSecSuccess || status == errSecNoSuchKeychain ||
              status == errSecInvalidKeychain || status == errSecDecode else { throw KeychainFailure(status: errSecIO) }
      }
    } else if opened != errSecInvalidKeychain && opened != errSecDecode && opened != errSecNoSuchKeychain {
      throw KeychainFailure(status: errSecIO)
    }
    // Security.framework may be unable to delete a damaged database. This
    // exact regular file belongs only to this account in our private directory.
    if try present(database) { try FileManager.default.removeItem(at: database) }
  }
}
