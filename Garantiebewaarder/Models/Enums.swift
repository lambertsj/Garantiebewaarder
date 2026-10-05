import Foundation

/// Categorie van een product. De rawValue wordt opgeslagen; hernoem hem dus nooit.
enum ProductCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case electronics
    case appliances
    case phoneComputer
    case household
    case furniture
    case tools
    case bikeMobility
    case clothingSports
    case other

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .electronics: "tv"
        case .appliances: "washer"
        case .phoneComputer: "laptopcomputer.and.iphone"
        case .household: "house"
        case .furniture: "chair.lounge"
        case .tools: "wrench.and.screwdriver"
        case .bikeMobility: "bicycle"
        case .clothingSports: "figure.run"
        case .other: "shippingbox"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .electronics: "category.electronics"
        case .appliances: "category.appliances"
        case .phoneComputer: "category.phoneComputer"
        case .household: "category.household"
        case .furniture: "category.furniture"
        case .tools: "category.tools"
        case .bikeMobility: "category.bikeMobility"
        case .clothingSports: "category.clothingSports"
        case .other: "category.other"
        }
    }
}

/// Waar de einddatum van de garantie vandaan komt.
enum WarrantySource: String, CaseIterable, Identifiable, Codable, Sendable {
    case statutoryDefault
    case manufacturer
    case manual

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .statutoryDefault: "warrantySource.default"
        case .manufacturer: "warrantySource.manufacturer"
        case .manual: "warrantySource.manual"
        }
    }
}

enum AttachmentKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case receipt
    case productPhoto
    case other

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .receipt: "attachment.receipt"
        case .productPhoto: "attachment.productPhoto"
        case .other: "attachment.other"
        }
    }
}
