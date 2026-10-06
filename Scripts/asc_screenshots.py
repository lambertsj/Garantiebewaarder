"""Uploadt de App Store-screenshots (iPhone 6,9") naar App Store Connect (idempotent:
bestaande screenshots in de set worden eerst vervangen)."""
import hashlib, json, pathlib, sys, time, urllib.request
import asc_client as a

APP = "6819593067"
ROOT = pathlib.Path(__file__).resolve().parents[2] / "AppStore-screenshots" / "iphone-6.9-inch"
LOCALES = {"nl-NL": "nl", "en-US": "en"}
DISPLAY = "APP_IPHONE_67"  # de API dekt 6,7" en 6,9" (1320x2868) met dit type

def put_part(op, data):
    chunk = data[op["offset"]: op["offset"] + op["length"]]
    req = urllib.request.Request(op["url"], data=chunk, method=op["method"],
                                headers={h["name"]: h["value"] for h in op.get("requestHeaders", [])})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.status

def main():
    s, r = a.get(f"/v1/apps/{APP}/appStoreVersions?filter[versionString]=1.0")
    VER = r["data"][0]["id"]
    s, r = a.get(f"/v1/appStoreVersions/{VER}/appStoreVersionLocalizations")
    locs = {l["attributes"]["locale"]: l["id"] for l in r["data"]}
    for locale, folder in LOCALES.items():
        loc = locs[locale]
        s, r = a.get(f"/v1/appStoreVersionLocalizations/{loc}/appScreenshotSets")
        sets = {x["attributes"]["screenshotDisplayType"]: x["id"] for x in r["data"]}
        if DISPLAY in sets:
            sid = sets[DISPLAY]
            s, r = a.get(f"/v1/appScreenshotSets/{sid}/appScreenshots")
            for old in r["data"]:
                a.delete(f"/v1/appScreenshots/{old['id']}")
            print(f"{locale}: {len(r['data'])} bestaande screenshots verwijderd")
        else:
            s, r = a.post("/v1/appScreenshotSets", {"data": {
                "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": DISPLAY},
                "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc}}}}})
            assert s == 201, (s, r); sid = r["data"]["id"]
        for f in sorted((ROOT / folder).glob("0*.png")):
            data = f.read_bytes()
            s, r = a.post("/v1/appScreenshots", {"data": {
                "type": "appScreenshots", "attributes": {"fileName": f.name, "fileSize": len(data)},
                "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sid}}}}})
            if s != 201:
                print("FOUT reserveren", f.name, s, json.dumps(r)[:400]); sys.exit(1)
            shot = r["data"]
            for op in shot["attributes"]["uploadOperations"]:
                put_part(op, data)
            s, r = a.patch(f"/v1/appScreenshots/{shot['id']}", {"data": {
                "type": "appScreenshots", "id": shot["id"],
                "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
            state = None
            for _ in range(30):
                s, r = a.get(f"/v1/appScreenshots/{shot['id']}")
                state = r["data"]["attributes"]["assetDeliveryState"]["state"]
                if state in ("COMPLETE", "FAILED"): break
                time.sleep(2)
            print(f"{locale} {f.name}: {state}")

if __name__ == "__main__":
    main()
