import Foundation

extension WarrantyRemaining {
    /// "nog 14 maanden", "nog 9 dagen", "loopt vandaag af",
    /// "verlopen op 3 maart 2026".
    ///
    /// `bundle` en `locale` zijn injecteerbaar zodat tests een vaste taal
    /// kunnen kiezen, los van de taal van het toestel.
    func text(bundle: Bundle = .main, locale: Locale = .current) -> String {
        switch self {
        case .months(let n):
            String(localized: "remaining.months \(n)", bundle: bundle, locale: locale)
        case .days(let n):
            String(localized: "remaining.days \(n)", bundle: bundle, locale: locale)
        case .today:
            String(localized: "remaining.today", bundle: bundle, locale: locale)
        case .expired(let date):
            String(
                localized: "remaining.expiredOn \(date.formatted(.dateTime.day().month(.wide).year().locale(locale)))",
                bundle: bundle, locale: locale
            )
        }
    }
}
