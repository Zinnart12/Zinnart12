#!/usr/bin/env python3
"""Serialize complete procedural preview meshes/materials/scene for source delivery.

The same sphere/ring algorithms are in PlanetGenerator.cs. Native import is
checked by the Editor tests; this baker never substitutes orbital animation.
"""
import json
import math
import pathlib
import re
import struct
import hashlib

def guid(path):
    return hashlib.sha256(('cosmic-unity-phase1/' + path).encode()).hexdigest()[:32]

ROOT = pathlib.Path(__file__).resolve().parents[1]
EDITOR = pathlib.Path('/workspace/.cache/cosmic-unity/unity66/Editor')
MESH_TEMPLATE = EDITOR / 'Data/Resources/PackageManager/BuiltInPackages/com.unity.animation.rigging/Editor/Shapes/CircleEffector.asset'


def mesh_asset(name, positions, normals, uv, triangles, extent):
    # Use the Editor's native Mesh serialization layout with actual vertex/index buffers.
    text = MESH_TEMPLATE.read_text().replace('m_Name: CircleEffector', 'm_Name: ' + name)
    text = text.replace('indexCount: 33', 'indexCount: ' + str(len(triangles))).replace('topology: 4', 'topology: 0')
    text = text.replace('vertexCount: 32', 'vertexCount: ' + str(len(positions))).replace('m_VertexCount: 32', 'm_VertexCount: ' + str(len(positions)))
    box = '{x: ' + str(extent[0]) + ', y: ' + str(extent[1]) + ', z: ' + str(extent[2]) + '}'
    text = text.replace('{x: 0.5, y: 0, z: 0.5}', box)
    indices = struct.pack('<' + 'H' * len(triangles), *triangles).hex()
    text = re.sub(r'm_IndexBuffer:.*', 'm_IndexBuffer: ' + indices, text)
    channels = ''
    for index in range(14):
        offset, dimension = {0: (0, 3), 1: (12, 3), 4: (24, 2)}.get(index, (0, 0))
        channels += f'    - stream: 0\n      offset: {offset}\n      format: 0\n      dimension: {dimension}\n'
    data = b''.join(struct.pack('<8f', *(p + n + t)) for p, n, t in zip(positions, normals, uv))
    start = text.index('    m_Channels:')
    end = text.index('  m_CompressedMesh:', start)
    text = text[:start] + '    m_Channels:\n' + channels + f'    m_DataSize: {len(data)}\n    _typelessdata: {data.hex()}\n' + text[end:]
    path = ROOT / ('Assets/Cosmic/Meshes/' + name + '.asset')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('\n'.join(line.rstrip() for line in text.splitlines()) + '\n')


def sphere(quality):
    segments = [24, 48, 96][quality]
    latitude = segments // 2
    positions, uv, triangles = [], [], []
    for y in range(latitude + 1):
        for x in range(segments + 1):
            u, v = x / segments, y / latitude
            a, b = u * math.tau, v * math.pi
            positions.append((math.sin(b) * math.cos(a), math.cos(b), math.sin(b) * math.sin(a)))
            uv.append((u, v))
    for y in range(latitude):
        for x in range(segments):
            i = y * (segments + 1) + x
            j = i + segments + 1
            triangles.extend([i, i + 1, j, i + 1, j + 1, j])
    mesh_asset('PlanetLOD' + str(quality), positions, positions, uv, triangles, (1, 1, 1))


def rings():
    p, n, uv, t = [], [], [], []
    for i in range(257):
        a = i * math.tau / 256
        for r in [1.25, 2.3]:
            p.append((math.cos(a) * r, 0, math.sin(a) * r));n.append((0, 1, 0));uv.append(((r - 1.25) / 1.05, i / 256))
        if i < 256:
            j = i * 2;t.extend([j, j + 2, j + 1, j + 1, j + 2, j + 3])
    mesh_asset('SaturnRings', p, n, uv, t, (2.3, 0, 2.3))


def linear(x):
    return x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4


def material(path, shader, floats=None, colors=None, instanced=False):
    shader_path = 'Assets/Cosmic/Shaders/' + {'Planet': 'PlanetSurfaceURP', 'Star': 'StarSurfaceURP'}.get(shader, shader) + '.shader'
    shader_guid = re.search(r'^guid: (\w+)', (ROOT / (shader_path + '.meta')).read_text(), re.M).group(1)
    floats, colors = floats or {}, colors or {}
    text = f'''%YAML 1.1
%TAG !u! tag:unity3d.com,2011:
--- !u!21 &2100000
Material:
  serializedVersion: 8
  m_ObjectHideFlags: 0
  m_CorrespondingSourceObject: {{fileID: 0}}
  m_PrefabInstance: {{fileID: 0}}
  m_PrefabAsset: {{fileID: 0}}
  m_Name: {pathlib.Path(path).stem}
  m_Shader: {{fileID: 4800000, guid: {shader_guid}, type: 3}}
  m_Parent: {{fileID: 0}}
  m_ModifiedSerializedProperties: 0
  m_ValidKeywords: []
  m_InvalidKeywords: []
  m_LightmapFlags: 4
  m_EnableInstancingVariants: {int(instanced)}
  m_DoubleSidedGI: 0
  m_CustomRenderQueue: -1
  stringTagMap: {{}}
  disabledShaderPasses: []
  m_LockedProperties:
  m_SavedProperties:
    serializedVersion: 3
    m_TexEnvs: []
    m_Ints: []
    m_Floats:''' + ('\n' if floats else ' []\n')
    for key, value in floats.items():
        text += f'    - {key}: {value}\n'
    text += '    m_Colors:' + ('\n' if colors else ' []\n')
    for key, values in colors.items():
        text += f'    - {key}: {{r: {values[0]}, g: {values[1]}, b: {values[2]}, a: {values[3]}}}\n'
    text += '  m_BuildTextureStacks: []\n'
    file = ROOT / path;file.parent.mkdir(parents=True, exist_ok=True);file.write_text(text)


class Scene:
    def __init__(self):
        self.next = 1000;self.nodes = [];self.components = []

    def node(self, name, parent=0, position=(0, 0, 0), scale=(1, 1, 1), rotation=(0, 0, 0, 1), tag='Untagged'):
        obj, transform = self.next, self.next + 1;self.next += 2
        self.nodes.append({'obj': obj, 'transform': transform, 'parent': parent, 'name': name, 'p': position, 's': scale, 'q': rotation, 'tag': tag, 'components': []})
        return self.nodes[-1]

    def component(self, node, type_id, body):
        identifier = self.next;self.next += 1;node['components'].append(identifier)
        self.components.append((type_id, identifier, node['obj'], body));return identifier

    def script(self, node, path, fields=''):
        return self.component(node, 114, f'''MonoBehaviour:
  m_ObjectHideFlags: 0
  m_CorrespondingSourceObject: {{fileID: 0}}
  m_PrefabInstance: {{fileID: 0}}
  m_PrefabAsset: {{fileID: 0}}
  m_Enabled: 1
  m_EditorHideFlags: 0
  m_Script: {{fileID: 11500000, guid: {guid(path)}, type: 3}}
  m_Name:
  m_EditorClassIdentifier:
''' + fields)

    def mesh(self, node, mesh, material_path):
        self.component(node, 33, f'MeshFilter:\n  m_ObjectHideFlags: 0\n  m_Mesh: {{fileID: 4300000, guid: {guid(mesh)}, type: 2}}\n')
        self.component(node, 23, f'''MeshRenderer:
  m_ObjectHideFlags: 0
  m_Enabled: 1
  m_CastShadows: 0
  m_ReceiveShadows: 0
  m_Materials:
  - {{fileID: 2100000, guid: {guid(material_path)}, type: 2}}
  m_StaticBatchInfo: {{firstSubMesh: 0, subMeshCount: 0}}
  m_StaticBatchRoot: {{fileID: 0}}
  m_ScaleInLightmap: 1
  m_SortingLayerID: 0
  m_SortingOrder: 0
''')

    def write(self, path):
        text = '%YAML 1.1\n%TAG !u! tag:unity3d.com,2011:\n'
        for node in self.nodes:
            obj, tr = node['obj'], node['transform']
            text += f'''--- !u!1 &{obj}
GameObject:
  m_ObjectHideFlags: 0
  m_CorrespondingSourceObject: {{fileID: 0}}
  m_PrefabInstance: {{fileID: 0}}
  m_PrefabAsset: {{fileID: 0}}
  serializedVersion: 6
  m_Component:
  - component: {{fileID: {tr}}}
'''
            for component in node['components']:text += f'  - component: {{fileID: {component}}}\n'
            text += f'  m_Layer: 0\n  m_Name: {node["name"]}\n  m_TagString: {node["tag"]}\n  m_IsActive: 1\n'
            p, s, q = node['p'], node['s'], node['q']
            children = [x['transform'] for x in self.nodes if x['parent'] == tr]
            text += f'''--- !u!4 &{tr}
Transform:
  m_ObjectHideFlags: 0
  m_CorrespondingSourceObject: {{fileID: 0}}
  m_PrefabInstance: {{fileID: 0}}
  m_PrefabAsset: {{fileID: 0}}
  m_GameObject: {{fileID: {obj}}}
  serializedVersion: 2
  m_LocalRotation: {{x: {q[0]}, y: {q[1]}, z: {q[2]}, w: {q[3]}}}
  m_LocalPosition: {{x: {p[0]}, y: {p[1]}, z: {p[2]}}}
  m_LocalScale: {{x: {s[0]}, y: {s[1]}, z: {s[2]}}}
  m_ConstrainProportionsScale: 0
  m_Children:''' + ('\n' if children else ' []\n')
            for child in children:text += f'  - {{fileID: {child}}}\n'
            text += f'  m_Father: {{fileID: {node["parent"]}}}\n  m_LocalEulerAnglesHint: {{x: 0, y: 0, z: 0}}\n'
        for type_id, identifier, obj, body in self.components:
            text += f'--- !u!{type_id} &{identifier}\n' + body.split('\n', 1)[0] + '\n  m_GameObject: {fileID: ' + str(obj) + '}\n' + body.split('\n', 1)[1]
        text += '--- !u!1660057539 &9223372036854775807\nSceneRoots:\n  m_ObjectHideFlags: 0\n  m_Roots:\n'
        for node in self.nodes:
            if node['parent'] == 0:text += f'  - {{fileID: {node["transform"]}}}\n'
        (ROOT / path).write_text(text)


def main():
    for quality in range(3):sphere(quality)
    rings()
    for name in ['Planet', 'Star', 'Atmosphere', 'Clouds', 'Rings', 'Starfield', 'Trail']:
        material('Assets/Resources/Materials/' + name + '.mat', name, instanced=name == 'Starfield')
    bodies = next(e['snapshot']['bodies'] for e in json.loads((ROOT / 'Assets/StreamingAssets/PresetCatalog.json').read_text())['entries'] if e['id'] == 'solar')
    sun = next(b for b in bodies if b['id'] == 'sun')
    scene = Scene();bootstrap = scene.node('Cosmic Bootstrap');manager = scene.node('SimulationManager')
    manager_id = scene.script(manager, 'Assets/Cosmic/Runtime/UniverseManager.cs')
    scene.script(manager, 'Assets/Cosmic/Runtime/SpaceBackground.cs')
    camera = scene.node('Space Camera', position=(0, 900, -1700), rotation=(math.sin(math.radians(28)/2), 0, 0, math.cos(math.radians(28)/2)), tag='MainCamera')
    camera_id = scene.component(camera, 20, '''Camera:
  m_ObjectHideFlags: 0
  m_Enabled: 1
  serializedVersion: 2
  m_ClearFlags: 2
  m_BackGroundColor: {r: 0, g: 0, b: 0, a: 1}
  m_NormalizedViewPortRect: {serializedVersion: 2, x: 0, y: 0, width: 1, height: 1}
  near clip plane: 0.1
  far clip plane: 8000
  field of view: 48
  orthographic: 0
  orthographic size: 5
  m_Depth: -1
  m_CullingMask: {serializedVersion: 2, m_Bits: 4294967295}
  m_RenderingPath: -1
  m_TargetTexture: {fileID: 0}
  m_TargetDisplay: 0
  m_TargetEye: 3
  m_HDR: 1
  m_AllowMSAA: 1
  m_AllowDynamicResolution: 0
  m_ForceIntoRT: 0
  m_OcclusionCulling: 0
''')
    scene.component(camera, 81, 'AudioListener:\n  m_ObjectHideFlags: 0\n  m_Enabled: 1\n')
    scene.script(camera, 'Assets/Cosmic/Runtime/SpaceCameraController.cs')
    preview = scene.node('Editor Preview - initial SI state', manager['transform'])
    scene.script(bootstrap, 'Assets/Cosmic/Runtime/CosmicBootstrap.cs', f'  showMenu: 0\n  initialPreset: solar\n  editorPreview: {{fileID: {preview["obj"]}}}\n  sceneManager: {{fileID: {manager_id}}}\n  sceneCamera: {{fileID: {camera_id}}}\n')
    scale = 32 / 149597870700
    for b in bodies:
        nearest = min(math.dist(b['position'], other['position']) * scale for other in bodies if other['id'] != b['id'])
        radius = max(b['radius'] * scale, min(max(b['radius'] * scale, .35 if b['kind'] == 'star' else .12), nearest * .22))
        root = scene.node(b['name'], preview['transform'], tuple(x * scale for x in b['position']), (radius,) * 3)
        tilt = math.radians(b['axial_tilt']) / 2
        rotation = scene.node('Axial Rotation', root['transform'], rotation=(0, 0, math.sin(tilt), math.cos(tilt)))
        color = tuple(linear(int(b['color'][i:i+2], 16) / 255) for i in [0, 2, 4]) + (1,)
        direction = [sun['position'][i] - b['position'][i] for i in range(3)]
        distance = math.sqrt(sum(x*x for x in direction))
        direction = tuple(x / distance for x in direction) + (0,) if distance else (1, 0, 0, 0)
        flux = (sun['radius'] ** 2 * 5.670374419e-8 * sun['temperature'] ** 4 / distance ** 2 / 1361) if distance else 0
        floats = {'_Temperature': b['temperature'], '_Seed': b['seed'], '_SurfaceKind': ['earth','rocky','gas','ice','lava','ocean'].index(b['surface']),
                  '_IsMars': int(b['id']=='mars'), '_RedSpot': int(b['id']=='jupiter'), '_PreviewFlux': flux,
                  '_AtmosphereStrength': min(1, math.log(1+b['atmosphere']))}
        colors = {'_BaseColor': color, '_TemperatureColor': (1, .88, .66, 1), '_PreviewLightDirection': direction, '_SunDirection': direction, '_PreviewLightColor': (1,.88,.66,1)}
        kinds = ['Star' if b['kind'] == 'star' else 'Planet']
        if b['atmosphere'] > 0 and b['kind'] != 'star':kinds.append('Atmosphere')
        if b['id'] in ['earth','venus']:kinds.append('Clouds')
        if b['id'] == 'saturn':kinds.append('Rings')
        for kind in kinds:
            path = f'Assets/Resources/Materials/Preview/{b["id"]}-{kind}.mat';material(path, kind, floats, colors)
            factor = {'Atmosphere': 1.04, 'Clouds': 1.013}.get(kind, 1)
            node = scene.node({'Rings': 'Grain Rings', 'Clouds': 'Cloud Layer'}.get(kind, kind+' Surface'), rotation['transform'], scale=(factor,) * 3)
            scene.mesh(node, 'Assets/Cosmic/Meshes/'+('SaturnRings' if kind=='Rings' else 'PlanetLOD2')+'.asset', path)
    scene.write('Assets/Scenes/SolarSystem.unity')
    print('Baked complete SolarSystem preview, procedural meshes and URP material assets.')


if __name__ == '__main__':main()
