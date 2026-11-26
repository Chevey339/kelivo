import CryptoKit
import Foundation
import Security

@main
struct MacManagedBackupKeychainTest {
  private static let account = BackupPasswordKeychain.account + ".device-fixture"
  private static let first = "first synthetic backup password 🔒"
  private static let second = "rotated synthetic backup password 🔒"

  static func main() throws {
    let phase = CommandLine.arguments[1]
    if phase == "capability" { print(SecureEnclave.isAvailable ? "supported" : "unsupported"); return }
    let root = URL(fileURLWithPath: CommandLine.arguments[2]).appendingPathComponent("vault")
    let fixture = URL(fileURLWithPath: CommandLine.arguments[2]).appendingPathComponent("login-fixture.keychain-db")
    // No synthetic test uses the user's real login keychain or changes its password.
    let unreachable = BackupPasswordKeychain { throw BackupPasswordKeychain.Failure(status: errSecAuthFailed) }
    let store = MacBackupPasswordStore(login: unreachable, root: { root })
    let id = SHA256.hash(data: Data(account.utf8)).map { String(format: "%02x", $0) }.joined()
    let dir = root.appendingPathComponent(id)
    let handle = dir.appendingPathComponent("device-key.plist")
    let database = dir.appendingPathComponent("password.keychain-db")
    let files = FileManager.default
    let fixtureStore = BackupPasswordKeychain {
      var ref: SecKeychain?
      let status = SecKeychainOpen(fixture.path, &ref)
      guard status == errSecSuccess, let ref else { throw BackupPasswordKeychain.Failure(status: status) }
      return ref
    }
    switch phase {
    case "enroll", "pending-enroll":
      do { _ = try store.read(account); fatalError("Default test keychain should reject access") }
      catch let failure as BackupPasswordKeychain.Failure { precondition(failure.status == errSecAuthFailed) }
      precondition(!files.fileExists(atPath: root.path))
      try store.remember(first, account: account, newConsent: true, previousRemovalPending: phase == "pending-enroll")
      let saved = try store.read(account)
      precondition(saved == first)
      let attrs = try files.attributesOfItem(atPath: dir.path)
      precondition((attrs[.posixPermissions] as? NSNumber)?.intValue == 0o700)
      for url in [handle, database] {
        let bytes = try Data(contentsOf: url)
        precondition(bytes.range(of: Data(first.utf8)) == nil)
      }
    case "check-locked":
      var ref: SecKeychain?
      precondition(SecKeychainOpen(database.path, &ref) == errSecSuccess)
      var flags: SecKeychainStatus = 0
      precondition(SecKeychainGetStatus(ref, &flags) == errSecSuccess)
      precondition(flags & UInt32(kSecUnlockStateStatus) == 0)
    case "cold-read", "rotate":
      let saved = try store.read(account)
      precondition(saved == first)
      if phase == "rotate" {
        try store.remember(second, account: account, newConsent: false, previousRemovalPending: false)
      }
    case "revoke":
      let saved = try store.read(account)
      precondition(saved == second)
      try store.forget(account)
      try store.forget(account)
      let removed = try store.read(account)
      precondition(removed == nil && !files.fileExists(atPath: database.path))
      let metadata = try PropertyListSerialization.propertyList(from: Data(contentsOf: handle), format: nil) as? [String: Any]
      precondition(metadata != nil && metadata?["keys"] == nil)
    case "create-login":
      let pass = UUID().uuidString
      var ref: SecKeychain?
      precondition(SecKeychainCreate(fixture.path, UInt32(pass.utf8.count), pass, false, nil, &ref) == errSecSuccess)
      let olderMac = MacBackupPasswordStore(login: fixtureStore, root: { root }, hasSecureEnclave: false)
      try olderMac.remember("legacy", account: account, newConsent: true, previousRemovalPending: false)
      precondition(!files.fileExists(atPath: root.path))
      // A credential previously kept in login can still be read and rotated.
      let upgraded = MacBackupPasswordStore(login: fixtureStore, root: { root })
      let prior = try upgraded.read(account)
      precondition(prior == "legacy")
      try upgraded.remember("legacy rotation", account: account, newConsent: false, previousRemovalPending: false)
      let updated = try fixtureStore.read(account)
      precondition(updated == "legacy rotation" && !files.fileExists(atPath: root.path))
    case "revoke-pending":
      do { try store.forget(account); fatalError("Old login removal should remain pending") }
      catch let failure as BackupPasswordKeychain.Failure { precondition(failure.status == errSecAuthFailed) }
      precondition(!files.fileExists(atPath: database.path))
      let repaired = MacBackupPasswordStore(login: fixtureStore, root: { root })
      try repaired.forget(account)
      let old = try fixtureStore.read(account)
      precondition(old == nil)
      try store.forget(account) // No further cleanup owed to the login keychain.
    case "fallback-from-retired":
      let changedMac = MacBackupPasswordStore(login: fixtureStore, root: { root }, hasSecureEnclave: false)
      try changedMac.remember(first, account: account, newConsent: true, previousRemovalPending: false)
      precondition(!files.fileExists(atPath: handle.path))
      let stored = try changedMac.read(account)
      precondition(stored == first)
      try changedMac.forget(account)
      let deleted = try fixtureStore.read(account)
      precondition(deleted == nil)
    case "cleanup":
      for url in [database, fixture] where files.fileExists(atPath: url.path) {
        var ref: SecKeychain?
        precondition(SecKeychainOpen(url.path, &ref) == errSecSuccess && SecKeychainDelete(ref) == errSecSuccess)
      }
    default:
      fatalError("Unknown test phase")
    }
  }
}
