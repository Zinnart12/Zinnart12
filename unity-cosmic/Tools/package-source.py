#!/usr/bin/env python3
"""Package Unity source only; no Editor binaries, cache, license or claimed EXE."""
import hashlib
import pathlib
import zipfile

root = pathlib.Path(__file__).resolve().parents[1]
release = root / 'Releases'
release.mkdir(exist_ok=True)
archive = release / 'cosmic-unity-phase1-source.zip'
paths = []
for folder in ['Assets', 'Packages', 'ProjectSettings', 'Docs', 'Tools']:
    for path in (root / folder).rglob('*'):
        if path.is_file() and not any(part in {'bin', 'obj', '__pycache__'} for part in path.parts):
            paths.append(path)
paths += [root / name for name in ['README.md', 'VALIDATION.md', '.gitignore']]
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as package:
    for path in sorted(paths):
        package.write(path, 'CosmicSandboxUnity/' + path.relative_to(root).as_posix())
with zipfile.ZipFile(archive) as package:
    if package.testzip() is not None:
        raise RuntimeError('Source ZIP integrity failure.')
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
(release / 'SHA256SUMS.txt').write_text(checksum + '  ' + archive.name + '\n')
print(archive.name, archive.stat().st_size, 'bytes; SHA256', checksum)
