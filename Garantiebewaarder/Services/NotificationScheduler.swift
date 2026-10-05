import Foundation
import UserNotifications
import OSLog

/// Smalle laag om `UNUserNotificationCenter` zodat de planning testbaar is.
protocol UserNotificationCenterProtocol: Sendable {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func removeAllPendingNotificationRequests()
    func add(_ request: sending UNNotificationRequest) async throws
}

extension UNUserNotificationCenter: UserNotificationCenterProtocol {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await requestAuthorization(options: [.alert, .sound])
    }
}

/// Plant uitsluitend lokale meldingen. Houdt de lijst in iOS gelijk aan de
/// planning: bij elke sync wordt alles verwijderd en opnieuw ingepland.
@MainActor
final class NotificationScheduler {
    nonisolated static let productIDKey = "productID"

    private let center: UserNotificationCenterProtocol
    private let logger = Logger(subsystem: "com.jeroenlamberts.garantiebewaarder", category: "notifications")

    init(center: UserNotificationCenterProtocol = UNUserNotificationCenter.current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.authorizationStatus()
    }

    /// Vraagt toestemming. Alleen aanroepen na uitleg aan de gebruiker.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization()
        } catch {
            logger.error("Toestemming vragen mislukt: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Zet de meldingen gelijk aan de huidige producten en instellingen.
    /// Vraagt nooit zelf toestemming; zonder toestemming blijft de lijst leeg.
    @discardableResult
    func sync(
        candidates: [ReminderCandidate],
        settings: ReminderSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async -> [PlannedReminder] {
        center.removeAllPendingNotificationRequests()
        guard settings.isEnabled else { return [] }
        let status = await center.authorizationStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return [] }

        let plan = NotificationPlanner.plan(candidates: candidates, settings: settings, now: now, calendar: calendar)
        for reminder in plan {
            do {
                try await center.add(Self.request(for: reminder, calendar: calendar))
            } catch {
                logger.error("Melding inplannen mislukt: \(error.localizedDescription, privacy: .public)")
            }
        }
        return plan
    }

    nonisolated static func request(for reminder: PlannedReminder, calendar: Calendar) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = AppInfo.name
        content.body = body(productName: reminder.productName, days: reminder.daysBefore)
        content.sound = .default
        content.userInfo = [productIDKey: reminder.productID.uuidString]
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
    }

    nonisolated static func body(productName: String, days: Int, bundle: Bundle = .main) -> String {
        days == 1
            ? String(localized: "reminder.body.one \(productName)", bundle: bundle)
            : String(localized: "reminder.body.other \(productName) \(days)", bundle: bundle)
    }
}
