import CoreLocation
import Foundation
import WeatherKit

/// Native WeatherKit backend for `get_weather`.
///
/// WeatherKit requires iOS 16+, the WeatherKit capability, and a visible
/// attribution payload that the Flutter UI must render.
final class WeatherToolHandler {
  private let locationHandler: LocationToolHandler

  init(locationHandler: LocationToolHandler) {
    self.locationHandler = locationHandler
  }

  static var isAvailable: Bool {
    if #available(iOS 16.0, *) { return true }
    return false
  }

  func getWeather(args: [String: Any], completion: @escaping (String) -> Void) {
    if #available(iOS 16.0, *) {
      fetchWeather(args: args, completion: completion)
    } else {
      completion(
        DeviceToolsSupport.errorPayload(
          "UNSUPPORTED_OS",
          "Weather requires iOS 16 or later."
        )
      )
    }
  }

  @available(iOS 16.0, *)
  private func fetchWeather(args: [String: Any], completion: @escaping (String) -> Void) {
    let latitude = DeviceToolsSupport.doubleArg(args["latitude"])
    let longitude = DeviceToolsSupport.doubleArg(args["longitude"])
    locationHandler.resolveLocation(latitude: latitude, longitude: longitude) { result in
      switch result {
      case .failure(let error):
        completion(error.payload)
      case .success(let location):
        Task {
          let payload = await self.queryWeatherKit(location: location)
          DeviceToolsSupport.finishOnMain { completion(payload) }
        }
      }
    }
  }

  @available(iOS 16.0, *)
  private func queryWeatherKit(location: CLLocation) async -> String {
    do {
      let service = WeatherService.shared
      async let weather = service.weather(for: location)
      async let attribution = service.attribution
      async let timeZone = Self.locationTimeZone(location)
      return DeviceToolsSupport.jsonString(
        Self.encode(
          weather: try await weather,
          attribution: try await attribution,
          location: location,
          timeZone: await timeZone
        )
      )
    } catch {
      return DeviceToolsSupport.errorPayload(
        "WEATHER_UNAVAILABLE",
        "Could not load weather for this location: \(error.localizedDescription)"
      )
    }
  }

  /// WeatherKit daily `date` is midnight in the forecast location's timezone.
  /// Fall back to the device timezone if reverse geocode fails.
  private static func locationTimeZone(_ location: CLLocation) async -> TimeZone {
    await withCheckedContinuation { continuation in
      let geocoder = CLGeocoder()
      geocoder.reverseGeocodeLocation(location) { marks, _ in
        _ = geocoder
        continuation.resume(returning: marks?.first?.timeZone ?? .current)
      }
    }
  }

  @available(iOS 16.0, *)
  private static func encode(
    weather: Weather,
    attribution: WeatherAttribution,
    location: CLLocation,
    timeZone: TimeZone
  ) -> [String: Any] {
    let current = weather.currentWeather
    let now = Date()
    let hourlyLimit = 12
    let dailyLimit = 7
    var calendar = DeviceToolsSupport.isoCalendar()
    calendar.timeZone = timeZone

    let hourly: [[String: Any]] = Array(weather.hourlyForecast)
      .filter { $0.date >= now.addingTimeInterval(-1800) }
      .prefix(hourlyLimit)
      .map { hour in
        [
          "time": DeviceToolsSupport.formatDateTime(hour.date),
          "condition": hour.condition.description,
          "symbol_name": hour.symbolName,
          "temperature_c": rounded(celsius(hour.temperature)),
          "precipitation_chance": rounded(hour.precipitationChance),
        ]
      }

    let daily: [[String: Any]] = Array(weather.dailyForecast)
      .prefix(dailyLimit)
      .map { day in
        var item: [String: Any] = [
          "date": DeviceToolsSupport.formatDateOnly(day.date, calendar: calendar),
          "condition": day.condition.description,
          "symbol_name": day.symbolName,
          "high_c": rounded(celsius(day.highTemperature)),
          "low_c": rounded(celsius(day.lowTemperature)),
          "precipitation_chance": rounded(day.precipitationChance),
        ]
        if let sunrise = day.sun.sunrise {
          item["sunrise"] = DeviceToolsSupport.formatDateTime(sunrise)
        }
        if let sunset = day.sun.sunset {
          item["sunset"] = DeviceToolsSupport.formatDateTime(sunset)
        }
        return item
      }

    var currentPayload: [String: Any] = [
      "observed_at": DeviceToolsSupport.formatDateTime(current.date),
      "condition": current.condition.description,
      "symbol_name": current.symbolName,
      "temperature_c": rounded(celsius(current.temperature)),
      "apparent_temperature_c": rounded(celsius(current.apparentTemperature)),
      "humidity": rounded(current.humidity),
      "uv_index": current.uvIndex.value,
      "cloud_cover": rounded(current.cloudCover),
    ]
    if let chance = nearestHourlyPrecipitation(weather, now: now) {
      currentPayload["precipitation_chance"] = chance
    }

    return [
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
      "updated_at": DeviceToolsSupport.formatDateTime(now),
      "current": currentPayload,
      "hourly": hourly,
      "daily": daily,
      "attribution": [
        "service_name": attribution.serviceName,
        "legal_page_url": attribution.legalPageURL.absoluteString,
        "display_text": "Weather data from \(attribution.serviceName)",
        "combined_mark_light_url": attribution.combinedMarkLightURL.absoluteString,
        "combined_mark_dark_url": attribution.combinedMarkDarkURL.absoluteString,
        "square_mark_url": attribution.squareMarkURL.absoluteString,
      ],
    ]
  }

  @available(iOS 16.0, *)
  private static func nearestHourlyPrecipitation(_ weather: Weather, now: Date) -> Double? {
    Array(weather.hourlyForecast)
      .min(by: { abs($0.date.timeIntervalSince(now)) < abs($1.date.timeIntervalSince(now)) })
      .map { rounded($0.precipitationChance) }
  }

  private static func celsius(_ value: Measurement<UnitTemperature>) -> Double {
    value.converted(to: .celsius).value
  }

  private static func rounded(_ value: Double) -> Double {
    (value * 10).rounded() / 10
  }
}
