//
//  PulseWidgetsLiveActivity.swift
//  PulseWidgets
//
//  Live Activity for active meeting recordings

import ActivityKit
import WidgetKit
import SwiftUI

struct PulseWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            // Lock screen/banner UI
            // Uses startTime for self-updating timer (no app updates needed)
            RecordingLockScreenView(
                meetingTitle: context.attributes.meetingTitle,
                startTime: context.attributes.startTime,
                isRecording: context.state.isRecording
            )
            .activityBackgroundTint(Color.black.opacity(0.3))
            .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI - when user long-presses the Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "waveform")
                        .foregroundStyle(.red)
                        .symbolEffect(.pulse)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    // Self-updating timer - counts up from recording start time
                    Text(context.attributes.startTime, style: .timer)
                        .font(.title3.monospacedDigit())
                        .fontWeight(.medium)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.meetingTitle)
                        .font(.headline)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption2)
                        Text("Recording")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                // Compact leading - left side of Dynamic Island
                Image(systemName: "waveform")
                    .foregroundStyle(.red)
            } compactTrailing: {
                // Compact trailing - right side of Dynamic Island
                Text(context.attributes.startTime, style: .timer)
                    .font(.caption2.monospacedDigit())
                    .fontWeight(.medium)
            } minimal: {
                // Minimal - shown when multiple activities are active
                Image(systemName: "waveform")
                    .foregroundStyle(.red)
            }
            .widgetURL(URL(string: "pulse://recording"))
            .keylineTint(Color.red)
        }
    }
}

/// Lock screen view for the Live Activity
struct RecordingLockScreenView: View {
    let meetingTitle: String
    let startTime: Date
    let isRecording: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Recording indicator
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: "waveform")
                    .foregroundStyle(.red)
                    .font(.system(size: 16, weight: .medium))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(meetingTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if isRecording {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("Recording")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Self-updating timer - counts up from recording start time
            Text(startTime, style: .timer)
                .font(.title3.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Previews

extension RecordingActivityAttributes {
    fileprivate static var preview: RecordingActivityAttributes {
        RecordingActivityAttributes(
            meetingTitle: "Team Standup",
            startTime: Date()
        )
    }
}

extension RecordingActivityAttributes.ContentState {
    fileprivate static var active: RecordingActivityAttributes.ContentState {
        RecordingActivityAttributes.ContentState(
            elapsedSeconds: 125,
            isRecording: true
        )
    }
}

#Preview("Notification", as: .content, using: RecordingActivityAttributes.preview) {
    PulseWidgetsLiveActivity()
} contentStates: {
    RecordingActivityAttributes.ContentState.active
}
