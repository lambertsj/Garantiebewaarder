import Foundation
import SwiftData

#if DEBUG
/// Voorbeelddata voor SwiftUI-previews en tests.
@MainActor
enum PreviewData {
    static func container() -> ModelContainer {
        let container = PersistenceController.makeContainer(inMemory: true)
        for product in sampleProducts() { container.mainContext.insert(product) }
        return container
    }

    static func sampleProducts(now: Date = Date(), calendar: Calendar = .current) -> [Product] {
        func product(_ name: String, _ brand: String, _ category: ProductCategory, _ store: String,
                     boughtMonthsAgo: Int, months: Int, price: Decimal?) -> Product {
            let purchase = calendar.date(byAdding: .month, value: -boughtMonthsAgo, to: now) ?? now
            return Product(
                name: name, brand: brand, category: category, store: store,
                purchaseDate: purchase, price: price,
                warrantyEndDate: WarrantyCalculator.endDate(purchaseDate: purchase, months: months, calendar: calendar)
            )
        }
        return [
            product("Wasmachine", "Voorbeeldmerk", .appliances, "Voorbeeldwinkel", boughtMonthsAgo: 4, months: 24, price: 649),
            product("Laptop", "Voorbeeldmerk", .phoneComputer, "Voorbeeldwinkel", boughtMonthsAgo: 23, months: 24, price: 1299),
            product("Koptelefoon", "Voorbeeldmerk", .electronics, "Voorbeeldwinkel", boughtMonthsAgo: 30, months: 24, price: 89.95),
            product("E-bike", "Voorbeeldmerk", .bikeMobility, "Voorbeeldwinkel", boughtMonthsAgo: 10, months: 36, price: 2199),
        ]
    }
}
#endif
