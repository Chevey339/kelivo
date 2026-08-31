import Foundation
import UIKit

/// Shared JSON, time, and permission helpers for device-local tools.
enum DeviceToolsSupport {
  static func parseArgs(_ arguments: Any?) -> [String: Any] {
    guard
      let json = arguments as? String,
      let data = json.data(using: .utf8),
      let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return [:]
    }
    return parsed
  }

  static func stringListArg(_ value: Any?) -> [String] {
    guard let list = value as? [Any] else { return [] }
    return list.compactMap { item in
      if let text = item as? String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
      }
      return nil
    }
  }

  static func intArg(_ value: Any?) -> Int? {
    if let number = value as? Int { return number }
    if let number = value as? Double { return Int(number) }
    if let text = value as? String { return Int(text.trimmingCharacters(in: .whitespaces)) }
    return nil
  }

  static func doubleArg(_ value: Any?) -> Double? {
    if let number = value as? Double { return number }
    if let number = value as? Int { return Double(number) }
    if let number = value as? NSNumber { return number.doubleValue }
    if let text = value as? String { return Double(text.trimmingCharacters(in: .whitespaces)) }
    return nil
  }

  static func boolArg(_ value: Any?) -> Bool? {
    if let flag = value as? Bool { return flag }
    if let text = (value as? String)?.lowercased() {
      if text == "true" { return true }
      if text == "false" { return false }
    }
    return nil
  }

  static func jsonString(_ payload: [String: Any]) -> String {
    guard
      let data = try? JSONSerialization.data(withJSONObject: payload),
      let text = String(data: data, encoding: .utf8)
    else {
      return "{\"error\":\"ENCODING_ERROR\",\"message\":\"Failed to encode tool result.\"}"
    }
    return text
  }

  static func errorPayload(_ error: String, _ message: String) -> String {
    jsonString(["error": error, "message": message])
  }

  static func invalidTimePayload(_ raw: String) -> String {
    errorPayload(
      "INVALID_TIME",
      "Invalid time format: '\(raw)'. Use ISO-8601 date/date-time or epoch milliseconds."
    )
  }

  static func noPermissionPayload(_ message: String) -> String {
    errorPayload("NO_PERMISSION", message)
  }

  static func isoCalendar() -> Calendar {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = .current
    return calendar
  }

  /// True when the raw string is a date-only `yyyy-MM-dd` (no time).
  static func isDateOnly(_ raw: String) -> Bool {
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard text.count == 10 else { return false }
    let parts = text.split(separator: "-")
    return parts.count == 3
      && parts[0].count == 4 && parts[0].allSatisfy(\.isNumber)
      && parts[1].count == 2 && parts[1].allSatisfy(\.isNumber)
      && parts[2].count == 2 && parts[2].allSatisfy(\.isNumber)
  }

  /// Parses epoch milliseconds, offset date-times, local date-times, and
  /// plain dates (interpreted at local midnight).
  static func parseTime(_ raw: String, calendar: Calendar) -> Date? {
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

  static func formatDateTime(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = .current
    return formatter.string(from: date)
  }

  static func formatDateOnly(_ date: Date, calendar: Calendar) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  /// Resolves a begin/end or range preset into `[start, end)`.
  /// On failure, `error` is a ready-to-return JSON payload.
  static func resolveDateRange(
    args: [String: Any],
    defaultPreset: String,
    allowedPresets: Set<String>
  ) -> (start: Date, end: Date, error: String?) {
    let calendar = isoCalendar()
    let now = Date()
    let startOfToday = calendar.startOfDay(for: now)
    let rangePreset = (args["range"] as? String)?.lowercased() ?? defaultPreset

    if let beginRaw = args["begin"] as? String, !beginRaw.isEmpty {
      guard let parsedStart = parseTime(beginRaw, calendar: calendar) else {
        return (now, now, invalidTimePayload(beginRaw))
      }
      if let endRaw = args["end"] as? String, !endRaw.isEmpty {
        guard let parsedEnd = parseTime(endRaw, calendar: calendar) else {
          return (now, now, invalidTimePayload(endRaw))
        }
        guard parsedStart < parsedEnd else {
          return (now, now, errorPayload("INVALID_RANGE", "begin must be earlier than end."))
        }
        return (parsedStart, parsedEnd, nil)
      }
      guard parsedStart < now else {
        return (now, now, errorPayload("INVALID_RANGE", "begin must be earlier than end."))
      }
      return (parsedStart, now, nil)
    }

    let preset = allowedPresets.contains(rangePreset) ? rangePreset : defaultPreset
    let startDate: Date
    let endDate: Date
    switch preset {
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
    return (startDate, endDate, nil)
  }

  static func openAppSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
  }

  static func finishOnMain(_ work: @escaping () -> Void) {
    if Thread.isMainThread {
      work()
    } else {
      DispatchQueue.main.async(execute: work)
    }
  }
}
