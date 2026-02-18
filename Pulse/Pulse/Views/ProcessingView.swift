//
//  ProcessingView.swift
//  Pulse
//

import SwiftUI
import CoreData
import Combine

struct ProcessingView: View {
    let meeting: Meeting
    var onComplete: () -> Void = {}

    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var transcriptionService = TranscriptionService()
    @StateObject private var actionDetectionService = ActionDetectionService()
    @State private var showReview = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hasStartedProcessing = false
    @State private var processingPhase: ProcessingPhase = .transcribing

    private enum ProcessingPhase {
        case transcribing
        case detectingActions
        case complete
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Processing animation
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: overallProgress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: overallProgress)

                Image(systemName: iconForStep)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
            }

            // Status text
            VStack(spacing: 8) {
                Text(currentStepText)
                    .font(.title3)
                    .fontWeight(.medium)

                Text("\(Int(overallProgress * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Meeting info
            Text(meeting.title ?? "Untitled Meeting")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .navigationTitle("Processing")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $showReview) {
            ActionReviewView(meeting: meeting, onComplete: onComplete)
        }
        .task {
            await startProcessingIfNeeded()
        }
        .alert("Processing Error", isPresented: $showError) {
            Button("Continue Anyway") {
                meeting.status = "completed"
                try? viewContext.save()
                showReview = true
            }
            Button("Cancel", role: .cancel) {
                onComplete()
            }
        } message: {
            Text(errorMessage)
        }
    }

    private var overallProgress: Double {
        switch processingPhase {
        case .transcribing:
            // Transcription is 0-70% of total
            return transcriptionService.progress * 0.7
        case .detectingActions:
            // Action detection is 70-100%
            return 0.7 + (actionDetectionService.progress * 0.3)
        case .complete:
            return 1.0
        }
    }

    private var currentStepText: String {
        switch processingPhase {
        case .transcribing:
            return transcriptionService.currentStep.isEmpty ? "Preparing..." : transcriptionService.currentStep
        case .detectingActions:
            return actionDetectionService.currentStep.isEmpty ? "Detecting actions..." : actionDetectionService.currentStep
        case .complete:
            return "Complete"
        }
    }

    private var iconForStep: String {
        switch processingPhase {
        case .transcribing:
            return "waveform"
        case .detectingActions:
            return "text.magnifyingglass"
        case .complete:
            return "checkmark.circle"
        }
    }

    private func startProcessingIfNeeded() async {
        NSLog("=== PROCESSING VIEW START ===")
        guard !hasStartedProcessing else {
            NSLog("Already started processing, returning")
            return
        }
        hasStartedProcessing = true

        // Get audio file URL
        guard let audioPath = meeting.audioFilePath else {
            NSLog("ERROR: No audio file path on meeting")
            // No audio file - skip to review
            meeting.status = "completed"
            try? viewContext.save()
            showReview = true
            return
        }

        NSLog("Audio path: %@", audioPath)
        let audioURL = URL(fileURLWithPath: audioPath)

        // Phase 1: Transcription
        processingPhase = .transcribing
        do {
            try await transcriptionService.transcribe(
                audioURL: audioURL,
                meeting: meeting,
                context: viewContext
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return
        }

        // Phase 2: Action Detection
        processingPhase = .detectingActions

        // Refresh meeting to see newly saved transcript chunks
        viewContext.refresh(meeting, mergeChanges: true)

        // Get transcript text from meeting's transcript chunks
        let transcriptText = getTranscriptText()

        // DEBUG: Log what we're passing to action detection
        NSLog("=== ACTION DETECTION DEBUG ===")
        let chunks = meeting.transcriptChunks as? Set<TranscriptChunk> ?? []
        NSLog("Number of transcript chunks: %d", chunks.count)
        for chunk in chunks.sorted(by: { $0.order < $1.order }) {
            NSLog("Chunk %d: '%@' (length: %d)", chunk.order, chunk.text ?? "nil", chunk.text?.count ?? 0)
        }
        NSLog("Combined transcript text length: %d", transcriptText.count)
        NSLog("Combined transcript text: %@", transcriptText)
        NSLog("==============================")

        if !transcriptText.isEmpty {
            do {
                let _ = try await actionDetectionService.detectActions(
                    from: transcriptText,
                    meeting: meeting,
                    context: viewContext
                )
            } catch {
                // Action detection errors are non-fatal, just log and continue
                print("Action detection warning: \(error)")
            }
        }

        // Complete
        processingPhase = .complete
        meeting.status = "completed"
        try? viewContext.save()

        // Refresh meeting to see newly saved action items
        viewContext.refresh(meeting, mergeChanges: true)

        // Small delay to show completion state
        try? await Task.sleep(for: .milliseconds(300))

        showReview = true
    }

    private func getTranscriptText() -> String {
        guard let chunks = meeting.transcriptChunks as? Set<TranscriptChunk> else {
            return ""
        }

        let sortedChunks = chunks.sorted { $0.order < $1.order }
        // Join with period + space to ensure proper sentence segmentation between chunks
        return sortedChunks.compactMap { $0.text }.joined(separator: ". ")
    }
}

#Preview {
    NavigationStack {
        ProcessingView(meeting: {
            let context = PersistenceController.preview.container.viewContext
            let meeting = Meeting(context: context)
            meeting.id = UUID()
            meeting.title = "Team Standup"
            meeting.createdAt = Date()
            meeting.status = "processing"
            return meeting
        }())
    }
}
