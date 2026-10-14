#!/usr/bin/env python3
"""Compile against real Unity 6 and URP DLLs without running Editor code.

This checks C# APIs, not scene execution, shader compilation or Unity licensing.
The official Editor includes its URP template's compiled ScriptAssemblies.
"""
import os
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
editor = pathlib.Path(os.environ.get('COSMIC_UNITY_EDITOR_ROOT', '/workspace/.cache/cosmic-unity/unity66/Editor'))
sdk = pathlib.Path(os.environ.get('COSMIC_DOTNET_ROOT', '/workspace/.cache/cosmic-unity/dotnet'))
output = root / 'TestResults' / 'Typecheck'
output.mkdir(parents=True, exist_ok=True)
compiler = sorted((sdk / 'sdk').glob('*/Roslyn/bincore/csc.dll'))[-1]
standard = editor / 'Data/NetStandard/ref/2.1.0/netstandard.dll'
template = next((editor / 'Data/Resources/PackageManager/ProjectTemplates/libcache').glob('com.unity.template.urp-blank-*/ScriptAssemblies'))
native = sorted((editor / 'Data/Managed/UnityEngine').glob('*.dll'))
packages = sorted(template.glob('Unity*.dll'))
if not standard.exists() or not packages:
    raise SystemExit('Official Unity 6000.6.5f1 Editor/reference assemblies are required.')


def compile_assembly(name, directory, extra=(), engine=True, define=''):
    shims = sorted((editor / 'Data/NetStandard/compat/2.1.0/shims/netfx').glob('*.dll'))
    references = [standard] + shims + (native + packages if engine else []) + list(extra)
    sources = sorted((root / directory).glob('*.cs'))
    arguments = ['-nologo', '-nostdlib+', '-langversion:9', '-target:library', '-warnaserror+',
                 '-out:"' + str(output / (name + '.dll')) + '"']
    if define:
        arguments += ['-define:' + define]
    arguments += ['-r:"' + str(p) + '"' for p in references]
    arguments += ['"' + str(p) + '"' for p in sources]
    rsp = output / (name + '.rsp')
    rsp.write_text('\n'.join(arguments))
    subprocess.run([str(sdk / 'dotnet'), str(compiler), '@' + str(rsp)], check=True)
    print('PASS real Unity API compile: ' + name, flush=True)
    return output / (name + '.dll')


core = compile_assembly('Cosmic.Core', 'Assets/Cosmic/Core', engine=False)
runtime = compile_assembly('Cosmic.Runtime', 'Assets/Cosmic/Runtime', [core])
editor_assembly = compile_assembly('Cosmic.Editor', 'Assets/Cosmic/Editor', [core, runtime], define='UNITY_EDITOR;UNITY_6000_0_OR_NEWER;UNITY_6000_6_OR_NEWER')
nunit = next((editor / 'Data/Resources/PackageManager/BuiltInPackages/com.unity.ext.nunit').rglob('nunit.framework.dll'))
compile_assembly('Cosmic.PlayModeTests', 'Assets/Tests/PlayMode', [core, runtime, nunit], define='UNITY_INCLUDE_TESTS')
compile_assembly('Cosmic.EditModeTests', 'Assets/Tests/EditMode', [core, runtime, editor_assembly, nunit], define='UNITY_EDITOR;UNITY_INCLUDE_TESTS')
