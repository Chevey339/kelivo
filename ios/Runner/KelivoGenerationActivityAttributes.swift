import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct CuplivoGenerationActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var displayTitle: String
    var detail: String
    var tokenCount: Int
    var tokenLabel: String
    var startedAt: Date
    var finishedAt: Date?
    var elapsedSeconds: Int
    var wavePhase: Int
    var isFinished: Bool
  }

  var title: String
}
