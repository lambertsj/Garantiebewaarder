import SwiftUI
import SwiftData

/// Eén gedeelde scheduler voor de hele app.
@MainActor
enum Reminders {
    static let scheduler = NotificationScheduler()

    static func syncNow(products: [Product]) async {
        await scheduler.sync(candidates: products.map(ReminderCandidate.init), settings: .current())
    }
}

/// Houdt de lokale meldingen gelijk aan de producten en instellingen: bij
/// start, bij terugkeren naar de app, na elke wijziging (ook door sync).
struct ReminderSync: ViewModifier {
    @Query private var products: [Product]
    @AppStorage(AppSettings.Key.remindersEnabled) private var enabled = AppSettings.Default.remindersEnabled
    @AppStorage(AppSettings.Key.reminderLeadDays) private var leadDays = AppSettings.Default.reminderLeadDays
    @AppStorage(AppSettings.Key.secondReminderEnabled) private var second = AppSettings.Default.secondReminderEnabled
    @Environment(\.scenePhase) private var scenePhase
    @State private var activations = 0

    private var signature: Int {
        var hasher = Hasher()
        for product in products {
            hasher.combine(product.id)
            hasher.combine(product.name)
            hasher.combine(product.warrantyEndDate)
            hasher.combine(product.isArchived)
        }
        hasher.combine(enabled)
        hasher.combine(leadDays)
        hasher.combine(second)
        hasher.combine(activations)
        return hasher.finalize()
    }

    func body(content: Content) -> some View {
        content
            .task(id: signature) {
                // Korte wachttijd: bundelt snel opeenvolgende wijzigingen.
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await Reminders.syncNow(products: products)
                await SystemIntegration.update(products: products, leadDays: leadDays)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { activations += 1 }
            }
    }
}

extension View {
    func syncsReminders() -> some View { modifier(ReminderSync()) }
}
