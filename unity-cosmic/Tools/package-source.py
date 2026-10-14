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
paths += [root / name for name in ['README.md', 'VALIDATION.md', '.gitignore', 'APPLY_REPAIR.cmd', 'AGENTS.md']]
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as package:
    for path in sorted(paths):
        package.write(path, 'CosmicSandboxUnity/' + path.relative_to(root).as_posix())
with zipfile.ZipFile(archive) as package:
    if package.testzip() is not None:
        raise RuntimeError('Source ZIP integrity failure.')
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
hotfix = release / 'cosmic-unity66-safe-mode-fix.zip'
with zipfile.ZipFile(hotfix, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as package:
    # Preserve additional user packages: APPLY_REPAIR merges module/URP pins into
    # their manifest instead of replacing it with the repository's manifest.
    for relative in ['AGENTS.md', 'APPLY_REPAIR.cmd',
                     'ProjectSettings/TagManager.asset',
                     'Assets/Cosmic/Editor/Cosmic.Editor.asmdef',
                     'Assets/Cosmic/Editor/MaterialRepair.cs',
                     'Assets/Cosmic/Editor/ProjectBuilder.cs',
                     'Assets/Cosmic/Editor/WindowsBuild.cs',
                     'Assets/Cosmic/Runtime/CosmicBootstrap.cs',
                     'Assets/Cosmic/Runtime/SpaceCameraController.cs',
                     'Assets/Cosmic/Settings/PC_RPAsset.asset',
                     'Assets/Tests/PlayMode/Cosmic.PlayModeTests.asmdef',
                     'Assets/Tests/PlayMode/PhaseOneSceneTests.cs',
                     'Assets/Tests/EditMode/Cosmic.EditModeTests.asmdef',
                     'Tools/repair-urp.ps1',
                     'Tools/build-windows.ps1',
                     'Tools/test-unity.ps1',
                     'Tools/verify-windows-build.py',
                     'Docs/WINDOWS_BUILD.md']:
        package.write(root / relative, relative)
with zipfile.ZipFile(hotfix) as package:
    if package.testzip() is not None:
        raise RuntimeError('Safe Mode hotfix ZIP integrity failure.')
hotfix_checksum = hashlib.sha256(hotfix.read_bytes()).hexdigest()
(release / 'SHA256SUMS.txt').write_text(checksum + '  ' + archive.name + '\n' +
                                      hotfix_checksum + '  ' + hotfix.name + '\n')
print(archive.name, archive.stat().st_size, 'bytes; SHA256', checksum)
print(hotfix.name, hotfix.stat().st_size, 'bytes; SHA256', hotfix_checksum)
