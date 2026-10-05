import Foundation

/// Welke velden in het formulier uit de bon komen, en hoe zeker we zijn.
struct ReceiptSuggestions: Equatable, Sendable {
    enum Field: Hashable, Sendable { case name, store, purchaseDate, price }

    var confidence: [Field: ParseConfidence] = [:]
    var nameCandidates: [String] = []
    /// Er was een bon, maar er kwam geen bruikbare tekst uit.
    var recognitionFoundNothing = false

    var hasRecognizedFields: Bool { !confidence.isEmpty }

    init(receipt: ParsedReceipt, hadReceiptAttachment: Bool) {
        nameCandidates = receipt.productNameCandidates
        if !receipt.productNameCandidates.isEmpty { confidence[.name] = .medium }
        if let store = receipt.storeName { confidence[.store] = store.confidence }
        if let date = receipt.purchaseDate { confidence[.purchaseDate] = date.confidence }
        if let total = receipt.totalAmount { confidence[.price] = total.confidence }
        recognitionFoundNothing = hadReceiptAttachment && receipt.isEmpty
    }

    init() {}
}

extension ProductDraft {
    /// Vult het formulier met het voorstel uit de bon. De gebruiker controleert
    /// en bevestigt daarna; er wordt niets opgeslagen.
    mutating func apply(receipt: ParsedReceipt, calendar: Calendar = .current) {
        if let store = receipt.storeName { self.store = store.value }
        if let date = receipt.purchaseDate {
            purchaseDate = date.value
            customEndDate = WarrantyCalculator.endDate(purchaseDate: date.value, months: warrantyMonths == Self.customChoice ? 24 : warrantyMonths, calendar: calendar)
        }
        if let total = receipt.totalAmount { price = total.value }
        if let name = receipt.productNameCandidates.first { self.name = name }
    }
}
