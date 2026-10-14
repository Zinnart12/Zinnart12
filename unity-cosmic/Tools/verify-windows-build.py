#!/usr/bin/env python3
"""Verify a completed Cosmic Sandbox Windows export without launching it.

Checks x64 PE binaries, complete Mono/data files, the successful-build manifest,
SHA-256 hashes and (when supplied) every packaged ZIP entry. This is an artifact
integrity check, not proof of game startup, visual quality or frame rate.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct
import zipfile

PRODUCT_DIRECTORY = 'CosmicSandboxBuild'
NATIVE_FILES = (
    'CosmicSandbox.exe', 'UnityPlayer.dll', 'UnityCrashHandler64.exe',
    'MonoBleedingEdge/EmbedRuntime/mono-2.0-bdwgc.dll',
)
DATA_FILES = (
    'CosmicSandbox_Data/globalgamemanagers', 'CosmicSandbox_Data/boot.config',
    'CosmicSandbox_Data/Managed/Cosmic.Core.dll', 'CosmicSandbox_Data/Managed/Cosmic.Runtime.dll',
    'CosmicSandbox_Data/StreamingAssets/PresetCatalog.json',
)


def sha256(stream):
    digest = hashlib.sha256()
    while chunk := stream.read(1024 * 1024):
        digest.update(chunk)
    return digest.hexdigest()


def verify_pe(path):
    if not path.is_file() or path.stat().st_size < 256:
        raise ValueError('Missing/truncated Windows binary: ' + str(path))
    with path.open('rb') as stream:
        if stream.read(2) != b'MZ':
            raise ValueError('Not a Windows PE binary: ' + str(path))
        stream.seek(0x3c)
        offset, = struct.unpack('<I', stream.read(4))
        if not 64 <= offset <= path.stat().st_size - 26:
            raise ValueError('Invalid PE header offset: ' + str(path))
        stream.seek(offset)
        signature, machine = struct.unpack('<IH', stream.read(6))
        stream.seek(offset + 24)
        magic, = struct.unpack('<H', stream.read(2))
        if signature != 0x4550 or machine != 0x8664 or magic != 0x20b:
            raise ValueError('Not an x64 PE32+ binary: ' + str(path))


def verify_manifest(manifest):
    expected = {'unityVersion': '6000.6.5f1', 'buildTarget': 'StandaloneWindows64',
                'backend': 'Mono', 'graphicsApi': 'Direct3D11', 'buildErrors': 0,
                'scenes': ['Assets/Scenes/MainMenu.unity', 'Assets/Scenes/SolarSystem.unity']}
    for key, value in expected.items():
        if manifest.get(key) != value:
            raise ValueError('Incorrect build configuration: ' + key)
    records = manifest.get('files')
    if not isinstance(records, list) or not records:
        raise ValueError('Build manifest has no file records.')
    seen = set()
    for entry in records:
        if not isinstance(entry, dict):
            raise ValueError('Invalid manifest file record.')
        name = entry.get('path')
        if not isinstance(name, str) or not name or '\\' in name or ':' in name:
            raise ValueError('Invalid manifest path.')
        path = PurePosixPath(name)
        if path.is_absolute() or '..' in path.parts or path.as_posix() != name or name.casefold() in seen:
            raise ValueError('Unsafe or duplicate manifest path: ' + name)
        if name == 'build-manifest.json':
            raise ValueError('The manifest cannot hash itself.')
        seen.add(name.casefold())
        if type(entry.get('bytes')) is not int or entry['bytes'] < 0:
            raise ValueError('Invalid manifest file size: ' + name)
        if not re.fullmatch('[a-f0-9]{64}', entry.get('sha256', '')):
            raise ValueError('Invalid manifest file hash: ' + name)
    return records


def verify_files(directory, records):
    expected = {entry['path'] for entry in records}
    actual = {path.relative_to(directory).as_posix() for path in directory.rglob('*') if path.is_file()}
    if actual != expected | {'build-manifest.json'}:
        raise ValueError('Build directory and manifest file lists differ.')
    for entry in records:
        path = directory / entry['path']
        if path.is_symlink() or not path.is_file() or path.stat().st_size != entry['bytes']:
            raise ValueError('Missing/truncated/linked build file: ' + entry['path'])
        with path.open('rb') as stream:
            if sha256(stream) != entry['sha256']:
                raise ValueError('Build file hash mismatch: ' + entry['path'])


def verify_archive(archive_path, directory):
    expected = {PRODUCT_DIRECTORY + '/' + path.relative_to(directory).as_posix(): path
                for path in directory.rglob('*') if path.is_file()}
    with zipfile.ZipFile(archive_path) as archive:
        files = [entry for entry in archive.infolist() if not entry.is_dir()]
        names = [entry.filename for entry in files]
        if len(names) != len(set(name.casefold() for name in names)) or set(names) != set(expected):
            raise ValueError('ZIP is incomplete or contains unexpected/duplicate files.')
        for entry in files:
            path = expected[entry.filename]
            if entry.file_size != path.stat().st_size:
                raise ValueError('ZIP file size mismatch: ' + entry.filename)
            with archive.open(entry) as packed, path.open('rb') as original:
                if sha256(packed) != sha256(original):
                    raise ValueError('ZIP file hash mismatch: ' + entry.filename)


def verify_build(directory, archive=None):
    if not directory.is_dir():
        raise ValueError('No completed Windows build directory: ' + str(directory))
    manifest_path = directory / 'build-manifest.json'
    if not manifest_path.is_file() or manifest_path.is_symlink():
        raise ValueError('No successful-build manifest: ' + str(manifest_path))
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    records = verify_manifest(manifest)
    verify_files(directory, records)
    for name in NATIVE_FILES:
        verify_pe(directory / name)
    for name in DATA_FILES:
        path = directory / name
        if not path.is_file() or path.stat().st_size == 0:
            raise ValueError('Required Windows player data missing: ' + name)
    if archive is not None:
        verify_archive(archive, directory)
    return len(records)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path, nargs='?', default=Path(__file__).resolve().parents[1] / PRODUCT_DIRECTORY)
    parser.add_argument('--archive', type=Path)
    args = parser.parse_args()
    try:
        count = verify_build(args.directory, args.archive)
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile) as error:
        raise SystemExit('FAIL Windows build verification: ' + str(error)) from error
    print('PASS complete x64 Mono / DX11 Windows artifact: ' + str(count) + ' hashed files. Startup/visual/performance tests are separate.')


if __name__ == '__main__':
    main()
