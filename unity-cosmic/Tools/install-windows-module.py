#!/usr/bin/env python3
"""Install the official, checksum-verified Unity 6.6 Windows Mono module on Linux.

This installs build support only. It never activates Unity or creates a player.
Unity's Linux release manifest supplies a PKG container; only its validated
WindowsStandaloneSupport payload is extracted, without running installer scripts.
"""
import argparse
import base64
import gzip
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import stat
import struct
import tempfile
import urllib.request
import xml.etree.ElementTree as ET
import zlib

VERSION = '6000.6.5f1'
RELEASE_API = 'https://services.api.unity.com/unity/editor/release/v1/releases?version=' + VERSION + '&limit=1'


def read_exact(stream, length):
    value = stream.read(length)
    if len(value) != length:
        raise ValueError('Truncated official installer payload.')
    return value


class LimitedPayload:
    """Keep gzip from reading the next XAR member after its own footer."""
    def __init__(self, stream, length):
        self.stream = stream
        self.remaining = length

    def read(self, size=-1):
        count = self.remaining if size < 0 else min(size, self.remaining)
        value = self.stream.read(count)
        self.remaining -= len(value)
        return value


def extract_payload(package, destination):
    with package.open('rb') as archive:
        magic, header_size, version, toc_size, _, _ = struct.unpack('>IHHQQI', read_exact(archive, 28))
        if magic != 0x78617221 or version != 1 or header_size != 28 or toc_size > 1024 * 1024:
            raise ValueError('Unsupported Unity installer XAR header.')
        toc = ET.fromstring(zlib.decompress(read_exact(archive, toc_size)))
        payloads = [entry for entry in toc.iter('file') if entry.findtext('name') == 'Payload']
        if len(payloads) != 1:
            raise ValueError('Expected one Windows Mono payload.')
        offset = header_size + toc_size + int(payloads[0].findtext('data/offset'))
        length = int(payloads[0].findtext('data/length'))
        if offset < header_size + toc_size or length <= 0 or offset + length > package.stat().st_size:
            raise ValueError('Invalid installer payload bounds.')
        archive.seek(offset)
        count = 0
        with gzip.GzipFile(fileobj=LimitedPayload(archive, length)) as payload:
            while True:
                header = read_exact(payload, 76)
                if header[:6] != b'070707':
                    raise ValueError('Unsupported Unity installer CPIO format.')
                mode = int(header[18:24], 8)
                name_size = int(header[59:65], 8)
                size = int(header[65:76], 8)
                if not 0 < name_size < 4096:
                    raise ValueError('Invalid installer entry name.')
                raw_name = read_exact(payload, name_size)
                if raw_name[-1:] != b'\0':
                    raise ValueError('Invalid installer entry terminator.')
                name = raw_name[:-1].decode('utf-8')
                if name == 'TRAILER!!!':
                    # Read through the gzip footer to verify its CRC as well.
                    while payload.read(1024 * 1024):
                        pass
                    break
                relative = PurePosixPath(name)
                if relative.is_absolute() or '..' in relative.parts or '\\' in name:
                    raise ValueError('Unsafe installer entry: ' + name)
                target = destination.joinpath(*relative.parts)
                if stat.S_ISDIR(mode):
                    if size != 0:
                        raise ValueError('Invalid installer directory.')
                    target.mkdir(parents=True, exist_ok=True)
                elif stat.S_ISREG(mode):
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with target.open('wb') as output:
                        remaining = size
                        while remaining:
                            chunk = read_exact(payload, min(remaining, 1024 * 1024))
                            output.write(chunk)
                            remaining -= len(chunk)
                    target.chmod(mode & 0o777)
                    count += 1
                else:
                    raise ValueError('Installer links/devices are not supported: ' + name)
        return count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--editor-root', type=Path, default=Path('/workspace/.cache/cosmic-unity/unity66/Editor'))
    parser.add_argument('--cache', type=Path, default=Path('/workspace/.cache/cosmic-unity'))
    args = parser.parse_args()
    if not (args.editor_root / 'Unity').is_file():
        raise SystemExit('Install the official Linux Unity ' + VERSION + ' Editor first.')
    args.cache.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(RELEASE_API, timeout=60) as response:
        releases = json.load(response)['results']
    release = next(item for item in releases if item['version'] == VERSION)
    editor = next(item for item in release['downloads'] if item['platform'] == 'LINUX' and item['architecture'] == 'X86_64')
    module = next(item for item in editor['modules'] if item['id'] == 'windows-mono')
    if not module['url'].startswith('https://download.unity3d.com/') or module['type'] != 'PKG':
        raise RuntimeError('Unexpected official Windows Mono download.')
    algorithm, encoded = module['integrity'].split('-', 1)
    raw = base64.b64decode(encoded)
    expected = raw.hex() if len(raw) == 16 else raw.decode('ascii')
    if algorithm != 'md5' or len(expected) != 32:
        raise RuntimeError('Unexpected official Unity module integrity format.')
    destination = args.editor_root / 'Data/PlaybackEngines/WindowsStandaloneSupport'
    marker = destination / 'cosmic-official-module.json'
    required = ['UnityEditor.WindowsStandalone.Extensions.dll', 'Variations/win64_player_nondevelopment_mono/UnityPlayer.dll']
    if marker.exists() and all((destination / item).is_file() for item in required):
        installed = json.loads(marker.read_text())
        if installed.get('version') == VERSION and installed.get('md5') == expected:
            print('Verified official Windows Mono module is already installed: ' + str(destination))
            return
    if destination.exists():
        raise SystemExit('Existing Windows support is not marked by this installer. Use Unity Hub or inspect it before replacement: ' + str(destination))
    package = args.cache / 'windows-mono66.pkg'
    if not package.is_file():
        print('Downloading official Windows Mono module (' + str(module['downloadSize']['value']) + ' bytes)', flush=True)
        with urllib.request.urlopen(module['url'], timeout=60) as response, package.open('wb') as output:
            shutil.copyfileobj(response, output, 4 * 1024 * 1024)
    digest = hashlib.md5()
    with package.open('rb') as downloaded:
        while chunk := downloaded.read(4 * 1024 * 1024):
            digest.update(chunk)
    if package.stat().st_size != module['downloadSize']['value'] or digest.hexdigest() != expected:
        package.unlink()
        raise RuntimeError('Official Windows Mono checksum/size mismatch; installer removed.')
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='cosmic-win-mono-', dir=destination.parent) as staging:
        staging_path = Path(staging) / 'WindowsStandaloneSupport'
        staging_path.mkdir()
        count = extract_payload(package, staging_path)
        for item in required:
            if not (staging_path / item).is_file():
                raise RuntimeError('Official module required file missing: ' + item)
        manifest = {'version': VERSION, 'module': module['id'], 'url': module['url'], 'md5': expected,
                    'download_bytes': package.stat().st_size, 'files': count}
        (staging_path / marker.name).write_text(json.dumps(manifest, indent=2) + '\n')
        staging_path.rename(destination)
    package.unlink()
    print('Verified and installed ' + str(count) + ' official Windows Mono files: ' + str(destination))


if __name__ == '__main__':
    main()
