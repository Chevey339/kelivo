import Cocoa

// Kept independently of the Flutter event loop so Dart callback latency cannot
// masquerade as sleep. Screen sleep and App Nap do not change this snapshot.
final class DesktopSystemPowerState: NSObject {
  private let notifications: NotificationCenter
  private var sleeping = false
  private var lastWakeAt: Int64 = 0

  var snapshot: [String: Any] {
    ["sleeping": sleeping, "lastWakeAt": lastWakeAt]
  }

  init(notifications: NotificationCenter = NSWorkspace.shared.notificationCenter) {
    self.notifications = notifications
    super.init()
    notifications.addObserver(self, selector: #selector(willSleep(_:)),
                              name: NSWorkspace.willSleepNotification, object: nil)
    notifications.addObserver(self, selector: #selector(didWake(_:)),
                              name: NSWorkspace.didWakeNotification, object: nil)
  }

  @objc private func willSleep(_ notification: Notification) {
    sleeping = true
  }

  @objc private func didWake(_ notification: Notification) {
    sleeping = false
    lastWakeAt = Int64(Date().timeIntervalSince1970 * 1000)
  }

  deinit {
    notifications.removeObserver(self)
  }
}
