#!/usr/bin/env python3
"""Check Unity import constraints that standalone Roslyn cannot validate."""
import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
TEST_RUNNERS = {'UnityEngine.TestRunner', 'UnityEditor.TestRunner'}


def validate_module_apis(enabled_packages, sources):
    if re.search(r'\bScreenCapture\s*\.', sources) and 'com.unity.modules.screencapture' not in enabled_packages:
        raise ValueError('ScreenCapture API requires enabled com.unity.modules.screencapture; an installed DLL alone is insufficient.')


def validate_assembly(data):
    references = data.get('references', [])
    if len(references) != len(set(references)):
        raise ValueError('Duplicate explicit assembly references: ' + data['name'])
    if 'TestAssemblies' in data.get('optionalUnityReferences', []):
        duplicated = TEST_RUNNERS.intersection(references)
        if duplicated:
            raise ValueError('TestAssemblies already adds these references: ' + ', '.join(sorted(duplicated)))


def validate_tags(text):
    # Unity's native YAML reader is stricter than generic YAML for empty slots.
    # Keep empty layer names as explicit strings, not null/naked sequence items.
    if re.search(r'(?m)^[ \t]*-$', text):
        raise ValueError('Bare empty YAML sequence item; serialize an empty layer as "".')
    for field, following in [('layers', 'm_SortingLayers'), ('m_RenderingLayers', None)]:
        start = text.index('  ' + field + ':\n') + len('  ' + field + ':\n')
        section = text[start:text.index('  ' + following + ':', start)] if following else text[start:]
        entries = section.splitlines()
        if len(entries) != 32 or any(not line.startswith('  - ') or not line[4:].strip() or line[4:].strip() in {'null', '~'} for line in entries):
            raise ValueError(field + ' must have 32 explicit string slots.')
    if not re.search(r'(?m)^  - name: Default\n    uniqueID: 0\n    locked: 0$', text):
        raise ValueError('Default sorting layer is missing or malformed.')


class ImportRegressionTests(unittest.TestCase):
    def test_screenshot_api_with_disabled_module_is_rejected(self):
        with self.assertRaises(ValueError):
            validate_module_apis({'com.unity.modules.imageconversion'}, 'ScreenCapture.CaptureScreenshotAsTexture()')

    def test_screenshot_api_with_enabled_module_is_accepted(self):
        validate_module_apis({'com.unity.modules.screencapture'}, 'ScreenCapture.CaptureScreenshotAsTexture()')

    def test_previous_empty_layer_representation_is_rejected(self):
        text = (ROOT / 'ProjectSettings/TagManager.asset').read_text()
        with self.assertRaises(ValueError):
            validate_tags(text.replace('  - ""\n', '  -\n', 1))

    def test_previous_playmode_implicit_duplicate_is_rejected(self):
        with self.assertRaises(ValueError):
            validate_assembly({'name': 'PlayMode', 'references': ['UnityEngine.TestRunner'],
                               'optionalUnityReferences': ['TestAssemblies']})

    def test_previous_editmode_implicit_duplicate_is_rejected(self):
        with self.assertRaises(ValueError):
            validate_assembly({'name': 'EditMode', 'references': ['UnityEditor.TestRunner'],
                               'optionalUnityReferences': ['TestAssemblies']})


def main():
    result = unittest.TextTestRunner(verbosity=1).run(unittest.defaultTestLoader.loadTestsFromTestCase(ImportRegressionTests))
    if not result.wasSuccessful():
        raise SystemExit(1)
    validate_tags((ROOT / 'ProjectSettings/TagManager.asset').read_text())
    for path in sorted((ROOT / 'Assets').rglob('*.asmdef')):
        validate_assembly(json.loads(path.read_text(encoding='utf-8-sig')))
    print('PASS 5 import/module regression checks; TagManager has 32 explicit layer/rendering slots; no duplicate implicit TestRunner references', flush=True)


if __name__ == '__main__':
    main()
