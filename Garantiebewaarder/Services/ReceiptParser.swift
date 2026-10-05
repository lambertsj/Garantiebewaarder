import Foundation

/// Hoe zeker de parser van een herkend veld is. Dit is een hulpmiddel voor
/// de weergave ("controleer dit even"), geen garantie.
enum ParseConfidence: Int, Comparable, Sendable {
    case low, medium, high
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct ParsedField<Value: Equatable & Sendable>: Equatable, Sendable {
    var value: Value
    var confidence: ParseConfidence
}

/// Voorstel op basis van bontekst. Altijd een voorstel: de gebruiker
/// controleert en bevestigt in het bewerkscherm.
struct ParsedReceipt: Equatable, Sendable {
    var storeName: ParsedField<String>?
    var purchaseDate: ParsedField<Date>?
    var totalAmount: ParsedField<Decimal>?
    var productNameCandidates: [String] = []

    var isEmpty: Bool {
        storeName == nil && purchaseDate == nil && totalAmount == nil && productNameCandidates.isEmpty
    }
}

/// Lokale, heuristische parser. Pure functies, geen netwerk, geen state.
enum ReceiptParser {
    static func parse(lines rawLines: [String], now: Date = Date(), calendar: Calendar = .current) -> ParsedReceipt {
        let lines = rawLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let store = parseStore(lines: lines)
        return ParsedReceipt(
            storeName: store,
            purchaseDate: parseDate(lines: lines, now: now, calendar: calendar),
            totalAmount: parseTotal(lines: lines),
            productNameCandidates: productCandidates(lines: lines, storeName: store?.value)
        )
    }

    // MARK: - Hulpfuncties

    private static func regex(_ pattern: String, options: NSRegularExpression.Options = [.caseInsensitive]) -> NSRegularExpression {
        // De patronen zijn constanten; een fout hierin is een programmeerfout die tests meteen vangen.
        guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else {
            preconditionFailure("Ongeldig regex-patroon: \(pattern)")
        }
        return expression
    }

    private static func matches(_ pattern: NSRegularExpression, in text: String) -> [NSTextCheckingResult] {
        pattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private static func group(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> String? {
        guard index < match.numberOfRanges, let range = Range(match.range(at: index), in: text) else { return nil }
        return String(text[range])
    }

    private static func contains(_ pattern: NSRegularExpression, _ text: String) -> Bool {
        pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    // MARK: - Datum

    private static let monthNames = "januari|january|jan|februari|february|feb|maart|march|mrt|mar|april|apr|mei|may|juni|june|jun|juli|july|jul|augustus|august|aug|september|sept|sep|oktober|october|okt|oct|november|nov|december|dec"

    private static let numericDate = regex(#"(?<!\d)([0-9OoIl]{1,2})\s?[-/.]\s?([0-9OoIl]{1,2})\s?[-/.]\s?(\d{4}|\d{2})(?!\d)"#)
    private static let isoDate = regex(#"(?<!\d)(\d{4})-(\d{2})-(\d{2})(?!\d)"#)
    private static let textDate = regex(#"(?<!\d)(\d{1,2})\s*[-\s.]?\s*("# + monthNames + #")\.?\s*[-\s,]?\s*(\d{4}|\d{2})(?!\d)"#)

    private static let dateKeyword = regex(#"datum|date|besteld|gekocht|ordered|purchase|aankoop"#)
    private static let dateExclusion = regex(#"vervaldatum|betaaltermijn|betaald voor|betalen voor|uiterlijk|expir|due|houdbaar|geldig tot|garantie|levering|bezorg|delivery|retour"#)

    private static func monthNumber(_ name: String) -> Int? {
        switch name.lowercased() {
        case "jan", "januari", "january": 1
        case "feb", "februari", "february": 2
        case "mrt", "mar", "maart", "march": 3
        case "apr", "april": 4
        case "mei", "may": 5
        case "jun", "juni", "june": 6
        case "jul", "juli", "july": 7
        case "aug", "augustus", "august": 8
        case "sep", "sept", "september": 9
        case "okt", "oct", "oktober", "october": 10
        case "nov", "november": 11
        case "dec", "december": 12
        default: nil
        }
    }

    private static func fixDigits(_ text: String) -> Int? {
        let mapped = text.map { c -> Character in
            switch c {
            case "O", "o": "0"
            case "I", "l": "1"
            default: c
            }
        }
        return Int(String(mapped))
    }

    private static func makeDate(day: Int, month: Int, year: Int, calendar: Calendar) -> Date? {
        let fullYear = year < 100 ? 2000 + year : year
        let components = DateComponents(year: fullYear, month: month, day: day)
        guard let date = calendar.date(from: components) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == fullYear, check.month == month, check.day == day else { return nil }
        return calendar.startOfDay(for: date)
    }

    /// Alle geldige, plausibele datums in één regel.
    static func dates(in line: String, now: Date, calendar: Calendar) -> [Date] {
        var found: [Date] = []
        for m in matches(isoDate, in: line) {
            if let y = group(m, 1, in: line).flatMap(Int.init), let mo = group(m, 2, in: line).flatMap(Int.init),
               let d = group(m, 3, in: line).flatMap(Int.init), let date = makeDate(day: d, month: mo, year: y, calendar: calendar) {
                found.append(date)
            }
        }
        for m in matches(numericDate, in: line) {
            guard var d = group(m, 1, in: line).flatMap(fixDigits), var mo = group(m, 2, in: line).flatMap(fixDigits),
                  let y = group(m, 3, in: line).flatMap(Int.init) else { continue }
            if mo > 12, d <= 12 { swap(&d, &mo) } // mm/dd/jjjj uit een Engelstalige bon
            if let date = makeDate(day: d, month: mo, year: y, calendar: calendar) { found.append(date) }
        }
        for m in matches(textDate, in: line) {
            if let d = group(m, 1, in: line).flatMap(Int.init), let mo = group(m, 2, in: line).flatMap(monthNumber),
               let y = group(m, 3, in: line).flatMap(Int.init), let date = makeDate(day: d, month: mo, year: y, calendar: calendar) {
                found.append(date)
            }
        }
        let today = calendar.startOfDay(for: now)
        let oldest = calendar.date(byAdding: .year, value: -15, to: today) ?? today
        return found.filter { $0 <= today && $0 >= oldest }
    }

    static func parseDate(lines: [String], now: Date, calendar: Calendar) -> ParsedField<Date>? {
        var keywordDates: [Date] = []
        var otherDates: [Date] = []
        for (index, line) in lines.enumerated() {
            if contains(dateExclusion, line) { continue }
            var found = dates(in: line, now: now, calendar: calendar)
            let hasKeyword = contains(dateKeyword, line)
            // Kolom-OCR: label "Datum" op één regel, de datum op de volgende.
            if found.isEmpty, hasKeyword, index + 1 < lines.count, !contains(dateExclusion, lines[index + 1]) {
                found = dates(in: lines[index + 1], now: now, calendar: calendar)
            }
            if hasKeyword { keywordDates += found } else { otherDates += found }
        }
        if let best = keywordDates.min() { return ParsedField(value: best, confidence: .high) }
        let distinct = Set(otherDates)
        guard let earliest = distinct.min() else { return nil }
        return ParsedField(value: earliest, confidence: distinct.count == 1 ? .medium : .low)
    }

    // MARK: - Bedrag

    private static let dateLike = regex(#"(?<!\d)[0-9OoIl]{1,2}\s?[-/.]\s?[0-9OoIl]{1,2}\s?[-/.]\s?\d{2,4}(?!\d)|(?<!\d)\d{4}-\d{2}-\d{2}(?!\d)"#)
    private static let moneyToken = regex(#"(€|EUR)?\s*(?<![\d.,])(\d{1,3}(?:\.\d{3})+|\d+)(?:[,.](\d{2}))?(?![\d])\s*(€|EUR)?"#)
    private static let totalPriority1 = regex(#"te betalen|totaal ?bedrag|eindtotaal|grand total|total due|amount due|to pay"#)
    private static let totalPriority2 = regex(#"\btotaal\b|\btotal\b|\bbedrag\b|\bamount\b"#)
    private static let totalExclusion = regex(#"subtotaal|sub-total|subtotal|korting|discount|bespaard|retour|wisselgeld|change|contant|cash|gegeven|verzend|shipping|bezorg|statiegeld|punten|spaarzegel"#)
    private static let vatWord = regex(#"btw|vat"#)
    private static let inclusive = regex(#"incl|inclusief|including"#)

    /// Bedragen in een regel. Hele getallen tellen alleen mee met een valutateken
    /// (anders zijn het aantallen, artikelnummers of postcodes).
    static func amounts(in line: String) -> [Decimal] {
        let cleaned = dateLike.stringByReplacingMatches(in: line, range: NSRange(line.startIndex..., in: line), withTemplate: " ")
        var result: [Decimal] = []
        for m in matches(moneyToken, in: cleaned) {
            guard let integerPart = group(m, 2, in: cleaned) else { continue }
            let decimals = group(m, 3, in: cleaned)
            let hasCurrency = group(m, 1, in: cleaned) != nil || group(m, 4, in: cleaned) != nil
            guard decimals != nil || hasCurrency else { continue }
            let digits = integerPart.replacingOccurrences(of: ".", with: "")
            guard let value = Decimal(string: digits + (decimals.map { "." + $0 } ?? ""), locale: Locale(identifier: "en_US_POSIX")),
                  value > 0 else { continue }
            result.append(value)
        }
        return result
    }

    private static func isTotalLineExcluded(_ line: String) -> Bool {
        if contains(totalExclusion, line) { return true }
        return contains(vatWord, line) && !contains(inclusive, line)
    }

    static func parseTotal(lines: [String]) -> ParsedField<Decimal>? {
        var first: [Decimal] = []
        var second: [Decimal] = []
        for (index, line) in lines.enumerated() {
            guard !isTotalLineExcluded(line) else { continue }
            let isFirst = contains(totalPriority1, line)
            guard isFirst || contains(totalPriority2, line) else { continue }
            var values = amounts(in: line)
            if values.isEmpty, index + 1 < lines.count, !isTotalLineExcluded(lines[index + 1]) {
                values = amounts(in: lines[index + 1])
            }
            if isFirst { first += values } else { second += values }
        }
        for group in [first, second] where !group.isEmpty {
            let distinct = Set(group)
            guard let best = distinct.max() else { continue }
            return ParsedField(value: best, confidence: distinct.count == 1 ? .high : .medium)
        }
        let fallback = lines.filter { !isTotalLineExcluded($0) }.flatMap(amounts(in:))
        return fallback.max().map { ParsedField(value: $0, confidence: .low) }
    }

    // MARK: - Winkel

    /// Bekende winkels: weergavenaam en zoekpatronen (hele woorden).
    static let knownStores: [(name: String, pattern: String)] = [
        ("bol", #"bol\.com|^\s*bol\s*$"#),
        ("Coolblue", #"cool\s?blue"#),
        ("MediaMarkt", #"media\s?markt"#),
        ("Amazon", #"amazon"#),
        ("IKEA", #"\bikea\b"#),
        ("Gamma", #"\bgamma\b"#),
        ("Praxis", #"\bpraxis\b"#),
        ("Action", #"\baction\b"#),
        ("Albert Heijn", #"albert\s?heijn"#),
        ("Apple", #"\bapple\b"#),
        ("Bakker Bart", #"bakker\s?bart"#),
        ("Wehkamp", #"wehkamp"#),
        ("Intratuin", #"intratuin"#),
        ("Decathlon", #"decathlon"#),
        ("Karwei", #"karwei"#),
        ("Hornbach", #"hornbach"#),
        ("Blokker", #"blokker"#),
        ("HEMA", #"\bhema\b"#),
        ("Kruidvat", #"kruidvat"#),
        ("Etos", #"\betos\b"#),
        ("Expert", #"\bexpert\b"#),
        ("BCC", #"\bbcc\b"#),
        ("Belsimpel", #"belsimpel"#),
        ("Fonq", #"\bfonq\b"#),
        ("Zalando", #"zalando"#),
        ("Samsung", #"samsung"#),
        ("Xenos", #"\bxenos\b"#),
        ("Jumbo", #"\bjumbo\b"#),
        ("Lidl", #"\blidl\b"#),
        ("Aldi", #"\baldi\b"#),
        ("Bijenkorf", #"bijenkorf"#),
        ("Leen Bakker", #"leen\s?bakker"#),
        ("Kwantum", #"kwantum"#),
        ("Halfords", #"halfords"#),
        ("Fietsenwinkel", #"fietsenwinkel"#),
        ("Gazelle", #"\bgazelle\b"#),
        ("Stella", #"\bstella\b"#),
    ]

    private static let knownStoreRegexes: [(String, NSRegularExpression)] = knownStores.map {
        ($0.name, regex($0.pattern, options: [.caseInsensitive, .anchorsMatchLines]))
    }

    private static let nonStoreLine = regex(#"kassabon|factuur|invoice|receipt|bon\b|datum|date|tel\b|telefoon|kvk|btw|www\.|http|@|\d{4}\s?[A-Z]{2}\b|totaal|order|^\W*$"#)

    static func parseStore(lines: [String]) -> ParsedField<String>? {
        // Bekende winkel: eerst in de kop van de bon, dan overal.
        for scope in [Array(lines.prefix(8)), lines] {
            for line in scope {
                for (name, pattern) in knownStoreRegexes where contains(pattern, line) {
                    return ParsedField(value: name, confidence: scope.count == lines.count && lines.count > 8 ? .medium : .high)
                }
            }
        }
        // Anders: eerste regel die op een naam lijkt.
        for line in lines.prefix(3) {
            let letters = line.filter(\.isLetter).count
            guard letters >= 3, !contains(nonStoreLine, line), letters * 2 >= line.count else { continue }
            return ParsedField(value: line, confidence: .low)
        }
        return nil
    }

    // MARK: - Productnamen

    private static let stopWords = regex(#"\bbtw\b|\bpin\b|pinnen|kassa|totaal|subtotaal|\btotal\b|datum|\bdate\b|\btel\b|telefoon|kvk|www\.|http|@|\biban\b|factuur|invoice|kassabon|klantnummer|ordernummer|retour|wisselgeld|contant|betaald|bedankt|tot ziens|openingstijden|artikel(en)?\b|omschrijving|aantal|\bprijs\b|\bamount\b|\bvat\b|\bcard\b|\bterminal\b|transactie|autorisatie|\d{4}\s?[A-Z]{2}\b|bank|\bkaart\b|verzend|bezorg|korting|\bnr\b|\bnummer\b|\bid\b|adres|straat"#)
    private static let trailingPrice = regex(#"\s*[€]?\s*-?\d{1,3}(?:\.\d{3})*[,.]\d{2}\s*(€|EUR|[A-C])?\s*$"#)
    private static let leadingQuantity = regex(#"^\s*\d{1,2}\s?[xX×]?\s+"#)
    private static let leadingCode = regex(#"^\s*\d{5,}\s+"#)

    static func productCandidates(lines: [String], storeName: String?, limit: Int = 5) -> [String] {
        var priced: [String] = []
        var unpriced: [String] = []
        for line in lines {
            if contains(stopWords, line) { continue }
            if dateLikeLine(line) { continue }
            let hadPrice = contains(trailingPrice, line)
            var text = trailingPrice.stringByReplacingMatches(in: line, range: NSRange(line.startIndex..., in: line), withTemplate: "")
            text = leadingCode.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
            text = leadingQuantity.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let letters = text.filter(\.isLetter).count
            let visible = text.filter { !$0.isWhitespace }.count
            guard letters >= 4, visible > 0, Double(letters) / Double(visible) >= 0.6, text.count <= 70 else { continue }
            if let storeName, squashed(text) == squashed(storeName) { continue }
            if contains(regex(#"^\W*(www|http)"#), text) { continue }
            if hadPrice { priced.append(text) } else { unpriced.append(text) }
        }
        var seen = Set<String>()
        return (priced + unpriced)
            .filter { seen.insert($0.lowercased()).inserted }
            .prefix(limit)
            .map { $0 }
    }

    private static func squashed(_ text: String) -> String {
        text.filter { !$0.isWhitespace }.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func dateLikeLine(_ line: String) -> Bool {
        contains(numericDate, line) || contains(isoDate, line) || contains(textDate, line)
    }
}
