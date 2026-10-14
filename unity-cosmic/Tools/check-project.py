#!/usr/bin/env python3
"""Check serialized component GUIDs and asmdef/package names against Unity 6."""
import json
import os
import pathlib
import re
import subprocess
import sys

from unity_reference_model import UnityReferenceModel

root = pathlib.Path(__file__).resolve().parents[1]
subprocess.run([sys.executable, str(root / 'Tools/check-import-config.py')], check=True)
editor = pathlib.Path(os.environ.get('COSMIC_UNITY_EDITOR_ROOT', '/workspace/.cache/cosmic-unity/unity66/Editor'))
packages = editor / 'Data/Resources/PackageManager/BuiltInPackages'
model = UnityReferenceModel(root, editor)
model.validate_asset_references()
for path in sorted((root / 'Assets').rglob('*.asmdef')):
    print('PASS asmdef dependency names:', path.relative_to(root))
source = '\n'.join(path.read_text() for path in (root / 'Assets').rglob('*.cs'))
if re.search(r'\bScreenCapture\s*\.', source) and 'com.unity.modules.screencapture' not in model.enabled_packages:
    raise RuntimeError('ScreenCapture requires com.unity.modules.screencapture in the enabled dependency graph.')
print('PASS project APIs and asmdef references use enabled module/package graph')
for name, version in json.loads((root / 'Packages/manifest.json').read_text())['dependencies'].items():
    data = json.loads((packages / name / 'package.json').read_text(encoding='utf-8-sig'))
    if data['version'] != version:
        raise RuntimeError('Package version differs from the chosen official Editor: ' + name)
print('PASS every direct dependency matches bundled Unity 6000.6.5f1 packages')
guids = {}
for meta in sorted((root / 'Assets').rglob('*.meta')):
    guid = re.search(r'^guid: (\w+)', meta.read_text(), re.M).group(1)
    if guid in guids:
        raise RuntimeError('Duplicate Unity GUID: ' + guid)
    asset = pathlib.Path(str(meta)[:-5])
    if not asset.exists():
        raise RuntimeError('Orphaned metadata: ' + str(meta))
    guids[guid] = asset
# Native material/pipeline/mesh references may target bundled package resources.
package_guids = set()
for package in model.enabled_packages:
 for meta in (packages / package).rglob('*.meta'):
    match = re.search(r'^guid: (\w+)', meta.read_text(errors='replace'), re.M)
    if match:
        package_guids.add(match[1])
for suffix in ['*.unity', '*.prefab', '*.mat', '*.asset']:
 for path in (root / 'Assets').rglob(suffix):
    for guid in re.findall(r'guid: (\w+)', path.read_text()):
        if guid not in guids and guid not in package_guids and not guid.startswith('0000000000000000'):
            raise RuntimeError('Missing serialized resource ' + guid + ': ' + str(path))
    if suffix == '*.unity':
        print('PASS complete scene resource references:', path.relative_to(root))
pipeline_meta = root / 'Assets/Cosmic/Settings/PC_RPAsset.asset.meta'
pipeline_guid = re.search(r'^guid: (\w+)', pipeline_meta.read_text(), re.M).group(1)
graphics = (root / 'ProjectSettings/GraphicsSettings.asset').read_text()
quality = (root / 'ProjectSettings/QualitySettings.asset').read_text()
if ('m_CustomRenderPipeline: {fileID: 11400000, guid: ' + pipeline_guid) not in graphics:
    raise RuntimeError('Global URP pipeline is not assigned.')
quality_refs = re.findall(r'customRenderPipeline: \{fileID: 11400000, guid: (\w+)', quality)
if len(quality_refs) != len(re.findall(r'^    name:', quality, re.M)) or any(g != pipeline_guid for g in quality_refs):
    raise RuntimeError('Some Quality levels are missing the correct URP pipeline.')
print('PASS global URP and all', len(quality_refs), 'Quality levels assigned')
pipeline = (root / 'Assets/Cosmic/Settings/PC_RPAsset.asset').read_text()
if not re.search(r'^  m_GPUResidentDrawerMode: 0$', pipeline, re.M):
    raise RuntimeError('Forward Renderer must disable GPU Resident Drawer to avoid unsupported configuration warnings.')
print('PASS Forward Renderer has compatible GPU Resident Drawer setting')
solar = (root / 'Assets/Scenes/SolarSystem.unity').read_text()
for name in ['Sun','Mercury','Venus','Earth','Mars','Jupiter','Saturn','Uranus','Neptune','Moon','Grain Rings','SimulationManager','Space Camera']:
    if '  m_Name: ' + name + '\n' not in solar:
        raise RuntimeError('SolarSystem scene missing: ' + name)
for path in (root / 'Assets/Cosmic/Runtime').glob('*.cs'):
    if re.search(r'^using UnityEditor', path.read_text(), re.M):
        raise RuntimeError('Editor dependency leaked into runtime: ' + str(path))
print('PASS SolarSystem hierarchy and runtime/Editor separation')
print('NOTE: static checks do not replace Unity scene import/PlayMode.')
