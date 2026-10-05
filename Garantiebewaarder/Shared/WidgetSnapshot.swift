import Foundation

/// De minimale gegevens die de widget nodig heeft (geen bijlagen, geen bontekst).
/// Wordt door de app naar de App Group geschreven en door de widget gelezen.
struct WidgetSnapshot: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Sendable, Identifiable {
        var id: UUID
        var name: String
        var endDate: Date
    }

    static let maxItems = 5

    var items: [Item]
    /// Herinneringsdrempel, zodat de widget dezelfde statuskleur kan tonen als de app.
    var leadDays: Int
    var updatedAt: Date

    static let empty = WidgetSnapshot(items: [], leadDays: AppSettings.Default.reminderLeadDays, updatedAt: .distantPast)

    /// De eerstvolgende garanties die nog lopen (niet gearchiveerd, einddatum vandaag of later).
    static func make(
        candidates: [ReminderCandidate],
        leadDays: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WidgetSnapshot {
        let today = calendar.startOfDay(for: now)
        let items = candidates
            .filter { !$0.isArchived && calendar.startOfDay(for: $0.warrantyEndDate) >= today }
            .sorted { ($0.warrantyEndDate, $0.name) < ($1.warrantyEndDate, $1.name) }
            .prefix(maxItems)
            .map { Item(id: $0.id, name: $0.name, endDate: calendar.startOfDay(for: $0.warrantyEndDate)) }
        return WidgetSnapshot(items: Array(items), leadDays: leadDays, updatedAt: now)
    }
}

enum WidgetStore {
    static let fileName = "widget-snapshot.json"

    static func fileURL() -> URL? {
        AppGroup.containerURL?.appendingPathComponent(fileName)
    }

    static func save(_ snapshot: WidgetSnapshot, to url: URL? = fileURL()) throws {
        guard let url else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(snapshot).write(to: url, options: .atomic)
    }

    static func load(from url: URL? = fileURL()) -> WidgetSnapshot {
        guard let url, let data = try? Data(contentsOf: url) else { return .empty }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(WidgetSnapshot.self, from: data)) ?? .empty
    }
}
