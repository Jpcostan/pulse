//
//  SummaryView.swift
//  Pulse
//

import SwiftUI
import CoreData

struct SummaryView: View {
    let meeting: Meeting
    let createdRemindersCount: Int
    var createdEventsCount: Int = 0
    var onComplete: () -> Void = {}

    @Environment(\.managedObjectContext) private var viewContext
    @State private var showDeleteAudioAlert = false
    @State private var audioDeleted = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success indicator
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
            }

            // Summary text
            VStack(spacing: 12) {
                Text("Meeting Complete")
                    .font(.title)
                    .fontWeight(.semibold)

                Text(meeting.title ?? "Untitled Meeting")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            // Stats
            VStack(spacing: 16) {
                SummaryStatRow(
                    icon: "clock",
                    title: "Duration",
                    value: formattedDuration
                )

                SummaryStatRow(
                    icon: "checkmark.circle",
                    title: "Reminders Created",
                    value: "\(createdRemindersCount)"
                )

                if createdEventsCount > 0 {
                    SummaryStatRow(
                        icon: "calendar",
                        title: "Calendar Events",
                        value: "\(createdEventsCount)"
                    )
                }

                SummaryStatRow(
                    icon: "waveform",
                    title: "Status",
                    value: "Processed"
                )

                if let audioSize = audioFileSize, !audioDeleted {
                    SummaryStatRow(
                        icon: "doc.fill",
                        title: "Audio File",
                        value: audioSize
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            // Storage cleanup option
            if hasAudioFile && !audioDeleted {
                Button {
                    showDeleteAudioAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Audio to Save Space")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.red)
                }
                .padding(.top, 8)
            } else if audioDeleted {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("Audio deleted - transcript saved")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            }

            Spacer()

            // Done button - pops to root
            Button(action: onComplete) {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .alert("Delete Audio?", isPresented: $showDeleteAudioAlert) {
            Button("Delete", role: .destructive) {
                deleteAudioFile()
            }
            Button("Keep", role: .cancel) { }
        } message: {
            Text("The transcript and action items will be kept. Only the audio recording will be deleted to free up storage space.")
        }
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

    private var hasAudioFile: Bool {
        guard let path = meeting.audioFilePath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    private var audioFileSize: String? {
        guard let path = meeting.audioFilePath,
              let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64 else {
            return nil
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    private func deleteAudioFile() {
        guard let path = meeting.audioFilePath else { return }

        do {
            try FileManager.default.removeItem(atPath: path)
            meeting.audioFilePath = nil
            try? viewContext.save()
            audioDeleted = true
        } catch {
            print("Failed to delete audio: \(error)")
        }
    }
}

struct SummaryStatRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    NavigationStack {
        SummaryView(
            meeting: {
                let context = PersistenceController.preview.container.viewContext
                let meeting = Meeting(context: context)
                meeting.id = UUID()
                meeting.title = "Team Standup"
                meeting.createdAt = Date()
                meeting.duration = 1847
                meeting.status = "completed"
                return meeting
            }(),
            createdRemindersCount: 4,
            createdEventsCount: 2
        )
    }
}
