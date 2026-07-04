import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

@main
struct GenerationActivityExtensionBundle: WidgetBundle {
  var body: some Widget {
    CuplivoGenerationActivityWidget()
  }
}

struct CuplivoGenerationActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: CuplivoGenerationActivityAttributes.self) { context in
      LockScreenLiveActivityView(context: context)
        .activityBackgroundTint(Color(.systemBackground))
        .activitySystemActionForegroundColor(.primary)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(
            context.state.displayTitle,
            systemImage: activitySymbolName(isFinished: context.state.isFinished)
          )
            .font(.caption)
            .fontWeight(.semibold)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.leading, 10)
        }
        DynamicIslandExpandedRegion(.trailing) {
          ActivityElapsedText(context: context)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 10)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(spacing: 0) {
            Spacer(minLength: 10)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Text(context.state.detail)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
              if !context.state.tokenLabel.isEmpty {
                Text(context.state.tokenLabel)
                  .font(.caption2)
                  .fontWeight(.semibold)
                  .monospacedDigit()
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                  .minimumScaleFactor(0.72)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
          .padding(.horizontal, 10)
          .padding(.bottom, 1)
        }
      } compactLeading: {
        Image(systemName: "sparkles")
      } compactTrailing: {
        if context.state.isFinished {
          Image(systemName: "checkmark")
            .font(.caption2)
            .fontWeight(.semibold)
        } else {
          ActivityElapsedText(context: context)
        }
      } minimal: {
        Image(systemName: activitySymbolName(isFinished: context.state.isFinished))
      }
    }
  }
}

private struct LockScreenLiveActivityView: View {
  let context: ActivityViewContext<CuplivoGenerationActivityAttributes>

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      ZStack {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(Color.accentColor.opacity(0.16))
        Image(systemName: activitySymbolName(isFinished: context.state.isFinished))
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(Color.accentColor)
      }
      .frame(width: 34, height: 34)

      VStack(alignment: .leading, spacing: 4) {
        Text(context.state.displayTitle)
          .font(.subheadline)
          .fontWeight(.semibold)
          .lineLimit(1)
          .minimumScaleFactor(0.82)

        Text(context.state.detail)
          .font(.caption)
          .lineLimit(1)
          .minimumScaleFactor(0.82)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      VStack(alignment: .trailing, spacing: 4) {
        ActivityElapsedText(context: context)

        if !context.state.tokenLabel.isEmpty {
          Text(context.state.tokenLabel)
            .font(.caption2)
            .fontWeight(.semibold)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
              Capsule(style: .continuous)
                .fill(Color.secondary.opacity(0.12))
            )
        }
      }
      .frame(minWidth: 62, alignment: .trailing)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
  }
}

private struct ActivityElapsedText: View {
  let context: ActivityViewContext<CuplivoGenerationActivityAttributes>

  var body: some View {
    Text(elapsedText(seconds: context.state.elapsedSeconds))
      .font(.caption2)
      .fontWeight(.semibold)
      .monospacedDigit()
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .minimumScaleFactor(0.72)
  }
}

private func activitySymbolName(isFinished: Bool) -> String {
  isFinished ? "checkmark" : "sparkles"
}

private func elapsedText(seconds: Int) -> String {
  let totalSeconds = max(0, seconds)
  let hours = totalSeconds / 3600
  let minutes = (totalSeconds % 3600) / 60
  let seconds = totalSeconds % 60
  if hours > 0 {
    return String(format: "%d:%02d", hours, minutes)
  }
  return String(format: "%d:%02d", minutes, seconds)
}
