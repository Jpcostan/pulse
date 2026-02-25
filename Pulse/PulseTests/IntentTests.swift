//
//  IntentTests.swift
//  PulseTests
//

import Testing
import Foundation
import SwiftUI
@testable import Pulsio

struct IntentTests {

    @Test @MainActor
    func meetingIntentStateSingleton() {
        let instance1 = MeetingIntentState.shared
        let instance2 = MeetingIntentState.shared
        #expect(instance1 === instance2)
    }

    @Test @MainActor
    func pendingMeetingTitleDefaultIsNil() {
        let state = MeetingIntentState.shared
        // Reset for test
        state.pendingMeetingTitle = nil
        #expect(state.pendingMeetingTitle == nil)
    }

    @Test @MainActor
    func settingPendingMeetingTitle() {
        let state = MeetingIntentState.shared
        state.pendingMeetingTitle = "Team Standup"
        #expect(state.pendingMeetingTitle == "Team Standup")
        // Clean up
        state.pendingMeetingTitle = nil
    }
}
