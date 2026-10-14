#!/usr/bin/env python3
"""Standalone DXC compile using the official Editor's URP HLSL includes.

This checks shader syntax/types. Unity import, platform variants and rendered
pixels still need the licensed Editor and the PlayMode tests.
"""
import os
import pathlib
import re
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
editor = pathlib.Path(os.environ.get('COSMIC_UNITY_EDITOR_ROOT', '/workspace/.cache/cosmic-unity/unity/Editor'))
dxc = pathlib.Path(os.environ.get('COSMIC_DXC', '/workspace/.cache/cosmic-unity/dxc/bin/dxc'))
output = root / 'TestResults' / 'HLSL'
output.mkdir(parents=True, exist_ok=True)
link = output / 'Packages'
if not link.exists():
    link.symlink_to(editor / 'Data/Resources/PackageManager/BuiltInPackages', target_is_directory=True)
passed = 0
for shader in sorted((root / 'Assets/Cosmic/Shaders').glob('*.shader')):
    program = re.search(r'HLSLPROGRAM(.*?)ENDHLSL', shader.read_text(), re.S).group(1)
    vertex = re.search(r'#pragma vertex (\w+)', program).group(1)
    fragment = re.search(r'#pragma fragment (\w+)', program).group(1)
    source = output / (shader.stem + '.hlsl')
    source.write_text(re.sub(r'^\s*#pragma[^\n]*', '', program, flags=re.M))
    variants = [False, True] if shader.stem == 'Starfield' else [False]
    for instanced in variants:
        for stage, entry in [('vs', vertex), ('ps', fragment)]:
            name = shader.stem + ('_instanced' if instanced else '') + '_' + stage
            args = [str(dxc), '-WX', '-flegacy-macro-expansion', '-T', stage + '_6_0', '-E', entry, '-D', 'SHADER_API_D3D11=1', '-D', 'SHADER_TARGET=45',
                    '-D', 'UNITY_VERSION=600000', '-D', 'UNITY_COMPILER_HLSL=1',
                    '-I', str(output), '-I', str(root / 'Assets/Cosmic/Shaders'), '-I', str(editor / 'Data/CGIncludes'),
                    '-Fo', str(output / (name + '.dxil')), str(source)]
            if instanced:
                args.extend(['-D', 'INSTANCING_ON=1'])
            subprocess.run(args, check=True)
            passed += 1
            print('PASS DXC + actual URP includes: ' + name, flush=True)
print('TOTAL', passed, 'HLSL stages/variants compiled; GPU rendering remains a separate check.')
