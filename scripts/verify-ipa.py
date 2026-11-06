#!/usr/bin/env python3
"""Check that every bundle in an IPA embeds an Ad Hoc provisioning profile.

Usage: verify-ipa.py path/to/App.ipa

For the app and each extension it prints the profile name, team, expiration date and
the number of devices it includes. It fails when a bundle has no profile, or when the
profile is not Ad Hoc (development profiles allow debugging; enterprise profiles
provision all devices). Writes `device_count` (the smallest count) to $GITHUB_OUTPUT.
"""

from __future__ import annotations

import os
import plistlib
import re
import subprocess
import sys
import zipfile

BUNDLE_PATTERN = re.compile(r"^(Payload/[^/]+\.app(?:/PlugIns/[^/]+\.appex)?)/embedded\.mobileprovision$")
APP_PATTERN = re.compile(r"^(Payload/[^/]+\.app(?:/PlugIns/[^/]+\.appex)?)/Info\.plist$")


def decode_profile(data: bytes) -> dict:
    """Extract the property list from the CMS envelope of a provisioning profile."""
    try:
        result = subprocess.run(
            ["security", "cms", "-D"], input=data, capture_output=True, check=False
        )
        if result.returncode == 0 and result.stdout:
            return plistlib.loads(result.stdout)
    except FileNotFoundError:
        pass  # Not on macOS: fall back to the plain XML inside the envelope.
    start = data.find(b"<?xml")
    end = data.find(b"</plist>")
    if start < 0 or end < 0:
        raise ValueError("the provisioning profile is not readable")
    return plistlib.loads(data[start:end + len(b"</plist>")])


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    ipa_path = sys.argv[1]
    in_actions = os.environ.get("GITHUB_ACTIONS") == "true"

    def fail(message: str) -> None:
        print(f"::error::{message}" if in_actions else f"error: {message}", file=sys.stderr)

    with zipfile.ZipFile(ipa_path) as archive:
        names = archive.namelist()
        bundles = sorted({match.group(1) for name in names if (match := APP_PATTERN.match(name))})
        profiles = {match.group(1): name for name in names if (match := BUNDLE_PATTERN.match(name))}
        if not bundles:
            fail(f"{ipa_path} contains no app bundle")
            return 1

        problems = 0
        device_counts = []
        for bundle in bundles:
            label = bundle.replace("Payload/", "")
            entry = profiles.get(bundle)
            if entry is None:
                fail(f"{label} has no embedded.mobileprovision")
                problems += 1
                continue
            try:
                profile = decode_profile(archive.read(entry))
            except (ValueError, plistlib.InvalidFileException) as error:
                fail(f"{label}: {error}")
                problems += 1
                continue

            entitlements = profile.get("Entitlements", {})
            devices = profile.get("ProvisionedDevices", [])
            debuggable = bool(entitlements.get("get-task-allow", False))
            all_devices = bool(profile.get("ProvisionsAllDevices", False))
            kind = "Ad Hoc"
            if all_devices:
                kind = "Enterprise"
            elif debuggable:
                kind = "Development"
            elif not devices:
                kind = "App Store"

            print(f"{label}")
            print(f"  profile:    {profile.get('Name', '?')} ({profile.get('UUID', '?')})")
            print(f"  type:       {kind}")
            print(f"  app id:     {entitlements.get('application-identifier', '?')}")
            print(f"  team:       {profile.get('TeamName', '?')} ({', '.join(profile.get('TeamIdentifier', []))})")
            print(f"  expires:    {profile.get('ExpirationDate', '?')}")
            print(f"  devices:    {len(devices)}")
            if kind != "Ad Hoc":
                fail(f"{label} is signed with a {kind} profile, expected Ad Hoc")
                problems += 1
            else:
                device_counts.append(len(devices))

    if problems:
        return 1
    count = min(device_counts)
    print(f"All {len(bundles)} bundles embed Ad Hoc profiles; the build installs on {count} registered device(s).")
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as handle:
            handle.write(f"device_count={count}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
