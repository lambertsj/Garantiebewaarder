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
}
