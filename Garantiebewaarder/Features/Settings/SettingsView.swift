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
    @State private var exportItem: ShareItem?
    @State private var exportProgress: (done: Int, total: Int)?
    @State private var exportFailed = false
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppSettings.Key.iCloudSyncEnabled) private var iCloudSync = AppSettings.Default.iCloudSyncEnabled
    @State private var iCloudStatus: ICloudStatus = .unknown
    @State private var confirmingDeleteAll = false
    @State private var finalDeleteConfirmation = false
    @State private var deleteFailed = false

    private static let termChoices = [12, 24, 36, 48, 60]
    private static let leadChoices = [7, 14, 30, 60, 90]

    var body: some View {
        NavigationStack {
            Form {
                warrantySection
                remindersSection
                iCloudSection
                dataSection
                deleteSection
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }.accessibilityIdentifier("settingsDoneButton")
                }
            }
            .sheet(item: $exportItem) { ShareSheet(url: $0.url).presentationDetents([.medium, .large]) }
            .alert("export.error.title", isPresented: $exportFailed) {
                Button("action.ok") {}
            } message: {
                Text("export.error.message")
            }
            .confirmationDialog("deleteAll.title", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
                Button("deleteAll.continue", role: .destructive) { finalDeleteConfirmation = true }
            } message: {
                Text("deleteAll.message")
            }
            .alert("deleteAll.final.title", isPresented: $finalDeleteConfirmation) {
                Button("deleteAll.final.confirm", role: .destructive, action: deleteEverything)
                Button("action.cancel", role: .cancel) {}
            } message: {
                Text(iCloudSync ? "deleteAll.final.messageSync" : "deleteAll.final.message")
            }
            .alert("deleteAll.error.title", isPresented: $deleteFailed) {
                Button("action.ok") {}
            } message: {
                Text("error.save.message")
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

    private var dataSection: some View {
        Section {
            Button(action: exportAll) {
                if let progress = exportProgress {
                    HStack {
                        ProgressView()
                        Text("export.working \(progress.done) \(progress.total)")
                    }
                } else {
                    Label("settings.exportAll", systemImage: "square.and.arrow.up.on.square")
                }
            }
            .disabled(exportProgress != nil || products.isEmpty)
            .accessibilityIdentifier("exportAllButton")
        } header: {
            Text("settings.section.data")
        } footer: {
            Text("settings.exportAll.footer")
        }
    }

    private func exportAll() {
        exportProgress = (0, products.count)
        Task {
            do {
                let url = try await ExportService.exportAll(products: products) { done, total in
                    exportProgress = (done, total)
                }
                exportItem = ShareItem(url: url)
            } catch {
                exportFailed = true
            }
            exportProgress = nil
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
                        .foregroundStyle(Theme.secondaryText)
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
        iCloudStatus = await ICloudStatus.fetch()
    }

    // MARK: iCloud

    private var iCloudSection: some View {
        Section {
            Toggle("settings.iCloud", isOn: $iCloudSync)
                .accessibilityIdentifier("iCloudToggle")
            Label(String(localized: iCloudStatus.title), systemImage: iCloudStatus.symbolName)
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
            if let note = iCloudNote {
                Label(note, systemImage: "arrow.clockwise")
                    .font(.footnote)
                    .accessibilityIdentifier("iCloudRestartNote")
            }
        } header: {
            Text("settings.section.iCloud")
        } footer: {
            Text("settings.iCloud.footer")
        }
    }

    /// Uitleg als de voorkeur afwijkt van wat er nu draait.
    private var iCloudNote: LocalizedStringKey? {
        let mode = PersistenceController.activeMode
        switch (iCloudSync, mode) {
        case (true, .local): return "settings.iCloud.restartOn"
        case (false, .iCloud): return "settings.iCloud.restartOff"
        case (true, .iCloudUnavailableUsingLocal): return "settings.iCloud.fellBack"
        default: return nil
        }
    }

    // MARK: Alles verwijderen

    private var deleteSection: some View {
        Section {
            NavigationLink {
                ArchivedProductsView()
            } label: {
                Label("settings.archived", systemImage: "archivebox")
            }
            .accessibilityIdentifier("archivedLink")
            NavigationLink {
                AboutView()
            } label: {
                Label("settings.about", systemImage: "info.circle")
            }
            .accessibilityIdentifier("aboutLink")
            Button(role: .destructive) { confirmingDeleteAll = true } label: {
                Label("settings.deleteAll", systemImage: "trash")
            }
            .accessibilityIdentifier("deleteAllButton")
        }
    }

    private func deleteEverything() {
        do {
            try DataEraser.deleteEverything(in: modelContext)
            Task {
                await Reminders.syncNow(products: [])
                await SystemIntegration.update(products: [], leadDays: leadDays)
            }
        } catch {
            deleteFailed = true
        }
    }
}

#if DEBUG
#Preview {
    SettingsView().modelContainer(PreviewData.container())
}
#endif
