//
//  ActionReviewView.swift
//  Pulse
//

import SwiftUI
import CoreData

struct ActionReviewView: View {
    @ObservedObject var meeting: Meeting
    var onComplete: () -> Void = {}

    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var remindersService = RemindersService()
    @State private var showSummary = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var createdRemindersCount = 0
    @State private var createdEventsCount = 0
    @State private var isCreating = false
    @State private var alsoCreateCalendarEvents = false
    @FocusState private var newItemFocused: Bool

    private var actionItems: [ActionItem] {
        guard let items = meeting.actionItems as? Set<ActionItem> else { return [] }
        return items.sorted { ($0.confidence) > ($1.confidence) }
    }

    private var includedItems: [ActionItem] {
        actionItems.filter { $0.isIncluded }
    }

    private var itemsWithDueDates: [ActionItem] {
        includedItems.filter { $0.dueDate != nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header stats
            HStack {
                VStack(alignment: .leading) {
                    Text("\(includedItems.count) of \(actionItems.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("action items selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()

            Divider()

            // Action items list or empty state
            if actionItems.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(actionItems, id: \.id) { item in
                        ActionItemRow(
                            item: item,
                            viewContext: viewContext,
                            isFocused: item == actionItems.last && newItemFocused
                        )
                    }

                    // Debug section - shows transcript chunks
                    Section("Debug: Transcript") {
                        Text(transcriptDebugText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            // Bottom buttons
            VStack(spacing: 12) {
                // Calendar events toggle (only show if items have due dates)
                if itemsWithDueDates.count > 0 && includedItems.count > 0 {
                    Toggle(isOn: $alsoCreateCalendarEvents) {
                        HStack {
                            Image(systemName: "calendar")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Also add to Calendar")
                                Text("Will add \(itemsWithDueDates.count) item(s)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if includedItems.count > 0 {
                    Button(action: createReminders) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .tint(.white)
                                Text("Creating...")
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Create \(includedItems.count) Reminders")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCreating)
                }

                Button(includedItems.count > 0 ? "Skip" : "Done") {
                    finishWithoutReminders()
                }
                .font(.subheadline)
                .foregroundStyle(includedItems.count > 0 ? .secondary : .primary)
                .disabled(isCreating)
            }
            .padding()
        }
        .navigationTitle("Review Actions")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $showSummary) {
            SummaryView(
                meeting: meeting,
                createdRemindersCount: createdRemindersCount,
                createdEventsCount: createdEventsCount,
                onComplete: onComplete
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    addManualActionItem()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func addManualActionItem() {
        let item = ActionItem(context: viewContext)
        item.id = UUID()
        item.title = ""
        item.confidence = 1.0
        item.isIncluded = true
        item.meeting = meeting
        try? viewContext.save()

        // Focus the new item's text field after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            newItemFocused = true
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Action Items Detected")
                .font(.title3)
                .fontWeight(.medium)
            Text("No tasks or commitments were found in this recording.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
    }

    /// Debug: Get the full transcript text for display
    private var transcriptDebugText: String {
        guard let chunks = meeting.transcriptChunks as? Set<TranscriptChunk> else {
            return "[No transcript chunks]"
        }
        let sortedChunks = chunks.sorted { $0.order < $1.order }
        let texts = sortedChunks.compactMap { $0.text }

        var output = "Chunks: \(texts.count)\n"
        output += "Combined length: \(texts.joined(separator: ". ").count) chars\n\n"

        for (i, chunk) in sortedChunks.enumerated() {
            let text = chunk.text ?? "[nil]"
            output += "--- Chunk \(i) (\(String(format: "%.1f", chunk.startTime))-\(String(format: "%.1f", chunk.endTime))s) ---\n"
            output += text + "\n\n"
        }

        // Show detected items for cross-reference
        let items = actionItems
        if !items.isEmpty {
            output += "--- Detected Actions ---\n"
            for item in items {
                output += "• \(item.title ?? "?") [\(Int(item.confidence * 100))%]\n"
                if let source = item.sourceSentence {
                    output += "  Source: \"\(source)\"\n"
                }
            }
        }

        output += "\n(Check Console.app → subsystem:com.jpcostan.Pulse for full filter log)"
        return output
    }

    private func createReminders() {
        isCreating = true

        Task {
            do {
                // Create reminders
                let remindersCount = try await remindersService.createReminders(
                    from: includedItems,
                    context: viewContext
                )
                createdRemindersCount = remindersCount

                // Optionally create calendar events
                if alsoCreateCalendarEvents && !itemsWithDueDates.isEmpty {
                    let eventsCount = try await remindersService.createCalendarEvents(
                        from: itemsWithDueDates,
                        context: viewContext
                    )
                    createdEventsCount = eventsCount
                }

                // Mark meeting as completed
                meeting.status = "completed"
                try? viewContext.save()

                isCreating = false
                showSummary = true
            } catch {
                isCreating = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func finishWithoutReminders() {
        createdRemindersCount = 0
        meeting.status = "completed"
        try? viewContext.save()
        showSummary = true
    }
}

struct ActionItemRow: View {
    @ObservedObject var item: ActionItem
    let viewContext: NSManagedObjectContext
    var isFocused: Bool = false

    @State private var isExpanded = false
    @State private var editedTitle: String = ""
    @State private var showDatePicker = false
    @State private var selectedDate: Date = Date()
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                // Toggle
                Button {
                    item.isIncluded.toggle()
                    try? viewContext.save()
                } label: {
                    Image(systemName: item.isIncluded ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(item.isIncluded ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Action item", text: $editedTitle, onCommit: saveTitle)
                        .font(.body)
                        .focused($titleFocused)

                    // Date button
                    Button {
                        selectedDate = item.dueDate ?? Date()
                        showDatePicker = true
                    } label: {
                        if let dueDate = item.dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                Text(dueDate, style: .date)
                                if let time = formattedTime(dueDate) {
                                    Text("at \(time)")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.plus")
                                Text("Add date")
                            }
                            .font(.caption)
                            .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)

                    // Confidence indicator
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("\(Int(item.confidence * 100))% confidence")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // Sync status (if already synced)
                    if item.reminderIdentifier != nil || item.calendarEventIdentifier != nil {
                        HStack(spacing: 4) {
                            if item.reminderIdentifier != nil {
                                Image(systemName: "checklist")
                                Text("Synced to Reminders")
                            }
                            if item.calendarEventIdentifier != nil {
                                Image(systemName: "calendar")
                                Text("In Calendar")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.green)
                    }
                }

                Spacer()

                // Expand button (only if there's source sentence)
                if item.sourceSentence != nil && !(item.sourceSentence?.isEmpty ?? true) {
                    Button {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Expanded source sentence
            if isExpanded, let source = item.sourceSentence, !source.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Source:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    Text("\"\(source)\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
                .padding(.leading, 36)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            editedTitle = item.title ?? ""
            if isFocused {
                titleFocused = true
            }
        }
        .onChange(of: item.title) { _, newValue in
            if editedTitle != newValue {
                editedTitle = newValue ?? ""
            }
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                VStack {
                    DatePicker(
                        "Due Date",
                        selection: $selectedDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .padding()

                    if item.dueDate != nil {
                        Button("Remove Date", role: .destructive) {
                            item.dueDate = nil
                            try? viewContext.save()
                            showDatePicker = false
                        }
                        .padding(.bottom)
                    }

                    Spacer()
                }
                .navigationTitle("Set Due Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showDatePicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            item.dueDate = selectedDate
                            try? viewContext.save()
                            showDatePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func saveTitle() {
        if editedTitle != item.title {
            item.title = editedTitle
            try? viewContext.save()
        }
    }

    private func formattedTime(_ date: Date) -> String? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        guard hour != 0 || minute != 0 else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ActionReviewView(meeting: {
            let context = PersistenceController.preview.container.viewContext
            let meeting = Meeting(context: context)
            meeting.id = UUID()
            meeting.title = "Team Standup"
            meeting.createdAt = Date()
            meeting.status = "processing"

            // Add sample action items
            let item1 = ActionItem(context: context)
            item1.id = UUID()
            item1.title = "Send project proposal to client"
            item1.sourceSentence = "I'll send the project proposal to the client by end of day tomorrow."
            item1.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
            item1.isIncluded = true
            item1.confidence = 0.95
            item1.meeting = meeting

            let item2 = ActionItem(context: context)
            item2.id = UUID()
            item2.title = "Schedule follow-up meeting"
            item2.sourceSentence = "We should schedule a follow-up meeting with the design team next week."
            item2.dueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
            item2.isIncluded = true
            item2.confidence = 0.88
            item2.meeting = meeting

            let item3 = ActionItem(context: context)
            item3.id = UUID()
            item3.title = "Review Q4 budget numbers"
            item3.sourceSentence = "Can you review the Q4 budget numbers before our next sync?"
            item3.isIncluded = false
            item3.confidence = 0.72
            item3.meeting = meeting

            return meeting
        }())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
