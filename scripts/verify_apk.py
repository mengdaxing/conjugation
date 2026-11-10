#!/usr/bin/env python3
"""Verify that the deliverable contains native Swift code and the offline lexicon."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('apk', type=Path)
args = parser.parse_args()
sdk = Path(os.environ.get('ANDROID_HOME', '/opt/homebrew/share/android-commandlinetools'))
build_tools = sorted((sdk / 'build-tools').iterdir(), key=lambda path: tuple(map(int, re.findall(r'\d+', path.name))))
badging = subprocess.check_output([str(build_tools[-1] / 'aapt2'), 'dump', 'badging', str(args.apk)], text=True)
assert re.search(r"package: name='com.personal.frenchconjugation' versionCode='7' versionName='1.0.0'", badging), 'Wrong package or build version'
assert "application-label:'MyConju'" in badging, 'Wrong launcher name'
with zipfile.ZipFile(args.apk) as archive:
    assert archive.testzip() is None, 'ZIP CRC failure'
    names = archive.namelist()
    assert 'AndroidManifest.xml' in names, 'Missing Android manifest'
    native = [name for name in names if name.startswith('lib/') and name.endswith('.so')]
    assert native and all(name.startswith('lib/arm64-v8a/') for name in native), 'Expected arm64 native libraries'
    assert any('Conjugation' in name for name in native), 'Missing compiled Swift application module'
    assert any('swiftCore' in name for name in native), 'Missing Swift runtime'
    for name in native:
        with archive.open(name) as library:
            header = library.read(64)
            offset = struct.unpack_from('<Q', header, 32)[0]
            entry_size, entry_count = struct.unpack_from('<HH', header, 54)
            library.seek(offset)
            program_headers = library.read(entry_size * entry_count)
        assert header[:4] == b'\x7fELF' and header[4] == 2 and struct.unpack('<H', header[18:20])[0] == 183, f'Wrong native architecture: {name}'
        alignments = [struct.unpack_from('<Q', program_headers, i * entry_size + 48)[0]
                      for i in range(entry_count) if struct.unpack_from('<I', program_headers, i * entry_size)[0] == 1]
        assert alignments and min(alignments) >= 16384, f'Native library lacks 16 KB page alignment: {name}'
    lexicons = [name for name in names if name.endswith('/verbs.json')]
    assert len(lexicons) == 1, f'Expected one lexicon, got {lexicons}'
    verbs = json.loads(archive.read(lexicons[0]))
    assert len(verbs) == len({verb['id'] for verb in verbs}) == 776, 'Wrong lexicon size'
    assert all(len(verb['forms']) == 16 and all(len(slots) == 6 for slots in verb['forms'].values()) for verb in verbs), 'Incomplete conjugation slots'
    assert any(name.endswith('/LICENSE.txt') for name in names), 'Missing project license'
    assert any(name.endswith('/MaterialIcons-LICENSE.txt') for name in names), 'Missing icon license'
print(f'{args.apk}: OK — MyConju / build 7 / {len(native)} arm64 libraries (16 KB aligned), 776 verbs, 16 tenses, ZIP CRC verified')
print(f'SHA-256: {hashlib.file_digest(args.apk.open("rb"), "sha256").hexdigest()}')
