import Foundation
import Testing
@testable import Garantiebewaarder

private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
    return c
}()
private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d))! }
private let now = day(2026, 6, 1)
private func parse(_ text: String) -> ParsedReceipt {
    ReceiptParser.parse(lines: text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), now: now, calendar: cal)
}
private func dec(_ s: String) -> Decimal { Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))! }

@Suite("ReceiptParser: complete bonnen")
struct ReceiptParserReceiptTests {
    @Test func coolblueInvoiceWithTextDate() {
        let r = parse("""
        Coolblue
        Factuur
        Factuurdatum: 12 maart 2026
        Bosch WAX32M40NL wasmachine   € 649,00
        Verzendkosten  € 0,00
        Totaal incl. btw  € 649,00
        BTW 21%  € 112,64
        """)
        #expect(r.storeName == ParsedField(value: "Coolblue", confidence: .high))
        #expect(r.purchaseDate == ParsedField(value: day(2026, 3, 12), confidence: .high))
        #expect(r.totalAmount == ParsedField(value: dec("649.00"), confidence: .high))
        #expect(r.productNameCandidates.first == "Bosch WAX32M40NL wasmachine")
        #expect(!r.productNameCandidates.contains { $0.localizedCaseInsensitiveContains("verzend") })
    }

    @Test func mediaMarktKassabonWithSubtotalAndDiscount() {
        let r = parse("""
        MEDIA MARKT
        Amsterdam Zuidoost
        Kassabon
        12-03-2026 14:32
        Samsung TV 55" QLED     1.299,00
        2 x HDMI kabel           19,98
        Subtotaal             1.318,98
        Korting                  -50,00
        TOTAAL                1.268,98
        PINNEN                1.268,98
        BTW 21%                 220,24
        """)
        #expect(r.storeName?.value == "MediaMarkt")
        #expect(r.purchaseDate == ParsedField(value: day(2026, 3, 12), confidence: .medium))
        #expect(r.totalAmount?.value == dec("1268.98"))
        #expect(Array(r.productNameCandidates.prefix(2)) == ["Samsung TV 55\" QLED", "HDMI kabel"])
    }

    @Test func bolOrderMailIgnoresDeliveryDate() {
        let r = parse("""
        bol.com
        Bedankt voor je bestelling!
        Besteldatum: 3 feb 2026
        Verwachte bezorging: 5 feb 2026
        Philips Airfryer XXL HD9650/90     € 199,99
        Totaalbedrag € 199,99
        """)
        #expect(r.storeName?.value == "bol")
        #expect(r.purchaseDate == ParsedField(value: day(2026, 2, 3), confidence: .high))
        #expect(r.totalAmount == ParsedField(value: dec("199.99"), confidence: .high))
        #expect(r.productNameCandidates.first == "Philips Airfryer XXL HD9650/90")
    }

    @Test func messyOCRWithLettersInsteadOfDigits() {
        let r = parse("""
        Bakker Bart
        Dorpsstraat 12
        12-O3-2026 l4:32
        Broodrooster Tefal   EUR 39,95
        Totaal  EUR 39,95
        """)
        #expect(r.storeName?.value == "Bakker Bart")
        #expect(r.purchaseDate?.value == day(2026, 3, 12))
        #expect(r.totalAmount?.value == dec("39.95"))
    }

    @Test func receiptWithoutDate() {
        let r = parse("""
        Praxis
        Boormachine Bosch    € 79,95
        Totaal               € 79,95
        """)
        #expect(r.purchaseDate == nil)
        #expect(r.storeName?.value == "Praxis")
        #expect(r.totalAmount?.value == dec("79.95"))
    }

    @Test func multipleAmountsWithoutKeywordFallBackToLargest() {
        let r = parse("""
        Kleine winkel
        Bonnummer 15
        Waterkoker 24,95
        Theepot 12,50
        Pot 3,00
        """)
        #expect(r.totalAmount == ParsedField(value: dec("24.95"), confidence: .low))
        #expect(r.storeName == ParsedField(value: "Kleine winkel", confidence: .low))
        #expect(r.productNameCandidates.contains("Waterkoker"))
        #expect(r.productNameCandidates.contains("Theepot"))
    }

    @Test func englishInvoiceWithISODate() {
        let r = parse("""
        Amazon.nl
        Invoice
        Order date: 2026-01-15
        Apple AirPods Pro 2    €279,00
        Total €279,00
        VAT 21% €48,42
        """)
        #expect(r.storeName?.value == "Amazon")
        #expect(r.purchaseDate == ParsedField(value: day(2026, 1, 15), confidence: .high))
        #expect(r.totalAmount?.value == dec("279.00"))
        #expect(r.productNameCandidates.first == "Apple AirPods Pro 2")
    }

    @Test func twoDigitYearAndWarrantyDateIgnored() {
        let r = parse("""
        Expert Zwolle
        Datum: 05/11/25
        Stofzuiger Dyson V15    549,00
        Totaal 549,00
        Garantie tot 05/11/27
        """)
        #expect(r.purchaseDate == ParsedField(value: day(2025, 11, 5), confidence: .high))
        #expect(r.storeName?.value == "Expert")
        #expect(r.totalAmount?.value == dec("549.00"))
    }

    @Test func futureAndAncientDatesAreRejected() {
        let r = parse("""
        Winkel X
        Datum 01-01-2040
        Aankoop 12-03-1990
        Magnetron  129,00
        Totaal 129,00
        """)
        #expect(r.purchaseDate == nil)
    }

    @Test func multipleDatesWithoutKeywordPickEarliestWithLowConfidence() {
        let r = parse("""
        Gamma
        10-02-2026 17:40
        04-02-2026 09:15
        Totaal € 35,00
        """)
        #expect(r.purchaseDate == ParsedField(value: day(2026, 2, 4), confidence: .low))
    }

    @Test func columnOCRPutsLabelAndValueOnSeparateLines() {
        let r = parse("""
        Datum
        28-04-2026
        Totaal
        € 1.049,00
        Coolblue
        """)
        #expect(r.purchaseDate == ParsedField(value: day(2026, 4, 28), confidence: .high))
        #expect(r.totalAmount?.value == dec("1049.00"))
        #expect(r.storeName?.value == "Coolblue")
    }

    @Test func garbageGivesEmptyProposal() {
        #expect(parse("\n###\n12 345 678\n").isEmpty)
        #expect(ReceiptParser.parse(lines: [], now: now, calendar: cal).isEmpty)
    }

    @Test func toPayBeatsTotalWhenBothPresent() {
        let r = parse("""
        Totaal 120,00
        Korting 20,00
        Te betalen 100,00
        """)
        #expect(r.totalAmount == ParsedField(value: dec("100.00"), confidence: .high))
    }
}

@Suite("ReceiptParser: onderdelen")
struct ReceiptParserPartsTests {
    @Test(arguments: [
        ("12-03-2026", 12, 3, 2026), ("12/03/26", 12, 3, 2026), ("12.03.2026", 12, 3, 2026),
        ("12 maart 2026", 12, 3, 2026), ("12 mrt 2026", 12, 3, 2026), ("12 mrt. 2026", 12, 3, 2026),
        ("2026-03-12", 12, 3, 2026), ("1 mei 2025", 1, 5, 2025), ("31 december 2025", 31, 12, 2025),
        ("03/25/2026", 25, 3, 2026),
    ])
    func recognizesDateFormats(text: String, d: Int, m: Int, y: Int) {
        #expect(ReceiptParser.dates(in: text, now: now, calendar: cal) == [day(y, m, d)])
    }

    @Test func rejectsImpossibleDates() {
        #expect(ReceiptParser.dates(in: "31-02-2026", now: now, calendar: cal).isEmpty)
        #expect(ReceiptParser.dates(in: "00-00-2026", now: now, calendar: cal).isEmpty)
    }

    @Test(arguments: [
        ("€ 49,95", "49.95"), ("1.299,00", "1299.00"), ("49.95", "49.95"), ("EUR 1.049,50", "1049.50"),
        ("249,00 EUR", "249.00"), ("Totaal 1299.00", "1299.00"), ("€ 49", "49"),
    ])
    func recognizesAmounts(text: String, expected: String) {
        #expect(ReceiptParser.amounts(in: text) == [dec(expected)])
    }

    @Test func ignoresNumbersThatAreNotAmounts() {
        #expect(ReceiptParser.amounts(in: "EAN 8710103123456").isEmpty)
        #expect(ReceiptParser.amounts(in: "Tel 0612345678").isEmpty)
        #expect(ReceiptParser.amounts(in: "Aantal 2").isEmpty)
        #expect(ReceiptParser.amounts(in: "12.03.2026 14:32").isEmpty)
    }

    @Test func candidateListIsCappedAndFiltered() {
        let lines = ["Artikel A", "Artikel B", "Winkelwagen", "Stofzuiger", "Koffiezetter", "Föhn Philips", "Waterkoker", "Pin 12,00", "BTW 21%", "Kassa 3"]
        let candidates = ReceiptParser.productCandidates(lines: lines, storeName: nil)
        #expect(candidates.count <= 5)
        #expect(!candidates.contains { $0.localizedCaseInsensitiveContains("btw") || $0.localizedCaseInsensitiveContains("kassa") })
    }
}
