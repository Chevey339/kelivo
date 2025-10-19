import Foundation
import FlutterMacOS

final class ICloudSyncHandler: NSObject, FlutterStreamHandler {
  static let shared = ICloudSyncHandler()

  private var observing = false
  private var applyingRemote = false
  private var eventSink: FlutterEventSink?

  private let kvStore = NSUbiquitousKeyValueStore.default
  private let keyPrefix = "flutter."

  func register(with controller: FlutterViewController) {
    let methodChannel = FlutterMethodChannel(
      name: "kelivo/icloud_kv",
      binaryMessenger: controller.engine.binaryMessenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "ICloud handler released", details: nil))
        return
      }
      switch call.method {
      case "initialize":
        DispatchQueue.main.async {
          self.startObserving()
          result(nil)
        }
      case "manualSync":
        DispatchQueue.main.async {
          self.syncLocalToICloud()
          result(nil)
        }
      case "shutdown":
        DispatchQueue.main.async {
          self.stopObserving()
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let eventChannel = FlutterEventChannel(
      name: "kelivo/icloud_kv_events",
      binaryMessenger: controller.engine.binaryMessenger
    )
    eventChannel.setStreamHandler(self)
  }

  private func startObserving() {
    guard !observing else { return }
    observing = true
    kvStore.synchronize()
    syncICloudToLocal(fullSync: true)
    syncLocalToICloud()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(userDefaultsChanged(_:)),
      name: UserDefaults.didChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(icloudChanged(_:)),
      name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
      object: kvStore
    )
  }

  private func stopObserving() {
    guard observing else { return }
    observing = false
    applyingRemote = false
    NotificationCenter.default.removeObserver(
      self,
      name: UserDefaults.didChangeNotification,
      object: nil
    )
    NotificationCenter.default.removeObserver(
      self,
      name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
      object: kvStore
    )
  }

  @objc private func userDefaultsChanged(_ notification: Notification) {
    if applyingRemote { return }
    syncLocalToICloud()
  }

  @objc private func icloudChanged(_ notification: Notification) {
    let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
    let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int ?? 0
    if reason == NSUbiquitousKeyValueStoreServerChange || reason == NSUbiquitousKeyValueStoreInitialSyncChange {
      syncICloudToLocal(changedKeys: keys)
    }
  }

  private func syncLocalToICloud() {
    guard observing else { return }
    let defaults = UserDefaults.standard.dictionaryRepresentation()
    var didChange = false

    for (key, value) in defaults where key.hasPrefix(keyPrefix) {
      if let current = kvStore.object(forKey: key) {
        if !valuesEqual(current, value) {
          kvStore.set(value, forKey: key)
          didChange = true
        }
      } else {
        kvStore.set(value, forKey: key)
        didChange = true
      }
    }

    let remote = kvStore.dictionaryRepresentation
    for key in remote.keys where key.hasPrefix(keyPrefix) && defaults[key] == nil {
      kvStore.removeObject(forKey: key)
      didChange = true
    }

    if didChange {
      kvStore.synchronize()
    }
  }

  private func syncICloudToLocal(changedKeys: [String]? = nil, fullSync: Bool = false) {
    guard observing else { return }
    let defaults = UserDefaults.standard
    applyingRemote = true

    var changedOut: [String] = []
    var removedOut: [String] = []

    if fullSync {
      let remote = kvStore.dictionaryRepresentation
      for (key, value) in remote where key.hasPrefix(keyPrefix) {
        if !valuesEqual(defaults.object(forKey: key), value) {
          defaults.set(value, forKey: key)
          changedOut.append(key)
        }
      }
      let local = defaults.dictionaryRepresentation()
      for (key, _) in local where key.hasPrefix(keyPrefix) && remote[key] == nil {
        defaults.removeObject(forKey: key)
        removedOut.append(key)
      }
    } else if let keys = changedKeys {
      for key in keys where key.hasPrefix(keyPrefix) {
        if let value = kvStore.object(forKey: key) {
          if !valuesEqual(defaults.object(forKey: key), value) {
            defaults.set(value, forKey: key)
            changedOut.append(key)
          }
        } else if defaults.object(forKey: key) != nil {
          defaults.removeObject(forKey: key)
          removedOut.append(key)
        }
      }
    }

    defaults.synchronize()
    applyingRemote = false

    if let sink = eventSink, (!changedOut.isEmpty || !removedOut.isEmpty) {
      sink(["changedKeys": changedOut, "removedKeys": removedOut])
    }
  }

  private func valuesEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil):
      return true
    case (nil, _), (_, nil):
      return false
    case let (l as NSNumber, r as NSNumber):
      return l == r
    case let (l as NSString, r as NSString):
      return l == r
    case let (l as NSArray, r as NSArray):
      return l.isEqual(r)
    case let (l as NSDictionary, r as NSDictionary):
      return l.isEqual(r)
    case let (l as Data, r as Data):
      return l == r
    default:
      if let lObj = lhs as? NSObject, let rObj = rhs as? NSObject {
        return lObj.isEqual(rObj)
      }
      return false
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
