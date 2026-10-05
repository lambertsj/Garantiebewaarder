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
@Suite("ProductDraft")
struct ProductDraftTests {
    @Test func newDraftUsesDefaultMonthsAndIsInvalidWithoutName() {
        var draft = ProductDraft(defaultMonths: 24, now: day(2026, 3, 10), calendar: cal)
        #expect(!draft.isValid)
        #expect(draft.endDate(calendar: cal) == day(2028, 3, 10))
        draft.name = "  Tv "
        #expect(draft.isValid)
    }

    @Test func endDateFollowsPurchaseDateAndTerm() {
        var draft = ProductDraft(defaultMonths: 24, now: day(2026, 1, 31), calendar: cal)
        draft.warrantyMonths = 1
        #expect(draft.endDate(calendar: cal) == day(2026, 2, 28))
    }

    @Test func customEndDateIsManualSource() {
        var draft = ProductDraft(defaultMonths: 24, now: day(2026, 1, 1), calendar: cal)
        draft.warrantyMonths = ProductDraft.customChoice
        draft.customEndDate = day(2030, 5, 5)
        #expect(draft.endDate(calendar: cal) == day(2030, 5, 5))
        #expect(draft.source == .manual)
    }

    @Test func makeProductTrimsAndStoresEverything() {
        var draft = ProductDraft(defaultMonths: 36, now: day(2026, 1, 1), calendar: cal)
        draft.name = "  Laptop "
        draft.price = Decimal(string: "999.5")
        draft.termSource = .manufacturer
        let product = draft.makeProduct(now: day(2026, 1, 2), calendar: cal)
        #expect(product.name == "Laptop")
        #expect(product.priceCents == 99_950)
        #expect(product.warrantyEndDate == day(2029, 1, 1))
        #expect(product.warrantySource == .manufacturer)
    }

    @Test func roundTripFromProductKeepsTermAndCustomDates() {
        var draft = ProductDraft(defaultMonths: 24, now: day(2026, 1, 1), calendar: cal)
        draft.name = "X"
        let product = draft.makeProduct(calendar: cal)
        let again = ProductDraft(product: product, calendar: cal)
        #expect(again.warrantyMonths == 24)

        product.warrantyEndDate = day(2027, 9, 9)
        product.warrantySource = .manual
        let custom = ProductDraft(product: product, calendar: cal)
        #expect(custom.usesCustomEndDate)
        #expect(custom.endDate(calendar: cal) == day(2027, 9, 9))
    }

    @Test func futurePurchaseDateIsFlagged() {
        var draft = ProductDraft(defaultMonths: 24, now: day(2026, 1, 1), calendar: cal)
        draft.purchaseDate = day(2026, 2, 1)
        #expect(draft.purchaseDateIssue(now: day(2026, 1, 1), calendar: cal) == .inFuture)
    }

    @Test func manualLinkAcceptsOnlyWebURLs() {
        #expect(ManualLink.url(from: "https://example.com/handleiding.pdf") != nil)
        #expect(ManualLink.url(from: "example.com/man") != nil)
        #expect(ManualLink.url(from: "javascript:alert(1)") == nil)
        #expect(ManualLink.url(from: "file:///etc/passwd") == nil)
        #expect(ManualLink.url(from: "") == nil)
    }
}

@MainActor
@Suite("Voorstel uit bon")
struct ReceiptSuggestionTests {
    private func receipt() -> ParsedReceipt {
        ParsedReceipt(
            storeName: ParsedField(value: "Coolblue", confidence: .high),
            purchaseDate: ParsedField(value: day(2026, 3, 12), confidence: .medium),
            totalAmount: ParsedField(value: Decimal(string: "649.00")!, confidence: .low),
            productNameCandidates: ["Bosch wasmachine", "Verlengsnoer"]
        )
    }

    @Test func draftIsPrefilledButNotSaved() {
        var draft = ProductDraft(defaultMonths: 24, now: day(2026, 5, 1), calendar: cal)
        draft.apply(receipt: receipt(), calendar: cal)
        #expect(draft.name == "Bosch wasmachine")
        #expect(draft.store == "Coolblue")
        #expect(draft.purchaseDate == day(2026, 3, 12))
        #expect(draft.price == Decimal(string: "649.00"))
        #expect(draft.endDate(calendar: cal) == day(2028, 3, 12))
    }

    @Test func suggestionsCarryConfidencePerField() {
        let s = ReceiptSuggestions(receipt: receipt(), hadReceiptAttachment: true)
        #expect(s.confidence[.store] == .high)
        #expect(s.confidence[.purchaseDate] == .medium)
        #expect(s.confidence[.price] == .low)
        #expect(s.nameCandidates.count == 2)
        #expect(!s.recognitionFoundNothing)
    }

    @Test func emptyRecognitionWithReceiptIsReportedForFriendlyFallback() {
        let s = ReceiptSuggestions(receipt: ParsedReceipt(), hadReceiptAttachment: true)
        #expect(s.recognitionFoundNothing)
        #expect(!s.hasRecognizedFields)
        #expect(!ReceiptSuggestions(receipt: ParsedReceipt(), hadReceiptAttachment: false).recognitionFoundNothing)
    }
}
