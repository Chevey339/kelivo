import CoreLocation
import Foundation

/// One-shot When-In-Use location for `get_current_location` and WeatherKit.
final class LocationToolHandler: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var pendingLocation: ((Result<CLLocation, LocationToolError>) -> Void)?
  private var pendingAuth: [(CLAuthorizationStatus) -> Void] = []
  private var locationTimeout: DispatchWorkItem?

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    manager.distanceFilter = kCLDistanceFilterNone
  }

  func hasPermission() -> Bool {
    isAuthorized(manager.authorizationStatus)
  }

  /// Settings toggle: prompt when undetermined; open Settings when denied.
  func requestPermission(completion: @escaping (Bool) -> Void) {
    DeviceToolsSupport.finishOnMain { [weak self] in
      guard let self else {
        completion(false)
        return
      }
      guard CLLocationManager.locationServicesEnabled() else {
        completion(false)
        return
      }
      let status = self.manager.authorizationStatus
      if self.isAuthorized(status) {
        completion(true)
        return
      }
      switch status {
      case .notDetermined:
        self.enqueueAuthorization { next in completion(self.isAuthorized(next)) }
      default:
        DeviceToolsSupport.openAppSettings()
        completion(false)
      }
    }
  }

  func getCurrentLocation(args: [String: Any], completion: @escaping (String) -> Void) {
    requestOneShotLocation(openSettingsIfDenied: false) { [weak self] result in
      switch result {
      case .failure(let error):
        completion(error.payload)
      case .success(let location):
        self?.buildPayload(location: location, completion: completion)
      }
    }
  }

  /// Resolves a `CLLocation` from explicit coordinates or a one-shot GPS fix.
  func resolveLocation(
    latitude: Double?,
    longitude: Double?,
    completion: @escaping (Result<CLLocation, LocationToolError>) -> Void
  ) {
    if let latitude, let longitude {
      guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
        completion(.failure(.invalidCoordinates))
        return
      }
      completion(.success(CLLocation(latitude: latitude, longitude: longitude)))
      return
    }
    if (latitude == nil) != (longitude == nil) {
      completion(.failure(.invalidCoordinates))
      return
    }
    requestOneShotLocation(openSettingsIfDenied: false, completion: completion)
  }

  func requestOneShotLocation(
    openSettingsIfDenied: Bool,
    completion: @escaping (Result<CLLocation, LocationToolError>) -> Void
  ) {
    DeviceToolsSupport.finishOnMain { [weak self] in
      guard let self else {
        completion(.failure(.unavailable))
        return
      }
      guard CLLocationManager.locationServicesEnabled() else {
        completion(.failure(.servicesDisabled))
        return
      }
      if self.pendingLocation != nil {
        completion(.failure(.busy))
        return
      }

      let deliver: (Result<CLLocation, LocationToolError>) -> Void = { result in
        DeviceToolsSupport.finishOnMain { completion(result) }
      }

      let startRequest = { [weak self] in
        guard let self else {
          deliver(.failure(.unavailable))
          return
        }
        if self.pendingLocation != nil {
          deliver(.failure(.busy))
          return
        }
        self.pendingLocation = deliver
        let timeout = DispatchWorkItem { [weak self] in
          guard let self, let pending = self.pendingLocation else { return }
          self.pendingLocation = nil
          pending(.failure(.timeout))
        }
        self.locationTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
        self.manager.requestLocation()
      }

      let status = self.manager.authorizationStatus
      if self.isAuthorized(status) {
        startRequest()
        return
      }
      if status == .notDetermined {
        self.enqueueAuthorization { [weak self] next in
          guard let self else { return }
          if self.isAuthorized(next) {
            startRequest()
          } else {
            deliver(.failure(.denied))
          }
        }
        return
      }
      if openSettingsIfDenied {
        DeviceToolsSupport.openAppSettings()
      }
      deliver(.failure(.denied))
    }
  }

  private func buildPayload(location: CLLocation, completion: @escaping (String) -> Void) {
    var payload: [String: Any] = [
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
      "accuracy_m": location.horizontalAccuracy,
      "timestamp": DeviceToolsSupport.formatDateTime(location.timestamp),
      "timestamp_ms": Int(location.timestamp.timeIntervalSince1970 * 1000),
    ]
    if location.verticalAccuracy >= 0 {
      payload["altitude_m"] = location.altitude
    }

    let geocoder = CLGeocoder()
    geocoder.reverseGeocodeLocation(location) { marks, _ in
      if let mark = marks?.first {
        if let city = mark.locality, !city.isEmpty { payload["city"] = city }
        if let region = mark.administrativeArea, !region.isEmpty { payload["region"] = region }
        if let country = mark.country, !country.isEmpty { payload["country"] = country }
        if let name = mark.name, !name.isEmpty { payload["place_name"] = name }
      }
      completion(DeviceToolsSupport.jsonString(payload))
    }
  }

  private func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
    status == .authorizedWhenInUse || status == .authorizedAlways
  }

  private func enqueueAuthorization(_ completion: @escaping (CLAuthorizationStatus) -> Void) {
    let alreadyWaiting = !pendingAuth.isEmpty
    pendingAuth.append(completion)
    if !alreadyWaiting {
      manager.requestWhenInUseAuthorization()
    }
  }

  private func finishLocation(_ result: Result<CLLocation, LocationToolError>) {
    locationTimeout?.cancel()
    locationTimeout = nil
    let pending = pendingLocation
    pendingLocation = nil
    pending?(result)
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let pending = pendingAuth
    pendingAuth.removeAll()
    for completion in pending {
      completion(manager.authorizationStatus)
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else {
      finishLocation(.failure(.unavailable))
      return
    }
    finishLocation(.success(location))
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    if let clError = error as? CLError, clError.code == .denied {
      finishLocation(.failure(.denied))
      return
    }
    finishLocation(.failure(.unavailable))
  }
}

enum LocationToolError: Error {
  case denied
  case servicesDisabled
  case timeout
  case busy
  case unavailable
  case invalidCoordinates

  var payload: String {
    switch self {
    case .denied:
      return DeviceToolsSupport.noPermissionPayload(
        "Location permission is not granted. Please allow Location While Using the App "
          + "in system Settings and try again."
      )
    case .servicesDisabled:
      return DeviceToolsSupport.errorPayload(
        "LOCATION_DISABLED",
        "Location services are turned off on this device."
      )
    case .timeout:
      return DeviceToolsSupport.errorPayload(
        "LOCATION_TIMEOUT",
        "Timed out waiting for a location fix. Please try again."
      )
    case .busy:
      return DeviceToolsSupport.errorPayload(
        "LOCATION_BUSY",
        "A location request is already in progress. Please try again."
      )
    case .unavailable:
      return DeviceToolsSupport.errorPayload(
        "LOCATION_UNAVAILABLE",
        "Could not determine the current location."
      )
    case .invalidCoordinates:
      return DeviceToolsSupport.errorPayload(
        "INVALID_COORDINATES",
        "latitude must be between -90 and 90, longitude between -180 and 180. "
          + "Provide both, or omit both to use the current location."
      )
    }
  }
}
