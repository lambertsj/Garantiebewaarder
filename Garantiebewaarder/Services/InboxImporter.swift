import Foundation
import OSLog

/// Leest wat de Share Extension in de inbox heeft gezet en maakt er één
/// startpunt voor het bewerkscherm van. Slaat nooit zelf iets op.
@MainActor
enum InboxImporter {
    struct Batch {
        var seed: AddProductSheet.Seed
        var files: [URL]
        var skippedUnreadable: Int
    }

    private static let logger = Logger(subsystem: "com.jeroenlamberts.garantiebewaarder", category: "inbox")

    /// Verwerkt alle wachtende bestanden (verkleinen, OCR). Geeft `nil` als er niets wacht.
    static func loadPending(store: InboxStore? = InboxStore.shared()) async -> Batch? {
        guard let store else { return nil }
        store.purgeStale()
        let files = store.pendingFiles()
        guard !files.isEmpty else { return nil }

        let controller = AttachmentImportController()
        var items: [PendingAttachment] = []
        var unreadable = 0
        for file in files {
            let result = await controller.process(fileURLs: [file], kind: .receipt)
            if result.isEmpty { unreadable += 1 } else { items += result }
        }
        if unreadable > 0 { logger.error("\(unreadable) bestand(en) in de inbox waren onleesbaar") }
        guard !items.isEmpty else {
            store.remove(files)
            return nil
        }
        return Batch(seed: AddProductSheet.Seed(attachments: items), files: files, skippedUnreadable: unreadable)
    }

    static func finish(_ batch: Batch, store: InboxStore? = InboxStore.shared()) {
        store?.remove(batch.files)
    }
}
