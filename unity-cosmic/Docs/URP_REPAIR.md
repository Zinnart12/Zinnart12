# URP repair — Unity 6000.6.5f1 / DirectX 11

## Lỗi đã xác minh trong source

- Project trước đó ghim Editor 6000.0.65f1 và URP 17.0.4, trong khi máy người
  dùng mở 6000.6.5f1 và có thêm material/package ngoài source GitHub.
- `GraphicsSettings.m_CustomRenderPipeline` và cả sáu
  `QualitySettings.customRenderPipeline` đều bằng null. Custom shader mang
  tag URP không có pipeline phù hợp, nên có thể hiện error shader/màu hồng.
- Không có material `.mat`, URP pipeline/renderer/global asset trong source;
  mọi thứ phụ thuộc script tạo asset lần đầu. Script chỉ chạy khi chưa có
  pipeline, không sửa các Quality level nếu asset đã tồn tại.
- Không có `SolarSystem.unity`; hai scene cũ chỉ có bootstrap, không có đầy
  đủ thiên thể nhìn thấy trong Editor. Một scene `Untitled` không có bootstrap
  không thể tự tạo mô phỏng.
- API tìm object theo InstanceID đã obsolete trong Unity 6.6; test chuyển
  sang API không sắp xếp (`FindAnyObjectByType` / `FindObjectsByType()`).

Lỗi custom UI của URP Lit trên máy người dùng chưa được tái hiện từ project
đã thêm asset/package: checkout không có URP Lit material hoặc stack trace
đó. Thiếu/mismatch assembly editor, C# package errors hoặc bản URP trùng
trong `Assets` có thể làm `LitShader` không tải được. Không gọi đó là lỗi
HLSL đã chứng minh khi chưa có log của project trên máy.

## Các thay đổi

- Xác minh release chính thức `6000.6.5f1 (3ff58d469c8a)` và package đi kèm:
  URP/Core/ShaderGraph **17.6.0**, uGUI **2.6.0**, Test Framework **1.8.0**.
- Asset native pipeline, renderer, global settings và volume lấy cấu trúc
  từ template chính thức đi kèm Editor; chỉ dùng Forward trên Windows DX11.
  Bỏ SSAO sample, dữ liệu resource đã obsolete và bốn test volume component
  không có script trong package. Các GUID còn lại được kiểm tra với source
  và package bundled. Không lấy texture/game asset từ Universe Sandbox.
- Gán pipeline ngay trong ProjectSettings và `ProjectBuilder` sửa lại mọi
  mức Quality mỗi lần bắt đầu phiên Editor, dù pipeline đã tồn tại.
- Material procedural được đưa vào source. `PlanetSurfaceURP.shader` và
  `StarSurfaceURP.shader` giữ HLSL/detail/thermal/temperature logic, không
  thay bằng material đơn sắc. Custom shader dùng inspector mặc định;
  canonical URP Lit giữ editor chính thức từ package tương thích.
- `MaterialRepair` quét material trong `Assets`, chuyển Built-in/Standard
  sang URP Lit và giữ base texture/color/UV, normal, metallic/specular,
  smoothness, occlusion, emission, alpha mode. Backup `.mat` vào
  `TestResults/MaterialBackups`, ngoài thư mục asset import. Shader custom
  bị thiếu hoặc không tương thích được báo rõ đường dẫn; không gán shader
  đơn sắc để che lỗi.
- `SolarSystem.unity` chứa preview hình học procedural, material riêng mỗi
  thiên thể và camera/manager được nối. Preview là trạng thái SI ban đầu;
  khi Play, nó tắt và các view lấy vị trí thật từ solver. Không có quỹ đạo
  animation. Editor builder dùng `PlanetGenerator` để dựng lại scene/mesh.
- Build order: MainMenu (0), SolarSystem (1). Runtime không tham chiếu
  UnityEditor; build chỉ dùng DX11/Windows x64. Không claim 60 FPS khi chưa đo.

## Trên máy Windows có thêm package/material

1. Đóng Unity. Dùng source mới và giữ các asset riêng của bạn.
2. Nếu package cache/assembly vẫn xung đột, chạy:

```powershell
./Tools/repair-urp.ps1 -ClearShaderCache
```

Script lưu backup manifest/lock, sửa đúng năm package liên quan và giữ
khai báo package khác. Chỉ xóa cache khi chọn switch; không xóa `Assets`
hoặc source/DLL của bạn. DLL/URP code trùng trong `Assets` cần được xác định
và xử lý riêng; sửa lỗi đỏ đầu tiên trong Console trước khi lỗi GUI thứ cấp.

3. Mở bằng Unity 6000.6.5f1 và chờ resolve/compile.
4. Chọn **Cosmic → Repair URP and Solar System**. Builder xác nhận class
   `LitShader`, kiểm tra toàn bộ material và pipeline; báo chính xác asset
   còn lỗi. Material/shader riêng chưa cung cấp source không được tự viết
   lại hoặc coi là đã sửa thành công.
5. Chọn **Cosmic → Open Solar System**, rồi **Play**. Nếu cần tạo lại scene,
   **Cosmic → Rebuild Solar System Scene** (scene này là file được tạo lại).
6. Chạy Test Runner EditMode/PlayMode hoặc `Tools/test-unity.ps1`; sau khi
   pass, **Cosmic → Build Windows x64**.

Cloud đã có đúng Editor 6.6 nhưng activation thiếu entitlement, exit 198.
Vì vậy native import, việc tạo inspector, scene/mesh deserialization và
framebuffer vẫn chưa được chạy; compiler/HLSL/GUID checks không thay thế chúng.
