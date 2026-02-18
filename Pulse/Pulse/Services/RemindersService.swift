//
//  RemindersService.swift
//  Pulse
//

import Foundation
@preconcurrency import EventKit
import CoreData
import Combine

@MainActor
final class RemindersService: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var remindersAuthStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var calendarAuthStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var isCreatingReminders = false
    @Published private(set) var error: RemindersError?

    // MARK: - Private Properties

    private let eventStore = EKEventStore()

    // MARK: - Error Types

    enum RemindersError: LocalizedError {
        case remindersPermissionDenied
        case calendarPermissionDenied
        case noDefaultRemindersList
        case noDefaultCalendar
        case reminderCreationFailed(Error)
        case calendarEventCreationFailed(Error)
        case saveFailed(Error)

        var errorDescription: String? {
            switch self {
            case .remindersPermissionDenied:
                return "Reminders access was denied. Please enable it in Settings > Privacy & Security > Reminders."
            case .calendarPermissionDenied:
                return "Calendar access was denied. Please enable it in Settings > Privacy & Security > Calendars."
            case .noDefaultRemindersList:
                return "No default reminders list found. Please create a reminders list in the Reminders app."
            case .noDefaultCalendar:
                return "No default calendar found. Please create a calendar in the Calendar app."
            case .reminderCreationFailed(let error):
                return "Failed to create reminder: \(error.localizedDescription)"
            case .calendarEventCreationFailed(let error):
                return "Failed to create calendar event: \(error.localizedDescription)"
            case .saveFailed(let error):
                return "Failed to save: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Initialization

    init() {
        updateAuthorizationStatuses()
    }

    // MARK: - Authorization

    /// Update cached authorization statuses
    func updateAuthorizationStatuses() {
        remindersAuthStatus = EKEventStore.authorizationStatus(for: .reminder)
        calendarAuthStatus = EKEventStore.authorizationStatus(for: .event)
    }

    /// Request access to Reminders
    func requestRemindersAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            await MainActor.run {
                updateAuthorizationStatuses()
            }
            return granted
        } catch {
            NSLog("Reminders access request failed: %@", error.localizedDescription)
            return false
        }
    }

    /// Request access to Calendar
    func requestCalendarAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                updateAuthorizationStatuses()
            }
            return granted
        } catch {
            NSLog("Calendar access request failed: %@", error.localizedDescription)
            return false
        }
    }

    /// Check if reminders access is authorized
    var hasRemindersAccess: Bool {
        remindersAuthStatus == .fullAccess
    }

    /// Check if calendar access is authorized
    var hasCalendarAccess: Bool {
        calendarAuthStatus == .fullAccess
    }

    // MARK: - Create Reminders

    /// Create reminders for the given action items
    /// - Parameters:
    ///   - actionItems: Array of ActionItem entities to create reminders from
    ///   - context: Core Data context for saving reminder identifiers
    /// - Returns: Number of reminders successfully created
    func createReminders(
        from actionItems: [ActionItem],
        context: NSManagedObjectContext
    ) async throws -> Int {
        isCreatingReminders = true
        error = nil

        defer {
            isCreatingReminders = false
        }

        // Check/request permission
        if !hasRemindersAccess {
            let granted = await requestRemindersAccess()
            if !granted {
                throw RemindersError.remindersPermissionDenied
            }
        }

        // Get default reminders list
        guard let defaultList = eventStore.defaultCalendarForNewReminders() else {
            throw RemindersError.noDefaultRemindersList
        }

        var createdCount = 0

        for item in actionItems {
            // Skip items that already have a reminder
            if item.reminderIdentifier != nil {
                NSLog("Skipping item '%@' - already has reminder", item.title ?? "Untitled")
                continue
            }

            do {
                let reminder = EKReminder(eventStore: eventStore)
                reminder.calendar = defaultList
                reminder.title = item.title ?? "Untitled Action"

                // Add source sentence as note if available
                if let source = item.sourceSentence, !source.isEmpty {
                    reminder.notes = "From meeting: \"\(source)\""
                }

                // Set due date if available
                if let dueDate = item.dueDate {
                    let dueDateComponents = Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute],
                        from: dueDate
                    )
                    reminder.dueDateComponents = dueDateComponents

                    // Also add an alarm at the due date
                    let alarm = EKAlarm(absoluteDate: dueDate)
                    reminder.addAlarm(alarm)
                }

                // Save the reminder
                try eventStore.save(reminder, commit: true)

                // Capture values before entering perform block to avoid Sendable warnings
                let reminderIdentifier = reminder.calendarItemIdentifier
                let itemObjectID = item.objectID

                // Store the reminder identifier in Core Data
                await context.perform {
                    if let actionItem = try? context.existingObject(with: itemObjectID) as? ActionItem {
                        actionItem.reminderIdentifier = reminderIdentifier
                        try? context.save()
                    }
                }

                createdCount += 1
                NSLog("Created reminder: %@ (ID: %@)", reminder.title ?? "", reminderIdentifier)

            } catch {
                NSLog("Failed to create reminder for '%@': %@", item.title ?? "", error.localizedDescription)
            }
        }

        return createdCount
    }

    // MARK: - Create Calendar Events

    /// Create calendar events for action items with due dates
    /// - Parameters:
    ///   - actionItems: Array of ActionItem entities to create events from
    ///   - context: Core Data context for saving event identifiers
    /// - Returns: Number of events successfully created
    func createCalendarEvents(
        from actionItems: [ActionItem],
        context: NSManagedObjectContext
    ) async throws -> Int {
        // Check/request permission
        if !hasCalendarAccess {
            let granted = await requestCalendarAccess()
            if !granted {
                throw RemindersError.calendarPermissionDenied
            }
        }

        // Get default calendar
        guard let defaultCalendar = eventStore.defaultCalendarForNewEvents else {
            throw RemindersError.noDefaultCalendar
        }

        var createdCount = 0

        for item in actionItems {
            // Only create events for items with due dates
            guard let dueDate = item.dueDate else { continue }

            // Skip items that already have a calendar event
            if item.calendarEventIdentifier != nil {
                NSLog("Skipping item '%@' - already has calendar event", item.title ?? "Untitled")
                continue
            }

            do {
                let event = EKEvent(eventStore: eventStore)
                event.calendar = defaultCalendar
                event.title = item.title ?? "Untitled Action"

                // Add source sentence as notes
                if let source = item.sourceSentence, !source.isEmpty {
                    event.notes = "From meeting: \"\(source)\""
                }

                // Set as all-day event on the due date
                event.startDate = dueDate
                event.endDate = dueDate
                event.isAllDay = true

                // Add reminder alert 1 hour before (for all-day, this is morning of)
                let alarm = EKAlarm(relativeOffset: -3600) // 1 hour before
                event.addAlarm(alarm)

                // Save the event
                try eventStore.save(event, span: .thisEvent, commit: true)

                // Capture values before entering perform block to avoid Sendable warnings
                let eventIdentifier = event.eventIdentifier
                let itemObjectID = item.objectID

                // Store the event identifier in Core Data
                await context.perform {
                    if let actionItem = try? context.existingObject(with: itemObjectID) as? ActionItem {
                        actionItem.calendarEventIdentifier = eventIdentifier
                        try? context.save()
                    }
                }

                createdCount += 1
                NSLog("Created calendar event: %@ (ID: %@)", event.title ?? "", eventIdentifier ?? "")

            } catch {
                NSLog("Failed to create calendar event for '%@': %@", item.title ?? "", error.localizedDescription)
            }
        }

        return createdCount
    }

    // MARK: - Delete Reminders/Events

    /// Delete a reminder by its identifier
    func deleteReminder(identifier: String) throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            return
        }
        try eventStore.remove(reminder, commit: true)
    }

    /// Delete a calendar event by its identifier
    func deleteCalendarEvent(identifier: String) throws {
        guard let event = eventStore.event(withIdentifier: identifier) else {
            return
        }
        try eventStore.remove(event, span: .thisEvent, commit: true)
    }

    // MARK: - Check Sync Status

    /// Check if a reminder still exists
    func reminderExists(identifier: String) -> Bool {
        return eventStore.calendarItem(withIdentifier: identifier) != nil
    }

    /// Check if a calendar event still exists
    func calendarEventExists(identifier: String) -> Bool {
        return eventStore.event(withIdentifier: identifier) != nil
    }
}
