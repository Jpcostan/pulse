//
//  OnboardingView.swift
//  Pulse
//

import SwiftUI
import StoreKit

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0
    @State private var isPurchasing = false
    private var store: StoreService { StoreService.shared }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                welcomeSlide
                    .tag(0)
                howItWorksSlide
                    .tag(1)
                getStartedSlide
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)

            // Bottom button area (slides 1-2 only)
            if currentPage < 2 {
                Button {
                    withAnimation {
                        currentPage += 1
                    }
                } label: {
                    Text("Next")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Slide 1: Welcome

    private var welcomeSlide: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.tint)

                Text("Welcome to Pulsio")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Turn meetings into actions — automatically.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                Text("Record your meetings, detect action items on-device, and create Apple Reminders & Calendar events — all privately, with no cloud processing.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Slide 2: How It Works

    private var howItWorksSlide: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("How It Works")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 24) {
                featureRow(
                    icon: "mic.fill",
                    title: "Record your meeting",
                    description: "Tap record and speak naturally."
                )
                featureRow(
                    icon: "text.magnifyingglass",
                    title: "AI detects action items",
                    description: "On-device intelligence finds tasks in your words."
                )
                featureRow(
                    icon: "checklist",
                    title: "Create reminders & events",
                    description: "Send actions to Apple Reminders & Calendar."
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text("All processing happens on your device.\nYour data stays private.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Slide 3: Get Started (Pro Upgrade)

    private var getStartedSlide: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)

                Text("Unlock Unlimited Recording")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Free recordings are limited to 3 minutes.\nGo Pro for unlimited recording length.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Feature comparison
            VStack(spacing: 16) {
                comparisonRow("Recording length", free: "3 min", pro: "60 min")
                comparisonRow("Action detection", free: "Included", pro: "Included")
                comparisonRow("Reminders & Calendar", free: "Included", pro: "Included")
                Divider()
                HStack {
                    Text("Price")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("Free")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 70)
                    Text(store.product?.displayPrice ?? "$5.99")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                        .frame(width: 70)
                }
            }
            .padding(20)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()

            // Purchase + skip buttons
            VStack(spacing: 16) {
                Button {
                    isPurchasing = true
                    Task {
                        await store.purchase()
                        isPurchasing = false
                        if store.isPro {
                            onComplete()
                        }
                    }
                } label: {
                    Group {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Go Pro — \(store.product?.displayPrice ?? "$5.99")")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPurchasing)

                Button("Continue for free") {
                    onComplete()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if let error = store.purchaseError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.bottom, 56)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Helper Views

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func comparisonRow(_ feature: String, free: String, pro: String) -> some View {
        HStack {
            Text(feature)
                .font(.subheadline)
            Spacer()
            Text(free)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 70)
            Text(pro)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 70)
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
