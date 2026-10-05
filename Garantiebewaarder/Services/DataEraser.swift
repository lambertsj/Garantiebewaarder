import Foundation
import SwiftData

/// Verwijdert alle gegevens van de gebruiker uit de app.
enum DataEraser {
    /// Verwijdert alle producten en bijlagen. Met iCloud-sync aan verdwijnen ze ook op andere toestellen.
    @MainActor
    static func deleteEverything(in context: ModelContext, inbox: InboxStore? = InboxStore.shared()) throws {
        for attachment in try context.fetch(FetchDescriptor<Attachment>()) { context.delete(attachment) }
        for product in try context.fetch(FetchDescriptor<Product>()) { context.delete(product) }
        try context.save()
        inbox?.remove(inbox?.pendingFiles() ?? [])
    }
}
