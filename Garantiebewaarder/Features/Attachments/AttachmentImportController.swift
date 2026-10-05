import SwiftUI
import PhotosUI
import OSLog

/// Verwerkt gekozen foto's, bestanden en scans op een achtergrondtaak, zodat
/// de UI vloeiend blijft. Eén controller per scherm.
@MainActor
@Observable
final class AttachmentImportController {
    enum ImportError: Identifiable {
        case unreadable
        case tooLarge
        var id: Int { self == .unreadable ? 0 : 1 }
        static func == (l: Self, r: Self) -> Bool { l.id == r.id }
        var message: LocalizedStringResource {
            switch self {
            case .unreadable: "import.error.unreadable"
            case .tooLarge: "import.error.tooLarge"
            }
        }
    }

    private(set) var isProcessing = false
    var error: ImportError?

    private static let logger = Logger(subsystem: "com.jeroenlamberts.garantiebewaarder", category: "import")

    func process(photos items: [PhotosPickerItem], kind: AttachmentKind) async -> [PendingAttachment] {
        isProcessing = true
        defer { isProcessing = false }
        var result: [PendingAttachment] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                error = .unreadable
                continue
            }
            if let pending = await Self.run({ AttachmentProcessor.process(data: data, kind: kind) }) {
                result.append(pending)
            } else {
                error = .unreadable
            }
        }
        return result
    }

    func process(fileURLs urls: [URL], kind: AttachmentKind) async -> [PendingAttachment] {
        isProcessing = true
        defer { isProcessing = false }
        var result: [PendingAttachment] = []
        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                error = .unreadable
                continue
            }
            if data.count > AttachmentProcessor.maxPDFBytes {
                error = .tooLarge
                continue
            }
            if let pending = await Self.run({ AttachmentProcessor.process(data: data, kind: kind) }) {
                result.append(pending)
            } else {
                error = .unreadable
            }
        }
        return result
    }

    func process(scannedImages images: [UIImage], kind: AttachmentKind = .receipt) async -> [PendingAttachment] {
        isProcessing = true
        defer { isProcessing = false }
        var result: [PendingAttachment] = []
        for image in images {
            if let pending = await Self.run({ AttachmentProcessor.processImage(image, kind: kind) }) {
                result.append(pending)
            } else {
                error = .unreadable
            }
        }
        return result
    }

    private static func run<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await Task.detached(priority: .userInitiated, operation: work).value
    }
}
