import Foundation
import Testing
@testable import Garantiebewaarder

/// Vaste kalender zodat tests niet afhangen van de tijdzone van de machine.
private let amsterdam: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
    calendar.locale = Locale(identifier: "nl_NL")
    return calendar
}()

private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0, minute: Int = 0) -> Date {
    amsterdam.date(from: DateComponents(year: y, month: m, day: d, hour: hour, minute: minute))!
}

@Suite("WarrantyCalculator.endDate")
struct EndDateTests {
    @Test func addsTwentyFourMonths() {
        let end = WarrantyCalculator.endDate(purchaseDate: date(2024, 6, 15, hour: 14), months: 24, calendar: amsterdam)
        #expect(end == date(2026, 6, 15))
    }

    @Test func leapDayPlusOneYearClampsToFeb28() {
        let end = WarrantyCalculator.endDate(purchaseDate: date(2024, 2, 29), months: 12, calendar: amsterdam)
        #expect(end == date(2025, 2, 28))
    }

    @Test func leapDayPlusFourYearsStaysFeb29() {
        let end = WarrantyCalculator.endDate(purchaseDate: date(2024, 2, 29), months: 48, calendar: amsterdam)
        #expect(end == date(2028, 2, 29))
    }

    @Test func monthEndClampsToShorterMonth() {
        #expect(WarrantyCalculator.endDate(purchaseDate: date(2025, 1, 31), months: 1, calendar: amsterdam) == date(2025, 2, 28))
        #expect(WarrantyCalculator.endDate(purchaseDate: date(2024, 1, 31), months: 1, calendar: amsterdam) == date(2024, 2, 29))
        #expect(WarrantyCalculator.endDate(purchaseDate: date(2025, 3, 31), months: 1, calendar: amsterdam) == date(2025, 4, 30))
    }

    @Test func monthEndKeepsDayWhenTargetMonthIsLongEnough() {
        #expect(WarrantyCalculator.endDate(purchaseDate: date(2025, 1, 31), months: 24, calendar: amsterdam) == date(2027, 1, 31))
    }

    @Test func resultIsAlwaysStartOfDayAcrossDST() {
        // Aankoop in de winter, einde in de zomer (en andersom): geen uur-verschuiving.
        for (purchase, months) in [(date(2025, 1, 10, hour: 23, minute: 59), 3), (date(2025, 7, 10, hour: 0, minute: 1), 4)] {
            let end = WarrantyCalculator.endDate(purchaseDate: purchase, months: months, calendar: amsterdam)
            let parts = amsterdam.dateComponents([.hour, .minute, .second], from: end)
            #expect(parts.hour == 0 && parts.minute == 0 && parts.second == 0)
        }
    }

    @Test func zeroAndNegativeMonthsKeepPurchaseDay() {
        #expect(WarrantyCalculator.endDate(purchaseDate: date(2025, 5, 5, hour: 9), months: 0, calendar: amsterdam) == date(2025, 5, 5))
        #expect(WarrantyCalculator.endDate(purchaseDate: date(2025, 5, 5, hour: 9), months: -3, calendar: amsterdam) == date(2025, 5, 5))
    }
}

@Suite("WarrantyCalculator.status en resterend")
struct StatusTests {
    private let end = date(2026, 3, 3)

    @Test func coveredWhenMoreThanLeadDaysRemain() {
        #expect(WarrantyCalculator.status(endDate: end, now: date(2025, 12, 1), leadDays: 30, calendar: amsterdam) == .covered)
    }

    @Test func expiringSoonExactlyAtLeadDays() {
        let now = date(2026, 2, 1) // 30 dagen voor 3 maart
        #expect(WarrantyCalculator.daysRemaining(endDate: end, now: now, calendar: amsterdam) == 30)
        #expect(WarrantyCalculator.status(endDate: end, now: now, leadDays: 30, calendar: amsterdam) == .expiringSoon)
        #expect(WarrantyCalculator.status(endDate: end, now: date(2026, 1, 31), leadDays: 30, calendar: amsterdam) == .covered)
    }

    @Test func endDateItselfIsStillCovered() {
        #expect(WarrantyCalculator.status(endDate: end, now: date(2026, 3, 3, hour: 23, minute: 59), leadDays: 30, calendar: amsterdam) == .expiringSoon)
        #expect(WarrantyCalculator.remaining(endDate: end, now: date(2026, 3, 3, hour: 23, minute: 59), calendar: amsterdam) == .today)
    }

    @Test func expiredDayAfterEndDate() {
        let now = date(2026, 3, 4, hour: 0, minute: 1)
        #expect(WarrantyCalculator.status(endDate: end, now: now, leadDays: 30, calendar: amsterdam) == .expired)
        #expect(WarrantyCalculator.remaining(endDate: end, now: now, calendar: amsterdam) == .expired(on: end))
    }

    @Test func endDateInThePastIsExpired() {
        #expect(WarrantyCalculator.status(endDate: date(2020, 1, 1), now: date(2026, 1, 1), leadDays: 30, calendar: amsterdam) == .expired)
    }

    @Test func daysAcrossDSTAreWholeDays() {
        // 29 maart 2025 → 31 maart 2025 is 47 uur (zomertijd), maar 2 kalenderdagen.
        #expect(WarrantyCalculator.daysRemaining(endDate: date(2025, 3, 31), now: date(2025, 3, 29, hour: 12), calendar: amsterdam) == 2)
        // En in de herfst (26 oktober 2025, 25-uurs dag).
        #expect(WarrantyCalculator.daysRemaining(endDate: date(2025, 10, 27), now: date(2025, 10, 25, hour: 23), calendar: amsterdam) == 2)
    }

    @Test func remainingShowsMonthsFarOut() {
        let now = date(2025, 1, 1)
        #expect(WarrantyCalculator.remaining(endDate: date(2026, 3, 1), now: now, calendar: amsterdam) == .months(14))
    }

    @Test func remainingShowsDaysWithinSixtyDays() {
        let now = date(2026, 2, 22)
        #expect(WarrantyCalculator.remaining(endDate: end, now: now, calendar: amsterdam) == .days(9))
        #expect(WarrantyCalculator.remaining(endDate: date(2026, 4, 22), now: date(2026, 2, 21), calendar: amsterdam) == .days(60))
    }

    @Test func remainingNeverShowsFewerThanTwoMonths() {
        // 61 dagen = net boven de drempel; blijft "2 maanden", nooit "1 maand".
        #expect(WarrantyCalculator.remaining(endDate: date(2026, 4, 23), now: date(2026, 2, 21), calendar: amsterdam) == .months(2))
    }

    @Test func futurePurchaseDateIsFlagged() {
        let now = date(2026, 1, 10, hour: 10)
        #expect(WarrantyCalculator.purchaseDateIssue(purchaseDate: date(2026, 1, 11), now: now, calendar: amsterdam) == .inFuture)
        #expect(WarrantyCalculator.purchaseDateIssue(purchaseDate: date(2026, 1, 10, hour: 23), now: now, calendar: amsterdam) == nil)
        #expect(WarrantyCalculator.purchaseDateIssue(purchaseDate: date(2025, 1, 1), now: now, calendar: amsterdam) == nil)
    }
}

@Suite("Tekst voor resterende tijd")
struct RemainingTextTests {
    private let nl = Locale(identifier: "nl_NL")
    private let nlBundle: Bundle = {
        let main = Bundle.main
        return main.path(forResource: "nl", ofType: "lproj").flatMap(Bundle.init(path:)) ?? main
    }()

    @Test func dutchFormatting() {
        #expect(WarrantyRemaining.months(14).text(bundle: nlBundle, locale: nl) == "nog 14 maanden")
        #expect(WarrantyRemaining.days(9).text(bundle: nlBundle, locale: nl) == "nog 9 dagen")
        #expect(WarrantyRemaining.days(1).text(bundle: nlBundle, locale: nl) == "nog 1 dag")
        #expect(WarrantyRemaining.today.text(bundle: nlBundle, locale: nl) == "Loopt vandaag af")
        #expect(WarrantyRemaining.expired(on: date(2026, 3, 3)).text(bundle: nlBundle, locale: nl) == "Verlopen op 3 maart 2026")
    }
}
