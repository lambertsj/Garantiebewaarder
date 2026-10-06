import Foundation
import SwiftData
import UIKit

#if DEBUG
/// Demodata voor App Store-screenshots (alleen DEBUG, via `-DemoData`). Fictieve
/// winkels en productnamen, zodat er geen echte merken in beeld komen.
@MainActor
enum DemoData {
    static var isEnglish: Bool { Locale.current.language.languageCode?.identifier == "en" }

    /// Nederlandse of Engelse demoteksten, afhankelijk van de taal van de app.
    static func t(_ nl: String, _ en: String) -> String { isEnglish ? en : nl }

    static func populate(_ context: ModelContext, now: Date = Date(), calendar: Calendar = .current) {
        func day(_ offset: Int) -> Date {
            calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: now) ?? now)
        }
        struct Item {
            var name: String; var brand: String; var category: ProductCategory; var store: String
            var endInDays: Int; var months: Int; var price: Decimal; var receipt: Bool
        }
        let items = [
            Item(name: t("Koffiemachine", "Coffee machine"), brand: "Aroma", category: .household, store: t("Huishoudhuis", "Home Goods"), endInDays: 9, months: 24, price: 329, receipt: true),
            Item(name: t("Wasmachine 8 kg", "Washing machine 8 kg"), brand: "Wasco", category: .appliances, store: t("Witgoed Centrum", "Appliance Center"), endInDays: 18, months: 24, price: 549, receipt: true),
            Item(name: t("Televisie 55\"", "Television 55\""), brand: "Visio", category: .electronics, store: t("TechHuis", "TechHouse"), endInDays: 130, months: 36, price: 699, receipt: true),
            Item(name: "Smartphone", brand: "Nova", category: .phoneComputer, store: t("TechHuis", "TechHouse"), endInDays: 250, months: 24, price: 799, receipt: false),
            Item(name: "Laptop 14\"", brand: "Pixel", category: .phoneComputer, store: t("TechHuis", "TechHouse"), endInDays: 430, months: 36, price: 1199, receipt: true),
            Item(name: t("Elektrische fiets", "Electric bike"), brand: "Ritmo", category: .bikeMobility, store: t("Fietsenmaker Jansen", "Jansen Bikes"), endInDays: 660, months: 36, price: 2199, receipt: false),
            Item(name: t("Koptelefoon", "Headphones"), brand: "Klank", category: .electronics, store: t("TechHuis", "TechHouse"), endInDays: -40, months: 24, price: 149, receipt: false),
        ]
        for (index, item) in items.enumerated() {
            let end = day(item.endInDays)
            let purchase = calendar.date(byAdding: .month, value: -item.months, to: end) ?? end
            let product = Product(
                name: item.name, brand: item.brand, category: item.category, store: item.store,
                purchaseDate: purchase, price: item.price, serialNumber: "SN-\(48210 + index * 37)",
                warrantyEndDate: end, warrantySource: .statutoryDefault,
                now: calendar.date(byAdding: .minute, value: index, to: now) ?? now
            )
            context.insert(product)
            if item.receipt,
               let pending = AttachmentProcessor.processImage(
                   receiptImage(store: item.store, product: item.name, price: item.price), kind: .receipt) {
                let attachment = Attachment(kind: .receipt, fileType: "jpg", data: pending.data, thumbnailData: pending.thumbnailData,
                                            recognizedText: "\(item.store) \(item.name) \(item.price)")
                context.insert(attachment)
                attachment.product = product
            }
        }
        try? context.save()
    }

    /// Een nette, fictieve kassabon als afbeelding.
    static func receiptImage(store: String, product: String, price: Decimal, date: String = "14-09-2026") -> UIImage {
        let size = CGSize(width: 900, height: 1300)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor(white: 0.985, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let mono = UIFont.monospacedSystemFont(ofSize: 40, weight: .regular)
            let bold = UIFont.monospacedSystemFont(ofSize: 52, weight: .bold)
            func draw(_ text: String, y: CGFloat, font: UIFont, center: Bool = false) {
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor(white: 0.12, alpha: 1)]
                let width = (text as NSString).size(withAttributes: attributes).width
                (text as NSString).draw(at: CGPoint(x: center ? (size.width - width) / 2 : 70, y: y), withAttributes: attributes)
            }
            let money = price.formatted(.currency(code: "EUR"))
            draw(store.uppercased(), y: 90, font: bold, center: true)
            draw(t("Kassabon", "Receipt"), y: 165, font: mono, center: true)
            draw("\(t("Datum", "Date")): \(date)  14:32", y: 260, font: mono)
            draw(String(repeating: "-", count: 30), y: 330, font: mono)
            draw(product, y: 400, font: mono)
            draw(money.padding(toLength: 12, withPad: " ", startingAt: 0), y: 460, font: mono)
            draw(String(repeating: "-", count: 30), y: 560, font: mono)
            draw("\(t("TOTAAL", "TOTAL"))   \(money)", y: 630, font: bold)
            draw("\(t("PINNEN", "CARD"))    \(money)", y: 720, font: mono)
            draw(t("BTW 21%", "VAT 21%"), y: 800, font: mono)
            draw(t("Bedankt voor uw aankoop!", "Thank you for your purchase!"), y: 1000, font: mono, center: true)
            draw(t("Bewaar deze bon voor garantie", "Keep this receipt for warranty"), y: 1060, font: mono, center: true)
        }
    }
}
#endif
