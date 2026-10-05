import SwiftUI
import SwiftData
import OSLog

/// Formulier om een product aan te maken of te bewerken.
struct ProductEditView: View {
    enum Mode {
        case create
        case edit(Product)
    }

    let mode: Mode
    var onSaved: (Product) -> Void = { _ in }
    /// Sluit het hele scherm. Nodig als dit scherm in een sheet is ingebed
    /// (`dismiss` zou dan alleen terug navigeren).
    var close: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.Key.defaultWarrantyMonths) private var defaultMonths = AppSettings.Default.defaultWarrantyMonths

    @State private var draft: ProductDraft
    private let initialDraft: ProductDraft
    private let suggestions: ReceiptSuggestions
    @State private var saveCount = 0
    @State private var saveError: String?
    @State private var pending: [PendingAttachment]
    @State private var removedAttachmentIDs: Set<UUID> = []
    @State private var importer = AttachmentImportController()

    private static let logger = Logger(subsystem: "com.jeroenlamberts.garantiebewaarder", category: "edit")

    init(mode: Mode, initialAttachments: [PendingAttachment] = [],
         receipt: ParsedReceipt = ParsedReceipt(), hadReceiptAttachment: Bool = false,
         onSaved: @escaping (Product) -> Void = { _ in }, close: (() -> Void)? = nil) {
        self.mode = mode
        self.onSaved = onSaved
        self.close = close
        _pending = State(initialValue: initialAttachments)
        var start: ProductDraft
        switch mode {
        case .create:
            let months = AppSettings.int(AppSettings.Key.defaultWarrantyMonths, default: AppSettings.Default.defaultWarrantyMonths)
            start = ProductDraft(defaultMonths: months)
            start.apply(receipt: receipt)
            suggestions = ReceiptSuggestions(receipt: receipt, hadReceiptAttachment: hadReceiptAttachment)
        case .edit(let product):
            start = ProductDraft(product: product)
            suggestions = ReceiptSuggestions()
        }
        initialDraft = start
        _draft = State(initialValue: start)
    }

    private var isCreating: Bool {
        if case .create = mode { true } else { false }
    }

    var body: some View {
        Form {
                productSection
                purchaseSection
                warrantySection
                AttachmentsEditorSection(
                    existing: existingAttachments, removedIDs: $removedAttachmentIDs,
                    pending: $pending, importer: importer
                )
                detailsSection
            }
            .navigationTitle(isCreating ? "edit.title.new" : "edit.title.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { closeScreen() }
                        .accessibilityIdentifier("cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save", action: save)
                        .disabled(!draft.isValid)
                        .accessibilityIdentifier("saveButton")
                }
            }
            .sensoryFeedback(.success, trigger: saveCount)
            .alert("error.save.title", isPresented: .constant(saveError != nil)) {
                Button("action.ok") { saveError = nil }
            } message: {
                Text("error.save.message")
            }
            .alert(
                Text(importer.error?.message ?? "import.error.unreadable"),
                isPresented: Binding(get: { importer.error != nil }, set: { if !$0 { importer.error = nil } })
            ) {
                Button("action.ok") { importer.error = nil }
            } message: {
                Text("import.error.hint")
            }
    }

    private var existingAttachments: [Attachment] {
        if case .edit(let product) = mode {
            return (product.attachments ?? []).sorted { $0.createdAt < $1.createdAt }
        }
        return []
    }

    private func closeScreen() {
        if let close { close() } else { dismiss() }
    }

    // MARK: Herkenning

    /// Een veld telt als "herkend" zolang de gebruiker het niet heeft aangepast.
    private func highlight(_ field: ReceiptSuggestions.Field, unchanged: Bool) -> ParseConfidence? {
        unchanged ? suggestions.confidence[field] : nil
    }

    @ViewBuilder
    private var recognitionBanner: some View {
        if suggestions.hasRecognizedFields {
            Section {
                Label("recognition.banner", systemImage: "text.viewfinder")
                    .font(.subheadline)
                    .accessibilityIdentifier("recognitionBanner")
            }
        } else if suggestions.recognitionFoundNothing {
            Section {
                Label("recognition.failed", systemImage: "info.circle")
                    .font(.subheadline)
                    .accessibilityIdentifier("recognitionFailedBanner")
            }
        }
    }

    @ViewBuilder
    private var nameCandidates: some View {
        let others = suggestions.nameCandidates.filter { $0 != draft.name }
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("recognition.otherNames").font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(others, id: \.self) { candidate in
                            Button(candidate) { draft.name = candidate }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .controlSize(.small)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    // MARK: Secties

    private var productSection: some View {
        Section("edit.section.product") {
            TextField("field.name", text: $draft.name)
                .textInputAutocapitalization(.sentences)
                .accessibilityIdentifier("nameField")
                .recognized(highlight(.name, unchanged: draft.name == initialDraft.name))
            nameCandidates
            TextField("field.brand", text: $draft.brand)
                .accessibilityIdentifier("brandField")
            Picker("field.category", selection: $draft.category) {
                ForEach(ProductCategory.allCases) { category in
                    Label(String(localized: category.title), systemImage: category.symbolName).tag(category)
                }
            }
        }
    }

    private var purchaseSection: some View {
        Section("edit.section.purchase") {
            TextField("field.store", text: $draft.store)
                .accessibilityIdentifier("storeField")
                .recognized(highlight(.store, unchanged: draft.store == initialDraft.store))
            DatePicker("field.purchaseDate", selection: $draft.purchaseDate, displayedComponents: .date)
                .recognized(highlight(.purchaseDate, unchanged: draft.purchaseDate == initialDraft.purchaseDate))
            if draft.purchaseDateIssue() != nil {
                Label("warning.purchaseInFuture", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("futureDateWarning")
            }
            TextField("field.price", value: $draft.price, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("priceField")
                .recognized(highlight(.price, unchanged: draft.price == initialDraft.price))
        }
    }

    private var warrantySection: some View {
        Section {
            Picker("field.warrantyTerm", selection: $draft.warrantyMonths) {
                ForEach(draft.choices(including: defaultMonths), id: \.self) { months in
                    Text("term.months \(months)").tag(months)
                }
                Text("term.custom").tag(ProductDraft.customChoice)
            }
            .accessibilityIdentifier("termPicker")

            if draft.usesCustomEndDate {
                DatePicker("field.customEndDate", selection: $draft.customEndDate, displayedComponents: .date)
            } else {
                Picker("field.warrantySource", selection: $draft.termSource) {
                    Text(WarrantySource.statutoryDefault.title).tag(WarrantySource.statutoryDefault)
                    Text(WarrantySource.manufacturer.title).tag(WarrantySource.manufacturer)
                }
            }

            LabeledContent("field.endDate") {
                Text(draft.endDate().formatted(date: .long, time: .omitted))
                    .accessibilityIdentifier("computedEndDate")
            }
            TextField("field.extraCoverage", text: $draft.extraCoverageNote, axis: .vertical)
        } header: {
            Text("edit.section.warranty")
        } footer: {
            Text("edit.warranty.footer")
        }
    }

    private var detailsSection: some View {
        Section("edit.section.details") {
            TextField("field.serialNumber", text: $draft.serialNumber)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            TextField("field.manualURL", text: $draft.manualURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("field.notes", text: $draft.notes, axis: .vertical)
                .lineLimit(3...8)
        }
    }

    // MARK: Opslaan

    private func save() {
        guard draft.isValid else { return }
        let saved: Product
        switch mode {
        case .create:
            saved = draft.makeProduct()
            modelContext.insert(saved)
        case .edit(let product):
            draft.apply(to: product)
            saved = product
        }
        for item in pending {
            let attachment = Attachment(
                kind: item.kind, fileType: item.fileType, data: item.data,
                thumbnailData: item.thumbnailData, recognizedText: item.recognizedText
            )
            modelContext.insert(attachment)
            attachment.product = saved
        }
        for attachment in existingAttachments where removedAttachmentIDs.contains(attachment.id) {
            modelContext.delete(attachment)
        }
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Opslaan mislukt: \(error.localizedDescription, privacy: .public)")
            saveError = error.localizedDescription
            return
        }
        saveCount += 1
        closeScreen()
        if isCreating { onSaved(saved) }
    }
}

#if DEBUG
#Preview("Nieuw") {
    NavigationStack { ProductEditView(mode: .create) }.modelContainer(PersistenceController.makeContainer(inMemory: true))
}
#endif


/// Markeert een veld dat uit de bon komt: tint, icoon en tekst (niet alleen kleur).
private struct RecognizedModifier: ViewModifier {
    let confidence: ParseConfidence?

    func body(content: Content) -> some View {
        if let confidence {
            content
                .listRowBackground(Color.accentColor.opacity(0.12))
                .overlay(alignment: .trailing) {
                    Image(systemName: confidence == .low ? "questionmark.circle" : "text.viewfinder")
                        .font(.footnote)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
                .accessibilityHint(Text(confidence == .low ? "recognition.hint.low" : "recognition.hint"))
        } else {
            content
        }
    }
}

private extension View {
    func recognized(_ confidence: ParseConfidence?) -> some View {
        modifier(RecognizedModifier(confidence: confidence))
    }
}
