//
//  SettingsView.swift
//  Pulse
//

import SwiftUI

struct SettingsView: View {
    private var store = StoreService.shared

    @State private var showPaywall = false
    @State private var isRestoring = false

    var body: some View {
        List {
            // Account section
            Section("Account") {
                HStack {
                    Text("Status")
                    Spacer()
                    if store.isPro {
                        Text("Pro — Lifetime")
                            .foregroundStyle(.green)
                            .fontWeight(.medium)
                    } else {
                        Text("Free")
                            .foregroundStyle(.secondary)
                    }
                }

                if !store.isPro {
                    Button("Upgrade to Pro") {
                        showPaywall = true
                    }
                }
            }

            // Purchases section
            Section {
                Button {
                    isRestoring = true
                    Task {
                        await store.restorePurchases()
                        isRestoring = false
                    }
                } label: {
                    HStack {
                        Text("Restore Purchases")
                        Spacer()
                        if isRestoring {
                            ProgressView()
                        }
                    }
                }
                .disabled(isRestoring)

                if let error = store.purchaseError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // Live Activity section
            Section("Live Activity") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recording Widget")
                        .font(.headline)
                    Text("To see the recording timer on your Lock Screen, add the Pulse Live Activity widget. Long-press your Lock Screen, tap Customize, and add the Pulse widget.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // About section
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Build")
                    Spacer()
                    Text(buildNumber)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
