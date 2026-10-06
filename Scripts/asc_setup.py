"""Vult App Store Connect met de gegevens uit AppStore/METADATA.md (idempotent).
Gebruik: ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_PATH=… python3 Scripts/asc_setup.py"""
import json, pathlib, re, sys
import asc_client as a

APP = "6819593067"
BUNDLE = "com.jeroenlamberts.garantiebewaarder"
text = pathlib.Path(__file__).resolve().parent.parent.joinpath("AppStore/METADATA.md").read_text()

def field(label):
    m = re.search(rf"\*\*{re.escape(label)}\*\* \(max \d+\):\s*(?:```\n(.*?)\n```|`([^`]*)`)", text, re.S)
    return (m.group(1) if m.group(1) is not None else m.group(2)).strip()

def review_notes():
    m = re.search(r"\*\*Notities voor de reviewer\*\* \(Engels\):\s*```\n(.*?)\n```", text, re.S)
    return m.group(1).strip()

def ok(label, res):
    s, r = res
    good = 200 <= s < 300
    print(("OK   " if good else "FOUT ") + f"{label} [{s}]")
    if not good:
        print("     ", json.dumps(r, ensure_ascii=False)[:700])
    return good, r

def main():
    s, r = a.get(f"/v1/apps/{APP}/appStoreVersions?filter[versionString]=1.0")
    VER = r["data"][0]["id"]
    s, r = a.get(f"/v1/apps/{APP}/appInfos"); INFO = r["data"][0]["id"]

    # 1. Categorieën
    ok("categorieën (Productiviteit / Lifestyle)", a.patch(f"/v1/appInfos/{INFO}", {"data": {
        "type": "appInfos", "id": INFO, "relationships": {
            "primaryCategory": {"data": {"type": "appCategories", "id": "PRODUCTIVITY"}},
            "secondaryCategory": {"data": {"type": "appCategories", "id": "LIFESTYLE"}}}}}))

    # 2. App-info lokalisaties (naam, ondertitel, privacy-URL)
    s, r = a.get(f"/v1/appInfos/{INFO}/appInfoLocalizations")
    have = {l["attributes"]["locale"]: l["id"] for l in r["data"]}
    info = {
        "nl-NL": {"name": "Garantiebewaarder", "subtitle": field("Subtitel"),
                  "privacyPolicyUrl": "https://jerlam.dev/garantiebewaarder/privacy.html"},
        "en-US": {"name": "Garantiebewaarder", "subtitle": field("Subtitle"),
                  "privacyPolicyUrl": "https://jerlam.dev/garantiebewaarder/en/privacy.html"},
    }
    for loc, attrs in info.items():
        if loc in have:
            ok(f"app-info {loc}", a.patch(f"/v1/appInfoLocalizations/{have[loc]}", {"data": {
                "type": "appInfoLocalizations", "id": have[loc], "attributes": attrs}}))
        else:
            ok(f"app-info {loc} (nieuw)", a.post("/v1/appInfoLocalizations", {"data": {
                "type": "appInfoLocalizations", "attributes": {"locale": loc, **attrs},
                "relationships": {"appInfo": {"data": {"type": "appInfos", "id": INFO}}}}}))

    # 3. Versie-lokalisaties (beschrijving, trefwoorden, promotietekst, URL's)
    s, r = a.get(f"/v1/appStoreVersions/{VER}/appStoreVersionLocalizations")
    have = {l["attributes"]["locale"]: l["id"] for l in r["data"]}
    ver = {
        "nl-NL": {"description": field("Beschrijving"), "keywords": field("Trefwoorden"),
                  "promotionalText": field("Promotietekst"),
                  "supportUrl": "https://jerlam.dev/garantiebewaarder", "marketingUrl": "https://jerlam.dev/garantiebewaarder"},
        "en-US": {"description": field("Description"), "keywords": field("Keywords"),
                  "promotionalText": field("Promotional text"),
                  "supportUrl": "https://jerlam.dev/garantiebewaarder/en/", "marketingUrl": "https://jerlam.dev/garantiebewaarder/en/"},
    }
    for loc, attrs in ver.items():
        if loc in have:
            ok(f"versie-tekst {loc}", a.patch(f"/v1/appStoreVersionLocalizations/{have[loc]}", {"data": {
                "type": "appStoreVersionLocalizations", "id": have[loc], "attributes": attrs}}))
        else:
            ok(f"versie-tekst {loc} (nieuw)", a.post("/v1/appStoreVersionLocalizations", {"data": {
                "type": "appStoreVersionLocalizations", "attributes": {"locale": loc, **attrs},
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": VER}}}}}))

    # 4. Copyright
    ok("copyright", a.patch(f"/v1/appStoreVersions/{VER}", {"data": {
        "type": "appStoreVersions", "id": VER, "attributes": {"copyright": "2026 Jeroen Lamberts"}}}))

    # 5. Nieuwste geldige build koppelen
    s, r = a.get(f"/v1/builds?filter[app]={APP}&filter[processingState]=VALID&sort=-uploadedDate&limit=1")
    build = r["data"][0]; print(f"     build {build['attributes']['version']} ({build['id']})")
    ok("build koppelen", a.patch(f"/v1/appStoreVersions/{VER}/relationships/build", {"data": {"type": "builds", "id": build["id"]}}))

    # 6. Contentrechten
    ok("contentrechten (geen content van derden)", a.patch(f"/v1/apps/{APP}", {"data": {
        "type": "apps", "id": APP, "attributes": {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"}}}))

    # 7. Leeftijdsclassificatie: overal "geen"
    none = {k: "NONE" for k in [
        "alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated", "gunsOrOtherWeapons", "horrorOrFearThemes",
        "matureOrSuggestiveThemes", "medicalOrTreatmentInformation", "profanityOrCrudeHumor", "sexualContentGraphicAndNudity",
        "sexualContentOrNudity", "violenceCartoonOrFantasy", "violenceRealistic", "violenceRealisticProlongedGraphicOrSadistic"]}
    flags = {k: False for k in ["gambling", "lootBox", "messagingAndChat", "parentalControls", "ageAssurance", "advertising",
                                "unrestrictedWebAccess", "userGeneratedContent", "healthOrWellnessTopics"]}
    ok("leeftijdsclassificatie (alles geen)", a.patch(f"/v1/ageRatingDeclarations/{INFO}", {"data": {
        "type": "ageRatingDeclarations", "id": INFO, "attributes": {**none, **flags}}}))

    # 8. Reviewnotities (contactgegevens vul jij zelf in)
    s, r = a.get(f"/v1/appStoreVersions/{VER}/appStoreReviewDetail")
    detail = r.get("data") if s == 200 else None
    attrs = {"demoAccountRequired": False, "notes": review_notes()}
    if detail:
        ok("reviewnotities", a.patch(f"/v1/appStoreReviewDetails/{detail['id']}", {"data": {
            "type": "appStoreReviewDetails", "id": detail["id"], "attributes": attrs}}))
    else:
        ok("reviewnotities (nieuw)", a.post("/v1/appStoreReviewDetails", {"data": {
            "type": "appStoreReviewDetails", "attributes": attrs,
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": VER}}}}}))

if __name__ == "__main__":
    main()
