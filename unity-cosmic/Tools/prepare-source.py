#!/usr/bin/env python3
"""Create deterministic Unity metadata and component scene/prefab serialization.

URP pipeline assets are checked in; ProjectBuilder validates them on import.
This tool never rewrites existing .meta files, scene edits, or material edits.
"""
import hashlib
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]


def guid(path):
    return hashlib.sha256(('cosmic-unity-phase1/' + path).encode()).hexdigest()[:32]


def component_asset(script, name, fields='', scene=False):
    text = '''%YAML 1.1
%TAG !u! tag:unity3d.com,2011:
--- !u!1 &1001
GameObject:
  m_ObjectHideFlags: 0
  m_CorrespondingSourceObject: {fileID: 0}
  m_PrefabInstance: {fileID: 0}
  m_PrefabAsset: {fileID: 0}
  serializedVersion: 6
  m_Component:
  - component: {fileID: 1002}
  - component: {fileID: 1003}
  m_Layer: 0
  m_Name: NAME
  m_TagString: Untagged
  m_Icon: {fileID: 0}
  m_NavMeshLayer: 0
  m_StaticEditorFlags: 0
  m_IsActive: 1
--- !u!4 &1002
Transform:
  m_ObjectHideFlags: 0
  m_CorrespondingSourceObject: {fileID: 0}
  m_PrefabInstance: {fileID: 0}
  m_PrefabAsset: {fileID: 0}
  m_GameObject: {fileID: 1001}
  serializedVersion: 2
  m_LocalRotation: {x: 0, y: 0, z: 0, w: 1}
  m_LocalPosition: {x: 0, y: 0, z: 0}
  m_LocalScale: {x: 1, y: 1, z: 1}
  m_ConstrainProportionsScale: 0
  m_Children: []
  m_Father: {fileID: 0}
  m_LocalEulerAnglesHint: {x: 0, y: 0, z: 0}
--- !u!114 &1003
MonoBehaviour:
  m_ObjectHideFlags: 0
  m_CorrespondingSourceObject: {fileID: 0}
  m_PrefabInstance: {fileID: 0}
  m_PrefabAsset: {fileID: 0}
  m_GameObject: {fileID: 1001}
  m_Enabled: 1
  m_EditorHideFlags: 0
  m_Script: {fileID: 11500000, guid: SCRIPT_GUID, type: 3}
  m_Name:
  m_EditorClassIdentifier:
FIELDS'''
    text = text.replace('NAME', name).replace('SCRIPT_GUID', guid(script)).replace('FIELDS', fields)
    if scene:
        text += '''--- !u!1660057539 &9223372036854775807
SceneRoots:
  m_ObjectHideFlags: 0
  m_Roots:
  - {fileID: 1002}
'''
    return text


def write_if_missing(path, value):
    file = ROOT / path
    file.parent.mkdir(parents=True, exist_ok=True)
    if not file.exists():
        file.write_text(value)


def main():
    bootstrap = 'Assets/Cosmic/Runtime/CosmicBootstrap.cs'
    for name, show_menu in [('MainMenu', 1), ('SolarSystem', 0)]:
        write_if_missing('Assets/Scenes/' + name + '.unity', component_asset(bootstrap, 'Cosmic Bootstrap',
                         '  showMenu: ' + str(show_menu) + '\n  initialPreset: solar\n', True))
    write_if_missing('Assets/Resources/Prefabs/CelestialBody.prefab', component_asset(
        'Assets/Cosmic/Runtime/CelestialBodyView.cs', 'Celestial Body'))
    for path in sorted((ROOT / 'Assets').rglob('*')):
        if path.suffix == '.meta':
            continue
        relative = path.relative_to(ROOT).as_posix()
        meta = pathlib.Path(str(path) + '.meta')
        if meta.exists():
            continue
        prefix = 'fileFormatVersion: 2\nguid: ' + guid(relative) + '\n'
        if path.is_dir():
            body = 'folderAsset: yes\nDefaultImporter:\n  externalObjects: {}\n'
        elif path.suffix == '.cs':
            body = 'MonoImporter:\n  externalObjects: {}\n  serializedVersion: 2\n  defaultReferences: []\n  executionOrder: 0\n  icon: {instanceID: 0}\n'
        else:
            importer = {'.shader': 'ShaderImporter', '.hlsl': 'ShaderIncludeImporter', '.asmdef': 'AssemblyDefinitionImporter',
                        '.json': 'TextScriptImporter', '.prefab': 'PrefabImporter', '.asset': 'NativeFormatImporter', '.mat': 'NativeFormatImporter'}.get(path.suffix, 'DefaultImporter')
            body = importer + ':\n  externalObjects: {}\n'
            if importer == 'NativeFormatImporter':
                file_id = 2100000 if path.suffix == '.mat' else 4300000 if 'Meshes' in path.parts else 11400000
                body += '  mainObjectFileID: ' + str(file_id) + '\n'
        meta.write_text(prefix + body + '  userData:\n  assetBundleName:\n  assetBundleVariant:\n')
    write_if_missing('ProjectSettings/EditorBuildSettings.asset', '''%YAML 1.1
%TAG !u! tag:unity3d.com,2011:
--- !u!1045 &1
EditorBuildSettings:
  m_ObjectHideFlags: 0
  serializedVersion: 2
  m_Scenes:
  - enabled: 1
    path: Assets/Scenes/MainMenu.unity
    guid: ''' + guid('Assets/Scenes/MainMenu.unity') + '''
  - enabled: 1
    path: Assets/Scenes/SolarSystem.unity
    guid: ''' + guid('Assets/Scenes/SolarSystem.unity') + '''
  m_configObjects: {}
''')
    print('Unity scenes, prefab and stable metadata prepared.')


if __name__ == '__main__':
    main()
