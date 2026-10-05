import Foundation

/// Wat de planner van een product nodig heeft; los van SwiftData zodat het testbaar blijft.
struct ReminderCandidate: Equatable, Sendable {
    var id: UUID
    var name: String
    var warrantyEndDate: Date
    var isArchived: Bool

    init(id: UUID, name: String, warrantyEndDate: Date, isArchived: Bool) {
        self.id = id
        self.name = name
        self.warrantyEndDate = warrantyEndDate
        self.isArchived = isArchived
    }

    init(_ product: Product) {
        self.init(id: product.id, name: product.name, warrantyEndDate: product.warrantyEndDate, isArchived: product.isArchived)
    }
}

struct ReminderSettings: Equatable, Sendable {
    var isEnabled: Bool
    var leadDays: Int
    var secondReminderEnabled: Bool

    static func current(defaults: UserDefaults = .standard) -> ReminderSettings {
        ReminderSettings(
            isEnabled: AppSettings.bool(AppSettings.Key.remindersEnabled, default: AppSettings.Default.remindersEnabled, in: defaults),
            leadDays: AppSettings.int(AppSettings.Key.reminderLeadDays, default: AppSettings.Default.reminderLeadDays, in: defaults),
            secondReminderEnabled: AppSettings.bool(AppSettings.Key.secondReminderEnabled, default: AppSettings.Default.secondReminderEnabled, in: defaults)
        )
    }
}

struct PlannedReminder: Equatable, Sendable {
    var identifier: String
    var productID: UUID
    var productName: String
    var daysBefore: Int
    var fireDate: Date
}

/// Bepaalt welke meldingen er moeten komen. Puur; plant zelf niets in.
enum NotificationPlanner {
    /// iOS staat 64 lokale meldingen tegelijk toe; we houden marge over.
    static let maxScheduled = 60
    static let secondLeadDays = 7
    static let fireHour = 10

    static func plan(
        candidates: [ReminderCandidate],
        settings: ReminderSettings,
        now: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = maxScheduled
    ) -> [PlannedReminder] {
        guard settings.isEnabled, settings.leadDays > 0 else { return [] }
        var leads = [settings.leadDays]
        if settings.secondReminderEnabled, settings.leadDays > secondLeadDays { leads.append(secondLeadDays) }

        var planned: [PlannedReminder] = []
        for candidate in candidates where !candidate.isArchived {
            let endDay = calendar.startOfDay(for: candidate.warrantyEndDate)
            for lead in leads {
                guard let day = calendar.date(byAdding: .day, value: -lead, to: endDay),
                      let fire = calendar.date(bySettingHour: fireHour, minute: 0, second: 0, of: day),
                      fire > now
                else { continue }
                planned.append(PlannedReminder(
                    identifier: identifier(productID: candidate.id, daysBefore: lead),
                    productID: candidate.id, productName: candidate.name, daysBefore: lead, fireDate: fire
                ))
            }
        }
        return Array(
            planned.sorted { ($0.fireDate, $0.identifier) < ($1.fireDate, $1.identifier) }.prefix(max(0, limit))
        )
    }

    static func identifier(productID: UUID, daysBefore: Int) -> String {
        "warranty-\(productID.uuidString)-\(daysBefore)"
    }
}
