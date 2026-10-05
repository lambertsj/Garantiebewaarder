import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Query private var products: [Product]

    @AppStorage(AppSettings.Key.defaultWarrantyMonths) private var defaultMonths = AppSettings.Default.defaultWarrantyMonths
    @AppStorage(AppSettings.Key.remindersEnabled) private var remindersEnabled = AppSettings.Default.remindersEnabled
    @AppStorage(AppSettings.Key.reminderLeadDays) private var leadDays = AppSettings.Default.reminderLeadDays
    @AppStorage(AppSettings.Key.secondReminderEnabled) private var secondReminder = AppSettings.Default.secondReminderEnabled
    @AppStorage(AppSettings.Key.hasAskedNotificationPermission) private var hasAsked = AppSettings.Default.hasAskedNotificationPermission

    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    private static let termChoices = [12, 24, 36, 48, 60]
    private static let leadChoices = [7, 14, 30, 60, 90]

    var body: some View {
        NavigationStack {
            Form {
                warrantySection
                remindersSection
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }.accessibilityIdentifier("settingsDoneButton")
                }
            }
            .task { await refreshStatus() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshStatus() } }
            }
        }
    }

    private var warrantySection: some View {
        Section {
            Picker("settings.defaultTerm", selection: $defaultMonths) {
                ForEach(termChoices, id: \.self) { Text("term.months \($0)").tag($0) }
            }
        } header: {
            Text("settings.section.warranty")
        } footer: {
            Text(LegalContent.defaultTermDisclaimer)
        }
    }

    private var termChoices: [Int] {
        Self.termChoices.contains(defaultMonths) ? Self.termChoices : (Self.termChoices + [defaultMonths]).sorted()
    }

    private var leadChoices: [Int] {
        Self.leadChoices.contains(leadDays) ? Self.leadChoices : (Self.leadChoices + [leadDays]).sorted()
    }

    private var remindersSection: some View {
        Section {
            Toggle("settings.reminders", isOn: remindersBinding)
                .accessibilityIdentifier("remindersToggle")
            if remindersEnabled {
                Picker("settings.leadDays", selection: $leadDays) {
                    ForEach(leadChoices, id: \.self) { Text("settings.daysBefore \($0)").tag($0) }
                }
                if leadDays > NotificationPlanner.secondLeadDays {
                    Toggle("settings.secondReminder", isOn: $secondReminder)
                }
            }
            if remindersEnabled, authStatus == .denied {
                VStack(alignment: .leading, spacing: 8) {
                    Label("settings.reminders.denied", systemImage: "bell.slash")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("settings.openSystemSettings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .font(.footnote)
                }
                .accessibilityIdentifier("remindersDeniedHint")
            }
        } header: {
            Text("settings.section.reminders")
        } footer: {
            Text("settings.reminders.footer")
        }
    }

    /// Zet je herinneringen aan en vraag dan (indien nog niet gevraagd) om toestemming.
    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { remindersEnabled },
            set: { newValue in
                remindersEnabled = newValue
                guard newValue else { return }
                Task {
                    await refreshStatus()
                    if authStatus == .notDetermined {
                        hasAsked = true
                        await Reminders.scheduler.requestAuthorization()
                        await refreshStatus()
                    }
                    await Reminders.syncNow(products: products)
                }
            }
        )
    }

    private func refreshStatus() async {
        authStatus = await Reminders.scheduler.authorizationStatus()
    }
}

#if DEBUG
#Preview {
    SettingsView().modelContainer(PreviewData.container())
}
#endif
