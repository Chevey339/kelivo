import Flutter
import UIKit
import XCTest
import HealthKit
import ActivityKit
import UserNotifications
import CoreLocation
@testable import Runner

private final class BackgroundTestMessenger: NSObject, FlutterBinaryMessenger {
  func send(onChannel channel: String, message: Data?) {}
  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) { callback?(nil) }
  func setMessageHandlerOnChannel(_ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler?) -> FlutterBinaryMessengerConnection { 0 }
  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}

class RunnerTests: XCTestCase {

  @MainActor
  func testNotificationCallbacksAreForwardedByTheApplicationDelegate() {
    XCTAssertTrue(UNUserNotificationCenter.current().delegate is AppDelegate)
  }

  func testBackgroundTaskUsesMillisecondsAndBoundsPresentationText() {
    let task = BackgroundGenerationTask([
      "id": "run", "conversationId": "chat", "startedAt": 1_700_000_000_000,
      "finishedAt": 1_700_000_060_000, "title": String(repeating: "a", count: 200),
      "detail": String(repeating: "b", count: 300), "tokens": 15,
    ])
    XCTAssertEqual(task.startedAt.timeIntervalSince1970, 1_700_000_000)
    XCTAssertEqual(task.finishedAt?.timeIntervalSince1970, 1_700_000_060)
    XCTAssertEqual(task.title.count, 120)
    XCTAssertEqual(task.detail.count, 180)
    XCTAssertEqual(task.conversationId, "chat")
  }

  @MainActor
  private func backgroundCall(_ handler: MobileBackgroundHandler, _ method: String,
                              _ args: Any? = nil) async -> Any? {
    await withCheckedContinuation { continuation in
      handler.handle(FlutterMethodCall(methodName: method, arguments: args)) { value in
        continuation.resume(returning: value)
      }
    }
  }

  @MainActor
  private func backgroundSnapshot(_ revision: Int, _ ids: [String], enabled: Bool = false, live: Bool = false) -> [String: Any] {
    ["revision": revision, "settings": ["iosEnabled": enabled, "liveActivitiesEnabled": live],
     "tasks": ids.map { ["id": $0, "conversationId": "chat-\($0)", "startedAt": 1_700_000_000_000] as [String: Any] }]
  }

  @MainActor
  func testBackgroundDefaultsDoNotAcquireResourcesOrAcceptOlderSnapshots() async {
    let handler = MobileBackgroundHandler()
    let first = await backgroundCall(handler, "sync", backgroundSnapshot(2, ["a", "b"])) as! [String: Any]
    XCTAssertEqual(first["activeTasks"] as? Int, 2)
    XCTAssertEqual(first["backgroundTaskActive"] as? Bool, false)
    XCTAssertEqual(first["locationActive"] as? Bool, false)
    XCTAssertEqual(first["silentAudioActive"] as? Bool, false)
    XCTAssertEqual(first["liveActivityActive"] as? Bool, false)
    let stale = await backgroundCall(handler, "sync", backgroundSnapshot(1, ["old"], enabled: true)) as! [String: Any]
    XCTAssertEqual(stale["activeTasks"] as? Int, 2)
    XCTAssertEqual(stale["backgroundTaskActive"] as? Bool, false)
    _ = await backgroundCall(handler, "sync", backgroundSnapshot(3, []))
    handler.prepareForTermination()
  }

  @MainActor
  func testBackgroundAssertionLivesUntilLastTaskAndStopsWhenDisabled() async {
    let handler = MobileBackgroundHandler()
    let started = await backgroundCall(handler, "sync", backgroundSnapshot(1, ["a", "b"], enabled: true)) as! [String: Any]
    XCTAssertEqual(started["backgroundTaskActive"] as? Bool, true)
    let one = await backgroundCall(handler, "sync", backgroundSnapshot(2, ["b"], enabled: true)) as! [String: Any]
    XCTAssertEqual(one["activeTasks"] as? Int, 1)
    XCTAssertEqual(one["backgroundTaskActive"] as? Bool, true)
    let disabled = await backgroundCall(handler, "sync", backgroundSnapshot(3, ["b"])) as! [String: Any]
    XCTAssertEqual(disabled["backgroundTaskActive"] as? Bool, false)
    let ended = await backgroundCall(handler, "sync", backgroundSnapshot(4, [], enabled: true)) as! [String: Any]
    XCTAssertEqual(ended["backgroundTaskActive"] as? Bool, false)
    handler.prepareForTermination()
  }

  @MainActor
  func testConcurrentTerminalAndRetrySnapshotsKeepTheNewerRun() async {
    let handler = MobileBackgroundHandler()
    let drained = expectation(description: "serial snapshots drained")
    handler.handle(FlutterMethodCall(methodName: "sync", arguments: backgroundSnapshot(1, ["old"]))) { _ in }
    handler.handle(FlutterMethodCall(methodName: "sync", arguments: backgroundSnapshot(3, ["retry"]))) { _ in }
    handler.handle(FlutterMethodCall(methodName: "sync", arguments: backgroundSnapshot(2, []))) { value in
      XCTAssertEqual((value as? [String: Any])?["activeTasks"] as? Int, 1)
      drained.fulfill()
    }
    await fulfillment(of: [drained], timeout: 5)
    _ = await backgroundCall(handler, "sync", backgroundSnapshot(4, []))
    handler.prepareForTermination()
  }

  @MainActor
  func testNarrationBufferingLeaseIsIndependentAndReleasedOnPause() async {
    let handler = MobileBackgroundHandler()
    _ = await backgroundCall(handler, "sync", ["revision": 1, "tasks": [], "settings": ["backgroundSpeechEnabled": true]])
    _ = await backgroundCall(handler, "audioOwner", ["owner": "speechBuffering", "active": true])
    let buffering = await backgroundCall(handler, "getStatus") as! [String: Any]
    XCTAssertEqual(buffering["backgroundTaskActive"] as? Bool, true)
    XCTAssertEqual(buffering["silentAudioActive"] as? Bool, false)
    _ = await backgroundCall(handler, "audioOwner", ["owner": "speechBuffering", "active": false])
    let paused = await backgroundCall(handler, "getStatus") as! [String: Any]
    XCTAssertEqual(paused["backgroundTaskActive"] as? Bool, false)
    handler.prepareForTermination()
  }

  @MainActor
  func testNarrationTakesOverGenerationResourcesUntilPause() async throws {
    let authorization = CLLocationManager().authorizationStatus
    guard authorization == .authorizedAlways || authorization == .authorizedWhenInUse else {
      throw XCTSkip("Requires existing location authorization; this test never requests permission")
    }
    let handler = MobileBackgroundHandler()
    handler.configure(messenger: BackgroundTestMessenger())
    defer { handler.prepareForTermination() }
    let settings: [String: Any] = ["iosEnabled": true, "backgroundSpeechEnabled": true, "locationEnabled": true]
    var snapshot = backgroundSnapshot(1, ["generation"])
    snapshot["settings"] = settings
    _ = await backgroundCall(handler, "sync", snapshot)
    NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    await Task.yield()
    let generating = await backgroundCall(handler, "getStatus") as! [String: Any]
    XCTAssertEqual(generating["backgroundTaskActive"] as? Bool, true)
    XCTAssertEqual(generating["locationActive"] as? Bool, true)
    _ = await backgroundCall(handler, "audioOwner", ["owner": "speechBuffering", "active": true])
    let narration = await backgroundCall(handler, "sync", ["revision": 2, "tasks": [], "settings": settings]) as! [String: Any]
    XCTAssertEqual(narration["activeTasks"] as? Int, 0)
    XCTAssertEqual(narration["backgroundTaskActive"] as? Bool, true)
    XCTAssertEqual(narration["locationActive"] as? Bool, true)
    XCTAssertEqual(narration["silentAudioActive"] as? Bool, false)
    _ = await backgroundCall(handler, "audioOwner", ["owner": "speechBuffering", "active": false])
    let paused = await backgroundCall(handler, "getStatus") as! [String: Any]
    XCTAssertEqual(paused["backgroundTaskActive"] as? Bool, false)
    XCTAssertEqual(paused["locationActive"] as? Bool, false)
  }

  @MainActor
  func testActivityConversationLinkIsBufferedForColdStartAndConsumedOnce() async {
    let handler = MobileBackgroundHandler()
    XCTAssertFalse(handler.receive(URL(string: "kelivo://unrelated/chat")!))
    XCTAssertTrue(handler.receive(URL(string: "kelivo://conversation/chat-123")!))
    let pending = await backgroundCall(handler, "takePendingConversation")
    XCTAssertEqual(pending as? String, "chat-123")
    let again = await backgroundCall(handler, "takePendingConversation")
    XCTAssertNil(again)
    handler.prepareForTermination()
  }

  @MainActor
  func testLiveActivityCreationCompletionAndRetryAreSerialized() async throws {
    guard #available(iOS 16.2, *), MobileBackgroundHandler.liveActivitiesSupported,
          ActivityAuthorizationInfo().areActivitiesEnabled else {
      throw XCTSkip("ActivityKit is not authorized on this test device")
    }
    let handler = MobileBackgroundHandler()
    let drained = expectation(description: "ActivityKit operations completed")
    handler.handle(FlutterMethodCall(methodName: "sync", arguments: backgroundSnapshot(1, ["old"], live: true))) { value in
      XCTAssertEqual((value as? [String: Any])?["liveActivityActive"] as? Bool, true,
                     "\(String(describing: value))")
    }
    handler.handle(FlutterMethodCall(methodName: "sync", arguments: backgroundSnapshot(2, [], live: true))) { value in
      XCTAssertEqual((value as? [String: Any])?["liveActivityActive"] as? Bool, false)
    }
    handler.handle(FlutterMethodCall(methodName: "sync", arguments: backgroundSnapshot(3, ["retry", "second"], live: true))) { value in
      XCTAssertEqual((value as? [String: Any])?["activeTasks"] as? Int, 2)
      XCTAssertEqual((value as? [String: Any])?["liveActivityActive"] as? Bool, true,
                     "\(String(describing: value))")
      drained.fulfill()
    }
    await fulfillment(of: [drained], timeout: 10)
    let one = await backgroundCall(handler, "sync", backgroundSnapshot(4, ["second"], live: true)) as! [String: Any]
    XCTAssertEqual(one["liveActivityActive"] as? Bool, true)
    _ = await backgroundCall(handler, "sync", backgroundSnapshot(5, []))
    XCTAssertFalse(Activity<KelivoGenerationActivityAttributes>.activities.contains { $0.activityState == .active })
    handler.prepareForTermination()
  }

  @MainActor
  func testOrphanedLiveActivitiesAreEndedWhenRuntimeStartsDisabled() async throws {
    guard #available(iOS 16.2, *), MobileBackgroundHandler.liveActivitiesSupported,
          ActivityAuthorizationInfo().areActivitiesEnabled else {
      throw XCTSkip("ActivityKit is not authorized on this test device")
    }
    let state = KelivoGenerationActivityAttributes.ContentState(
      displayTitle: "Orphan", detail: "Generating", tokenCount: 0, startedAt: Date(),
      finishedAt: nil, activeTaskCount: 1, conversationId: "orphan", outcome: "", staleMessage: "Stale")
    let orphan = try Activity.request(attributes: KelivoGenerationActivityAttributes(groupId: UUID().uuidString),
      content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(60)), pushType: nil)
    let handler = MobileBackgroundHandler()
    _ = await backgroundCall(handler, "sync", backgroundSnapshot(1, []))
    XCTAssertTrue(orphan.activityState == .ended || orphan.activityState == .dismissed)
    handler.prepareForTermination()
  }

  @MainActor
  func testSystemEndedActivityDoesNotReappearUntilANewRunStarts() async throws {
    guard #available(iOS 16.2, *), MobileBackgroundHandler.liveActivitiesSupported,
          ActivityAuthorizationInfo().areActivitiesEnabled else {
      throw XCTSkip("ActivityKit is not authorized on this test device")
    }
    let handler = MobileBackgroundHandler()
    _ = await backgroundCall(handler, "sync", backgroundSnapshot(1, ["removed"], live: true))
    let activity = try XCTUnwrap(Activity<KelivoGenerationActivityAttributes>.activities.first {
      $0.content.state.conversationId == "chat-removed"
    })
    await activity.end(nil, dismissalPolicy: .immediate)
    let removed = await backgroundCall(handler, "sync", backgroundSnapshot(2, ["removed"], live: true)) as! [String: Any]
    XCTAssertEqual(removed["liveActivityActive"] as? Bool, false)
    let next = await backgroundCall(handler, "sync", backgroundSnapshot(3, ["new"], live: true)) as! [String: Any]
    XCTAssertEqual(next["liveActivityActive"] as? Bool, true)
    _ = await backgroundCall(handler, "sync", backgroundSnapshot(4, []))
    handler.prepareForTermination()
  }

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
