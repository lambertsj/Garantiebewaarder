import CloudKit
import Foundation

/// Toestand van het iCloud-account, voor weergave in de instellingen.
/// Leest alleen de accountstatus; er worden geen gegevens opgehaald of verstuurd.
enum ICloudStatus: Equatable, Sendable {
    case available
    case noAccount
    case restricted
    case unknown

    static func fetch() async -> ICloudStatus {
        do {
            let status = try await CKContainer(identifier: PersistenceController.cloudContainerIdentifier).accountStatus()
            return map(status)
        } catch {
            return .unknown
        }
    }

    static func map(_ status: CKAccountStatus) -> ICloudStatus {
        switch status {
        case .available: .available
        case .noAccount: .noAccount
        case .restricted: .restricted
        case .couldNotDetermine, .temporarilyUnavailable: .unknown
        @unknown default: .unknown
        }
    }

    var symbolName: String {
        switch self {
        case .available: "checkmark.icloud"
        case .noAccount: "icloud.slash"
        case .restricted: "exclamationmark.icloud"
        case .unknown: "questionmark.circle"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .available: "icloud.status.available"
        case .noAccount: "icloud.status.noAccount"
        case .restricted: "icloud.status.restricted"
        case .unknown: "icloud.status.unknown"
        }
    }
}
