#!/usr/bin/env python3
"""Record original Godot sources/resources so later phases can track parity."""
import hashlib
import json
import pathlib
import re

root = pathlib.Path(__file__).resolve().parents[1]
godot = root.parent / 'godot-cosmic'
files = []
for source in sorted(godot.rglob('*')):
    path = source.relative_to(godot).as_posix()
    if not source.is_file() or any(part in {'.godot', 'builds', 'releases'} for part in source.parts):
        continue
    if source.suffix not in {'.gd', '.gdshader', '.gdshaderinc', '.tscn', '.tres', '.godot', '.cfg', '.svg', '.md'}:
        continue
    data = source.read_bytes()
    text = data.decode('utf-8')
    files.append({'path': path, 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data),
                  'lines': len(text.splitlines()), 'functions': re.findall(r'^(?:static )?func (\w+)', text, re.M),
                  'resources': sorted(set(re.findall(r'res://[^"\s)]+', text)))})
output = root / 'Docs/godot-source-inventory.json'
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps({'source_commit': '92b434a43b556867e7f22ad70dd05b827d719de1',
                             'note': 'ExportUnityMigration.gd is the new migration bridge; other Godot sources retain the baseline.',
                             'files': files}, ensure_ascii=False, indent=2) + '\n')
print('Godot source inventory:', len(files), 'files')
