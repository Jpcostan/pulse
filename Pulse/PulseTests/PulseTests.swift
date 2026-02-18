//
//  PulseTests.swift
//  PulseTests
//
//  Created by Joshua Costanza on 1/23/26.
//

import Testing
import CoreData
@testable import Pulse

struct PulseTests {
    @Test @MainActor
    func detectsActionsAndSavesItems() async throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)

        let service = ActionDetectionService()
        let transcript = """
        We need to finalize the deck by March 5, 2030.
        The weather is nice.
        Don't forget to email John by April 1, 2030.
        """

        let count = try await service.detectActions(
            from: transcript,
            meeting: meeting,
            context: context
        )

        #expect(count == 2)

        let items = try context.fetch(ActionItem.fetchRequest())
        #expect(items.count == 2)

        let titles = Set(items.map { $0.title })
        #expect(titles.contains("Finalize the deck by March 5, 2030"))
        #expect(titles.contains("Email John by April 1, 2030"))

        for item in items {
            let title = item.title ?? ""
            guard let dueDate = item.dueDate else {
                Issue.record("Expected a due date for item '\(title)'")
                continue
            }

            let components = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
            if title.contains("March 5, 2030") {
                #expect(components.year == 2030)
                #expect(components.month == 3)
                #expect(components.day == 5)
            } else if title.contains("April 1, 2030") {
                #expect(components.year == 2030)
                #expect(components.month == 4)
                #expect(components.day == 1)
            }
        }
    }

    @Test @MainActor
    func autoIncludeAtThreshold() async throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)

        let service = ActionDetectionService()
        let transcript = "Please send the proposal."

        let count = try await service.detectActions(
            from: transcript,
            meeting: meeting,
            context: context
        )

        #expect(count == 1)

        let items = try context.fetch(ActionItem.fetchRequest())
        #expect(items.count == 1)
        #expect(items.first?.isIncluded == true)
        #expect(items.first?.title == "Send the proposal")
    }

    @Test @MainActor
    func ignoresNonActionSentences() async throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)

        let service = ActionDetectionService()
        let transcript = "The weather is nice. We talked about nothing important."

        let count = try await service.detectActions(
            from: transcript,
            meeting: meeting,
            context: context
        )

        #expect(count == 0)

        let items = try context.fetch(ActionItem.fetchRequest())
        #expect(items.isEmpty)
    }

    private func makeInMemoryContext() -> NSManagedObjectContext {
        let controller = PersistenceController(inMemory: true)
        return controller.container.viewContext
    }

    private func makeMeeting(in context: NSManagedObjectContext) -> Meeting {
        let meeting = Meeting(context: context)
        meeting.id = UUID()
        meeting.title = "Test Meeting"
        meeting.createdAt = Date()
        meeting.status = "processing"
        try? context.save()
        return meeting
    }
}
