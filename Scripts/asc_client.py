"""Minimale App Store Connect API-client (JWT ES256). Geen geheimen in de code:
KEY_ID, ISSUER_ID en KEY_PATH komen uit omgevingsvariabelen."""
import json, os, time, urllib.request, urllib.error
import jwt  # PyJWT

BASE = "https://api.appstoreconnect.apple.com"

def token():
    key = open(os.path.expanduser(os.environ["ASC_KEY_PATH"])).read()
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
        key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})

def call(method, path, body=None, raw=False):
    url = path if path.startswith("http") else BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            payload = r.read()
            return (r.status, json.loads(payload) if payload and not raw else payload)
    except urllib.error.HTTPError as e:
        payload = e.read()
        try: return (e.code, json.loads(payload))
        except Exception: return (e.code, payload.decode(errors="replace"))

def get(path): return call("GET", path)
def post(path, body): return call("POST", path, body)
def patch(path, body): return call("PATCH", path, body)
def delete(path): return call("DELETE", path)
