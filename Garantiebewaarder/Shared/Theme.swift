import SwiftUI

/// Kleuren en vaste maten. Statuskleur wordt altijd met icoon en tekst getoond.
enum Theme {
    static func color(for status: WarrantyStatus) -> Color {
        switch status {
        case .covered: .green
        case .expiringSoon: .orange
        case .expired: .red
        }
    }
}

/// Status als badge: icoon + tekst + kleur.
struct StatusBadge: View {
    let status: WarrantyStatus

    var body: some View {
        Label(String(localized: status.title), systemImage: status.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.color(for: status))
            .accessibilityIdentifier("statusBadge")
    }
}
