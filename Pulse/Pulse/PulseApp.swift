//
//  PulseApp.swift
//  Pulse
//

import SwiftUI
import CoreData
import AppIntents
import ActivityKit

@main
struct PulseApp: App {
    let persistenceController = PersistenceController.shared
    // Initialize StoreService singleton at app launch so entitlements are loaded early
    private let storeService = StoreService.shared

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    init() {
        // Register App Shortcuts with Siri
        PulseShortcuts.updateAppShortcutParameters()

        // Clean up any stale Live Activities left over from a force-kill
        cleanUpStaleLiveActivities()
    }

    private func cleanUpStaleLiveActivities() {
        for activity in Activity<RecordingActivityAttributes>.activities {
            Task {
                await activity.end(
                    .init(
                        state: RecordingActivityAttributes.ContentState(
                            elapsedSeconds: 0,
                            isRecording: false
                        ),
                        staleDate: nil
                    ),
                    dismissalPolicy: .immediate
                )
            }
        }
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
