import ActivityKit
import AVFoundation
import CoreLocation
import Flutter
import UIKit
import UserNotifications

struct BackgroundGenerationTask {
  let id: String
  let conversationId: String
  let title: String
  let detail: String
  let startedAt: Date
  let tokens: Int
  let outcome: String
  let finishedAt: Date?

  init(_ map: [String: Any]) {
    id = map["id"] as? String ?? ""
    conversationId = map["conversationId"] as? String ?? ""
    title = String((map["title"] as? String ?? "Kelivo").prefix(120))
    detail = String((map["detail"] as? String ?? "").prefix(180))
    startedAt = Date(timeIntervalSince1970: ((map["startedAt"] as? NSNumber)?.doubleValue ?? 0) / 1000)
    tokens = map["tokens"] as? Int ?? 0
    outcome = map["outcome"] as? String ?? ""
    if let ms = map["finishedAt"] as? NSNumber {
      finishedAt = Date(timeIntervalSince1970: ms.doubleValue / 1000)
    } else {
      finishedAt = nil
    }
  }
}

/// Main-thread state, with a serial async queue for ActivityKit operations.
/// Display retention never extends the generation's resource lifetime.
@MainActor
final class MobileBackgroundHandler: NSObject, CLLocationManagerDelegate {
  private var channel: FlutterMethodChannel?
  private var tail: Task<Void, Never>?
  private var tasks: [BackgroundGenerationTask] = []
  private var settings: [String: Any] = [:]
  private var labels: [String: String] = [:]
  private var revision = -1
  private var assertion: UIBackgroundTaskIdentifier = .invalid
  private var activity: Any?
  private var activityRunIds: Set<String> = []
  private var activityObserver: Task<Void, Never>?
  private var suppressedRunIds: Set<String> = []
  private var heartbeat: Timer?
  private var lastPush = Date.distantPast
  private var nextActivityAttempt = Date.distantPast
  private var groupStartedAt: Date?
  private var finishedTask: BackgroundGenerationTask?
  private var didCleanActivities = false
  private var locationManager: CLLocationManager?
  private var locationActive = false
  private var preparingBackground = false
  private var assertionExpired = false
  private var audioEngine: AVAudioEngine?
  private var silentPlayer: AVAudioPlayerNode?
  private var audioOwners: Set<String> = []
  private var audioInterrupted = false
  private var observers: [NSObjectProtocol] = []
  private var lastError = UserDefaults.standard.string(forKey: "kelivo.background.lastError") ?? ""
  private var dartReady = false
  private static let pendingConversationKey = "kelivo.background.pendingConversation"

  static var liveActivitiesSupported: Bool {
    #if targetEnvironment(macCatalyst)
    return false
    #else
    guard !ProcessInfo.processInfo.isiOSAppOnMac else { return false }
    if UIDevice.current.userInterfaceIdiom == .pad {
      guard #available(iOS 17.0, *) else { return false }
    }
    if #available(iOS 16.1, *) { return true }
    return false
    #endif
  }

  func configure(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.mobile_background", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      Task { @MainActor in self?.handle(call, result: result) }
    }
    if UserDefaults.standard.bool(forKey: "kelivo.background.hadTasks") {
      recordError("previous_process_terminated")
    }
    UserDefaults.standard.set(false, forKey: "kelivo.background.hadTasks")
    observe(UIApplication.willResignActiveNotification) { handler in
      handler.preparingBackground = true
      handler.evaluateRuntime()
    }
    observe(UIApplication.didEnterBackgroundNotification) { handler in
      handler.preparingBackground = false
      handler.evaluateRuntime()
      handler.enqueue { await $0.updateActivity(force: true) }
    }
    observe(UIApplication.didBecomeActiveNotification) { handler in
      handler.assertionExpired = false
      handler.preparingBackground = false
      handler.nextActivityAttempt = .distantPast
      handler.evaluateRuntime()
      handler.enqueue { value in
        value.finishedTask = nil
        await value.updateActivity(force: true)
      }
    }
    observers.append(NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
    ) { [weak self] note in
      Task { @MainActor in
        guard let self else { return }
        let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue
        self.audioInterrupted = type == AVAudioSession.InterruptionType.began.rawValue
        if self.audioInterrupted {
          self.stopSilentAudio(deactivate: false)
          self.channel?.invokeMethod("pauseSpeech", arguments: nil)
        } else {
          self.evaluateRuntime()
        }
      }
    })
    observe(AVAudioSession.mediaServicesWereLostNotification) { handler in
      handler.audioInterrupted = true
      handler.stopSilentAudio(deactivate: false)
      handler.channel?.invokeMethod("pauseSpeech", arguments: nil)
    }
    observe(AVAudioSession.mediaServicesWereResetNotification) { handler in
      handler.audioInterrupted = false
      handler.stopSilentAudio(deactivate: false)
      handler.channel?.invokeMethod("pauseSpeech", arguments: nil)
      handler.evaluateRuntime()
    }
    observers.append(NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
    ) { [weak self] note in
      Task { @MainActor in
        guard let self else { return }
        let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
        if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
          self.channel?.invokeMethod("pauseSpeech", arguments: nil)
        }
        self.evaluateRuntime()
      }
    })
    enqueue { await $0.updateActivity(force: true) }
  }

  private func observe(_ name: Notification.Name, action: @escaping (MobileBackgroundHandler) -> Void) {
    observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
      Task { @MainActor in if let self { action(self) } }
    })
  }

  private func enqueue(_ action: @escaping (MobileBackgroundHandler) async -> Void) {
    let previous = tail
    tail = Task { @MainActor [weak self] in
      await previous?.value
      guard let self else { return }
      await action(self)
    }
  }

  private func enabled(_ key: String) -> Bool { settings[key] as? Bool == true }
  private var inBackground: Bool { UIApplication.shared.applicationState == .background }
  private var hasAudibleOwner: Bool { audioOwners.contains { $0 != "speechBuffering" } }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "sync":
      let args = call.arguments as? [String: Any] ?? [:]
      enqueue { handler in
        let nextRevision = args["revision"] as? Int ?? 0
        guard nextRevision > handler.revision else { handler.returnStatus(result); return }
        handler.revision = nextRevision
        let oldIds = Set(handler.tasks.map(\.id))
        let oldPrivate = handler.enabled("privacyMode")
        let changedSettings = !NSDictionary(dictionary: handler.settings).isEqual(to: args["settings"] as? [String: Any] ?? [:])
        handler.settings = args["settings"] as? [String: Any] ?? [:]
        handler.labels = args["labels"] as? [String: String] ?? [:]
        handler.tasks = (args["tasks"] as? [[String: Any]] ?? []).map(BackgroundGenerationTask.init).filter { !$0.id.isEmpty }
        let ids = Set(handler.tasks.map(\.id))
        if !ids.subtracting(oldIds).isEmpty { handler.suppressedRunIds = []; handler.assertionExpired = false }
        handler.suppressedRunIds.formIntersection(ids)
        if !handler.tasks.isEmpty {
          if handler.groupStartedAt == nil { handler.groupStartedAt = handler.tasks.map(\.startedAt).min() }
          handler.finishedTask = nil
          handler.evaluateRuntime()
        } else if let terminal = args["terminal"] as? [String: Any] {
          handler.finishedTask = BackgroundGenerationTask(terminal)
        }
        if !oldPrivate && handler.enabled("privacyMode") { handler.clearCompletionNotifications() }
        UserDefaults.standard.set(!handler.tasks.isEmpty, forKey: "kelivo.background.hadTasks")
        await handler.updateActivity(force: changedSettings || oldIds != ids || args["terminal"] is [String: Any])
        if handler.tasks.isEmpty { handler.groupStartedAt = nil }
        // Await Activity.end before giving the OS back the last assertion.
        handler.evaluateRuntime()
        handler.returnStatus(result)
      }
    case "getStatus": returnStatus(result)
    case "takePendingConversation":
      dartReady = true
      let id = UserDefaults.standard.string(forKey: Self.pendingConversationKey)
      UserDefaults.standard.removeObject(forKey: Self.pendingConversationKey)
      result(id)
    case "requestPermission": requestPermission(call.arguments as? String ?? "", result: result)
    case "openSettings": openSettings(call.arguments as? String ?? "app", result: result)
    case "audioOwner":
      let args = call.arguments as? [String: Any] ?? [:]
      let owner = args["owner"] as? String ?? ""
      if args["active"] as? Bool == true {
        audioOwners.insert(owner)
        if owner != "speechBuffering" { stopSilentAudio(deactivate: false) }
      } else {
        audioOwners.remove(owner)
      }
      evaluateRuntime()
      if audioOwners.isEmpty && audioEngine == nil && !audioInterrupted {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
      }
      result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  func receive(_ url: URL) -> Bool {
    guard url.scheme == "kelivo", url.host == "conversation" else { return false }
    let id = url.pathComponents.dropFirst().first ?? ""
    guard !id.isEmpty else { return false }
    if dartReady { channel?.invokeMethod("openConversation", arguments: id) }
    else { UserDefaults.standard.set(id, forKey: Self.pendingConversationKey) }
    return true
  }

  private func requestPermission(_ permission: String, result: @escaping FlutterResult) {
    guard UIApplication.shared.applicationState == .active else {
      result(FlutterError(code: "foreground_required", message: "Open Kelivo to request permission.", details: nil)); return
    }
    switch permission {
    case "notifications":
      UNUserNotificationCenter.current().getNotificationSettings { state in
        DispatchQueue.main.async {
          if state.authorizationStatus == .denied {
            self.openSettings("notifications", result: result)
          } else {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
              DispatchQueue.main.async {
                if let error { self.recordError(error.localizedDescription) }
                self.channel?.invokeMethod("statusChanged", arguments: nil)
                result(nil)
              }
            }
          }
        }
      }
    case "location":
      let location = manager()
      if location.authorizationStatus == .denied || location.authorizationStatus == .restricted {
        openSettings("app", result: result)
      } else {
        location.requestWhenInUseAuthorization()
        result(nil)
      }
    case "locationAlways":
      manager().requestAlwaysAuthorization()
      result(nil)
    default: result(nil)
    }
  }

  private func openSettings(_ destination: String, result: @escaping FlutterResult) {
    var target = UIApplication.openSettingsURLString
    if #available(iOS 16.0, *), destination == "notifications" { target = UIApplication.openNotificationSettingsURLString }
    guard let url = URL(string: target) else { result(nil); return }
    UIApplication.shared.open(url, options: [:]) { opened in
      result(opened ? nil : FlutterError(code: "settings_unavailable", message: "Unable to open system settings.", details: nil))
    }
  }

  private func manager() -> CLLocationManager {
    if let manager = locationManager { return manager }
    let manager = CLLocationManager()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    manager.distanceFilter = kCLDistanceFilterNone
    manager.pausesLocationUpdatesAutomatically = false
    manager.showsBackgroundLocationIndicator = true
    locationManager = manager
    return manager
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    evaluateRuntime()
    channel?.invokeMethod("statusChanged", arguments: nil)
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    // Location is only a task-scoped execution mechanism. Do not retain, log,
    // publish or forward any of these coordinates to the model/tool pipeline.
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    if (error as? CLError)?.code == .denied {
      manager.stopUpdatingLocation()
      locationActive = false
      recordError("location_permission_denied")
    }
  }

  private func evaluateRuntime() {
    let generationNeeded = enabled("iosEnabled") && !tasks.isEmpty
    let speechNeeded = enabled("backgroundSpeechEnabled") && (audioOwners.contains("speech") || audioOwners.contains("speechBuffering"))
    let needed = generationNeeded || speechNeeded
    if needed && assertion == .invalid && !assertionExpired {
      assertion = UIApplication.shared.beginBackgroundTask(withName: "KelivoGeneration") { [weak self] in
        guard let self else { return }
        self.assertionExpired = true
        self.endAssertion()
        if self.enabled("iosEnabled") && self.audioEngine == nil && !self.locationActive && !self.hasAudibleOwner {
          self.recordError("background_time_expired")
          self.channel?.invokeMethod("interrupted", arguments: ["ids": self.tasks.map(\.id), "reason": "background_time_expired"])
        }
      }
    } else if !needed { endAssertion() }

    // Narration, including network buffering, can take over the last
    // generation's location lease after its short background time expires.
    let wantsLocation = needed && enabled("iosEnabled") && enabled("locationEnabled") && (inBackground || preparingBackground)
    if wantsLocation {
      let manager = manager()
      let authorized = manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse
      if !authorized && locationActive {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        locationActive = false
      }
      // Arm while leaving the foreground. With When In Use permission a new
      // location session must not be started by a background-only callback.
      if authorized && !locationActive && (!inBackground || manager.authorizationStatus == .authorizedAlways) {
        manager.allowsBackgroundLocationUpdates = true
        manager.startUpdatingLocation()
        locationActive = true
      }
    } else if locationActive {
      locationManager?.stopUpdatingLocation()
      locationManager?.allowsBackgroundLocationUpdates = false
      locationActive = false
    }
    if needed && enabled("iosEnabled") && enabled("silentAudioEnabled") && (inBackground || preparingBackground) && !hasAudibleOwner && !audioInterrupted {
      startSilentAudio()
    } else {
      stopSilentAudio(deactivate: !hasAudibleOwner && !audioInterrupted)
    }
    if tasks.isEmpty || !enabled("liveActivitiesEnabled") {
      heartbeat?.invalidate(); heartbeat = nil
    } else if heartbeat == nil && activity != nil {
      heartbeat = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
        Task { @MainActor in self?.enqueue { await $0.updateActivity(force: false) } }
      }
    }
  }

  private func endAssertion() {
    guard assertion != .invalid else { return }
    let value = assertion
    assertion = .invalid
    UIApplication.shared.endBackgroundTask(value)
  }

  private func startSilentAudio() {
    guard audioEngine == nil else { return }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
      let engine = AVAudioEngine()
      let player = AVAudioPlayerNode()
      guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100) else { throw NSError(domain: "KelivoAudio", code: 1) }
      buffer.frameLength = 44100
      if let samples = buffer.floatChannelData?[0] { samples.initialize(repeating: 0, count: 44100) }
      engine.attach(player)
      engine.connect(player, to: engine.mainMixerNode, format: format)
      player.scheduleBuffer(buffer, at: nil, options: .loops)
      try engine.start()
      player.play()
      audioEngine = engine
      silentPlayer = player
    } catch {
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
      recordError("silent_audio_failed: \(error.localizedDescription)")
    }
  }

  private func stopSilentAudio(deactivate: Bool) {
    guard audioEngine != nil else { return }
    silentPlayer?.stop(); audioEngine?.stop()
    silentPlayer = nil; audioEngine = nil
    if deactivate { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
  }

  private func updateActivity(force: Bool) async {
    guard Self.liveActivitiesSupported else { return }
    if #available(iOS 16.1, *) {
      var existing = activity as? Activity<KelivoGenerationActivityAttributes>
      // The state stream can trail a sync. Respect removal synchronously as
      // well, without suppressing a new run that arrived after that activity.
      if let previous = existing, previous.activityState == .ended || previous.activityState == .dismissed {
        suppressedRunIds.formUnion(activityRunIds)
        activity = nil
        existing = nil
      }
      // Enumeration is for orphan cleanup, not proof that a just-requested
      // activity disappeared: Activity.activities can lag creation.
      if !didCleanActivities || !enabled("liveActivitiesEnabled") || !inBackground {
        for other in Activity<KelivoGenerationActivityAttributes>.activities where other.id != existing?.id {
          await end(other, state: nil, immediately: true)
        }
        didCleanActivities = true
      }
      guard enabled("liveActivitiesEnabled"), ActivityAuthorizationInfo().areActivitiesEnabled else {
        if let existing { activity = nil; await end(existing, state: nil, immediately: true) }
        finishedTask = nil
        return
      }
      if tasks.isEmpty {
        if let existing {
          activity = nil
          let terminal = finishedTask
          let immediate = !inBackground || terminal == nil || terminal?.outcome == "cancelled"
          let state = terminal.map { contentState(task: $0, finished: true) }
          await end(existing, state: state, immediately: immediate)
        }
        groupStartedAt = nil
        return
      }
      guard !Set(tasks.map(\.id)).isSubset(of: suppressedRunIds), let task = tasks.first else { return }
      let state = contentState(task: task, finished: false)
      if let existing, isRunning(existing) {
        let interval = inBackground ? 5.0 : 3.0
        guard force || Date().timeIntervalSince(lastPush) >= interval else { return }
        activityRunIds = Set(tasks.map(\.id))
        if #available(iOS 16.2, *) {
          await existing.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(60)))
        } else { await existing.update(using: state) }
        lastPush = Date()
      } else {
        guard UIApplication.shared.applicationState == .active else { return }
        guard Date() >= nextActivityAttempt else { return }
        nextActivityAttempt = Date().addingTimeInterval(10)
        do {
          let attributes = KelivoGenerationActivityAttributes(groupId: UUID().uuidString)
          let next: Activity<KelivoGenerationActivityAttributes>
          if #available(iOS 16.2, *) {
            next = try Activity.request(attributes: attributes,
                content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(60)), pushType: nil)
          } else { next = try Activity.request(attributes: attributes, contentState: state, pushType: nil) }
          activity = next
          activityRunIds = Set(tasks.map(\.id))
          nextActivityAttempt = .distantPast
          lastPush = Date()
          activityObserver?.cancel()
          activityObserver = Task { @MainActor [weak self] in
            for await state in next.activityStateUpdates {
              guard let self, !Task.isCancelled else { return }
              if state == .dismissed || state == .ended {
                if (self.activity as? Activity<KelivoGenerationActivityAttributes>)?.id == next.id {
                  self.suppressedRunIds.formUnion(self.activityRunIds)
                  self.activity = nil
                  self.channel?.invokeMethod("statusChanged", arguments: nil)
                }
                return
              }
            }
          }
        } catch { recordError("live_activity_failed: \(error.localizedDescription)") }
      }
    }
  }

  @available(iOS 16.1, *)
  private func isRunning(_ activity: Activity<KelivoGenerationActivityAttributes>) -> Bool {
    if #available(iOS 16.2, *) {
      return activity.activityState == .active || activity.activityState == .stale
    }
    return activity.activityState == .active
  }

  @available(iOS 16.1, *)
  private func contentState(task: BackgroundGenerationTask, finished: Bool) -> KelivoGenerationActivityAttributes.ContentState {
    KelivoGenerationActivityAttributes.ContentState(
      displayTitle: tasks.count > 1 ? "\(tasks.count) \(labels["tasks"] ?? "Tasks")" : task.title,
      detail: task.detail,
      tokenCount: tasks.isEmpty ? task.tokens : tasks.reduce(0) { $0 + $1.tokens },
      startedAt: groupStartedAt ?? task.startedAt,
      finishedAt: finished ? task.finishedAt ?? Date() : nil,
      activeTaskCount: tasks.count,
      conversationId: task.conversationId,
      outcome: finished ? task.outcome : "",
      staleMessage: labels["stale"] ?? "Open Kelivo to check the task.")
  }

  @available(iOS 16.1, *)
  private func end(_ target: Activity<KelivoGenerationActivityAttributes>,
                   state: KelivoGenerationActivityAttributes.ContentState?, immediately: Bool) async {
    let seconds = max(0, min(900, settings["completionSeconds"] as? Int ?? 60))
    let dismissal: ActivityUIDismissalPolicy = immediately || seconds == 0
        ? .immediate : .after(Date().addingTimeInterval(TimeInterval(seconds)))
    if #available(iOS 16.2, *) {
      await target.end(state.map { ActivityContent(state: $0, staleDate: nil) }, dismissalPolicy: dismissal)
    } else { await target.end(using: state, dismissalPolicy: dismissal) }
  }

  private func returnStatus(_ result: @escaping FlutterResult) {
    // Capture this operation's state before the asynchronous permission query.
    // A queued completion/retry must not change an earlier sync's result.
    var activitiesEnabled = false
    var activityActive = false
    if Self.liveActivitiesSupported, #available(iOS 16.1, *) {
      activitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
      if let activity = activity as? Activity<KelivoGenerationActivityAttributes> {
        activityActive = isRunning(activity)
      }
    }
    let location: String
    switch manager().authorizationStatus {
    case .authorizedAlways: location = "always"
    case .authorizedWhenInUse: location = "whenInUse"
    case .notDetermined: location = "notDetermined"
    default: location = "denied"
    }
    let snapshot: [String: Any] = [
      "backgroundTaskActive": assertion != .invalid,
      "activeTasks": tasks.count,
      "liveActivitiesSupported": Self.liveActivitiesSupported,
      "liveActivitiesEnabled": activitiesEnabled,
      "liveActivityActive": activityActive,
      "locationAuthorization": location,
      "locationActive": locationActive,
      "silentAudioActive": audioEngine != nil,
      "lastError": lastError,
    ]
    UNUserNotificationCenter.current().getNotificationSettings { permissions in
      DispatchQueue.main.async {
        result(snapshot.merging([
          "notificationsAuthorized": permissions.authorizationStatus == .authorized || permissions.authorizationStatus == .provisional,
        ]) { _, new in new })
      }
    }
  }

  private func clearCompletionNotifications() {
    UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
      let ids = notifications.filter { $0.request.content.threadIdentifier == "kelivo.chat-completion" }.map { $0.request.identifier }
      UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }
  }

  private func recordError(_ error: String) {
    lastError = error
    UserDefaults.standard.set(error, forKey: "kelivo.background.lastError")
    NSLog("Kelivo background: %@", error)
  }

  func prepareForTermination() {
    locationManager?.stopUpdatingLocation()
    locationManager?.allowsBackgroundLocationUpdates = false
    locationActive = false
    stopSilentAudio(deactivate: audioOwners.isEmpty)
    endAssertion()
    tasks = []
    finishedTask = nil
    heartbeat?.invalidate()
    enqueue { await $0.updateActivity(force: true) }
  }
}
