import Foundation
import HealthKit

/// HealthKit summary for `get_health_summary`.
///
/// Read authorization cannot be distinguished from "no samples" on iOS, so
/// missing metrics are returned as `{ "status": "unavailable" }` rather than 0.
final class HealthToolHandler {
  private let store = HKHealthStore()

  func isAvailable() -> Bool {
    HKHealthStore.isHealthDataAvailable()
  }

  /// Settings toggle: presents the Health read sheet. The completion flag is
  /// only "the sheet finished"; iOS does not reveal per-type read grants.
  func requestPermission(completion: @escaping (Bool) -> Void) {
    DeviceToolsSupport.finishOnMain { [weak self] in
      guard let self else {
        completion(false)
        return
      }
      guard self.isAvailable() else {
        completion(false)
        return
      }
      self.store.requestAuthorization(toShare: [], read: self.readTypes) { success, _ in
        DeviceToolsSupport.finishOnMain { completion(success) }
      }
    }
  }

  func getHealthSummary(args: [String: Any], completion: @escaping (String) -> Void) {
    guard isAvailable() else {
      completion(
        DeviceToolsSupport.errorPayload(
          "HEALTH_UNAVAILABLE",
          "Health data is not available on this device."
        )
      )
      return
    }

    store.requestAuthorization(toShare: [], read: readTypes) { [weak self] _, _ in
      guard let self else { return }
      self.buildSummary(completion: completion)
    }
  }

  private var readTypes: Set<HKObjectType> {
    var types = Set<HKObjectType>()
    if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
      types.insert(steps)
    }
    if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
      types.insert(energy)
    }
    if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
      types.insert(distance)
    }
    if let heart = HKObjectType.quantityType(forIdentifier: .heartRate) {
      types.insert(heart)
    }
    if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
      types.insert(sleep)
    }
    types.insert(HKObjectType.workoutType())
    return types
  }

  private func buildSummary(completion: @escaping (String) -> Void) {
    let calendar = DeviceToolsSupport.isoCalendar()
    let now = Date()
    let startOfToday = calendar.startOfDay(for: now)
    // Last night: yesterday 18:00 → today noon (not yesterday 06:00).
    let lastNightStart = calendar.date(byAdding: .hour, value: -6, to: startOfToday) ?? startOfToday
    let lastNightEnd = calendar.date(byAdding: .hour, value: 12, to: startOfToday) ?? now
    let workoutLookback = calendar.date(byAdding: .day, value: -14, to: now) ?? now
    let updatedAt = DeviceToolsSupport.formatDateTime(now)

    let group = DispatchGroup()
    var steps: [String: Any] = Self.unavailable(startOfToday, now)
    var energy: [String: Any] = Self.unavailable(startOfToday, now)
    var distance: [String: Any] = Self.unavailable(startOfToday, now)
    var sleep: [String: Any] = Self.unavailable(lastNightStart, lastNightEnd)
    var heartRate: [String: Any] = ["status": "unavailable"]
    var workouts: [String: Any] = ["status": "unavailable"]

    if let type = HKQuantityType.quantityType(forIdentifier: .stepCount) {
      group.enter()
      querySum(type: type, unit: .count(), start: startOfToday, end: now) { metric in
        steps = metric
        group.leave()
      }
    }
    if let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
      group.enter()
      querySum(type: type, unit: .kilocalorie(), start: startOfToday, end: now) { metric in
        energy = metric
        group.leave()
      }
    }
    if let type = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
      group.enter()
      querySum(type: type, unit: .meter(), start: startOfToday, end: now) { metric in
        distance = metric
        group.leave()
      }
    }
    group.enter()
    querySleep(start: lastNightStart, end: lastNightEnd) { metric in
      sleep = metric
      group.leave()
    }
    group.enter()
    queryLatestHeartRate { metric in
      heartRate = metric
      group.leave()
    }
    group.enter()
    queryWorkouts(start: workoutLookback, end: now, limit: 5) { metric in
      workouts = metric
      group.leave()
    }

    group.notify(queue: .global(qos: .userInitiated)) {
      let payload: [String: Any] = [
        "updated_at": updatedAt,
        "interval": [
          "start": DeviceToolsSupport.formatDateTime(startOfToday),
          "end": DeviceToolsSupport.formatDateTime(now),
        ],
        "steps": steps,
        "active_energy_kcal": energy,
        "walking_running_distance_m": distance,
        "sleep_last_night": sleep,
        "heart_rate": heartRate,
        "workouts": workouts,
      ]
      DeviceToolsSupport.finishOnMain {
        completion(DeviceToolsSupport.jsonString(payload))
      }
    }
  }

  private func querySum(
    type: HKQuantityType,
    unit: HKUnit,
    start: Date,
    end: Date,
    completion: @escaping ([String: Any]) -> Void
  ) {
    let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let query = HKStatisticsQuery(
      quantityType: type,
      quantitySamplePredicate: predicate,
      options: .cumulativeSum
    ) { _, statistics, _ in
      guard let quantity = statistics?.sumQuantity() else {
        completion(Self.unavailable(start, end))
        return
      }
      var metric = Self.interval(start, end)
      metric["status"] = "ok"
      metric["value"] = (quantity.doubleValue(for: unit) * 10).rounded() / 10
      completion(metric)
    }
    store.execute(query)
  }

  private func querySleep(start: Date, end: Date, completion: @escaping ([String: Any]) -> Void) {
    guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
      completion(Self.unavailable(start, end))
      return
    }
    let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let query = HKSampleQuery(
      sampleType: sleepType,
      predicate: predicate,
      limit: HKObjectQueryNoLimit,
      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
    ) { _, samples, _ in
      let categorySamples = samples as? [HKCategorySample] ?? []
      guard let asleep = Self.mergedAsleepInterval(categorySamples) else {
        completion(Self.unavailable(start, end))
        return
      }
      var metric = Self.interval(start, end)
      metric["status"] = "ok"
      metric["duration_minutes"] = Int((asleep.duration / 60).rounded())
      metric["sleep_start"] = DeviceToolsSupport.formatDateTime(asleep.start)
      metric["sleep_end"] = DeviceToolsSupport.formatDateTime(asleep.end)
      completion(metric)
    }
    store.execute(query)
  }

  private func queryLatestHeartRate(completion: @escaping ([String: Any]) -> Void) {
    guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
      completion(["status": "unavailable"])
      return
    }
    let query = HKSampleQuery(
      sampleType: type,
      predicate: nil,
      limit: 1,
      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
    ) { _, samples, _ in
      guard let sample = samples?.first as? HKQuantitySample else {
        completion(["status": "unavailable"])
        return
      }
      let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
      completion([
        "status": "ok",
        "bpm": (bpm * 10).rounded() / 10,
        "measured_at": DeviceToolsSupport.formatDateTime(sample.endDate),
      ])
    }
    store.execute(query)
  }

  private func queryWorkouts(
    start: Date,
    end: Date,
    limit: Int,
    completion: @escaping ([String: Any]) -> Void
  ) {
    let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    let query = HKSampleQuery(
      sampleType: .workoutType(),
      predicate: predicate,
      limit: limit,
      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
    ) { _, samples, _ in
      let workouts = samples as? [HKWorkout] ?? []
      guard !workouts.isEmpty else {
        var metric = Self.unavailable(start, end)
        metric["items"] = []
        completion(metric)
        return
      }
      let items: [[String: Any]] = workouts.map { workout in
        var item: [String: Any] = [
          "type": Self.workoutName(workout.workoutActivityType),
          "start": DeviceToolsSupport.formatDateTime(workout.startDate),
          "end": DeviceToolsSupport.formatDateTime(workout.endDate),
          "duration_minutes": Int((workout.duration / 60).rounded()),
        ]
        if let energy = workout.totalEnergyBurned {
          item["active_energy_kcal"] =
            (energy.doubleValue(for: .kilocalorie()) * 10).rounded() / 10
        }
        if let distance = workout.totalDistance {
          item["distance_m"] = (distance.doubleValue(for: .meter()) * 10).rounded() / 10
        }
        return item
      }
      var metric = Self.interval(start, end)
      metric["status"] = "ok"
      metric["items"] = items
      completion(metric)
    }
    store.execute(query)
  }

  /// Unions overlapping asleep samples so Watch + third-party sources are
  /// not double-counted.
  private static func mergedAsleepInterval(
    _ samples: [HKCategorySample]
  ) -> (duration: TimeInterval, start: Date, end: Date)? {
    var intervals: [(start: Date, end: Date)] = []
    for sample in samples where isAsleep(sample) {
      guard sample.endDate > sample.startDate else { continue }
      intervals.append((sample.startDate, sample.endDate))
    }
    guard !intervals.isEmpty else { return nil }
    intervals.sort { $0.start < $1.start }

    var merged: [(start: Date, end: Date)] = [intervals[0]]
    for interval in intervals.dropFirst() {
      let lastIndex = merged.count - 1
      if interval.start <= merged[lastIndex].end {
        merged[lastIndex].end = max(merged[lastIndex].end, interval.end)
      } else {
        merged.append(interval)
      }
    }

    let duration = merged.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
    guard duration > 0 else { return nil }
    let start = merged[0].start
    let end = merged.map(\.end).max() ?? merged[0].end
    return (duration, start, end)
  }

  private static func isAsleep(_ sample: HKCategorySample) -> Bool {
    if #available(iOS 16.0, *) {
      switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
      case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM:
        return true
      default:
        return false
      }
    }
    return sample.value == 1
  }

  private static func unavailable(_ start: Date, _ end: Date) -> [String: Any] {
    var metric = interval(start, end)
    metric["status"] = "unavailable"
    return metric
  }

  private static func interval(_ start: Date, _ end: Date) -> [String: Any] {
    [
      "start": DeviceToolsSupport.formatDateTime(start),
      "end": DeviceToolsSupport.formatDateTime(end),
    ]
  }

  private static func workoutName(_ type: HKWorkoutActivityType) -> String {
    if #available(iOS 16.0, *) {
      switch type {
      case .running: return "running"
      case .walking: return "walking"
      case .cycling: return "cycling"
      case .swimming: return "swimming"
      case .yoga: return "yoga"
      case .functionalStrengthTraining: return "strength"
      case .traditionalStrengthTraining: return "strength"
      case .coreTraining: return "core"
      case .elliptical: return "elliptical"
      case .rowing: return "rowing"
      case .hiking: return "hiking"
      case .dance: return "dance"
      case .cooldown: return "cooldown"
      case .mixedCardio: return "cardio"
      case .highIntensityIntervalTraining: return "hiit"
      default: return "other"
      }
    }
    return "other"
  }
}
