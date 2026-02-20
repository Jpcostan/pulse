//
//  HomeView.swift
//  Pulse
//

import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Meeting.createdAt, ascending: false)],
        animation: .default
    )
    private var meetings: FetchedResults<Meeting>

    @State private var navigationPath = NavigationPath()
    private var intentState = MeetingIntentState.shared

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if meetings.isEmpty {
                    emptyStateView
                } else {
                    meetingsList
                }
            }
            .navigationTitle("Pulse")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: startNewMeeting) {
                        Image(systemName: "mic.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .navigationDestination(for: Meeting.self) { meeting in
                RecordingView(meeting: meeting, onComplete: popToRoot)
            }
            .navigationDestination(for: MeetingDetailRoute.self) { route in
                MeetingDetailView(meeting: route.meeting)
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .onChange(of: intentState.pendingMeetingTitle) { _, title in
                if let title {
                    startMeetingFromIntent(title: title)
                    intentState.pendingMeetingTitle = nil
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "waveform.circle")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)

            Text("No Meetings Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap the microphone to start\nrecording your first meeting.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: startNewMeeting) {
                Label("Start Recording", systemImage: "mic.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }

    private var meetingsList: some View {
        List {
            ForEach(meetings) { meeting in
                Button {
                    navigationPath.append(MeetingDetailRoute(meeting: meeting))
                } label: {
                    MeetingRowView(meeting: meeting)
                }
                .foregroundStyle(.primary)
            }
            .onDelete(perform: deleteMeetings)
        }
    }

    private func startNewMeeting() {
        let newMeeting = Meeting(context: viewContext)
        newMeeting.id = UUID()
        newMeeting.title = "Meeting \(meetings.count + 1)"
        newMeeting.createdAt = Date()
        newMeeting.status = "recording"

        do {
            try viewContext.save()
            navigationPath.append(newMeeting)
        } catch {
            let nsError = error as NSError
            print("Error creating meeting: \(nsError), \(nsError.userInfo)")
        }
    }

    private func startMeetingFromIntent(title: String) {
        // If already recording, navigate to that meeting instead
        if let recordingMeeting = meetings.first(where: { $0.status == "recording" }) {
            navigationPath = NavigationPath()
            navigationPath.append(recordingMeeting)
            return
        }

        let newMeeting = Meeting(context: viewContext)
        newMeeting.id = UUID()
        newMeeting.title = title
        newMeeting.createdAt = Date()
        newMeeting.status = "recording"

        do {
            try viewContext.save()
            navigationPath = NavigationPath()
            navigationPath.append(newMeeting)
        } catch {
            print("Error creating meeting from intent: \(error)")
        }
    }

    private func popToRoot() {
        navigationPath = NavigationPath()
    }

    private func deleteMeetings(offsets: IndexSet) {
        withAnimation {
            offsets.map { meetings[$0] }.forEach(viewContext.delete)
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting meeting: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Handle pulse://recording deep link from Live Activity
        guard url.scheme == "pulse" else { return }

        switch url.host {
        case "recording":
            // Find the currently recording meeting and navigate to it
            if let recordingMeeting = meetings.first(where: { $0.status == "recording" }) {
                // Clear navigation path and navigate to recording
                navigationPath = NavigationPath()
                navigationPath.append(recordingMeeting)
            }
        default:
            break
        }
    }
}

// Route wrapper for MeetingDetailView to differentiate from Recording navigation
struct MeetingDetailRoute: Hashable {
    let meeting: Meeting
}

struct MeetingRowView: View {
    @ObservedObject var meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(meeting.title ?? "Untitled Meeting")
                    .font(.headline)

                Spacer()

                StatusBadge(status: meeting.status ?? "unknown")
            }

            HStack {
                Text(meeting.createdAt ?? Date(), style: .date)
                Text(formattedDuration)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var formattedDuration: String {
        let duration = meeting.duration
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(status.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case "recording":
            return .red.opacity(0.15)
        case "processing":
            return .orange.opacity(0.15)
        case "completed":
            return .green.opacity(0.15)
        default:
            return .gray.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case "recording":
            return .red
        case "processing":
            return .orange
        case "completed":
            return .green
        default:
            return .gray
        }
    }
}

#Preview {
    HomeView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
