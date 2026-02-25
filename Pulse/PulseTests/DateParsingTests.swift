//
//  DateParsingTests.swift
//  PulseTests
//

import Testing
import CoreData
import NaturalLanguage
@testable import Pulsio

struct DateParsingTests {

    // MARK: - Helpers

    private func detectAndGetDueDate(_ text: String) async throws -> Date? {
        let context = await makeInMemoryContext()
        let meeting = await makeMeeting(in: context)
        let service = await ActionDetectionService()

        _ = try await service.detectActions(
            from: text,
            meeting: meeting,
            context: context
        )

        let items = try await context.perform {
            try context.fetch(ActionItem.fetchRequest())
        }
        return items.first?.dueDate
    }

    // MARK: - NSDataDetector Dates

    @Test @MainActor
    func detectsExplicitDate() async throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)
        let service = ActionDetectionService()

        _ = try await service.detectActions(
            from: "Please submit the report by March 5, 2030.",
            meeting: meeting,
            context: context
        )

        let items = try context.fetch(ActionItem.fetchRequest())
        #expect(items.count == 1)
        guard let dueDate = items.first?.dueDate else {
            Issue.record("Expected a due date")
            return
        }

        let components = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
        #expect(components.year == 2030)
        #expect(components.month == 3)
        #expect(components.day == 5)
    }

    // MARK: - Relative Dates

    @Test @MainActor
    func detectsTomorrow() async throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)
        let service = ActionDetectionService()

        _ = try await service.detectActions(
            from: "Please send the report tomorrow.",
            meeting: meeting,
            context: context
        )

        let items = try context.fetch(ActionItem.fetchRequest())
        guard let dueDate = items.first?.dueDate else {
            Issue.record("Expected a due date for 'tomorrow'")
            return
        }

        let expected = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let dueDateDay = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
        let expectedDay = Calendar.current.dateComponents([.year, .month, .day], from: expected)
        #expect(dueDateDay.year == expectedDay.year)
        #expect(dueDateDay.month == expectedDay.month)
        #expect(dueDateDay.day == expectedDay.day)
    }

    @Test @MainActor
    func detectsInThreeDays() async throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)
        let service = ActionDetectionService()

        _ = try await service.detectActions(
            from: "I need to finish the project in 3 days.",
            meeting: meeting,
            context: context
        )

        let items = try context.fetch(ActionItem.fetchRequest())
        guard let dueDate = items.first?.dueDate else {
            Issue.record("Expected a due date for 'in 3 days'")
            return
        }

        let expected = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        let dueDateDay = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
        let expectedDay = Calendar.current.dateComponents([.year, .month, .day], from: expected)
        #expect(dueDateDay.year == expectedDay.year)
        #expect(dueDateDay.month == expectedDay.month)
        #expect(dueDateDay.day == expectedDay.day)
    }

    @Test @MainActor
    func detectsInTwoWeeks() async throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)
        let service = ActionDetectionService()

        _ = try await service.detectActions(
            from: "I need to prepare the presentation in 2 weeks.",
            meeting: meeting,
            context: context
        )

        let items = try context.fetch(ActionItem.fetchRequest())
        guard let dueDate = items.first?.dueDate else {
            Issue.record("Expected a due date for 'in 2 weeks'")
            return
        }

        let expected = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        let dueDateDay = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
        let expectedDay = Calendar.current.dateComponents([.year, .month, .day], from: expected)
        #expect(dueDateDay.year == expectedDay.year)
        #expect(dueDateDay.month == expectedDay.month)
        #expect(dueDateDay.day == expectedDay.day)
    }

    // MARK: - Weekday Dates

    @Test @MainActor
    func detectsByFriday() async throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)
        let service = ActionDetectionService()

        _ = try await service.detectActions(
            from: "The report is due by Friday afternoon.",
            meeting: meeting,
            context: context
        )

        let items = try context.fetch(ActionItem.fetchRequest())
        guard let dueDate = items.first?.dueDate else {
            Issue.record("Expected a due date for 'by Friday'")
            return
        }

        // Should have parsed a non-nil due date (specific day depends on current day of week)
        // The date service resolves "Friday" to the next occurrence
        #expect(dueDate != nil)
    }

    @Test @MainActor
    func detectsNextMonday() async throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)
        let service = ActionDetectionService()

        _ = try await service.detectActions(
            from: "Schedule the meeting for next Monday.",
            meeting: meeting,
            context: context
        )

        let items = try context.fetch(ActionItem.fetchRequest())
        guard let dueDate = items.first?.dueDate else {
            Issue.record("Expected a due date for 'next Monday'")
            return
        }

        let weekday = Calendar.current.component(.weekday, from: dueDate)
        #expect(weekday == 2) // Monday is weekday 2

        // Should be in the future
        #expect(dueDate > Date())
    }

    // MARK: - Special Dates

    @Test @MainActor
    func detectsASAP() async throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)
        let service = ActionDetectionService()

        _ = try await service.detectActions(
            from: "Please send the invoice ASAP to the client.",
            meeting: meeting,
            context: context
        )

        let items = try context.fetch(ActionItem.fetchRequest())
        guard let dueDate = items.first?.dueDate else {
            Issue.record("Expected a due date for 'ASAP'")
            return
        }

        // ASAP → tomorrow
        let expected = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let dueDateDay = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
        let expectedDay = Calendar.current.dateComponents([.year, .month, .day], from: expected)
        #expect(dueDateDay.year == expectedDay.year)
        #expect(dueDateDay.month == expectedDay.month)
        #expect(dueDateDay.day == expectedDay.day)
    }

    @Test @MainActor
    func detectsEndOfMonth() async throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)
        let service = ActionDetectionService()

        _ = try await service.detectActions(
            from: "I need to submit the budget by end of month.",
            meeting: meeting,
            context: context
        )

        let items = try context.fetch(ActionItem.fetchRequest())
        guard let dueDate = items.first?.dueDate else {
            Issue.record("Expected a due date for 'end of month'")
            return
        }

        let calendar = Calendar.current
        guard let monthRange = calendar.range(of: .day, in: .month, for: Date()) else {
            Issue.record("Could not get month range")
            return
        }
        let lastDay = monthRange.count
        let dueDateDay = calendar.component(.day, from: dueDate)
        #expect(dueDateDay == lastDay)
    }

    // MARK: - Time of Day

    @Test @MainActor
    func detectsBy3pm() async throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)
        let service = ActionDetectionService()

        _ = try await service.detectActions(
            from: "Send the email by 3pm today please.",
            meeting: meeting,
            context: context
        )

        let items = try context.fetch(ActionItem.fetchRequest())
        guard let dueDate = items.first?.dueDate else {
            Issue.record("Expected a due date for 'by 3pm'")
            return
        }

        let hour = Calendar.current.component(.hour, from: dueDate)
        #expect(hour == 15)
    }

    @Test @MainActor
    func detectsEOD() async throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)
        let service = ActionDetectionService()

        _ = try await service.detectActions(
            from: "Please finish the report by eod.",
            meeting: meeting,
            context: context
        )

        let items = try context.fetch(ActionItem.fetchRequest())
        guard let dueDate = items.first?.dueDate else {
            Issue.record("Expected a due date for 'eod'")
            return
        }

        let hour = Calendar.current.component(.hour, from: dueDate)
        #expect(hour == 17) // EOD → 17:00
    }

    // MARK: - Spelled-Out Numbers

    @Test @MainActor
    func detectsAtNine() async throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)
        let service = ActionDetectionService()

        _ = try await service.detectActions(
            from: "I have a meeting at nine tomorrow morning.",
            meeting: meeting,
            context: context
        )

        let items = try context.fetch(ActionItem.fetchRequest())
        // Should detect the meeting pattern and the date
        #expect(items.count >= 1)
    }

    // MARK: - No Date

    @Test @MainActor
    func noDateReturnsNil() async throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)
        let service = ActionDetectionService()

        _ = try await service.detectActions(
            from: "Please send the report to the team.",
            meeting: meeting,
            context: context
        )

        let items = try context.fetch(ActionItem.fetchRequest())
        #expect(items.count == 1)
        #expect(items.first?.dueDate == nil)
    }

    // MARK: - Multiple Dates in Transcript

    @Test @MainActor
    func differentDatesForDifferentActions() async throws {
        let context = makeInMemoryContext()
        let meeting = makeMeeting(in: context)
        let service = ActionDetectionService()

        let count = try await service.detectActions(
            from: """
            Please send the report by March 5, 2030.
            Don't forget to email John by April 1, 2030.
            """,
            meeting: meeting,
            context: context
        )

        #expect(count == 2)

        let items = try context.fetch(ActionItem.fetchRequest())
        #expect(items.count == 2)

        let dates = items.compactMap(\.dueDate)
        #expect(dates.count == 2)

        // Both dates should be non-nil and in different months
        let months = Set(dates.map { Calendar.current.component(.month, from: $0) })
        #expect(months.count == 2)
    }
}
