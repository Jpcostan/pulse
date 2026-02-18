//
//  LoggingService.swift
//  Pulse
//

import Foundation
import OSLog

/// Centralized logging using the modern os.Logger API
/// Logs appear in Xcode console AND Console.app (filter by "Pulse")
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.jpcostan.Pulse"

    static let transcription = Logger(subsystem: subsystem, category: "Transcription")
    static let actionDetection = Logger(subsystem: subsystem, category: "ActionDetection")
    static let audio = Logger(subsystem: subsystem, category: "Audio")
    static let reminders = Logger(subsystem: subsystem, category: "Reminders")
    static let general = Logger(subsystem: subsystem, category: "General")
}
