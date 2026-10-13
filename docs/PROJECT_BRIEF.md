# MASTER PROMPT: PHÁT TRIỂN GAME UNIVERSE SIMULATOR 3D

## VAI TRÒ

Bạn là một nhóm chuyên gia gồm:

- Senior Game Engine Developer
- Astrophysics Simulation Engineer
- Computational Physics Researcher
- Three.js / WebGPU Graphics Engineer
- GLSL / WGSL Shader Developer
- 3D Technical Artist
- UI/UX Game Designer
- Performance Optimization Engineer

Hãy phát triển một trò chơi mô phỏng vũ trụ 3D lấy cảm hứng từ Universe Sandbox, dựa trên video tham khảo:

https://www.youtube.com/watch?v=5SMPkrmeq_o

Tên dự án: **COSMIC SANDBOX – REALISTIC UNIVERSE SIMULATOR**

Tôi muốn một trò chơi sandbox khoa học thực sự, nơi người chơi có thể tạo, chỉnh sửa, điều khiển và phá hủy những thiên thể trong vũ trụ.

Đây không được chỉ là bản demo đồ họa hoặc hoạt ảnh dựng sẵn.

## 1. NỀN TẢNG VÀ CÔNG NGHỆ

Game chạy trực tiếp trên trình duyệt máy tính.

Công nghệ:
- TypeScript hoặc JavaScript.
- Three.js.
- WebGL2, ưu tiên hỗ trợ WebGPU nếu khả thi.
- GLSL / WGSL.
- Web Workers cho hệ thống vật lý.
- InstancedMesh.
- GPU Particle System.
- HDR Rendering.
- Procedural Planet Generation.
- Custom Physics Engine.

Tách riêng physics engine, renderer, UI và simulation state.

Nếu một file HTML không đủ, hãy tạo dự án nhiều file có cấu trúc rõ ràng và hướng dẫn chạy trên Windows.

## 2. MÔ PHỎNG HỆ MẶT TRỜI

Tạo sẵn hệ Mặt Trời với:

- Sun
- Mercury
- Venus
- Earth
- Moon
- Mars
- Jupiter
- Saturn
- Uranus
- Neptune

Mỗi thiên thể có thông số thực tế:
- Khối lượng.
- Bán kính.
- Mật độ.
- Nhiệt độ.
- Vị trí.
- Vận tốc quỹ đạo.
- Chu kỳ quay.
- Độ nghiêng trục.
- Thành phần vật chất.
- Trọng lực bề mặt.

Cho phép người chơi thêm, xóa, di chuyển và thay đổi mọi thiên thể.

Không được để hành tinh chỉ quay theo quỹ đạo hình tròn dựng sẵn. Vị trí phải được cập nhật từ mô hình hấp dẫn.

## 3. HỆ THỐNG VẬT LÝ N-BODY

Đây là phần quan trọng nhất.

Triển khai hấp dẫn Newton:

F = G × m1 × m2 / r²

Sử dụng:
- Velocity Verlet hoặc Leapfrog Integrator.
- Adaptive Timestep.
- Double Precision trên CPU.
- Chuyển đổi đơn vị khoa học.
- Phát hiện va chạm.
- Bảo toàn động lượng.
- Theo dõi năng lượng toàn hệ.

Mọi thiên thể có thể tác động hấp dẫn lẫn nhau.

Khi tăng khối lượng Mặt Trời, quỹ đạo các hành tinh phải thực sự thay đổi.

Khi thêm một ngôi sao mới, toàn bộ hệ thống phải phản ứng với trường hấp dẫn mới.

Không dùng animation giả lập quỹ đạo.

Với số lượng vật thể lớn, cân nhắc Barnes–Hut hoặc thuật toán xấp xỉ phù hợp.

## 4. THƯ VIỆN THIÊN THỂ

Cho phép tạo:

**Hành tinh**
- Earth-like Planet
- Rocky Planet
- Gas Giant
- Ice Giant
- Lava Planet
- Ocean Planet
- Dwarf Planet

**Sao và vật thể đặc**
- Red Dwarf
- Main Sequence Star
- Red Giant
- White Dwarf
- Neutron Star
- Pulsar
- Magnetar
- Black Hole

**Vật thể nhỏ**
- Moon
- Asteroid
- Comet
- Meteoroid
- Debris
- Planetary Rings

Mỗi loại cần có shader, kết cấu, thông số vật lý và phản ứng riêng.

## 5. VA CHẠM VÀ PHÁ HỦY THIÊN THỂ

Tôi muốn mô phỏng va chạm tương tự Universe Sandbox.

Khi hai thiên thể va chạm:

1. Phát hiện tiếp xúc.
2. Tính vận tốc tương đối.
3. Tính năng lượng va chạm.
4. Ước lượng mức độ phá hủy.
5. Làm biến dạng bề mặt.
6. Hình thành miệng hố hoặc các vết nứt.
7. Phóng mảnh đá, bụi và vật chất nóng chảy.
8. Cập nhật khối lượng và động lượng.
9. Cho vật chất rơi trở lại hoặc thoát ra không gian.

Các trường hợp khác nhau phải có phản ứng khác nhau:

- Tiểu hành tinh đâm Trái Đất.
- Mặt Trăng va chạm Trái Đất.
- Hai hành tinh đá va nhau.
- Hành tinh khí va chạm với hành tinh đá.
- Hai ngôi sao va chạm.
- Sao neutron tiến vào hố đen.

Không dùng một hiệu ứng nổ giống nhau cho mọi va chạm.

## 6. HỆ THỐNG HỐ ĐEN CHÂN THỰC

Tạo hố đen 3D có:

- Event Horizon.
- Black Hole Shadow.
- Photon Sphere.
- Gravitational Lensing.
- Accretion Disk.
- Relativistic Doppler Beaming.
- Gravitational Redshift.
- Plasma Turbulence.
- Tidal Disruption.
- Matter Accretion.

Hố đen phải bẻ cong hình ảnh của các thiên thể phía sau.

Không tạo hố đen chỉ bằng quả cầu đen và vòng sáng.

Đĩa bồi tụ phải có kết cấu khí bất quy tắc, không được xuất hiện các đường sọc đồng tâm quá đều.

Tính bán kính Schwarzschild:

Rs = 2GM / c²

Xử lý lực thủy triều dựa trên khối lượng, mật độ, kích thước và khoảng cách.

Đối với hố đen siêu khối lượng, một thiên thể có thể vượt qua chân trời sự kiện trước khi bị xé nát. Không sử dụng hiệu ứng phá hủy cố định cho mọi trường hợp.

Với hố đen quay, sử dụng mô hình Kerr xấp xỉ hoặc geodesic solver phù hợp; ghi rõ giới hạn độ chính xác.

## 7. SAO NEUTRON VÀ PULSAR

Thêm sao neutron có:
- Mật độ cực cao.
- Khối lượng và bán kính thực tế.
- Trường hấp dẫn mạnh.
- Hiệu ứng phát xạ nhiệt.
- Chế độ Pulsar.
- Chùm bức xạ quay theo trục từ.
- Hiệu ứng gravitational lensing gần bề mặt.

Khi sao neutron tiếp cận hố đen:

- Tính quỹ đạo lao vào.
- Xác định khả năng bị xé bởi lực thủy triều.
- Tạo dòng vật chất nếu xảy ra phá hủy.
- Mô phỏng việc sáp nhập theo mô hình xấp xỉ.

Không cho sao neutron nổ hoặc bị xé trong mọi trường hợp nếu điều kiện vật lý không phù hợp.

## 8. SAO VÀ SIÊU TÂN TINH

Tạo mô phỏng stellar evolution ở mức xấp xỉ:

- Main Sequence.
- Red Giant.
- White Dwarf.
- Core Collapse.
- Supernova.
- Neutron Star Remnant.
- Black Hole Remnant.

Khi xảy ra supernova:

- Có sóng xung kích.
- Vật chất được phóng ra không gian.
- Có sự biến thiên nhiệt độ và độ sáng.
- Xuất hiện các lớp khí giãn nở.
- Các thiên thể lân cận chịu tác động vật lý thích hợp.

Không biến mọi ngôi sao thành siêu tân tinh khi hết nhiên liệu.

## 9. KHÍ HẬU VÀ BỀ MẶT HÀNH TINH

Thêm hệ thống vật lý bề mặt:

- Nhiệt độ theo vĩ độ.
- Bức xạ từ ngôi sao.
- Hiệu ứng nhà kính xấp xỉ.
- Khí quyển.
- Nước lỏng.
- Băng.
- Bốc hơi.
- Đóng băng.
- Nung nóng do va chạm.
- Địa hình và miệng núi lửa.

Nếu di chuyển Trái Đất gần Mặt Trời:
- Nhiệt độ cân bằng phải tăng.
- Băng tan khi đủ nóng.
- Đại dương có thể bốc hơi.
- Khí hậu thay đổi theo thời gian.

Nếu di chuyển ra xa:
- Nhiệt độ giảm.
- Đại dương có thể đóng băng.

Không thay đổi toàn bộ bề mặt ngay lập tức nếu quá trình thực tế cần thời gian.

## 10. ĐỒ HỌA VÀ SHADER AAA-INSPIRED

Tạo hình ảnh chất lượng cao:

**Hành tinh**
- Procedural terrain.
- PBR materials.
- Normal maps.
- Roughness maps.
- Atmospheric scattering.
- Dynamic cloud layers.
- Day/night lighting.
- City lights cho Trái Đất.
- Ocean specular reflections.
- Thermal emission cho dung nham.

**Ngôi sao**
- Procedural photosphere.
- Solar granulation.
- Stellar corona.
- Prominences.
- Magnetic flare effects.
- Temperature-based color.

**Không gian**
- Starfield HDR.
- Nebulae.
- Milky Way backdrop.
- Realistic exposure.
- Bloom.
- ACES tone mapping.
- High precision depth.

**Va chạm**
- GPU particles.
- Debris trails.
- Molten ejecta.
- Dynamic craters.
- Thermal glow.
- Shockwave visualization.

Mọi hiệu ứng phải được thiết kế tối ưu. Không hy sinh sự ổn định chỉ để tăng bloom.

## 11. CAMERA VÀ ĐIỀU KHIỂN

Cho phép:

- Xoay camera 360 độ.
- Zoom từ hệ sao xuống hành tinh.
- Focus vào bất kỳ thiên thể nào.
- Fly Camera bằng WASD.
- Camera tự động theo dõi.
- Smooth transitions.
- Cinematic Camera.
- Hiển thị quỹ đạo.
- Hiển thị vận tốc.
- Hiển thị vector lực hấp dẫn.
- Hiển thị khoảng cách giữa hai thiên thể.

Phải xử lý sự chênh lệch kích thước từ thiên thạch đến thiên hà bằng hệ thống scale và floating origin thích hợp.

## 12. GIAO DIỆN SANDBOX

Thiết kế giao diện khoa học hiện đại giống tinh thần Universe Sandbox.

Thanh công cụ dưới cùng:
- Add
- Select
- Move
- Velocity
- Temperature
- Composition
- Collision
- Delete
- Reset
- Save
- Load

Panel bên phải khi chọn một hành tinh:

- Name
- Mass
- Radius
- Density
- Temperature
- Gravity
- Velocity
- Rotation
- Atmosphere
- Surface
- Composition
- Orbital Elements

Cho phép chỉnh thông số ngay khi đang mô phỏng.

Các thanh trượt phải thực sự thay đổi vật lý, không chỉ thay đổi hình ảnh.

## 13. ĐIỀU KHIỂN THỜI GIAN

Cho phép:
- Pause.
- Resume.
- Slow Motion.
- Real Time.
- Fast Forward.
- Reverse bằng cách khôi phục snapshot mô phỏng nếu không thể tích phân đảo chính xác.
- Step Simulation.

Đơn vị:
- Seconds.
- Minutes.
- Hours.
- Days.
- Years.
- Thousands of Years.
- Millions of Years.

Timestep vật lý phải độc lập với FPS đồ họa.

Tự động giảm timestep khi thiên thể tiến rất gần nhau để tránh xuyên vật thể hoặc mất ổn định số.

## 14. CÁC KỊCH BẢN CÓ SẴN

Tạo các preset:

1. Solar System.
2. Earth & Moon.
3. Earth vs Moon Collision.
4. Asteroid Impact.
5. Two Stars Collision.
6. Supernova.
7. Black Hole vs Earth.
8. Neutron Star vs Black Hole.
9. Binary Star System.
10. Custom Planetary System.

Các preset phải có vận tốc và thông số ban đầu phù hợp, không chỉ đặt các vật thể ngẫu nhiên.

## 15. LƯU VÀ TẢI MÔ PHỎNG

- Save simulation.
- Load simulation.
- Export JSON.
- Import JSON.
- Reset to initial conditions.
- Lưu trạng thái vật lý, các thông số thiên thể và thời điểm mô phỏng.
- Kiểm tra tính hợp lệ của dữ liệu khi tải.

## 16. HIỆU SUẤT

Phần cứng mục tiêu:

NVIDIA RTX 3050 Ti Laptop GPU, Intel Core i7-11800H, RAM 16GB.

Yêu cầu:

- Tối ưu GPU.
- Web Worker cho physics.
- Frustum culling.
- Level of Detail.
- Adaptive render resolution.
- Instanced rendering.
- Particle pooling.
- Geometry batching khi phù hợp.
- Không cấp phát bộ nhớ liên tục trong vòng lặp.
- Có chế độ Performance, Balanced và Ultra.

Mục tiêu 60 FPS ở 1080p cho cảnh có số lượng vật thể vừa phải. Không cam kết FPS nếu mô phỏng vật lý hoặc hiệu ứng vượt quá khả năng phần cứng.

## 17. KIẾN TRÚC PHÁT TRIỂN

Chia dự án thành các module:

- SimulationEngine
- GravitySolver
- CollisionEngine
- CelestialBodySystem
- PlanetRenderer
- StarRenderer
- BlackHoleRenderer
- ParticleSystem
- ClimateSystem
- TimeController
- CameraController
- SandboxUI
- SaveLoadManager
- PerformanceManager

Không gom tất cả logic vào một render loop khổng lồ.

## 18. PHÁT TRIỂN THEO GIAI ĐOẠN

**Phase 1 – Playable Foundation**

Tạo hệ Mặt Trời 3D, camera, lựa chọn thiên thể, N-body gravity và điều khiển thời gian.

**Phase 2 – Sandbox Interaction**

Cho phép thêm, xóa, kéo thả, chỉnh thông số, thay đổi vận tốc và tạo hệ hành tinh mới.

**Phase 3 – Collision & Destruction**

Thêm va chạm, bảo toàn động lượng, mảnh vỡ, nhiệt và các hiệu ứng bề mặt.

**Phase 4 – Advanced Celestial Objects**

Thêm sao neutron, pulsar, hố đen, siêu tân tinh và các tương tác vật lý liên quan.

**Phase 5 – Graphics Upgrade**

Nâng cấp shader, ánh sáng, khí quyển, bề mặt hành tinh và hậu kỳ.

**Phase 6 – Optimization & Verification**

Đo hiệu suất, kiểm tra năng lượng hệ, tính ổn định quỹ đạo, sửa lỗi và hoàn thiện UI.

Mỗi giai đoạn phải có kết quả chạy được và có thể kiểm thử trước khi tiếp tục.

## 19. KIỂM THỬ VẬT LÝ BẮT BUỘC

Tạo các bài kiểm thử:

- Trái Đất quay quanh Mặt Trời trong một năm.
- Mặt Trăng quay quanh Trái Đất.
- Tăng khối lượng Mặt Trời làm thay đổi quỹ đạo.
- Hai thiên thể va chạm bảo toàn động lượng.
- Vật thể có vận tốc thoát phù hợp có thể thoát trường hấp dẫn.
- Quỹ đạo elip không tự suy giảm năng lượng trong hệ hai vật Newton cô lập.
- Vật thể vượt chân trời sự kiện được xử lý đúng mô hình.
- Thiên thể không bị phá hủy tùy tiện nếu ứng suất thủy triều chưa vượt ngưỡng.

Hiển thị rõ sai số và giới hạn của các mô hình xấp xỉ.

## 20. YÊU CẦU CUỐI CÙNG

Tôi muốn một GAME SANDBOX THỰC SỰ có khả năng tương tác, không phải video, hình ảnh hoặc visual demo.

Không được:
- Dùng quỹ đạo giả.
- Dùng va chạm dựng sẵn cho mọi trường hợp.
- Cho vật thể xuyên qua nhau.
- Để thanh chỉnh UI không hoạt động.
- Bỏ qua lực hấp dẫn giữa các vật thể.
- Dùng hiệu ứng nổ thay thế hoàn toàn mô phỏng phá hủy.
- Tự nhận mô phỏng chính xác tuyệt đối khi chỉ là xấp xỉ.
- Cắt bỏ physics engine để tập trung làm giao diện đẹp.

Ưu tiên theo thứ tự:

1. Game chạy được.
2. Hệ thống vật lý đúng và ổn định.
3. Tương tác sandbox đầy đủ.
4. Va chạm và phá hủy.
5. Shader và đồ họa.
6. Hiệu năng.
7. Giao diện hoàn thiện.

Hãy bắt đầu bằng Phase 1, viết mã nguồn thật, đầy đủ, có hướng dẫn chạy và kiểm thử. Sau khi hoàn thành một giai đoạn, bảo toàn kiến trúc để tiếp tục mở rộng các giai đoạn còn lại.