#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_dotnet="${COSMIC_DOTNET_ROOT:-/workspace/.cache/cosmic-unity/dotnet}"
if [ ! -x "$task_dotnet/dotnet" ]; then
  printf 'Set COSMIC_DOTNET_ROOT to a .NET 8 SDK directory.\n' >&2
  exit 1
fi
# Invoke Roslyn directly: also works in containers that restrict named CLI mutexes.
python3 - "$task_root" "$task_dotnet" <<'PY'
import pathlib,sys,json,subprocess
root=pathlib.Path(sys.argv[1]); sdk=pathlib.Path(sys.argv[2]); out=root/'TestResults/Core'
out.mkdir(parents=True,exist_ok=True)
refs=sorted((sdk/'packs/Microsoft.NETCore.App.Ref').glob('*/ref/net8.0'))[-1]
compiler=sorted((sdk/'sdk').glob('*/Roslyn/bincore/csc.dll'))[-1]
sources=sorted((root/'Assets/Cosmic/Core').glob('*.cs'))+[root/'Tools/CoreTests.cs']
lines=['-nologo','-langversion:9','-warnaserror+','-target:exe','-out:"'+str(out/'CoreTests.dll')+'"']
lines += ['-r:"'+str(p)+'"' for p in sorted(refs.glob('*.dll'))]
lines += ['"'+str(p)+'"' for p in sources]
rsp=out/'compile.rsp';rsp.write_text('\n'.join(lines))
subprocess.run([str(sdk/'dotnet'),str(compiler),'@'+str(rsp)],check=True)
runtime=sorted((sdk/'shared/Microsoft.NETCore.App').iterdir())[-1].name
(out/'CoreTests.runtimeconfig.json').write_text(json.dumps({'runtimeOptions':{'tfm':'net8.0','framework':{'name':'Microsoft.NETCore.App','version':runtime}}}))
subprocess.run([str(sdk/'dotnet'),str(out/'CoreTests.dll'),str(root)],check=True)
PY
