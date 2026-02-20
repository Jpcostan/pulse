//
//  RecordingView.swift
//  Pulse
//

import SwiftUI
import CoreData
import Combine

struct RecordingView: View {
    let meeting: Meeting
    var onComplete: () -> Void = {}

    @ObservedObject private var audioService = AudioRecordingService.shared
    @State private var showProcessing = false
    @State private var showError = false
    @State private var hasStartedRecording = false
    @State private var showPreRecordingWarning = false
    @State private var preRecordingWarningMessage = ""
    @State private var showDurationWarningAlert = false
    @State private var showAutoStopAlert = false
    @State private var showPaywall = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Recording indicator
            VStack(spacing: 16) {
                ZStack {
                    // Outer pulsing circle based on audio level
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 120 + CGFloat(audioService.audioLevel * 20), height: 120 + CGFloat(audioService.audioLevel * 20))
                        .animation(.easeInOut(duration: 0.1), value: audioService.audioLevel)

                    Circle()
                        .fill(Color.red)
                        .frame(width: 80, height: 80)
                        .scaleEffect(audioService.isRecording ? 1.0 : 0.8)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: audioService.isRecording)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                }

                Text(audioService.isRecording ? "Recording" : "Starting...")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            // Timer display
            Text(formattedTime)
                .font(.system(size: 64, weight: .light, design: .monospaced))
                .foregroundStyle(.primary)

            // Remaining time (shown when past halfway or warning threshold)
            if audioService.currentTime > AudioRecordingService.warningThreshold - (5 * 60) {
                Text("Time remaining: \(audioService.formattedRemainingTime)")
                    .font(.subheadline)
                    .foregroundStyle(audioService.remainingTime < 5 * 60 ? .red : .orange)
            }

            // Meeting title
            Text(meeting.title ?? "Untitled Meeting")
                .font(.headline)
                .foregroundStyle(.secondary)

            // Audio level indicator
            AudioLevelView(level: audioService.audioLevel)
                .frame(height: 4)
                .padding(.horizontal, 40)

            Spacer()

            // Stop button
            Button(action: stopRecording) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 72, height: 72)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                }
            }
            .disabled(!audioService.isRecording)
            .opacity(audioService.isRecording ? 1.0 : 0.5)
            .padding(.bottom, 60)
        }
        .navigationTitle("Recording")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    cancelRecording()
                }
            }
        }
        .navigationDestination(isPresented: $showProcessing) {
            ProcessingView(meeting: meeting, onComplete: onComplete)
        }
        .task {
            await startRecordingIfNeeded()
        }
        .alert("Recording Error", isPresented: $showError) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(audioService.error?.localizedDescription ?? "An unknown error occurred")
        }
        .alert("Recording Time Warning", isPresented: $showDurationWarningAlert) {
            Button("Continue Recording") {
                audioService.dismissDurationWarning()
            }
            Button("Stop Now") {
                stopRecording()
            }
        } message: {
            Text("Recording will automatically stop in \(audioService.formattedRemainingTime). This is to protect your device's battery and storage.")
        }
        .alert("Recording Complete", isPresented: $showAutoStopAlert) {
            Button("OK") {
                handleAutoStop()
            }
        } message: {
            Text("The recording reached the maximum duration of 60 minutes and was automatically saved.")
        }
        .onReceive(audioService.$showDurationWarning) { show in
            if show { showDurationWarningAlert = true }
        }
        .onReceive(audioService.$didAutoStop) { stopped in
            if stopped { showAutoStopAlert = true }
        }
        .onReceive(audioService.$didHitFreeLimit) { hit in
            if hit { showPaywall = true }
        }
        .sheet(isPresented: $showPaywall, onDismiss: {
            // Recording already stopped and saved — proceed to processing
            handleFreeLimitStop()
        }) {
            PaywallView()
        }
        .alert("Warning", isPresented: $showPreRecordingWarning) {
            Button("Record Anyway") {
                Task {
                    await forceStartRecording()
                }
            }
            Button("Cancel", role: .cancel) {
                cancelRecording()
            }
        } message: {
            Text(preRecordingWarningMessage)
        }
        .onReceive(audioService.$error) { newError in
            showError = newError != nil
        }
    }

    private var formattedTime: String {
        let time = audioService.currentTime
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func startRecordingIfNeeded() async {
        guard !hasStartedRecording else { return }

        guard let meetingID = meeting.id else { return }

        // Check pre-recording conditions (battery, storage)
        if let warning = audioService.validatePreRecordingConditions() {
            preRecordingWarningMessage = warning.localizedDescription
            showPreRecordingWarning = true
            return
        }

        hasStartedRecording = true

        do {
            let fileURL = try await audioService.startRecording(
                meetingID: meetingID,
                meetingTitle: meeting.title ?? "Untitled Meeting"
            )
            meeting.audioFilePath = fileURL.path
            try? meeting.managedObjectContext?.save()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    private func forceStartRecording() async {
        guard !hasStartedRecording else { return }
        hasStartedRecording = true

        guard let meetingID = meeting.id else { return }

        do {
            let fileURL = try await audioService.startRecording(
                meetingID: meetingID,
                meetingTitle: meeting.title ?? "Untitled Meeting"
            )
            meeting.audioFilePath = fileURL.path
            try? meeting.managedObjectContext?.save()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    private func handleAutoStop() {
        // Meeting was auto-stopped, use the stored result
        if let result = audioService.autoStopResult {
            meeting.duration = result.duration
            meeting.audioFilePath = result.url.path
        }
        meeting.status = "processing"
        try? meeting.managedObjectContext?.save()

        showProcessing = true
    }

    private func stopRecording() {
        guard let result = audioService.stopRecording() else { return }

        // Update meeting with duration and file path
        meeting.duration = result.duration
        meeting.audioFilePath = result.url.path
        meeting.status = "processing"
        try? meeting.managedObjectContext?.save()

        showProcessing = true
    }

    private func handleFreeLimitStop() {
        if let result = audioService.autoStopResult {
            meeting.duration = result.duration
            meeting.audioFilePath = result.url.path
        }
        meeting.status = "processing"
        try? meeting.managedObjectContext?.save()

        showProcessing = true
    }

    private func cancelRecording() {
        audioService.cancelRecording()

        // Delete the meeting
        if let context = meeting.managedObjectContext {
            context.delete(meeting)
            try? context.save()
        }

        onComplete()
    }

}

// MARK: - Audio Level View

struct AudioLevelView: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(Color.secondary.opacity(0.2))

                // Level indicator
                Capsule()
                    .fill(Color.red)
                    .frame(width: geometry.size.width * CGFloat(level))
                    .animation(.easeOut(duration: 0.1), value: level)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecordingView(meeting: {
            let context = PersistenceController.preview.container.viewContext
            let meeting = Meeting(context: context)
            meeting.id = UUID()
            meeting.title = "Team Standup"
            meeting.createdAt = Date()
            meeting.status = "recording"
            return meeting
        }())
    }
}
