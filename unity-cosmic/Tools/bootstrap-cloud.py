#!/usr/bin/env python3
"""Install official, verified developer tools into a writable cloud cache.

Does not activate Unity, create accounts, accept account credentials or build an EXE.
Only downloads/extracts the Editor, .NET SDK and DXC when their binaries are absent.
"""
import argparse
import base64
import hashlib
import json
import pathlib
import tarfile
import urllib.request

CACHE = pathlib.Path('/workspace/.cache/cosmic-unity')


def metadata(url):
    with urllib.request.urlopen(url, timeout=60) as response:
        return json.load(response)


def install(url, directory, algorithm, expected):
    archive = CACHE / (directory + '.download')
    digest = hashlib.new(algorithm)
    print('Downloading official ' + directory, flush=True)
    with urllib.request.urlopen(url, timeout=60) as response, archive.open('wb') as file:
        while chunk := response.read(4 * 1024 * 1024):
            digest.update(chunk)
            file.write(chunk)
    if digest.hexdigest() != expected:
        archive.unlink()
        raise RuntimeError('Official checksum mismatch for ' + directory)
    destination = CACHE / directory
    destination.mkdir(exist_ok=True)
    # Python 3.12+ extraction protects against archive path traversal.
    with tarfile.open(archive) as package:
        package.extractall(destination, filter='data')
    archive.unlink()
    print('Verified and extracted ' + directory, flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--core-only', action='store_true', help='Skip Unity Editor and DXC downloads.')
    args = parser.parse_args()
    CACHE.mkdir(parents=True, exist_ok=True)
    if not (CACHE / 'dotnet/dotnet').exists():
        releases = metadata('https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/8.0/releases.json')
        release = next(r for r in releases['releases'] if r['sdk']['version'] == '8.0.426')
        file = next(f for f in release['sdk']['files'] if f['rid'] == 'linux-x64' and f['name'].endswith('.tar.gz'))
        install(file['url'], 'dotnet', 'sha512', file['hash'])
    if args.core_only:
        return
    if not (CACHE / 'unity66/Editor/Unity').exists():
        release = metadata('https://services.api.unity.com/unity/editor/release/v1/releases?version=6000.6.5f1&limit=1')['results'][0]
        file = next(f for f in release['downloads'] if f['platform'] == 'LINUX' and f['architecture'] == 'X86_64')
        raw = base64.b64decode(file['integrity'].split('-', 1)[1])
        expected = raw.hex() if len(raw) == 16 else raw.decode()
        install(file['url'], 'unity66', 'md5', expected)
    if not (CACHE / 'dxc/bin/dxc').exists():
        release = metadata('https://api.github.com/repos/microsoft/DirectXShaderCompiler/releases/tags/v1.9.2609')
        file = next(f for f in release['assets'] if f['name'].startswith('linux_dxc'))
        install(file['browser_download_url'], 'dxc', 'sha256', file['digest'].split(':')[1])


if __name__ == '__main__':
    main()
