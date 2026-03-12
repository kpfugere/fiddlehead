import SwiftUI

/// Shown when the user hits the 10-recording free cap and tries to record.
struct PaywallView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var showKeyEntry = false
    @State private var licenseKey = ""

    var body: some View {
        VStack(spacing: FiddleheadTheme.paddingLarge) {
            Text("free limit reached")
                .font(FiddleheadTheme.mono(16, weight: .bold))
                .foregroundStyle(FiddleheadTheme.textPrimary)

            Text("you've used all \(LicenseManager.freeRecordingLimit) free recordings. unlock fiddlehead to keep taking notes.")
                .font(FiddleheadTheme.mono(12))
                .foregroundStyle(FiddleheadTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: { licenseManager.openCheckout() }) {
                Text("unlock fiddlehead — $29")
                    .font(FiddleheadTheme.mono(14, weight: .medium))
                    .foregroundStyle(FiddleheadTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(FiddleheadTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: FiddleheadTheme.cornerRadius))
            }
            .buttonStyle(.plain)

            if showKeyEntry {
                VStack(spacing: FiddleheadTheme.paddingSmall) {
                    TextField("license key", text: $licenseKey)
                        .textFieldStyle(.plain)
                        .font(FiddleheadTheme.monoFixed(12))
                        .foregroundStyle(FiddleheadTheme.textPrimary)
                        .padding(FiddleheadTheme.paddingSmall)
                        .background(FiddleheadTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: FiddleheadTheme.cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: FiddleheadTheme.cornerRadius)
                                .stroke(FiddleheadTheme.border, lineWidth: 1)
                        )

                    Button(action: {
                        Task { await licenseManager.activateLicense(licenseKey) }
                    }) {
                        if licenseManager.isActivating {
                            ProgressView()
                                .controlSize(.small)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        } else {
                            Text("activate")
                                .font(FiddleheadTheme.mono(12, weight: .medium))
                                .foregroundStyle(FiddleheadTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                    }
                    .buttonStyle(.plain)
                    .background(FiddleheadTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: FiddleheadTheme.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: FiddleheadTheme.cornerRadius)
                            .stroke(FiddleheadTheme.border, lineWidth: 1)
                    )
                    .disabled(licenseManager.isActivating || licenseKey.isEmpty)

                    if let error = licenseManager.activationError {
                        Text(error)
                            .font(FiddleheadTheme.mono(10))
                            .foregroundStyle(FiddleheadTheme.recording)
                    }
                }
            } else {
                Button(action: { showKeyEntry = true }) {
                    Text("i have a license key")
                        .font(FiddleheadTheme.mono(11))
                        .foregroundStyle(FiddleheadTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FiddleheadTheme.paddingXL)
    }
}
