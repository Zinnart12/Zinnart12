# Kết quả kiểm tra — 14/10/2026

Đây là checkpoint **source Phase 1**, chưa phải game Unity hoàn chỉnh hoặc
bản Windows EXE. Môi trường Linux cloud có Unity Editor chính thức nhưng
chưa được kích hoạt license.

| Kiểm tra đã thực hiện | Kết quả |
| --- | --- |
| .NET 8.0.426 / Roslyn, core C# engine không tham chiếu Unity | 29 bài test pass |
| Quỹ đạo elip e=0.6, 5 năm, năng lượng Newton | Drift lớn nhất `3.806739685e-6` |
| Clock 30 FPS vs 60 FPS, cùng thời gian, không giới hạn CPU | Cùng số bước, thời gian và tọa độ bit-identical |
| Ngân sách substep và backlog | Chỉ cộng thời gian thực tính, backlog tính tiếp; pause xóa backlog |
| Xóa Sun trong core | Vận tốc giữ nguyên, thiên thể chuyển động thẳng khi không còn nguồn lực |
| Thay nguồn bằng compact cùng mass, trong direct Newton solver | Gia tốc xa không đổi |
| Dữ liệu preset | Đủ 9 preset; toàn bộ double của thiên thể giữ đúng bit qua snapshot adapter |
| Đối chiếu một bước với bộ tham chiếu độc lập | 9 oracle pass; sai số relative position/velocity < `1e-14` |
| C# API bằng DLL Editor 6000.0.65f1 + template URP thật | Core, Runtime, Editor và PlayModeTests compile, warnings-as-errors |
| HLSL bằng DXC `1.9.2609.5` + includes URP 17.0.4 thật | 16 vertex/fragment stage/variant pass, gồm starfield instancing |
| Manifest/asmdef/serialized script GUID | Khớp package bundled và component script references |
| Source ZIP giải nén thư mục sạch, không có Unity Library | Chạy lại 29 CPU, 4 C# assembly, 16 HLSL stage/variant và static project checks: pass |

Biên dịch độc lập xác nhận C# type/API và HLSL, **không** thay thế import,
Unity shader variants, serialization scene, native JSON parser hoặc pixels.
File kết quả thực tế trong `Docs/Validation`; không cộng test chưa chạy vào
29 bài CPU hoặc dùng kết quả của engine khác để báo Unity pass.

Phần engine cũ, công cụ export và các gói của engine cũ đã được gỡ. Preset và
bộ tham chiếu vẫn giữ nguyên từng byte; CPU và API compile được chạy lại sau
khi đổi đường dẫn dữ liệu và menu import. Shader không đổi so với lần kiểm
tra HLSL ở bảng trên. Tình trạng license/PlayMode/Windows vẫn như bên dưới.

## Lần chạy Unity Editor thực tế

Editor Linux 6000.0.65f1 được tải từ Unity official release API, verify checksum
archive do API cung cấp, giải nén và gọi:

```text
Unity -batchmode -nographics -quit -projectPath unity-cosmic
  -executeMethod Cosmic.Editor.ProjectSetup.Prepare -logFile TestResults/import.log
```

Tiến trình kết thúc với exit code **198** trước khi import/execute method.
Các dòng lỗi xác nhận:

```text
Error: Access token is unavailable; failed to update
Found 0 entitlement groups and 0 free entitlements matching requested entitlement ids
No valid Unity Editor license found. Please activate your license.
```

DLL typecheck và HLSL compile bên trên dùng công cụ hợp lệ độc lập;
không vượt qua hoặc bỏ qua kiểm tra license của Unity Editor.

## Kiểm tra còn chờ

- Unity package/asset import và auto tạo URP pipeline/material.
- 5 bài PlayMode: Solar System/mesh/shader, camera và SI, native JSON precision,
  Earth–Moon/Binary dynamics, pixel Sun/Earth/Jupiter thật.
- Chạy trực quan menu, camera, nhãn và UI ở 1080p/fullscreen.
- Windows x64 build bằng Mono support module và chạy toàn bộ thư mục output
  trên Windows 11. Hiện không có Unity EXE được tạo/phân phối.
- Benchmark i7-11800H/RTX 3050 Ti/RAM 16 GB; không có số đo 60 FPS.
- Test user requirements 2–9 qua UI/advanced models chờ Phase 2–5.

Vì yêu cầu mỗi phase phải chạy được trước phase sau, tiến độ dừng ở cổng
native runtime Phase 1. Source, data và test cho cổng này đã được chuẩn bị.
