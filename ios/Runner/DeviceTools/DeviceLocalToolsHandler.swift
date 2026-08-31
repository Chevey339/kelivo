import EventKit
import Flutter
import Foundation

/// Native backend for the AI assistant's device-local tools on iOS.
///
/// Calendar query/create is implemented with EventKit. Location, weather,
/// health, and reminders are dispatched to dedicated handlers. Screen time
/// has no generally available query API on iOS, so it is not exposed here.
///
/// Methods receive the tool arguments as a JSON string and return a JSON
/// string payload. Errors the LLM should see (missing permission, bad
/// arguments) are returned as JSON payloads with an "error" field.
final class DeviceLocalToolsHandler {
  private let eventStore = EKEventStore()
  private let locationHandler = LocationToolHandler()
  private let healthHandler = HealthToolHandler()
  private lazy var weatherHandler = WeatherToolHandler(locationHandler: locationHandler)
  private lazy var remindersHandler = RemindersToolHandler(eventStore: eventStore)

  func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = DeviceToolsSupport.parseArgs(call.arguments)
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
          result(Self.noCalendarPermissionPayload)
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          let payload = self.queryCalendar(args: args)
          DeviceToolsSupport.finishOnMain { result(payload) }
        }
      }
    case "createCalendarEvent":
      ensureCalendarAccess { [weak self] granted in
        guard let self else { return }
        guard granted else {
          result(Self.noCalendarPermissionPayload)
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          let payload = self.createCalendarEvent(args: args)
          DeviceToolsSupport.finishOnMain { result(payload) }
        }
      }
    case "getScreenTime":
      result(DeviceToolsSupport.errorPayload(
        "UNSUPPORTED_PLATFORM",
        "Screen time queries are not available on iOS; Apple does not provide a general-purpose API for this."
      ))
    case "hasLocationPermission":
      result(locationHandler.hasPermission())
    case "requestLocationPermission":
      locationHandler.requestPermission { granted in result(granted) }
    case "getCurrentLocation":
      locationHandler.getCurrentLocation(args: args) { payload in result(payload) }
    case "isWeatherKitAvailable":
      result(WeatherToolHandler.isAvailable)
    case "getWeather":
      weatherHandler.getWeather(args: args) { payload in result(payload) }
    case "hasRemindersPermission":
      result(remindersHandler.hasPermission())
    case "requestRemindersPermission":
      remindersHandler.requestPermission { granted in result(granted) }
    case "queryReminders":
      remindersHandler.ensureAccess { [weak self] granted in
        guard let self else { return }
        guard granted else {
          result(Self.noRemindersPermissionPayload)
          return
        }
        self.remindersHandler.query(args: args) { payload in result(payload) }
      }
    case "createReminder":
      remindersHandler.ensureAccess { [weak self] granted in
        guard let self else { return }
        guard granted else {
          result(Self.noRemindersPermissionPayload)
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          let payload = self.remindersHandler.create(args: args)
          DeviceToolsSupport.finishOnMain { result(payload) }
        }
      }
    case "completeReminder":
      remindersHandler.ensureAccess { [weak self] granted in
        guard let self else { return }
        guard granted else {
          result(Self.noRemindersPermissionPayload)
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          let payload = self.remindersHandler.complete(args: args)
          DeviceToolsSupport.finishOnMain { result(payload) }
        }
      }
    case "isHealthDataAvailable":
      result(healthHandler.isAvailable())
    case "availableHealthTypes":
      result(healthHandler.availableTypeIds())
    case "requestHealthPermission":
      healthHandler.requestPermission(
        types: DeviceToolsSupport.stringListArg(args["types"])
      ) { granted in result(granted) }
    case "getHealthSummary":
      healthHandler.getHealthSummary(args: args) { payload in result(payload) }
    case "openAppSettings":
      DeviceToolsSupport.openAppSettings()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Calendar permission

  private static let noCalendarPermissionPayload = DeviceToolsSupport.noPermissionPayload(
    "Calendar permission is not granted. Please ask the user to allow full calendar access "
      + "for this app in the system Settings and try again."
  )

  private static let noRemindersPermissionPayload = DeviceToolsSupport.noPermissionPayload(
    "Reminders permission is not granted. Please ask the user to allow full reminders access "
      + "for this app in the system Settings and try again."
  )

  private func hasCalendarPermission() -> Bool {
    let status = EKEventStore.authorizationStatus(for: .event)
    if #available(iOS 17.0, *) {
      return status == .fullAccess
    }
    return status == .authorized
  }

  private func requestCalendarPermission(result: @escaping FlutterResult) {
    let finish: (Bool) -> Void = { granted in
      DeviceToolsSupport.finishOnMain { result(granted) }
    }
    let status = EKEventStore.authorizationStatus(for: .event)
    if #available(iOS 17.0, *) {
      switch status {
      case .fullAccess:
        finish(true)
      case .notDetermined:
        eventStore.requestFullAccessToEvents { granted, _ in finish(granted) }
      default:
        DeviceToolsSupport.openAppSettings()
        finish(false)
      }
    } else {
      switch status {
      case .authorized:
        finish(true)
      case .notDetermined:
        eventStore.requestAccess(to: .event) { granted, _ in finish(granted) }
      default:
        DeviceToolsSupport.openAppSettings()
        finish(false)
      }
    }
  }

  private func ensureCalendarAccess(completion: @escaping (Bool) -> Void) {
    let finish: (Bool) -> Void = { granted in
      DeviceToolsSupport.finishOnMain { completion(granted) }
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
    let limit = min(max(DeviceToolsSupport.intArg(args["limit"]) ?? 20, 1), 100)
    let keyword = (args["query"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    let range = DeviceToolsSupport.resolveDateRange(
      args: args,
      defaultPreset: "today",
      allowedPresets: ["today", "week", "month"]
    )
    if let error = range.error { return error }

    let calendar = DeviceToolsSupport.isoCalendar()
    let predicate = eventStore.predicateForEvents(
      withStart: range.start,
      end: range.end,
      calendars: nil
    )
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
        item["start"] = DeviceToolsSupport.formatDateOnly(event.startDate, calendar: calendar)
        item["end"] = event.endDate.map {
          DeviceToolsSupport.formatDateOnly(Self.exclusiveAllDayEnd($0, calendar: calendar), calendar: calendar)
        } ?? ""
      } else {
        item["start"] = DeviceToolsSupport.formatDateTime(event.startDate)
        item["end"] = event.endDate.map(DeviceToolsSupport.formatDateTime) ?? ""
      }
      items.append(item)
    }

    return DeviceToolsSupport.jsonString([
      "range_start": DeviceToolsSupport.formatDateTime(range.start),
      "range_end": DeviceToolsSupport.formatDateTime(range.end),
      "count": items.count,
      "events": items,
    ])
  }

  // MARK: - Calendar create

  private func createCalendarEvent(args: [String: Any]) -> String {
    let title = (args["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let startRaw = (args["start"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !title.isEmpty, !startRaw.isEmpty else {
      return DeviceToolsSupport.errorPayload("MISSING_REQUIRED", "Both 'title' and 'start' are required.")
    }
    let allDay = DeviceToolsSupport.boolArg(args["all_day"]) ?? false

    let calendar = DeviceToolsSupport.isoCalendar()

    guard let startDate = DeviceToolsSupport.parseTime(startRaw, calendar: calendar) else {
      return DeviceToolsSupport.invalidTimePayload(startRaw)
    }
    let endDate: Date
    if let endRaw = args["end"] as? String, !endRaw.isEmpty {
      guard let parsedEnd = DeviceToolsSupport.parseTime(endRaw, calendar: calendar) else {
        return DeviceToolsSupport.invalidTimePayload(endRaw)
      }
      endDate = parsedEnd
    } else if allDay {
      let dayStart = calendar.startOfDay(for: startDate)
      endDate = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? startDate.addingTimeInterval(86400)
    } else {
      endDate = startDate.addingTimeInterval(3600)
    }
    guard startDate < endDate else {
      return DeviceToolsSupport.errorPayload("INVALID_RANGE", "end must be later than start.")
    }

    let allDayStart = calendar.startOfDay(for: startDate)
    let allDayEndExclusive = calendar.startOfDay(for: endDate)
    if allDay, allDayStart >= allDayEndExclusive {
      return DeviceToolsSupport.errorPayload("INVALID_RANGE", "all-day event end date must be later than start date.")
    }

    guard let targetCalendar = eventStore.defaultCalendarForNewEvents else {
      return DeviceToolsSupport.errorPayload(
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
      event.endDate = allDayEndExclusive.addingTimeInterval(-1)
    } else {
      event.startDate = startDate
      event.endDate = endDate
    }

    let reminderMinutes = Self.reminderMinutesArg(args["reminders"])
    for minutes in reminderMinutes {
      event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-minutes * 60)))
    }

    do {
      try eventStore.save(event, span: .thisEvent, commit: true)
    } catch {
      return DeviceToolsSupport.errorPayload("INSERT_FAILED", "Failed to save calendar event: \(error.localizedDescription)")
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
      payload["start"] = DeviceToolsSupport.formatDateOnly(allDayStart, calendar: calendar)
      payload["end"] = DeviceToolsSupport.formatDateOnly(allDayEndExclusive, calendar: calendar)
    } else {
      payload["start"] = DeviceToolsSupport.formatDateTime(startDate)
      payload["end"] = DeviceToolsSupport.formatDateTime(endDate)
    }
    return DeviceToolsSupport.jsonString(payload)
  }

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

  private static func exclusiveAllDayEnd(_ end: Date, calendar: Calendar) -> Date {
    calendar.startOfDay(for: end.addingTimeInterval(1))
  }
}
