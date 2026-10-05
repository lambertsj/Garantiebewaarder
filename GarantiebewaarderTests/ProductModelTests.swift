import Foundation
import SwiftData
import Testing
@testable import Garantiebewaarder

@MainActor
@Suite("Product en Attachment")
struct ProductModelTests {
    private func makeContext() -> ModelContext {
        ModelContext(PersistenceController.makeContainer(inMemory: true))
    }

    private func makeProduct(price: Decimal? = nil) -> Product {
        Product(name: "Wasmachine", purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
                price: price, warrantyEndDate: Date(timeIntervalSince1970: 1_760_000_000))
    }

    @Test func priceRoundTripsThroughCents() {
        let product = makeProduct(price: Decimal(string: "1299.99"))
        #expect(product.priceCents == 129_999)
        #expect(product.price == Decimal(string: "1299.99"))
        product.price = nil
        #expect(product.priceCents == nil)
    }

    @Test func priceRoundsToWholeCentsAndRejectsNegative() {
        #expect(Money.cents(from: Decimal(string: "49.955")!) == 4996)
        #expect(Money.cents(from: -1) == nil)
        #expect(Money.cents(from: 0) == 0)
    }

    @Test func enumsFallBackOnUnknownRawValues() {
        let product = makeProduct()
        product.categoryRaw = "iets-uit-de-toekomst"
        product.warrantySourceRaw = "onbekend"
        #expect(product.category == .other)
        #expect(product.warrantySource == .statutoryDefault)
    }

    @Test func persistsAndFetches() throws {
        let context = makeContext()
        context.insert(makeProduct(price: 10))
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<Product>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Wasmachine")
    }

    @Test func deletingProductCascadesToAttachments() throws {
        let context = makeContext()
        let product = makeProduct()
        context.insert(product)
        let attachment = Garantiebewaarder.Attachment(kind: .receipt, fileType: "pdf", data: Data([1, 2, 3]))
        attachment.product = product
        context.insert(attachment)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Garantiebewaarder.Attachment>()) == 1)

        context.delete(product)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Garantiebewaarder.Attachment>()) == 0)
    }

    @Test func statusUsesLeadDays() {
        let end = Date(timeIntervalSince1970: 1_760_000_000)
        let product = makeProduct()
        product.warrantyEndDate = end
        let tenDaysBefore = end.addingTimeInterval(-10 * 86_400)
        #expect(product.status(now: tenDaysBefore, leadDays: 30) == .expiringSoon)
        #expect(product.status(now: tenDaysBefore, leadDays: 5) == .covered)
    }
}
