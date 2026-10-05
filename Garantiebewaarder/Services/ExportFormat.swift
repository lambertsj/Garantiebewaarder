import Foundation

/// Het exportformaat voor "Exporteer alle gegevens". STABIEL: wijzig bestaande
/// velden nooit van betekenis; nieuwe velden mogen alleen optioneel erbij komen
/// (en `schemaVersion` gaat dan omhoog bij een breuk).
///
/// Schema versie 1 (`products.json`):
/// ```
/// {
///   "schemaVersion": 1,
///   "app": "Garantiebewaarder",
///   "appVersion": "1.0",
///   "exportedAt": "2026-03-12T09:30:00Z",          // ISO 8601, UTC
///   "products": [{
///     "id": "UUID",
///     "name": "Wasmachine",
///     "brand": "",
///     "category": "appliances",                     // electronics | appliances | phoneComputer |
///                                                   // household | furniture | tools | bikeMobility |
///                                                   // clothingSports | other
///     "store": "",
///     "purchaseDate": "2026-03-12",                 // lokale kalenderdag, yyyy-MM-dd
///     "priceCents": 64900,                          // geheel aantal centen; ontbreekt = onbekend
///     "currency": "EUR",
///     "serialNumber": "",
///     "notes": "",
///     "warrantyEndDate": "2028-03-12",              // lokale kalenderdag, yyyy-MM-dd
///     "warrantySource": "statutoryDefault",         // statutoryDefault | manufacturer | manual
///     "extraCoverageNote": "",
///     "manualURL": "",
///     "isArchived": false,
///     "createdAt": "…", "updatedAt": "…",           // ISO 8601, UTC
///     "attachments": [{
///       "id": "UUID",
///       "kind": "receipt",                          // receipt | productPhoto | other
///       "fileType": "jpg",                          // jpg | pdf
///       "file": "attachments/<productId>/<id>.jpg", // pad binnen de export; ontbreekt als er geen bestand is
///       "recognizedText": "",                       // ruwe OCR-tekst
///       "createdAt": "…"
///     }]
///   }]
/// }
/// ```
struct ExportDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int = currentSchemaVersion
    var app: String
    var appVersion: String
    var exportedAt: Date
    var products: [ExportProduct]
}

struct ExportProduct: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var brand: String
    var category: String
    var store: String
    var purchaseDate: String
    var priceCents: Int?
    var currency: String = "EUR"
    var serialNumber: String
    var notes: String
    var warrantyEndDate: String
    var warrantySource: String
    var extraCoverageNote: String
    var manualURL: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    var attachments: [ExportAttachment]
}

struct ExportAttachment: Codable, Equatable, Sendable {
    var id: UUID
    var kind: String
    var fileType: String
    var file: String?
    var recognizedText: String
    var createdAt: Date
}

/// Kalenderdagen als "yyyy-MM-dd" (lokale kalender), zodat een datum niet
/// verschuift door tijdzones.
enum DayString {
    static func string(from date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(from string: String, calendar: Calendar = .current) -> Date? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
