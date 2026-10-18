import SwiftData
import SwiftUI

/// Everything a club can change after setup, behind the admin code.
///
/// One `Form`, which is a `NavigationSplitView`'s detail on a tablet and the
/// whole screen on a phone — the standard settings shape in both size classes
/// (ADR 0009). Secrets are shown as "set" and never read back into a view.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \TaskDefinition.sortOrder) private var tasks: [TaskDefinition]

    let configuration: AppConfiguration
    let secrets: any SecretStore
    let connection: ConnectionProvider
    let settings: AppSettings

    @State private var clubName = ""
    @State private var proxyURL = ""
    @State private var clubSchema = ""
    @State private var newSecret = ""
    @State private var isChangingSecret = false
    @State private var newAdminCode = ""
    @State private var isChangingAdminCode = false
    @State private var isConfirmingErase = false
    @State private var testState: SetupModel.TestState = .untested
    @State private var feedback = 0

    var body: some View {
        NavigationStack {
            Form {
                connectionSection
                clubSection
                tasksSection
                adminSection
                dataSection
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                clubName = settings.clubName ?? ""
                proxyURL = configuration.proxyURL
                clubSchema = configuration.clubSchema
            }
            .sensoryFeedback(.success, trigger: feedback)
        }
    }

    // MARK: - Connection

    @ViewBuilder
    private var connectionSection: some View {
        Section {
            Picker("Connection", selection: Binding(
                get: { configuration.connectionMode },
                set: { configuration.connectionMode = $0 }
            )) {
                Text("Proxy").tag(ConnectionMode.proxy)
                Text("Direct").tag(ConnectionMode.direct)
            }
            .disabled(configuration.managedKeys.contains(.connectionMode))

            if configuration.connectionMode == .proxy {
                managedRow(.proxyURL) {
                    TextField("Proxy URL", text: $proxyURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                secretRow(
                    title: String(localized: "Device token"),
                    isSet: secrets.hasSecret(for: .deviceToken),
                    managed: configuration.managedKeys.contains(.deviceToken)
                )
            } else {
                managedRow(.clubSchema) {
                    TextField("Club schema", text: $clubSchema)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                secretRow(
                    title: String(localized: "API key"),
                    isSet: secrets.hasSecret(for: .apiKey),
                    managed: false
                )
                Label("The key gives access to all of your club's member and financial data.", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(Color.flag)
            }

            Button {
                Task { await test() }
            } label: {
                if case .testing = testState {
                    ProgressView()
                } else {
                    Text("Test connection")
                }
            }

            switch testState {
            case .untested, .testing:
                EmptyView()
            case .succeeded(let result):
                Label(
                    result.clubName.map { String(localized: "Connected to \($0)") } ?? String(localized: "Connected"),
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(Color.runningTimer)
                .font(.footnote)
            case .failed:
                Label("Could not connect with these details.", systemImage: "xmark.circle.fill")
                    .foregroundStyle(Color.stopAction)
                    .font(.footnote)
            }
        } header: {
            Text("Connection")
        } footer: {
            if !configuration.managedKeys.isEmpty {
                Text("Some values are managed by your organisation and cannot be changed here.")
            }
        }
    }

    private func managedRow(
        _ field: ManagedConfiguration.Field,
        @ViewBuilder content: () -> some View
    ) -> some View {
        let managed = configuration.managedKeys.contains(field)
        return HStack {
            content()
                .disabled(managed)
                .foregroundStyle(managed ? .secondary : .primary)
            if managed {
                Image(systemName: "building.2")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Managed by your organisation"))
            }
        }
    }

    /// Shows that a secret exists without ever putting it in a view.
    private func secretRow(title: String, isSet: Bool, managed: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(isSet ? "••••••• (set)" : "Not set")
                .foregroundStyle(.secondary)
            if !managed {
                Button("Change") { isChangingSecret = true }
                    .buttonStyle(.borderless)
            }
        }
        .alert("New value", isPresented: $isChangingSecret) {
            SecureField("Value", text: $newSecret)
                .textInputAutocapitalization(.never)
            Button("Save") { saveSecret() }
            Button("Cancel", role: .cancel) { newSecret = "" }
        } message: {
            Text("Paste the token or key. It goes straight into the Keychain.")
        }
    }

    // MARK: - Club

    private var clubSection: some View {
        Section("Club") {
            TextField("Club name", text: $clubName)

            DatePicker(
                "Timers stop at",
                selection: Binding(
                    get: {
                        Calendar.club.date(from: settings.closingComponents) ?? Date()
                    },
                    set: { newValue in
                        let parts = Calendar.club.dateComponents([.hour, .minute], from: newValue)
                        settings.closingHour = parts.hour ?? 21
                        settings.closingMinute = parts.minute ?? 0
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .disabled(configuration.managedKeys.contains(.closingTime))

            Picker("Hours are written in", selection: Binding(
                get: { ReportingLanguage(code: settings.reportingLanguageCode) },
                set: { settings.reportingLanguageCode = $0.code }
            )) {
                Text("English").tag(ReportingLanguage.english)
                Text("Nederlands").tag(ReportingLanguage.dutch)
                Text("Français").tag(ReportingLanguage.french)
            }
        }
    }

    // MARK: - Tasks

    private var tasksSection: some View {
        Section {
            ForEach(tasks) { task in
                HStack(spacing: 12) {
                    Image(systemName: task.symbolName)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(task.color.gradient, in: .rect(cornerRadius: 7))
                    TextField("Task", text: Binding(
                        get: { task.label },
                        set: { task.label = $0 }
                    ))
                    if task.asksForAircraft {
                        Image(systemName: "airplane")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text("Asks which aircraft"))
                    }
                }
            }
        } header: {
            Text("Tasks")
        } footer: {
            Text("Rename these to whatever your club calls them. The names are yours and are never translated.")
        }
    }

    // MARK: - Admin code

    private var adminSection: some View {
        Section("Admin code") {
            Button("Change the admin code") { isChangingAdminCode = true }
                .alert("New admin code", isPresented: $isChangingAdminCode) {
                    SecureField("Six digits", text: $newAdminCode)
                        .keyboardType(.numberPad)
                    Button("Save") { saveAdminCode() }
                    Button("Cancel", role: .cancel) { newAdminCode = "" }
                } message: {
                    Text("Six digits. Store it with your other club passwords.")
                }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section {
            Button("Erase everything on this device", role: .destructive) {
                isConfirmingErase = true
            }
            .confirmationDialog(
                "Erase everything on this device?",
                isPresented: $isConfirmingErase,
                titleVisibility: .visible
            ) {
                Button("Erase", role: .destructive) { erase() }
                Button("Cancel", role: .cancel) {}
            } message: {
                (pendingUploads > 0
                    ? Text("^[\(pendingUploads) session](inflect: true) has not reached zweef.app yet and will be lost.")
                    : Text("Members, tasks, hours and the connection are all removed."))
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Hours already in zweef.app stay there.")
        }
    }

    // MARK: - Actions

    private var pendingUploads: Int {
        let sessions = (try? context.fetch(FetchDescriptor<WorkSession>())) ?? []
        return sessions.filter { $0.syncState != .uploaded }.count
    }

    private func save() {
        configuration.proxyURL = proxyURL
        configuration.clubSchema = clubSchema
        settings.setClubName(typed: clubName)
        try? context.save()
        connection.update(ConnectionSettings(configuration: configuration, secrets: secrets))
    }

    private func saveSecret() {
        let key: SecretKey = configuration.connectionMode == .proxy ? .deviceToken : .apiKey
        try? secrets.setSecret(newSecret.trimmed, for: key)
        newSecret = ""
        connection.update(ConnectionSettings(configuration: configuration, secrets: secrets))
        feedback += 1
    }

    private func saveAdminCode() {
        let verifier = AdminCodeVerifier(secrets: secrets, configuration: configuration)
        try? verifier.setCode(newAdminCode.filter(\.isNumber))
        newAdminCode = ""
        feedback += 1
    }

    private func test() async {
        testState = .testing
        let snapshot = ConnectionSettings(configuration: configuration, secrets: secrets)
        do {
            testState = .succeeded(try await ConnectionTester.test(snapshot.makeAPI()))
        } catch let error as ZweefError {
            testState = .failed(error)
        } catch {
            testState = .failed(.unreachable)
        }
    }

    /// Removes everything: the database, the settings and the secrets.
    ///
    /// The only way back from a forgotten admin code, and the right thing to do
    /// with a device leaving the club.
    private func erase() {
        try? context.delete(model: WorkSession.self)
        try? context.delete(model: Member.self)
        try? context.delete(model: Aircraft.self)
        try? context.delete(model: TaskDefinition.self)
        try? context.delete(model: SyncLog.self)
        try? context.delete(model: AppSettings.self)
        try? context.save()

        try? secrets.removeAll()
        configuration.reset()
        connection.update(nil)
        dismiss()
    }
}

#Preview("iPad", traits: .landscapeLeft) {
    SettingsPreview()
}

#Preview("iPhone · managed by MDM") {
    SettingsPreview(managed: [
        "connectionMode": "proxy",
        "proxyURL": "https://winter-proxy.example.workers.dev",
        "deviceToken": "managed-token",
    ])
}

private struct SettingsPreview: View {
    var managed: [String: Any] = [:]

    var body: some View {
        let container = try! SampleData.container()
        let settings = (try? container.mainContext.fetch(FetchDescriptor<AppSettings>()).first) ?? AppSettings()
        let configuration = AppConfiguration(
            defaults: UserDefaults(suiteName: "preview-settings") ?? .standard,
            managed: ManagedConfiguration(values: managed)
        )

        return SettingsView(
            configuration: configuration,
            secrets: InMemorySecretStore([.deviceToken: "token", .adminCode: "salt:hash"]),
            connection: ConnectionProvider(),
            settings: settings
        )
        .modelContainer(container)
    }
}
