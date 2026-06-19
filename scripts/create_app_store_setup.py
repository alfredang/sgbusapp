#!/usr/bin/env python3
import base64
import json
import os
import time
import urllib.parse
import urllib.request
from pathlib import Path

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature


def load_env(path: Path) -> None:
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key, value.strip().strip("\"'"))


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def jwt() -> str:
    key_id = os.environ["ASC_KEY_ID"]
    issuer_id = os.environ["ASC_ISSUER_ID"]
    key_path = Path(os.environ.get("ASC_PRIVATE_KEY_PATH", f"~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8")).expanduser()
    key = serialization.load_pem_private_key(key_path.read_bytes(), password=None)
    now = int(time.time())
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    payload = {"iss": issuer_id, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}
    signing_input = f"{b64url(json.dumps(header, separators=(',', ':')).encode())}.{b64url(json.dumps(payload, separators=(',', ':')).encode())}".encode()
    der_signature = key.sign(signing_input, ec.ECDSA(hashes.SHA256()))
    r, s = decode_dss_signature(der_signature)
    return f"{signing_input.decode()}.{b64url(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))}"


TOKEN = None


def request(method: str, path: str, body: dict | None = None) -> dict:
    req = urllib.request.Request(
        "https://api.appstoreconnect.apple.com" + path,
        data=None if body is None else json.dumps(body).encode(),
        method=method,
        headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as response:
            data = response.read()
    except urllib.error.HTTPError as error:
        detail = error.read().decode()
        raise SystemExit(f"{method} {path} failed: HTTP {error.code}\n{detail}") from error
    return json.loads(data.decode()) if data else {}


def find_one(path: str, filters: dict[str, str]) -> dict | None:
    query = urllib.parse.urlencode({f"filter[{key}]": value for key, value in filters.items()})
    data = request("GET", f"{path}?{query}")
    return next(iter(data.get("data", [])), None)


def main() -> None:
    global TOKEN
    load_env(Path(".env"))
    TOKEN = jwt()

    bundle_id = os.environ["ASC_BUNDLE_ID"]
    app_name = os.environ["ASC_APP_NAME"]
    sku = os.environ["ASC_SKU"]
    profile_name = os.environ.get("ASC_PROFILE_NAME", f"{app_name} App Store")

    bundle = find_one("/v1/bundleIds", {"identifier": bundle_id})
    if bundle is None:
        bundle = request(
            "POST",
            "/v1/bundleIds",
            {
                "data": {
                    "type": "bundleIds",
                    "attributes": {"identifier": bundle_id, "name": app_name, "platform": "IOS"},
                }
            },
        )["data"]

    app = find_one("/v1/apps", {"bundleId": bundle_id})
    app_create_error = None
    if app is None:
        try:
            app = request(
                "POST",
                "/v1/apps",
                {
                    "data": {
                        "type": "apps",
                        "attributes": {"name": app_name, "primaryLocale": "en-US", "sku": sku},
                        "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle["id"]}}},
                    }
                },
            )["data"]
        except SystemExit as error:
            app_create_error = str(error).splitlines()[0]

    certificates = request(
        "GET",
        f"/v1/certificates?{urllib.parse.urlencode({'filter[certificateType]': 'DISTRIBUTION'})}",
    )["data"]
    if not certificates:
        certificates = request(
            "GET",
            f"/v1/certificates?{urllib.parse.urlencode({'filter[certificateType]': 'IOS_DISTRIBUTION'})}",
        )["data"]
    if not certificates:
        raise SystemExit("No distribution certificate found in App Store Connect.")
    cert_serial = os.environ.get("ASC_DISTRIBUTION_CERT_SERIAL", "").upper()
    certificate = next(
        (cert for cert in certificates if cert["attributes"].get("serialNumber", "").upper() == cert_serial),
        certificates[0],
    )

    existing_profiles = request(
        "GET",
        f"/v1/profiles?{urllib.parse.urlencode({'filter[name]': profile_name, 'filter[profileType]': 'IOS_APP_STORE'})}",
    )["data"]
    if existing_profiles:
        profile = existing_profiles[0]
    else:
        profile = request(
            "POST",
            "/v1/profiles",
            {
                "data": {
                    "type": "profiles",
                    "attributes": {"name": profile_name, "profileType": "IOS_APP_STORE"},
                    "relationships": {
                        "bundleId": {"data": {"type": "bundleIds", "id": bundle["id"]}},
                        "certificates": {"data": [{"type": "certificates", "id": certificate["id"]}]},
                    },
                }
            },
        )["data"]

    profile_content = base64.b64decode(profile["attributes"]["profileContent"])
    profile_dir = Path.home() / "Library/MobileDevice/Provisioning Profiles"
    profile_dir.mkdir(parents=True, exist_ok=True)
    profile_path = profile_dir / f"{profile['attributes']['uuid']}.mobileprovision"
    profile_path.write_bytes(profile_content)

    print(json.dumps({
        "app_id": app["id"] if app else None,
        "app_name": app["attributes"]["name"] if app else None,
        "app_create_error": app_create_error,
        "bundle_id": bundle_id,
        "bundle_resource_id": bundle["id"],
        "profile_id": profile["id"],
        "profile_uuid": profile["attributes"]["uuid"],
        "profile_name": profile["attributes"]["name"],
        "profile_path": str(profile_path),
    }, indent=2))


if __name__ == "__main__":
    main()
