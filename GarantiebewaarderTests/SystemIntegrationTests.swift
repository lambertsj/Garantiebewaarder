import CoreSpotlight
import Foundation
import Testing
@testable import Garantiebewaarder

private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
    return c
}()
private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d))! }

@Suite("Widget-snapshot")
struct WidgetSnapshotTests {
    private func c(_ name: String, _ end: Date, archived: Bool = false) -> ReminderCandidate {
        ReminderCandidate(id: UUID(), name: name, warrantyEndDate: end, isArchived: archived)
    }

    @Test func keepsOnlyRunningWarrantiesSortedAndCapped() {
        let now = day(2026, 6, 1)
        let candidates = [
            c("Later", day(2027, 1, 1)), c("Vandaag", day(2026, 6, 1)), c("Verlopen", day(2026, 5, 31)),
            c("Archief", day(2026, 7, 1), archived: true), c("Eerst", day(2026, 6, 10)),
        ] + (0..<10).map { c("X\($0)", day(2028, 1, 1 + $0)) }
        let snapshot = WidgetSnapshot.make(candidates: candidates, leadDays: 30, now: now, calendar: cal)
        #expect(snapshot.items.map(\.name).prefix(3) == ["Vandaag", "Eerst", "Later"])
        #expect(snapshot.items.count == WidgetSnapshot.maxItems)
        #expect(!snapshot.items.contains { $0.name == "Verlopen" || $0.name == "Archief" })
        #expect(snapshot.leadDays == 30)
    }

    @Test func storeRoundTripsAndFallsBackToEmpty() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("widget-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(WidgetStore.load(from: url) == .empty)
        let snapshot = WidgetSnapshot(items: [.init(id: UUID(), name: "Tv", endDate: day(2027, 3, 3))], leadDays: 14, updatedAt: Date(timeIntervalSince1970: 1_800_000_000))
        try WidgetStore.save(snapshot, to: url)
        #expect(WidgetStore.load(from: url) == snapshot)
        try Data("kapot".utf8).write(to: url)
        #expect(WidgetStore.load(from: url) == .empty)
    }
}

@MainActor
@Suite("Spotlight en deep links")
struct DeepLinkTests {
    @Test func parsesWidgetURLs() {
        let id = UUID()
        #expect(SystemIntegration.productID(from: URL(string: "garantiebewaarder://product/\(id.uuidString)")!) == id)
        #expect(SystemIntegration.productID(from: URL(string: "garantiebewaarder://other/\(id.uuidString)")!) == nil)
        #expect(SystemIntegration.productID(from: URL(string: "https://product/\(id.uuidString)")!) == nil)
        #expect(SystemIntegration.productID(from: URL(string: "garantiebewaarder://product/geen-uuid")!) == nil)
    }

    @Test func parsesSpotlightActivity() {
        let id = UUID()
        let activity = NSUserActivity(activityType: CSSearchableItemActionType)
        activity.userInfo = [CSSearchableItemActivityIdentifier: id.uuidString]
        #expect(SystemIntegration.productID(from: activity) == id)
    }

    @Test func indexesOnlyActiveProductsWithoutReceiptText() {
        let active = Product(name: "Wasmachine", brand: "Bosch", store: "Coolblue", purchaseDate: day(2026, 1, 1), warrantyEndDate: day(2028, 1, 1))
        let archived = Product(name: "Oud", purchaseDate: day(2020, 1, 1), warrantyEndDate: day(2022, 1, 1))
        archived.isArchived = true
        active.attachments = [Garantiebewaarder.Attachment(kind: .receipt, fileType: "jpg", data: nil, recognizedText: "GEHEIM 123")]
        let items = SystemIntegration.searchableItems(for: [active, archived])
        #expect(items.count == 1)
        #expect(items[0].uniqueIdentifier == active.id.uuidString)
        #expect(items[0].attributeSet.title == "Wasmachine")
        let dump = "\(items[0].attributeSet.contentDescription ?? "") \(items[0].attributeSet.keywords ?? [])"
        #expect(!dump.contains("GEHEIM"))
    }
}

@Suite("Klachtmail-sjabloon")
struct ClaimEmailTests {
    private let nl = Locale(identifier: "nl_NL")
    private let bundle: Bundle = Bundle.main.path(forResource: "nl", ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main

    @Test func fillsInProductDetails() {
        let message = ClaimEmailTemplate.make(
            .init(productName: "WAX32", brand: "Bosch", store: "Coolblue", purchaseDate: day(2026, 3, 12),
                  price: Decimal(string: "649"), serialNumber: "SN-9"),
            bundle: bundle, locale: nl)
        #expect(message.subject == "Klacht over Bosch WAX32, gekocht op 12 maart 2026")
        #expect(message.body.contains("Coolblue"))
        #expect(message.body.contains("12 maart 2026"))
        #expect(message.body.contains("649"))
        #expect(message.body.contains("SN-9"))
        #expect(message.body.contains("[beschrijf hier"))
        #expect(message.body.contains("redelijke termijn"))
    }

    @Test func omitsMissingOptionalDetails() {
        let message = ClaimEmailTemplate.make(
            .init(productName: "Tv", brand: "", store: "", purchaseDate: day(2026, 1, 2), price: nil, serialNumber: ""),
            bundle: bundle, locale: nl)
        #expect(!message.body.contains("Serienummer"))
        #expect(!message.body.contains("Aankoopbedrag"))
        #expect(message.body.contains("het volgende product gekocht: Tv"))
    }

    @Test func mailtoURLIsEncodedAndHasNoRecipient() throws {
        let url = try #require(ClaimEmailTemplate.mailtoURL(for: .init(subject: "Klacht & zo", body: "Regel 1\nRegel 2")))
        let text = url.absoluteString
        #expect(text.hasPrefix("mailto:?"))
        #expect(text.contains("subject=Klacht%20&%20zo") || text.contains("subject=Klacht%20%26%20zo"))
        #expect(!text.contains(" "))
        #expect(text.contains("%0A"))
    }

    @Test func feedbackMailtoHasRecipient() throws {
        let url = try #require(ClaimEmailTemplate.mailtoURL(for: .init(subject: "Garantiebewaarder 1.0", body: ""), recipient: "feedback@example.com"))
        #expect(url.absoluteString.hasPrefix("mailto:feedback@example.com?"))
    }
}
