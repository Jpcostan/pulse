//
//  MeetingDetailView.swift
//  Pulse
//

import SwiftUI
import CoreData

struct MeetingDetailView: View {
    @ObservedObject var meeting: Meeting
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var playbackService = AudioPlaybackService()
    @State private var hasLoadedAudio = false
    @State private var isEditingTranscript = false
    @State private var editedChunks: [UUID: String] = [:]

    var body: some View {
        List {
            // Audio playback section
            if let audioPath = meeting.audioFilePath,
               FileManager.default.fileExists(atPath: audioPath) {
                Section("Recording") {
                    AudioPlayerView(playbackService: playbackService)
                }
            }

            // Meeting info section
            Section("Details") {
                LabeledContent("Date", value: meeting.createdAt ?? Date(), format: .dateTime)
                LabeledContent("Duration", value: formattedDuration)
                LabeledContent("Status", value: (meeting.status ?? "unknown").capitalized)
            }

            // Transcript section
            Section {
                if let chunks = meeting.transcriptChunks as? Set<TranscriptChunk>, !chunks.isEmpty {
                    ForEach(Array(chunks).sorted { $0.order < $1.order }, id: \.id) { chunk in
                        if isEditingTranscript {
                            let chunkID = chunk.id ?? UUID()
                            TextEditor(text: Binding(
                                get: { editedChunks[chunkID] ?? chunk.text ?? "" },
                                set: { editedChunks[chunkID] = $0 }
                            ))
                            .font(.body)
                            .frame(minHeight: 80)
                        } else {
                            Text(chunk.text ?? "")
                                .font(.body)
                        }
                    }
                } else {
                    Text("No transcript available")
                        .foregroundStyle(.secondary)
                        .italic()
                }
            } header: {
                HStack {
                    Text("Transcript")
                    Spacer()
                    if let chunks = meeting.transcriptChunks as? Set<TranscriptChunk>, !chunks.isEmpty {
                        Button(isEditingTranscript ? "Done" : "Edit") {
                            if isEditingTranscript {
                                saveTranscriptEdits()
                            } else {
                                // Populate editedChunks with current text
                                if let chunks = meeting.transcriptChunks as? Set<TranscriptChunk> {
                                    for chunk in chunks {
                                        if let id = chunk.id {
                                            editedChunks[id] = chunk.text ?? ""
                                        }
                                    }
                                }
                            }
                            isEditingTranscript.toggle()
                        }
                        .font(.subheadline)
                    }
                }
            }

            // Action items section
            Section("Action Items") {
                if let items = meeting.actionItems as? Set<ActionItem>, !items.isEmpty {
                    ForEach(Array(items).sorted { ($0.confidence) > ($1.confidence) }, id: \.id) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title ?? "Untitled")
                                if let dueDate = item.dueDate {
                                    Text(dueDate, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            // Sync status icons
                            HStack(spacing: 8) {
                                if item.reminderIdentifier != nil {
                                    Image(systemName: "checklist")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                }
                                if item.calendarEventIdentifier != nil {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(.blue)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                } else {
                    Text("No action items")
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
        }
        .navigationTitle(meeting.title ?? "Untitled Meeting")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadAudioIfNeeded()
        }
        .onDisappear {
            playbackService.cleanup()
        }
    }

    private func saveTranscriptEdits() {
        guard let chunks = meeting.transcriptChunks as? Set<TranscriptChunk> else { return }
        for chunk in chunks {
            if let id = chunk.id, let editedText = editedChunks[id] {
                chunk.text = editedText
            }
        }
        try? viewContext.save()
        editedChunks.removeAll()
    }

    private var formattedDuration: String {
        let duration = meeting.duration
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    private func loadAudioIfNeeded() {
        guard !hasLoadedAudio,
              let audioPath = meeting.audioFilePath else { return }

        hasLoadedAudio = true

        do {
            try playbackService.load(path: audioPath)
        } catch {
            print("Failed to load audio: \(error)")
        }
    }
}

// MARK: - Audio Player View

struct AudioPlayerView: View {
    @ObservedObject var playbackService: AudioPlaybackService

    var body: some View {
        VStack(spacing: 12) {
            // Progress slider
            Slider(
                value: Binding(
                    get: { playbackService.currentTime },
                    set: { playbackService.seek(to: $0) }
                ),
                in: 0...max(playbackService.duration, 0.01)
            )
            .tint(.accentColor)

            // Time labels
            HStack {
                Text(formatTime(playbackService.currentTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                Text(formatTime(playbackService.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            // Playback controls
            HStack(spacing: 32) {
                // Skip back 15s
                Button {
                    playbackService.skip(by: -15)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }
                .buttonStyle(.plain)

                // Play/Pause
                Button {
                    playbackService.togglePlayPause()
                } label: {
                    Image(systemName: playbackService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                }
                .buttonStyle(.plain)

                // Skip forward 15s
                Button {
                    playbackService.skip(by: 15)
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationStack {
        MeetingDetailView(meeting: {
            let context = PersistenceController.preview.container.viewContext
            let meeting = Meeting(context: context)
            meeting.id = UUID()
            meeting.title = "Team Standup"
            meeting.createdAt = Date()
            meeting.duration = 1847
            meeting.status = "completed"
            return meeting
        }())
    }
}
