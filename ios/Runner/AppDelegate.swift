 import Flutter
 import UIKit
 import AuthenticationServices
 import BackgroundTasks
 import UserNotifications
 import ActivityKit
 import EventKit

private let backgroundRefreshIdentifier = "psyche.kelivo.background-generation.refresh"
private let backgroundProcessingIdentifier = "psyche.kelivo.background-generation.processing"

@main
@objc class AppDelegate: FlutterAppDelegate {
   private let fileSaveHandler = NativeFileSaveHandler()
   private let backgroundGenerationHandler = IosBackgroundGenerationHandler()
   private let mcpOAuthHandler = IosMcpOAuthHandler()
   private let deviceLocalToolsHandler = DeviceLocalToolsHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    backgroundGenerationHandler.registerBackgroundTasks()
    if let controller = window?.rootViewController as? FlutterViewController {
      let clipboardChannel = FlutterMethodChannel(name: "app.clipboard", binaryMessenger: controller.binaryMessenger)
      clipboardChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "getClipboardImages" {
          var paths: [String] = []
          if let image = UIPasteboard.general.image {
            if let data = image.pngData() ?? image.jpegData(compressionQuality: 0.95) {
              let tmp = NSTemporaryDirectory()
              let filename = "pasted_\(Int(Date().timeIntervalSince1970 * 1000)).png"
              let url = URL(fileURLWithPath: tmp).appendingPathComponent(filename)
              do {
                try data.write(to: url)
                paths.append(url.path)
              } catch {
                // ignore write error
              }
            }
          }
          result(paths)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }

      let fileSaveChannel = FlutterMethodChannel(name: "app.file_save", binaryMessenger: controller.binaryMessenger)
      fileSaveHandler.presentingViewController = controller
      fileSaveChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        guard call.method == "saveFileFromPath" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.fileSaveHandler.handle(call: call, result: result)
      }

      let iosBackgroundChannel = FlutterMethodChannel(name: "app.ios_background_generation", binaryMessenger: controller.binaryMessenger)
      iosBackgroundChannel.setMethodCallHandler { [weak self] call, result in
        self?.backgroundGenerationHandler.handle(call: call, result: result)
      }

      let mcpOAuthChannel = FlutterMethodChannel(name: "app.mcp_oauth", binaryMessenger: controller.binaryMessenger)
      mcpOAuthHandler.presentationAnchor = window
      mcpOAuthChannel.setMethodCallHandler { [weak self] call, result in
        self?.mcpOAuthHandler.handle(call: call, result: result)
      }
 
       let deviceToolsChannel = FlutterMethodChannel(name: "app.device_tools", binaryMessenger: controller.binaryMessenger)
       deviceToolsChannel.setMethodCallHandler { [weak self] call, result in
         self?.deviceLocalToolsHandler.handle(call: call, result: result)
       }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    backgroundGenerationHandler.dismissFinishedLiveActivityIfNeeded()
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.scheme == "kelivo" && url.host == "oauth-return" {
      return true
    }
    return super.application(app, open: url, options: options)
  }
}

private final class IosMcpOAuthHandler: NSObject, ASWebAuthenticationPresentationContextProviding {
  weak var presentationAnchor: UIWindow?
  private var session: ASWebAuthenticationSession?

  func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "authenticate":
      guard session == nil else {
        result(FlutterError(code: "authorization_in_progress", message: "An authorization session is already in progress.", details: nil))
        return
      }
      let arguments = call.arguments as? [String: Any]
      guard
        let urlString = arguments?["url"] as? String,
        let url = URL(string: urlString),
        let callbackScheme = arguments?["callbackScheme"] as? String,
        !callbackScheme.isEmpty
      else {
        result(FlutterError(code: "invalid_arguments", message: "A valid authorization URL and callback scheme are required.", details: nil))
        return
      }

      let authenticationSession = ASWebAuthenticationSession(
        url: url,
        callbackURLScheme: callbackScheme
      ) { [weak self] callbackURL, error in
        self?.session = nil
        if let callbackURL {
          result(callbackURL.absoluteString)
          return
        }
        let nsError = error as NSError?
        let cancelled = nsError?.domain == ASWebAuthenticationSessionErrorDomain && nsError?.code == 1
        result(
          FlutterError(
            code: cancelled ? "authorization_cancelled" : "authorization_failed",
            message: error?.localizedDescription ?? "Authorization did not return a callback URL.",
            details: nil
          )
        )
      }
      authenticationSession.presentationContextProvider = self
      authenticationSession.prefersEphemeralWebBrowserSession = false
      session = authenticationSession
      if !authenticationSession.start() {
        session = nil
        result(FlutterError(code: "authorization_failed", message: "Could not start the authorization session.", details: nil))
      }
    case "cancel":
      session?.cancel()
      session = nil
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    if let presentationAnchor {
      return presentationAnchor
    }
    for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
      if let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
        return window
      }
    }
    return UIWindow()
  }
}

private final class IosBackgroundGenerationHandler {
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var notificationsEnabled = false
  private var refreshEnabled = false
  private var liveActivity: Any?
  private var liveActivityRefreshTimer: Timer?
  private var liveActivityDisplayTitle = ""
  private var liveActivityDetail = ""
  private var liveActivityTokenCount = 0
  private var liveActivityTokenLabel = ""
  private var liveActivityStartedAt = Date()
  private var liveActivityFinishedAt: Date?
  private var liveActivityFinishedDetail = ""
  private var liveActivityFinished = false
  private var liveActivityWavePhase = 0

  func registerBackgroundTasks() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundRefreshIdentifier, using: nil) { task in
      self.handleBackgroundTask(task)
    }
    BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundProcessingIdentifier, using: nil) { task in
      self.handleBackgroundTask(task)
    }
  }

  func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getStatus":
      getStatus(result: result)
    case "requestNotificationAuthorization":
      requestNotificationAuthorization(result: result)
    case "openAppSettings":
      openAppSettings(result: result)
    case "openNotificationSettings":
      openNotificationSettings(result: result)
    case "start":
      start(arguments: call.arguments, result: result)
    case "update":
      update(arguments: call.arguments, result: result)
    case "finish":
      finish(arguments: call.arguments, result: result)
    case "cancel":
      cancel(arguments: call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(arguments: Any?, result: @escaping FlutterResult) {
    let args = arguments as? [String: Any] ?? [:]
    notificationsEnabled = args["notificationsEnabled"] as? Bool ?? false
    refreshEnabled = args["refreshEnabled"] as? Bool ?? false
    beginBackgroundTask()
    if refreshEnabled { scheduleBackgroundTasks() }
    if args["liveActivityEnabled"] as? Bool ?? false {
      startLiveActivity(
        title: args["title"] as? String ?? "Kelivo",
        detail: args["detail"] as? String ?? "",
        tokenCount: args["tokenCount"] as? Int ?? 0,
        tokenLabel: args["tokenLabel"] as? String ?? ""
      )
    }
    result(true)
  }

  private func update(arguments: Any?, result: @escaping FlutterResult) {
    let args = arguments as? [String: Any] ?? [:]
    updateLiveActivity(
      detail: args["detail"] as? String ?? "",
      tokenCount: args["tokenCount"] as? Int ?? 0,
      tokenLabel: args["tokenLabel"] as? String ?? ""
    )
    result(true)
  }

  private func finish(arguments: Any?, result: @escaping FlutterResult) {
    let args = arguments as? [String: Any] ?? [:]
    let title = args["title"] as? String ?? "Kelivo"
    let detail = args["detail"] as? String ?? ""
    finishLiveActivity(title: title, detail: detail)
    if notificationsEnabled { showCompletionNotification(title: title, body: detail) }
    endBackgroundTask()
    resetGenerationOptions()
    result(true)
  }

  private func cancel(arguments: Any?, result: @escaping FlutterResult) {
    let args = arguments as? [String: Any] ?? [:]
    finishLiveActivity(
      title: liveActivityDisplayTitle.isEmpty ? "Kelivo" : liveActivityDisplayTitle,
      detail: args["detail"] as? String ?? ""
    )
    endBackgroundTask()
    resetGenerationOptions()
    result(true)
  }

  private func resetGenerationOptions() {
    notificationsEnabled = false
    refreshEnabled = false
  }

  private func getStatus(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        var liveActivitiesEnabled = false
        if #available(iOS 16.1, *) {
          liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        }
        result([
          "backgroundTaskActive": self.backgroundTask != .invalid,
          "liveActivityActive": self.isLiveActivityActive(),
          "notificationsAuthorized": settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional,
          "liveActivitiesEnabled": liveActivitiesEnabled,
        ])
      }
    }
  }

  private func requestNotificationAuthorization(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
      DispatchQueue.main.async { result(granted) }
    }
  }

  private func openAppSettings(result: @escaping FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      result(false)
      return
    }
    UIApplication.shared.open(url, options: [:]) { opened in
      result(opened)
    }
  }

  private func openNotificationSettings(result: @escaping FlutterResult) {
    let url: URL?
    if #available(iOS 16.0, *) {
      url = URL(string: UIApplication.openNotificationSettingsURLString)
    } else {
      url = URL(string: UIApplication.openSettingsURLString)
    }
    guard let url else {
      result(false)
      return
    }
    UIApplication.shared.open(url, options: [:]) { opened in
      result(opened)
    }
  }

  private func beginBackgroundTask() {
    if backgroundTask != .invalid { return }
    backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "KelivoBackgroundGeneration") { [weak self] in
      self?.endBackgroundTask()
    }
  }

  private func endBackgroundTask() {
    guard backgroundTask != .invalid else { return }
    UIApplication.shared.endBackgroundTask(backgroundTask)
    backgroundTask = .invalid
  }

  private func scheduleBackgroundTasks() {
    let refresh = BGAppRefreshTaskRequest(identifier: backgroundRefreshIdentifier)
    refresh.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    do {
      try BGTaskScheduler.shared.submit(refresh)
    } catch {
      NSLog("Kelivo background refresh schedule failed: \(error)")
    }

    let processing = BGProcessingTaskRequest(identifier: backgroundProcessingIdentifier)
    processing.requiresNetworkConnectivity = true
    processing.requiresExternalPower = false
    processing.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    do {
      try BGTaskScheduler.shared.submit(processing)
    } catch {
      NSLog("Kelivo background processing schedule failed: \(error)")
    }
  }

  private func handleBackgroundTask(_ task: BGTask) {
    if refreshEnabled { scheduleBackgroundTasks() }
    task.expirationHandler = { task.setTaskCompleted(success: false) }
    task.setTaskCompleted(success: true)
  }

  private func showCompletionNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let request = UNNotificationRequest(identifier: "kelivo.background-generation.\(Date().timeIntervalSince1970)", content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
  }

  private func isLiveActivityActive() -> Bool {
    if #available(iOS 16.1, *) {
      return liveActivity as? Activity<KelivoGenerationActivityAttributes> != nil
    }
    return false
  }

  private func startLiveActivity(title: String, detail: String, tokenCount: Int, tokenLabel: String) {
    if #available(iOS 16.1, *) {
      guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
      liveActivityDisplayTitle = title
      liveActivityDetail = detail
      liveActivityStartedAt = Date()
      liveActivityFinishedAt = nil
      liveActivityFinishedDetail = ""
      liveActivityFinished = false
      liveActivityWavePhase = 0
      liveActivityTokenCount = tokenCount
      liveActivityTokenLabel = tokenLabel
      let state = liveActivityState(
        displayTitle: title,
        detail: detail,
        tokenCount: tokenCount,
        tokenLabel: tokenLabel,
        finishedAt: nil,
        isFinished: false
      )
      do {
        if #available(iOS 16.2, *) {
          liveActivity = try Activity<KelivoGenerationActivityAttributes>.request(attributes: KelivoGenerationActivityAttributes(title: title), content: ActivityContent(state: state, staleDate: nil), pushType: nil)
        } else {
          liveActivity = try Activity<KelivoGenerationActivityAttributes>.request(attributes: KelivoGenerationActivityAttributes(title: title), contentState: state, pushType: nil)
        }
        startLiveActivityRefreshTimer()
      } catch {
        NSLog("Kelivo live activity start failed: \(error)")
        liveActivity = nil
      }
    }
  }

  private func updateLiveActivity(detail: String, tokenCount: Int, tokenLabel: String) {
    guard isLiveActivityActive(), !liveActivityFinished else { return }
    liveActivityTokenCount = tokenCount
    liveActivityTokenLabel = tokenLabel
    liveActivityDetail = detail
    liveActivityFinishedAt = nil
    liveActivityFinishedDetail = ""
  }

  func dismissFinishedLiveActivityIfNeeded() {
    guard liveActivityFinished else { return }
    endLiveActivity(detail: liveActivityFinishedDetail)
  }

  private func finishLiveActivity(title: String, detail: String) {
    liveActivityDisplayTitle = title
    liveActivityDetail = detail
    stopLiveActivityRefreshTimer()
    if UIApplication.shared.applicationState == .active {
      liveActivityFinishedAt = Date()
      liveActivityFinishedDetail = detail
      liveActivityFinished = true
      endLiveActivity(detail: detail)
      return
    }
    markLiveActivityFinished(title: title, detail: detail)
  }

  private func markLiveActivityFinished(title: String, detail: String) {
    if #available(iOS 16.1, *), let activity = liveActivity as? Activity<KelivoGenerationActivityAttributes> {
      let finishedAt = Date()
      liveActivityDisplayTitle = title
      liveActivityDetail = detail
      liveActivityFinishedAt = finishedAt
      liveActivityFinishedDetail = detail
      liveActivityFinished = true
      let state = liveActivityState(
        displayTitle: title,
        detail: detail,
        tokenCount: liveActivityTokenCount,
        tokenLabel: liveActivityTokenLabel,
        finishedAt: finishedAt,
        isFinished: true
      )
      Task {
        if #available(iOS 16.2, *) {
          await activity.update(ActivityContent(state: state, staleDate: nil))
        } else {
          await activity.update(using: state)
        }
      }
    }
  }

  private func endLiveActivity(detail: String) {
    if #available(iOS 16.1, *), let activity = liveActivity as? Activity<KelivoGenerationActivityAttributes> {
      let state = liveActivityState(
        displayTitle: liveActivityDisplayTitle,
        detail: detail,
        tokenCount: liveActivityTokenCount,
        tokenLabel: liveActivityTokenLabel,
        finishedAt: liveActivityFinishedAt,
        isFinished: liveActivityFinished
      )
      Task {
        if #available(iOS 16.2, *) {
          await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
        } else {
          await activity.end(using: state, dismissalPolicy: .immediate)
        }
      }
      liveActivity = nil
      stopLiveActivityRefreshTimer()
      liveActivityDisplayTitle = ""
      liveActivityDetail = ""
      liveActivityTokenCount = 0
      liveActivityTokenLabel = ""
      liveActivityStartedAt = Date()
      liveActivityFinishedAt = nil
      liveActivityFinishedDetail = ""
      liveActivityFinished = false
      liveActivityWavePhase = 0
    }
  }

  private func startLiveActivityRefreshTimer() {
    stopLiveActivityRefreshTimer()
    let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
      self?.refreshLiveActivity()
    }
    liveActivityRefreshTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  private func stopLiveActivityRefreshTimer() {
    liveActivityRefreshTimer?.invalidate()
    liveActivityRefreshTimer = nil
  }

  private func refreshLiveActivity() {
    guard #available(iOS 16.1, *), let activity = liveActivity as? Activity<KelivoGenerationActivityAttributes> else { return }
    guard !liveActivityFinished else { return }
    liveActivityWavePhase += 1
    let state = liveActivityState(
      displayTitle: liveActivityDisplayTitle,
      detail: liveActivityDetail,
      tokenCount: liveActivityTokenCount,
      tokenLabel: liveActivityTokenLabel,
      finishedAt: nil,
      isFinished: false
    )
    Task {
      if #available(iOS 16.2, *) {
        await activity.update(ActivityContent(state: state, staleDate: nil))
      } else {
        await activity.update(using: state)
      }
    }
  }

  @available(iOS 16.1, *)
  private func liveActivityState(
    displayTitle: String,
    detail: String,
    tokenCount: Int,
    tokenLabel: String,
    finishedAt: Date?,
    isFinished: Bool
  ) -> KelivoGenerationActivityAttributes.ContentState {
    let startedAt = liveActivityStartedAt
    let effectiveFinishedAt = finishedAt ?? Date()
    return KelivoGenerationActivityAttributes.ContentState(
      displayTitle: displayTitle,
      detail: detail,
      tokenCount: tokenCount,
      tokenLabel: tokenLabel,
      startedAt: startedAt,
      finishedAt: finishedAt,
      elapsedSeconds: isFinished
        ? elapsedSeconds(from: startedAt, to: effectiveFinishedAt)
        : elapsedSeconds(since: startedAt),
      wavePhase: liveActivityWavePhase,
      isFinished: isFinished
    )
  }

  private func elapsedSeconds(since startedAt: Date) -> Int {
    elapsedSeconds(from: startedAt, to: Date())
  }

  private func elapsedSeconds(from startedAt: Date, to endedAt: Date) -> Int {
    max(0, Int(endedAt.timeIntervalSince(startedAt)))
  }
}

private final class NativeFileSaveHandler: NSObject, UIDocumentPickerDelegate {
  weak var presentingViewController: UIViewController?
  private var pendingResult: FlutterResult?

  func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    if pendingResult != nil {
      result(FlutterError(code: "busy", message: "Another save operation is already in progress.", details: nil))
      return
    }

    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "invalid_args", message: "Arguments must be a map.", details: nil))
      return
    }

    let rawSourcePath = (args["sourcePath"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !rawSourcePath.isEmpty else {
      result(FlutterError(code: "invalid_args", message: "Missing sourcePath.", details: nil))
      return
    }

    let sourceURL = URL(fileURLWithPath: rawSourcePath)
    guard FileManager.default.fileExists(atPath: sourceURL.path) else {
      result(FlutterError(code: "not_found", message: "Source file does not exist.", details: nil))
      return
    }

    guard let presenter = topViewController(from: presentingViewController) else {
      result(FlutterError(code: "unavailable", message: "Unable to present document picker.", details: nil))
      return
    }

    pendingResult = result

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      let picker: UIDocumentPickerViewController
      if #available(iOS 14.0, *) {
        picker = UIDocumentPickerViewController(forExporting: [sourceURL], asCopy: true)
      } else {
        picker = UIDocumentPickerViewController(url: sourceURL, in: .exportToService)
      }

      picker.delegate = self
      picker.modalPresentationStyle = .formSheet
      if let popover = picker.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
        popover.permittedArrowDirections = []
      }

      presenter.present(picker, animated: true)
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finish(with: false)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    finish(with: !urls.isEmpty)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
    finish(with: true)
  }

  private func finish(with value: Bool) {
    let result = pendingResult
    pendingResult = nil
    result?(value)
  }

  private func topViewController(from controller: UIViewController?) -> UIViewController? {
    if let navigation = controller as? UINavigationController {
      return topViewController(from: navigation.visibleViewController)
    }
    if let tab = controller as? UITabBarController {
      return topViewController(from: tab.selectedViewController)
    }
    if let presented = controller?.presentedViewController {
      return topViewController(from: presented)
    }
    return controller
  }
}
 
 /// Native backend for the AI assistant's device-local tools on iOS.
 ///
 /// Calendar query/create is implemented with EventKit. Screen time has no
 /// generally available query API on iOS (the Screen Time frameworks require a
 /// special Family Controls entitlement), so it is not exposed here; the Dart
 /// side never offers that tool on iOS.
 ///
 /// Methods receive the tool arguments as a JSON string and return a JSON
 /// string payload. Errors the LLM should see (missing permission, bad
 /// arguments) are returned as JSON payloads with an "error" field.
 private final class DeviceLocalToolsHandler {
   private let eventStore = EKEventStore()
 
   func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
     let args = Self.parseArgs(call.arguments)
     switch call.method {
     case "hasUsageStatsPermission":
       result(false)
     case "openUsageAccessSettings":
       result(nil)
     case "hasCalendarPermission":
       result(hasCalendarPermission())
     case "requestCalendarPermission":
       requestCalendarPermission(result: result)
     case "queryCalendar":
       ensureCalendarAccess { [weak self] granted in
         guard let self else { return }
         guard granted else {
           result(Self.noPermissionPayload)
           return
         }
         DispatchQueue.global(qos: .userInitiated).async {
           let payload = self.queryCalendar(args: args)
           DispatchQueue.main.async { result(payload) }
         }
       }
     case "createCalendarEvent":
       ensureCalendarAccess { [weak self] granted in
         guard let self else { return }
         guard granted else {
           result(Self.noPermissionPayload)
           return
         }
         DispatchQueue.global(qos: .userInitiated).async {
           let payload = self.createCalendarEvent(args: args)
           DispatchQueue.main.async { result(payload) }
         }
       }
     case "getScreenTime":
       result(Self.errorPayload(
         "UNSUPPORTED_PLATFORM",
         "Screen time queries are not available on iOS; Apple does not provide a general-purpose API for this."
       ))
     default:
       result(FlutterMethodNotImplemented)
     }
   }
 
   // MARK: - Permission
 
   private static let noPermissionPayload = errorPayload(
     "NO_PERMISSION",
     "Calendar permission is not granted. Please ask the user to allow full calendar access "
       + "for this app in the system Settings and try again."
   )

   private func hasCalendarPermission() -> Bool {
     let status = EKEventStore.authorizationStatus(for: .event)
     if #available(iOS 17.0, *) {
       return status == .fullAccess
     }
     return status == .authorized
   }

   /// Used by the assistant settings toggle. Prompts when undetermined; opens
   /// Settings when previously denied/restricted/write-only.
   private func requestCalendarPermission(result: @escaping FlutterResult) {
     let finish: (Bool) -> Void = { granted in
       DispatchQueue.main.async { result(granted) }
     }
     let status = EKEventStore.authorizationStatus(for: .event)
     if #available(iOS 17.0, *) {
       switch status {
       case .fullAccess:
         finish(true)
       case .notDetermined:
         eventStore.requestFullAccessToEvents { granted, _ in finish(granted) }
       default:
         openAppSettings()
         finish(false)
       }
     } else {
       switch status {
       case .authorized:
         finish(true)
       case .notDetermined:
         eventStore.requestAccess(to: .event) { granted, _ in finish(granted) }
       default:
         openAppSettings()
         finish(false)
       }
     }
   }

   private func openAppSettings() {
     guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
     UIApplication.shared.open(url)
   }
 
   private func ensureCalendarAccess(completion: @escaping (Bool) -> Void) {
     let finish: (Bool) -> Void = { granted in
       DispatchQueue.main.async { completion(granted) }
     }
     let status = EKEventStore.authorizationStatus(for: .event)
     if #available(iOS 17.0, *) {
       switch status {
       case .fullAccess:
         finish(true)
       case .notDetermined:
         eventStore.requestFullAccessToEvents { granted, _ in finish(granted) }
       default:
         finish(false)
       }
     } else {
       switch status {
       case .authorized:
         finish(true)
       case .notDetermined:
         eventStore.requestAccess(to: .event) { granted, _ in finish(granted) }
       default:
         finish(false)
       }
     }
   }
 
   // MARK: - Calendar query
 
   private func queryCalendar(args: [String: Any]) -> String {
     let limit = min(max(Self.intArg(args["limit"]) ?? 20, 1), 100)
     let keyword = (args["query"] as? String)?
       .trimmingCharacters(in: .whitespacesAndNewlines)
       .lowercased()
     let rangePreset = (args["range"] as? String)?.lowercased() ?? "today"
 
     // ISO 8601 calendar so week presets start on Monday, matching Android.
     var calendar = Calendar(identifier: .iso8601)
     calendar.timeZone = .current
     let now = Date()
     let startOfToday = calendar.startOfDay(for: now)
 
     let startDate: Date
     let endDate: Date
     if let beginRaw = args["begin"] as? String, !beginRaw.isEmpty {
       guard let parsedStart = Self.parseTime(beginRaw, calendar: calendar) else {
         return Self.invalidTimePayload(beginRaw)
       }
       startDate = parsedStart
       if let endRaw = args["end"] as? String, !endRaw.isEmpty {
         guard let parsedEnd = Self.parseTime(endRaw, calendar: calendar) else {
           return Self.invalidTimePayload(endRaw)
         }
         endDate = parsedEnd
       } else {
         endDate = now
       }
     } else {
       switch rangePreset {
       case "week":
         let weekStart = calendar.date(
           from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
         ) ?? startOfToday
         startDate = weekStart
         endDate = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now
       case "month":
         let monthStart = calendar.date(
           from: calendar.dateComponents([.year, .month], from: now)
         ) ?? startOfToday
         startDate = monthStart
         endDate = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now
       default:
         startDate = startOfToday
         endDate = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
       }
     }
 
     guard startDate < endDate else {
       return Self.errorPayload("INVALID_RANGE", "begin must be earlier than end.")
     }
 
     let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
     var events = eventStore.events(matching: predicate)
     if let keyword, !keyword.isEmpty {
       events = events.filter { ($0.title ?? "").lowercased().contains(keyword) }
     }
     events.sort { $0.startDate < $1.startDate }
 
     var items: [[String: Any]] = []
     for event in events.prefix(limit) {
       var item: [String: Any] = [
         "id": event.eventIdentifier ?? "",
         "title": event.title ?? "",
         "description": event.notes ?? "",
         "location": event.location ?? "",
         "all_day": event.isAllDay,
         "calendar": event.calendar?.title ?? "",
       ]
       if event.isAllDay {
         item["start"] = Self.formatDateOnly(event.startDate, calendar: calendar)
         // Report the exclusive end date (tool convention, matches Android);
         // EventKit stores all-day ends inside the last included day.
         item["end"] = event.endDate.map {
           Self.formatDateOnly(Self.exclusiveAllDayEnd($0, calendar: calendar), calendar: calendar)
         } ?? ""
       } else {
         item["start"] = Self.formatDateTime(event.startDate)
         item["end"] = event.endDate.map(Self.formatDateTime) ?? ""
       }
       items.append(item)
     }
 
     return Self.jsonString([
       "range_start": Self.formatDateTime(startDate),
       "range_end": Self.formatDateTime(endDate),
       "count": items.count,
       "events": items,
     ])
   }
 
   // MARK: - Calendar create
 
   private func createCalendarEvent(args: [String: Any]) -> String {
     let title = (args["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
     let startRaw = (args["start"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
     guard !title.isEmpty, !startRaw.isEmpty else {
       return Self.errorPayload("MISSING_REQUIRED", "Both 'title' and 'start' are required.")
     }
     let allDay = Self.boolArg(args["all_day"]) ?? false
 
     var calendar = Calendar(identifier: .iso8601)
     calendar.timeZone = .current
 
     guard let startDate = Self.parseTime(startRaw, calendar: calendar) else {
       return Self.invalidTimePayload(startRaw)
     }
     let endDate: Date
     if let endRaw = args["end"] as? String, !endRaw.isEmpty {
       guard let parsedEnd = Self.parseTime(endRaw, calendar: calendar) else {
         return Self.invalidTimePayload(endRaw)
       }
       endDate = parsedEnd
     } else if allDay {
       let dayStart = calendar.startOfDay(for: startDate)
       endDate = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? startDate.addingTimeInterval(86400)
     } else {
       endDate = startDate.addingTimeInterval(3600)
     }
     guard startDate < endDate else {
       return Self.errorPayload("INVALID_RANGE", "end must be later than start.")
     }
 
     // For all-day events, normalize both ends to day boundaries first (like
     // Android's LocalDate comparison), so e.g. a 12:00-18:00 same-day range is
     // rejected instead of silently producing a degenerate event.
     let allDayStart = calendar.startOfDay(for: startDate)
     let allDayEndExclusive = calendar.startOfDay(for: endDate)
     if allDay, allDayStart >= allDayEndExclusive {
       return Self.errorPayload("INVALID_RANGE", "all-day event end date must be later than start date.")
     }
 
     guard let targetCalendar = eventStore.defaultCalendarForNewEvents else {
       return Self.errorPayload(
         "NO_CALENDAR",
         "No calendar account found on this device. Please add a calendar account first."
       )
     }
 
     let event = EKEvent(eventStore: eventStore)
     event.calendar = targetCalendar
     event.title = title
     if let notes = args["description"] as? String, !notes.isEmpty {
       event.notes = notes
     }
     if let location = args["location"] as? String, !location.isEmpty {
       event.location = location
     }
     if allDay {
       event.isAllDay = true
       event.startDate = allDayStart
       // The tool's 'end' is exclusive (next-day midnight); EventKit treats the
       // end date's day as included, so step back one second to avoid spilling
       // into an extra day. Payloads convert back to the exclusive date.
       event.endDate = allDayEndExclusive.addingTimeInterval(-1)
     } else {
       event.startDate = startDate
       event.endDate = endDate
     }
 
     // Reminders are minutes before the event start; EKAlarm takes a negative
     // offset in seconds relative to the start date.
     let reminderMinutes = Self.reminderMinutesArg(args["reminders"])
     for minutes in reminderMinutes {
       event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-minutes * 60)))
     }
 
     do {
       try eventStore.save(event, span: .thisEvent, commit: true)
     } catch {
       return Self.errorPayload("INSERT_FAILED", "Failed to save calendar event: \(error.localizedDescription)")
     }
 
     var payload: [String: Any] = [
       "success": true,
       "event_id": event.eventIdentifier ?? "",
       "title": title,
       "all_day": allDay,
       "location": event.location ?? "",
       "reminders": reminderMinutes,
     ]
     if allDay {
       payload["start"] = Self.formatDateOnly(allDayStart, calendar: calendar)
       payload["end"] = Self.formatDateOnly(allDayEndExclusive, calendar: calendar)
     } else {
       payload["start"] = Self.formatDateTime(startDate)
       payload["end"] = Self.formatDateTime(endDate)
     }
     return Self.jsonString(payload)
   }
 
   // MARK: - Argument/JSON helpers
 
   private static func parseArgs(_ arguments: Any?) -> [String: Any] {
     guard
       let json = arguments as? String,
       let data = json.data(using: .utf8),
       let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
     else {
       return [:]
     }
     return parsed
   }
 
   private static func intArg(_ value: Any?) -> Int? {
     if let number = value as? Int { return number }
     if let number = value as? Double { return Int(number) }
     if let text = value as? String { return Int(text.trimmingCharacters(in: .whitespaces)) }
     return nil
   }
 
   /// Reminder offsets in minutes before the event start. Accepts a JSON array,
   /// or a single number/string for convenience. Negative values (models
   /// sometimes send "-10" for "10 minutes before") are folded to positive;
   /// duplicates are dropped and at most 5 are kept, matching EventKit's
   /// practical limit for well-behaved events.
   private static func reminderMinutesArg(_ value: Any?) -> [Int] {
     let raw: [Any]
     if let list = value as? [Any] {
       raw = list
     } else if let value, !(value is NSNull) {
       raw = [value]
     } else {
       return []
     }
     var seen = Set<Int>()
     var minutes: [Int] = []
     for item in raw {
       guard let normalized = clampedMinutes(item) else { continue }
       if seen.insert(normalized).inserted {
         minutes.append(normalized)
       }
       if minutes.count == 5 { break }
     }
     return minutes
   }
 
   /// Clamps one reminder offset into 0...40320 minutes (4 weeks). Parsed as a
   /// Double throughout: an out-of-range or Int.min value would trap on the
   /// Int conversion, and these values come straight from model output.
   private static func clampedMinutes(_ value: Any?) -> Int? {
     let raw: Double
     if let number = value as? NSNumber {
       raw = number.doubleValue
     } else if let text = (value as? String)?.trimmingCharacters(in: .whitespaces),
               let parsed = Double(text) {
       raw = parsed
     } else {
       return nil
     }
     guard raw.isFinite else { return nil }
     return Int(min(abs(raw), 40320))
   }
 
   private static func boolArg(_ value: Any?) -> Bool? {
     if let flag = value as? Bool { return flag }
     if let text = (value as? String)?.lowercased() {
       if text == "true" { return true }
       if text == "false" { return false }
     }
     return nil
   }
 
   private static func jsonString(_ payload: [String: Any]) -> String {
     guard
       let data = try? JSONSerialization.data(withJSONObject: payload),
       let text = String(data: data, encoding: .utf8)
     else {
       return "{\"error\":\"ENCODING_ERROR\",\"message\":\"Failed to encode tool result.\"}"
     }
     return text
   }
 
   private static func errorPayload(_ error: String, _ message: String) -> String {
     jsonString(["error": error, "message": message])
   }
 
   private static func invalidTimePayload(_ raw: String) -> String {
     errorPayload(
       "INVALID_TIME",
       "Invalid time format: '\(raw)'. Use ISO-8601 date/date-time or epoch milliseconds."
     )
   }
 
   // MARK: - Time parsing/formatting
 
   /// Parses epoch milliseconds, offset date-times, local date-times, and
   /// plain dates (interpreted at local midnight), mirroring the Android tool.
   private static func parseTime(_ raw: String, calendar: Calendar) -> Date? {
     let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
     if !text.isEmpty, text.allSatisfy({ $0.isNumber }), let millis = Double(text) {
       return Date(timeIntervalSince1970: millis / 1000.0)
     }
 
     let isoWithFraction = ISO8601DateFormatter()
     isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
     if let date = isoWithFraction.date(from: text) { return date }
 
     let iso = ISO8601DateFormatter()
     iso.formatOptions = [.withInternetDateTime]
     if let date = iso.date(from: text) { return date }
 
     for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd"] {
       let formatter = DateFormatter()
       formatter.locale = Locale(identifier: "en_US_POSIX")
       formatter.timeZone = calendar.timeZone
       formatter.dateFormat = format
       if let date = formatter.date(from: text) { return date }
     }
     return nil
   }
 
   private static func formatDateTime(_ date: Date) -> String {
     let formatter = ISO8601DateFormatter()
     formatter.formatOptions = [.withInternetDateTime]
     formatter.timeZone = .current
     return formatter.string(from: date)
   }
 
   private static func formatDateOnly(_ date: Date, calendar: Calendar) -> String {
     let formatter = DateFormatter()
     formatter.locale = Locale(identifier: "en_US_POSIX")
     formatter.timeZone = calendar.timeZone
     formatter.dateFormat = "yyyy-MM-dd"
     return formatter.string(from: date)
   }
 
   /// Converts a stored all-day end date to the tool's exclusive end date.
   /// EventKit keeps the end inside the last included day (e.g. 23:59:59),
   /// while the tool reports the next-day midnight boundary. Ends already at
   /// an exact midnight are treated as exclusive and returned unchanged.
   private static func exclusiveAllDayEnd(_ end: Date, calendar: Calendar) -> Date {
     calendar.startOfDay(for: end.addingTimeInterval(1))
   }
 }
