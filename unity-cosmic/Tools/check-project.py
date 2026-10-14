#!/usr/bin/env python3
"""Check serialized component GUIDs and asmdef/package names against Unity 6."""
import json
import os
import pathlib
import re

root = pathlib.Path(__file__).resolve().parents[1]
editor = pathlib.Path(os.environ.get('COSMIC_UNITY_EDITOR_ROOT', '/workspace/.cache/cosmic-unity/unity/Editor'))
packages = editor / 'Data/Resources/PackageManager/BuiltInPackages'
known = {}
for base in [root / 'Assets', packages]:
    for path in base.rglob('*.asmdef'):
        data = json.loads(path.read_text(encoding='utf-8-sig'))
        known[data['name']] = path
for path in sorted((root / 'Assets').rglob('*.asmdef')):
    for name in json.loads(path.read_text())['references']:
        if name not in known:
            raise RuntimeError('Unknown assembly reference: ' + name + ' in ' + str(path))
    print('PASS asmdef dependency names:', path.relative_to(root))
for name, version in json.loads((root / 'Packages/manifest.json').read_text())['dependencies'].items():
    data = json.loads((packages / name / 'package.json').read_text(encoding='utf-8-sig'))
    if data['version'] != version:
        raise RuntimeError('Package version differs from the chosen official Editor: ' + name)
print('PASS every direct dependency matches bundled Unity 6000.0.65f1 packages')
guids = {}
for meta in sorted((root / 'Assets').rglob('*.meta')):
    guid = re.search(r'^guid: (\w+)', meta.read_text(), re.M).group(1)
    if guid in guids:
        raise RuntimeError('Duplicate Unity GUID: ' + guid)
    asset = pathlib.Path(str(meta)[:-5])
    if not asset.exists():
        raise RuntimeError('Orphaned metadata: ' + str(meta))
    guids[guid] = asset
for path in list((root / 'Assets').rglob('*.unity')) + list((root / 'Assets').rglob('*.prefab')):
    for guid in re.findall(r'guid: (\w+)', path.read_text()):
        if guid not in guids or guids[guid].suffix != '.cs':
            raise RuntimeError('Missing component script: ' + str(path))
    print('PASS serialized component script references:', path.relative_to(root))
print('NOTE: static checks do not replace Unity scene import/PlayMode.')
