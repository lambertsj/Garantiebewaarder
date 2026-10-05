import Foundation

/// Afgeleide status van een garantie. Wordt berekend, nooit opgeslagen.
enum WarrantyStatus: String, CaseIterable, Identifiable, Sendable {
    /// Nog gedekt, met meer dan `reminderLeadDays` resterend.
    case covered
    /// Loopt binnen `reminderLeadDays` af.
    case expiringSoon
    case expired

    var id: String { rawValue }

    /// Status wordt altijd getoond met icoon én tekst, nooit alleen met kleur.
    var symbolName: String {
        switch self {
        case .covered: "checkmark.shield.fill"
        case .expiringSoon: "exclamationmark.triangle.fill"
        case .expired: "xmark.shield.fill"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .covered: "status.covered"
        case .expiringSoon: "status.expiringSoon"
        case .expired: "status.expired"
        }
    }
}

/// Resterende tijd tot de einddatum, als pure waarde zodat hij testbaar is
/// los van lokalisatie. De tekst staat in `WarrantyRemaining+Text.swift`.
enum WarrantyRemaining: Equatable, Sendable {
    case months(Int)
    case days(Int)
    case today
    case expired(on: Date)
}
