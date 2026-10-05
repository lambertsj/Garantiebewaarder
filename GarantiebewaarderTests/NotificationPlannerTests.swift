import Foundation
import Testing
import UserNotifications
@testable import Garantiebewaarder

private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
    return c
}()
private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))! }
private let now = day(2026, 6, 1, hour: 12)

private func candidate(_ name: String, end: Date, archived: Bool = false) -> ReminderCandidate {
    ReminderCandidate(id: UUID(), name: name, warrantyEndDate: end, isArchived: archived)
}
private let defaults = ReminderSettings(isEnabled: true, leadDays: 30, secondReminderEnabled: true)

@Suite("NotificationPlanner")
struct NotificationPlannerTests {
    @Test func schedulesLeadAndSecondReminderAtTenLocalTime() {
        let c = candidate("Tv", end: day(2026, 9, 15))
        let plan = NotificationPlanner.plan(candidates: [c], settings: defaults, now: now, calendar: cal)
        #expect(plan.map(\.daysBefore) == [30, 7])
        #expect(plan[0].fireDate == day(2026, 8, 16, hour: 10))
        #expect(plan[1].fireDate == day(2026, 9, 8, hour: 10))
        #expect(plan.allSatisfy { $0.productID == c.id })
    }

    @Test func secondReminderCanBeDisabledAndSkippedWhenLeadIsShort() {
        let c = candidate("Tv", end: day(2026, 9, 15))
        let off = ReminderSettings(isEnabled: true, leadDays: 30, secondReminderEnabled: false)
        #expect(NotificationPlanner.plan(candidates: [c], settings: off, now: now, calendar: cal).map(\.daysBefore) == [30])
        let short = ReminderSettings(isEnabled: true, leadDays: 7, secondReminderEnabled: true)
        #expect(NotificationPlanner.plan(candidates: [c], settings: short, now: now, calendar: cal).map(\.daysBefore) == [7])
    }

    @Test func skipsArchivedExpiredAndAlreadyPassedReminders() {
        let archived = candidate("Archief", end: day(2027, 1, 1), archived: true)
        let expired = candidate("Oud", end: day(2026, 1, 1))
        let soon = candidate("Binnenkort", end: day(2026, 6, 20)) // 30 dagen-melding is al voorbij, 7 dagen niet
        let plan = NotificationPlanner.plan(candidates: [archived, expired, soon], settings: defaults, now: now, calendar: cal)
        #expect(plan.count == 1)
        #expect(plan[0].productName == "Binnenkort" && plan[0].daysBefore == 7)
    }

    @Test func disabledSettingsPlanNothing() {
        let off = ReminderSettings(isEnabled: false, leadDays: 30, secondReminderEnabled: true)
        #expect(NotificationPlanner.plan(candidates: [candidate("Tv", end: day(2027, 1, 1))], settings: off, now: now, calendar: cal).isEmpty)
    }

    @Test func respectsTheSixtyNotificationCapKeepingTheSoonest() {
        // 100 producten × 2 meldingen = 200 kandidaten; er mogen er maximaal 60 door.
        let candidates = (0..<100).map { i in candidate("P\(i)", end: day(2026, 8, 1).addingTimeInterval(Double(i) * 86_400)) }
        let plan = NotificationPlanner.plan(candidates: candidates, settings: defaults, now: now, calendar: cal)
        #expect(plan.count == NotificationPlanner.maxScheduled)
        #expect(plan.map(\.fireDate) == plan.map(\.fireDate).sorted())
        let all = NotificationPlanner.plan(candidates: candidates, settings: defaults, now: now, calendar: cal, limit: 1000)
        #expect(plan == Array(all.prefix(60)))
        #expect(Set(all.map(\.identifier)).count == all.count)
    }

    @Test func fireTimeStaysTenOClockAcrossDST() {
        // Einddatum 5 april 2026 − 30 dagen = 6 maart (wintertijd); − 7 = 29 maart (zomertijd begint 29 maart 2026).
        let c = candidate("Fiets", end: day(2026, 4, 5))
        let plan = NotificationPlanner.plan(candidates: [c], settings: defaults, now: day(2026, 1, 1), calendar: cal)
        for reminder in plan {
            let parts = cal.dateComponents([.hour, .minute], from: reminder.fireDate)
            #expect(parts.hour == 10 && parts.minute == 0)
        }
        #expect(plan.count == 2)
    }

    @Test func identifierIsStablePerProductAndLead() {
        let id = UUID()
        #expect(NotificationPlanner.identifier(productID: id, daysBefore: 30) == "warranty-\(id.uuidString)-30")
    }
}

/// Nep-centrum: onthoudt wat er gebeurt, zonder iets in iOS te plannen.
private final class FakeCenter: UserNotificationCenterProtocol, @unchecked Sendable {
    var status: UNAuthorizationStatus
    var grantOnRequest = true
    private(set) var removeAllCalls = 0
    private(set) var added: [UNNotificationRequest] = []
    private(set) var requestedAuthorization = 0

    init(status: UNAuthorizationStatus) { self.status = status }

    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func requestAuthorization() async throws -> Bool { requestedAuthorization += 1; return grantOnRequest }
    func removeAllPendingNotificationRequests() { removeAllCalls += 1; added.removeAll() }
    func add(_ request: sending UNNotificationRequest) async throws { added.append(request) }
}

@MainActor
@Suite("NotificationScheduler")
struct NotificationSchedulerTests {
    private let one = [candidate("Wasmachine", end: day(2026, 12, 1))]

    @Test func addsRequestsWithDeepLinkInfoWhenAuthorized() async throws {
        let center = FakeCenter(status: .authorized)
        let scheduler = NotificationScheduler(center: center)
        let plan = await scheduler.sync(candidates: one, settings: defaults, now: now, calendar: cal)
        #expect(plan.count == 2)
        #expect(center.removeAllCalls == 1)
        #expect(center.added.count == 2)
        let request = try #require(center.added.first)
        #expect(request.content.userInfo[NotificationScheduler.productIDKey] as? String == one[0].id.uuidString)
        #expect(request.content.body.contains("Wasmachine"))
        #expect(request.trigger is UNCalendarNotificationTrigger)
        #expect((request.trigger as? UNCalendarNotificationTrigger)?.repeats == false)
    }

    @Test func schedulesNothingWhenDeniedButStillClearsOldOnes() async {
        let center = FakeCenter(status: .denied)
        let plan = await NotificationScheduler(center: center).sync(candidates: one, settings: defaults, now: now, calendar: cal)
        #expect(plan.isEmpty)
        #expect(center.added.isEmpty)
        #expect(center.removeAllCalls == 1)
    }

    @Test func neverPromptsForPermissionDuringSync() async {
        let center = FakeCenter(status: .notDetermined)
        await NotificationScheduler(center: center).sync(candidates: one, settings: defaults, now: now, calendar: cal)
        #expect(center.requestedAuthorization == 0)
        #expect(center.added.isEmpty)
    }

    @Test func resyncReplacesInsteadOfDuplicating() async {
        let center = FakeCenter(status: .authorized)
        let scheduler = NotificationScheduler(center: center)
        await scheduler.sync(candidates: one, settings: defaults, now: now, calendar: cal)
        await scheduler.sync(candidates: one, settings: defaults, now: now, calendar: cal)
        #expect(center.removeAllCalls == 2)
        #expect(center.added.count == 2)
    }

    @Test func disabledRemindersClearEverything() async {
        let center = FakeCenter(status: .authorized)
        let off = ReminderSettings(isEnabled: false, leadDays: 30, secondReminderEnabled: true)
        await NotificationScheduler(center: center).sync(candidates: one, settings: off, now: now, calendar: cal)
        #expect(center.added.isEmpty)
        #expect(center.removeAllCalls == 1)
    }

    @Test func bodySingularAndPlural() {
        let nl = Bundle.main.path(forResource: "nl", ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        #expect(NotificationScheduler.body(productName: "Tv", days: 30, bundle: nl)
                == "De garantie op je Tv loopt over 30 dagen af. Werkt alles nog goed? Controleer het nu nog.")
        #expect(NotificationScheduler.body(productName: "Tv", days: 1, bundle: nl).contains("morgen"))
    }
}
