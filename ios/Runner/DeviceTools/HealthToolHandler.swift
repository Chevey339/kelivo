import Foundation
import HealthKit

/// HealthKit summary for `get_health_summary`.
///
/// Read authorization cannot be distinguished from "no samples" on iOS, so
/// missing metrics are returned as `{ "status": "unavailable" }` rather than 0.
/// Only collaborator-selected type IDs are authorized and queried.
final class HealthToolHandler {
  private let store = HKHealthStore()

  func isAvailable() -> Bool {
    HKHealthStore.isHealthDataAvailable()
  }

  func availableTypeIds() -> [String] {
    HealthMetric.allCases.compactMap { metric in
      metric.objectType == nil ? nil : metric.rawValue
    }
  }

  /// Settings toggle: presents the Health read sheet for [types] only.
  /// The completion flag is only "the sheet finished"; iOS does not reveal
  /// per-type read grants.
  func requestPermission(types: [String], completion: @escaping (Bool) -> Void) {
    DeviceToolsSupport.finishOnMain { [weak self] in
      guard let self else {
        completion(false)
        return
      }
      guard self.isAvailable() else {
        completion(false)
        return
      }
      let readTypes = self.objectTypes(for: types)
      guard !readTypes.isEmpty else {
        completion(true)
        return
      }
      self.store.requestAuthorization(toShare: [], read: readTypes) { success, _ in
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

    let ids = DeviceToolsSupport.stringListArg(args["types"]).filter { objectType(for: $0) != nil }
    guard !ids.isEmpty else {
      completion(
        DeviceToolsSupport.errorPayload(
          "NO_TYPES",
          "No health data types are enabled for this assistant."
        )
      )
      return
    }

    store.requestAuthorization(toShare: [], read: objectTypes(for: ids)) { [weak self] _, _ in
      guard let self else { return }
      self.buildSummary(ids: ids, completion: completion)
    }
  }

  private func objectTypes(for ids: [String]) -> Set<HKObjectType> {
    Set(ids.compactMap { objectType(for: $0) })
  }

  private func objectType(for id: String) -> HKObjectType? {
    guard let metric = HealthMetric(rawValue: id) else { return nil }
    return metric.objectType
  }

  private func buildSummary(ids: [String], completion: @escaping (String) -> Void) {
    let calendar = DeviceToolsSupport.isoCalendar()
    let now = Date()
    let startOfToday = calendar.startOfDay(for: now)
    // Last night: yesterday 18:00 → today noon (not yesterday 06:00).
    let lastNightStart = calendar.date(byAdding: .hour, value: -6, to: startOfToday) ?? startOfToday
    let lastNightEnd = calendar.date(byAdding: .hour, value: 12, to: startOfToday) ?? now
    let workoutLookback = calendar.date(byAdding: .day, value: -14, to: now) ?? now
    let updatedAt = DeviceToolsSupport.formatDateTime(now)
    let selected = Set(ids)

    let group = DispatchGroup()
    var metrics: [String: Any] = [:]
    let lock = NSLock()

    func put(_ key: String, _ value: [String: Any]) {
      lock.lock()
      metrics[key] = value
      lock.unlock()
    }

    if selected.contains(HealthMetric.steps.rawValue),
       let type = HKQuantityType.quantityType(forIdentifier: .stepCount) {
      group.enter()
      querySum(type: type, unit: .count(), start: startOfToday, end: now) { metric in
        put("steps", metric)
        group.leave()
      }
    }
    if selected.contains(HealthMetric.daylight.rawValue) {
      group.enter()
      queryDaylight(start: startOfToday, end: now) { metric in
        put("time_in_daylight_minutes", metric)
        group.leave()
      }
    }
    if selected.contains(HealthMetric.activeEnergy.rawValue),
       let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
      group.enter()
      querySum(type: type, unit: .kilocalorie(), start: startOfToday, end: now) { metric in
        put("active_energy_kcal", metric)
        group.leave()
      }
    }
    if selected.contains(HealthMetric.exerciseMinutes.rawValue),
       let type = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
      group.enter()
      querySum(type: type, unit: .minute(), start: startOfToday, end: now) { metric in
        put("exercise_minutes", metric)
        group.leave()
      }
    }
    if selected.contains(HealthMetric.standTime.rawValue),
       let type = HKQuantityType.quantityType(forIdentifier: .appleStandTime) {
      group.enter()
      querySum(type: type, unit: .minute(), start: startOfToday, end: now) { metric in
        put("stand_minutes", metric)
        group.leave()
      }
    }
    if selected.contains(HealthMetric.distance.rawValue),
       let type = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
      group.enter()
      querySum(type: type, unit: .meter(), start: startOfToday, end: now) { metric in
        put("walking_running_distance_m", metric)
        group.leave()
      }
    }
    if selected.contains(HealthMetric.workouts.rawValue) {
      group.enter()
      queryWorkouts(start: workoutLookback, end: now, limit: 5) { metric in
        put("workouts", metric)
        group.leave()
      }
    }
    if selected.contains(HealthMetric.sleep.rawValue) {
      group.enter()
      querySleep(start: lastNightStart, end: lastNightEnd) { metric in
        put("sleep_last_night", metric)
        group.leave()
      }
    }
    if selected.contains(HealthMetric.mindfulness.rawValue) {
      group.enter()
      queryMindfulness(start: startOfToday, end: now) { metric in
        put("mindfulness", metric)
        group.leave()
      }
    }
    if selected.contains(HealthMetric.heartRate.rawValue) {
      group.enter()
      queryLatestHeartRate { metric in
        put("heart_rate", metric)
        group.leave()
      }
    }
    if selected.contains(HealthMetric.restingHeartRate.rawValue) {
      group.enter()
      queryLatestQuantity(
        identifier: .restingHeartRate,
        unit: HKUnit.count().unitDivided(by: .minute()),
        valueKey: "bpm"
      ) { metric in
        put("resting_heart_rate", metric)
        group.leave()
      }
    }
    if selected.contains(HealthMetric.bloodOxygen.rawValue) {
      group.enter()
      queryLatestQuantity(
        identifier: .oxygenSaturation,
        unit: .percent(),
        valueKey: "percent",
        scale: 100
      ) { metric in
        put("blood_oxygen", metric)
        group.leave()
      }
    }
    if selected.contains(HealthMetric.dietaryEnergy.rawValue),
       let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
      group.enter()
      querySum(type: type, unit: .kilocalorie(), start: startOfToday, end: now) { metric in
        put("dietary_energy_kcal", metric)
        group.leave()
      }
    }
    if selected.contains(HealthMetric.water.rawValue),
       let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) {
      group.enter()
      querySum(
        type: type,
        unit: HKUnit.literUnit(with: .milli),
        start: startOfToday,
        end: now
      ) { metric in
        put("water_ml", metric)
        group.leave()
      }
    }
    if selected.contains(HealthMetric.weight.rawValue) {
      group.enter()
      queryLatestQuantity(
        identifier: .bodyMass,
        unit: .gramUnit(with: .kilo),
        valueKey: "kg"
      ) { metric in
        put("body_weight_kg", metric)
        group.leave()
      }
    }
    if selected.contains(HealthMetric.bmi.rawValue) {
      group.enter()
      queryLatestQuantity(
        identifier: .bodyMassIndex,
        unit: .count(),
        valueKey: "value"
      ) { metric in
        put("bmi", metric)
        group.leave()
      }
    }
    if selected.contains(HealthMetric.bloodGlucose.rawValue) {
      group.enter()
      queryLatestQuantity(
        identifier: .bloodGlucose,
        unit: HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.literUnit(with: .deci)),
        valueKey: "mg_dl"
      ) { metric in
        put("blood_glucose_mg_dl", metric)
        group.leave()
      }
    }

    group.notify(queue: .global(qos: .userInitiated)) {
      lock.lock()
      let snapshot = metrics
      lock.unlock()
      var payload: [String: Any] = [
        "updated_at": updatedAt,
        "interval": [
          "start": DeviceToolsSupport.formatDateTime(startOfToday),
          "end": DeviceToolsSupport.formatDateTime(now),
        ],
      ]
      for (key, value) in snapshot {
        payload[key] = value
      }
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

  private func queryDaylight(start: Date, end: Date, completion: @escaping ([String: Any]) -> Void) {
    if #available(iOS 17.0, *) {
      guard let type = HKQuantityType.quantityType(forIdentifier: .timeInDaylight) else {
        completion(Self.unavailable(start, end))
        return
      }
      querySum(type: type, unit: .minute(), start: start, end: end, completion: completion)
      return
    }
    completion(Self.unavailable(start, end))
  }

  private func querySleep(start: Date, end: Date, completion: @escaping ([String: Any]) -> Void) {
    guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
      completion(Self.unavailable(start, end))
      return
    }
    // Default options: samples that overlap the window, not only those that start in it.
    let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
    let query = HKSampleQuery(
      sampleType: sleepType,
      predicate: predicate,
      limit: HKObjectQueryNoLimit,
      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
    ) { _, samples, _ in
      let categorySamples = samples as? [HKCategorySample] ?? []
      guard let asleep = Self.mergedAsleepInterval(
        categorySamples,
        windowStart: start,
        windowEnd: end
      ) else {
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

  private func queryMindfulness(start: Date, end: Date, completion: @escaping ([String: Any]) -> Void) {
    guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
      completion(Self.unavailable(start, end))
      return
    }
    let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
    let query = HKSampleQuery(
      sampleType: type,
      predicate: predicate,
      limit: HKObjectQueryNoLimit,
      sortDescriptors: nil
    ) { _, samples, _ in
      let categorySamples = samples as? [HKCategorySample] ?? []
      let duration = categorySamples.reduce(0.0) { partial, sample in
        let clippedStart = max(sample.startDate, start)
        let clippedEnd = min(sample.endDate, end)
        guard clippedStart < clippedEnd else { return partial }
        return partial + clippedEnd.timeIntervalSince(clippedStart)
      }
      guard duration > 0 else {
        completion(Self.unavailable(start, end))
        return
      }
      var metric = Self.interval(start, end)
      metric["status"] = "ok"
      metric["duration_minutes"] = Int((duration / 60).rounded())
      completion(metric)
    }
    store.execute(query)
  }

  private func queryLatestHeartRate(completion: @escaping ([String: Any]) -> Void) {
    queryLatestQuantity(
      identifier: .heartRate,
      unit: HKUnit.count().unitDivided(by: .minute()),
      valueKey: "bpm",
      completion: completion
    )
  }

  private func queryLatestQuantity(
    identifier: HKQuantityTypeIdentifier,
    unit: HKUnit,
    valueKey: String,
    scale: Double = 1,
    completion: @escaping ([String: Any]) -> Void
  ) {
    guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
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
      let raw = sample.quantity.doubleValue(for: unit) * scale
      completion([
        "status": "ok",
        valueKey: (raw * 10).rounded() / 10,
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

  /// Clips asleep samples to the query window, then unions overlaps so Watch
  /// + third-party sources are not double-counted.
  private static func mergedAsleepInterval(
    _ samples: [HKCategorySample],
    windowStart: Date,
    windowEnd: Date
  ) -> (duration: TimeInterval, start: Date, end: Date)? {
    var intervals: [(start: Date, end: Date)] = []
    for sample in samples where isAsleep(sample) {
      let clippedStart = max(sample.startDate, windowStart)
      let clippedEnd = min(sample.endDate, windowEnd)
      guard clippedStart < clippedEnd else { continue }
      intervals.append((clippedStart, clippedEnd))
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

private enum HealthMetric: String, CaseIterable {
  case steps = "steps"
  case daylight = "daylight"
  case activeEnergy = "active_energy"
  case exerciseMinutes = "exercise_minutes"
  case standTime = "stand_time"
  case distance = "distance"
  case workouts = "workouts"
  case sleep = "sleep"
  case mindfulness = "mindfulness"
  case heartRate = "heart_rate"
  case restingHeartRate = "resting_heart_rate"
  case bloodOxygen = "blood_oxygen"
  case dietaryEnergy = "dietary_energy"
  case water = "water"
  case weight = "weight"
  case bmi = "bmi"
  case bloodGlucose = "blood_glucose"

  var objectType: HKObjectType? {
    switch self {
    case .steps:
      return HKObjectType.quantityType(forIdentifier: .stepCount)
    case .daylight:
      if #available(iOS 17.0, *) {
        return HKObjectType.quantityType(forIdentifier: .timeInDaylight)
      }
      return nil
    case .activeEnergy:
      return HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
    case .exerciseMinutes:
      return HKObjectType.quantityType(forIdentifier: .appleExerciseTime)
    case .standTime:
      return HKObjectType.quantityType(forIdentifier: .appleStandTime)
    case .distance:
      return HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
    case .workouts:
      return HKObjectType.workoutType()
    case .sleep:
      return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
    case .mindfulness:
      return HKObjectType.categoryType(forIdentifier: .mindfulSession)
    case .heartRate:
      return HKObjectType.quantityType(forIdentifier: .heartRate)
    case .restingHeartRate:
      return HKObjectType.quantityType(forIdentifier: .restingHeartRate)
    case .bloodOxygen:
      return HKObjectType.quantityType(forIdentifier: .oxygenSaturation)
    case .dietaryEnergy:
      return HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)
    case .water:
      return HKObjectType.quantityType(forIdentifier: .dietaryWater)
    case .weight:
      return HKObjectType.quantityType(forIdentifier: .bodyMass)
    case .bmi:
      return HKObjectType.quantityType(forIdentifier: .bodyMassIndex)
    case .bloodGlucose:
      return HKObjectType.quantityType(forIdentifier: .bloodGlucose)
    }
    }
}
