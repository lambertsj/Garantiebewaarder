import Foundation
import SwiftData

/// Een aankoop met garantie.
///
/// CloudKit-eisen: alle properties hebben een standaardwaarde, geen
/// `.unique`, relaties zijn optioneel met inverse. Enums worden als
/// rawValue-string bewaard en bedragen als gehele centen.
@Model
final class Product {
    var id: UUID = UUID()
    var name: String = ""
    var brand: String = ""
    var categoryRaw: String = ProductCategory.other.rawValue
    var store: String = ""
    var purchaseDate: Date = Date()
    /// Bedrag in centen. `nil` = onbekend. Zie `price`.
    var priceCents: Int?
    var serialNumber: String = ""
    var notes: String = ""
    /// De effectieve einddatum (start van de dag, lokale tijd).
    var warrantyEndDate: Date = Date()
    var warrantySourceRaw: String = WarrantySource.statutoryDefault.rawValue
    var extraCoverageNote: String = ""
    var manualURL: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Attachment.product)
    var attachments: [Attachment]?

    init(
        name: String,
        brand: String = "",
        category: ProductCategory = .other,
        store: String = "",
        purchaseDate: Date,
        price: Decimal? = nil,
        serialNumber: String = "",
        notes: String = "",
        warrantyEndDate: Date,
        warrantySource: WarrantySource = .statutoryDefault,
        extraCoverageNote: String = "",
        manualURL: String = "",
        now: Date = Date()
    ) {
        self.name = name
        self.brand = brand
        self.categoryRaw = category.rawValue
        self.store = store
        self.purchaseDate = purchaseDate
        self.priceCents = price.flatMap(Money.cents(from:))
        self.serialNumber = serialNumber
        self.notes = notes
        self.warrantyEndDate = warrantyEndDate
        self.warrantySourceRaw = warrantySource.rawValue
        self.extraCoverageNote = extraCoverageNote
        self.manualURL = manualURL
        self.createdAt = now
        self.updatedAt = now
    }

    var category: ProductCategory {
        get { ProductCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var warrantySource: WarrantySource {
        get { WarrantySource(rawValue: warrantySourceRaw) ?? .statutoryDefault }
        set { warrantySourceRaw = newValue.rawValue }
    }

    /// Bedrag als `Decimal`; opgeslagen als centen zodat CloudKit er niets
    /// van afrondt of weigert.
    var price: Decimal? {
        get { priceCents.map(Money.decimal(fromCents:)) }
        set { priceCents = newValue.flatMap(Money.cents(from:)) }
    }

    func status(now: Date = Date(), leadDays: Int, calendar: Calendar = .current) -> WarrantyStatus {
        WarrantyCalculator.status(
            endDate: warrantyEndDate, now: now, leadDays: leadDays, calendar: calendar
        )
    }

    func remaining(now: Date = Date(), calendar: Calendar = .current) -> WarrantyRemaining {
        WarrantyCalculator.remaining(endDate: warrantyEndDate, now: now, calendar: calendar)
    }
}
