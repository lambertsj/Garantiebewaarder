import Foundation

/// Sjabloon voor een klachtmail, ingevuld met de productgegevens. De app
/// verstuurt niets zelf: de gebruiker past de tekst aan en deelt hem zelf.
enum ClaimEmailTemplate {
    struct Input: Equatable, Sendable {
        var productName: String
        var brand: String
        var store: String
        var purchaseDate: Date
        var price: Decimal?
        var serialNumber: String
    }

    struct Message: Equatable, Sendable {
        var subject: String
        var body: String
    }

    static func make(
        _ input: Input,
        bundle: Bundle = .main,
        locale: Locale = .current
    ) -> Message {
        let date = input.purchaseDate.formatted(.dateTime.day().month(.wide).year().locale(locale))
        let name = [input.brand, input.productName].filter { !$0.isEmpty }.joined(separator: " ")
        let subject = String(localized: "claim.mail.subject \(name) \(date)", bundle: bundle, locale: locale)

        var lines: [String] = []
        lines.append(String(localized: "claim.mail.greeting", bundle: bundle, locale: locale))
        lines.append("")
        if input.store.isEmpty {
            lines.append(String(localized: "claim.mail.intro.noStore \(date) \(name)", bundle: bundle, locale: locale))
        } else {
            lines.append(String(localized: "claim.mail.intro \(date) \(input.store) \(name)", bundle: bundle, locale: locale))
        }
        if let price = input.price {
            lines.append(String(localized: "claim.mail.price \(price.formatted(.currency(code: "EUR").locale(locale)))", bundle: bundle, locale: locale))
        }
        if !input.serialNumber.isEmpty {
            lines.append(String(localized: "claim.mail.serial \(input.serialNumber)", bundle: bundle, locale: locale))
        }
        lines.append("")
        lines.append(String(localized: "claim.mail.problem", bundle: bundle, locale: locale))
        lines.append("")
        lines.append(String(localized: "claim.mail.request", bundle: bundle, locale: locale))
        lines.append("")
        lines.append(String(localized: "claim.mail.closing", bundle: bundle, locale: locale))
        return Message(subject: subject, body: lines.joined(separator: "\n"))
    }

    /// `mailto:`-URL; bij een klacht zonder ontvanger (die weet de gebruiker zelf).
    static func mailtoURL(for message: Message, recipient: String = "") -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: message.subject),
            URLQueryItem(name: "body", value: message.body),
        ]
        // `URLComponents` laat spaties als "+" staan in sommige gevallen; mailto verwacht %20.
        return components.string.flatMap { URL(string: $0.replacingOccurrences(of: "+", with: "%20")) }
    }
}
