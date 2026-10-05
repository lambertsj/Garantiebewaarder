import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Startpunt voor "toevoegen": scan, kies foto/PDF of vul handmatig in.
struct AddProductSheet: View {
    /// Wat het bewerkscherm als startpunt krijgt.
    struct Seed: Hashable, Identifiable {
        let id = UUID()
        var attachments: [PendingAttachment] = []
        var receipt = ParsedReceipt()

        init() {}

        /// Bouwt het startpunt uit verwerkte bijlagen, inclusief het voorstel uit de bontekst.
        init(attachments: [PendingAttachment]) {
            self.attachments = attachments
            let lines = attachments
                .filter { $0.kind == .receipt }
                .flatMap { $0.recognizedText.split(whereSeparator: \.isNewline).map(String.init) }
            receipt = ReceiptParser.parse(lines: lines)
        }

        var hasReceiptAttachment: Bool { attachments.contains { $0.kind == .receipt } }

        static func == (l: Self, r: Self) -> Bool { l.id == r.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    var onSaved: (Product) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var importer = AttachmentImportController()
    @State private var seed: Seed?
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var showingFileImporter = false
    @State private var showingPhotoPicker = false
    @State private var showingScanner = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if DocumentScannerView.isSupported {
                        Button { showingScanner = true } label: {
                            OptionRow(title: "add.scan", detail: "add.scan.detail", symbol: "doc.viewfinder")
                        }
                        .accessibilityIdentifier("scanButton")
                    }
                    Button { showingPhotoPicker = true } label: {
                        OptionRow(title: "add.photo", detail: "add.photo.detail", symbol: "photo.on.rectangle")
                    }
                    .accessibilityIdentifier("photoButton")
                    Button { showingFileImporter = true } label: {
                        OptionRow(title: "add.file", detail: "add.file.detail", symbol: "doc.badge.plus")
                    }
                    .accessibilityIdentifier("fileButton")
                    Button { seed = Seed() } label: {
                        OptionRow(title: "add.manual", detail: "add.manual.detail", symbol: "square.and.pencil")
                    }
                    .accessibilityIdentifier("manualButton")
                } footer: {
                    if !DocumentScannerView.isSupported { Text("add.scan.unavailable") }
                }

                if importer.isProcessing {
                    Section { HStack { ProgressView(); Text("import.processing") } }
                }
            }
            .navigationTitle("add.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }.accessibilityIdentifier("cancelAddButton")
                }
            }
            .navigationDestination(item: $seed) { seed in
                ProductEditView(mode: .create, initialAttachments: seed.attachments, receipt: seed.receipt,
                                hadReceiptAttachment: seed.hasReceiptAttachment, onSaved: onSaved, close: { dismiss() })
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $photoSelection, maxSelectionCount: 10, matching: .images)
            .onChange(of: photoSelection) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    let result = await importer.process(photos: items, kind: .receipt)
                    photoSelection = []
                    if !result.isEmpty { seed = Seed(attachments: result) }
                }
            }
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
                guard case .success(let urls) = result else { return }
                Task {
                    let items = await importer.process(fileURLs: urls, kind: .receipt)
                    if !items.isEmpty { seed = Seed(attachments: items) }
                }
            }
            .fullScreenCover(isPresented: $showingScanner) {
                DocumentScannerView(
                    onFinish: { images in
                        showingScanner = false
                        Task {
                            let items = await importer.process(scannedImages: images)
                            if !items.isEmpty { seed = Seed(attachments: items) }
                        }
                    },
                    onCancel: { showingScanner = false }
                )
                .ignoresSafeArea()
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
    }
}

private struct OptionRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let symbol: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title2).frame(width: 36).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
