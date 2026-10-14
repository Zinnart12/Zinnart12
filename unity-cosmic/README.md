# COSMIC SANDBOX 3D — Unity 6.6 — URP repair

Source **Phase 1** cho Unity **6000.6.5f1**, C#, URP **17.6.0**, uGUI,
Windows x64. Đây là dự án native Unity, mở trực tiếp bằng Unity Hub.

**Trạng thái:** source Phase 1 sửa URP/scene đã được kiểm tra độc lập bằng
DLL Unity 6.6, DXC và kiểm tra GUID. Project có đầy đủ scene/material/mesh
trong source; không cần gán shader thủ công cho từng hành tinh. Play Mode còn chờ license Unity; Phase 1 chưa vượt cổng kiểm thử
chạy game. Chưa có bản Unity EXE và chưa chuyển sang Phase 2–5. Xem
[VALIDATION.md](VALIDATION.md) để phân biệt kết quả đã chạy và kiểm tra còn chờ.

Xem [Docs/URP_REPAIR.md](Docs/URP_REPAIR.md) cho nguyên nhân, cách sửa project
có material/package bổ sung và những kiểm tra native còn chờ.

## Mở dự án

1. Cài Unity Hub, kích hoạt license Unity hợp lệ trên máy của bạn.
2. Cài **6000.6.5f1** cùng **Windows Build Support (Mono)**. Version/hash được
   xác nhận từ API release chính thức của Unity.
3. Hub → Add project from disk → chọn thư mục `unity-cosmic`, hoặc
   `CosmicSandboxUnity` sau khi giải nén `Releases/cosmic-unity-phase1-source.zip`.
4. Chờ package import và C# compile. Project đã có URP renderer, pipeline, material và preview đầy đủ.
   Chọn **Cosmic → Repair URP and Solar System** để kiểm tra/sửa các material
   bổ sung và gán pipeline cho mọi mức Quality.
5. Mở `Assets/Scenes/MainMenu.unity` rồi nhấn **Play**. Hoặc mở
   `Assets/Scenes/SolarSystem.unity` để vào Solar System trực tiếp.

Source có scene `.unity`, prefab `.prefab`, `.meta` GUID ổn định, asmdef,
package manifest và Editor build scripts. Dữ liệu thiên thể và bộ kết quả tham
chiếu được đóng gói sẵn trong project, không cần công cụ chuyển đổi bên ngoài.

## Nội dung Phase 1

- Solar System: Sun, Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus,
  Neptune và Moon; Earth–Moon barycenter và toàn hệ barycentric.
- Earth & Moon và Binary Stars dùng điều kiện đầu SI đã được kiểm tra.
- CPU dùng `double`/`Double3`, mét, kg, giây, m/s, K. Lực hấp dẫn từng cặp đối
  xứng, Velocity Verlet, substep thích nghi, diagnostic năng lượng/động lượng.
- Clock tích lũy thời gian; ranh giới tích phân không theo FPS. Backlog do ngân
  sách CPU được giữ để tính tiếp, UI báo `solver backlog`; không nhảy đồng hồ
  qua phần chưa tích phân. Pause và đổi preset xóa backlog.
- Baseline va chạm swept-sphere hợp nhất không đàn hồi, bảo toàn khối lượng,
  động lượng, thể tích và tăng nhiệt. Phân mảnh/miệng hố vật lý là Phase 4.
- Camera orbit/fly, zoom mượt, focus/follow, floating origin và thay đổi đơn vị
  render để nhìn cận cảnh. Trừ tọa độ double trước khi chuyển `Vector3` float.
- UI menu, danh sách thiên thể, inspector vật lý, preset, Pause/Play, Step,
  Slow/Fast, True Size, Trails, Labels và ba mức chất lượng đều nối logic thật.
- Shader HLSL cho URP: planet procedural, đại dương/GGX, băng, đèn
  đêm, đá/hố màu procedural, dải khí/Great Red Spot, granulation sao, lớp mây,
  khí quyển mỏng và vành Saturn. ACES, HDR và bloom có giới hạn.
- 4.096 sao nền instanced, mesh LOD và frustum culling. Trails lưu vị trí đã
  tích phân; marker là hỗ trợ chọn ở xa, không phải bán kính vật lý.

Các hình bề mặt là procedural, không phải dữ liệu địa hình NASA/JPL. Khí
quyển và mây là lớp mesh xấp xỉ; chưa phải solver khí hậu hoặc volumetric
scattering đầy đủ. Emission/irradiance gắn với nhiệt độ và flux SI, nhưng
exposure hiển thị được nén để giữ chi tiết; không phải phổ bức xạ đo tuyệt đối.

## Điều khiển

| Thao tác | Kết quả |
| --- | --- |
| Kéo chuột trái | Orbit hoặc nhìn quanh Fly |
| Click mesh / marker / danh sách | Chọn thiên thể |
| Wheel | Zoom mượt / thay tốc độ Fly |
| WASD, Q/E; Shift | Bay tự do; tăng tốc ×4 |
| F | Focus và theo dõi thiên thể đã chọn |
| R | Khung toàn hệ |
| C | Orbit / Fly |
| Space | Pause / Play |
| F11 | Fullscreen / windowed |
| Escape | Menu / tiếp tục |

## Dữ liệu và tiến độ phát triển

Toàn bộ **9 preset** được giữ trong
`Assets/StreamingAssets/PresetCatalog.json`, gồm thông số hố đen, pulsar, sức
bền, spin metadata và disk flag. Phase 1 chỉ bật ba preset không compact.
Các preset compact được lưu để tiếp tục Phase 3–5; runtime chủ động từ chối
load chúng khi capture/tidal/renderer chưa được chuyển, tránh mô phỏng sai.

`DoubleEncoding` đọc `_bits` IEEE-754 little-endian kèm giá trị JSON để giữ
nguyên bit, kể cả signed zero. Snapshot được kiểm tra schema/range trước
khi áp dụng. Bộ tham chiếu độc lập nằm trong `NBodyReferenceSteps.json`.

Trong Unity chọn **Cosmic → Import Validated Snapshot JSON** để kiểm tra và
lưu JSON schema 1 trong `StreamingAssets/ImportedSaves`. Đây là công cụ dữ liệu;
Add/Delete/Replace/Clone thuộc Phase 2; Save/Load trong game thuộc Phase 5.

[Docs/DEVELOPMENT.md](Docs/DEVELOPMENT.md) có cấu trúc module, giới hạn và
cổng kiểm thử từng phase. Project và ZIP source chỉ chứa nền tảng Unity.

## Kiểm thử

Không cần Unity license cho các kiểm thử CPU với .NET 8 SDK:

```powershell
dotnet run --project Tools/CoreTests.csproj -- .
```

Cloud Linux bị hạn chế named mutex của CLI dùng `bash Tools/test-core.sh`
để gọi Roslyn trực tiếp. `Tools/bootstrap-cloud.py` cài các công cụ chính thức
đã kiểm checksum vào cache writable; không kích hoạt license Unity.

Với Editor có license trên Windows:

```powershell
./Tools/test-unity.ps1 -Unity 'C:/Program Files/Unity/Hub/Editor/6000.6.5f1/Editor/Unity.exe'
```

Hoặc Window → General → Test Runner → EditMode/PlayMode → Run All. Có ba
test Editor (Quality, Lit inspector/material conversion, solar hierarchy) và năm test scene,
focus/SI, JSON double, preset và pixel thật của Sun/Earth/Jupiter. Bài pixel
cần GPU/cửa sổ hiển thị, không dùng `-nographics`. Kết quả/ảnh vào
`TestResults`, không ghi đè save người chơi.

## Build Windows x64

Sau khi PlayMode pass, chọn **Cosmic → Build Windows x64** hoặc:

```powershell
./Tools/build-windows.ps1 -Unity 'C:/Program Files/Unity/Hub/Editor/6000.6.5f1/Editor/Unity.exe'
```

Output: `Builds/Windows/CosmicSandbox.exe`. Phân phối **toàn bộ thư mục**
Windows gồm EXE, UnityPlayer.dll và dữ liệu đi kèm. Build script kiểm tra
Windows support module và `BuildReport`; không báo thành công khi build lỗi.

Chưa benchmark trên i7-11800H / RTX 3050 Ti / RAM 16 GB hoặc chạy Windows 11.
60 FPS/1080p là mục tiêu kiểm thử hiệu suất cuối dự án, chưa phải kết quả đo.
