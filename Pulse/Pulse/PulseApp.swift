//
//  PulseApp.swift
//  Pulse
//

import SwiftUI
import CoreData
import AppIntents

@main
struct PulseApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        NSLog("🚀 PULSE APP LAUNCHED 🚀")
        print("🚀 PULSE APP LAUNCHED (print) 🚀")

        // Register App Shortcuts with Siri
        PulseShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
