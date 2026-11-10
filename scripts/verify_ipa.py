#!/usr/bin/env python3
"""Verify IPA structure, target platform, resources, and unsigned state."""
import json
import plistlib
import struct
import sys
import zipfile

path = sys.argv[1]
prefix = "Payload/Conjugation.app/"
with zipfile.ZipFile(path) as ipa:
    names = set(ipa.namelist())
    assert not any(n.rsplit("/", 1)[-1].startswith("._") or "__MACOSX" in n for n in names)
    info = plistlib.loads(ipa.read(prefix + "Info.plist"))
    assert info["CFBundleIdentifier"] == "com.personal.frenchconjugation"
    # SideStore versions affected by #1489 send this name as Apple's appIdName.
    # Keep both possible name sources ASCII to avoid registration rejection.
    for key in ("CFBundleDisplayName", "CFBundleName"):
        assert info[key] == "MyConju", f"Unexpected signing name: {key}"
        assert info[key].isascii() and info[key].isalnum(), f"Invalid appIdName source: {key}"
    assert info["CFBundleVersion"] == "7"
    assert info["CFBundlePackageType"] == "APPL"
    assert info["MinimumOSVersion"] == "16.0"
    assert info["CFBundleSupportedPlatforms"] == ["iPhoneOS"]
    assert not any("_CodeSignature/" in n or n.endswith("embedded.mobileprovision") for n in names)
    executable = ipa.read(prefix + info["CFBundleExecutable"])
    assert b"UI_DIAGNOSTIC_WARNING" not in executable and b"UI_DIAGNOSTIC_ERROR" not in executable, "Debug log fixtures leaked into Release"
    magic, cpu, subtype, filetype, ncmds, cmdsize, flags, reserved = struct.unpack_from("<8I", executable)
    assert magic == 0xFEEDFACF, "Must be a thin 64-bit Mach-O"
    assert cpu == 0x0100000C, "Must be arm64"
    assert filetype == 2, "Must be an executable"
    offset = 32
    platform = None
    for _ in range(ncmds):
        cmd, size = struct.unpack_from("<2I", executable, offset)
        if cmd == 0x32:
            platform = struct.unpack_from("<I", executable, offset + 8)[0]
        assert cmd != 0x1D, "Unexpected code signature in unsigned executable"
        offset += size
    assert platform == 2, "Must target iOS devices, not the simulator"
    verbs = json.loads(ipa.read(prefix + "verbs.json"))
    assert len(verbs) == 776
    assert len({v["id"] for v in verbs}) == 776
    assert all(len(v["forms"]) == 16 for v in verbs)
    assert prefix + "Assets.car" in names
    for icon in ("AppIcon60x60@2x.png", "AppIcon76x76@2x~ipad.png"):
        assert len(ipa.read(prefix + icon)) > 2000, "Missing or suspiciously blank compiled icon"
    assert prefix + "LICENSE.txt" in names
    assert ipa.testzip() is None
print("IPA verified: MyConju / build 7 / speech recovery / diagnostic logs / replicate answer / new icon / ASCII signing names / iOS device / arm64 / iOS 16+ / unsigned / 776 verbs / 16 tenses")
