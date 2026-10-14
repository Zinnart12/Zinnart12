"""Resolve enabled Unity package/module and explicit asmdef references.

Bundled DLLs do not imply that their packages/modules are enabled in a project.
This is an offline approximation of Unity import, using bundled package metadata.
"""
import json
import pathlib
import re


class UnityReferenceModel:
    def __init__(self, root, editor, dependencies=None):
        self.root = pathlib.Path(root)
        self.editor = pathlib.Path(editor)
        self.packages = self.editor / 'Data/Resources/PackageManager/BuiltInPackages'
        self.managed = self.editor / 'Data/Managed/UnityEngine'
        self.template = next((self.editor / 'Data/Resources/PackageManager/ProjectTemplates/libcache')
                             .glob('com.unity.template.urp-blank-*/ScriptAssemblies'))
        self.dependencies = dependencies if dependencies is not None else json.loads(
            (self.root / 'Packages/manifest.json').read_text())['dependencies']
        self.enabled_packages = set()
        self.external_packages = set()
        pending = list(self.dependencies)
        while pending:
            name = pending.pop()
            if name in self.enabled_packages:
                continue
            self.enabled_packages.add(name)
            package = self.packages / name / 'package.json'
            if not package.exists():
                # External registry dependencies have no source in the Editor archive.
                self.external_packages.add(name)
                continue
            pending.extend(json.loads(package.read_text(encoding='utf-8-sig')).get('dependencies', {}))

        self.module_dlls = {}
        for package in self.packages.glob('com.unity.modules.*/package.json'):
            data = json.loads(package.read_text(encoding='utf-8-sig'))
            names = re.findall(r'UnityEngine\.(\w+Module)', data.get('description') or '')
            if not names:
                identifier = data['name'].rsplit('.', 1)[1]
                names = [dll.stem.split('.', 1)[1] for dll in self.managed.glob('UnityEngine.*Module.dll')
                         if dll.stem.split('.', 1)[1][:-6].lower() == identifier]
            self.module_dlls[data['name']] = {self.managed / ('UnityEngine.' + name + '.dll') for name in names}
        all_optional = set().union(*self.module_dlls.values())
        selected = set().union(*(dlls for name, dlls in self.module_dlls.items() if name in self.enabled_packages))
        # Internal engine modules have no optional UPM package. Exclude the legacy
        # UnityEngine.dll facade: its forwarders can expose disabled modules.
        self.engine = sorted(set(self.managed.glob('UnityEngine.*.dll')) - all_optional | selected)
        self.editor_references = sorted(self.managed.glob('UnityEditor*.dll'))
        self.assemblies = {}
        self.guid_names = {}
        self.asset_assemblies = {}
        for base in [self.root / 'Assets'] + [self.packages / name for name in sorted(self.enabled_packages)
                                              if (self.packages / name).is_dir()]:
            for path in sorted(base.rglob('*.asmdef')):
                if any(part.endswith('~') for part in path.parts):
                    continue
                data = json.loads(path.read_text(encoding='utf-8-sig'))
                self.assemblies[data['name']] = (path, data)
                if base == self.root / 'Assets':
                    self.asset_assemblies[data['name']] = (path, data)
                meta = pathlib.Path(str(path) + '.meta')
                if meta.exists():
                    match = re.search(r'^guid: (\w+)', meta.read_text(), re.M)
                    if match:
                        self.guid_names[match[1]] = data['name']

    def resolve_name(self, name):
        if name.startswith('GUID:'):
            if name[5:] not in self.guid_names:
                raise ValueError('Assembly GUID is outside the enabled package graph: ' + name)
            return self.guid_names[name[5:]]
        return name

    def assembly_references(self, data, compiled):
        result = []
        for item in data.get('references', []):
            name = self.resolve_name(item)
            if name in compiled:
                result.append(compiled[name])
            elif name in self.asset_assemblies:
                raise ValueError('Project assembly must be compiled first: ' + name)
            elif name in self.assemblies:
                dll = self.template / (name + '.dll')
                if not dll.exists():
                    raise ValueError('Reference DLL is not supplied by the official template: ' + name)
                result.append(dll)
            elif any(dll.stem == name for dll in self.engine):
                result.append(self.managed / (name + '.dll'))
            else:
                raise ValueError('Assembly reference is outside the enabled package graph: ' + name)
        if 'TestAssemblies' in data.get('optionalUnityReferences', []):
            if 'com.unity.test-framework' not in self.enabled_packages:
                raise ValueError('TestAssemblies requires com.unity.test-framework')
            result.extend(self.template / (name + '.dll') for name in ['UnityEngine.TestRunner', 'UnityEditor.TestRunner'])
            result.append(next((self.packages / 'com.unity.ext.nunit').rglob('nunit.framework.dll')))
        return result

    def validate_asset_references(self):
        for path, data in self.asset_assemblies.values():
            for item in data.get('references', []):
                name = self.resolve_name(item)
                if name not in self.assemblies and not any(dll.stem == name for dll in self.engine):
                    raise ValueError('Unknown or disabled assembly reference ' + name + ': ' + str(path))
