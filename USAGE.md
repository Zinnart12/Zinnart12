# Event Horizon — Black Hole Observatory

Ứng dụng mô phỏng hố đen 3D bằng Three.js, WebGL2 và GLSL. Toàn bộ đĩa bồi tụ, sao và tinh vân được tạo procedural; không dùng ảnh hố đen hay ảnh đĩa 2D.

## Chạy ngay bằng một tệp HTML

Mở **`dist/index.html`** bằng Chrome, Edge hoặc Firefox hỗ trợ WebGL2 và hardware acceleration. Tệp này chứa cả Three.js, shader, JavaScript và CSS; không cần server, CDN, kết nối Internet hay API key. Có thể đổi tên thành `black-hole.html` rồi gửi sang máy khác.

`index.html` ở gốc là tệp **phát triển**, phải chạy qua Vite. Để tạo lại tệp độc lập:

```bash
cd /workspace/Zinnart12
npm ci --cache /workspace/.cache/npm --no-audit --no-fund
npm run build
```

Trên máy riêng, có thể dùng `npm ci` với cache npm mặc định. Node.js 22.12+ hoặc 24 LTS; các phiên bản phụ thuộc được khóa trong `package-lock.json`.

## Phát triển

```bash
npm run dev -- --port 5173
```

Mở địa chỉ do Vite hiển thị trên máy của bạn. Không cần backend hay dịch vụ khác. Server có hot reload. Không tạo Git worktree để chạy ứng dụng; dùng checkout hiện có vì các tác vụ cloud đã được cách ly.

`npm run preview` phục vụ bản `dist` đã build. `npm run build` dùng esbuild để tạo một tệp HTML độc lập, không tải asset ngoài.

## Điều khiển

| Thao tác | Kết quả |
| --- | --- |
| Giữ chuột trái + kéo | Orbit quanh hố đen; nhìn quanh trong Fly |
| Cuộn chuột | Zoom trong Orbit; đổi tốc độ trong Fly |
| C | Đổi Orbit / Fly |
| WASD | Bay trước/sau/trái/phải; W/S và A/D chỉnh Orbit |
| Q / E | Hạ / nâng trong Fly |
| Shift | Bay nhanh gấp 4 |
| R | Đặt lại camera, tắt tự xoay |
| Space | Pause / Resume chuyển động khí và camera cinematic |
| EDGE / TOP / BELOW | Góc nhìn ngang / trên / dưới |
| Screenshot | Tải PNG của khung nhìn, không chứa bảng điều khiển |
| Fullscreen | Toàn màn hình nếu trình duyệt cho phép |

Tất cả thanh trượt tác động đến shader hoặc tốc độ mô phỏng. Bán kính Schwarzschild và khối lượng được liên kết hai chiều, vì không thể điều chỉnh độc lập trong cùng mô hình vật lý. Mở “Horizon radius & lensing” để chỉnh bán kính và cường độ lensing. Bảng bên phải cuộn được; trên màn hình nhỏ, nút điều khiển ở góc trên mở bảng.

“Tidal assessment” là phép tính cho vật thể thử, không phải một hành tinh đã được thêm vào cảnh. Chọn Earth / Asteroid / Probe, rồi chỉnh bán kính, mật độ, sức bền kéo và khoảng cách. Các thanh trượt này cập nhật báo cáo thủy triều; không kích hoạt hoạt ảnh phá hủy.

Scientific đặt spin = 0, lensing = 1, tắt tự xoay. Cinematic tăng bloom, exposure và bật bay vòng (trừ khi hệ thống yêu cầu giảm chuyển động); có thể tắt ở Scene layers. Performance giảm bước tích phân, độ phân giải, bloom và tinh vân. Chế độ vẫn cho phép thay đổi thông số thủ công.

## Mô hình và giới hạn vật lý

- `Rₛ = 2GM/c²`, với G = 6.67430 × 10⁻¹¹ SI, c = 299792458 m/s và M☉ = 1.98847 × 10³⁰ kg. Mặc định 4.3 triệu M☉ tương ứng Rₛ ≈ 12.70 triệu km.
- Đơn vị tọa độ cảnh là Rₛ của khối lượng tham chiếu 4.3 triệu M☉. Shader chia tọa độ cho Rₛ hiện tại để luôn tích phân trong đơn vị Rₛ = 1. Camera giữ tọa độ tham chiếu khi thay đổi khối lượng, nên kích thước biểu kiến thay đổi thật.
- Với lensing = 1, tia null Schwarzschild được tích phân trong không gian 3D theo phương trình affine `x'' = -3 L² x / (2 r⁵)` trong đơn vị Rₛ = 1. Dùng velocity-Verlet ở xa và RK4 khi r < 7 Rₛ để giảm sai lệch gần quỹ đạo photon bất ổn. Chuyển đổi hướng nhìn từ tetrad cục bộ của người quan sát, theo dõi mô men góc L, hấp thụ tia tại r ≤ 1. Đây là tích phân đường đi tia sáng, không phải bộ lọc méo ảnh screen-space.
- Trường được cắt ở 40 Rₛ để giới hạn chi phí; phần ngoài được coi như thẳng. Bước tích phân phụ thuộc khoảng cách, với 96 / 144 / 216 / 320 bước tối đa. Tia chưa thoát sau ngân sách này được hấp thụ để tránh rò bầu trời. Ảnh thứ cấp và tia sát quỹ đạo photon có sai số số học; tăng quality để giảm sai số. Đây không phải công cụ đo đạc thiên văn chính xác.
- Với camera ngoài 40 Rₛ, tetrad được tính tại vị trí camera thật trước khi đưa tia đến biên. Vận tốc ở biên được khôi phục với cùng L và E = 1 để tránh đổi impact parameter; phần trường yếu bên ngoài vẫn là xấp xỉ. Kiểm thử GPU có cả người quan sát ở trong và ngoài biên.
- Đĩa là một thể tích khí có chiều cao Gaussian tăng nhẹ theo bán kính và nhiễu. Mỗi đoạn tia được cắt với slab và tích phân bằng hai điểm Gauss; bước được giảm khi xuyên qua chiều cao đĩa. Optical depth dùng chiều dài riêng của khung tĩnh, được chuyển sang khung comoving theo hệ số Doppler. Công thức truyền bức xạ xám LTE là `I += transmission × B(T) × (1-exp(-τ))`, sau đó `transmission *= exp(-τ)`. Đây không phải một mặt phẳng opaque.
- Kết cấu dùng noise 3D đa thang, fBm, domain warping và turbulence phi tuần hoàn; không còn các hàm sin theo bán kính tạo sọc. Từng lớp noise được lọc theo ray cone và đạo hàm shear ước lượng, tránh dùng đạo hàm màn hình trong vòng ray-loop phân nhánh. Có vùng mật độ khác nhau và các đốm nóng/lạnh tương quan; cả domain warping và advection tiếp tục biến đổi theo thời gian. Hai trường khí có tuổi thọ hữu hạn được hòa trộn bằng trọng số mượt, chỉ đổi seed khi trọng số bằng không; seed mới theo epoch không lặp lại. Cách này giữ chi tiết khi chạy lâu, thay vì để shear tăng vô hạn làm bộ lọc biến mọi octave thành giá trị trung bình.
- Vận tốc góc `Ω = sqrt(0.5/r³)` trong đơn vị Rₛ, với hệ số spin xấp xỉ. Advection vi sai tạo shear; dấu chuyển động của kết cấu khớp dấu vận tốc trong Doppler. Kết cấu ban đầu đã có một độ shear nhỏ thay vì bắt đầu bằng mây đẳng hướng; các lớp noise ngoài băng thông pixel được bỏ qua để giảm tải GPU. Mô hình không giải thủy động lực học, từ trường hay GRMHD. Đồng hồ thị giác dùng hệ số gia tốc để dễ quan sát chuyển động, không phải thời gian riêng hiệu chuẩn của hệ Sagittarius A*.
- Nhiệt độ lấy profile zero-torque `T⁴ ∝ x⁻³(1-x⁻¹ᐟ²)`, x = r/r_inner, chuẩn hóa ở cực đại x = 49/36. Thanh Accretion temperature đặt nhiệt độ đỉnh. Khí có thêm biến động nhiệt từ noise. Phát xạ bolometric thực sự tỉ lệ với T⁴; không chỉ đổi hue.
- Tia affine được chuyển sang hướng cục bộ tại khí trước khi tính Doppler. Hệ số `g = sqrt(f_emitter/f_observer) / [γ(1-β cosθ)]`, f = 1-1/r, bao gồm cả thế hấp dẫn tại người quan sát hữu hạn. Màu được lấy ở nhiệt độ gT, và cường độ bolometric được boost bằng **g⁴**; g³ chỉ phù hợp với cường độ phổ trên đơn vị tần số. Mật độ quyết định optical depth, không được cộng như một brightness độc lập.
- Photon sphere Schwarzschild ở **1.5 Rₛ**, chân trời ở **1 Rₛ**, và critical impact parameter của bóng ở xa là **2.598 Rₛ**. Với người quan sát tĩnh ở r > 1.5 Rₛ, góc bóng là `sin α = b_crit sqrt(1-1/r)/r`. Không coi 2.598 Rₛ là kích thước của chân trời.
- **Không còn vòng sáng Gaussian cộng lên ảnh, torus hoặc viền photon vẽ sẵn.** Các ảnh thứ cấp và photon hình thành từ khí được tia cong gặp. Công tắc Photon ring cho phép/tắt phát xạ trên phần đường tia đã quét quá π radian, tức ảnh đĩa bậc cao; nó cũng ảnh hưởng các ảnh thứ cấp thuộc nhóm này. Khi không có đĩa phát xạ, công tắc này không thể tạo ra một vòng sáng. Nền vẫn được lensing bởi tia cong. Chỉ những ảnh bậc cao được ngân sách bước/pixel phân giải mới hiện; không bù bằng vòng sáng giả.
- **Spin không triển khai metric Kerr.** Giá trị này thay đổi quay khí và biên trong phát xạ bằng công thức ISCO Kerr thuận chiều. Chân trời và đường đi ánh sáng vẫn là Schwarzschild; không có frame dragging, ergosphere hay horizon Kerr. Giao diện ghi rõ khi bật hiệu ứng này.
- Phát xạ luôn bị loại khi mẫu nằm trong chân trời Schwarzschild, kể cả khi ISCO Kerr xấp xỉ ở spin cao cho r_inner < 1 Rₛ.
- Lensing strength khác 1 là thí nghiệm điều chỉnh lực bẻ cong, không phải nghiệm GR vật lý. Các thông số photon sphere trong HUD là giá trị Schwarzschild chuẩn.
- Nền gồm ba lớp sao procedural ở khoảng cách hữu hạn, tạo thị sai khi camera di chuyển, cùng tinh vân từ noise. Hướng tia sau khi tích phân được dùng để nhìn nền, nên sao cũng chịu lensing.
- Thời gian hiển thị điều khiển chuyển động trực quan, chưa phải thời gian riêng hay thời gian Schwarzschild. Không mô phỏng dilation thời gian của người quan sát.

## Thủy triều và ngưỡng vật thể

Tính toán dùng SI, mô hình vật thể cầu đồng nhất và trường thủy triều tuyến tính:

```text
m = (4π/3) ρ R³
g_self = Gm/R²
Δa_surface = 2GM_BH R / r³
Δa_diameter = 2 Δa_surface
σ_tidal = ρ GM_BH R² / (2 r³)
σ_self = ρ g_self R / 4
σ_support = σ_self + tensile_strength
r_disruption = [ρ GM_BH R² / (2 σ_support)]^(1/3)
```

Radial tidal eigenvalue 2GM/r³ cũng là giá trị Schwarzschild trong khung rơi tự do; phản ứng nội tại của vật thể vẫn dùng xấp xỉ Newton và ứng suất tĩnh. Mô hình báo khi kích thước vật thể không còn nhỏ so với khoảng cách; nó không giải biến dạng, đáp ứng đàn hồi, quỹ đạo Roche của chất lỏng hay thời gian phân mảnh. Vượt ngưỡng không đồng nghĩa vỡ tức thì.

Với Sagittarius A* 4.3 triệu M☉ và Trái Đất (R = 6371 km, ρ = 5514 kg/m³, sức bền đại diện 50 MPa), tại chân trời Δa_surface ≈ **3550 m/s²**, trong khi g_self ≈ **9.82 m/s²**. Ngưỡng ứng suất tĩnh ở khoảng **7.12 Rₛ**, ngoài chân trời. Vì vậy không đúng khi mặc định cho rằng thủy triều của Sagittarius A* tại chân trời yếu hơn trọng lực tự thân của một vật thể cỡ Trái Đất. Kết luận về thời điểm phá hủy hoàn toàn cần mô phỏng động lực học.

Với hố đen 100 triệu M☉, cùng vật thể có ngưỡng nằm trong chân trời (khoảng 0.874 Rₛ theo xấp xỉ này); một probe nhỏ và có sức bền cũng có thể vượt chân trời dưới ngưỡng ứng suất. Các trường hợp được kiểm thử riêng, không dùng khoảng cách kích hoạt cố định.

## Render và hiệu suất

HDR dùng framebuffer half-float khi GPU hỗ trợ `EXT_color_buffer_float`. Nếu thiếu extension, ứng dụng báo và chuyển sang LDR. Bloom có threshold và Gaussian blur ở ¼ kích thước; ACES filmic tone mapping, exposure và FXAA được thực hiện ở pass cuối. Không dùng TAA nên không có lịch sử ảnh gây bóng ma khi camera thay đổi.

Bloom được giảm và threshold tăng để giữ kết cấu khí; dithering dưới 1 LSB giảm banding vùng tối và không làm sáng pixel bị chân trời hấp thụ. Ray cone giới hạn tần số noise khi render resolution giảm. Khi Pause và camera đứng yên, ứng dụng giữ ảnh đã render thay vì chạy lại toàn bộ shader mỗi frame; camera/resize/thay đổi tham số vẫn làm mới ảnh. Render dạng fullscreen không có các mặt đĩa chồng nhau nên không có z-fighting giữa mesh.

Không kẹp radiance ở 40 trước tone mapping như bản cũ; framebuffer half-float giữ headroom tới giới hạn an toàn 60000. Exposure có thể giảm tới 0.01 khi tăng nhiệt độ mạnh. Việc tăng T thật sự tăng phát xạ theo T⁴ nên thiết lập nhiệt độ/brightness quá cao vẫn cần giảm exposure; không tự cân sáng để che đi quan hệ vật lý này.

Độ phân giải GPU = viewport × render scale × min(devicePixelRatio, 1.5), giới hạn 4.2 triệu pixel và 4096 pixel mỗi chiều. Bộ nhớ framebuffer chỉ được cấp lại khi resize/đổi scale; shader có số vòng lặp hữu hạn. Khi FPS < 28 kéo dài, Adaptive quality giảm độ phân giải, rồi số bước và bloom, tối đa một thay đổi mỗi 7 giây. Tắt công tắc để giữ thiết lập khi đánh giá ảnh.

Với RTX 3050 Ti, bắt đầu ở Balanced, resolution 70–85%, bloom bật; dùng Performance nếu cần. Mục tiêu 60 FPS ở 1080p cần đo trên GPU thực tế. Kiểm thử cloud dùng Chromium SwiftShader, **không phải benchmark RTX và không xác nhận 60 FPS**. Chế độ Ultra ưu tiên ảnh hơn tốc độ.

Không có WebGL2: ứng dụng hiển thị lỗi có hướng dẫn thay vì chạy màn hình đen. Khi mất context GPU, vòng render tạm dừng; khi context khôi phục, tài nguyên được dựng lại và mô phỏng tiếp tục. Camera tránh tọa độ chân trời gây kỳ dị, hỗ trợ resize và fullscreen.

## Kiểm thử

```bash
npm test
npm run build
npm run test:browser
```

15 kiểm thử Node xác minh bán kính, ISCO, tia bị hấp thụ, ngưỡng b_crit với người quan sát hữu hạn, tia đi vòng quanh photon sphere, độ lệch so với tích phân Binet Schwarzschild độc lập, Doppler/dịch đỏ, shear và các ngưỡng thủy triều. Bộ kiểm thử trình duyệt đọc pixel thật, kiểm tra bóng GPU so với công thức góc bóng, việc không thể tạo vòng photon khi không có khí, độ cháy sáng, các thanh trượt/lớp, báo cáo thủy triều, camera, ảnh PNG, fullscreen, mobile, mất/khôi phục context, adaptive quality và HTML độc lập không có request mạng. Kết quả ảnh nằm trong `test-results/`.

Chromium do nền tảng cloud quản lý chặn URL `file://` (`ERR_BLOCKED_BY_ADMINISTRATOR`). Vì vậy kiểm tra bản HTML độc lập dùng đúng nội dung tệp trong trang `about:blank`, với browser đặt offline. Đây là kiểm tra không có mạng, không phải xác nhận truy cập `file://` trong cloud. Trên trình duyệt máy riêng không có chính sách chặn tệp, bản HTML không cần import module hoặc fetch asset nên có thể mở trực tiếp.

Mặc định Chromium là `/usr/bin/chromium`. Nếu dùng đường dẫn khác:

```bash
CHROMIUM_PATH=/path/to/chromium npm run test:browser
```

Các cờ SwiftShader và `--no-sandbox` chỉ nằm trong runner kiểm thử container; ứng dụng dùng GPU và cơ chế bảo vệ mặc định của trình duyệt khi người dùng mở HTML.

## Mã nguồn

| Tệp | Vai trò |
| --- | --- |
| `src/main.js` | Pipeline HDR, bloom, FXAA, render loop, adaptive quality, screenshot và xử lý lỗi |
| `src/shaders/blackhole.frag.glsl` | Tích phân tia, thể tích đĩa, Doppler, dịch đỏ, photon ring và nền |
| `src/shaders/bloom.frag.glsl` | Threshold / Gaussian blur |
| `src/shaders/composite.frag.glsl` | FXAA, exposure, ACES và gamma |
| `src/camera.js` | Orbit, Fly, phím và chuột |
| `src/physics.js` | Hằng số vật lý, Rₛ, ISCO và integrator kiểm thử |
| `src/ui.js`, `src/style.css` | Bảng điều khiển và giao diện responsive |
| `scripts/build.mjs` | Đóng gói HTML độc lập |

Three.js được phân phối theo MIT; xem `THIRD_PARTY_NOTICES.md`.
