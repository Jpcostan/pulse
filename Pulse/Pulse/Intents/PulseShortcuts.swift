//
//  PulseShortcuts.swift
//  Pulse
//
//  Registers App Shortcuts with Siri for voice and Shortcuts app access

import AppIntents

struct PulseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartMeetingIntent(),
            phrases: [
                "Start a meeting in \(.applicationName)",
                "Start recording in \(.applicationName)",
                "Record a meeting with \(.applicationName)"
            ],
            shortTitle: "Start Meeting",
            systemImageName: "mic.fill"
        )

        AppShortcut(
            intent: StopMeetingIntent(),
            phrases: [
                "Stop meeting in \(.applicationName)",
                "Stop recording in \(.applicationName)"
            ],
            shortTitle: "Stop Meeting",
            systemImageName: "stop.fill"
        )
    }
}
