#!/usr/bin/env python3
"""Package the shared sources and Android project, excluding private signing keys."""
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
output = root / 'dist/MyConju-Android-source.zip'
directories = ['Sources', 'Conjugation', 'Conjugation.xcodeproj', 'Project.xcworkspace',
               'Android', 'Darwin', 'Tests', 'scripts', 'vendor', 'Design', 'docs/android']
files = ['Package.swift', 'Package.resolved', 'Skip.env', '.swift-version', '.gitignore', 'README.md', 'LICENSE']
excluded = {'build', '.build', '.gradle', '.kotlin', '.swiftpm', 'xcuserdata', '__pycache__'}
private = {'keystore.jks', 'keystore.properties', 'local.properties', '.DS_Store'}
paths = {root / name for name in files}
for name in directories:
    paths.update((root / name).rglob('*'))
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for path in sorted(paths):
        relative = path.relative_to(root)
        if path.is_symlink() or not path.is_file() or excluded.intersection(relative.parts) or path.name in private:
            continue
        archive.write(path, 'MyConju/' + relative.as_posix())
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    assert not any(Path(name).name in private for name in archive.namelist())
    assert 'MyConju/Sources/Conjugation/Models/Lexicon.swift' in archive.namelist()
    print(f'{output}: {len(archive.namelist())} files, {output.stat().st_size / 1e6:.1f} MB, CRC verified')
