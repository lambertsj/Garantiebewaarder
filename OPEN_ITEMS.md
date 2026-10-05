# Open punten

Alles wat jij nog moet doen of controleren voor release, plus bekende beperkingen en aannames.

## 1. `TODO(user)`-punten in de code

Zoek ze met `grep -rn "TODO(user)" Garantiebewaarder project.yml`.

| Waar | Wat |
|---|---|
| `Shared/LegalContent.swift` (kop) | **Alle `legal.*`-teksten nalezen** voor release, bij voorkeur tegen de actuele informatie van ConsuWijzer. |
| `LegalContent.generalInfo` | Disclaimer "Algemene informatie, geen juridisch advies." controleren. |
| `LegalContent.defaultTermDisclaimer` | Zin over de standaardduur ("Veel producten hebben standaard twee jaar garantie…") controleren. Bewust neutraal: de 24 maanden is een **instelling**, geen juridische bewering. |
| `LegalContent.claimSteps` | Controleer elke stap, vooral 3 t/m 5: "begin meestal bij de verkoper, niet per se bij de fabrikant", "redelijke termijn" (er wordt geen aantal dagen genoemd), verwijzing naar ConsuWijzer en een geschillencommissie. Gekoppelde sleutels: `legal.claim.1…5.title/detail` in `Localizable.xcstrings`. |
| `LegalContent.officialSourceURL` | Controleer of `https://www.consuwijzer.nl` en de naam "ConsuWijzer" nog actueel zijn. |
| Klachtmail-sjabloon (`claim.mail.*` in de catalogus) | Tekst nalezen (algemeen gehouden; geen wettelijke claims). |
| `AppInfo.feedbackEmail` | Nu `feedback@example.com`; vul je eigen adres in. |
| `Shared/AppGroup.swift` | App Group-id (`group.com.jeroenlamberts.garantiebewaarder`) moet bij je developer-account passen. |
| `Models/PersistenceController.swift` | iCloud-container-id (`iCloud.com.jeroenlamberts.garantiebewaarder`) moet bij je account passen (ook in `project.yml` onder entitlements). |

## 2. Overig wat jij moet instellen

- **Bundle-identifiers** (aanname): `com.jeroenlamberts.garantiebewaarder` (+ `.share`, `.widget`, `.tests`, `.uitests`). Wijzig in `project.yml` en in de entitlements.
- **Signing**: `DEVELOPMENT_TEAM` staat leeg in `project.yml`; zet je team-id. Daarna in het developer-portal: App Group, iCloud (CloudKit-container) en Push Notifications voor de app, en App Group voor de Share Extension en de widget.
- **CloudKit-schema deployen**: SwiftData maakt het schema in de *development*-omgeving aan zodra je met een echt account synchroniseert. Voor TestFlight/App Store moet je in de CloudKit Dashboard het schema **"Deploy Schema Changes to Production"**. Zonder dat synchroniseren productie-builds niet.
- **Naam**: "Garantiebewaarder" is een werknaam (`CFBundleDisplayName` in `project.yml`; extensienamen daar ook). Controleer beschikbaarheid in App Store Connect.
- **App-icoon**: `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` is een gegenereerde placeholder (schild met vinkje). Vervang het bestand door je eigen 1024×1024-icoon; de rest werkt automatisch. Eventueel ook donker/getint toevoegen.
- **Privacybeleid-URL**: App Store Connect vraagt er een. De app heeft bewust geen eigen server; een korte statische pagina volstaat (de teksten onder "Over deze app" kun je hergebruiken).
- **Taal**: Nederlands is de brontaal, Engels staat klaar (`Localizable.xcstrings`, ook voor de Share Extension). Laat de Engelse teksten nalezen als je Engels wilt uitbrengen; voeg `nl`/`en` toe aan de App Store-metadata.
- **App Store-metadata**: beschrijving, trefwoorden, categorie (Productiviteit of Zakelijk/Lifestyle), schermafbeeldingen, leeftijdsclassificatie, exportcompliance (`ITSAppUsesNonExemptEncryption` staat op `false`).

## 3. Bekende beperkingen en aannames

**Niet gebouwd (bewust, uit de opdracht optioneel/later):**
- Import van een eigen export (JSON/zip) is niet gebouwd; het formaat is wel stabiel en gedocumenteerd.
- App Intents / Siri-sneltoets ("Voeg bon toe") ontbreekt (optioneel in de opdracht).
- De claimhulp is statisch; geen contactgegevens van winkels.

**Aannames:**
- Standaardwaarden: 24 maanden garantie, herinnering 30 dagen vooraf, plus een tweede melding 7 dagen vooraf (aan; instelbaar), 10:00 lokale tijd. iCloud-sync staat **standaard uit**.
- Maanden of dagen: vanaf meer dan 60 dagen resterend tonen we maanden (minimaal 2), anders dagen. De einddatum zelf telt nog als gedekt; "verlopen" begint de dag erna.
- Bedragen worden opgeslagen als gehele centen in euro's; andere valuta zijn niet ondersteund (`currency` staat in de export vast op `EUR`).
- Bijlagen: afbeeldingen worden verkleind tot max. 2400 px (JPEG 0,8); PDF's tot 30 MB; max. 3 pagina's per scan-PDF worden voor OCR gerenderd; PDF-export neemt max. 20 pagina's per PDF-bijlage mee.
- Bij het wisselen van iCloud aan/uit is een herstart nodig (beschreven in de UI). Dit is de eenvoudige aanpak uit de opdracht; hij bleek niet fragiel omdat beide modi hetzelfde opslagbestand gebruiken. Het live-wisselen zonder herstart is niet geprobeerd.
- De Share Extension kopieert bestanden naar de inbox; de hoofdapp doet OCR en toont het voorstel. Als de app nooit wordt geopend, blijven bestanden maximaal 14 dagen staan.

**Niet getest op echt toestel / buiten de simulator** (zie handmatige scenario's in `README.md`):
- Document-camera (VisionKit werkt niet in de simulator), echte iCloud-sync tussen toestellen en de CloudKit-schemadeploy.
- De widget is gebouwd en de logica (snapshot, deep link) is getest, maar het uiterlijk is niet in de simulator bekeken.
- De Share Extension zelf is gebouwd en ingebed; het pad "inbox → app" is end-to-end getest door een bestand in de App Group te zetten, niet via het deelmenu van een andere app.
- OCR-kwaliteit op echte, gekreukte of schuine bonnen: de parser is getest op gesimuleerde tekst en één gerenderde afbeelding. Verwacht dat sommige bonnen een leeg of onjuist voorstel opleveren; de gebruiker controleert altijd.
- Prestaties met 200+ producten zijn niet gemeten (lijst filtert in het geheugen; verwacht voldoende, maar controleer).
- Toegankelijkheid: automatisch geauditeerd en op de grootste tekstgrootte bekeken, maar niet met VoiceOver doorlopen.

**Technische noten:**
- Build-log bevat Xcode-ruis die niet van de code komt: "not stripping binary because it is signed" (XCTest-libraries in Debug) en "AppIntents metadata extraction skipped".
- Swift 6-taalmodus staat aan; `SWIFT_TREAT_WARNINGS_AS_ERRORS` ook.
- Het `.xcodeproj` wordt door xcodegen gegenereerd uit `project.yml` en staat ook in git.
- De Share Extension en widget hebben geen eigen `PrivacyInfo.xcprivacy`; ze gebruiken geen required-reason API's (de extension leest alleen bestandsgrootte). Controleer dit bij archiveren; Xcode meldt het als het wel nodig is.

## 4. Korte checklist voor TestFlight / App Store

- [ ] Alle `TODO(user)`-punten hierboven afgehandeld; juridische teksten nagelezen.
- [ ] Team ingesteld; App Group, iCloud/CloudKit en Push-capabilities aangemaakt; bundle-id's definitief.
- [ ] CloudKit-schema naar Production gedeployed.
- [ ] Eigen app-icoon, finale naam en feedback-adres.
- [ ] Versie/buildnummer verhogen (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`; ook voor de extensies).
- [ ] Archive-build zonder waarschuwingen; Xcode-validatie geslaagd (let op privacy-manifest-meldingen).
- [ ] Handmatige scenario's uit `README.md` doorlopen op een echt toestel (camera, sync, meldingen, widget, deelmenu).
- [ ] **Privacylabel**: "Gegevens niet verzameld" (geen tracking, geen analytics, geen server). Controleer dat dit klopt met de laatste build.
- [ ] **Privacybeleid-URL** ingevuld.
- [ ] **Schermafbeeldingen** (6,9"- en 6,3"-iPhone, optioneel iPad): overzicht, bon-herkenning/bewerkscherm, detail met bijlage, claimhulp, widget.
- [ ] **Beschrijving** en trefwoorden (nl, evt. en); noem expliciet: gratis, geen account, gegevens blijven op je toestel.
- [ ] Leeftijdsclassificatie en exportcompliance ingevuld; "Geen in-app aankopen".
- [ ] Review-notitie: uitleg dat de app geen login heeft; camera-, meldings- en iCloud-gebruik worden alleen op gebruikersactie gevraagd.
- [ ] TestFlight: intern testen, daarna extern met korte testinstructies (scan, deel, melding, iCloud).
