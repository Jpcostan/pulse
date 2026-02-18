//
//  RecordingActivityAttributes.swift
//  Pulse
//
//  Defines the Live Activity for active meeting recordings

import ActivityKit
import Foundation

/// Attributes for the recording Live Activity
struct RecordingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Current elapsed time in seconds
        var elapsedSeconds: Int

        /// Whether recording is active (vs paused/stopped)
        var isRecording: Bool
    }

    /// Meeting title (static - doesn't change during activity)
    var meetingTitle: String

    /// Start time of the recording (static)
    var startTime: Date
}
