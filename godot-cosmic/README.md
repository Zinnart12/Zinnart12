# COSMIC SANDBOX 3D — Graphics & Black Hole Update

Game native **Godot 4.6.3 Standard / GDScript / Forward+ Vulkan**, bản 0.2.
Sửa trực tiếp nền tảng Phase 1, giữ Solar System, Earth & Moon, Binary Stars
và solver Newton velocity Verlet. Không cần HTML, JavaScript, Electron,
Three.js, .NET, extension hoặc asset tải thêm để chạy dự án Godot.

## Tải và chạy

- Windows 10 x86-64: tải `releases/cosmic-godot-windows.zip`, giải nén,
  mở **CosmicSandbox.exe**, chọn **ENTER SANDBOX**. EXE nhúng PCK.
- Source: giải nén `releases/cosmic-godot-source.zip`, import
  `CosmicSandboxGodot/project.godot` bằng **Godot 4.6.3 Standard**.
- **F5** mở menu; mở `scenes/Sandbox.tscn` rồi **F6** chạy sandbox trực tiếp.
  CameraRig và BlackHole là scene thành phần được sandbox tạo/kết nối.
- Driver Vulkan phù hợp cần được cài trên Windows. **F11** đổi fullscreen.
  Viewport thiết kế 1920×1080; cửa sổ mặc định 1280×720.

Bản xuất đã kiểm tra cấu trúc PE, PCK và source; môi trường Linux cloud
chưa chạy EXE trên Windows 10 và chưa benchmark RTX 3050 Ti. Xem
[VALIDATION.md](VALIDATION.md) để phân biệt các kiểm tra đã chạy.

## Nguyên nhân lỗi đã xác minh

Ảnh baseline Forward+ cho thấy Sun ở góc nhìn toàn hệ chỉ khoảng 0.79 pixel
bán kính; Earth khoảng 0.013 pixel. Camera lấy khung toàn hệ đến Neptune,
trong khi Earth/Moon còn chia sẻ giới hạn visual scale để tránh chồng mesh.
Tên hiện được không có nghĩa mesh đã đủ lớn để thấy.

Shader sao cũ bật `unshaded`, đặt `ALBEDO=0` và chỉ ghi `EMISSION`. Nhánh
unshaded của [Godot 4.6.3](https://github.com/godotengine/godot/blob/4.6.3-stable/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L2980)
trả `albedo`, khiến photosphere đen. Test cũ lấy vùng pixel cố định và có
thể lẫn nhãn/UI, nên đã bỏ sót lỗi. Shader mới dùng emission trong pipeline
spatial có lighting; test lấy pixel từ vị trí mesh chiếu qua camera và ẩn
nhãn/marker khi đo bề mặt.

Cận cảnh vật thể compact với đơn vị render cố định còn làm near/far quá
chênh lệch, gây lỗi `RenderingLightCuller.prepare_camera` và cảnh đen.
Camera mới dùng floating origin **và thay đổi đơn vị render** khi focus
vật thể nhỏ; clipping dựa trên khoảng cách quan sát. Billboard trước đây
bỏ mất scale của MODEL_MATRIX; đã sửa để corona và đĩa không bị cắt cạnh.

Hố đen chưa tồn tại trong source Godot cũ. Bản này có module vật lý,
renderer ray, scene, UI và preset thực sự nối vào engine.

## Điều khiển và công cụ

| Thao tác | Kết quả |
| --- | --- |
| Kéo chuột trái | Xoay Orbit / nhìn quanh Fly |
| Nhấp mesh hoặc marker | Chọn thiên thể |
| Double-click tên / F / Focus | Cận cảnh và theo dõi; tự tính khung theo bán kính/FOV |
| Cuộn chuột | Zoom mượt theo log khoảng cách; đổi tốc độ Fly |
| WASD / Q E | Fly trước/sau/trái/phải/lên/xuống |
| Shift | Bay nhanh gấp 4 |
| C | Orbit / Fly |
| R / Overview | Căn khung toàn hệ; Binary có cả hai sao |
| Space / Pause / Play | Dừng / tiếp tục vật lý |
| Step | Tích phân theo ngân sách, không nhảy thời gian chưa tính |
| Time speed | 0.001 giây/giây đến 1 năm/giây |
| Search | Lọc danh sách thiên thể |
| Add Object | Thêm loại đang chọn vào mảng N-body với trạng thái SI |
| Delete Object | Xóa thiên thể đã chọn |
| Mass field / slider | Chỉnh khối lượng hấp dẫn; Rs tự cập nhật với hố đen |
| Edit Physical State + Enter | Sửa bán kính, nhiệt độ, sức bền, chu kỳ quay, vị trí, vận tốc |
| Accretion Disk | Bật/tắt phát xạ plasma của hố đen đã chọn |
| True size | Bán kính render đúng vật lý; không sửa bán kính va chạm |
| Save / Load | Lưu/khôi phục trạng thái double và thông số compact |
| Debug renderer | Renderer/GPU, shader đang dùng, lý do mesh ngoài khung hoặc quá nhỏ |

Các marker có kích thước màn hình tối thiểu, hỗ trợ chọn từ xa cả khi True
Size bật. Chúng là biểu tượng chọn, không phải hành tinh phóng to vật lý.
Bán kính biểu kiến phóng đại khi True Size tắt chỉ ảnh hưởng renderer.
Nhãn tránh các nhãn trước đó và panel UI; một số nhãn có thể được ẩn khi
vùng quá chật. Vệt ghi vị trí đã tích phân, không phải quỹ đạo animation.

Add Object có Earth, Black Hole, Sagittarius A*, Stellar Black Hole,
Supermassive Black Hole, Neutron Star, Pulsar, White Dwarf, Asteroid. Vật
thể được đặt cạnh đối tượng đã chọn và có vận tốc ban đầu; có thể sửa
position/velocity bằng ba thành phần SI `x, y, z` trong inspector.

Presets: Solar System, Earth & Moon, Binary Stars, Black Hole Observatory,
Earth vs Black Hole, Solar System vs Black Hole, Neutron Star vs Black Hole,
Binary Black Hole, Black Hole Accretion Disk. Encounter compact mặc định
0.01 giây/giây để quan sát; điều kiện ban đầu minh họa, không phải ephemeris
JPL hoặc quỹ đạo S2 đã fit theo quan sát.

## Đồ họa và ánh sáng

- Nguồn sao dùng `L = 4πR²σT⁴`, `F = L/(4πd²)` theo SI. Bề mặt nhận tối đa
  bốn nguồn sáng mạnh nhất, với Lambert + Cook–Torrance/GGX và ánh sáng
  gián tiếp rất nhỏ. Flux được nén exposure trước hiển thị, không sửa vật lý.
- Earth: địa hình procedural, đại dương/specular, normal detail, băng theo
  nhiệt độ, mây chuyển động, đèn đêm, khí quyển và sắc bình minh/hoàng hôn.
  Đây là lục địa procedural, không phải bản đồ địa lý Trái Đất chính xác.
- Jupiter: dòng khí thay đổi theo vĩ độ, dải mây noise, Great Red Spot.
  Saturn: vành đai noise/grain, Cassini gap, bóng hành tinh/vành đai giải tích.
  Mars: đá đỏ, chi tiết miệng hố procedural, khí quyển mỏng.
- Sao: granulation, starspots, photosphere thay đổi theo thời gian, corona
  billboard và prominence 3D. Photosphere được chuẩn hóa exposure để giữ
  chi tiết; không phải ảnh phổ đo tuyệt đối.
- Pulsar: khối lượng/bán kính thật, bề mặt nóng, quay thật theo chu kỳ,
  trục từ nghiêng và hai beam hình nón. Beam là hiệu ứng thị giác, không
  phải solver từ thủy động lực hoặc tính bức xạ phổ đầy đủ.
- Hố đen: numerical ray paths, shadow, ảnh đĩa phía sau/phía dưới, plasma
  3D noise/fBm/domain warp, shear Kepler theo bán kính, density/temperature,
  optical depth `1-exp(-τ)`, Doppler `g⁴`, gravitational redshift.
  Photon images xuất hiện từ đường tia, không vẽ một vòng sáng cố định.
- MultiMesh tối đa 4.096 sao nền, LOD mesh, frustum culling của Godot,
  ACES/HDR và glow có giới hạn. Sao nền dùng alpha scissor để có mặt trong
  screen/depth buffer phục vụ lensing.

Earth & Moon là bài toán hấp dẫn hai vật thể. Preset này dùng một Mặt Trời
ngoại vi tại 1 AU **chỉ làm điều kiện chiếu sáng**, không thêm khối lượng
ngầm vào solver. Solar System dùng vị trí Sun thật để chiếu sáng Earth/Moon.

Graphics có preset Performance/Balanced/Ultra và các điều khiển thật:
render scale, MSAA, TAA Forward+, glow, exposure, bóng giải tích, chi tiết
mesh/noise, corona/beam/sao nền, số bước ray hố đen, LOD, VSync và FPS limit.
HDR là pipeline nội bộ Forward+, không tuyên bố hỗ trợ HDR10 màn hình.
Procedural texture quality chỉnh chi tiết shader; dự án không có bộ image
texture để đổi độ phân giải. Balanced có thể giảm render scale xuống 0.55
khi FPS thấp. Ray budget là 112/192/320 bước tùy mức chất lượng.

## Vật lý và giới hạn mô hình

CPU dùng mét, kg, m/s, giây, K và **PackedFloat64Array/float64**. Standard
Godot Vector3 là float32: trừ origin bằng double rồi mới chuyển sang Vector3.
Renderer khởi đầu 32 đơn vị/AU, đổi thang khi cận cảnh; sự thay đổi này không
đụng vào khối lượng, bán kính, vị trí hoặc vận tốc vật lý.

Newton solver gốc giữ nguyên công thức đối xứng từng cặp và velocity Verlet.
Bước tối đa 3.600 s, giảm theo thời gian động lực và vận tốc tương đối. Ngân
sách mặc định 256 substeps/6 ms mỗi frame; UI báo tốc độ bị giới hạn, đồng
hồ chỉ cộng thời gian đã tích phân. Solver trực tiếp O(N²), tối đa 128 bodies.

Hố đen không quay trong metric hiển thị:

```text
Rs = 2GM/c²
photon sphere = 1.5 Rs
shadow impact radius (observer xa) = sqrt(27)/2 Rs ≈ 2.598 Rs
Δa_tidal ≈ 2GM R_body / d³
stress_tidal ≈ ρ Δa_tidal R_body
resistance ≈ strength + ρ G M_body / R_body
```

Bắt giữ kiểm tra tâm vật thể vượt Rs và swept segment giữa hai bước. Không
hợp nhất hố đen bằng bán kính tiếp xúc của hành tinh. Khối lượng/động lượng
Newton của phần bị nuốt được cộng vào sink, Rs tính lại. Hai hố đen hợp nhất
khi các horizon chạm nhau theo mô hình sink. Không giải horizon chung, spin
sau merger, sóng hấp dẫn hoặc khối lượng–năng lượng bức xạ chính xác.

Nếu stress vượt resistance bên ngoài horizon, tạo tám mảnh có khối lượng,
bán kính, vị trí/vận tốc riêng; bảo toàn khối lượng, thể tích và động lượng
ban đầu. Mảnh tiếp tục chịu lực, va chạm và bị bắt giữ. Có giới hạn một thế
hệ phân mảnh và tổng 128 vật thể; không tạo mảnh nhỏ hơn độ phân giải trạng thái
1e-6 kg / bán kính 1 mm. Đây là mô hình phá hủy theo ngưỡng, không
phải SPH/EOS, fracture continuum hoặc mô phỏng spaghettification liên tục.
Không bắt buộc xé mọi hành tinh trước horizon: hố đen đủ lớn có Roche estimate
nằm trong Rs và có thể nuốt nguyên vật thể.

Weak-field 1PN test-body correction thêm precession với recoil để giữ động
lượng; chỉ dùng khi `r > 10 Rs`, `v < 0.2c`, mass ratio ≤0.01. Bên ngoài miền
này vẫn dùng Newton + capture/tidal rule; **không** gọi đó là quỹ đạo timelike
GR chính xác. Binary black holes vẫn có dynamics Newton. Monitor năng lượng
là kinetic + Newton potential, chưa bao gồm năng lượng 1PN hoặc bức xạ.

Ray shader tích phân phương trình null-orbit Schwarzschild không quay trong
đơn vị Rs, midpoint thích nghi. Miền ray hữu hạn 18 Rs, số bước hữu hạn; gần
critical orbit chưa giải vô hạn photon images. Background lensing dùng
reprojection screen/depth buffer, nên không phục hồi nguồn ngoài màn hình,
không trace chính xác mọi geometry (đặc biệt các lớp trong suốt) qua spacetime và không giải metric nhiều
hố đen. Đĩa có radiative transfer đơn giản, chưa có scattering, MHD hoặc
self-gravity của khí shader. Spin có thể lưu/chỉnh dưới nhãn **metadata (Kerr
off)**; không có Kerr metric, frame dragging hoặc quay horizon.

Nhiệt độ của Black Hole trong inspector là nhiệt độ tham chiếu **plasma đĩa**,
không phải Hawking temperature. Mean density là khối lượng/thể tích hình
học Rs; GM/R² là ước lượng Newton, không phải gia tốc proper của người đứng
sát horizon. Với sao neutron, cấu trúc degenerate là dữ liệu đại diện; chưa
có nuclear EOS. Va chạm thường vẫn hợp nhất hoàn toàn không đàn hồi với
nhiệt dung đại diện 1.000 J/(kg·K), chưa có deform/crater vật lý do impact.

## Source và lưu game

```text
scenes/    MainMenu.tscn, Sandbox.tscn, CameraRig.tscn, BlackHole.tscn
scripts/   UniverseManager.gd, CelestialBody.gd, CameraController.gd,
           BlackHoleRenderer.gd
systems/   GravitySolver.gd, SimulationEngine.gd, CollisionSystem.gd,
           BlackHoleSystem.gd, NeutronStarSystem.gd, StellarLighting.gd,
           PlanetGenerator.gd, StarSystem.gd, TimeController.gd, SaveSystem.gd
shaders/   planet/star/atmosphere/clouds/rings/corona/prominence/pulsar,
           BlackHoleShader.gdshader, noise/lighting include, starfield
ui/        MainMenu.gd, SandboxUI.gd, GraphicsMenu.gd, BodyMarkers.gd,
           PropertyEditor.gd, ThemeFactory.gd
presets/   SolarSystem.gd, CompactPresets.gd
materials/ Planet.tres, Star.tres
assets/    icon.svg
tests/     PhysicsTests, SceneTests, CompactPhysicsTests,
           CompactSceneTests, GraphicsTests
tools/     test.sh, test.ps1, PackageRelease.gd
releases/  source ZIP, Windows ZIP, SHA256SUMS.txt
```

Save dùng native Variant, `get_var(false)` không khởi tạo object tùy ý,
validation trước khi áp dụng, atomic replacement, giữ nguyên bit double.
Save Phase 1 còn đọc được; thuộc tính compact mới có default. File Windows:
`%APPDATA%\Godot\app_userdata\Cosmic Sandbox 3D\cosmic-sandbox.csu`.
Các test dùng file riêng, không ghi đè save người chơi.

## Kiểm thử và export lại

PowerShell tại thư mục có project.godot:

```powershell
$godot = "C:\Tools\Godot_v4.6.3-stable_win64.exe"
./tools/test.ps1 -Godot $godot
& $godot --path . --script res://tests/GraphicsTests.gd
```

Graphics tests cần renderer thật, không thêm `--headless`; ảnh ở
`user://captures` hoặc thư mục `COSMIC_CAPTURE_DIR` được đặt trước khi chạy.

Cài **Export Templates 4.6.3** trong Editor → Manage Export Templates.
Project → Export → Windows Desktop → Export Project, bỏ Export With Debug.
Hoặc:

```powershell
& $godot --headless --path . --editor --import --quit
& $godot --headless --path . --export-release "Windows Desktop" "builds/windows/CosmicSandbox.exe"
& $godot --headless --path . --script res://tools/PackageRelease.gd
```

Các ZIP mới thay gói tên Phase 1; bản cũ vẫn có trong lịch sử GitHub.
Preset export Embed PCK, Windows x86-64; cloud giữ PE resource của template
để không cần Wine/rcedit. Hai file license Godot đi cùng bản phân phối.
