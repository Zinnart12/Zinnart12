#!/usr/bin/env python3
"""Regression checks for build rejection; temporary fixtures are not game builds."""
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
import zipfile

SPEC = importlib.util.spec_from_file_location('cosmic_build_verifier', Path(__file__).with_name('verify-windows-build.py'))
VERIFY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFY)


def manifest(records):
    return {'unityVersion': '6000.6.5f1', 'buildTarget': 'StandaloneWindows64', 'backend': 'Mono',
            'graphicsApi': 'Direct3D11', 'buildErrors': 0,
            'scenes': ['Assets/Scenes/MainMenu.unity', 'Assets/Scenes/SolarSystem.unity'], 'files': records}


def record(name='fixture.txt', content=b'fixture'):
    return {'path': name, 'bytes': len(content), 'sha256': hashlib.sha256(content).hexdigest()}


class RejectionTests(unittest.TestCase):
    def test_missing_build_cannot_pass(self):
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaisesRegex(ValueError, 'No completed'):
                VERIFY.verify_build(Path(temporary) / 'absent')
            with self.assertRaisesRegex(ValueError, 'No successful-build manifest'):
                VERIFY.verify_build(Path(temporary))

    def test_wrong_backend_and_scene_order_fail(self):
        for key, value in [('backend', 'IL2CPP'), ('scenes', ['Assets/Scenes/SolarSystem.unity']), ('buildErrors', 1)]:
            value_manifest = manifest([record()])
            value_manifest[key] = value
            with self.assertRaisesRegex(ValueError, 'Incorrect build configuration'):
                VERIFY.verify_manifest(value_manifest)

    def test_traversal_and_windows_path_aliases_fail(self):
        for path in ['../secret', '/outside', 'C:/outside', 'folder\\alias', 'folder//alias', 'folder/./alias']:
            with self.assertRaises(ValueError):
                VERIFY.verify_manifest(manifest([record(path)]))

    def test_duplicate_case_insensitive_names_fail(self):
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            VERIFY.verify_manifest(manifest([record('Dll.dll'), record('dll.dll')]))

    def test_modified_and_unrecorded_data_fail(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'build-manifest.json').write_text('{}')
            (root / 'fixture.txt').write_bytes(b'changed')
            with self.assertRaisesRegex(ValueError, 'hash mismatch'):
                VERIFY.verify_files(root, [record()])
            (root / 'fixture.txt').write_bytes(b'fixture')
            (root / 'unexpected.txt').write_text('extra')
            with self.assertRaisesRegex(ValueError, 'file lists differ'):
                VERIFY.verify_files(root, [record()])

    def test_empty_optional_file_is_hashed_and_negative_size_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            records = [record('optional-empty.txt', b'')]
            (root / 'build-manifest.json').write_text(json.dumps(manifest(records)))
            (root / 'optional-empty.txt').write_bytes(b'')
            VERIFY.verify_files(root, VERIFY.verify_manifest(manifest(records)))
            (root / 'optional-empty.txt').write_bytes(b'x')
            with self.assertRaisesRegex(ValueError, 'truncated'):
                VERIFY.verify_files(root, records)
            records[0]['bytes'] = -1
            with self.assertRaisesRegex(ValueError, 'file size'):
                VERIFY.verify_manifest(manifest(records))

    def test_incomplete_or_changed_zip_fails(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'folder'
            root.mkdir()
            (root / 'fixture.txt').write_bytes(b'fixture')
            archive = Path(temporary) / 'test.zip'
            for packed in [None, b'changed']:
                with zipfile.ZipFile(archive, 'w') as output:
                    if packed is not None:
                        output.writestr('CosmicSandboxBuild/fixture.txt', packed)
                with self.assertRaises(ValueError):
                    VERIFY.verify_archive(archive, root)

    def test_wrong_pe_architecture_and_truncation_fail(self):
        # Synthetic header only for rejection testing; never exported or released.
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'header.fixture'
            path.write_bytes(b'MZ')
            with self.assertRaisesRegex(ValueError, 'truncated'):
                VERIFY.verify_pe(path)
            data = bytearray(512)
            data[:2] = b'MZ'
            struct.pack_into('<I', data, 0x3c, 128)
            struct.pack_into('<IH', data, 128, 0x4550, 0x14c)
            struct.pack_into('<H', data, 152, 0x10b)
            path.write_bytes(data)
            with self.assertRaisesRegex(ValueError, 'x64'):
                VERIFY.verify_pe(path)


if __name__ == '__main__':
    unittest.main()
