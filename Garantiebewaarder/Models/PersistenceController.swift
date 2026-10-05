import Foundation
import SwiftData
import OSLog
import os

/// Bouwt de `ModelContainer`, met of zonder iCloud-sync (privé CloudKit-database
/// van de gebruiker). De keuze wordt bij het opstarten gemaakt op basis van de
/// voorkeur; een wijziging werkt dus pas na een herstart. Beide modi gebruiken
/// hetzelfde opslagbestand, dus aan- of uitzetten verliest geen gegevens.
enum PersistenceController {
    enum SyncMode: Equatable, Sendable {
        /// Alleen op dit toestel.
        case local
        /// Synchroniseert via iCloud.
        case iCloud
        /// iCloud was gevraagd maar kon niet starten; de app werkt lokaal door.
        case iCloudUnavailableUsingLocal
    }

    /// TODO(user): moet overeenkomen met de iCloud-container in je Apple Developer-account.
    static let cloudContainerIdentifier = "iCloud.com.jeroenlamberts.garantiebewaarder"

    private static let logger = Logger(subsystem: "com.jeroenlamberts.garantiebewaarder", category: "persistence")
    private static let mode = OSAllocatedUnfairLock(initialState: SyncMode.local)

    static let schema = Schema([Product.self, Attachment.self])

    /// De modus waarmee de huidige container is gestart.
    static var activeMode: SyncMode { mode.withLock { $0 } }

    static func makeContainer(inMemory: Bool = false, syncEnabled: Bool? = nil) -> ModelContainer {
        if inMemory {
            return makeInMemory()
        }
        ensureApplicationSupportExists()
        let wantsSync = syncEnabled ?? AppSettings.bool(AppSettings.Key.iCloudSyncEnabled, default: AppSettings.Default.iCloudSyncEnabled)

        if wantsSync {
            do {
                let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .private(cloudContainerIdentifier))
                let container = try ModelContainer(for: schema, configurations: [configuration])
                mode.withLock { $0 = .iCloud }
                return container
            } catch {
                // Geen account, geen entitlement of een schemaprobleem: werk gewoon lokaal door.
                logger.error("iCloud-sync starten mislukt: \(error.localizedDescription, privacy: .public)")
            }
        }

        do {
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [local])
            mode.withLock { $0 = wantsSync ? .iCloudUnavailableUsingLocal : .local }
            return container
        } catch {
            logger.error("Persistente opslag openen mislukt: \(error.localizedDescription, privacy: .public)")
            mode.withLock { $0 = wantsSync ? .iCloudUnavailableUsingLocal : .local }
            return makeInMemory()
        }
    }

    private static func makeInMemory() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        guard let container = try? ModelContainer(for: schema, configurations: [configuration]) else {
            preconditionFailure("Kan geen ModelContainer in het geheugen maken.")
        }
        return container
    }

    /// Op een schone installatie bestaat `Application Support` nog niet en
    /// kan SwiftData de store niet aanmaken.
    private static func ensureApplicationSupportExists() {
        do {
            _ = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        } catch {
            logger.error("Application Support-map aanmaken mislukt")
        }
    }
}
