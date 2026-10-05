import CoreSpotlight
import Foundation
import OSLog
import UniformTypeIdentifiers
import WidgetKit

/// Houdt Spotlight en de widget bij. Alles lokaal: de Spotlight-index blijft op
/// het toestel en de widget krijgt alleen naam, einddatum en id.
@MainActor
enum SystemIntegration {
    private static let logger = Logger(subsystem: "com.jeroenlamberts.garantiebewaarder", category: "system")
    static let spotlightDomain = "products"

    static func update(products: [Product], leadDays: Int) async {
        updateWidget(products: products, leadDays: leadDays)
        await updateSpotlight(products: products)
    }

    // MARK: Widget

    static func updateWidget(products: [Product], leadDays: Int) {
        let snapshot = WidgetSnapshot.make(candidates: products.map(ReminderCandidate.init), leadDays: leadDays)
        do {
            try WidgetStore.save(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            logger.error("Widget-gegevens schrijven mislukt: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Spotlight

    /// Alleen niet-gearchiveerde producten; bontekst en bijlagen gaan niet in de index.
    static func searchableItems(for products: [Product]) -> [CSSearchableItem] {
        products.filter { !$0.isArchived }.map { product in
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = product.name
            let details = [product.brand, product.store].filter { !$0.isEmpty }
            let until = String(localized: "spotlight.until \(product.warrantyEndDate.formatted(date: .long, time: .omitted))")
            attributes.contentDescription = (details + [until]).joined(separator: " · ")
            attributes.keywords = [product.name, product.brand, product.store, String(localized: product.category.title)].filter { !$0.isEmpty }
            attributes.thumbnailData = (product.attachments ?? []).first(where: { $0.thumbnailData != nil })?.thumbnailData
            return CSSearchableItem(uniqueIdentifier: product.id.uuidString, domainIdentifier: spotlightDomain, attributeSet: attributes)
        }
    }

    static func updateSpotlight(products: [Product]) async {
        let index = CSSearchableIndex.default()
        let items = searchableItems(for: products)
        do {
            try await index.deleteSearchableItems(withDomainIdentifiers: [spotlightDomain])
            if !items.isEmpty { try await index.indexSearchableItems(items) }
        } catch {
            logger.error("Spotlight bijwerken mislukt: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Deep links

    static func productID(from url: URL) -> UUID? {
        guard url.scheme == "garantiebewaarder", url.host() == "product" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }

    static func productID(from activity: NSUserActivity) -> UUID? {
        (activity.userInfo?[CSSearchableItemActivityIdentifier] as? String).flatMap(UUID.init(uuidString:))
    }
}
