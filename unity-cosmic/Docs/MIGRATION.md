# Mapping và cổng kiểm thử chuyển Godot → Unity

Baseline: Godot `92b434a43b556867e7f22ad70dd05b827d719de1` (native 0.2).
Source hiện có gồm GDScript, scene, shader, material, UI, dữ liệu và test;
mesh/texture thiên thể được sinh procedural. Không có project ZIP thiếu
hoặc mã nguồn phải suy đoán. Inventory trong `godot-source-inventory.json`
ghi 52 file, hash, hàm và resource references; bridge export là file mới.

## Kết quả kiểm tra baseline

Godot đã có Solar System/Earth & Moon/Binary, Newton velocity Verlet double,
floating origin, camera đổi thang render, ánh sáng nhiều sao, planet/star
shader, compact presets, native Save/Load và property editor. Bản Godot trước
đó đã đạt 94 kiểm tra riêng; con số này **không** được dùng như bằng chứng
Unity đã chạy.

Phần thiếu của Godot so với yêu cầu mới: phá hủy theo nhiều giai đoạn, crater
vật lý, biến dạng liên tục, khí quyển bị bóc tách, galaxy mode, supernova,
thư viện lớn, Replace/Clone/Clone Orbit, Barnes–Hut, Jobs/Burst. Tidal Godot
chỉ phân mảnh theo ngưỡng; impact thông thường chỉ hợp nhất. Spin lưu metadata,
ray renderer Schwarzschild hữu hạn và 1PN miền yếu không phải GR/Kerr đầy đủ.

## Mapping

| Godot | Unity | Trạng thái |
| --- | --- | --- |
| `project.godot` | `ProjectSettings`, `Packages/manifest.json`, `ProjectSetup.cs` | Version, URP, input, build config có source; native import chờ license |
| `CelestialBody.gd` | `Core/CelestialBody.cs`, `Double3.cs` | Chuyển dữ liệu SI, derived properties và validation |
| `GravitySolver.gd` | `Core/NBodyGravitySolver.cs` | Port công thức đối xứng/Verlet/adaptive/diagnostics; đối chiếu oracle 9 preset |
| `SimulationEngine.gd` | `Core/SimulationEngine.cs` | Load atomic, ngân sách, đồng hồ thực tính, diagnostics |
| `TimeController.gd` | `Core/TimeController.cs` | Accumulator giữ backlog; quantum không phụ thuộc FPS |
| `CollisionSystem.gd` | `Core/CollisionSystem.cs` | Chuyển baseline swept contact + merge/heat; fracture Phase 3 |
| `SolarSystem.gd` | `StreamingAssets/GodotPresets.json` + `LegacyData.cs` | Giữ nguyên điều kiện đầu được xuất từ Godot |
| `CompactPresets.gd`, `NeutronStarSystem.gd` | Cùng catalog | Dữ liệu giữ đủ, runtime compact chờ Phase 3–5 |
| `SaveSystem.gd` | `ExportUnityMigration.gd`, `DoubleEncoding.cs`, `Editor/LegacySaveImporter.cs` | Chuyển save an toàn và bit-preserving; runtime save mới Phase 2 |
| `UniverseManager.gd` | `Runtime/UniverseManager.cs`, `Core/FloatingOrigin.cs` | Tách physics, coordinate adapter và view |
| `CameraController.gd` | `Runtime/SpaceCameraController.cs` | Orbit/fly/focus/follow, units, clipping, input |
| `PlanetGenerator.gd` | `Runtime/PlanetGenerator.cs`, `CelestialBodyView.cs` | Procedural sphere/rings, LOD, materials |
| `StarSystem.gd` | `Runtime/SpaceBackground.cs`, `CelestialBodyView.cs` | Nền instanced và temperature color; corona/flares nâng cao Phase 4 |
| `StellarLighting.gd` | `CelestialBodyView.cs`, `SurfaceCommon.hlsl` | Flux SI và tối đa 4 nguồn; GGX/exposure hiển thị |
| `MainMenu.gd`, `SandboxUI.gd`, `BodyMarkers.gd`, `ThemeFactory.gd` | `Runtime/SandboxUIController.cs` | Menu, inspector đọc, preset/time và marker tránh overlap |
| `GraphicsMenu.gd` | `UniverseManager.SetQuality` và UI quality | Ba mức đổi render scale/MSAA/LOD/bloom; menu nâng cao Phase 6 |
| `PropertyEditor.gd` | UI editor mới Phase 2 | Chưa port, không có nút giả |
| `MainMenu.tscn`, `Sandbox.tscn`, `CameraRig.tscn` | Hai scene `.unity` và `CosmicBootstrap.cs` | Scene component serialization, runtime hierarchy |
| `Planet.tres`, `Star.tres` | `Resources/Materials/*.mat` | Unity Editor tạo native material assets từ HLSL |
| `planet/star/atmosphere/clouds/rings/starfield.gdshader` | ShaderLab/HLSL tương ứng | Source được viết lại theo URP; DXC kiểm 16 stage/variant |
| `noise.gdshaderinc`, `lighting.gdshaderinc` | `Noise.hlsl`, `SurfaceCommon.hlsl` | Port fBm/domain warping và SI lighting |
| `BlackHoleSystem.gd` | `BlackHoleSystem.cs` Phase 3 | Chờ capture ưu tiên, tidal stage, 1PN miền yếu và conservation tests |
| `BlackHoleRenderer.gd`, `BlackHole.tscn`, `BlackHoleShader.gdshader` | Renderer/HLSL/prefab Phase 4 | Chờ URP depth/opaque texture + null-ray integration validation |
| `corona/prominence/pulsar.gdshader` | Renderer/HLSL Phase 4–5 | Source Godot giữ nguyên để tiếp tục |

Không đổi đuôi file: physics Core không tham chiếu Unity; render tạo mesh,
material, uGUI và coordinate adapter theo API Unity. Các trường compact
không bị bỏ dù Phase 1 chưa bật phần dynamics tương ứng.

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

Tọa độ CPU là double SI, render là float sau trừ origin. True Size, mesh LOD,
zoom và display radius không sửa lực hay radius va chạm. Kepler chỉ dùng tạo
điều kiện đầu từ Godot, không điều khiển vị trí theo animation.

Earth & Moon có nguồn Sun ngoại vi **chỉ chiếu sáng**, giống baseline Godot.
Không thêm lực hấp dẫn ngầm. Monitor năng lượng là Newton, reset khi merge.
Baseline va chạm có nhiệt dung đại diện 1000 J/(kg·K), chưa giải EOS/fracture.

## Cổng từng phase

| Phase | Cổng phải vượt | Hiện tại |
| --- | --- | --- |
| 1 — Migration | CPU oracle/energy/FPS/double pass; Unity import + 5 PlayMode tests pass | CPU/API/HLSL/static đã pass; import bị chặn license |
| 2 — Interactive Sandbox | Phase 1 chạy; Add/Delete/Replace/Clone/Save/Load tests; Sun Removed qua UI | Chưa bắt đầu |
| 3 — Destruction | Collision momentum/mass/heat/debris; stress/material/self gravity; staged tidal + intact SMBH capture | Chưa bắt đầu |
| 4 — Graphics | Ray shadow/photon distinction, evolving plasma, day/night, controlled HDR thật trên GPU | Chưa bắt đầu; surface HLSL nền đã chuyển ở Phase 1 |
| 5 — Advanced Objects | Neutron/pulsar/comet/galaxy/supernova presets có logic và model limits | Chưa bắt đầu |
| 6 — Optimization | Jobs/Burst/Barnes–Hut so với exact solver, benchmark target, Windows build/run | Chưa bắt đầu |

Test Sun Removed hiện chứng minh **core** giữ velocity khi xóa nguồn lực.
Test thay Sun cùng khối lượng chứng minh gia tốc Newton phía xa không đổi.
Chúng chưa chứng minh UI Delete/Replace, vì hai thao tác này thuộc Phase 2.
Không sử dụng thành công CPU hoặc DXC thay cho chứng nhận game Unity chạy.

## Tiếp tục tại checkpoint

1. Cung cấp môi trường Editor được kích hoạt hợp lệ bằng Unity Hub hoặc cơ chế
   license Unity hỗ trợ. Không nhập password/token vào source hoặc chat.
2. Chạy `Tools/test-unity.ps1`; sửa mọi lỗi import/scene/shader/pixel.
3. Khi PlayMode pass, ghi kết quả và giữ checkpoint Phase 1; bắt đầu Phase 2.
4. Giữ cùng solver/oracle và bổ sung test phù hợp mỗi phase. Đừng bỏ mất tiến
   độ Godot hoặc mô phỏng phá hủy bằng explosion thay thế bodies thật.
