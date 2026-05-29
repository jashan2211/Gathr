import ActivityKit
import SwiftUI
import WidgetKit

// Brand colors duplicated locally so the widget stays independent of the app module.
private let brandPurple = Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255)
private let brandPink = Color(red: 236 / 255, green: 72 / 255, blue: 153 / 255)

struct EventDayLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EventDayActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.functionIcon)
                        .font(.title2)
                        .foregroundStyle(brandPurple)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownLabel(state: context.state)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(brandPink)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.functionName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let location = context.state.locationName {
                            Label(location, systemImage: "mappin.and.ellipse")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if let next = context.state.nextUpName {
                            Text("Up next: \(next)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: context.state.functionIcon)
                    .foregroundStyle(brandPurple)
            } compactTrailing: {
                CountdownLabel(state: context.state)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(brandPink)
            } minimal: {
                Image(systemName: context.state.functionIcon)
                    .foregroundStyle(brandPurple)
            }
            .widgetURL(URL(string: "gather://event/\(context.attributes.eventId)"))
            .keylineTint(brandPurple)
        }
    }
}

// MARK: - Lock Screen / Banner

private struct LockScreenView: View {
    let context: ActivityViewContext<EventDayActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [brandPurple, brandPink],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                Image(systemName: context.state.functionIcon)
                    .font(.title3)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(context.attributes.eventTitle.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(context.state.functionName)
                    .font(.headline)
                    .lineLimit(1)
                if let location = context.state.locationName {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                if context.state.isOngoing {
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 7, height: 7)
                        Text("Now")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("STARTS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                CountdownLabel(state: context.state)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(brandPink)
            }
        }
        .padding()
    }
}

// MARK: - Countdown

/// Shows "Now" while a function is ongoing, otherwise an auto-updating relative
/// countdown to its start ("in 59 min", "in 2 hr").
private struct CountdownLabel: View {
    let state: EventDayActivityAttributes.ContentState

    var body: some View {
        if state.isOngoing {
            Text("Now")
        } else {
            Text(state.functionStart, style: .relative)
        }
    }
}
