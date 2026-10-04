import SwiftUI
import ActivityKit
import WidgetKit

/// Live Activity «Скоро визит»: таймер до начала и до конца визита
struct SBVisitLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SBVisitAttributes.self) { context in
            lockScreen(context.state)
                .activityBackgroundTint(SBWidgetStyle.background)
                .activitySystemActionForegroundColor(SBWidgetStyle.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.client)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context.state)
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.procedure)
                            .font(.system(size: 13))
                            .lineLimit(1)
                        Text(rangeText(context.state))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "sparkles")
                    .foregroundStyle(SBWidgetStyle.accent)
            } compactTrailing: {
                countdown(context.state)
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "sparkles")
            }
        }
    }

    // MARK: Экран блокировки

    private func lockScreen(_ state: SBVisitAttributes.ContentState) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Скоро визит")
                    .font(.system(size: 12))
                    .foregroundStyle(SBWidgetStyle.secondary)
                Text("\(state.client) · \(state.procedure)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SBWidgetStyle.primary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                countdown(state)
                    .foregroundStyle(SBWidgetStyle.primary)
                Text(SBWidgetTime.string(from: state.start))
                    .font(.system(size: 12))
                    .foregroundStyle(SBWidgetStyle.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Таймер

    /// До начала — обратный отсчёт, после начала — «Идёт до HH:mm»
    @ViewBuilder
    private func countdown(_ state: SBVisitAttributes.ContentState) -> some View {
        if state.start > Date() {
            Text(timerInterval: Date()...state.start, countsDown: true)
                .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
        } else {
            Text("Идёт до \(SBWidgetTime.string(from: state.end))")
                .font(.system(size: 14, weight: .medium, design: .rounded).monospacedDigit())
        }
    }

    /// «14:00–15:30»
    private func rangeText(_ state: SBVisitAttributes.ContentState) -> String {
        let from: String = SBWidgetTime.string(from: state.start)
        let to: String = SBWidgetTime.string(from: state.end)
        return "\(from)–\(to)"
    }
}
