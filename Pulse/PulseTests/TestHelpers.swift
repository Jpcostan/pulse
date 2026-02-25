//
//  TestHelpers.swift
//  PulseTests
//

import CoreData
@testable import Pulsio

/// Create an in-memory Core Data context for testing
@MainActor
func makeInMemoryContext() -> NSManagedObjectContext {
    let controller = PersistenceController(inMemory: true)
    return controller.container.viewContext
}

/// Create a Meeting entity in the given context
@MainActor
func makeMeeting(in context: NSManagedObjectContext, title: String = "Test Meeting") -> Meeting {
    let meeting = Meeting(context: context)
    meeting.id = UUID()
    meeting.title = title
    meeting.createdAt = Date()
    meeting.status = "processing"
    try? context.save()
    return meeting
}
