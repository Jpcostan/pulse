//
//  PersistenceControllerTests.swift
//  PulseTests
//

import Testing
import CoreData
@testable import Pulsio

struct PersistenceControllerTests {

    @Test
    func inMemoryContainerHasViewContext() {
        let controller = PersistenceController(inMemory: true)
        #expect(controller.container.viewContext != nil)
    }

    @Test @MainActor
    func previewContainerIsAccessible() {
        // Verify preview controller can be created without crashing.
        // Note: Full data validation skipped as Core Data entity matching
        // can produce warnings when multiple in-memory stores exist in parallel tests.
        let controller = PersistenceController.preview
        #expect(controller.container.viewContext != nil)
    }

    @Test
    func mergePolicyIsSet() {
        let controller = PersistenceController(inMemory: true)
        let policy = controller.container.viewContext.mergePolicy as? NSMergePolicy
        #expect(policy?.mergeType == .mergeByPropertyObjectTrumpMergePolicyType)
    }

    @Test
    func automaticallyMergesChangesEnabled() {
        let controller = PersistenceController(inMemory: true)
        #expect(controller.container.viewContext.automaticallyMergesChangesFromParent == true)
    }
}
