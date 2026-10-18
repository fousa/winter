import SwiftData
import SwiftUI

/// First launch: the few things the app cannot work out for itself.
///
/// One step per page, large fields, and nothing hidden behind a gesture — this
/// is done once, by someone standing in a clubhouse, possibly on a device
/// mounted on a wall. Same steps in both size classes (ADR 0009).
struct SetupView: View {
    @Environment(\.metrics) private var metrics
    @Environment(\.locale) private var locale

    @State private var model: SetupModel
    var onFinish: () -> Void

    init(model: SetupModel, onFinish: @escaping () -> Void) {
        self._model = State(initialValue: model)
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 0) {
            progress
                .padding(metrics.gutter)

            ScrollView {
                VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    switch model.step {
                    case .welcome: welcome
                    case .connection: connection
                    case .club: club
                    case .adminCode: adminCode
                    case .done: done
                    }
                }
                .frame(maxWidth: 620, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(metrics.gutter)
            }

            footer
                .padding(metrics.gutter)
        }
        .background(Color(.systemGroupedBackground))
        .resolvedLayoutMetrics()
    }

    // MARK: - Chrome

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(SetupModel.Step.allCases) { step in
                Capsule()
                    .fill(step.rawValue <= model.step.rawValue ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(height: 6)
            }
        }
        .accessibilityLabel(Text("Step \(model.step.rawValue + 1) of \(SetupModel.Step.allCases.count)"))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if model.step != .welcome, model.step != .done {
                Button("Back") { model.goBack() }
                    .frame(minHeight: LayoutMetrics.minimumTapTarget)
                    .buttonStyle(.glass)
            }

            Spacer(minLength: 0)

            Button {
                if model.step == .done {
                    onFinish()
                } else {
                    model.advance()
                }
            } label: {
                Text(model.step == .done ? "Start using Winter" : "Next")
                    .frame(minWidth: 140, minHeight: metrics.primaryButtonHeight)
            }
            .buttonStyle(.glassProminent)
            .disabled(!model.canAdvance)
        }
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to Winter")
                .font(.largeTitle.weight(.bold))
            Text("Members log their maintenance hours here with start and stop, without logging in. The hours are kept on this device and sent to zweef.app as soon as there is a connection.")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Label("Your club's schema name and an API key from zweef.app", systemImage: "key")
                Label("The time forgotten timers should stop", systemImage: "moon.stars")
                Label("A six-digit code to protect these settings", systemImage: "lock")
            }
            .font(.callout)
            .padding(.top, 8)
        }
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            header(
                "Connect to zweef.app",
                detail: "The schema name is in your club settings in zweef.app, and the API key is created on its admin pages."
            )

            VStack(spacing: 0) {
                field("Club schema", text: $model.clubSchema, managed: model.isManaged(.clubSchema))
                Divider()
                secureField("API key", text: $model.apiKey, managed: false)
            }
            .background(.background, in: .rect(cornerRadius: metrics.cardCornerRadius))

            // Said plainly and unconditionally: this is the one real risk the
            // app asks a club to accept (ADR 0013).
            Label("This key opens your club's whole zweef.app account — member data and finances included — and it is stored on this device. Keep the device somewhere safe, and if you lose it, create a new key in zweef.app straight away.", systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(Color.flag)

            testRow
        }
    }

    private var testRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Task { await model.testConnection() }
            } label: {
                if case .testing = model.testState {
                    ProgressView().frame(maxWidth: .infinity, minHeight: LayoutMetrics.minimumTapTarget)
                } else {
                    Label("Test connection", systemImage: "antenna.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity, minHeight: LayoutMetrics.minimumTapTarget)
                }
            }
            .buttonStyle(.glass)
            .disabled(!model.hasConnectionFields)

            switch model.testState {
            case .untested, .testing:
                Text("You can skip this and set it up later; the app works offline either way.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

            case .succeeded(let result):
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        result.clubName.map { String(localized: "Connected to \($0)") }
                            ?? String(localized: "Connected"),
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(Color.runningTimer)
                    (result.periodId == nil
                        ? Text("No maintenance period found yet.")
                        : Text("^[\(result.registrationCount) registration](inflect: true) in period \(result.periodId ?? 0)."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

            case .failed(let error):
                Label(message(for: error), systemImage: "xmark.circle.fill")
                    .foregroundStyle(Color.stopAction)
                    .font(.callout)
            }
        }
    }

    private var club: some View {
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            header(
                "Your club",
                detail: "The name appears as the title on the home screen. zweef.app does not always give it, so you can type it yourself."
            )

            VStack(spacing: 0) {
                field("Club name", text: $model.clubName, managed: false)
                Divider()
                HStack {
                    Text("Timers stop automatically at")
                    Spacer()
                    DatePicker(
                        "Timers stop automatically at",
                        selection: closingTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .disabled(model.isManaged(.closingTime))
                }
                .padding(14)
                Divider()
                HStack {
                    Text("Hours are written to zweef.app in")
                    Spacer()
                    Picker("Hours are written to zweef.app in", selection: $model.reportingLanguage) {
                        Text("English").tag(ReportingLanguage.english)
                        Text("Nederlands").tag(ReportingLanguage.dutch)
                        Text("Français").tag(ReportingLanguage.french)
                    }
                    .labelsHidden()
                }
                .padding(14)
            }
            .background(.background, in: .rect(cornerRadius: metrics.cardCornerRadius))

            Text("The board reads one consistent list, whichever language a member's own device is in.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var adminCode: some View {
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            header(
                "A code for these settings",
                detail: "Six digits. Members never need it — it only protects the settings, the tokens and the erase button. Store it with your other club passwords."
            )

            VStack(spacing: 0) {
                codeField("Code", text: $model.adminCode)
                Divider()
                codeField("Again", text: $model.adminCodeRepeat)
            }
            .background(.background, in: .rect(cornerRadius: metrics.cardCornerRadius))

            if let error = model.adminCodeError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Color.stopAction)
            } else if !model.adminCodeRepeat.isEmpty, model.adminCode != model.adminCodeRepeat {
                Text("The two codes are not the same.")
                    .font(.footnote)
                    .foregroundStyle(Color.stopAction)
            }

            Label("Forgotten it? The app has to be deleted and set up again, and hours that have not been uploaded are lost with it.", systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(Color.flag)
        }
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .scaledFont(size: 64, relativeTo: .largeTitle)
                .foregroundStyle(Color.runningTimer)

            Text("Ready")
                .font(.largeTitle.weight(.bold))
            Text("Members can start logging hours. The list of members arrives as soon as this device has a connection.")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Label("On a shared device, turn on Guided Access so the app cannot be left: Settings › Accessibility › Guided Access", systemImage: "lock.shield")
                Label("Reach these settings again by holding the title for three seconds", systemImage: "hand.tap")
            }
            .font(.callout)
            .padding(.top, 8)
        }
    }

    // MARK: - Pieces

    private func header(_ title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title.weight(.semibold))
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func field(_ label: LocalizedStringKey, text: Binding<String>, managed: Bool) -> some View {
        HStack {
            Text(label)
                .frame(width: 140, alignment: .leading)
            TextField(label, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(managed)
                .foregroundStyle(managed ? .secondary : .primary)
            if managed {
                Image(systemName: "building.2")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Managed by your organisation"))
            }
        }
        .padding(14)
    }

    private func secureField(_ label: LocalizedStringKey, text: Binding<String>, managed: Bool) -> some View {
        HStack {
            Text(label)
                .frame(width: 140, alignment: .leading)
            SecureField(label, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(managed)
            if managed {
                Image(systemName: "building.2")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Managed by your organisation"))
            }
        }
        .padding(14)
    }

    private func codeField(_ label: LocalizedStringKey, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .frame(width: 140, alignment: .leading)
            SecureField(label, text: text)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .monospaced()
                .onChange(of: text.wrappedValue) { _, newValue in
                    // Six digits, enforced as you type rather than complained
                    // about afterwards.
                    let digits = newValue.filter(\.isNumber)
                    text.wrappedValue = String(digits.prefix(AdminCodeVerifier.length))
                }
        }
        .padding(14)
    }

    private var closingTime: Binding<Date> {
        Binding {
            var components = DateComponents()
            components.hour = model.closingHour
            components.minute = model.closingMinute
            return Calendar.club.date(from: components) ?? Date()
        } set: { newValue in
            let parts = Calendar.club.dateComponents([.hour, .minute], from: newValue)
            model.closingHour = parts.hour ?? 21
            model.closingMinute = parts.minute ?? 0
        }
    }

    private func message(for error: ZweefError) -> String {
        switch error {
        case .notAuthorised:
            String(localized: "Refused: check the API key.")
        case .invalidConfiguration:
            String(localized: "That club schema cannot be used.")
        case .unreachable:
            String(localized: "No connection. You can continue and test again later.")
        case .server(let status):
            String(localized: "zweef.app had a problem (\(status)). Try again later.")
        case .rejected(let status, _):
            String(localized: "zweef.app refused the request (\(status)).")
        case .decoding:
            String(localized: "zweef.app answered something unexpected.")
        }
    }
}

#Preview("iPad", traits: .landscapeLeft) {
    SetupPreview()
}

#Preview("iPhone · French") {
    SetupPreview()
        .environment(\.locale, Locale(identifier: "fr"))
}

private struct SetupPreview: View {
    var body: some View {
        let container = try! WinterSchema.inMemoryContainer()
        let settings = AppSettings()
        container.mainContext.insert(settings)

        return SetupView(
            model: SetupModel(
                configuration: AppConfiguration(defaults: UserDefaults(suiteName: "preview") ?? .standard),
                secrets: InMemorySecretStore(),
                connection: ConnectionProvider(),
                settings: settings
            ),
            onFinish: {}
        )
        .modelContainer(container)
    }
}
