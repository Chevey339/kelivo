import Flutter
import UIKit
import XCTest
import HealthKit
@testable import Runner

class RunnerTests: XCTestCase {

  private let start = Date(timeIntervalSince1970: 1_700_000_000)
  private let end = Date(timeIntervalSince1970: 1_700_086_400)

  private func sample(_ flow: Int, cycleStart: Bool = false) -> HKCategorySample {
    let metadata = [HKMetadataKeyMenstrualCycleStart: cycleStart]
    return HKCategorySample(
      type: HKObjectType.categoryType(forIdentifier: .menstrualFlow)!,
      value: flow, start: start, end: end, metadata: metadata
    )
  }

  func testMissingMenstrualDataIsNotNoFlow() {
    let missing = HealthToolHandler.menstrualFlowSummary([], start: start, end: end)
    XCTAssertEqual(missing["status"] as? String, "unavailable")
    XCTAssertEqual((missing["records"] as? [[String: Any]])?.count, 0)
    let noFlow = HealthToolHandler.menstrualFlowSummary([sample(5)], start: start, end: end)
    XCTAssertEqual(noFlow["status"] as? String, "ok")
    XCTAssertEqual((noFlow["records"] as? [[String: Any]])?.first?["flow"] as? String, "none")
  }

  func testMenstrualRecordsPreserveFlowDatesAndCycleMarkers() {
    let samples = [sample(1, cycleStart: true), sample(2, cycleStart: false),
                   sample(3), sample(4), sample(5)]
    let summary = HealthToolHandler.menstrualFlowSummary(
      samples, start: start.addingTimeInterval(3600), end: end
    )
    let records = summary["records"] as! [[String: Any]]
    XCTAssertEqual(records.compactMap { $0["flow"] as? String },
                   ["unspecified", "light", "medium", "heavy", "none"])
    XCTAssertEqual(records[0]["start"] as? String, DeviceToolsSupport.formatDateTime(start))
    XCTAssertEqual(records[0]["end"] as? String, DeviceToolsSupport.formatDateTime(end))
    XCTAssertEqual(records[0]["is_cycle_start"] as? Bool, true)
    XCTAssertEqual(records[1]["is_cycle_start"] as? Bool, false)
    XCTAssertEqual(records[2]["is_cycle_start"] as? Bool, false)
    XCTAssertEqual(summary["truncated"] as? Bool, false)
  }

  func testMenstrualRecordLimitReportsOmittedRecords() {
    let samples = Array(repeating: sample(2), count: 181)
    let summary = HealthToolHandler.menstrualFlowSummary(samples, start: start, end: end)
    XCTAssertEqual((summary["records"] as? [[String: Any]])?.count, 180)
    XCTAssertEqual(summary["truncated"] as? Bool, true)
    let exactLimit = HealthToolHandler.menstrualFlowSummary(Array(samples.prefix(180)), start: start, end: end)
    XCTAssertEqual(exactLimit["truncated"] as? Bool, false)
  }

  private func sleepSample(_ value: Int, from: Double, to: Double) -> HKCategorySample {
    HKCategorySample(
      type: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!, value: value,
      start: start.addingTimeInterval(from * 60), end: start.addingTimeInterval(to * 60)
    )
  }

  func testInBedOnlyReturnsRecordedTimeWithoutInventingSleep() {
    let summary = HealthToolHandler.sleepSummary(
      [sleepSample(0, from: 0, to: 420)], start: start, end: end
    )
    XCTAssertEqual(summary["status"] as? String, "ok")
    let bed = summary["in_bed"] as! [String: Any]
    XCTAssertEqual(bed["duration_minutes"] as? Int, 420)
    let asleep = summary["asleep"] as! [String: Any]
    XCTAssertEqual(asleep["status"] as? String, "unavailable")
    XCTAssertNil(asleep["duration_minutes"])
    XCTAssertEqual((summary["awake"] as? [String: Any])?["status"] as? String, "unavailable")
  }

  func testSleepStagesAndDaytimeNapAreSeparateAndDeduplicated() throws {
    guard #available(iOS 16.0, *) else { throw XCTSkip("Sleep stages require iOS 16") }
    // Bed, awake, core, deep, REM, and unspecified sleep, including two sources
    // covering the same sleep and a separate daytime nap.
    let samples = [
      sleepSample(0, from: 0, to: 480), sleepSample(2, from: 0, to: 30),
      sleepSample(3, from: 30, to: 180), sleepSample(3, from: 60, to: 180),
      sleepSample(4, from: 180, to: 240), sleepSample(5, from: 240, to: 300),
      sleepSample(1, from: 30, to: 360), sleepSample(3, from: 900, to: 930),
    ]
    let summary = HealthToolHandler.sleepSummary(samples, start: start, end: end)
    let asleep = summary["asleep"] as! [String: Any]
    XCTAssertEqual(asleep["duration_minutes"] as? Int, 360)
    XCTAssertEqual((asleep["intervals"] as? [[String: Any]])?.count, 2)
    XCTAssertEqual((summary["in_bed"] as? [String: Any])?["duration_minutes"] as? Int, 480)
    XCTAssertEqual((summary["awake"] as? [String: Any])?["duration_minutes"] as? Int, 30)
    let stages = summary["stages"] as! [String: [String: Any]]
    XCTAssertEqual(stages["unspecified"]?["duration_minutes"] as? Int, 330)
    if #available(iOS 16.0, *) {
      XCTAssertEqual(stages["core"]?["duration_minutes"] as? Int, 180)
      XCTAssertEqual(stages["deep"]?["duration_minutes"] as? Int, 60)
      XCTAssertEqual(stages["rem"]?["duration_minutes"] as? Int, 60)
    }
    XCTAssertTrue(JSONSerialization.isValidJSONObject(summary))
  }

  func testSleepClipsOverlappingSamplesToWindowAndKeepsGaps() {
    let windowEnd = start.addingTimeInterval(120 * 60)
    let samples = [
      sleepSample(1, from: -120, to: -60), sleepSample(1, from: -30, to: 30),
      sleepSample(1, from: 10, to: 60), sleepSample(1, from: 90, to: 150),
      sleepSample(1, from: 150, to: 180),
    ]
    let summary = HealthToolHandler.sleepSummary(samples, start: start, end: windowEnd)
    let asleep = summary["asleep"] as! [String: Any]
    XCTAssertEqual(asleep["duration_minutes"] as? Int, 90)
    let intervals = asleep["intervals"] as! [[String: String]]
    XCTAssertEqual(intervals.count, 2)
    XCTAssertEqual(intervals[0]["start"], DeviceToolsSupport.formatDateTime(start))
    XCTAssertEqual(intervals[0]["end"], DeviceToolsSupport.formatDateTime(start.addingTimeInterval(3600)))
    XCTAssertEqual(intervals[1]["end"], DeviceToolsSupport.formatDateTime(windowEnd))
  }

  func testMissingSleepAndAwakeOnlyDoNotImplyZeroSleep() {
    let missing = HealthToolHandler.sleepSummary([], start: start, end: end)
    XCTAssertEqual(missing["status"] as? String, "unavailable")
    let awakeOnly = HealthToolHandler.sleepSummary(
      [sleepSample(2, from: 30, to: 45)], start: start, end: end
    )
    XCTAssertEqual(awakeOnly["status"] as? String, "ok")
    XCTAssertEqual((awakeOnly["awake"] as? [String: Any])?["duration_minutes"] as? Int, 15)
    let asleep = awakeOnly["asleep"] as! [String: Any]
    XCTAssertEqual(asleep["status"] as? String, "unavailable")
    XCTAssertNil(asleep["duration_minutes"])
  }

}
