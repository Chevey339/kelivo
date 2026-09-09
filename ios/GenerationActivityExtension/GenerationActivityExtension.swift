import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

@main
struct GenerationActivityBundle: WidgetBundle {
  var body: some Widget { GenerationActivityWidget() }
}

struct GenerationActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: KelivoGenerationActivityAttributes.self) { context in
      HStack(spacing: 12) {
        Image(systemName: symbol(context.state, stale: activityIsStale(context)))
          .font(.title2).foregroundStyle(activityIsStale(context) ? .orange : .blue)
        VStack(alignment: .leading, spacing: 4) {
          Text(context.state.displayTitle).font(.headline).lineLimit(1)
          Text(activityIsStale(context) ? context.state.staleMessage : context.state.detail)
            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
          if context.state.tokenCount > 0 {
            Text("\(context.state.tokenCount) tokens").font(.caption2).foregroundStyle(.secondary)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Spacer(minLength: 4)
        GenerationElapsedTime(state: context.state).font(.caption.monospacedDigit())
          .frame(width: 64, alignment: .trailing)
      }
      .padding(16)
      .widgetURL(conversationURL(context.state.conversationId))
      .activityBackgroundTint(Color(.secondarySystemBackground))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: symbol(context.state, stale: activityIsStale(context))).foregroundStyle(.blue)
            .font(.title3)
        }
        DynamicIslandExpandedRegion(.trailing) {
          GenerationElapsedTime(state: context.state).font(.caption.monospacedDigit())
            .frame(width: 64, alignment: .trailing)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 4) {
            Text(context.state.displayTitle).font(.headline).lineLimit(1)
            Text(activityIsStale(context) ? context.state.staleMessage : context.state.detail)
              .font(.caption).foregroundStyle(.secondary).lineLimit(2)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.top, 6)
          .padding(.horizontal, 4)
          .padding(.bottom, 10)
        }
      } compactLeading: {
        Image(systemName: symbol(context.state, stale: activityIsStale(context))).foregroundStyle(.blue)
      } compactTrailing: {
        if context.state.activeTaskCount > 1 {
          Text("\(context.state.activeTaskCount)").monospacedDigit()
        } else {
          GenerationElapsedTime(state: context.state).font(.caption2.monospacedDigit())
            .frame(width: 48, alignment: .trailing)
        }
      } minimal: {
        Image(systemName: symbol(context.state, stale: activityIsStale(context))).foregroundStyle(.blue)
      }
      .widgetURL(conversationURL(context.state.conversationId))
      .keylineTint(.blue)
      .contentMargins(.horizontal, 20, for: .expanded)
    }
  }
}

private func symbol(_ state: KelivoGenerationActivityAttributes.ContentState, stale: Bool) -> String {
  if stale { return "exclamationmark.circle" }
  switch state.outcome {
  case "completed": return "checkmark.circle.fill"
  case "failed", "interrupted": return "exclamationmark.circle.fill"
  case "cancelled": return "stop.circle"
  default: return "sparkles"
  }
}

private func conversationURL(_ id: String) -> URL? {
  var components = URLComponents()
  components.scheme = "kelivo"
  components.host = "conversation"
  components.path = "/\(id)"
  return components.url
}

private struct GenerationElapsedTime: View {
  let state: KelivoGenerationActivityAttributes.ContentState

  var body: some View {
    Group {
      if let end = state.finishedAt {
        let seconds = max(0, Int(end.timeIntervalSince(state.startedAt)))
        Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
      } else {
        // WidgetKit owns the timer; no per-second ActivityKit updates.
        Text(timerInterval: state.startedAt...state.startedAt.addingTimeInterval(8 * 3600), countsDown: false)
      }
    }
    // Timer Text fills the offered width; frame alignment alone aligns its
    // container, leaving the changing digits at the leading edge.
    .multilineTextAlignment(.trailing)
    .lineLimit(1)
    .minimumScaleFactor(0.8)
    .frame(maxWidth: .infinity, alignment: .trailing)
  }
}

private func activityIsStale(_ context: ActivityViewContext<KelivoGenerationActivityAttributes>) -> Bool {
  if #available(iOS 16.2, *) { return context.isStale }
  return false
}
