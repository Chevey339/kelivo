import Foundation
import Security

/// The test creates its own macOS keychain. Never set the user's default or
/// supply an unlock password for their login keychain.
@main
struct BackupPasswordKeychainTest {
  static let account = BackupPasswordKeychain.account + ".fixture"

  static func main() throws {
    let phase = CommandLine.arguments[1]
    let path = CommandLine.arguments[2]
    var ref: SecKeychain?
    if phase == "create" {
      let password = UUID().uuidString
      precondition(SecKeychainCreate(path, UInt32(password.utf8.count), password, false, nil, &ref) == errSecSuccess)
    } else {
      precondition(SecKeychainOpen(path, &ref) == errSecSuccess)
    }
    guard let ref else { fatalError("Missing test keychain") }
    let store = BackupPasswordKeychain { ref }
    switch phase {
    case "create":
      try store.forget(account)
      try store.remember("  first test password  ", account: account)
    case "reopen":
      let saved = try store.read(account)
      precondition(saved == "  first test password  ")
      try store.remember("second test password", account: account)
    case "locked":
      let saved = try store.read(account)
      precondition(saved == "second test password")
      try store.forget(account)
      try store.forget(account)
      let removed = try store.read(account)
      precondition(removed == nil)
      try store.remember("lock check", account: account)
      precondition(SecKeychainLock(ref) == errSecSuccess)
      do {
        _ = try store.read(account)
        fatalError("Unattended read must fail on a locked keychain")
      } catch let error as BackupPasswordKeychain.Failure {
        precondition(error.code == "backup_keychain_locked")
      }
    case "dispose":
      precondition(SecKeychainDelete(ref) == errSecSuccess)
    default:
      fatalError("Unknown phase")
    }
  }
}
