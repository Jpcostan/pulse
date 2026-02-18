//
//  MeetingIntentState.swift
//  Pulse
//
//  Shared state between App Intents and the UI

import SwiftUI

@MainActor
@Observable
class MeetingIntentState {
    static let shared = MeetingIntentState()

    /// When set, HomeView creates a meeting with this title and navigates to recording
    var pendingMeetingTitle: String?
}
