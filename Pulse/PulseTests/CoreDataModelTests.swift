//
//  CoreDataModelTests.swift
//  PulseTests
//

import Testing
import CoreData
@testable import Pulsio

struct CoreDataModelTests {

    // MARK: - Meeting Creation

    @Test @MainActor
    func meetingCreationWithAllFields() throws {
        let context = makeInMemoryContext()
        let id = UUID()
        let now = Date()

        let meeting = Meeting(context: context)
        meeting.id = id
        meeting.title = "Test Meeting"
        meeting.createdAt = now
        meeting.duration = 1800
        meeting.status = "completed"
        meeting.audioFilePath = "/path/to/audio.m4a"
        try context.save()

        let fetched = try context.fetch(Meeting.fetchRequest())
        #expect(fetched.count == 1)
        #expect(fetched[0].id == id)
        #expect(fetched[0].title == "Test Meeting")
        #expect(fetched[0].duration == 1800)
        #expect(fetched[0].status == "completed")
        #expect(fetched[0].audioFilePath == "/path/to/audio.m4a")
    }

    // MARK: - TranscriptChunk

    @Test @MainActor
    func transcriptChunkCreation() throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)

        let chunk = TranscriptChunk(context: context)
        chunk.id = UUID()
        chunk.text = "Hello world this is a test."
        chunk.startTime = 0.0
        chunk.endTime = 30.0
        chunk.order = 0
        chunk.meeting = meeting
        try context.save()

        let fetched = try context.fetch(TranscriptChunk.fetchRequest())
        #expect(fetched.count == 1)
        #expect(fetched[0].text == "Hello world this is a test.")
        #expect(fetched[0].startTime == 0.0)
        #expect(fetched[0].endTime == 30.0)
        #expect(fetched[0].order == 0)
        #expect(fetched[0].meeting?.id == meeting.id)
    }

    @Test @MainActor
    func transcriptChunkOrdering() throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)

        for i: Int16 in (0..<3).reversed() {
            let chunk = TranscriptChunk(context: context)
            chunk.id = UUID()
            chunk.text = "Chunk \(i)"
            chunk.startTime = Double(i) * 30
            chunk.endTime = Double(i + 1) * 30
            chunk.order = i
            chunk.meeting = meeting
        }
        try context.save()

        let request = TranscriptChunk.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        let fetched = try context.fetch(request)

        #expect(fetched.count == 3)
        #expect(fetched[0].order == 0)
        #expect(fetched[1].order == 1)
        #expect(fetched[2].order == 2)
    }

    // MARK: - ActionItem

    @Test @MainActor
    func actionItemCreationWithAllFields() throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)
        let id = UUID()
        let dueDate = Date().addingTimeInterval(86400)

        let item = ActionItem(context: context)
        item.id = id
        item.title = "Send the report"
        item.sourceSentence = "Please send the report by Friday."
        item.dueDate = dueDate
        item.isIncluded = true
        item.confidence = 0.90
        item.reminderIdentifier = "reminder-123"
        item.calendarEventIdentifier = "event-456"
        item.meeting = meeting
        try context.save()

        let fetched = try context.fetch(ActionItem.fetchRequest())
        #expect(fetched.count == 1)
        #expect(fetched[0].id == id)
        #expect(fetched[0].title == "Send the report")
        #expect(fetched[0].sourceSentence == "Please send the report by Friday.")
        #expect(fetched[0].isIncluded == true)
        #expect(fetched[0].confidence == 0.90)
        #expect(fetched[0].reminderIdentifier == "reminder-123")
        #expect(fetched[0].calendarEventIdentifier == "event-456")
        #expect(fetched[0].meeting?.id == meeting.id)
    }

    @Test @MainActor
    func actionItemDefaultIsIncludedTrue() throws {
        let context = makeInMemoryContext()
        let item = ActionItem(context: context)
        item.id = UUID()
        item.title = "Test"
        // isIncluded default in Core Data model is YES
        #expect(item.isIncluded == true)
    }

    // MARK: - Relationships

    @Test @MainActor
    func meetingToTranscriptChunksRelationship() throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)

        for i: Int16 in 0..<3 {
            let chunk = TranscriptChunk(context: context)
            chunk.id = UUID()
            chunk.text = "Chunk \(i)"
            chunk.order = i
            chunk.startTime = Double(i) * 30
            chunk.endTime = Double(i + 1) * 30
            chunk.meeting = meeting
        }
        try context.save()

        context.refresh(meeting, mergeChanges: true)
        #expect((meeting.transcriptChunks?.count ?? 0) == 3)
    }

    @Test @MainActor
    func meetingToActionItemsRelationship() throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)

        for i in 0..<2 {
            let item = ActionItem(context: context)
            item.id = UUID()
            item.title = "Action \(i)"
            item.confidence = 0.85
            item.meeting = meeting
        }
        try context.save()

        context.refresh(meeting, mergeChanges: true)
        #expect((meeting.actionItems?.count ?? 0) == 2)
    }

    // MARK: - Cascade Delete

    @Test @MainActor
    func cascadeDeleteRemovesChunksAndActions() throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)

        let chunk = TranscriptChunk(context: context)
        chunk.id = UUID()
        chunk.text = "Test chunk"
        chunk.order = 0
        chunk.startTime = 0
        chunk.endTime = 30
        chunk.meeting = meeting

        let item = ActionItem(context: context)
        item.id = UUID()
        item.title = "Test action"
        item.confidence = 0.85
        item.meeting = meeting
        try context.save()

        // Verify entities exist
        #expect(try context.fetch(TranscriptChunk.fetchRequest()).count == 1)
        #expect(try context.fetch(ActionItem.fetchRequest()).count == 1)

        // Delete meeting
        context.delete(meeting)
        try context.save()

        // Cascade should remove related entities
        #expect(try context.fetch(Meeting.fetchRequest()).count == 0)
        #expect(try context.fetch(TranscriptChunk.fetchRequest()).count == 0)
        #expect(try context.fetch(ActionItem.fetchRequest()).count == 0)
    }

    // MARK: - Save/Fetch Round-Trip

    @Test @MainActor
    func saveFetchRoundTrip() throws {
        let context = makeInMemoryContext()
        let id = UUID()
        let title = "Round Trip Meeting"

        let meeting = Meeting(context: context)
        meeting.id = id
        meeting.title = title
        meeting.createdAt = Date()
        meeting.status = "recording"
        try context.save()

        // Fetch fresh
        let request = Meeting.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        let results = try context.fetch(request)

        #expect(results.count == 1)
        #expect(results[0].id == id)
        #expect(results[0].title == title)
        #expect(results[0].status == "recording")
    }
}
