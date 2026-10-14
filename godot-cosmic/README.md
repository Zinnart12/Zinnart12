# COSMIC SANDBOX 3D — Godot 4

Dự án **native Godot 4.6.3 / GDScript / Forward+ (Vulkan)**, Phase 1 chạy
được độc lập. Bản này dùng scene, mesh, shader và UI của Godot; không cần
trình duyệt hoặc thư viện của bản web trước đây.

## Chạy trên Windows 10

### Chạy game đã xuất

1. Tải `releases/cosmic-godot-phase1-windows.zip`.
2. Giải nén toàn bộ vào một thư mục.
3. Mở `CosmicSandbox.exe`, chọn **ENTER SANDBOX**.

EXE x86-64 có dữ liệu game nhúng; không phải launcher mở trang web và không
cần cài Godot để chạy. Bản xuất dùng Forward+ với Vulkan. GPU mục tiêu RTX
3050 Ti hỗ trợ renderer này khi có driver phù hợp. Nút **Graphics** chọn
Performance/Balanced/Ultra và fullscreen; **F11** đổi toàn màn hình.

### Mở mã nguồn trong editor

1. Cài **Godot 4.6.3 Standard**, bản Windows x86-64.
2. Giải nén `releases/cosmic-godot-phase1-source.zip`.
3. Trong Project Manager chọn **Import**, tìm `project.godot` bên trong.
4. Chờ editor import asset/script. Nhấn **F5** để mở menu chính.
5. Mở `scenes/Sandbox.tscn`, nhấn **F6** để chạy sandbox trực tiếp.

Không cần .NET, extension C++, plugin hoặc asset tải từ Internet để chạy
mã nguồn này. `CameraRig.tscn` là scene thành phần; sandbox và menu chính
là hai scene có thể chạy độc lập.

## Điều khiển

| Thao tác | Kết quả |
| --- | --- |
| Chuột trái + kéo | Xoay Orbit hoặc nhìn quanh trong Fly |
| Nhấp thiên thể | Chọn bằng ray–sphere picking |
| Cuộn chuột | Zoom Orbit; đổi tốc độ Fly |
| WASD / Q E | Tự chuyển sang Fly; trước/sau/trái/phải/lên/xuống |
| Shift | Bay nhanh gấp 4 |
| C hoặc Orbit / Fly | Đổi chế độ camera |
| F hoặc Focus | Theo dõi/cận cảnh thiên thể đã chọn |
| R hoặc Overview | Căn khung toàn hệ |
| Space hoặc Pause / Play | Tạm dừng/tiếp tục vật lý |
| Step | Tiến vật lý một khoảng, tối đa 1 ngày trong một yêu cầu |
| Time speed | Từ thời gian thực đến 1 năm trên giây, giới hạn bởi ngân sách tính |
| Mass field + Enter | Thay khối lượng bằng kg, chấp nhận dạng `1.98847e30` |
| Mass slider | Chỉnh khối lượng thật theo thang logarit |
| True size | Dùng bán kính hiển thị đúng tỉ lệ |
| Save / Load | Lưu/khôi phục toàn bộ trạng thái SI |

Thử chọn **Sun**, tăng khối lượng và quan sát quỹ đạo. Các hành tinh không
bị gắn vào vòng tròn/animation. Chọn **Earth & Moon** để xem quỹ đạo vệ tinh;
**Binary Stars** để xem hai ngôi sao phản ứng với hấp dẫn lẫn nhau.

Mặc định chỉ **bán kính hiển thị** được phóng đại và giới hạn theo khoảng
cách lân cận để mesh không chồng lên nhau trước tiếp xúc. Tâm thiên thể,
bán kính tiếp xúc và lực hấp dẫn vẫn dùng số liệu SI. Vệt được ghi từ vị trí
đã tích phân; chưa có vệt tương lai dựng sẵn. Bật True size rồi Focus để
quan sát các hành tinh có kích thước nhỏ.

## Những gì Phase 1 đã có

- Hệ Mặt Trời gồm Sun, Mercury, Venus, Earth, Moon, Mars, Jupiter, Saturn,
  Uranus, Neptune với dữ liệu thiên văn đại diện.
- Solver Newton N-body đối xứng theo từng cặp, velocity Verlet, timestep
  thích nghi và đồng hồ ghi đúng thời gian đã tích phân.
- Khối lượng, bán kính, vị trí, vận tốc, nhiệt độ, khí quyển, chu kỳ quay,
  nghiêng trục, thành phần; mật độ/trọng lực/vận tốc thoát được tính từ dữ liệu.
- Camera floating origin, Orbit/Fly, chọn/focus và chuyển giữa toàn hệ/cận cảnh.
- Main menu, HUD native, chỉnh khối lượng, presets, thời gian, đồ họa và lưu game.
- Bề mặt procedural, đại dương PBR, normal detail, mây, night lights,
  khí quyển Fresnel xấp xỉ, granulation sao và nhiệt phát xạ.
- 4.096 sao nền trong MultiMeshInstance3D; LOD mesh, culling của Godot,
  ACES và glow có giới hạn; Balanced giảm render scale khi FPS thấp.
- Va chạm tiếp xúc cơ bản: swept sphere + hợp nhất, bảo toàn khối lượng,
  thể tích và động lượng tuyến tính, tăng nhiệt đại diện.
- Preset xuất Windows, EXE nhúng PCK và các gói ZIP để tải.

Các giai đoạn **spawn/di chuyển/chỉnh mọi thuộc tính**, phân mảnh/miệng hố/
đá bụi có hấp dẫn, hố đen/sao neutron/GR, khí hậu và nâng cấp shader tiếp
chưa được coi là hoàn thành. Phase 1 không chứa những module rỗng giả làm
chức năng đã có. `BlackHoleSystem.gd` sẽ được thêm khi làm Phase 4; không
biểu diễn thấu kính hấp dẫn bằng một quả cầu đen ở giai đoạn này.

## Đơn vị, độ chính xác và giới hạn

CPU dùng **mét, kg, m/s, giây và kelvin**. GDScript `float` là 64-bit;
**`PackedFloat64Array`** giữ vị trí/vận tốc và scratch acceleration.
`Vector3` của engine tiêu chuẩn dùng float32, nên không được dùng làm dữ
liệu tích phân. Renderer trừ hai tọa độ double trước, sau đó mới tạo
`Vector3`, theo 32 đơn vị scene/AU. Không cần tự biên dịch Godot double để
đạt độ chính xác CPU này.

```text
aᵢ = Σⱼ G mⱼ (xⱼ − xᵢ) / |xⱼ − xᵢ|³
G = 6.67430 × 10⁻¹¹ m³ kg⁻¹ s⁻²
x(t+h) = x(t) + v(t)h + ½a(t)h²
v(t+h) = v(t) + ½[a(t)+a(t+h)]h
```

Bước tối đa 3.600 giây, giảm theo 1% thời gian động lực của cặp và giới
hạn dịch chuyển tương đối. Mỗi frame tối đa 256 substeps và khoảng 6 ms
CPU cho phần tích phân; đồng hồ không nhảy qua thời gian chưa tính.
Monitor báo khi tốc độ mong muốn vượt ngân sách. Tab/cửa sổ dừng lâu được
giới hạn catch-up 5 giây thực; physics vẫn có bước riêng với render FPS.
Solver trực tiếp O(N²); bản lưu giới hạn 128 thiên thể, chưa có Barnes–Hut.

ΔE / |E₀| theo động năng + thế năng của tất cả cặp. Thay khối lượng, tải
hoặc hợp nhất sẽ đặt lại năng lượng tham chiếu. Verlet với bước cố định
có sai số năng lượng dao động hữu hạn; bước thích nghi không giữ tính
symplectic chính xác. Preset là điều kiện ban đầu Kepler xấp xỉ, không
phải ephemeris JPL tại một thời điểm cụ thể.

Va chạm là hợp nhất hoàn toàn không đàn hồi, chưa phải SPH/fracture.
Nhiệt dung đại diện 1.000 J/(kg·K), chưa có EOS vật liệu. Chưa mô phỏng
biến dạng, mảnh vỡ, khí hậu, stellar evolution, hố đen hoặc sao neutron.
Ánh sáng scene được chuẩn hóa để nhìn rõ hành tinh, chưa giải truyền
bức xạ/tương đối rộng. Khí quyển là shell thị giác xấp xỉ, chưa phải
multiple-scattering khí quyển thiên văn.

## Lưu game

Dữ liệu tại `user://cosmic-sandbox.csu`; Windows thường nằm trong:

```text
%APPDATA%\Godot\app_userdata\Cosmic Sandbox 3D\cosmic-sandbox.csu
```

Định dạng Variant nhị phân của Godot giữ nguyên bit float64, gồm mọi
thuộc tính vật thể, tên hệ, thời điểm và số bước. Tải bằng `get_var(false)`
không cho phép dựng object từ dữ liệu. Dữ liệu được kiểm tra schema, số
hữu hạn, phạm vi, vector và ID trùng trước khi thay trạng thái. Lưu qua
file tạm rồi thay thế; UI chỉ báo thành công sau khi hoàn tất ghi.

Đường đi cũ được xóa khi tải để không nối hai trạng thái thành quỹ đạo
sai. Sai số năng lượng bắt đầu lại từ trạng thái khôi phục. Định dạng lưu
native được chọn vì parser JSON Godot có thể làm lệch một ULP với số
rất lớn; đây không phải tệp JSON đổi đuôi.

## Cấu trúc

```text
project.godot
export_presets.cfg
scenes/     MainMenu.tscn, Sandbox.tscn, CameraRig.tscn
scripts/    UniverseManager.gd, CelestialBody.gd, CameraController.gd
systems/    GravitySolver.gd, SimulationEngine.gd, CollisionSystem.gd
            PlanetGenerator.gd, StarSystem.gd, TimeController.gd, SaveSystem.gd
presets/    SolarSystem.gd
shaders/    planet, star, atmosphere, clouds, starfield (.gdshader)
materials/  Planet.tres, Star.tres
assets/     icon.svg
ui/         MainMenu.gd, SandboxUI.gd, GraphicsMenu.gd, ThemeFactory.gd
tests/      PhysicsTests.gd, SceneTests.gd, GraphicsTests.gd
tools/      test.sh, test.ps1, PackageRelease.gd
releases/   source ZIP, Windows ZIP
```

## Xuất Windows lại

Trong Godot 4.6.3: **Editor → Manage Export Templates → Download and Install**.
Sau đó **Project → Export → Windows Desktop → Export Project**, chọn
`builds/windows/CosmicSandbox.exe` và bỏ **Export With Debug**.

Preset đã dùng Windows x86-64, Forward+ Vulkan và Embed PCK. Có thể bật
Modify Resources khi môi trường editor có công cụ sửa resource Windows;
bản xuất cloud giữ nguyên PE resource của template để không phụ thuộc Wine.

PowerShell, thay đường dẫn bằng editor của bạn:

```powershell
$godot = "C:\Tools\Godot_v4.6.3-stable_win64.exe"
& $godot --headless --path . --editor --import --quit
& $godot --headless --path . --export-release "Windows Desktop" "builds/windows/CosmicSandbox.exe"
```

Để tạo lại hai ZIP và SHA256SUMS sau export:

```powershell
& $godot --headless --path . --script res://tools/PackageRelease.gd
```

## Kiểm tra

```powershell
& "C:\Tools\Godot_v4.6.3-stable_win64.exe" --headless --path . --script res://tests/PhysicsTests.gd
& "C:\Tools\Godot_v4.6.3-stable_win64.exe" --headless --path . --script res://tests/SceneTests.gd
& "C:\Tools\Godot_v4.6.3-stable_win64.exe" --path . --script res://tests/GraphicsTests.gd
```

Bộ test đồ họa cần renderer thực, không thêm `--headless`. Nó chụp menu,
Earth, Sun và Earth–Moon, kiểm tra pixel của mesh độc lập với UI và xác
nhận đang dùng Forward+. Ảnh mặc định ở `user://captures`.

16 kiểm tra vật lý + 16 kiểm tra scene/UI + 7 kiểm tra đồ họa đạt trong
cloud. Xem `VALIDATION.md`. Export Windows đã thành công, nhưng chưa chạy
EXE trên Windows 10 và chưa đo RTX 3050 Ti; không xác nhận 60 FPS từ GPU
phần mềm. `GODOT_LICENSE.txt` và `GODOT_THIRD_PARTY.txt` đi cùng bản phân phối.
