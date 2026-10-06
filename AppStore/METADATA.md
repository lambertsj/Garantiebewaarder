# App Store Connect: alles om in te vullen

Kopieer per veld. Tekenlimieten zijn gecontroleerd (zie `Scripts/check-metadata.py`).
Primaire taal: **Nederlands**. Voeg daarna **Engels (V.S.)** toe als tweede lokalisatie.

## App-gegevens (eenmalig)

| Veld | Waarde |
|---|---|
| Naam | Garantiebewaarder |
| Bundle-ID | `com.jeroenlamberts.garantiebewaarder` |
| SKU | `garantiebewaarder-ios` |
| Primaire taal | Nederlands |
| Categorie primair / secundair | Productiviteit / Lifestyle |
| Prijs | Gratis (geen in-app aankopen) |
| Copyright | 2026 Jeroen Lamberts |
| Content rights | Bevat geen content van derden |
| Versie | 1.0 (build 1) |
| Release | Handmatig vrijgeven na goedkeuring (of automatisch; jouw keuze) |

## URL's (staan live)

| Veld | URL |
|---|---|
| Privacybeleid-URL (nl) | https://jerlam.dev/garantiebewaarder/privacy.html |
| Support-URL | https://jerlam.dev/garantiebewaarder |
| Marketing-URL | https://jerlam.dev/garantiebewaarder |
| Engelse site | https://jerlam.dev/garantiebewaarder/en/ (controleer of er een Engelse privacypagina is; zo niet, gebruik voor Engels dezelfde privacy-URL) |

## Nederlands

**Subtitel** (max 30): `Bonnen en garantie op één plek`

**Promotietekst** (max 170):
```
Bewaar je bonnen, zie wanneer de garantie afloopt en krijg een herinnering voor het te laat is. Gratis, zonder account, alles op je eigen iPhone.
```

**Trefwoorden** (max 100):
```
garantie,bon,bonnetjes,kassabon,aankoop,scanner,herinnering,producten,administratie,elektronica
```

**Beschrijving** (max 4000):
```
Waar was die bon ook alweer? En zit hier nog garantie op? Met Garantiebewaarder weet je het meteen.

BEWAAR JE BONNEN OP ÉÉN PLEK
• Scan een bon met de camera, kies een foto of PDF, of deel een bestelbevestiging vanuit Mail, Safari of Bestanden.
• De app leest de bon op je toestel en doet een voorstel voor winkel, datum, bedrag en productnaam. Jij controleert en past aan: er wordt nooit iets stilzwijgend opgeslagen.
• Voeg productfoto's, het serienummer, notities en een link naar de handleiding toe.

ZIE WANNEER DE GARANTIE AFLOOPT
• Per product zie je de einddatum en hoe lang het nog gedekt is, met een duidelijke status: gedekt, bijna verlopen of verlopen.
• Stel zelf je standaard garantieduur in en noteer extra dekking, bijvoorbeeld via je creditcard.
• Een widget laat zien welke garantie het eerst afloopt.

HERINNERINGEN VÓÓR HET TE LAAT IS
• Kies hoeveel dagen van tevoren je een melding wilt, zodat je een product nog kunt laten controleren. Optioneel krijg je ook een melding een week van tevoren.

ALS ER IETS KAPOT GAAT
• De claimhulp geeft een eenvoudig stappenplan en een klachtmail die al is ingevuld met de gegevens van je product. Jij past hem aan en verstuurt hem zelf.

ZOEKEN, DELEN, MEENEMEN
• Zoek op naam, merk, winkel, serienummer en zelfs op tekst op de bon, ook via Spotlight.
• Exporteer één product als nette PDF, of al je gegevens als zip met JSON, CSV en alle bijlagen.

PRIVÉ EN GRATIS
• Al je gegevens blijven op je eigen toestel. Geen account, geen eigen server, geen tracking en geen advertenties.
• Tekst op bonnen wordt lokaal op je toestel herkend.
• Synchroniseren via je eigen iCloud is optioneel en staat standaard uit.
• Helemaal gratis: geen abonnement, geen aankopen en geen limiet op het aantal producten. Garantiebewaarder is een hobbyproject en niet commercieel.

Garantiebewaarder geeft algemene informatie en is geen juridisch advies. Kijk voor de actuele regels op ConsuWijzer (consuwijzer.nl).
```

## English (U.S.)

**Subtitle** (max 30): `Receipts & warranties, simply`

**Promotional text** (max 170):
```
Keep your receipts, see when each warranty ends and get a reminder before it's too late. Free, no account, everything stays on your own iPhone.
```

**Keywords** (max 100):
```
warranty,receipt,receipts,purchase,scanner,reminder,products,organizer,electronics,private,guarantee
```

**Description** (max 4000):
```
Where was that receipt again? And is this still under warranty? With Garantiebewaarder you know right away.

KEEP YOUR RECEIPTS IN ONE PLACE
• Scan a receipt with the camera, pick a photo or PDF, or share an order confirmation from Mail, Safari or Files.
• The app reads the receipt on your device and suggests the store, date, amount and product name. You check and adjust: nothing is ever saved silently.
• Add product photos, the serial number, notes and a link to the manual.

SEE WHEN THE WARRANTY ENDS
• For each product you see the end date and how long it's still covered, with a clear status: covered, expiring soon or expired.
• Set your own default warranty term and note extra coverage, for example through your credit card.
• A widget shows which warranty ends first.

REMINDERS BEFORE IT'S TOO LATE
• Choose how many days ahead you want a reminder, so you can still have a product checked. Optionally get a second reminder a week before.

WHEN SOMETHING BREAKS
• Claim help gives a simple step-by-step guide and a complaint email already filled in with your product's details. You edit it and send it yourself.

SEARCH, SHARE, TAKE IT WITH YOU
• Search by name, brand, store, serial number and even text on the receipt, also from Spotlight.
• Export a single product as a neat PDF, or all your data as a zip with JSON, CSV and all attachments.

PRIVATE AND FREE
• All your data stays on your own device. No account, no server of ours, no tracking and no ads.
• Text on receipts is recognized locally on your device.
• Syncing through your own iCloud is optional and off by default.
• Completely free: no subscription, no purchases and no limit on the number of products. Garantiebewaarder is a hobby project and not commercial.

Garantiebewaarder provides general information and is not legal advice. For current rules, see ConsuWijzer (consuwijzer.nl).
```

## Screenshots

Map: `AppStore-screenshots/iphone-6.9-inch/nl` en `…/en` (buiten de repo, naast deze map). Upload bij **iPhone 6,9"**; de kleinere formaten schaalt Apple zelf. De app is iPhone-only, dus geen iPad-screenshots. Volgorde: 01 overzicht, 02 herkenning, 03 detail, 04 bon, 05 herinneringen, 06 claimhulp, 07 privacy.

## App-privacy ("Privacy Nutrition Label")

Antwoord: **"Gegevens niet verzameld"** (Data Not Collected). Klopt met `PrivacyInfo.xcprivacy`: geen tracking, geen verzamelde datatypes, geen third-party SDK's. Optionele iCloud-sync gaat naar de privé-database van de gebruiker zelf; de ontwikkelaar ontvangt niets.
Tracking: **Nee**.

## Leeftijdsclassificatie

Alle vragen **Geen/Nee** (geen geweld, gokken, 18+-inhoud, vrije webtoegang of door gebruikers gegenereerde content met delen). Resultaat: **4+**.

## Exportcompliance / overig

- Versleuteling: de app gebruikt alleen standaard Apple-systeemfuncties; `ITSAppUsesNonExemptEncryption = false` staat al in de app, dus de vraag verschijnt niet bij elke build.
- Advertentie-ID (IDFA): **Nee**.
- Voor kinderen: **Nee**.
- **EU Digital Services Act "trader status"**: App Store Connect vraagt of je als *trader* optreedt. Dit is een eigen, juridische keuze: het is een gratis, niet-commercieel hobbyproject, maar jij bepaalt de juiste status (bij "trader" worden naam/adres/telefoon publiek getoond op de productpagina in de EU). Lees de uitleg van Apple en kies zelf.

## App Review-informatie

Contactgegevens (voornaam, achternaam, telefoon, e-mail) vul je zelf in. **Aanmelden vereist: Nee** (geen account).

**Notities voor de reviewer** (Engels):
```
Garantiebewaarder is a free, private app for keeping receipts and tracking warranty end dates. There is no login, no account and no server; no demo account is needed.

How to test:
1. Launch the app, skip or finish the 3 onboarding screens.
2. Tap "+" > "Enter manually", fill in a product name and tap Save. The product detail opens with the warranty end date and status.
3. In the product detail, tap "Something's wrong" for the claim help (steps + prefilled complaint email template; the app never sends anything itself), or the share button for a PDF export.
4. Settings (gear icon): reminders (local notifications, optional), optional iCloud sync (off by default), export all data, delete everything.

Notes:
- Camera: only used by the document scanner to photograph receipts (requires a physical device). Photos/PDFs can also be picked from the library or Files, or shared into the app via the Share Extension ("Save in Garantiebewaarder").
- Text on receipts is recognized on-device with Apple Vision; nothing leaves the device.
- Notifications are local only and requested after the user saves their first product, with an explanation first.
- The only network use is optional iCloud sync (CloudKit, the user's own private database). There are no third-party SDKs, analytics or ads, and no in-app purchases.
- The app gives general information and does not provide legal advice (disclaimer shown in the claim help).
```

## Wat er in de build moet zitten

Versie 1.0 (1). Een app-icoon van 1024×1024 zonder alfakanaal (nu een placeholder: schild met vinkje; vervang `Garantiebewaarder/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` als je een eigen icoon hebt).
