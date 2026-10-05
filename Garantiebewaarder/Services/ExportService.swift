import Foundation
import PDFKit
import UIKit
import OSLog

/// Snapshot van een product voor PDF-export; Sendable zodat het renderen op
/// een achtergrondtaak kan.
struct ProductPDFInput: Sendable {
    struct Page: Sendable {
        var kind: AttachmentKind
        var fileType: String
        var data: Data
    }

    var name: String
    var brand: String
    var categoryTitle: String
    var statusTitle: String
    var remainingText: String
    var store: String
    var purchaseDate: Date
    var price: Decimal?
    var endDate: Date
    var sourceTitle: String
    var extraCoverage: String
    var serialNumber: String
    var manualURL: String
    var notes: String
    var attachments: [Page]

    @MainActor
    init(product: Product, leadDays: Int, now: Date = Date()) {
        name = product.name
        brand = product.brand
        categoryTitle = String(localized: product.category.title)
        statusTitle = String(localized: product.status(now: now, leadDays: leadDays).title)
        remainingText = product.remaining(now: now).text()
        store = product.store
        purchaseDate = product.purchaseDate
        price = product.price
        endDate = product.warrantyEndDate
        sourceTitle = String(localized: product.warrantySource.title)
        extraCoverage = product.extraCoverageNote
        serialNumber = product.serialNumber
        manualURL = product.manualURL
        notes = product.notes
        attachments = (product.attachments ?? [])
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap { a in a.data.map { Page(kind: a.kind, fileType: a.fileType, data: $0) } }
    }
}

enum ExportService {
    private static let logger = Logger(subsystem: "com.jeroenlamberts.garantiebewaarder", category: "export")

    // MARK: - JSON

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func encode(_ document: ExportDocument) throws -> Data { try encoder().encode(document) }
    static func decode(_ data: Data) throws -> ExportDocument { try decoder().decode(ExportDocument.self, from: data) }

    /// Bouwt het exportdocument. `attachmentFiles` koppelt een bijlage-id aan het pad in de export.
    @MainActor
    static func document(
        for products: [Product],
        attachmentFiles: [UUID: String] = [:],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ExportDocument {
        // Op hele seconden afronden: ISO 8601 bewaart geen fracties, dus round-trips blijven gelijk.
        func whole(_ date: Date) -> Date { Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down)) }
        let exported = products
            .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
            .map { p in
                ExportProduct(
                    id: p.id, name: p.name, brand: p.brand, category: p.categoryRaw, store: p.store,
                    purchaseDate: DayString.string(from: p.purchaseDate, calendar: calendar),
                    priceCents: p.priceCents, serialNumber: p.serialNumber, notes: p.notes,
                    warrantyEndDate: DayString.string(from: p.warrantyEndDate, calendar: calendar),
                    warrantySource: p.warrantySourceRaw, extraCoverageNote: p.extraCoverageNote,
                    manualURL: p.manualURL, isArchived: p.isArchived,
                    createdAt: whole(p.createdAt), updatedAt: whole(p.updatedAt),
                    attachments: (p.attachments ?? []).sorted { $0.createdAt < $1.createdAt }.map { a in
                        ExportAttachment(
                            id: a.id, kind: a.kindRaw, fileType: a.fileType, file: attachmentFiles[a.id],
                            recognizedText: a.recognizedText, createdAt: whole(a.createdAt)
                        )
                    }
                )
            }
        return ExportDocument(app: "Garantiebewaarder", appVersion: AppInfo.version, exportedAt: whole(now), products: exported)
    }

    // MARK: - CSV

    /// RFC 4180: komma-gescheiden, UTF-8, velden met komma/aanhalingsteken/regeleinde tussen aanhalingstekens.
    static func csv(for document: ExportDocument) -> String {
        let header = ["id", "name", "brand", "category", "store", "purchaseDate", "price", "currency", "serialNumber",
                      "warrantyEndDate", "warrantySource", "extraCoverageNote", "manualURL", "isArchived", "notes", "attachments"]
        var rows = [header.joined(separator: ",")]
        for p in document.products {
            let price = p.priceCents.map { String(format: "%d.%02d", $0 / 100, $0 % 100) } ?? ""
            let fields = [p.id.uuidString, p.name, p.brand, p.category, p.store, p.purchaseDate, price, p.currency,
                          p.serialNumber, p.warrantyEndDate, p.warrantySource, p.extraCoverageNote, p.manualURL,
                          p.isArchived ? "true" : "false", p.notes, String(p.attachments.count)]
            rows.append(fields.map(csvEscape).joined(separator: ","))
        }
        return rows.joined(separator: "\r\n") + "\r\n"
    }

    static func csvEscape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - Alles exporteren

    /// Schrijft `products.json`, `products.csv` en de bijlagen naar een map en
    /// verpakt die met Apple's eigen `NSFileCoordinator` tot één zip. Product voor
    /// product, zodat niet alle bijlagen tegelijk in het geheugen staan.
    @MainActor
    static func exportAll(
        products: [Product],
        in workDirectory: URL = FileManager.default.temporaryDirectory,
        now: Date = Date(),
        progress: (Int, Int) -> Void = { _, _ in }
    ) async throws -> URL {
        let name = "\(AppInfo.name)-export-\(DayString.string(from: now))"
        let folder = workDirectory.appendingPathComponent(name, isDirectory: true)
        let fm = FileManager.default
        try? fm.removeItem(at: folder)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        var files: [UUID: String] = [:]
        for (index, product) in products.enumerated() {
            for attachment in product.attachments ?? [] {
                guard let data = attachment.data else { continue }
                let relative = "attachments/\(product.id.uuidString)/\(attachment.id.uuidString).\(attachment.fileType)"
                let url = folder.appendingPathComponent(relative)
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url, options: .atomic)
                files[attachment.id] = relative
            }
            progress(index + 1, products.count)
            await Task.yield()
        }

        let document = document(for: products, attachmentFiles: files, now: now)
        try encode(document).write(to: folder.appendingPathComponent("products.json"), options: .atomic)
        try Data(csv(for: document).utf8).write(to: folder.appendingPathComponent("products.csv"), options: .atomic)
        try Data(readme.utf8).write(to: folder.appendingPathComponent("README.txt"), options: .atomic)

        let zip = try zipDirectory(folder, named: name, in: workDirectory)
        try? fm.removeItem(at: folder)
        return zip
    }

    private static func zipDirectory(_ folder: URL, named name: String, in directory: URL) throws -> URL {
        let target = directory.appendingPathComponent("\(name).zip")
        try? FileManager.default.removeItem(at: target)
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordinationError) { zipped in
            do { try FileManager.default.copyItem(at: zipped, to: target) } catch { copyError = error }
        }
        if let error = coordinationError ?? copyError.map({ $0 as NSError }) { throw error }
        return target
    }

    static let readme = """
    Garantiebewaarder - export
    ==========================

    products.json   Alle producten en bijlage-verwijzingen (schemaVersion 1).
    products.csv    Dezelfde producten als spreadsheet (komma-gescheiden, UTF-8).
    attachments/    De bijlagen (bonnen en foto's), per product in een eigen map.

    Datums zonder tijd zijn kalenderdagen (yyyy-MM-dd); tijdstempels zijn ISO 8601 in UTC.
    Bedragen staan in hele centen (priceCents). Het volledige schema staat in de broncode
    van de app (ExportFormat.swift) en in de README van het project.
    """

    // MARK: - PDF per product

    /// Eén product als nette PDF: gegevens op de eerste pagina, bijlagen erna.
    static func pdfData(for input: ProductPDFInput, now: Date = Date()) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            var writer = PDFPageWriter(context: context, pageRect: pageRect, now: now)
            writer.newPage()
            writer.title(input.name)
            let subtitle = [input.brand, input.categoryTitle].filter { !$0.isEmpty }.joined(separator: " · ")
            writer.subtitle(subtitle)
            writer.status("\(input.statusTitle) — \(input.remainingText)")

            writer.section(String(localized: "detail.section.warranty"))
            writer.row(String(localized: "field.endDate"), input.endDate.formatted(date: .long, time: .omitted))
            writer.row(String(localized: "detail.source"), input.sourceTitle)
            writer.row(String(localized: "pdf.extraCoverage"), input.extraCoverage)

            writer.section(String(localized: "detail.section.purchase"))
            writer.row(String(localized: "field.store"), input.store)
            writer.row(String(localized: "field.purchaseDate"), input.purchaseDate.formatted(date: .long, time: .omitted))
            writer.row(String(localized: "field.price"), input.price?.formatted(.currency(code: "EUR")) ?? "")

            writer.section(String(localized: "detail.section.data"))
            writer.row(String(localized: "field.serialNumber"), input.serialNumber)
            writer.row(String(localized: "field.manualURL"), input.manualURL)
            writer.row(String(localized: "field.notes"), String(input.notes.prefix(3000)))

            for attachment in input.attachments {
                writer.attachmentPages(attachment)
            }
            writer.finish()
        }
    }
}

/// Eenvoudige paginaschrijver: tekst van boven naar beneden met automatisch een nieuwe pagina.
private struct PDFPageWriter {
    let context: UIGraphicsPDFRendererContext
    let pageRect: CGRect
    let now: Date
    let margin: CGFloat = 48
    var y: CGFloat = 0
    private var hasPage = false

    init(context: UIGraphicsPDFRendererContext, pageRect: CGRect, now: Date) {
        self.context = context
        self.pageRect = pageRect
        self.now = now
    }

    var contentWidth: CGFloat { pageRect.width - margin * 2 }
    private var bottom: CGFloat { pageRect.height - margin - 20 }

    mutating func newPage() {
        if hasPage { drawFooter() }
        context.beginPage()
        hasPage = true
        y = margin
    }

    mutating func finish() {
        if hasPage { drawFooter() }
    }

    private func drawFooter() {
        let text = "\(String(localized: "pdf.footer \(AppInfo.name) \(now.formatted(date: .long, time: .omitted))")) · \(String(localized: LegalContent.generalInfo))"
        draw(text, in: CGRect(x: margin, y: pageRect.height - margin, width: contentWidth, height: 14),
             font: .systemFont(ofSize: 8), color: .darkGray)
    }

    @discardableResult
    private func draw(_ text: String, in rect: CGRect, font: UIFont, color: UIColor = .black) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let string = NSAttributedString(string: text, attributes: attributes)
        let height = ceil(string.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                                              options: [.usesLineFragmentOrigin], context: nil).height)
        string.draw(with: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: height),
                    options: [.usesLineFragmentOrigin], context: nil)
        return height
    }

    private func height(of text: String, font: UIFont, width: CGFloat) -> CGFloat {
        ceil(NSAttributedString(string: text, attributes: [.font: font])
            .boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil).height)
    }

    private mutating func ensureSpace(_ needed: CGFloat) {
        if y + needed > bottom { newPage() }
    }

    mutating func title(_ text: String) {
        let font = UIFont.boldSystemFont(ofSize: 24)
        ensureSpace(height(of: text, font: font, width: contentWidth))
        y += draw(text, in: CGRect(x: margin, y: y, width: contentWidth, height: 0), font: font) + 4
    }

    mutating func subtitle(_ text: String) {
        guard !text.isEmpty else { return }
        y += draw(text, in: CGRect(x: margin, y: y, width: contentWidth, height: 0), font: .systemFont(ofSize: 13), color: .darkGray) + 8
    }

    mutating func status(_ text: String) {
        y += draw(text, in: CGRect(x: margin, y: y, width: contentWidth, height: 0), font: .boldSystemFont(ofSize: 14)) + 18
    }

    mutating func section(_ text: String) {
        ensureSpace(40)
        y += 6
        y += draw(text.uppercased(), in: CGRect(x: margin, y: y, width: contentWidth, height: 0), font: .boldSystemFont(ofSize: 10), color: .darkGray) + 4
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: y))
        line.addLine(to: CGPoint(x: margin + contentWidth, y: y))
        UIColor.lightGray.setStroke()
        line.lineWidth = 0.5
        line.stroke()
        y += 6
    }

    mutating func row(_ label: String, _ value: String) {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let labelWidth: CGFloat = 150
        let font = UIFont.systemFont(ofSize: 12)
        let valueWidth = contentWidth - labelWidth
        let rowHeight = max(height(of: value, font: font, width: valueWidth), 16)
        ensureSpace(min(rowHeight, bottom - margin))
        draw(label, in: CGRect(x: margin, y: y, width: labelWidth - 8, height: 0), font: font, color: .darkGray)
        draw(value, in: CGRect(x: margin + labelWidth, y: y, width: valueWidth, height: 0), font: font)
        y += min(rowHeight, bottom - y) + 6
    }

    /// Een afbeelding, of elke pagina van een PDF-bijlage, op een eigen pagina.
    mutating func attachmentPages(_ attachment: ProductPDFInput.Page) {
        let caption = String(localized: attachment.kind.title)
        if attachment.fileType == "pdf" {
            guard let document = PDFDocument(data: attachment.data) else { return }
            for index in 0..<min(document.pageCount, 20) {
                guard let page = document.page(at: index) else { continue }
                newPage()
                draw(caption, in: CGRect(x: margin, y: margin, width: contentWidth, height: 0), font: .boldSystemFont(ofSize: 11), color: .darkGray)
                let area = CGRect(x: margin, y: margin + 22, width: contentWidth, height: bottom - margin - 22)
                let bounds = page.bounds(for: .mediaBox)
                let scale = min(area.width / bounds.width, area.height / bounds.height)
                let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
                let cg = context.cgContext
                cg.saveGState()
                cg.translateBy(x: area.minX, y: area.minY + size.height)
                cg.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: cg)
                cg.restoreGState()
            }
        } else if let image = UIImage(data: attachment.data) {
            newPage()
            draw(caption, in: CGRect(x: margin, y: margin, width: contentWidth, height: 0), font: .boldSystemFont(ofSize: 11), color: .darkGray)
            let area = CGRect(x: margin, y: margin + 22, width: contentWidth, height: bottom - margin - 22)
            let scale = min(area.width / image.size.width, area.height / image.size.height, 1.5)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: area.minX, y: area.minY, width: size.width, height: size.height))
        }
    }
}
