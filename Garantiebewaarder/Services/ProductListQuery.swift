import Foundation

enum ProductStatusFilter: String, CaseIterable, Identifiable, Sendable {
    case all, expiringSoon, covered, expired
    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .all: "filter.all"
        case .expiringSoon: "status.expiringSoon"
        case .covered: "status.covered"
        case .expired: "status.expired"
        }
    }

    func matches(_ status: WarrantyStatus) -> Bool {
        switch self {
        case .all: true
        case .expiringSoon: status == .expiringSoon
        case .covered: status == .covered
        case .expired: status == .expired
        }
    }
}

enum ProductSort: String, CaseIterable, Identifiable, Sendable {
    case endDate, name, purchaseDate
    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .endDate: "sort.endDate"
        case .name: "sort.name"
        case .purchaseDate: "sort.purchaseDate"
        }
    }
}

/// Filteren, zoeken en sorteren van de productlijst. Puur en testbaar.
struct ProductListQuery: Equatable, Sendable {
    var status: ProductStatusFilter = .all
    var category: ProductCategory?
    var sort: ProductSort = .endDate
    var search: String = ""

    var isFiltering: Bool { status != .all || category != nil || !trimmedSearch.isEmpty }
    private var trimmedSearch: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }

    func apply(
        to products: [Product],
        now: Date = Date(),
        leadDays: Int,
        calendar: Calendar = .current
    ) -> [Product] {
        let filtered = products.filter { product in
            guard !product.isArchived else { return false }
            if let category, product.category != category { return false }
            guard status.matches(product.status(now: now, leadDays: leadDays, calendar: calendar)) else { return false }
            return Self.matches(search: trimmedSearch, product: product)
        }
        return Self.sorted(filtered, by: sort, now: now, calendar: calendar)
    }

    /// Zoekt hoofdletter- en accentongevoelig in naam, merk, winkel,
    /// serienummer en herkende bontekst; elk woord moet ergens voorkomen.
    static func matches(search: String, product: Product) -> Bool {
        guard !search.isEmpty else { return true }
        let haystacks = [product.name, product.brand, product.store, product.serialNumber]
            + (product.attachments ?? []).map(\.recognizedText)
        return search.split(whereSeparator: \.isWhitespace).allSatisfy { word in
            haystacks.contains { $0.localizedStandardContains(word) }
        }
    }

    /// Bij "einddatum": nog gedekte producten eerst (bijna verlopen bovenaan),
    /// daarna de verlopen producten, meest recent verlopen eerst.
    static func sorted(_ products: [Product], by sort: ProductSort, now: Date, calendar: Calendar) -> [Product] {
        switch sort {
        case .name:
            return products.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .purchaseDate:
            return products.sorted { $0.purchaseDate > $1.purchaseDate }
        case .endDate:
            let today = calendar.startOfDay(for: now)
            let active = products.filter { $0.warrantyEndDate >= today }.sorted { $0.warrantyEndDate < $1.warrantyEndDate }
            let expired = products.filter { $0.warrantyEndDate < today }.sorted { $0.warrantyEndDate > $1.warrantyEndDate }
            return active + expired
        }
    }
}
