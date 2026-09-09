import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct KelivoGenerationActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var displayTitle: String
    var detail: String
    var tokenCount: Int
    var startedAt: Date
    var finishedAt: Date?
    var activeTaskCount: Int
    var conversationId: String
    var outcome: String
    var staleMessage: String
  }

  // Immutable attributes contain no conversation title or other private text.
  var groupId: String
}
