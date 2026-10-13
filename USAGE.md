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

Scientific đặt spin = 0, lensing = 1, tắt tự xoay. Cinematic tăng bloom, exposure và bật bay vòng (trừ khi hệ thống yêu cầu giảm chuyển động); có thể tắt ở Scene layers. Performance giảm bước tích phân, độ phân giải, bloom và tinh vân. Chế độ vẫn cho phép thay đổi thông số thủ công.

## Mô hình và giới hạn vật lý

- `Rₛ = 2GM/c²`, với G = 6.67430 × 10⁻¹¹ SI, c = 299792458 m/s và M☉ = 1.98847 × 10³⁰ kg. Mặc định 4.3 triệu M☉ tương ứng Rₛ ≈ 12.70 triệu km.
- Đơn vị tọa độ cảnh là Rₛ của khối lượng tham chiếu 4.3 triệu M☉. Shader chia tọa độ cho Rₛ hiện tại để luôn tích phân trong đơn vị Rₛ = 1. Camera giữ tọa độ tham chiếu khi thay đổi khối lượng, nên kích thước biểu kiến thay đổi thật.
- Với lensing = 1, tia null Schwarzschild được tích phân trong không gian 3D bằng velocity-Verlet, theo phương trình affine `x'' = -3 L² x / (2 r⁵)` trong đơn vị Rₛ = 1. Chuyển đổi hướng nhìn từ khung cục bộ của người quan sát, theo dõi mô men góc L, hấp thụ tia tại r ≤ 1. Đây là tích phân đường đi tia sáng, không phải bộ lọc méo ảnh screen-space.
- Trường được cắt ở 40 Rₛ để giới hạn chi phí; phần ngoài được coi như thẳng. Bước tích phân phụ thuộc khoảng cách, với 96 / 144 / 216 / 320 bước tối đa. Tia chưa thoát sau ngân sách này được hấp thụ để tránh rò bầu trời. Ảnh thứ cấp và tia sát quỹ đạo photon có sai số số học; tăng quality để giảm sai số. Đây không phải công cụ đo đạc thiên văn chính xác.
- Đĩa là một thể tích mỏng. Mỗi đoạn tia được cắt với slab của đĩa rồi lấy mẫu phát xạ và tích phân optical depth. Cấu trúc được tạo bởi noise và các sợi xoắn; vận tốc góc giảm theo r⁻³ᐟ². Không giải thủy động lực học, từ trường hay GRMHD.
- Nhiệt độ giảm theo bán kính; màu blackbody được dịch bởi hệ số Doppler và dịch đỏ hấp dẫn. Cường độ phát xạ biến đổi theo g³. Nhiệt độ, mật độ và brightness là tham số của mô hình phát xạ đơn giản, không hiệu chuẩn phổ quan sát.
- Photon sphere Schwarzschild ở 1.5 Rₛ; bóng hố đen có bán kính biểu kiến khoảng 2.598 Rₛ với người quan sát xa. Các lần tia cắt đĩa tạo vòng ảnh thứ cấp. Công tắc Photon ring điều khiển phần bù dưới pixel cho các ảnh bậc cao không được phân giải, không xóa các ảnh thứ cấp đã tích phân từ đĩa.
- **Spin không triển khai metric Kerr.** Giá trị này thay đổi quay khí và biên trong phát xạ bằng công thức ISCO Kerr thuận chiều. Chân trời và đường đi ánh sáng vẫn là Schwarzschild; không có frame dragging, ergosphere hay horizon Kerr. Giao diện ghi rõ khi bật hiệu ứng này.
- Lensing strength khác 1 là thí nghiệm điều chỉnh lực bẻ cong, không phải nghiệm GR vật lý. Các thông số photon sphere trong HUD là giá trị Schwarzschild chuẩn.
- Nền gồm ba lớp sao procedural ở khoảng cách hữu hạn, tạo thị sai khi camera di chuyển, cùng tinh vân từ noise. Hướng tia sau khi tích phân được dùng để nhìn nền, nên sao cũng chịu lensing.
- Thời gian hiển thị điều khiển chuyển động trực quan, chưa phải thời gian riêng hay thời gian Schwarzschild. Không mô phỏng dilation thời gian của người quan sát.

## Render và hiệu suất

HDR dùng framebuffer half-float khi GPU hỗ trợ `EXT_color_buffer_float`. Nếu thiếu extension, ứng dụng báo và chuyển sang LDR. Bloom có threshold và Gaussian blur ở ¼ kích thước; ACES filmic tone mapping, exposure và FXAA được thực hiện ở pass cuối. Không dùng TAA nên không có lịch sử ảnh gây bóng ma khi camera thay đổi.

Độ phân giải GPU = viewport × render scale × min(devicePixelRatio, 1.5), giới hạn 4.2 triệu pixel và 4096 pixel mỗi chiều. Bộ nhớ framebuffer chỉ được cấp lại khi resize/đổi scale; shader có số vòng lặp hữu hạn. Khi FPS < 28 kéo dài, Adaptive quality giảm độ phân giải, rồi số bước và bloom, tối đa một thay đổi mỗi 7 giây. Tắt công tắc để giữ thiết lập khi đánh giá ảnh.

Với RTX 3050 Ti, bắt đầu ở Balanced, resolution 70–85%, bloom bật; dùng Performance nếu cần. Mục tiêu 60 FPS ở 1080p cần đo trên GPU thực tế. Kiểm thử cloud dùng Chromium SwiftShader, **không phải benchmark RTX và không xác nhận 60 FPS**. Chế độ Ultra ưu tiên ảnh hơn tốc độ.

Không có WebGL2: ứng dụng hiển thị lỗi có hướng dẫn thay vì chạy màn hình đen. Khi mất context GPU, vòng render tạm dừng; khi context khôi phục, tài nguyên được dựng lại và mô phỏng tiếp tục. Camera tránh tọa độ chân trời gây kỳ dị, hỗ trợ resize và fullscreen.

## Kiểm thử

```bash
npm test
npm run build
npm run test:browser
```

Sáu kiểm thử Node xác minh bán kính, ISCO, tia bị hấp thụ, ngưỡng tham số va chạm, độ lệch trường yếu và lensing tắt. Bộ kiểm thử trình duyệt khởi động Vite riêng ở cổng 5174, chạy Chromium, đọc pixel thật, kiểm tra các thanh trượt/lớp, camera, ảnh PNG, fullscreen, bố cục mobile, mất/khôi phục context, adaptive quality và bản HTML độc lập không có request mạng. Kết quả ảnh nằm trong `test-results/`.

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
