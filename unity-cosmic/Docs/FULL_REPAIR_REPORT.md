# Unity 6000.6.5f1 — compiler, scene and Windows export repair

## Lỗi được xác minh

| Lỗi | Nguyên nhân | Sửa chữa và kiểm tra |
| --- | --- | --- |
| CS0103 ScreenCapture | Manifest thiếu com.unity.modules.screencapture; compiler cũ nạp mọi DLL nên che lỗi module | Bật module 1.0.0; compiler mới bỏ module tái hiện đúng lỗi trong test thật |
| UAC0005 AppDomain.GetAssemblies | Quét assembly không qua registry Unity | TypeCache tìm Lit inspector; analyzer Unity Common/LongLiving thật kiểm tra warnings-as-errors |
| GPU Resident Drawer Console warning | GRD bật cùng renderer Forward; URP 17.6 yêu cầu Forward+/Deferred+ | Tắt trong pipeline asset và mỗi lần repair; thêm dependency GPUDriven.Runtime cho Editor setter |
| Mất độ chính xác render khi zoom xa sau F | Camera giữ scale cận cảnh, tọa độ float tăng lớn khi ra toàn hệ sao | Adaptive scale, vẫn giữ double SI/origin; thêm test camera ở 25 AU |
| Pixel test thất bại trong batch | WaitForEndOfFrame không chạy trong Editor batch mode | Chạy PlayMode với Editor/Game View/GPU; chỉ import/EditMode dùng batch/nographics |
| Safe Mode trước đó | TagManager serialization và explicit/implicit TestRunner trùng | Giữ bản sửa template, 32 slots và TestAssemblies references |

C# checker hiện đọc manifest, dependency package được bật, asmdef trực tiếp
và analyzer thật; không còn coi mọi DLL trong Editor là dependency hợp lệ.
Cả năm assembly đã biên dịch với warnings-as-errors. Hai kiểm tra âm bằng
compiler thật tái hiện CS0103 và UAC0005. Đây chưa phải native import.

## Những phần giữ nguyên

MainMenu, SolarSystem, Sun/8 hành tinh/Moon/rings, procedural planet/star/
atmosphere/cloud/ring shaders và material, starfield instancing, LOD, camera,
menu/inspector/time controls, SI double Newton/Verlet, collisions hợp nhất,
floating origin, toàn bộ preset/reference data và GUID đã có. Không tạo
project trống mới, không đổi material thành cầu đơn sắc để che lỗi.

## Build thật đã thử

Đã cài WindowsStandaloneSupport Mono từ release API chính thức Unity 6.6:
378,085,188 bytes, MD5 c4e2bf5faaeba75140af6ee10af78ed0, 403 file.
Unity được gọi với -buildTarget Win64 và Cosmic.Editor.WindowsBuild.Build.
Nó thoát 198 vì thiếu entitlement trước import/executeMethod. Không có EXE,
CosmicSandbox_Data, bản ZIP player hoặc kết quả mở player được tạo ra.
Xem Validation/windows-build-results.json cho trạng thái đã thực hiện.

Exporter mới tạo output trong staging, kiểm BuildReport, PE x64, data,
Mono/managed assemblies, streaming catalog và SHA256 manifest, rồi mới công
bố CosmicSandboxBuild/ và ZIP toàn bộ thư viện. Xem WINDOWS_BUILD.md.
Bộ verifier có test từ chối artifact thiếu/hỏng; pass verifier không thay
thế một lượt export Unity hoặc kiểm tra game chạy trên Windows.

## Phần mở rộng còn chờ cổng chạy scene

Theo thứ tự yêu cầu mới: repair/import -> solar/camera -> celestial library
-> Add/Delete/Replace/Clone và N-body -> black hole/tidal/collision destruction
-> graphics/optimization -> Windows build/run. Library mở rộng, editable
inspector, runtime Save/Load, compact ray rendering, phân mảnh và galaxy
simulation chưa được đánh dấu hoàn thành. Không vượt cổng native bằng cách
chỉ thêm source hoặc dùng ảnh bản web làm bằng chứng Unity đã chạy.
