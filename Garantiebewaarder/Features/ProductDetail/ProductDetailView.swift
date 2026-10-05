import SwiftUI
import SwiftData
import OSLog

struct ProductDetailView: View {
    let product: Product

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(AppSettings.Key.reminderLeadDays) private var leadDays = AppSettings.Default.reminderLeadDays

    @State private var showingEdit = false
    @State private var confirmingDelete = false
    @State private var actionError: String?
    @State private var shareItem: ShareItem?
    @State private var isExporting = false

    private static let logger = Logger(subsystem: "com.jeroenlamberts.garantiebewaarder", category: "detail")

    private var status: WarrantyStatus { product.status(leadDays: leadDays) }

    var body: some View {
        List {
            headerSection
            warrantySection
            purchaseSection
            attachmentsSection
            dataSection
            actionsSection
        }
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("action.edit") { showingEdit = true }
                    .accessibilityIdentifier("editButton")
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: sharePDF) {
                    if isExporting { ProgressView() } else { Label("action.sharePDF", systemImage: "square.and.arrow.up") }
                }
                .disabled(isExporting)
                .accessibilityIdentifier("sharePDFButton")
            }
        }
        .sheet(item: $shareItem) { ShareSheet(url: $0.url).presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showingEdit) { NavigationStack { ProductEditView(mode: .edit(product)) } }
        .confirmationDialog("delete.title", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("action.delete", role: .destructive, action: deleteProduct)
                .accessibilityIdentifier("confirmDeleteButton")
        } message: {
            Text("delete.message")
        }
        .alert("error.save.title", isPresented: .constant(actionError != nil)) {
            Button("action.ok") { actionError = nil }
        } message: {
            Text("error.save.message")
        }
        .accessibilityIdentifier("productDetail")
    }

    // MARK: Secties

    private var headerSection: some View {
        Section {
            // Bij de grootste tekstgroottes staat de tekst onder de afbeelding in plaats van ernaast.
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 16))
            layout {
                ProductThumbnail(product: product, size: 72)
                VStack(alignment: .leading, spacing: 6) {
                    Text(product.name).font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("detailName")
                    if !product.brand.isEmpty { Text(product.brand).foregroundStyle(Theme.secondaryText) }
                    StatusBadge(status: status)
                    Text(product.remaining().text()).font(.subheadline).foregroundStyle(Theme.secondaryText)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var warrantySection: some View {
        Section("detail.section.warranty") {
            LabeledContent("field.endDate", value: product.warrantyEndDate.formatted(date: .long, time: .omitted))
            LabeledContent("detail.source") { Text(product.warrantySource.title) }
            if !product.extraCoverageNote.isEmpty {
                LabeledContent("field.extraCoverage", value: product.extraCoverageNote)
            }
        }
    }

    private var purchaseSection: some View {
        Section("detail.section.purchase") {
            if !product.store.isEmpty { LabeledContent("field.store", value: product.store) }
            LabeledContent("field.purchaseDate", value: product.purchaseDate.formatted(date: .long, time: .omitted))
            if let price = product.price {
                LabeledContent("field.price", value: price.formatted(.currency(code: "EUR")))
            }
        }
    }

    @ViewBuilder
    private var attachmentsSection: some View {
        let items = (product.attachments ?? []).sorted { $0.createdAt < $1.createdAt }
        if !items.isEmpty {
            Section("detail.section.attachments") { AttachmentGrid(attachments: items) }
        }
    }

    @ViewBuilder
    private var dataSection: some View {
        let link = ManualLink.url(from: product.manualURL)
        if !product.serialNumber.isEmpty || !product.notes.isEmpty || link != nil {
            Section("detail.section.data") {
                if !product.serialNumber.isEmpty {
                    LabeledContent("field.serialNumber", value: product.serialNumber)
                }
                if let link {
                    // Opent pas na een tik van de gebruiker.
                    Button { openURL(link) } label: {
                        Label("detail.openManual", systemImage: "book")
                    }
                }
                if !product.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("field.notes").font(.caption).foregroundStyle(Theme.secondaryText)
                        Text(product.notes)
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        Section {
            NavigationLink {
                ClaimHelpView(product: product)
            } label: {
                Label("action.somethingWrong", systemImage: "wrench.and.screwdriver")
            }
            .accessibilityIdentifier("claimHelpLink")
            Button(action: toggleArchive) {
                Label(product.isArchived ? "action.unarchive" : "action.archive",
                      systemImage: product.isArchived ? "tray.and.arrow.up" : "archivebox")
            }
            .accessibilityIdentifier("archiveButton")
            Button(role: .destructive) { confirmingDelete = true } label: {
                Label("action.delete", systemImage: "trash")
            }
            .accessibilityIdentifier("deleteButton")
        }
    }

    // MARK: Acties

    /// Maakt de PDF op een achtergrondtaak en opent daarna de deelsheet.
    private func sharePDF() {
        isExporting = true
        let input = ProductPDFInput(product: product, leadDays: leadDays)
        Task {
            let data = await Task.detached(priority: .userInitiated) { ExportService.pdfData(for: input) }.value
            let safeName = input.name.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "-")
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName.isEmpty ? AppInfo.name : safeName).pdf")
            do {
                try data.write(to: url, options: .atomic)
                shareItem = ShareItem(url: url)
            } catch {
                Self.logger.error("PDF schrijven mislukt: \(error.localizedDescription, privacy: .public)")
                actionError = error.localizedDescription
            }
            isExporting = false
        }
    }

    private func toggleArchive() {
        product.isArchived.toggle()
        product.updatedAt = Date()
        persist()
        if product.isArchived { dismiss() }
    }

    private func deleteProduct() {
        modelContext.delete(product)
        persist()
        dismiss()
    }

    private func persist() {
        do { try modelContext.save() } catch {
            Self.logger.error("Opslaan mislukt: \(error.localizedDescription, privacy: .public)")
            actionError = error.localizedDescription
        }
    }
}

#if DEBUG
#Preview {
    let container = PreviewData.container()
    let product = (try? container.mainContext.fetch(FetchDescriptor<Product>()))?.first
    return NavigationStack { if let product { ProductDetailView(product: product) } }
        .modelContainer(container)
}
#endif
