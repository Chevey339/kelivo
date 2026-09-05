/// HealthKit metric IDs stored per collaborator and sent to iOS.
///
/// Values must match MethodChannel / Swift identifiers. New sensitive types
/// default OFF; [defaultSelected] is the original six-metric summary.
enum HealthDataCategory { activity, rest, heart, body, reproductive }

enum HealthDataType {
  steps,
  daylight,
  activeEnergy,
  exerciseMinutes,
  standTime,
  distance,
  workouts,
  sleep,
  mindfulness,
  heartRate,
  restingHeartRate,
  bloodOxygen,
  dietaryEnergy,
  water,
  weight,
  bmi,
  bloodGlucose,
  menstrualFlow,
}

abstract final class HealthDataTypeIds {
  HealthDataTypeIds._();

  static const String steps = 'steps';
  static const String daylight = 'daylight';
  static const String activeEnergy = 'active_energy';
  static const String exerciseMinutes = 'exercise_minutes';
  static const String standTime = 'stand_time';
  static const String distance = 'distance';
  static const String workouts = 'workouts';
  static const String sleep = 'sleep';
  static const String mindfulness = 'mindfulness';
  static const String heartRate = 'heart_rate';
  static const String restingHeartRate = 'resting_heart_rate';
  static const String bloodOxygen = 'blood_oxygen';
  static const String dietaryEnergy = 'dietary_energy';
  static const String water = 'water';
  static const String weight = 'weight';
  static const String bmi = 'bmi';
  static const String bloodGlucose = 'blood_glucose';
  static const String menstrualFlow = 'menstrual_flow';

  static const List<String> all = [
    steps,
    daylight,
    activeEnergy,
    exerciseMinutes,
    standTime,
    distance,
    workouts,
    sleep,
    mindfulness,
    heartRate,
    restingHeartRate,
    bloodOxygen,
    dietaryEnergy,
    water,
    weight,
    bmi,
    bloodGlucose,
    menstrualFlow,
  ];

  /// Types that existed in the original Health summary tool.
  static const List<String> defaultSelected = [
    steps,
    activeEnergy,
    distance,
    sleep,
    heartRate,
    workouts,
  ];

  /// Types that do not need a newer-than-deployment-target OS.
  /// `daylight` (time in daylight) requires iOS 17.
  static const List<String> withoutOsVersionGate = [
    steps,
    activeEnergy,
    exerciseMinutes,
    standTime,
    distance,
    workouts,
    sleep,
    mindfulness,
    heartRate,
    restingHeartRate,
    bloodOxygen,
    dietaryEnergy,
    water,
    weight,
    bmi,
    bloodGlucose,
    menstrualFlow,
  ];

  static const Set<String> known = {
    steps,
    daylight,
    activeEnergy,
    exerciseMinutes,
    standTime,
    distance,
    workouts,
    sleep,
    mindfulness,
    heartRate,
    restingHeartRate,
    bloodOxygen,
    dietaryEnergy,
    water,
    weight,
    bmi,
    bloodGlucose,
    menstrualFlow,
  };

  static HealthDataType? typeForId(String id) {
    return switch (id) {
      steps => HealthDataType.steps,
      daylight => HealthDataType.daylight,
      activeEnergy => HealthDataType.activeEnergy,
      exerciseMinutes => HealthDataType.exerciseMinutes,
      standTime => HealthDataType.standTime,
      distance => HealthDataType.distance,
      workouts => HealthDataType.workouts,
      sleep => HealthDataType.sleep,
      mindfulness => HealthDataType.mindfulness,
      heartRate => HealthDataType.heartRate,
      restingHeartRate => HealthDataType.restingHeartRate,
      bloodOxygen => HealthDataType.bloodOxygen,
      dietaryEnergy => HealthDataType.dietaryEnergy,
      water => HealthDataType.water,
      weight => HealthDataType.weight,
      bmi => HealthDataType.bmi,
      bloodGlucose => HealthDataType.bloodGlucose,
      menstrualFlow => HealthDataType.menstrualFlow,
      _ => null,
    };
  }

  static String idFor(HealthDataType type) {
    return switch (type) {
      HealthDataType.steps => steps,
      HealthDataType.daylight => daylight,
      HealthDataType.activeEnergy => activeEnergy,
      HealthDataType.exerciseMinutes => exerciseMinutes,
      HealthDataType.standTime => standTime,
      HealthDataType.distance => distance,
      HealthDataType.workouts => workouts,
      HealthDataType.sleep => sleep,
      HealthDataType.mindfulness => mindfulness,
      HealthDataType.heartRate => heartRate,
      HealthDataType.restingHeartRate => restingHeartRate,
      HealthDataType.bloodOxygen => bloodOxygen,
      HealthDataType.dietaryEnergy => dietaryEnergy,
      HealthDataType.water => water,
      HealthDataType.weight => weight,
      HealthDataType.bmi => bmi,
      HealthDataType.bloodGlucose => bloodGlucose,
      HealthDataType.menstrualFlow => menstrualFlow,
    };
  }

  static HealthDataCategory categoryFor(HealthDataType type) {
    return switch (type) {
      HealthDataType.steps ||
      HealthDataType.daylight ||
      HealthDataType.activeEnergy ||
      HealthDataType.exerciseMinutes ||
      HealthDataType.standTime ||
      HealthDataType.distance ||
      HealthDataType.workouts => HealthDataCategory.activity,
      HealthDataType.sleep ||
      HealthDataType.mindfulness => HealthDataCategory.rest,
      HealthDataType.heartRate ||
      HealthDataType.restingHeartRate ||
      HealthDataType.bloodOxygen => HealthDataCategory.heart,
      HealthDataType.dietaryEnergy ||
      HealthDataType.water ||
      HealthDataType.weight ||
      HealthDataType.bmi ||
      HealthDataType.bloodGlucose => HealthDataCategory.body,
      HealthDataType.menstrualFlow => HealthDataCategory.reproductive,
    };
  }

  static List<HealthDataType> typesIn(HealthDataCategory category) {
    return [
      for (final type in HealthDataType.values)
        if (categoryFor(type) == category) type,
    ];
  }

  /// English labels embedded in the tool description for the model.
  static String toolLabel(String id) {
    return switch (id) {
      steps => 'steps',
      daylight => 'time in daylight',
      activeEnergy => 'active energy',
      exerciseMinutes => 'exercise minutes',
      standTime => 'stand time',
      distance => 'walking/running distance',
      workouts => 'recent workouts',
      sleep =>
        'sleep, time in bed, awake periods and sleep stages over the past 24 hours',
      mindfulness => 'mindfulness/resting sessions',
      heartRate => 'latest heart rate',
      restingHeartRate => 'resting heart rate',
      bloodOxygen => 'blood oxygen',
      dietaryEnergy => 'dietary energy',
      water => 'water intake',
      weight => 'body weight',
      bmi => 'BMI',
      bloodGlucose => 'blood glucose',
      menstrualFlow => 'recorded menstrual flow',
      _ => id,
    };
  }

  static bool isKnown(String id) => known.contains(id);

  /// Missing / invalid JSON uses [defaultSelected]. An explicit empty list
  /// is preserved so the user can turn every type off.
  static List<String> parseStoredIds(Object? raw) {
    if (raw == null) {
      return List<String>.from(defaultSelected);
    }
    if (raw is! List) {
      return List<String>.from(defaultSelected);
    }
    final seen = <String>{};
    final out = <String>[];
    for (final item in raw) {
      if (item is String && isKnown(item) && seen.add(item)) {
        out.add(item);
      }
    }
    return out;
  }

  static List<String> knownOnly(Iterable<String> ids) {
    final seen = <String>{};
    final out = <String>[];
    for (final id in ids) {
      if (isKnown(id) && seen.add(id)) out.add(id);
    }
    return out;
  }

  static List<String> intersectAvailable(
    Iterable<String> ids,
    Iterable<String> available,
  ) {
    final allowed = available.toSet();
    return [
      for (final id in knownOnly(ids))
        if (allowed.contains(id)) id,
    ];
  }
}
