import Foundation
import SwiftData
import OSLog

/// Bouwt de `ModelContainer`. CloudKit-sync komt in mijlpaal 7; tot dan is
/// alles lokaal.
enum PersistenceController {
    private static let logger = Logger(subsystem: "com.jeroenlamberts.garantiebewaarder", category: "persistence")

    static let schema = Schema([Product.self, Attachment.self])

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        if !inMemory { ensureApplicationSupportExists() }
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            logger.error("Persistente opslag openen mislukt: \(error.localizedDescription, privacy: .public)")
            // Terugval: werk in het geheugen door in plaats van te crashen.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            if let container = try? ModelContainer(for: schema, configurations: [fallback]) {
                return container
            }
            preconditionFailure("Kan geen ModelContainer maken, ook niet in het geheugen.")
        }
    }

    /// Op een schone installatie bestaat `Application Support` nog niet en
    /// kan SwiftData de store niet aanmaken.
    private static func ensureApplicationSupportExists() {
        guard let url = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else {
            logger.error("Application Support-map aanmaken mislukt")
            return
        }
        _ = url
    }
}
