#!/usr/bin/env python3
"""Install a pinned, checksum-verified PowerShell for cloud script checks only.

Windows users can run the project scripts with built-in PowerShell 5.1.
This Linux helper neither activates Unity nor exports a game.
"""
import argparse
import hashlib
import pathlib
import tarfile
import urllib.request

VERSION = '7.6.7'
ARCHIVE = 'powershell-' + VERSION + '-linux-x64.tar.gz'
SOURCE = 'https://github.com/PowerShell/PowerShell/releases/download/v' + VERSION + '/' + ARCHIVE
SHA256 = '6896f9e3a6b0a354bf470835a96da76d2f801cd50dcf047ad7c4563bf93bf431'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--destination', type=pathlib.Path,
                        default=pathlib.Path('/workspace/.cache/cosmic-unity/powershell'))
    args = parser.parse_args()
    destination = args.destination
    record = destination / 'runtime-source.txt'
    if (destination / 'pwsh').is_file() and record.is_file() and SHA256 in record.read_text():
        print('PASS cached official PowerShell ' + VERSION + ': ' + str(destination / 'pwsh'))
        return
    destination.mkdir(parents=True, exist_ok=True)
    archive = destination / ARCHIVE
    urllib.request.urlretrieve(SOURCE, archive)
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    if checksum != SHA256:
        archive.unlink()
        raise SystemExit('PowerShell archive does not match official release SHA256.')
    with tarfile.open(archive) as contents:
        contents.extractall(destination, filter='data')
    (destination / 'pwsh').chmod(0o755)
    record.write_text('Official PowerShell v' + VERSION + ' linux-x64\nURL: ' + SOURCE
                      + '\nSHA256: ' + checksum + '\nVerified against official hashes.sha256\n')
    archive.unlink()
    print('PASS installed official PowerShell ' + VERSION + ', SHA256 ' + checksum)


if __name__ == '__main__':
    main()
