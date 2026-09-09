 import Flutter
 import UIKit
 import AuthenticationServices
 import UserNotifications
 import SwiftUI
 import Translation


@main
@objc class AppDelegate: FlutterAppDelegate {
   private let fileSaveHandler = NativeFileSaveHandler()
   private let backgroundGenerationHandler = MobileBackgroundHandler()
   private let mcpOAuthHandler = IosMcpOAuthHandler()
   private let deviceLocalToolsHandler = DeviceLocalToolsHandler()
   private let iosTranslationHandler = IosTranslationHandler()
   private let incomingShareHandler = IosIncomingShareHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // FlutterAppDelegate forwards foreground presentation and cold/warm taps
    // to flutter_local_notifications. Assigning a delegate requests no access.
    UNUserNotificationCenter.current().delegate = self
    if let controller = window?.rootViewController as? FlutterViewController {
      incomingShareHandler.register(messenger: controller.binaryMessenger)
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

      backgroundGenerationHandler.configure(messenger: controller.binaryMessenger)

      let mcpOAuthChannel = FlutterMethodChannel(name: "app.mcp_oauth", binaryMessenger: controller.binaryMessenger)
      mcpOAuthHandler.presentationAnchor = window
      mcpOAuthChannel.setMethodCallHandler { [weak self] call, result in
        self?.mcpOAuthHandler.handle(call: call, result: result)
      }

      let iosTranslationChannel = FlutterMethodChannel(name: "app.ios_translation", binaryMessenger: controller.binaryMessenger)
      iosTranslationHandler.presentingViewController = controller
      iosTranslationChannel.setMethodCallHandler { [weak self] call, result in
        self?.iosTranslationHandler.handle(call: call, result: result)
      }
 
       let deviceToolsChannel = FlutterMethodChannel(name: "app.device_tools", binaryMessenger: controller.binaryMessenger)
       deviceToolsChannel.setMethodCallHandler { [weak self] call, result in
         self?.deviceLocalToolsHandler.handle(call: call, result: result)
       }

      WorkspacePlugin.register(messenger: controller.binaryMessenger, presenter: controller)

      // Free space on the volume holding the app's data. Uses the "important
      // usage" capacity, which is what iOS will actually free up for data the
      // app cannot regenerate -- the plain available-capacity value understates
      // it and would make the app skip copies it could have made.
      let storageChannel = FlutterMethodChannel(name: "app.device_storage", binaryMessenger: controller.binaryMessenger)
      storageChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "freeBytes":
          guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            result(nil)
            return
          }
          do {
            let values = try directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
              result(NSNumber(value: capacity))
              return
            }
          } catch {
            // Fall through: the caller treats a missing answer as "unknown".
          }
          result(nil)

        // Local database copies live under Documents, which iCloud backs up in
        // full. They can reach gigabytes and are reproducible from the live
        // database, so backing them up would bloat -- and can break -- the
        // user's iCloud backup without protecting anything new.
        case "excludeFromBackup":
          guard
            let arguments = call.arguments as? [String: Any],
            let path = arguments["path"] as? String,
            !path.isEmpty
          else {
            result(FlutterError(code: "invalid_args", message: "Missing path.", details: nil))
            return
          }
          var url = URL(fileURLWithPath: path)
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          do {
            try url.setResourceValues(values)
            result(true)
          } catch {
            result(FlutterError(code: "exclude_failed", message: error.localizedDescription, details: nil))
          }

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    backgroundGenerationHandler.prepareForTermination()
    super.applicationWillTerminate(application)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if backgroundGenerationHandler.receive(url) { return true }
    if incomingShareHandler.receiveFile(url) { return true }
    if url.scheme == "kelivo" && url.host == "oauth-return" {
      return true
    }
    return super.application(app, open: url, options: options)
  }
}

private final class IosTranslationHandler {
  weak var presentingViewController: UIViewController?
  private var hostingController: UIViewController?

  func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      if #available(iOS 17.4, *) {
        result(true)
      } else {
        result(false)
      }
    case "present":
      guard #available(iOS 17.4, *) else {
        result(false)
        return
      }
      let arguments = call.arguments as? [String: Any]
      guard
        let text = arguments?["text"] as? String,
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        let anchorX = arguments?["anchorX"] as? Double,
        let anchorY = arguments?["anchorY"] as? Double,
        let presenter = presentingViewController,
        presenter.viewIfLoaded?.window != nil
      else {
        result(false)
        return
      }
      present(
        text: text,
        anchor: CGPoint(x: anchorX, y: anchorY),
        in: presenter
      )
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 17.4, *)
  private func present(text: String, anchor: CGPoint, in presenter: UIViewController) {
    removeHostingController()

    let bounds = presenter.view.bounds
    let point = CGPoint(
      x: min(max(anchor.x, bounds.minX + 1), bounds.maxX - 1),
      y: min(max(anchor.y, bounds.minY + 1), bounds.maxY - 1)
    )
    let hostingController = UIHostingController(
      rootView: NativeTranslationPresenter(text: text) { [weak self] in
        self?.removeHostingController()
      }
    )
    hostingController.view.backgroundColor = .clear
    hostingController.view.frame = CGRect(
      x: point.x - 1,
      y: point.y - 1,
      width: 2,
      height: 2
    )
    presenter.addChild(hostingController)
    presenter.view.addSubview(hostingController.view)
    hostingController.didMove(toParent: presenter)
    self.hostingController = hostingController
  }

  private func removeHostingController() {
    guard let hostingController else { return }
    hostingController.willMove(toParent: nil)
    hostingController.view.removeFromSuperview()
    hostingController.removeFromParent()
    self.hostingController = nil
  }
}

@available(iOS 17.4, *)
private struct NativeTranslationPresenter: View {
  let text: String
  let onDismiss: () -> Void
  @State private var isPresented = false

  var body: some View {
    Color.clear
      .translationPresentation(isPresented: $isPresented, text: text)
      .onAppear {
        DispatchQueue.main.async {
          isPresented = true
        }
      }
      .onChange(of: isPresented) { visible in
        if !visible {
          onDismiss()
        }
      }
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
