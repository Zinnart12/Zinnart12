# Windows x64 build

The export command builds the existing project with Unity **6000.6.5f1**, **URP 17.6.0**, **Mono** and **DirectX 11**. `MainMenu.unity` is the first build scene; `SolarSystem.unity` is second. The player starts through the configured `CosmicBootstrap` rather than an empty scene.

## Build on your Windows computer

1. Open this project in Unity 6000.6.5f1 through Unity Hub and activate a valid Unity license. The Windows Editor includes the Windows Mono player; IL2CPP/Visual Studio is not required for this Mono build. On another host platform, install **Windows Build Support (Mono)** for that exact Editor release.
2. Let packages and scripts compile. Resolve every red Console entry. Run **Cosmic → Repair URP and Solar System**, open **Cosmic → Open Solar System**, and test Play Mode.
3. Choose **Cosmic → Build Windows x64**. Alternatively, close Unity and run this command in PowerShell from the project folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\build-windows.ps1 `
  -Unity "C:\Program Files\Unity\Hub\Editor\6000.6.5f1\Editor\Unity.exe"
```

The script selects `Win64` before compilation, invokes the real `BuildPipeline.BuildPlayer`, and checks the Editor exit code. Export settings use the Windows platform profile and the shared scene list; you can inspect them in **File → Build Profiles → Windows**. The scripted export explicitly supplies both scenes, Windows x64, the Player subtarget, Mono, 1080p, Linear color and DX11. It does not depend on a manually selected custom profile.

Only a successful Unity `BuildReport`, error-free shader imports, valid scene references, and complete output publish these artifacts:

```text
CosmicSandboxBuild/
├── CosmicSandbox.exe
├── CosmicSandbox_Data/
│   ├── Managed/
│   ├── StreamingAssets/
│   └── Unity player data files
├── UnityPlayer.dll
├── UnityCrashHandler64.exe
├── MonoBleedingEdge/
├── build-manifest.json
└── Any additional libraries/plugins emitted by Unity

Releases/CosmicSandboxBuild.zip
```

Copy or extract **the entire directory**, including `MonoBleedingEdge` and all data/plugins. The EXE runs without Unity Editor. Fullscreen/windowed startup and resolution also accept standard Unity player arguments, for example:

```powershell
.\CosmicSandboxBuild\CosmicSandbox.exe -force-d3d11 -screen-fullscreen 0 -screen-width 1920 -screen-height 1080
```

The builder creates fresh staging output under `TestResults`, verifies native x64 PE files and required Mono/managed/data files, writes SHA-256 hashes for every emitted file, and packages the complete output. Existing published output is retained until the new build passes validation; a publication failure restores it. Failed builds do not publish an incomplete release. Build logs are at `TestResults/build-windows.log`.

## Launch check and visual check

On Windows, add `-SmokeTest` to the build command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\build-windows.ps1 `
  -Unity "C:\Program Files\Unity\Hub\Editor\6000.6.5f1\Editor\Unity.exe" -SmokeTest
```

This launches the actual DX11 player at 1920×1080, waits for the solar bootstrap readiness message in `TestResults/windows-player-smoke.log`, rejects observed runtime/shader exceptions or early exit, then closes the player. It verifies startup, not pixels or sustained performance. The manifest records `launchTested: false` at export time; subsequent launch evidence is kept in the separate smoke log.

Manually open the EXE afterward and check the main menu, Sun/planets/Moon/rings, starfield, zoom, focus and time controls. Inspect close-up surfaces for pink materials. A measured RTX 3050 Ti frame-rate result and complete gameplay validation require that real Windows run.

An optional Python integrity check validates all manifest hashes and every packaged ZIP member:

```powershell
python .\Tools\verify-windows-build.py .\CosmicSandboxBuild --archive .\Releases\CosmicSandboxBuild.zip
```

It fails if the build directory is absent, binaries are not x64 PE32+, dependencies are missing, files changed, or the archive is incomplete. It does not generate a build.

## Cloud build status and prerequisites

The official **6000.6.5f1 Linux Editor** is installed in this cloud. Its official Windows Mono module was downloaded from Unity's release API, verified against the published MD5 checksum `c4e2bf5faaeba75140af6ee10af78ed0`, and extracted with gzip CRC/path checks: **403 files**, including the Windows player, `UnityPlayer.dll`, Mono runtime and Editor Windows build extension. These are toolchain files, not a compiled Cosmic Sandbox game.

For a fresh cloud setup, install the module after `Tools/bootstrap-cloud.py`:

```bash
python3 Tools/install-windows-module.py
```

Unity's official Linux release lists this Windows Mono module, so cross-export to Windows is supported. Windows IL2CPP is not selected. A valid Editor entitlement is still required before importing/building. Current native cloud attempts stop at licensing with **exit 198**, before the build method can run; therefore **no verified CosmicSandbox.exe or playable Windows ZIP is currently provided**. See [VALIDATION.md](../VALIDATION.md) for actual executed checks and the current build result.

The request's remaining celestial library, black-hole/destruction, save/load, in-game graphics menu and performance targets remain separate feature/runtime acceptance work. Successful compilation or artifact validation does not establish that those systems are complete.
