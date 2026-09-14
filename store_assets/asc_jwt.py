#!/usr/bin/env python3
"""Print an App Store Connect API bearer token.

`xcrun altool --generate-jwt` is broken in Xcode 26, so sign the ES256 JWT
ourselves. Uses only openssl and the standard library.

    TOK=$(python3 store_assets/asc_jwt.py)
    curl -H "Authorization: Bearer $TOK" \
      "https://api.appstoreconnect.apple.com/v1/apps?filter%5BbundleId%5D=sek.leocore.erp"
"""
import base64
import json
import os
import subprocess
import time

KEY_ID = os.environ.get("ASC_KEY_ID", "R86H46956N")
ISSUER = os.environ.get("ASC_ISSUER", "afc4f68b-4d8f-4940-ad87-fbd53041cc13")
KEY = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")


def b64(raw: bytes) -> bytes:
    return base64.urlsafe_b64encode(raw).rstrip(b"=")


def der_to_raw(der: bytes) -> bytes:
    """ECDSA DER SEQUENCE{INTEGER r, INTEGER s} -> the raw r||s JOSE wants."""
    i = 2 + (der[1] & 0x7F if der[1] & 0x80 else 0)

    def read(at):
        assert der[at] == 0x02, "expected an ASN.1 INTEGER"
        length = der[at + 1]
        value = der[at + 2 : at + 2 + length]
        return value.lstrip(b"\x00").rjust(32, b"\x00"), at + 2 + length

    r, i = read(i)
    s, _ = read(i)
    return r + s


def token(ttl=1200) -> str:
    now = int(time.time())
    header = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    payload = {"iss": ISSUER, "iat": now, "exp": now + ttl,
               "aud": "appstoreconnect-v1"}
    dump = lambda o: json.dumps(o, separators=(",", ":")).encode()
    signing_input = b64(dump(header)) + b"." + b64(dump(payload))
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", KEY],
        input=signing_input, capture_output=True, check=True,
    ).stdout
    return (signing_input + b"." + b64(der_to_raw(der))).decode()


if __name__ == "__main__":
    print(token())
