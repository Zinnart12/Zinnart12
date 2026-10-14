#!/usr/bin/env python3
"""Compile enabled Unity modules/asmdef references with real Unity analyzers.

Checks APIs and module/analyzer failures, not native import, rendering or licensing.
Package DLLs come from the official Editor's compiled URP template.
"""
import argparse
import os
import pathlib
import subprocess

from unity_reference_model import UnityReferenceModel

root = pathlib.Path(__file__).resolve().parents[1]
editor = pathlib.Path(os.environ.get('COSMIC_UNITY_EDITOR_ROOT', '/workspace/.cache/cosmic-unity/unity66/Editor'))
sdk = pathlib.Path(os.environ.get('COSMIC_DOTNET_ROOT', '/workspace/.cache/cosmic-unity/dotnet'))
output = root / 'TestResults' / 'Typecheck'
output.mkdir(parents=True, exist_ok=True)
compiler = sorted((sdk / 'sdk').glob('*/Roslyn/bincore/csc.dll'))[-1]
standard = editor / 'Data/NetStandard/ref/2.1.0/netstandard.dll'
shims = sorted((editor / 'Data/NetStandard/compat/2.1.0/shims/netfx').glob('*.dll'))
analyzers = [editor / 'Data/Tools/BuildPipeline' / name / (name + '.dll')
             for name in ['Unity.Analyzers.Common', 'Unity.Analyzers.LongLiving']]
if not standard.exists() or any(not path.exists() for path in analyzers):
    raise SystemExit('Official Unity 6000.6.5f1 Editor/reference assemblies/analyzers are required.')


def compile_assembly(name, sources, data, model, compiled, *, check=True):
    engine = not data.get('noEngineReferences', False)
    editor_only = 'Editor' in data.get('includePlatforms', []) or 'TestAssemblies' in data.get('optionalUnityReferences', [])
    references = [standard] + shims + model.assembly_references(data, compiled)
    if engine:
        references += model.engine
        if editor_only:
            references += model.editor_references
    defines = ['UNITY_6000_0_OR_NEWER', 'UNITY_6000_6_OR_NEWER']
    if editor_only:
        defines.append('UNITY_EDITOR')
    if 'TestAssemblies' in data.get('optionalUnityReferences', []):
        defines.append('UNITY_INCLUDE_TESTS')
    arguments = ['-nologo', '-nostdlib+', '-langversion:9', '-target:library', '-warnaserror+',
                 '-out:"' + str(output / (name + '.dll')) + '"', '-define:' + ';'.join(defines)]
    arguments += ['-r:"' + str(p) + '"' for p in dict.fromkeys(references)]
    arguments += ['-analyzer:"' + str(p) + '"' for p in analyzers]
    arguments += ['"' + str(p) + '"' for p in sources]
    rsp = output / (name + '.rsp')
    rsp.write_text('\n'.join(arguments))
    result = subprocess.run([str(sdk / 'dotnet'), str(compiler), '@' + str(rsp)],
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if check and result.returncode:
        print(result.stdout, end='')
        raise subprocess.CalledProcessError(result.returncode, result.args)
    if check:
        if result.stdout:
            print(result.stdout, end='')
        print('PASS manifest/asmdef-scoped Unity API + analyzer compile: ' + name, flush=True)
    return output / (name + '.dll'), result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--regressions', action='store_true', help='Prove missing ScreenCapture and UAC0005 are rejected by the compiler.')
    args = parser.parse_args()
    model = UnityReferenceModel(root, editor)
    model.validate_asset_references()
    compiled = {}
    pending = dict(model.asset_assemblies)
    while pending:
        ready = [name for name, (_, data) in pending.items() if all(model.resolve_name(ref) not in pending for ref in data.get('references', []))]
        if not ready:
            raise SystemExit('Cyclic project asmdef references: ' + ', '.join(pending))
        for name in sorted(ready):
            path, data = pending.pop(name)
            sources = [source for source in sorted(path.parent.rglob('*.cs'))
                       if not any(nested.parent in source.parents for nested in path.parent.rglob('*.asmdef') if nested != path)]
            compiled[name], _ = compile_assembly(name, sources, data, model, compiled)
    print('PASS enabled engine modules resolved through manifest and bundled transitive package dependencies')
    if model.external_packages:
        print('NOTE external package source metadata is not bundled; no project asmdef directly references: ' + ', '.join(sorted(model.external_packages)))
    if args.regressions:
        dependencies = dict(model.dependencies)
        dependencies.pop('com.unity.modules.screencapture', None)
        missing = UnityReferenceModel(root, editor, dependencies)
        path, data = model.asset_assemblies['Cosmic.PlayModeTests']
        _, result = compile_assembly('MissingScreenCaptureRegression', sorted(path.parent.glob('*.cs')), data, missing, compiled, check=False)
        (output / 'missing-screencapture.txt').write_text(result.stdout)
        if result.returncode == 0 or 'ScreenCapture' not in result.stdout or not any(code in result.stdout for code in ['CS0103', 'CS1069']):
            raise SystemExit('Regression failed: screenshot test must not compile without its enabled module.\n' + result.stdout)
        print('PASS compiler regression: removing screencapture rejects the unchanged screenshot test')
        fixture = output / 'ObsoleteAssemblyScan.cs'
        fixture.write_text('public static class ObsoleteAssemblyScan { public static System.Reflection.Assembly[] Scan() => System.AppDomain.CurrentDomain.GetAssemblies(); }\n')
        _, result = compile_assembly('AssemblyScanAnalyzerRegression', [fixture], {'name': 'Regression', 'includePlatforms': ['Editor']}, model, compiled, check=False)
        (output / 'uac0005.txt').write_text(result.stdout)
        if result.returncode == 0 or 'UAC0005' not in result.stdout:
            raise SystemExit('Regression failed: real Unity analyzer must reject AppDomain.GetAssemblies.\n' + result.stdout)
        print('PASS compiler regression: real Unity analyzer rejects assembly scanning with UAC0005')


if __name__ == '__main__':
    main()
