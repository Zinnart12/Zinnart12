# Unity 6.6 URP repair — kiểm tra 14/10/2026

Checkpoint **source Phase 1** cho Unity **6000.6.5f1 (3ff58d469c8a)**,
URP/Core/ShaderGraph **17.6.0**, Windows x64 **DirectX 11**. Source/material/
pipeline/scene đã được sửa; chưa chứng nhận native Play Mode hoặc Windows EXE.

| Kiểm tra thực hiện | Kết quả |
| --- | --- |
| Core double SI / Roslyn .NET 8.0.426 | 29 bài test pass |
| Elip e=0.6, 5 năm, năng lượng Newton | Drift tối đa `3.806739685e-6` |
| Clock 30/60 FPS và backlog | Cùng trạng thái, chỉ cộng thời gian đã tích phân |
| Preset, bit double và 9 Newton oracle | Pass; dữ liệu vật lý giữ nguyên |
| API với DLL **Unity 6000.6.5f1** và template URP thật | Core, Runtime, Editor, PlayModeTests, EditModeTests compile theo manifest/asmdef và analyzer Unity thật; warnings-as-errors |
| HLSL với DXC 1.9.2609.5 + includes URP 17.6.0 thật | 16 stage/variant pass, gồm instancing |
| Pipeline/quality/material/mesh/scene/package GUID | Không còn resource GUID thiếu; global và sáu Quality level có đúng pipeline |
| SolarSystem hierarchy | Sun, 8 hành tinh, Moon, Saturn rings, camera và manager được nối trong source |
| Runtime dependency scan | Không có UnityEditor import trong runtime |
| Windows artifact verifier | 8 kiểm tra từ chối artifact lỗi/thiếu và hash file phụ rỗng; không phải game build |
| Windows toolchain | 403 file module Mono chính thức, checksum hợp lệ; 4 native binary xác minh PE x64 |
| PowerShell script/report checks | 4 parser checks, 2 positive/9 rejection XML fixtures và GPU PlayMode argument guard; chưa chạy Unity/Windows |
| Safe Mode import configuration regression | 5 kiểm tra hồi quy; 32 layer/rendering-layer slots, không còn explicit/implicit TestRunner trùng |

Ảnh Console Windows do người dùng cung cấp sau commit `742492e` đã xác nhận
hai lỗi source: TagManager YAML parser và TestRunner duplicate references.
Chúng đã được sửa trong source và có kiểm tra import configuration riêng.
Kết quả biên dịch Roslyn trước đó không kiểm tra native YAML/asmdef import;
không được coi là bằng chứng Unity đã import thành công. Chưa có ảnh hoặc
kết quả native Windows sau bản vá để xác nhận Safe Mode đã thoát.

DXC kiểm tra cú pháp/type HLSL, không phải kết quả native FXC/DX11 hoặc pixel.
Static GUID/serialization checks không thay thế Unity deserialization. Không
cộng các test native chưa chạy vào số 29 bài CPU.

Kiểm tra âm bằng compiler thật: bỏ module screencapture tái hiện CS0103
trên screenshot test hiện tại; AppDomain fixture tái hiện UAC0005 với analyzer.
GPU Resident Drawer đã tắt vì renderer dùng Forward; camera có adaptive scale.
Các thay đổi này vẫn cần native import/rendering để chứng nhận Console/pixel.

## Native Unity đã thử

Editor 6.6 được tải từ Unity release API chính thức, kiểm checksum archive
do API cung cấp, cài vào cache và chạy batch import. LicensingClient trả:

```text
Error: Access token is unavailable; failed to update
Found 0 entitlement groups and 0 free entitlements matching requested entitlement ids
Error: 'com.unity.editor.headless' was not found.
Application will exit with return code 198
```

Môi trường chưa có Unity license/entitlement. Editor thoát trước import và
execute method. Sau khi cài Windows Mono module chính thức, lệnh export thật
`-buildTarget Win64 -executeMethod Cosmic.Editor.WindowsBuild.Build` cũng
thoát 198. Không có `CosmicSandboxBuild/CosmicSandbox.exe` được tạo. Trạng thái
được ghi trong `Docs/Validation/windows-build-results.json`. Không bỏ qua licensing; C# và DXC dùng công cụ độc lập hợp lệ.

## Còn chờ chạy với license hợp lệ

- Import/save/reopen native mesh/material/scene trong Unity 6.6.
- **3 EditMode tests:** tất cả Quality/DX11/build order, tạo Lit inspector và
  bảo toàn PBR khi convert, full SolarSystem hierarchy/camera.
- **6 PlayMode tests:** đủ mesh/compiled shader, focus/SI, native JSON double,
  Earth–Moon/Binary, zoom 25 AU và framebuffer Sun/Earth/Jupiter thật với UI bị ẩn.
- Chạy scene/menu/camera/marker trực quan ở 1080p, kiểm Console và pixel hồng.
- Project riêng có package/material bổ sung: chạy repair trên máy và cung
  cấp lỗi đỏ đầu tiên nếu còn lỗi. Nguồn shader/stack trace riêng chưa có
  trong checkout; không tuyên bố chúng đã được sửa hoặc được chạy.
- Windows x64 build/run và benchmark RTX 3050 Ti/i7-11800H/16 GB. Chưa có
  Unity EXE được tạo, chưa đo 60 FPS.

Library mở rộng, Jobs/Burst, editing, black hole ray renderer, staged destruction,
scenarios và runtime Save/Load được ghi trong DEVELOPMENT.md, chưa được
đánh dấu hoàn thành. Cổng native Phase 1 cần pass trước khi sang phase sau.
