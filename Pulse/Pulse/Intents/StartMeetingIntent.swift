//
//  StartMeetingIntent.swift
//  Pulse
//
//  App Intent for starting a meeting recording via Siri or Shortcuts

import AppIntents
import CoreData

struct StartMeetingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Meeting"
    static var description = IntentDescription("Start recording a new meeting in Pulse")
    static var openAppWhenRun = true

    @Parameter(title: "Meeting Title", default: "Meeting")
    var meetingTitle: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Signal the app to create a meeting and navigate to recording
        MeetingIntentState.shared.pendingMeetingTitle = meetingTitle

        return .result(dialog: "Recording \(meetingTitle)")
    }
}
