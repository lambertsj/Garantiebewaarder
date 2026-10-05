import Foundation
import Testing
@testable import Garantiebewaarder

private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
    return c
}()
private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d))! }

@MainActor
@Suite("ProductListQuery")
struct ProductListQueryTests {
    let now = day(2026, 6, 1)

    private func product(_ name: String, end: Date, bought: Date = day(2024, 1, 1), store: String = "", serial: String = "",
                         category: ProductCategory = .other, archived: Bool = false) -> Product {
        let p = Product(name: name, store: store, purchaseDate: bought, warrantyEndDate: end)
        p.serialNumber = serial
        p.category = category
        p.isArchived = archived
        return p
    }

    private var sample: [Product] {
        [
            product("Laptop", end: day(2026, 6, 20), store: "Coolblue", category: .phoneComputer), // bijna verlopen
            product("Wasmachine", end: day(2028, 1, 1), bought: day(2026, 1, 1), serial: "SN-123", category: .appliances),
            product("Tv", end: day(2025, 1, 1)),                                                     // verlopen
            product("Oude fiets", end: day(2027, 1, 1), archived: true),
        ]
    }

    private func names(_ q: ProductListQuery) -> [String] {
        q.apply(to: sample, now: now, leadDays: 30, calendar: cal).map(\.name)
    }

    @Test func defaultSortPutsExpiringFirstAndExpiredLast() {
        #expect(names(ProductListQuery()) == ["Laptop", "Wasmachine", "Tv"])
    }

    @Test func archivedProductsAreHidden() {
        #expect(!names(ProductListQuery()).contains("Oude fiets"))
    }

    @Test func statusFilters() {
        #expect(names(.init(status: .expiringSoon)) == ["Laptop"])
        #expect(names(.init(status: .covered)) == ["Wasmachine"])
        #expect(names(.init(status: .expired)) == ["Tv"])
    }

    @Test func categoryFilter() {
        #expect(names(.init(category: .appliances)) == ["Wasmachine"])
    }

    @Test func sortByNameAndPurchaseDate() {
        #expect(names(.init(sort: .name)) == ["Laptop", "Tv", "Wasmachine"])
        #expect(names(.init(sort: .purchaseDate)).first == "Wasmachine")
    }

    @Test func searchCoversNameStoreSerialCaseAndDiacriticInsensitive() {
        #expect(names(.init(search: "lap")) == ["Laptop"])
        #expect(names(.init(search: "COOLBLUE")) == ["Laptop"])
        #expect(names(.init(search: "sn-123")) == ["Wasmachine"])
        #expect(names(.init(search: "geen treffer")).isEmpty)
    }

    @Test func searchFindsRecognizedReceiptText() {
        let p = product("Koptelefoon", end: day(2027, 1, 1))
        let a = Garantiebewaarder.Attachment(kind: .receipt, fileType: "jpg", data: nil, recognizedText: "Bose QuietComfort 45 € 279,00")
        p.attachments = [a]
        #expect(ProductListQuery.matches(search: "quietcomfort", product: p))
        #expect(!ProductListQuery.matches(search: "sony", product: p))
    }

    @Test func multipleWordsMustAllMatch() {
        #expect(names(.init(search: "laptop coolblue")) == ["Laptop"])
        #expect(names(.init(search: "laptop ikea")).isEmpty)
    }
}
