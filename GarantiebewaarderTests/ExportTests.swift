import Foundation
import PDFKit
import SwiftData
import Testing
import UIKit
@testable import Garantiebewaarder

private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
    return c
}()
private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d))! }

@MainActor
private func makeProducts(in context: ModelContext) -> [Product] {
    let a = Product(name: "Wasmachine, \"Bosch\"", brand: "Bosch", category: .appliances, store: "Coolblue",
                    purchaseDate: day(2026, 3, 12), price: Decimal(string: "649.05"), serialNumber: "SN-1",
                    notes: "Regel 1\nRegel 2", warrantyEndDate: day(2028, 3, 12), warrantySource: .manufacturer,
                    extraCoverageNote: "Creditcard", manualURL: "https://example.com/man.pdf",
                    now: Date(timeIntervalSince1970: 1_800_000_000))
    let b = Product(name: "Laptop", purchaseDate: day(2025, 1, 31), warrantyEndDate: day(2027, 1, 31),
                    now: Date(timeIntervalSince1970: 1_800_000_100))
    b.isArchived = true
    context.insert(a); context.insert(b)
    let receipt = Garantiebewaarder.Attachment(kind: .receipt, fileType: "jpg", data: Data([1, 2, 3]), recognizedText: "Totaal 649,05",
                                               now: Date(timeIntervalSince1970: 1_800_000_050))
    receipt.product = a
    context.insert(receipt)
    return [a, b]
}

@MainActor
@Suite("Export")
struct ExportTests {
    @Test func jsonRoundTripKeepsEveryField() throws {
        let context = ModelContext(PersistenceController.makeContainer(inMemory: true))
        let products = makeProducts(in: context)
        let attachmentID = try #require(products[0].attachments?.first?.id)
        let document = ExportService.document(
            for: products, attachmentFiles: [attachmentID: "attachments/x/y.jpg"],
            now: Date(timeIntervalSince1970: 1_800_001_000), calendar: cal
        )
        let data = try ExportService.encode(document)
        let decoded = try ExportService.decode(data)
        #expect(decoded == document)
        #expect(decoded.schemaVersion == 1)
        #expect(decoded.products.count == 2)

        let first = try #require(decoded.products.first { $0.name.hasPrefix("Wasmachine") })
        #expect(first.priceCents == 64_905)
        #expect(first.purchaseDate == "2026-03-12")
        #expect(first.warrantyEndDate == "2028-03-12")
        #expect(first.category == "appliances")
        #expect(first.warrantySource == "manufacturer")
        #expect(first.attachments.first?.file == "attachments/x/y.jpg")
        #expect(first.attachments.first?.recognizedText == "Totaal 649,05")
        let second = try #require(decoded.products.first { $0.name == "Laptop" })
        #expect(second.priceCents == nil && second.isArchived)
    }

    @Test func jsonUsesStableKeysAndISODates() throws {
        let context = ModelContext(PersistenceController.makeContainer(inMemory: true))
        let document = ExportService.document(for: makeProducts(in: context), now: Date(timeIntervalSince1970: 1_800_001_000), calendar: cal)
        let text = String(decoding: try ExportService.encode(document), as: UTF8.self)
        for key in ["\"schemaVersion\"", "\"exportedAt\"", "\"priceCents\"", "\"warrantyEndDate\"", "\"recognizedText\"", "\"currency\" : \"EUR\""] {
            #expect(text.contains(key))
        }
        #expect(text.contains("2027-01-15T")) // 1_800_001_000 s → 15 jan 2027 (UTC)
    }

    @Test func dayStringRoundTripsAndIgnoresTimeZoneShifts() {
        #expect(DayString.string(from: day(2026, 3, 29), calendar: cal) == "2026-03-29")
        #expect(DayString.date(from: "2026-03-29", calendar: cal) == day(2026, 3, 29))
        #expect(DayString.date(from: "kapot", calendar: cal) == nil)
    }

    @Test func csvEscapesCommasQuotesAndNewlines() {
        #expect(ExportService.csvEscape("gewoon") == "gewoon")
        #expect(ExportService.csvEscape("a,b") == "\"a,b\"")
        #expect(ExportService.csvEscape("zeg \"hoi\"") == "\"zeg \"\"hoi\"\"\"")
        #expect(ExportService.csvEscape("r1\nr2") == "\"r1\nr2\"")
        let context = ModelContext(PersistenceController.makeContainer(inMemory: true))
        let csv = ExportService.csv(for: ExportService.document(for: makeProducts(in: context), calendar: cal))
        let lines = csv.components(separatedBy: "\r\n")
        #expect(lines[0].hasPrefix("id,name,brand"))
        #expect(csv.contains("649.05"))
        #expect(csv.contains("\"Wasmachine, \"\"Bosch\"\"\""))
    }

    @Test func exportAllProducesZipWithJSONCSVAndAttachments() async throws {
        let context = ModelContext(PersistenceController.makeContainer(inMemory: true))
        let products = makeProducts(in: context)
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("export-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }

        var lastProgress = (0, 0)
        let zip = try await ExportService.exportAll(products: products, in: work, now: Date()) { lastProgress = ($0, $1) }
        #expect(zip.pathExtension == "zip")
        let bytes = try Data(contentsOf: zip)
        #expect(bytes.starts(with: Data("PK".utf8)))
        let listing = String(decoding: bytes, as: UTF8.self)
        #expect(listing.contains("products.json"))
        #expect(listing.contains("products.csv"))
        #expect(listing.contains("attachments/"))
        #expect(lastProgress == (2, 2))
    }

    @Test func productPDFHasDetailsPageAndOnePagePerAttachment() throws {
        let context = ModelContext(PersistenceController.makeContainer(inMemory: true))
        let product = makeProducts(in: context)[0]
        let image = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 600)).image { ctx in
            UIColor.systemTeal.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 600))
        }
        product.attachments?.first?.data = image.jpegData(compressionQuality: 0.8)
        let input = ProductPDFInput(product: product, leadDays: 30, now: day(2026, 6, 1))
        let data = ExportService.pdfData(for: input, now: day(2026, 6, 1))
        let document = try #require(PDFDocument(data: data))
        #expect(document.pageCount == 2)
        let text = document.page(at: 0)?.string ?? ""
        #expect(text.contains("Wasmachine"))
        #expect(text.contains("Coolblue"))
        #expect(text.contains("SN-1"))
    }

    @Test func productWithoutAttachmentsIsSinglePage() throws {
        let context = ModelContext(PersistenceController.makeContainer(inMemory: true))
        let product = makeProducts(in: context)[1]
        let data = ExportService.pdfData(for: ProductPDFInput(product: product, leadDays: 30))
        #expect(try #require(PDFDocument(data: data)).pageCount == 1)
    }
}

@MainActor
@Suite("InboxStore")
struct InboxStoreTests {
    private func makeStore() -> InboxStore {
        InboxStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("inbox-\(UUID().uuidString)"))
    }

    @Test func addsListsAndRemovesFiles() throws {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let a = try store.add(data: Data([1]), fileExtension: "JPG")
        let b = try store.add(data: Data([2]), fileExtension: "pdf")
        #expect(a.pathExtension == "jpg")
        #expect(Set(store.pendingFiles()) == [a, b])
        store.remove([a])
        #expect(store.pendingFiles() == [b])
    }

    @Test func rejectsUnsupportedAndOversizedFiles() {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        #expect(throws: InboxStore.InboxError.self) { try store.add(data: Data([1]), fileExtension: "exe") }
        #expect(throws: InboxStore.InboxError.self) { try store.add(data: Data(count: InboxStore.maxFileBytes + 1), fileExtension: "pdf") }
        #expect(store.pendingFiles().isEmpty)
    }

    @Test func copiesFilesFromElsewhere() throws {
        let store = makeStore()
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("bron-\(UUID().uuidString).pdf")
        try Data("%PDF-1.4".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: store.directory); try? FileManager.default.removeItem(at: source) }
        let copied = try store.add(fileAt: source)
        #expect(try Data(contentsOf: copied) == Data("%PDF-1.4".utf8))
    }

    @Test func purgesStaleFilesOnly() throws {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let url = try store.add(data: Data([1]), fileExtension: "png")
        store.purgeStale(now: Date())
        #expect(store.pendingFiles() == [url])
        store.purgeStale(now: Date().addingTimeInterval(InboxStore.staleAfter + 60))
        #expect(store.pendingFiles().isEmpty)
    }

    @Test func importerTurnsInboxFilesIntoSeedAndCleansUp() async throws {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        }
        try store.add(data: try #require(image.pngData()), fileExtension: "png")
        try store.add(data: Data("geen plaatje".utf8), fileExtension: "jpg")

        let batch = try #require(await InboxImporter.loadPending(store: store))
        #expect(batch.seed.attachments.count == 1)
        #expect(batch.skippedUnreadable == 1)
        #expect(batch.files.count == 2)
        InboxImporter.finish(batch, store: store)
        #expect(store.pendingFiles().isEmpty)
        #expect(await InboxImporter.loadPending(store: store) == nil)
    }
}
