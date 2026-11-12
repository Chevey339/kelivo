import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var loginLaunch: Bool?
  private var launchCallbacks: [(Bool) -> Void] = []

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let event = NSAppleEventManager.shared().currentAppleEvent
    let launchedAtLogin = event?.eventID == kAEOpenApplication
      && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    loginLaunch = launchedAtLogin
    for callback in launchCallbacks { callback(launchedAtLogin) }
    launchCallbacks.removeAll()
    super.applicationDidFinishLaunching(notification)
  }

  func readLoginLaunch(_ completion: @escaping (Bool) -> Void) {
    if let value = loginLaunch {
      completion(value)
    } else {
      launchCallbacks.append(completion)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    let mainWindow = sender.windows.first { $0 is MainFlutterWindow }
      ?? sender.windows.first { $0.canBecomeKey }

    if let window = mainWindow {
      if window.isMiniaturized {
        window.deminiaturize(self)
      }
      window.orderFrontRegardless()
      window.makeKeyAndOrderFront(self)
    }

    sender.activate(ignoringOtherApps: true)
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
