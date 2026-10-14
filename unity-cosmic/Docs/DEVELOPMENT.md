# Cấu trúc và tiến độ Unity 6

Project: Unity 6000.6.5f1, URP 17.6.0, C#, HLSL và uGUI.
Source Phase 1 được kiểm tra độc lập; native PlayMode còn chờ Unity license.
Không chuyển sang Phase 2 cho đến khi cổng chạy scene/pixel của Phase 1 pass.

## Module

| Thành phần | Nhiệm vụ |
| --- | --- |
| `Core/CelestialBody.cs`, `Double3.cs` | Trạng thái và thuộc tính thiên thể bằng double SI |
| `Core/NBodyGravitySolver.cs` | Lực từng cặp đối xứng, Velocity Verlet, adaptive step, diagnostics |
| `Core/SimulationEngine.cs`, `CollisionSystem.cs` | Load atomic, tích phân thực tính, swept contact, inelastic merge và heat |
| `Core/TimeController.cs` | Accumulator và quantum độc lập FPS, giữ backlog ngân sách CPU |
| `Core/FloatingOrigin.cs` | Trừ double origin trước chuyển sang render float |
| `Core/LegacyData.cs`, `DoubleEncoding.cs` | Snapshot schema 1 và IEEE-754 bit preservation |
| `Runtime/UniverseManager.cs`, `CosmicBootstrap.cs` | Nối core, prefab, camera, material và scene |
| `Runtime/SpaceCameraController.cs` | Orbit/fly, smooth zoom, focus/follow, units và clipping |
| `Runtime/PlanetGenerator.cs`, `CelestialBodyView.cs` | Procedural mesh, LOD, spin, SI lighting và trail |
| `Runtime/SpaceBackground.cs` | 4.096 sao nền instanced |
| `Runtime/SandboxUIController.cs` | Menu, inspector đọc, danh sách, marker và điều khiển thời gian |
| `Editor/ProjectBuilder.cs`, `MaterialRepair.cs`, `SolarSystemBuilder.cs` | Repair package/pipeline/material, dựng scene và kiểm tra build |
| `Editor/WindowsBuild.cs` | Windows x64 / DirectX 11 build |
| `Editor/SnapshotImporter.cs` | Kiểm tra/import JSON snapshot, không sửa file nguồn |
| `StreamingAssets/PresetCatalog.json` | 9 preset và thông số thiên thể, giữ đủ metadata compact |
| `StreamingAssets/NBodyReferenceSteps.json` | Oracle một bước và bit tham chiếu độc lập, không sinh lại bằng solver đang test |

Preset và bộ oracle được giữ nguyên từng byte từ checkpoint trước khi gỡ
engine cũ. Nguồn lịch sử: commit `eba6ef542fc167869f07557544f5b58fd4147182`.
Project hiện tại không cần source hoặc công cụ của engine cũ để đóng gói/test.

## Hierarchy

```text
MainMenu.unity / SolarSystem.unity
  Cosmic Bootstrap
  SimulationManager (UniverseManager, Volume, SpaceBackground)
    Celestial Body [prefab]
      Axial Rotation [LODGroup]
        Surface LOD 0 / 1 / 2
        Atmosphere / Cloud Layer / Grain Rings (khi phù hợp)
    Integrated Orbit Trails
  Space Camera (Camera, UniversalAdditionalCameraData, controller)
  Sandbox UI (Canvas, scaler, raycaster)
    Header / Objects / Inspector / Time Toolbar / Markers / Main Menu
  EventSystem
```

CPU dùng mét, kg, giây, m/s và K. Mesh radius, camera và True Size không sửa
radius va chạm hoặc lực. Trails ghi vị trí đã tích phân; không dùng animation
quỹ đạo. Earth & Moon có Sun ngoại vi chỉ chiếu sáng, không có lực hấp dẫn ngầm.

Va chạm hiện hợp nhất không đàn hồi và dùng nhiệt dung đại diện 1000 J/(kg·K).
Đây chưa phải fracture/SPH/EOS. HLSL surface đã có nền procedural, nhưng
scattering và mây vẫn là lớp mesh xấp xỉ. Compact runtime chưa bật; dữ liệu
được lưu để triển khai capture/tidal/ray renderer ở các phase tiếp theo.

## Cổng từng phase

| Phase | Cổng kiểm thử | Hiện tại |
| --- | --- | --- |
| 1 — URP/Import repair | C# dependency/analyzer/module, YAML/asmdef, material/shader import | Independent checks pass; native import chờ license |
| 2 — Solar/camera | Sun/8 planets/Moon/rings, camera, starfield và 6 PlayMode tests | Source đã có; native scene/pixel chưa chạy |
| 3 — Library | Moons, dwarf planets, additional planet types, compact stars, clusters/nebulae/galaxies | Chờ cổng chạy scene; hiện Solar 10 bodies và 3 preset được bật |
| 4 — Sandbox physics | Jobs/Burst, Add/Delete/Replace/Clone, editable inspector, SI trajectory tests | Newton/Verlet double nền đã có; interactive expansion còn chờ |
| 5 — Compact/destruction | Ray lensing, tidal stages, fracture/heat/debris và intact SMBH capture | Chưa bắt đầu runtime |
| 6 — Graphics/performance | Corona/flares, nebula, advanced scattering và hardware optimization | Procedural shader/LOD/instancing nền đã có; phần nâng cao chờ |
| 7 — Windows release | Save/load acceptance, real EXE/export/run và fullscreen/resolution | Exporter và module đã có; actual export thoát 198 vì license |
| Performance validation | RTX 3050 Ti / i7-11800H / 1080p benchmark | Chưa đo |

Test Sun Removed và thay nguồn cùng mass hiện chứng minh core Newton,
chưa chứng minh UI Delete/Replace của Phase 2. Native tests qua
`Tools/test-unity.ps1` là bước tiếp theo sau khi Editor được kích hoạt hợp lệ.
