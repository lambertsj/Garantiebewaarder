import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Sectie in het bewerkscherm om bijlagen toe te voegen of te verwijderen.
struct AttachmentsEditorSection: View {
    let existing: [Attachment]
    @Binding var removedIDs: Set<UUID>
    @Binding var pending: [PendingAttachment]
    var importer: AttachmentImportController

    @State private var receiptPhotos: [PhotosPickerItem] = []
    @State private var productPhoto: [PhotosPickerItem] = []
    @State private var showingFileImporter = false
    @State private var showingScanner = false

    private var visibleExisting: [Attachment] { existing.filter { !removedIDs.contains($0.id) } }

    var body: some View {
        Section {
            ForEach(visibleExisting) { attachment in
                row(kind: attachment.kind, thumb: attachment.thumbnailData, isPDF: attachment.fileType == "pdf") {
                    removedIDs.insert(attachment.id)
                }
            }
            ForEach(pending) { item in
                row(kind: item.kind, thumb: item.thumbnailData, isPDF: item.fileType == "pdf") {
                    pending.removeAll { $0.id == item.id }
                }
            }

            if DocumentScannerView.isSupported {
                Button { showingScanner = true } label: { Label("add.scan", systemImage: "doc.viewfinder") }
                    .accessibilityIdentifier("scanButton")
            }
            PhotosPicker(selection: $receiptPhotos, maxSelectionCount: 10, matching: .images) {
                Label("add.photo", systemImage: "photo.on.rectangle")
            }
            Button { showingFileImporter = true } label: { Label("add.file", systemImage: "doc.badge.plus") }
            PhotosPicker(selection: $productPhoto, maxSelectionCount: 1, matching: .images) {
                Label("add.productPhoto", systemImage: "camera")
            }

            if importer.isProcessing {
                HStack { ProgressView(); Text("import.processing") }
            }
        } header: {
            Text("edit.section.attachments")
        }
        .onChange(of: receiptPhotos) { _, items in
            guard !items.isEmpty else { return }
            Task {
                pending += await importer.process(photos: items, kind: .receipt)
                receiptPhotos = []
            }
        }
        .onChange(of: productPhoto) { _, items in
            guard !items.isEmpty else { return }
            Task {
                pending += await importer.process(photos: items, kind: .productPhoto)
                productPhoto = []
            }
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            Task { pending += await importer.process(fileURLs: urls, kind: .receipt) }
        }
        .fullScreenCover(isPresented: $showingScanner) {
            DocumentScannerView(
                onFinish: { images in
                    showingScanner = false
                    Task { pending += await importer.process(scannedImages: images) }
                },
                onCancel: { showingScanner = false }
            )
            .ignoresSafeArea()
        }
    }

    private func row(kind: AttachmentKind, thumb: Data?, isPDF: Bool, remove: @escaping () -> Void) -> some View {
        HStack {
            AttachmentThumbnail(thumbnailData: thumb, isPDF: isPDF, size: 44)
            Text(kind.title)
            Spacer()
            Button(role: .destructive, action: remove) { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("action.removeAttachment"))
        }
    }
}
