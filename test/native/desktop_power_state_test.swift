import Cocoa

@main
struct PowerStateTest {
  static func main() {
    let notifications = NotificationCenter()
    weak var released: DesktopSystemPowerState?
    do {
      let power = DesktopSystemPowerState(notifications: notifications)
      released = power
      precondition(power.snapshot["sleeping"] as? Bool == false)
      precondition(power.snapshot["lastWakeAt"] as? Int64 == 0)

      // A dark screen or inactive window must not be mistaken for system sleep.
      notifications.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
      notifications.post(name: NSApplication.didResignActiveNotification, object: nil)
      precondition(power.snapshot["sleeping"] as? Bool == false)
      precondition(power.snapshot["lastWakeAt"] as? Int64 == 0)

      notifications.post(name: NSWorkspace.willSleepNotification, object: nil)
      precondition(power.snapshot["sleeping"] as? Bool == true)
      precondition(power.snapshot["lastWakeAt"] as? Int64 == 0)
      notifications.post(name: NSWorkspace.didWakeNotification, object: nil)
      precondition(power.snapshot["sleeping"] as? Bool == false)
      precondition((power.snapshot["lastWakeAt"] as? Int64 ?? 0) > 0)
    }
    precondition(released == nil)
    notifications.post(name: NSWorkspace.didWakeNotification, object: nil)
    print("Native system power snapshot passed")
  }
}
