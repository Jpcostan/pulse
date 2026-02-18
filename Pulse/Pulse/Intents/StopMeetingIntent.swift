//
//  StopMeetingIntent.swift
//  Pulse
//
//  App Intent for stopping the current meeting recording via Siri or Shortcuts

import AppIntents
import CoreData

struct StopMeetingIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Meeting"
    static var description = IntentDescription("Stop the current meeting recording in Pulse")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let audioService = AudioRecordingService.shared

        guard audioService.isRecording else {
            return .result(dialog: "No meeting is currently being recorded.")
        }

        // Stop recording
        guard let result = audioService.stopRecording() else {
            return .result(dialog: "Failed to stop the recording.")
        }

        // Update the meeting entity in Core Data
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Meeting> = Meeting.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "status == %@", "recording")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Meeting.createdAt, ascending: false)]
        fetchRequest.fetchLimit = 1

        if let meeting = try? context.fetch(fetchRequest).first {
            meeting.duration = result.duration
            meeting.audioFilePath = result.url.path
            meeting.status = "processing"
            try? context.save()
        }

        // Format duration for dialog
        let minutes = Int(result.duration) / 60
        let seconds = Int(result.duration) % 60
        let durationText = minutes > 0
            ? "\(minutes) minute\(minutes == 1 ? "" : "s") and \(seconds) second\(seconds == 1 ? "" : "s")"
            : "\(seconds) second\(seconds == 1 ? "" : "s")"

        return .result(dialog: "Meeting stopped. Recorded \(durationText). Open Pulse to process the recording.")
    }
}
