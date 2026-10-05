# Garantiebewaarder

Een gratis, privacy-first iOS-app om bonnen en aankopen te bewaren en te zien wanneer de garantie afloopt.
Hobbyproject, niet commercieel. De naam is een werknaam (zie "Naam wijzigen").

## Wat de app doet

- Bonnen en aankopen bewaren, met foto's en PDF's als bijlage.
- Een bon scannen (document-camera), een foto/PDF kiezen of delen vanuit een andere app. De tekst wordt lokaal herkend (Vision) en de app doet een **voorstel** voor winkel, datum, bedrag en productnaam. Jij controleert en bewaart; er wordt nooit stilzwijgend iets opgeslagen.
- Berekent de einddatum van de garantie en toont de status (gedekt / bijna verlopen / verlopen) met icoon, tekst én kleur.
- Lokale herinneringen vóór de garantie afloopt.
- Zoeken (ook in herkende bontekst), filteren, sorteren, archiveren.
- Claimhulp ("Er is iets mis") met stappenplan en een invulbare klachtmail die jij zelf verstuurt.
- PDF-export per product, export van alle gegevens (zip met JSON, CSV en bijlagen).
- Widget (eerstvolgende garantie), Spotlight-zoeken, Share Extension ("Bewaar in Garantiebewaarder").
- Optionele iCloud-sync (je eigen privé-database).

## Privacyprincipes

1. Alle data blijft op het toestel. Optioneel synchroniseren via de privé-iCloud (CloudKit) van de gebruiker. Geen eigen server, geen account.
2. Geen trackers, geen analytics, geen advertenties, geen crashreporters van derden. Er is **geen enkele third-party dependency** en geen netwerkcode (`URLSession` komt nergens voor).
3. Gratis: geen StoreKit, geen limiet.
4. Tekstherkenning gebeurt met Apple Vision op het toestel.
5. Alleen algemene informatie, geen juridisch advies. Alle juridische teksten staan gebundeld in `Garantiebewaarder/Shared/LegalContent.swift` (de zinnen zelf onder de `legal.*`-sleutels in de String Catalog).
6. `PrivacyInfo.xcprivacy` meldt: geen tracking, geen verzamelde data, required-reason API's: UserDefaults (`CA92.1`) en file timestamps (`C617.1`, bestanden in de eigen/App Group-container).

Het App Store-privacylabel kan daarom "Gegevens niet verzameld" zijn.

## Bouwen

Vereisten: Xcode 26, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate                      # project.yml is de bron; het .xcodeproj wordt daaruit gemaakt
open Garantiebewaarder.xcodeproj
# of vanaf de command line:
xcodebuild -scheme Garantiebewaarder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Let op: deze xcodegen-installatie laadt geen standaard "SettingPresets"; alle build settings staan daarom expliciet in `project.yml`. Bij nieuwe bestanden opnieuw `xcodegen generate` draaien.

Zonder Apple Developer-team bouwt en draait alles in de simulator. Voor een toestel/TestFlight: zie `OPEN_ITEMS.md`.

### Naam wijzigen
De weergavenaam staat op één plek: `CFBundleDisplayName` in `project.yml` (target `Garantiebewaarder`). De UI leest hem via `AppInfo.name`. De naam van de Share Extension ("Bewaar in …") en de widget staan in hun eigen `info`-blok in `project.yml`.

## Architectuur

Eenvoudig en leesbaar: SwiftUI-views, daarnaast losse services zonder UI. Geen architectuurframework.

```
Garantiebewaarder/
  App/        App-entry, AppDelegate (notificaties), DeepLinkRouter, RootView, RemindersSync
  Models/     Product, Attachment, enums, Money, PersistenceController, PreviewData
  Services/   WarrantyCalculator, ReceiptParser, OCRService, NotificationPlanner/-Scheduler,
              ExportService + ExportFormat, InboxImporter, AttachmentProcessor, ProductListQuery,
              ProductDraft, ReceiptSuggestions, ClaimEmailTemplate, DataEraser, SystemIntegration, ICloudStatus
  Features/   Onboarding, ProductList, AddProduct, ProductDetail, Attachments, ClaimHelp, Settings, Export
  Shared/     AppInfo, AppSettings, AppGroup, InboxStore, LegalContent, Theme, WidgetSnapshot, ...
  Resources/  Localizable.xcstrings, Assets, PrivacyInfo.xcprivacy
GarantiebewaarderShare/    Share Extension (kent het model niet; schrijft naar de App Group-inbox)
GarantiebewaarderWidget/   WidgetKit-extensie (leest een klein JSON-snapshot uit de App Group)
GarantiebewaarderTests/    Swift Testing
GarantiebewaarderUITests/  XCUITest
```

Kernideeën:

- **Logica buiten de views.** `WarrantyCalculator`, `ReceiptParser`, `NotificationPlanner`, `ProductListQuery`, `ProductDraft` en `ExportService` zijn pure/testbare code. Views tonen en roepen aan.
- **CloudKit-vriendelijk model.** Alle properties hebben een standaardwaarde, geen `.unique`, relaties zijn optioneel met inverse, bijlagen staan in `.externalStorage`. Enums staan als raw-string (onbekende waarde valt veilig terug), bedragen als gehele centen (`priceCents`).
- **Garantiestatus is afgeleid**, nooit opgeslagen. De einddatum zelf wordt wel opgeslagen (als start van de dag, lokale tijd); de einddatum is zelf nog een geldige dag.
- **OCR → voorstel → controle.** `OCRService` voegt Vision-blokken op dezelfde hoogte samen tot regels (kolommen: "Wasmachine   649,00"). `ReceiptParser` (puur) geeft per veld een betrouwbaarheid. Het formulier markeert herkende velden met tint, icoon en tekst en laat de gebruiker alles aanpassen.
- **Meldingen.** `NotificationPlanner` bepaalt de planning (10:00 lokale tijd; hoofdherinnering + optioneel 7 dagen vooraf), begrenst op de 60 eerstvolgende (iOS-limiet is 64) en wordt bij start, foreground, na elke wijziging en na sync opnieuw uitgerekend; `NotificationScheduler` verwijdert alles en plant opnieuw. Toestemming wordt nooit tijdens sync gevraagd, alleen na uitleg bij het eerste bewaarde product of via de instellingen.
- **iCloud-sync aan/uit.** Bij het opstarten wordt de `ModelConfiguration` met of zonder CloudKit gekozen op basis van de voorkeur. Beide modi gebruiken hetzelfde bestand, dus aan/uit zetten verliest niets; een wijziging werkt na een herstart (de UI legt dat uit). Faalt iCloud (geen account, geen entitlement), dan werkt de app lokaal door zonder blokkerende foutmelding (`PersistenceController.SyncMode.iCloudUnavailableUsingLocal`).
- **Share Extension.** Schrijft bestanden naar `inbox/` in de App Group. De hoofdapp importeert bij start en bij foreground (`InboxImporter`), draait OCR en opent het bewerkscherm; de inbox wordt pas na het sluiten van dat scherm opgeruimd. Bestanden ouder dan 14 dagen worden opgeruimd.
- **Widget/Spotlight.** De widget krijgt alleen id, naam en einddatum (geen bijlagen, geen bontekst). Spotlight indexeert lokaal, zonder bontekst.

## JSON-exportformaat (schemaVersion 1)

"Instellingen → Exporteer alle gegevens" maakt `Garantiebewaarder-export-<datum>.zip` met `products.json`, `products.csv`, `README.txt` en `attachments/<productId>/<attachmentId>.<jpg|pdf>`. De bron van waarheid is `Services/ExportFormat.swift`. Bestaande velden veranderen nooit van betekenis; nieuwe velden komen optioneel erbij.

```json
{
  "schemaVersion": 1,
  "app": "Garantiebewaarder",
  "appVersion": "1.0",
  "exportedAt": "2026-03-12T09:30:00Z",
  "products": [{
    "id": "UUID",
    "name": "Wasmachine",
    "brand": "",
    "category": "appliances",
    "store": "",
    "purchaseDate": "2026-03-12",
    "priceCents": 64900,
    "currency": "EUR",
    "serialNumber": "",
    "notes": "",
    "warrantyEndDate": "2028-03-12",
    "warrantySource": "statutoryDefault",
    "extraCoverageNote": "",
    "manualURL": "",
    "isArchived": false,
    "createdAt": "2026-03-12T09:30:00Z",
    "updatedAt": "2026-03-12T09:30:00Z",
    "attachments": [{
      "id": "UUID",
      "kind": "receipt",
      "fileType": "jpg",
      "file": "attachments/<productId>/<id>.jpg",
      "recognizedText": "",
      "createdAt": "2026-03-12T09:30:00Z"
    }]
  }]
}
```

- `category`: `electronics | appliances | phoneComputer | household | furniture | tools | bikeMobility | clothingSports | other`
- `warrantySource`: `statutoryDefault | manufacturer | manual`; `kind`: `receipt | productPhoto | other`
- Datums zonder tijd zijn lokale kalenderdagen (`yyyy-MM-dd`); tijdstempels zijn ISO 8601 in UTC; `priceCents` ontbreekt als het bedrag onbekend is.
- CSV: RFC 4180, komma-gescheiden, UTF-8, bedragen met punt (`649.05`).
- Import van een eigen export is nog niet gebouwd (zie `OPEN_ITEMS.md`).

## Teststrategie en testrapport

Draaien: `xcodebuild -scheme Garantiebewaarder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

**Stand bij oplevering (iPhone 17 Pro-simulator, iOS 26): 109 unit tests (Swift Testing, 19 suites) en 10 UI-tests (XCUITest) slagen. Debug- en Release-build zonder waarschuwingen** (de enige regels in de log zijn Xcode-ruis: "not stripping binary" voor XCTest-libraries en "AppIntents metadata skipped").

| Onderdeel | Dekking |
|---|---|
| `WarrantyCalculator` | schrikkeljaar, maandeinde, zomer-/wintertijd (hele kalenderdagen), aankoopdatum in de toekomst, einddatum in het verleden, statusgrenzen, "nog 14 maanden / 9 dagen / verlopen op …" |
| `ReceiptParser` | 14 gesimuleerde bonnen (Coolblue-factuur, MediaMarkt-kassabon, bol-mail, rommelige OCR, geen datum, meerdere bedragen, Engelstalig, kolom-OCR, toekomst/te oude datums, "te betalen" vs "totaal") plus parametrische tests voor datum- en bedragformaten |
| `OCRService` | rij-samenvoeging, een écht Vision-run op een gerenderde bon, PDF met ingebedde tekst |
| `NotificationPlanner/-Scheduler` | 60-limiet (200 kandidaten), rooster 10:00 over zomertijd heen, tweede melding, gearchiveerd/verlopen, geweigerd/onbepaald (nooit prompten), opnieuw synchroniseren zonder duplicaten (nep-notificatiecentrum) |
| `ExportService` | JSON round-trip met alle velden, stabiele sleutels, CSV-escaping, zip met JSON/CSV/bijlagen, PDF per product (paginatelling, inhoud) |
| Persistentie | cascade delete, iCloud-aanvraag crasht/blokkeert nooit, alles verwijderen, archief |
| Overig | inbox (Share Extension), widget-snapshot, deep links, Spotlight (geen bontekst), klachtmail-sjabloon, attachment-verwerking, lijst filteren/zoeken/sorteren |
| UI-tests | toevoegen → detail → bewerken → verwijderen; zoeken; onboarding; instellingen; bon-herkenning (voorstel → Bewaar in één tik); claimhulp; **toegankelijkheidsaudit** (`performAccessibilityAudit`) incl. grootste Dynamic Type |

De accessibility-audit negeert bewust enkele door het systeem veroorzaakte meldingen (navigatiebalkknoppen en systeemtekst bij Dynamic Type, "grenswaarde" bij door het systeem gestijlde koppen, anonieme meldingen over het transparante navigatiebalkmateriaal). Zie `AccessibilityAuditUITests.audit(_:)`. Echte fouten laten de test falen; de grootste tekstgrootte is daarnaast met een screenshot beoordeeld.

### Handmatige testscenario's

De simulator kan niet alles; loop deze na op een toestel:

1. **Geen iCloud-account:** uitgelogd → iCloud-sync aanzetten → herstart → instellingen tonen "Niet ingelogd bij iCloud", de app werkt lokaal door zonder foutmelding.
2. **iCloud uit/aan:** aan → herstart → data blijft; uit → herstart → data blijft lokaal; tweede toestel ontvangt wijzigingen.
3. **Nieuw toestel (sync-herstel):** installeer op een tweede toestel met hetzelfde Apple ID, sync aan, producten en bijlagen verschijnen; meldingen worden daarna opnieuw ingepland.
4. **Meldingen geweigerd:** weiger bij de uitleg → instellingen tonen de hint met knop naar systeeminstellingen; de app blijft werken. Daarna toestaan → meldingen worden ingepland.
5. **Meldingen:** product met einddatum over 8 dagen → zet het toestel-/simulatortijdstip voor een snelle test; tik op de melding → het juiste product opent (ook bij koude start).
6. **Grote PDF:** een PDF van ~25 MB en één > 30 MB (moet netjes worden geweigerd met "te groot").
7. **200+ producten:** importeer veel voorbeeldproducten (bijv. via een tijdelijke seed-functie) → lijst blijft vloeiend scrollen, zoeken reageert direct.
8. **Dynamic Type op het grootst** (Instellingen → Toegankelijkheid → Grotere tekst): alle schermen blijven bruikbaar.
9. **VoiceOver:** door overzicht, detail, formulier (herkende velden melden "Herkend van je bon"), claimhulp; statusbadge leest status + tijd voor.
10. **Vliegtuigmodus:** alles werkt volledig (scannen, OCR, export, meldingen); alleen iCloud-sync wacht.
11. **Document-camera** (alleen op toestel): scan een echte bon; meerdere pagina's; annuleren.
12. **Share Extension:** deel een bonfoto uit Foto's, een PDF uit Bestanden en een factuur uit Mail → "Bewaard" → open de app → bewerkscherm met voorstel.
13. **Widget:** voeg de widget (klein en middel) toe; tik opent het product; na verwijderen van alles toont hij de lege staat.
14. **Dark Mode en iPad:** beide bekeken in de simulator; controleer de kleuren van het "herkend"-label.

## Bekende beperkingen
Zie `OPEN_ITEMS.md`.
