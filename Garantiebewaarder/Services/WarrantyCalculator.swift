import Foundation

/// Pure garantieberekeningen. Alles werkt met `startOfDay` in de opgegeven
/// kalender, zodat tijdzones en zomer-/wintertijd geen uur-verschuivingen
/// veroorzaken.
enum WarrantyCalculator {
    /// Waarschuwing bij een aankoopdatum die niet klopt.
    enum PurchaseDateIssue: Equatable, Sendable {
        case inFuture
    }

    /// Einddatum = aankoopdatum + `months` kalendermaanden, als start van de dag.
    /// Bij maandeinden klemt Calendar naar de laatste dag van de doelmaand
    /// (31 jan + 1 maand = 28 of 29 feb).
    static func endDate(
        purchaseDate: Date,
        months: Int,
        calendar: Calendar = .current
    ) -> Date {
        let start = calendar.startOfDay(for: purchaseDate)
        let end = calendar.date(byAdding: .month, value: max(0, months), to: start) ?? start
        return calendar.startOfDay(for: end)
    }

    static func purchaseDateIssue(
        purchaseDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> PurchaseDateIssue? {
        calendar.startOfDay(for: purchaseDate) > calendar.startOfDay(for: now) ? .inFuture : nil
    }

    /// Hele kalenderdagen van vandaag tot de einddatum (negatief = verlopen).
    static func daysRemaining(endDate: Date, now: Date = Date(), calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: endDate)
        return calendar.dateComponents([.day], from: today, to: end).day ?? 0
    }

    /// De einddatum zelf is nog een geldige dag: de garantie is verlopen
    /// vanaf de dag erna.
    static func status(
        endDate: Date,
        now: Date = Date(),
        leadDays: Int,
        calendar: Calendar = .current
    ) -> WarrantyStatus {
        let days = daysRemaining(endDate: endDate, now: now, calendar: calendar)
        if days < 0 { return .expired }
        if days <= leadDays { return .expiringSoon }
        return .covered
    }

    /// Vanaf deze afstand (in dagen) tonen we maanden in plaats van dagen.
    static let monthsThresholdDays = 60

    static func remaining(
        endDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WarrantyRemaining {
        let days = daysRemaining(endDate: endDate, now: now, calendar: calendar)
        if days < 0 { return .expired(on: calendar.startOfDay(for: endDate)) }
        if days == 0 { return .today }
        if days > monthsThresholdDays {
            let today = calendar.startOfDay(for: now)
            let end = calendar.startOfDay(for: endDate)
            let months = calendar.dateComponents([.month], from: today, to: end).month ?? 0
            return .months(max(2, months))
        }
        return .days(days)
    }
}
