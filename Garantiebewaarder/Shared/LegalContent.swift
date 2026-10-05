import Foundation

/// ALLE juridische en uitlegteksten van de app staan hier gebundeld (de
/// eigenlijke zinnen staan in `Resources/Localizable.xcstrings` onder de
/// sleutels `legal.*`). Nalezen en bijwerken kan dus op één plek.
///
/// Uitgangspunt: de app geeft algemene informatie en geen juridisch advies.
/// Er worden geen wettelijke termijnen of rechten beweerd. De standaard
/// garantieduur (24 maanden) is een instelling van de gebruiker.
///
/// TODO(user): controleer alle `legal.*`-teksten voor release, bij voorkeur
/// tegen de actuele informatie van ConsuWijzer (consuwijzer.nl).
enum LegalContent {
    /// Korte disclaimer, bij claimhulp en bij de standaardduur.
    /// TODO(user): controleer deze tekst voor release
    static let generalInfo: LocalizedStringResource = "legal.generalInfo"

    /// Bij het kiezen van de standaard garantieduur.
    /// TODO(user): controleer deze tekst voor release
    static let defaultTermDisclaimer: LocalizedStringResource = "legal.defaultTerm"

    /// Verwijzing naar de officiële bron.
    /// TODO(user): controleer of deze URL en naam nog actueel zijn
    static let officialSourceName = "ConsuWijzer"
    static let officialSourceURL = URL(string: "https://www.consuwijzer.nl")

    /// Stappenplan in de claimhulp. Bewust algemeen gehouden: geen termijnen of rechten genoemd.
    /// TODO(user): controleer elke stap (vooral 3 t/m 5) voor release tegen ConsuWijzer.
    struct ClaimStep: Identifiable {
        let number: Int
        let title: LocalizedStringResource
        let detail: LocalizedStringResource
        var id: Int { number }
    }

    static let claimSteps: [ClaimStep] = [
        ClaimStep(number: 1, title: "legal.claim.1.title", detail: "legal.claim.1.detail"),
        ClaimStep(number: 2, title: "legal.claim.2.title", detail: "legal.claim.2.detail"),
        ClaimStep(number: 3, title: "legal.claim.3.title", detail: "legal.claim.3.detail"),
        ClaimStep(number: 4, title: "legal.claim.4.title", detail: "legal.claim.4.detail"),
        ClaimStep(number: 5, title: "legal.claim.5.title", detail: "legal.claim.5.detail"),
    ]
}
