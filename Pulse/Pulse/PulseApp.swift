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
    // Initialize StoreService singleton at app launch so entitlements are loaded early
    private let storeService = StoreService.shared

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

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
                .onAppear {
                    if !hasCompletedOnboarding {
                        showOnboarding = true
                    }
                }
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView(onComplete: {
                        hasCompletedOnboarding = true
                        showOnboarding = false
                    })
                }
        }
    }
}
