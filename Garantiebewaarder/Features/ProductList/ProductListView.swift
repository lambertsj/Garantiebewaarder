import SwiftUI
import SwiftData

struct ProductListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var products: [Product]
    @AppStorage(AppSettings.Key.reminderLeadDays) private var leadDays = AppSettings.Default.reminderLeadDays

    @State private var query = ProductListQuery()
    @State private var path = NavigationPath()
    @State private var showingAdd = false
    @State private var showingSettings = false
    @State private var primerPending = false
    @State private var showingReminderPrimer = false
    @AppStorage(AppSettings.Key.remindersEnabled) private var remindersEnabled = AppSettings.Default.remindersEnabled
    @AppStorage(AppSettings.Key.hasAskedNotificationPermission) private var hasAsked = AppSettings.Default.hasAskedNotificationPermission
    private let router = DeepLinkRouter.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var inboxBatch: InboxImporter.Batch?
    @State private var isLoadingInbox = false

    private var visible: [Product] {
        query.apply(to: products, leadDays: leadDays)
    }

    private var hasActiveProducts: Bool { products.contains { !$0.isArchived } }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if !hasActiveProducts {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle(AppInfo.name)
            .navigationDestination(for: Product.self) { product in
                ProductDetailView(product: product)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Label("action.add", systemImage: "plus") }
                        .accessibilityIdentifier("addButton")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: { Label("settings.title", systemImage: "gearshape") }
                        .accessibilityIdentifier("settingsButton")
                }
                if hasActiveProducts {
                    ToolbarItem(placement: .topBarLeading) { sortMenu }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddProductSheet { created in
                    path.append(created)
                    primerPending = true
                }
            }
            .sheet(item: Binding(get: { inboxBatch.map(InboxSheetItem.init) }, set: { if $0 == nil { finishInbox() } })) { item in
                AddProductSheet(initialSeed: item.batch.seed) { created in
                    path.append(created)
                    primerPending = true
                }
            }
            .task { await importInbox() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await importInbox() } }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .onChange(of: showingAdd) { _, isShowing in
                if !isShowing, primerPending {
                    primerPending = false
                    Task { await offerReminderPrimerIfNeeded() }
                }
            }
            .alert("primer.title", isPresented: $showingReminderPrimer) {
                Button("primer.accept") { Task { await acceptReminders() } }
                Button("primer.decline", role: .cancel) { hasAsked = true }
            } message: {
                Text("primer.message")
            }
            .onChange(of: router.pendingProductID, initial: true) { _, _ in openPendingDeepLink() }
        }
        .searchable(text: $query.search, prompt: Text("search.prompt"))
        .syncsReminders()
    }

    // MARK: Inbox (Share Extension)

    private func importInbox() async {
        guard !isLoadingInbox, inboxBatch == nil, !showingAdd else { return }
        #if DEBUG
        // UI-test: simuleert een bon waarvan de tekst al herkend is (zonder camera of OCR).
        if ProcessInfo.processInfo.arguments.contains("-UITestingSeedReceipt") {
            let text = "Coolblue\nFactuurdatum: 12 maart 2026\nBosch wasmachine WAX32   € 649,00\nTotaal incl. btw € 649,00"
            let item = PendingAttachment(kind: .receipt, fileType: "jpg", data: Data(), thumbnailData: nil, recognizedText: text)
            inboxBatch = InboxImporter.Batch(seed: AddProductSheet.Seed(attachments: [item]), files: [], skippedUnreadable: 0)
            return
        }
        #endif
        isLoadingInbox = true
        defer { isLoadingInbox = false }
        if let batch = await InboxImporter.loadPending() { inboxBatch = batch }
    }

    private func finishInbox() {
        if let inboxBatch { InboxImporter.finish(inboxBatch) }
        inboxBatch = nil
    }

    // MARK: Herinneringen en deep links

    /// Uitleg vooraf, pas bij het bewaren van het eerste product.
    private func offerReminderPrimerIfNeeded() async {
        guard remindersEnabled, !hasAsked, !ProcessInfo.processInfo.arguments.contains("-UITesting") else { return }
        guard await Reminders.scheduler.authorizationStatus() == .notDetermined else { return }
        showingReminderPrimer = true
    }

    private func acceptReminders() async {
        hasAsked = true
        await Reminders.scheduler.requestAuthorization()
        await Reminders.syncNow(products: products)
    }

    private func openPendingDeepLink() {
        guard let id = router.pendingProductID,
              let product = products.first(where: { $0.id == id }) else { return }
        _ = router.consume()
        showingAdd = false
        showingSettings = false
        path = NavigationPath()
        path.append(product)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("list.empty.title", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("list.empty.message")
        } actions: {
            Button("list.empty.action") { showingAdd = true }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("emptyAddButton")
        }
    }

    private var list: some View {
        List {
            Section {
                filterBar
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            if visible.isEmpty {
                ContentUnavailableView.search
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("noResults")
            } else {
                Section {
                    ForEach(visible) { product in
                        NavigationLink(value: product) {
                            ProductRow(product: product, status: product.status(leadDays: leadDays))
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("productList")
    }

    private var filterBar: some View {
        VStack(spacing: 8) {
            Picker("filter.status", selection: $query.status) {
                ForEach(ProductStatusFilter.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("statusFilter")

            HStack {
                Menu {
                    Picker("filter.category", selection: $query.category) {
                        Text("filter.allCategories").tag(ProductCategory?.none)
                        ForEach(ProductCategory.allCases) { category in
                            Label(String(localized: category.title), systemImage: category.symbolName)
                                .tag(ProductCategory?.some(category))
                        }
                    }
                } label: {
                    Label(
                        query.category.map { String(localized: $0.title) } ?? String(localized: "filter.allCategories"),
                        systemImage: "line.3.horizontal.decrease.circle"
                    )
                    .font(.subheadline)
                }
                .accessibilityIdentifier("categoryFilter")
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private var sortMenu: some View {
        Menu {
            Picker("sort.title", selection: $query.sort) {
                ForEach(ProductSort.allCases) { Text($0.title).tag($0) }
            }
        } label: {
            Label("sort.title", systemImage: "arrow.up.arrow.down")
        }
        .accessibilityIdentifier("sortMenu")
    }
}

private struct InboxSheetItem: Identifiable {
    let batch: InboxImporter.Batch
    var id: UUID { batch.seed.id }
}

#if DEBUG
#Preview("Met producten") {
    ProductListView().modelContainer(PreviewData.container())
}

#Preview("Leeg") {
    ProductListView().modelContainer(PersistenceController.makeContainer(inMemory: true))
}
#endif
