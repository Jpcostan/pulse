//
//  RemindersServiceTests.swift
//  PulseTests
//

import Testing
import Foundation
import EventKit
@testable import Pulsio

struct RemindersServiceTests {

    // MARK: - Error Descriptions

    @Test
    func remindersPermissionDeniedErrorDescription() {
        let error = RemindersService.RemindersError.remindersPermissionDenied
        #expect(error.errorDescription?.contains("Reminders access was denied") == true)
    }

    @Test
    func calendarPermissionDeniedErrorDescription() {
        let error = RemindersService.RemindersError.calendarPermissionDenied
        #expect(error.errorDescription?.contains("Calendar access was denied") == true)
    }

    @Test
    func noDefaultRemindersListErrorDescription() {
        let error = RemindersService.RemindersError.noDefaultRemindersList
        #expect(error.errorDescription?.contains("No default reminders list") == true)
    }

    @Test
    func noDefaultCalendarErrorDescription() {
        let error = RemindersService.RemindersError.noDefaultCalendar
        #expect(error.errorDescription?.contains("No default calendar") == true)
    }

    @Test
    func reminderCreationFailedErrorDescription() {
        let underlying = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "save error"])
        let error = RemindersService.RemindersError.reminderCreationFailed(underlying)
        #expect(error.errorDescription?.contains("Failed to create reminder") == true)
    }

    @Test
    func saveFailedErrorDescription() {
        let underlying = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "disk full"])
        let error = RemindersService.RemindersError.saveFailed(underlying)
        #expect(error.errorDescription?.contains("Failed to save") == true)
    }
}
