# COSMIC SANDBOX — Realistic Universe Simulator

Bản **Phase 1: Playable Foundation** chạy trên trình duyệt, dùng Three.js,
TypeScript, shader GLSL và Web Worker riêng cho hấp dẫn. Đây là mô phỏng
tương tác: vị trí thiên thể được tích phân từ lực hấp dẫn của toàn hệ.

## Chạy trên Windows

### Dùng bản đóng gói

Tải `dist/index.html` rồi mở bằng Chrome hoặc Edge có hỗ trợ WebGL2 và bật
hardware acceleration. Tệp đã chứa mã ứng dụng, Three.js, shader, CSS và
physics Worker; không cần CDN hoặc mạng để mô phỏng.

Tải cả `dist/blackhole.html` vào cùng thư mục để nút **Hố đen ↗** mở được
phòng quan sát hố đen trước đây. IndexedDB tùy thuộc chính sách trình duyệt
đối với tệp cục bộ; xuất/nhập JSON là cách mang bản lưu sang máy khác.

### Chạy mã nguồn

Cài **Node.js 24 LTS** và Git. Mở PowerShell:

```powershell
git clone https://github.com/Zinnart12/Zinnart12.git
cd Zinnart12
npm ci
npm run dev
```

Mở địa chỉ Vite in trong cửa sổ PowerShell trên máy của bạn. `index.html`
ở gốc là tệp phát triển; bản mở độc lập là `dist/index.html`.

```powershell
npm run typecheck
npm test
npm run build
```

Build tạo hai HTML độc lập: Cosmic Sandbox và phòng quan sát hố đen.
Gói `dist/cosmic-sandbox-source.zip` chứa mã nguồn và hai bản HTML.

## Những gì chơi được

- Hệ Mặt Trời: Sun, Mercury, Venus, Earth, Moon, Mars, Jupiter, Saturn,
  Uranus và Neptune. Khối lượng, bán kính, nhiệt độ, chu kỳ quay, nghiêng
  trục, khí quyển và thành phần được lưu cùng mỗi thiên thể.
- Năm kịch bản: Solar System, Earth & Moon, Binary Stars, Giant Impact
  và Empty Space. Các vận tốc quỹ đạo khởi đầu được tính từ điều kiện Kepler.
- Chọn thiên thể bằng danh sách hoặc nhấp trong cảnh. Focus, theo dõi,
  Orbit 360°, zoom và Fly bằng WASD/QE; Shift để bay nhanh.
- Pause/Resume, tốc độ từ giây đến năm trên giây thực, Step và tua về
  snapshot trước. Đồng hồ chỉ ghi thời gian Worker đã thực sự tích phân.
- Thêm sáu mẫu thiên thể, xóa, sửa tên, khối lượng, bán kính, nhiệt độ,
  vị trí, vận tốc, chu kỳ quay và nghiêng trục. Các thanh trượt khối lượng
  và bán kính sửa dữ liệu vật lý, không chỉ kích thước mesh.
- Lưu/tải trong IndexedDB; xuất/nhập JSON có kiểm tra định dạng và phạm vi.
  Reset khôi phục điều kiện ban đầu của kịch bản hoặc bản lưu đang mở.
- Va chạm tiếp xúc cơ bản hợp nhất thiên thể, bảo toàn khối lượng và
  động lượng tuyến tính, ghi năng lượng va chạm và tăng nhiệt độ đại diện.
- Shader procedural cho hành tinh, khí quyển, mây, sao và vành Saturn;
  HDR khi được hỗ trợ, ACES, bloom có giới hạn, ba mức chất lượng.
- Vệt chuyển động lấy từ vị trí đã tích phân; vector vận tốc màu xanh
  và hướng gia tốc hấp dẫn màu cam; theo dõi sai số năng lượng toàn hệ.

Trong Orbit: kéo chuột trái để xoay, cuộn để zoom, chuột phải để pan.
Nhấp **⌖** trong bảng thiên thể hoặc nhấp đúp tên trong danh sách để Focus.
**Space** tạm dừng/tiếp tục, trừ khi đang nhập thông số. **Di chuyển** và
**Vận tốc** mở ô chỉnh tọa độ/vận tốc, không phải công cụ kéo thả.

Chế độ mặc định phóng đại **bán kính hiển thị** để dễ nhìn, có giới hạn
theo khoảng cách lân cận để tránh hai mesh chồng lên nhau trước va chạm.
Tâm thiên thể, khoảng cách, lực hấp dẫn và bán kính tiếp xúc luôn dùng SI
thật. Bật **Kích thước thật** để xem đúng tỉ lệ; hành tinh nhỏ cần Focus.
Vệt quỹ đạo được tích lũy khi mô phỏng chạy, không vẽ sẵn vòng tròn.

## Mô hình vật lý và sai số

Toàn bộ trạng thái dùng **mét, kg, m/s, giây và kelvin**. JavaScript Number
trên CPU là IEEE 754 64-bit. Renderer dịch tọa độ theo floating origin rồi
đổi sang 32 đơn vị hiển thị/AU; phép đổi này không tác động tới Worker.

Hấp dẫn trực tiếp theo cặp:

```text
aᵢ = Σⱼ G mⱼ (xⱼ − xᵢ) / |xⱼ − xᵢ|³
G = 6.67430 × 10⁻¹¹ m³ kg⁻¹ s⁻²
```

Velocity Verlet gồm bước cập nhật vị trí, tính lại gia tốc và cập nhật
vận tốc. Bước tối đa 7.200 giây, giảm theo thời gian động lực cặp thiên
thể và tốc độ tiếp cận. Phát hiện tiếp xúc dùng cả vị trí đầu/cuối bước
và swept spheres để bắt vật thể nhanh đi xuyên giữa hai lần lấy mẫu.
Các vật thể đã chạm được hợp nhất trước bước tiếp theo.

Năng lượng Newton được tính từ động năng và thế năng của tất cả cặp.
Bảng **ΔE / |E₀|** dùng năng lượng tham chiếu mới sau khi chỉnh/thêm/xóa,
tải bản lưu hoặc hợp nhất, vì những thao tác này thay đổi năng lượng hệ.
Velocity Verlet với bước cố định có sai số năng lượng dao động hữu hạn;
bước thích nghi không bảo đảm tính symplectic chính xác. Monitor và các
bài kiểm tra quỹ đạo là bằng chứng ổn định trong phạm vi đã kiểm tra,
không phải cam kết chính xác tuyệt đối cho mọi dữ liệu nhập.

Giới hạn hiện tại **128 thiên thể**, solver O(N²), tối đa 512 bước mỗi
yêu cầu tương tác. Khi không đủ ngân sách, đồng hồ chỉ tăng phần đã tính
và UI báo giới hạn tốc độ. Thời gian chờ Worker được tích lũy độc lập
FPS, với tồn đọng tối đa 5 giây thực; đổi tốc độ, pause, tải trạng thái
hoặc chuyển nền sẽ xóa phần chờ để tránh nhảy thời gian. Không nhảy quỹ đạo để bắt kịp năm/giây. Chạy
thời gian rất dài cần nhiều yêu cầu và không được bảo đảm nhanh như các
mức giây/ngày. Barnes–Hut chưa được triển khai.

Quỹ đạo khởi đầu của hệ Mặt Trời là xấp xỉ theo tham số Kepler và các pha
mẫu; không phải ephemeris JPL tại một ngày cụ thể. Tất cả thiên thể tác
động hấp dẫn lẫn nhau ngay sau khởi tạo. Hệ tọa độ khởi đầu được đưa về
tâm khối lượng, động lượng tổng gần bằng không trong sai số số học.

Va chạm hiện là **hợp nhất hoàn toàn không đàn hồi**: cộng khối lượng,
cộng thể tích và lấy vận tốc theo động lượng. Nhiệt tăng từ năng lượng
va chạm với nhiệt dung đại diện 1.000 J/(kg·K), không phải EOS vật liệu.
Sparks trên GPU là hiệu ứng thị giác, không phải các mảnh vật chất có
khối lượng. Chưa có phá vỡ, hoàn trả mảnh vỡ, miệng hố động hoặc SPH.

Nhiệt độ/khí quyển/thành phần hiện là thuộc tính lưu được và đầu vào cho
hiển thị, chưa có bộ giải khí hậu hay stellar evolution. Chiếu sáng hành
tinh được chuẩn hóa để nhìn rõ; không phải mô hình truyền bức xạ vật lý.
Không gán độ chính xác thiên văn cho màu sắc procedural.

## Kiến trúc và các giai đoạn tiếp theo

| Module | Trách nhiệm |
| --- | --- |
| `types.ts` | Dữ liệu SI và giao thức Worker |
| `physics/gravity.ts` | Lực theo cặp, Verlet, bước thích nghi, năng lượng |
| `physics/engine.ts` | Trạng thái, kiểm tra dữ liệu, tiếp xúc/hợp nhất |
| `physics/worker.ts`, `WorkerClient.ts` | Chạy vật lý ngoài luồng giao diện |
| `presets.ts` | Điều kiện ban đầu và mẫu thiên thể |
| `rendering/UniverseRenderer.ts` | Cảnh Three.js, camera, floating origin, vệt |
| `rendering/shaders.ts` | Bề mặt, sao, khí quyển, particles trên GPU |
| `SandboxUI.ts`, `style.css` | Thư viện, inspector, thời gian và công cụ |
| `TimeController.ts` | Tốc độ, snapshot, khôi phục lịch sử |
| `SaveLoadManager.ts` | IndexedDB và JSON có schema |
| `main.ts` | Điều phối Worker, render và UI |

Phase 1 đã có một số thao tác nền tảng cho Phase 2; các giai đoạn còn lại
chưa được coi là hoàn thành. Phase 2 mở rộng kéo thả và thư viện; Phase 3
thêm mô hình phá hủy/mảnh vỡ; Phase 4 ghép vật thể đặc, accretion, tidal
disruption và evolution; Phase 5 mở rộng đồ họa/khí hậu; Phase 6 tối ưu
và đo trên phần cứng thực. WebGPU chưa dùng; renderer hiện là WebGL2/GLSL.

Phòng quan sát hố đen trước đây chạy riêng trong `blackhole.html` và
`dist/blackhole.html`, giữ bộ giải tia Schwarzschild và mô hình thủy triều.
Hố đen chưa được ghép vào solver N-body Newton của Cosmic Sandbox.
Giới hạn riêng của phòng quan sát được ghi trong [USAGE.md](USAGE.md).

## Kiểm tra

```powershell
npm run typecheck
npm test
npm run build
npx playwright install chromium
$env:CHROMIUM_PATH = "C:\duong-dan-den\chrome.exe"
npm run test:browser:cosmic
npm run test:browser
```

`CHROMIUM_PATH` chỉ cần khi đường dẫn mặc định `/usr/bin/chromium` không
tồn tại. Trên Windows có thể đặt đường dẫn Chrome/Edge đang cài. Bộ kiểm
thử dùng Playwright, các cờ SwiftShader phục vụ môi trường kiểm tra.

34 kiểm thử Node gồm 10 N-body, 9 lưu trữ/thời gian và 15 vật lý hố đen.
Kiểm thử mới xác minh Trái Đất một năm, quỹ đạo Mặt Trăng, thay khối lượng
Mặt Trời, thoát hấp dẫn, năng lượng quỹ đạo elip, động lượng va chạm,
bước thích nghi, kiểm tra dữ liệu, tua lại liên tiếp và tích lũy thời gian
ở 1/30/60/120 FPS khi Worker bận.

Kiểm tra trình duyệt thực hiện thao tác UI, đọc trạng thái Worker và
pixel WebGL, lưu/tải IndexedDB/JSON và chạy HTML đóng gói với Worker nhúng.
Ảnh nằm trong `test-results/`. Cloud dùng Chromium SwiftShader, **không
phải đo RTX 3050 Ti**; mục tiêu 60 FPS ở 1080p cần đo trên máy mục tiêu.
Không dùng benchmark phần mềm để khẳng định tốc độ GPU thực.

Vòng kiểm tra hoàn tất trong môi trường cloud: TypeScript đạt, 34 bài Node
và 14 nhóm thao tác trình duyệt đạt. Cải thiện camera cuối cùng được
kiểm tra riêng bằng 6 phép thử trên đúng HTML đóng gói. Bản đóng gói
được chạy với trình duyệt
offline; physics Worker nhúng vẫn cập nhật vị trí và không phát sinh request
mạng. Yêu cầu gốc và kế hoạch các giai đoạn được lưu trong
[docs/PROJECT_BRIEF.md](docs/PROJECT_BRIEF.md).
