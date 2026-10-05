import Foundation

/// Bewerkbare kopie van een product voor het formulier. Het echte
/// `Product` wordt pas aangepast bij opslaan.
struct ProductDraft: Equatable {
    static let monthChoices = [12, 24, 36, 60]
    /// `warrantyMonths == customChoice` betekent: eigen einddatum.
    static let customChoice = 0

    var name = ""
    var brand = ""
    var category: ProductCategory = .other
    var store = ""
    var purchaseDate: Date
    var price: Decimal?
    var warrantyMonths: Int
    var customEndDate: Date
    /// Alleen relevant bij een termijn in maanden; een eigen datum is altijd `.manual`.
    var termSource: WarrantySource = .statutoryDefault
    var serialNumber = ""
    var notes = ""
    var extraCoverageNote = ""
    var manualURL = ""

    init(defaultMonths: Int, now: Date = Date(), calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        purchaseDate = today
        warrantyMonths = defaultMonths
        customEndDate = WarrantyCalculator.endDate(purchaseDate: today, months: defaultMonths, calendar: calendar)
    }

    init(product: Product, calendar: Calendar = .current) {
        name = product.name
        brand = product.brand
        category = product.category
        store = product.store
        purchaseDate = product.purchaseDate
        price = product.price
        serialNumber = product.serialNumber
        notes = product.notes
        extraCoverageNote = product.extraCoverageNote
        manualURL = product.manualURL
        customEndDate = product.warrantyEndDate

        // Herken een bestaande termijn in maanden; anders is het een eigen datum.
        let matching = (Self.monthChoices + [Self.customChoice]).first { months in
            months != Self.customChoice
                && WarrantyCalculator.endDate(purchaseDate: product.purchaseDate, months: months, calendar: calendar)
                    == calendar.startOfDay(for: product.warrantyEndDate)
        }
        if let matching, product.warrantySource != .manual {
            warrantyMonths = matching
            termSource = product.warrantySource
        } else {
            warrantyMonths = Self.customChoice
            termSource = .statutoryDefault
        }
    }

    var usesCustomEndDate: Bool { warrantyMonths == Self.customChoice }

    var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func endDate(calendar: Calendar = .current) -> Date {
        usesCustomEndDate
            ? calendar.startOfDay(for: customEndDate)
            : WarrantyCalculator.endDate(purchaseDate: purchaseDate, months: warrantyMonths, calendar: calendar)
    }

    var source: WarrantySource { usesCustomEndDate ? .manual : termSource }

    func purchaseDateIssue(now: Date = Date(), calendar: Calendar = .current) -> WarrantyCalculator.PurchaseDateIssue? {
        WarrantyCalculator.purchaseDateIssue(purchaseDate: purchaseDate, now: now, calendar: calendar)
    }

    /// Keuzes voor de termijn, inclusief de ingestelde standaardduur als die afwijkt.
    func choices(including defaultMonths: Int) -> [Int] {
        var all = Self.monthChoices
        for extra in [defaultMonths, warrantyMonths] where extra > 0 && !all.contains(extra) { all.append(extra) }
        return all.sorted()
    }

    func apply(to product: Product, now: Date = Date(), calendar: Calendar = .current) {
        product.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        product.brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        product.category = category
        product.store = store.trimmingCharacters(in: .whitespacesAndNewlines)
        product.purchaseDate = calendar.startOfDay(for: purchaseDate)
        product.price = price
        product.serialNumber = serialNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        product.notes = notes
        product.extraCoverageNote = extraCoverageNote.trimmingCharacters(in: .whitespacesAndNewlines)
        product.manualURL = manualURL.trimmingCharacters(in: .whitespacesAndNewlines)
        product.warrantyEndDate = endDate(calendar: calendar)
        product.warrantySource = source
        product.updatedAt = now
    }

    func makeProduct(now: Date = Date(), calendar: Calendar = .current) -> Product {
        let product = Product(name: name, purchaseDate: purchaseDate, warrantyEndDate: endDate(calendar: calendar), now: now)
        apply(to: product, now: now, calendar: calendar)
        return product
    }
}

enum ManualLink {
    /// Geeft alleen een http(s)-URL terug; andere schema's openen we nooit.
    static func url(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: candidate), let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http", url.host()?.isEmpty == false
        else { return nil }
        return url
    }
}
