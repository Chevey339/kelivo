import EventKit
import Foundation

/// EventKit reminders backend. Shares `EKEventStore` with calendar tools.
final class RemindersToolHandler {
  private let eventStore: EKEventStore

  init(eventStore: EKEventStore) {
    self.eventStore = eventStore
  }

  func hasPermission() -> Bool {
    let status = EKEventStore.authorizationStatus(for: .reminder)
    if #available(iOS 17.0, *) {
      return status == .fullAccess
    }
    return status == .authorized
  }

  func requestPermission(completion: @escaping (Bool) -> Void) {
    let finish: (Bool) -> Void = { granted in
      DeviceToolsSupport.finishOnMain { completion(granted) }
    }
    let status = EKEventStore.authorizationStatus(for: .reminder)
    if hasPermission() {
      finish(true)
      return
    }
    if status == .notDetermined {
      requestAccess { granted in finish(granted) }
      return
    }
    DeviceToolsSupport.openAppSettings()
    finish(false)
  }

  func ensureAccess(completion: @escaping (Bool) -> Void) {
    let finish: (Bool) -> Void = { granted in
      DeviceToolsSupport.finishOnMain { completion(granted) }
    }
    if hasPermission() {
      finish(true)
      return
    }
    if EKEventStore.authorizationStatus(for: .reminder) == .notDetermined {
      requestAccess { granted in finish(granted) }
      return
    }
    finish(false)
  }

  func query(args: [String: Any], completion: @escaping (String) -> Void) {
    let range = DeviceToolsSupport.resolveDateRange(
      args: args,
      defaultPreset: "today",
      allowedPresets: ["today", "week", "month"]
    )
    if let error = range.error {
      completion(error)
      return
    }

    let limit = min(max(DeviceToolsSupport.intArg(args["limit"]) ?? 20, 1), 100)
    let keyword = (args["query"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    let completedFilter = completedArg(args["completed"])
    let calendar = DeviceToolsSupport.isoCalendar()

    let predicate = eventStore.predicateForReminders(in: nil)
    eventStore.fetchReminders(matching: predicate) { reminders in
      var items = reminders ?? []
      items = items.filter { reminder in
        if let completedFilter {
          if reminder.isCompleted != completedFilter { return false }
        }
        if let keyword, !keyword.isEmpty {
          let title = (reminder.title ?? "").lowercased()
          let notes = (reminder.notes ?? "").lowercased()
          if !title.contains(keyword) && !notes.contains(keyword) { return false }
        }
        if let due = Self.dueDate(reminder, calendar: calendar) {
          return due >= range.start && due < range.end
        }
        // Undated reminders are included only when no explicit begin/end
        // was given (preset query), so "today's list" still shows inbox items.
        return args["begin"] == nil
      }
      items.sort { lhs, rhs in
        let left = Self.dueDate(lhs, calendar: calendar) ?? .distantFuture
        let right = Self.dueDate(rhs, calendar: calendar) ?? .distantFuture
        if left != right { return left < right }
        return (lhs.title ?? "") < (rhs.title ?? "")
      }

      let payloadItems: [[String: Any]] = items.prefix(limit).map { reminder in
        var item: [String: Any] = [
          "id": reminder.calendarItemIdentifier,
          "title": reminder.title ?? "",
          "notes": reminder.notes ?? "",
          "completed": reminder.isCompleted,
          "priority": reminder.priority,
          "list": reminder.calendar?.title ?? "",
        ]
        Self.applyDue(reminder, to: &item, calendar: calendar)
        if reminder.isCompleted, let completedAt = reminder.completionDate {
          item["completed_at"] = DeviceToolsSupport.formatDateTime(completedAt)
        }
        return item
      }

      completion(
        DeviceToolsSupport.jsonString([
          "range_start": DeviceToolsSupport.formatDateTime(range.start),
          "range_end": DeviceToolsSupport.formatDateTime(range.end),
          "count": payloadItems.count,
          "reminders": payloadItems,
        ])
      )
    }
  }

  func create(args: [String: Any]) -> String {
    let title = (args["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !title.isEmpty else {
      return DeviceToolsSupport.errorPayload("MISSING_REQUIRED", "'title' is required.")
    }
    guard let calendar = eventStore.defaultCalendarForNewReminders() else {
      return DeviceToolsSupport.errorPayload(
        "NO_REMINDERS_LIST",
        "No reminders list found on this device. Please add a Reminders account first."
      )
    }

    let reminder = EKReminder(eventStore: eventStore)
    reminder.calendar = calendar
    reminder.title = title
    if let notes = args["notes"] as? String, !notes.isEmpty {
      reminder.notes = notes
    } else if let notes = args["description"] as? String, !notes.isEmpty {
      reminder.notes = notes
    }
    reminder.priority = normalizedPriority(args["priority"])

    if let dueRaw = (args["due"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
       !dueRaw.isEmpty {
      let calendar = DeviceToolsSupport.isoCalendar()
      guard let due = DeviceToolsSupport.parseTime(dueRaw, calendar: calendar) else {
        return DeviceToolsSupport.invalidTimePayload(dueRaw)
      }
      // EventKit requires startDateComponents whenever dueDateComponents is set.
      // Date-only `yyyy-MM-dd` is an all-day reminder (no time components).
      let units: Set<Calendar.Component> = DeviceToolsSupport.isDateOnly(dueRaw)
        ? [.year, .month, .day]
        : [.year, .month, .day, .hour, .minute, .second, .timeZone]
      let components = calendar.dateComponents(units, from: due)
      reminder.startDateComponents = components
      reminder.dueDateComponents = components
    }

    do {
      try eventStore.save(reminder, commit: true)
    } catch {
      return DeviceToolsSupport.errorPayload(
        "INSERT_FAILED",
        "Failed to save reminder: \(error.localizedDescription)"
      )
    }

    var payload: [String: Any] = [
      "success": true,
      "id": reminder.calendarItemIdentifier,
      "title": reminder.title ?? title,
      "notes": reminder.notes ?? "",
      "priority": reminder.priority,
      "completed": false,
      "list": reminder.calendar?.title ?? "",
    ]
    Self.applyDue(reminder, to: &payload, calendar: DeviceToolsSupport.isoCalendar())
    return DeviceToolsSupport.jsonString(payload)
  }

  func complete(args: [String: Any]) -> String {
    let id = (args["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !id.isEmpty else {
      return DeviceToolsSupport.errorPayload("MISSING_REQUIRED", "'id' is required.")
    }
    guard let item = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
      return DeviceToolsSupport.errorPayload(
        "NOT_FOUND",
        "No reminder found with id '\(id)'."
      )
    }
    if item.isCompleted {
      return DeviceToolsSupport.jsonString([
        "success": true,
        "id": item.calendarItemIdentifier,
        "title": item.title ?? "",
        "completed": true,
        "already_completed": true,
      ])
    }
    item.isCompleted = true
    do {
      try eventStore.save(item, commit: true)
    } catch {
      return DeviceToolsSupport.errorPayload(
        "UPDATE_FAILED",
        "Failed to complete reminder: \(error.localizedDescription)"
      )
    }
    var payload: [String: Any] = [
      "success": true,
      "id": item.calendarItemIdentifier,
      "title": item.title ?? "",
      "completed": true,
    ]
    if let completedAt = item.completionDate {
      payload["completed_at"] = DeviceToolsSupport.formatDateTime(completedAt)
    }
    return DeviceToolsSupport.jsonString(payload)
  }

  private func requestAccess(completion: @escaping (Bool) -> Void) {
    if #available(iOS 17.0, *) {
      eventStore.requestFullAccessToReminders { granted, _ in completion(granted) }
    } else {
      eventStore.requestAccess(to: .reminder) { granted, _ in completion(granted) }
    }
  }

  /// `true`/`false` filter, or nil for all. Also accepts "all".
  private func completedArg(_ value: Any?) -> Bool? {
    if let flag = DeviceToolsSupport.boolArg(value) { return flag }
    if let text = (value as? String)?.lowercased() {
      if text == "all" { return nil }
    }
    return nil
  }

  private static func dueDate(_ reminder: EKReminder, calendar: Calendar) -> Date? {
    guard var components = reminder.dueDateComponents else { return nil }
    if components.calendar == nil {
      components.calendar = calendar
    }
    return components.date
  }

  /// All-day when EventKit stored a date with no hour/minute components.
  private static func isAllDay(_ reminder: EKReminder) -> Bool {
    guard let components = reminder.dueDateComponents else { return false }
    return components.hour == nil && components.minute == nil
  }

  private static func applyDue(
    _ reminder: EKReminder,
    to payload: inout [String: Any],
    calendar: Calendar
  ) {
    guard let due = dueDate(reminder, calendar: calendar) else { return }
    if isAllDay(reminder) {
      payload["due"] = DeviceToolsSupport.formatDateOnly(due, calendar: calendar)
      payload["all_day"] = true
    } else {
      payload["due"] = DeviceToolsSupport.formatDateTime(due)
      payload["all_day"] = false
    }
  }

  /// EventKit: 0 none, 1 high, 5 medium, 9 low. Also accepts those labels.
  private func normalizedPriority(_ value: Any?) -> Int {
    if let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
      switch text {
      case "high": return 1
      case "medium": return 5
      case "low": return 9
      case "none", "": return 0
      default: break
      }
    }
    guard let raw = DeviceToolsSupport.intArg(value) else { return 0 }
    return min(max(raw, 0), 9)
  }
}
