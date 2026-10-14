# Cấu trúc và tiến độ Unity 6

Project: Unity 6000.0.65f1 LTS, URP 17.0.4, C#, HLSL và uGUI.
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
| `Editor/ProjectSetup.cs`, `WindowsBuild.cs` | Tạo native URP asset, material và build Windows x64 |
| `Editor/SnapshotImporter.cs` | Kiểm tra/import JSON snapshot, không sửa file nguồn |
| `StreamingAssets/PresetCatalog.json` | 9 preset và thông số thiên thể, giữ đủ metadata compact |
| `StreamingAssets/NBodyReferenceSteps.json` | Oracle một bước và bit tham chiếu độc lập, không sinh lại bằng solver đang test |

Preset và bộ oracle được giữ nguyên từng byte từ checkpoint trước khi gỡ
engine cũ. Nguồn lịch sử: commit `eba6ef542fc167869f07557544f5b58fd4147182`.
Project hiện tại không cần source hoặc công cụ của engine cũ để đóng gói/test.

## Hierarchy

```text
MainMenu.unity / Sandbox.unity
  Cosmic Bootstrap
  Universe (UniverseManager, Volume, SpaceBackground)
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
| 1 — Foundation | CPU/reference/energy/FPS/double; Unity import + 5 PlayMode tests | Independent checks pass; native runtime thiếu license |
| 2 — Interactive Sandbox | Add/Delete/Replace/Clone/Save/Load; Sun Removed qua UI | Chưa bắt đầu |
| 3 — Destruction | Collision conservation, physical debris, tidal stages, intact SMBH capture | Chưa bắt đầu |
| 4 — Graphics | Native GPU pixels, lensing/photon/shadow, evolving plasma, controlled HDR | Chưa bắt đầu; surface HLSL nền đã có |
| 5 — Advanced Objects | Neutron/pulsar/comet/galaxy/supernova có logic và model limits | Chưa bắt đầu |
| 6 — Optimization | Jobs/Burst/Barnes–Hut so với exact solver; hardware benchmark; Windows build/run | Chưa bắt đầu |

Test Sun Removed và thay nguồn cùng mass hiện chứng minh core Newton,
chưa chứng minh UI Delete/Replace của Phase 2. Native tests qua
`Tools/test-unity.ps1` là bước tiếp theo sau khi Editor được kích hoạt hợp lệ.
