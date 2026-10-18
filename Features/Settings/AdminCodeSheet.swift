import SwiftUI

/// The gate in front of the settings.
///
/// Six digits, and a delay that grows after repeated wrong tries. It keeps a
/// curious member out of the tokens and the erase button; it is not pretending
/// to stop someone who takes the device home (ADR 0002).
struct AdminCodeSheet: View {
    @Environment(\.metrics) private var metrics
    @Environment(\.dismiss) private var dismiss

    let verifier: AdminCodeVerifier
    var onUnlocked: () -> Void

    @State private var code = ""
    @State private var message: String?
    @State private var lockedUntil: Date?

    var body: some View {
        NavigationStack {
            VStack(spacing: metrics.sectionSpacing) {
                Image(systemName: "lock")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text("Enter the admin code")
                    .font(.title2.weight(.semibold))

                SecureField("Code", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .monospaced()
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .padding(14)
                    .background(.background, in: .rect(cornerRadius: metrics.cardCornerRadius))
                    .onChange(of: code) { _, newValue in
                        let digits = newValue.filter(\.isNumber)
                        code = String(digits.prefix(AdminCodeVerifier.length))
                        if code.count == AdminCodeVerifier.length { check() }
                    }

                if let message {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(Color.stopAction)
                        .multilineTextAlignment(.center)
                }

                if let lockedUntil {
                    // Counts down rather than leaving someone guessing how long
                    // "try again later" means.
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, lockedUntil.timeIntervalSince(context.date))
                        if remaining > 0 {
                            Text("Try again in \(Int(remaining.rounded(.up))) s")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(metrics.gutter)
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
        .presentationSizing(.form)
        .resolvedLayoutMetrics()
    }

    private func check() {
        do {
            try verifier.verify(code)
            onUnlocked()
        } catch let failure as AdminCodeVerifier.Failure {
            code = ""
            switch failure {
            case .incorrect(let lockedFor):
                message = String(localized: "That code is not right.")
                lockedUntil = lockedFor > 0 ? Date().addingTimeInterval(lockedFor) : nil
            case .lockedOut(let remaining):
                message = String(localized: "Too many attempts.")
                lockedUntil = Date().addingTimeInterval(remaining)
            case .malformed:
                message = String(localized: "Six digits, please.")
            case .storage:
                message = String(localized: "No code is set on this device.")
            }
        } catch {
            code = ""
            message = String(localized: "That code is not right.")
        }
    }
}

#Preview {
    let configuration = AppConfiguration(defaults: UserDefaults(suiteName: "preview-admin") ?? .standard)
    let secrets = InMemorySecretStore()
    let verifier = AdminCodeVerifier(secrets: secrets, configuration: configuration)
    try? verifier.setCode("123456")

    return AdminCodeSheet(verifier: verifier, onUnlocked: {})
}
