import Flutter
import UIKit
import UserNotifications

/// This adapter never starts a model on a timer. Notification content is already
/// persisted by Dart before being registered here.
final class ScheduledTaskNotifications {
    private let center = UNUserNotificationCenter.current()
    private let prefix = "scheduled-task:"
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    func configure(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "app.scheduled_notifications", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { return }
            switch call.method {
            case "schedule": self.schedule(call.arguments, result: result)
            case "cancel":
                guard let id = call.arguments as? String else {
                    result(FlutterError(code: "invalid_args", message: nil, details: nil)); return
                }
                self.center.removePendingNotificationRequests(withIdentifiers: [self.prefix + id])
                result(nil)
            case "pending":
                self.center.getPendingNotificationRequests { requests in
                    let ids = requests.map(\.identifier).filter { $0.hasPrefix(self.prefix) }
                        .map { String($0.dropFirst(self.prefix.count)) }
                    DispatchQueue.main.async { result(ids) }
                }
            case "permission":
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    DispatchQueue.main.async {
                        if let error { result(FlutterError(code: "notification_permission", message: error.localizedDescription, details: nil)) }
                        else { result(granted) }
                    }
                }
            case "beginPreparation":
                if self.backgroundTask == .invalid {
                    self.backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Prepare scheduled task") { [weak self] in
                        channel.invokeMethod("expired", arguments: nil)
                        self?.endPreparation()
                    }
                }
                result(nil)
            case "endPreparation": self.endPreparation(); result(nil)
            default: result(FlutterMethodNotImplemented)
            }
        }
    }

    private func endPreparation() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    private func schedule(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let runId = args["runId"] as? String,
              let at = args["at"] as? NSNumber,
              let title = args["title"] as? String,
              let body = args["body"] as? String,
              let payload = args["payload"] as? String else {
            result(FlutterError(code: "invalid_args", message: nil, details: nil)); return
        }
        let date = Date(timeIntervalSince1970: at.doubleValue / 1000)
        guard date > Date() else { result(false); return }
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                DispatchQueue.main.async { result(false) }; return
            }
            self.center.getPendingNotificationRequests { pending in
                let identifier = self.prefix + runId
                // Leave room for other notifications, and never silently evict
                // another task when iOS's finite pending queue fills up.
                if pending.count >= 60 && !pending.contains(where: { $0.identifier == identifier }) {
                    DispatchQueue.main.async { result(false) }; return
                }
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = String(body.prefix(4000))
                content.sound = .default
                content.threadIdentifier = "kelivo.scheduled-tasks"
                // Use flutter_local_notifications' response bridge for both
                // cold-launch and warm-launch taps, alongside normal replies.
                content.userInfo = ["NotificationId": 0, "payload": payload,
                    "scheduledPrepared": args["prepared"] as? Bool ?? false,
                    "presentAlert": true, "presentSound": true, "presentBadge": false,
                    "presentBanner": true, "presentList": true]
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
                components.timeZone = calendar.timeZone
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                self.center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)) { error in
                    DispatchQueue.main.async {
                        if let error { result(FlutterError(code: "notification_schedule", message: error.localizedDescription, details: nil)) }
                        else { result(true) }
                    }
                }
            }
        }
    }
}
