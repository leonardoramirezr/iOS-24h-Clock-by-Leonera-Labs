#!/usr/bin/env python3
"""Minimal App Store Connect API client used by the CI workflow.

Only the Python standard library and the `openssl` command line tool (to sign the
ES256 JWT) are required.

Environment:
  ASC_KEY_ID       Key ID of the App Store Connect API key.
  ASC_ISSUER_ID    Issuer ID of the key.
  ASC_KEY_PATH     Path to the AuthKey_<id>.p8 file, or
  ASC_KEY_P8       the contents of the .p8 file.

Commands:
  write-key PATH                 Write ASC_KEY_P8 to PATH (mode 600) for xcodebuild.
  check                          Verify the key works and at least one iOS device is registered.
  keychain-dev-serials           Print the serial numbers of "Apple Development" certificates
                                 in the keychain search list, one per line.
  revoke-new-dev-certs --before  Revoke (through the API) the "Apple Development" certificates
                                 that are in the keychain now but were not listed in the file.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

API_ROOT = "https://api.appstoreconnect.apple.com"
TOKEN_LIFETIME_SECONDS = 15 * 60  # Apple accepts at most 20 minutes.
DEVELOPMENT_CERTIFICATE_NAME = "Apple Development"


class AscError(Exception):
    """An error that is reported to the user without a traceback."""


# ---------------------------------------------------------------------------
# GitHub Actions helpers
# ---------------------------------------------------------------------------

def log_error(message: str) -> None:
    if os.environ.get("GITHUB_ACTIONS") == "true":
        print(f"::error::{message}", file=sys.stderr)
    else:
        print(f"error: {message}", file=sys.stderr)


def log_warning(message: str) -> None:
    if os.environ.get("GITHUB_ACTIONS") == "true":
        print(f"::warning::{message}")
    else:
        print(f"warning: {message}")


def set_output(name: str, value: str) -> None:
    path = os.environ.get("GITHUB_OUTPUT")
    if path:
        with open(path, "a", encoding="utf-8") as handle:
            handle.write(f"{name}={value}\n")


# ---------------------------------------------------------------------------
# JWT (ES256) signed with openssl
# ---------------------------------------------------------------------------

def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def der_signature_to_raw(der: bytes, size: int = 32) -> bytes:
    """Convert an ASN.1 DER ECDSA signature (SEQUENCE {r, s}) to the JWS r||s form."""

    def read_length(buffer: bytes, index: int) -> tuple[int, int]:
        first = buffer[index]
        index += 1
        if first < 0x80:
            return first, index
        count = first & 0x7F
        return int.from_bytes(buffer[index:index + count], "big"), index + count

    if not der or der[0] != 0x30:
        raise AscError("openssl returned an unexpected signature format")
    _, index = read_length(der, 1)
    numbers = []
    for _ in range(2):
        if der[index] != 0x02:
            raise AscError("openssl returned an unexpected signature format")
        length, index = read_length(der, index + 1)
        numbers.append(int.from_bytes(der[index:index + length], "big"))
        index += length
    return b"".join(number.to_bytes(size, "big") for number in numbers)


def make_token(key_id: str, issuer_id: str, key_path: str) -> str:
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    now = int(time.time())
    payload = {
        "iss": issuer_id,
        "iat": now,
        "exp": now + TOKEN_LIFETIME_SECONDS,
        "aud": "appstoreconnect-v1",
    }
    signing_input = ".".join(
        b64url(json.dumps(part, separators=(",", ":")).encode("utf-8")) for part in (header, payload)
    )
    result = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", key_path],
        input=signing_input.encode("ascii"),
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        detail = result.stderr.decode("utf-8", "replace").strip()
        raise AscError(f"openssl could not sign the token with ASC_KEY_P8 (is it a valid .p8 key?): {detail}")
    return signing_input + "." + b64url(der_signature_to_raw(result.stdout))


def normalize_p8(content: str) -> str:
    """Accept the .p8 file as pasted (also with literal \\n sequences or base64 encoded)."""
    text = content.strip()
    if "\\n" in text and "\n" not in text:
        text = text.replace("\\n", "\n")
    if "BEGIN PRIVATE KEY" not in text:
        try:
            decoded = base64.b64decode(text, validate=False).decode("utf-8")
        except (ValueError, UnicodeDecodeError):
            decoded = ""
        if "BEGIN PRIVATE KEY" in decoded:
            text = decoded.strip()
    if "BEGIN PRIVATE KEY" not in text:
        raise AscError("ASC_KEY_P8 does not look like the contents of an AuthKey_<id>.p8 file")
    return text + "\n"


def resolve_key_path() -> str:
    path = os.environ.get("ASC_KEY_PATH", "").strip()
    if path:
        if not os.path.isfile(path):
            raise AscError(f"ASC_KEY_PATH points to a missing file: {path}")
        return path
    content = os.environ.get("ASC_KEY_P8", "")
    if not content.strip():
        raise AscError("Set ASC_KEY_PATH or ASC_KEY_P8")
    handle = tempfile.NamedTemporaryFile("w", suffix=".p8", delete=False)
    with handle:
        handle.write(normalize_p8(content))
    os.chmod(handle.name, 0o600)
    return handle.name


# ---------------------------------------------------------------------------
# HTTP client
# ---------------------------------------------------------------------------

class Client:
    def __init__(self) -> None:
        key_id = os.environ.get("ASC_KEY_ID", "").strip()
        issuer_id = os.environ.get("ASC_ISSUER_ID", "").strip()
        if not key_id or not issuer_id:
            raise AscError("ASC_KEY_ID and ASC_ISSUER_ID must be set")
        self.token = make_token(key_id, issuer_id, resolve_key_path())

    def request(self, method: str, path_or_url: str, query: dict | None = None) -> dict | None:
        url = path_or_url if path_or_url.startswith("https://") else API_ROOT + path_or_url
        if query:
            url += "?" + urllib.parse.urlencode(query)
        request = urllib.request.Request(
            url,
            method=method,
            headers={"Authorization": f"Bearer {self.token}", "Accept": "application/json"},
        )
        for attempt in range(4):
            try:
                with urllib.request.urlopen(request, timeout=60) as response:
                    body = response.read()
                    return json.loads(body) if body else None
            except urllib.error.HTTPError as error:
                body = error.read().decode("utf-8", "replace")
                if error.code in (429, 500, 502, 503, 504) and attempt < 3:
                    time.sleep(2 ** (attempt + 1))
                    continue
                raise AscError(describe_http_error(method, url, error.code, body)) from None
            except urllib.error.URLError as error:
                if attempt < 3:
                    time.sleep(2 ** (attempt + 1))
                    continue
                raise AscError(f"{method} {url} failed: {error.reason}") from None
        raise AscError(f"{method} {url} failed")

    def list_all(self, path: str, query: dict) -> list[dict]:
        page = self.request("GET", path, query) or {}
        items = list(page.get("data", []))
        next_url = (page.get("links") or {}).get("next")
        while next_url:
            page = self.request("GET", next_url) or {}
            items.extend(page.get("data", []))
            next_url = (page.get("links") or {}).get("next")
        return items


def describe_http_error(method: str, url: str, status: int, body: str) -> str:
    details = ""
    try:
        errors = json.loads(body).get("errors", [])
        details = "; ".join(f"{e.get('title', '')}: {e.get('detail', '')}".strip(": ") for e in errors)
    except (ValueError, AttributeError):
        details = body[:300]
    hint = ""
    if status == 401:
        hint = " The API key was rejected: check ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8."
    elif status == 403:
        hint = " The API key is not allowed to do this: use a Team Key with the Admin role."
    path = urllib.parse.urlsplit(url).path
    return f"{method} {path} returned HTTP {status}: {details}.{hint}"


# ---------------------------------------------------------------------------
# Keychain helpers
# ---------------------------------------------------------------------------

def normalize_serial(value: str) -> str:
    serial = value.strip().upper().replace(":", "")
    return serial.lstrip("0") or "0"


def keychain_development_certificates() -> dict[str, str]:
    """Serial number → subject of every "Apple Development" certificate in the keychain."""
    result = subprocess.run(
        ["security", "find-certificate", "-a", "-c", DEVELOPMENT_CERTIFICATE_NAME, "-p"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return {}
    certificates: dict[str, str] = {}
    pems = re.findall(r"-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----", result.stdout, re.S)
    for pem in pems:
        parsed = subprocess.run(
            ["openssl", "x509", "-noout", "-serial", "-subject"],
            input=pem,
            capture_output=True,
            text=True,
            check=False,
        )
        if parsed.returncode != 0:
            continue
        serial, subject = "", ""
        for line in parsed.stdout.splitlines():
            if line.lower().startswith("serial="):
                serial = normalize_serial(line.split("=", 1)[1])
            elif line.lower().startswith("subject"):
                subject = line.split("=", 1)[1].strip() if "=" in line else line
        if serial:
            certificates[serial] = subject
    return certificates


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def command_check(_: argparse.Namespace) -> int:
    client = Client()
    devices = client.list_all(
        "/v1/devices",
        {
            "filter[platform]": "IOS",
            "filter[status]": "ENABLED",
            "fields[devices]": "name,deviceClass,model,status",
            "limit": "200",
        },
    )
    print("App Store Connect API key is valid.")
    if not devices:
        raise AscError(
            "No enabled iOS devices are registered in the Apple Developer portal. "
            "Register the UDID of your iPhone (Certificates, Identifiers & Profiles › Devices) and push again."
        )
    print(f"Registered iOS devices: {len(devices)}")
    for device in devices:
        attributes = device.get("attributes", {})
        name = attributes.get("name") or "(unnamed)"
        kind = attributes.get("deviceClass") or "?"
        model = attributes.get("model") or ""
        print(f"  - {name} [{kind}] {model}".rstrip())
    set_output("device_count", str(len(devices)))
    return 0


def command_write_key(arguments: argparse.Namespace) -> int:
    content = os.environ.get("ASC_KEY_P8", "")
    if not content.strip():
        raise AscError("ASC_KEY_P8 is empty")
    directory = os.path.dirname(os.path.abspath(arguments.path))
    os.makedirs(directory, exist_ok=True)
    descriptor = os.open(arguments.path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
        handle.write(normalize_p8(content))
    print(f"Wrote the App Store Connect API key to {arguments.path}")
    return 0


def command_keychain_dev_serials(_: argparse.Namespace) -> int:
    for serial in sorted(keychain_development_certificates()):
        print(serial)
    return 0


def command_revoke_new_dev_certs(arguments: argparse.Namespace) -> int:
    if not os.path.isfile(arguments.before):
        # Without the list taken before the build nothing can be told apart: revoke nothing.
        print(f"{arguments.before} was not recorded (the build stopped earlier); nothing to revoke.")
        return 0
    with open(arguments.before, encoding="utf-8") as handle:
        before = {normalize_serial(line) for line in handle if line.strip()}
    current = keychain_development_certificates()
    new_serials = {serial: subject for serial, subject in current.items() if serial not in before}
    if not new_serials:
        print("No new Apple Development certificates were created by this run.")
        return 0

    client = Client()
    certificates = client.list_all(
        "/v1/certificates",
        {"fields[certificates]": "serialNumber,name,displayName,certificateType", "limit": "200"},
    )
    by_serial = {
        normalize_serial(item.get("attributes", {}).get("serialNumber", "")): item for item in certificates
    }

    failures = 0
    for serial, subject in sorted(new_serials.items()):
        certificate = by_serial.get(serial)
        if certificate is None:
            log_warning(f"Certificate {serial} ({subject}) is not in App Store Connect; nothing to revoke.")
            continue
        certificate_type = certificate.get("attributes", {}).get("certificateType", "")
        if "DEVELOPMENT" not in certificate_type:
            log_warning(f"Skipping certificate {serial}: type {certificate_type} is not a development certificate.")
            continue
        try:
            client.request("DELETE", f"/v1/certificates/{certificate['id']}")
            print(f"Revoked temporary development certificate {serial} ({subject}).")
        except AscError as error:
            failures += 1
            log_error(f"Could not revoke certificate {serial}: {error}")
    return 1 if failures else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    write_key = commands.add_parser("write-key")
    write_key.add_argument("path")
    write_key.set_defaults(handler=command_write_key)
    commands.add_parser("check").set_defaults(handler=command_check)
    commands.add_parser("keychain-dev-serials").set_defaults(handler=command_keychain_dev_serials)
    revoke = commands.add_parser("revoke-new-dev-certs")
    revoke.add_argument("--before", required=True, help="File with the serial numbers recorded before the build")
    revoke.set_defaults(handler=command_revoke_new_dev_certs)
    arguments = parser.parse_args()
    try:
        return arguments.handler(arguments)
    except AscError as error:
        log_error(str(error))
        return 1


if __name__ == "__main__":
    sys.exit(main())
