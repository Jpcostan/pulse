//
//  PaywallView.swift
//  Pulse
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    private var store = StoreService.shared

    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // App branding
                VStack(spacing: 16) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.tint)

                    Text("Unlock Unlimited Recordings")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Free recordings are limited to 3 minutes.\nUpgrade to Pro for unlimited recording length.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Features
                VStack(alignment: .leading, spacing: 12) {
                    featureRow("Unlimited recording length", icon: "infinity")
                    featureRow("Up to 60 minutes per session", icon: "clock")
                    featureRow("One-time purchase, lifetime access", icon: "checkmark.seal")
                }
                .padding(.horizontal, 24)

                Spacer()

                // Purchase button
                VStack(spacing: 16) {
                    Button {
                        isPurchasing = true
                        Task {
                            await store.purchase()
                            isPurchasing = false
                            if store.isPro {
                                dismiss()
                            }
                        }
                    } label: {
                        Group {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(store.product?.displayPrice ?? "$5.99")
                                + Text(" — Lifetime")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPurchasing)

                    // Restore purchases
                    Button("Restore Purchases") {
                        Task {
                            await store.restorePurchases()
                            if store.isPro {
                                dismiss()
                            }
                        }
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
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func featureRow(_ text: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 24)
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    PaywallView()
}
