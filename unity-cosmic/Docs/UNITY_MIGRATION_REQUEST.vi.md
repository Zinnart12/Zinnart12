# COSMIC SANDBOX 3D – GODOT 4 TO UNITY 6 COMPLETE MIGRATION & ADVANCED UNIVERSE SIMULATION

## VAI TRÒ

Bạn là một nhóm kỹ sư phát triển game chuyên nghiệp gồm:

- Senior Unity 6 Game Developer
- C# Software Architect
- Astrophysics Simulation Engineer
- Computational Physics Engineer
- Procedural Graphics Engineer
- HLSL / Compute Shader Specialist
- Technical Artist
- Physics Destruction Engineer
- UI/UX Designer
- Performance Optimization Engineer

Nhiệm vụ của bạn là **chuyển toàn bộ dự án Cosmic Sandbox 3D hiện tại từ Godot 4 sang Unity 6**, đồng thời sửa những vấn đề hiện có, mở rộng hệ thống vật lý và đồ họa để tạo một game mô phỏng vũ trụ tương tự về chức năng và trải nghiệm với Universe Sandbox.

Tham khảo:

https://universesandbox.com/presskit/

https://www.youtube.com/watch?v=5SMPkrmeq_o

Đây là dự án game sandbox khoa học 3D dành cho Windows, không phải website hay bản demo đồ họa.

Không sao chép tài sản có bản quyền hoặc giao diện độc quyền của Universe Sandbox. Hãy phát triển hệ thống và thiết kế riêng nhưng có độ sâu tương tác tương đương.

---

# PHẦN I – CHUYỂN GODOT 4 SANG UNITY 6

## 1. KIỂM TRA DỰ ÁN GODOT HIỆN TẠI

Trước tiên, hãy đọc toàn bộ dự án hiện có, bao gồm:

- project.godot
- GDScript
- Scene .tscn
- Shader .gdshader
- Mesh
- Texture
- Materials
- UI
- Preset hệ hành tinh
- Save files
- Các thuật toán vật lý

Xác định những tính năng đã hoàn thành, những thành phần lỗi và các hệ thống còn thiếu.

Phải chuyển đổi logic hiện có sang Unity thay vì loại bỏ toàn bộ.

Ví dụ:

Godot → Unity

- UniverseManager.gd → UniverseManager.cs
- GravitySolver.gd → NBodyGravitySolver.cs
- CelestialBody.gd → CelestialBody.cs
- BlackHoleSystem.gd → BlackHoleSystem.cs
- DestructionSystem.gd → DestructionSystem.cs
- CameraController.gd → SpaceCameraController.cs
- SandboxUI.gd → SandboxUIController.cs
- .gdshader → HLSL hoặc Shader Graph
- .tscn → Unity Scene / Prefab

Nếu chưa có mã nguồn Godot, yêu cầu tôi cung cấp project ZIP. Không tự nhận rằng đã chuyển đổi code chưa được cung cấp.

## 2. CẤU HÌNH UNITY

Sử dụng:

- Unity 6 LTS.
- C#.
- Universal Render Pipeline (URP).
- HLSL.
- Shader Graph.
- Compute Shader.
- Unity Jobs System.
- Burst Compiler khi phù hợp.
- GPU Instancing.
- Visual Effect Graph nếu tương thích với pipeline và phiên bản dự án.
- UI Toolkit hoặc uGUI.
- Windows x64 Build.

Không dùng Unity Rigidbody làm hệ thống hấp dẫn thiên văn chính.

Xây dựng physics engine riêng.

---

# PHẦN II – NÂNG CẤP VẬT LÝ THIÊN VĂN

## 3. N-BODY GRAVITY ENGINE

Áp dụng hấp dẫn Newton:

F = G × m1 × m2 / r²

Yêu cầu:

- Mỗi thiên thể chịu lực hấp dẫn từ các thiên thể khác.
- Quỹ đạo được tính theo vận tốc và gia tốc.
- Không sử dụng animation quỹ đạo dựng sẵn.
- Velocity Verlet hoặc Leapfrog Integrator.
- Double Precision Physics.
- Adaptive Substeps.
- Bảo toàn động lượng.
- Theo dõi sai số năng lượng.
- Hỗ trợ quỹ đạo elip, hyperbolic và parabolic.
- Floating Origin.
- Physics Simulation Time độc lập FPS.

Khi có nhiều vật thể, tối ưu bằng Barnes–Hut hoặc mô hình xấp xỉ khác.

Các vật thể nhỏ như hạt bụi có thể sử dụng solver riêng để tối ưu.

## 4. XÓA MẶT TRỜI – HỆ HÀNH TINH MẤT QUỸ ĐẠO

Tôi muốn người chơi có thể xóa Mặt Trời ngay khi hệ Mặt Trời đang hoạt động.

Khi xóa:

- Mặt Trời phải ngừng đóng góp lực hấp dẫn.
- Trái Đất không được tiếp tục quỹ đạo tròn dựng sẵn.
- Các hành tinh khác cũng mất quỹ đạo quanh Mặt Trời.
- Chúng tiếp tục chuyển động theo vận tốc và lực hấp dẫn còn lại.
- Một số hành tinh có thể bay ra không gian.
- Một số có thể tương tác và tạo các quỹ đạo mới.

Không làm các hành tinh dừng lại ngay lập tức.

Không sử dụng hoạt ảnh để giả lập việc mất quỹ đạo.

## 5. THÊM VÀ THAY THẾ HÀNH TINH

Thêm các chức năng:

- Add Celestial Body.
- Delete Body.
- Replace Body.
- Clone Body.
- Clone Orbit.
- Modify Velocity.
- Modify Mass.
- Modify Radius.
- Modify Temperature.
- Set Stable Orbit.
- Set Collision Course.

Ví dụ:

Người chơi xóa Earth và chọn Replace With Mars.

Hệ thống phải:

1. Lưu vị trí của Earth.
2. Lưu vector vận tốc của Earth.
3. Xóa Earth.
4. Tạo Mars mới tại vị trí đó.
5. Cho Mars nhận vector vận tốc cũ hoặc tính vận tốc quỹ đạo phù hợp theo tùy chọn.
6. Cập nhật các lực hấp dẫn.
7. Tiếp tục mô phỏng.

Có thể thay Sun bằng Black Hole hoặc Neutron Star.

Việc thay thế phải dùng thông số vật lý thật của thiên thể mới, không chỉ thay texture.

---

# PHẦN III – PHÁ HỦY HÀNH TINH CÓ DIỄN BIẾN

## 6. VẤN ĐỀ PHẢI KHẮC PHỤC

Trong bản Godot hiện tại, hành tinh tiến vào hố đen thường chỉ biến mất.

Không thấy:

- Kéo giãn vật thể.
- Bề mặt nứt vỡ.
- Mảnh đá bị bóc tách.
- Khí quyển bị mất.
- Debris Stream.
- Vật chất nóng lên.
- Accretion.

Tôi muốn thay thế cơ chế đơn giản này bằng một hệ thống phá hủy nhiều giai đoạn.

## 7. PHÁ HỦY DO LỰC THỦY TRIỀU

Tính tidal acceleration xấp xỉ:

Δa ≈ 2GMR / r³

Trong đó:

- M: khối lượng nguồn hấp dẫn.
- R: bán kính vật thể bị tác động.
- r: khoảng cách giữa tâm hai vật thể.
- G: hằng số hấp dẫn.

So sánh ứng suất thủy triều với:

- Self-gravity.
- Material strength.
- Internal pressure.
- Structural cohesion.

Các giai đoạn:

**Stage 1 – Stable**

Thiên thể giữ nguyên cấu trúc khi lực thủy triều chưa đủ mạnh.

**Stage 2 – Deformation**

Thiên thể bắt đầu biến dạng, kéo dài và chịu ứng suất.

**Stage 3 – Surface Failure**

Bề mặt nứt, khí quyển bị bóc tách, vật chất bên ngoài bắt đầu thoát ra.

**Stage 4 – Fragmentation**

Vật thể vỡ thành nhiều mảnh có khối lượng và vận tốc riêng.

**Stage 5 – Debris Stream**

Các mảnh vỡ tạo dòng vật chất kéo dài theo quỹ đạo.

**Stage 6 – Accretion**

Một số mảnh vỡ đi vào đĩa bồi tụ, một số bay ra ngoài, số khác rơi qua chân trời sự kiện.

Quan trọng:

Không bắt buộc vật thể phải đi qua đủ sáu giai đoạn.

Nếu hố đen quá lớn, một hành tinh có thể đi qua chân trời sự kiện trước khi bị phá hủy hoàn toàn.

Nếu vật thể vượt qua chân trời sự kiện khi còn nguyên vẹn, xử lý hấp thụ đúng mô hình thay vì cố tạo hiệu ứng nổ phi vật lý.

## 8. MÔ PHỎNG VA CHẠM

Tạo hệ thống va chạm hành tinh.

Các loại va chạm:

- Asteroid vs Earth.
- Moon vs Earth.
- Planet vs Planet.
- Gas Giant vs Rocky Planet.
- Star vs Star.
- Neutron Star vs Black Hole.

Sau va chạm:

- Tính năng lượng.
- Xác định mức phá hủy.
- Tạo miệng hố.
- Biến dạng bề mặt.
- Phun đá và bụi.
- Tạo vật chất nóng chảy.
- Thay đổi nhiệt độ.
- Cập nhật khối lượng và động lượng.
- Tạo mảnh vỡ tiếp tục chịu hấp dẫn.

Sử dụng phương pháp xấp xỉ phù hợp như procedural fragmentation, clustered rigid fragments hoặc GPU particles.

Không để vụ nổ chỉ là particle rồi vật thể chính tự biến mất.

---

# PHẦN IV – ĐỒ HỌA HÀNH TINH CHẤT LƯỢNG CAO

## 9. SỬA HỆ MẶT TRỜI QUÁ ĐƠN ĐIỆU

Hiện tại hệ Mặt Trời trông giống bản đồ sao với nhiều chấm nhỏ.

Tôi muốn nó trở thành môi trường 3D có thể khám phá, zoom gần từng hành tinh và xem bề mặt chi tiết.

Tạo các hệ thống:

- Procedural Planet Generation.
- Planet Surface Shader.
- Atmospheric Scattering.
- Volumetric Clouds xấp xỉ.
- Ocean Shader.
- Planetary Rings.
- Surface Deformation.
- Planet LOD.
- Dynamic Planet Lighting.

## 10. CHI TIẾT RIÊNG CHO CÁC HÀNH TINH

**Earth**
- Lục địa.
- Đại dương.
- Núi.
- Mây động.
- Khí quyển xanh.
- Ánh sáng ban đêm.
- Ngày và đêm.
- Băng ở hai cực.

**Mars**
- Địa hình sa mạc đỏ.
- Hố va chạm.
- Olympus Mons nếu dữ liệu địa hình cho phép.
- Khí quyển mỏng.
- Bụi.

**Jupiter**
- Các dải khí.
- Great Red Spot.
- Chuyển động khí quyển.
- Shader nhiễu mây.

**Saturn**
- Vành đai cấu tạo từ các lớp hạt.
- Bóng đổ lên hành tinh.
- Các vùng mật độ khác nhau.

**Venus**
- Khí quyển dày.
- Mây vàng nhạt.
- Hiệu ứng tán xạ ánh sáng.

**Mercury**
- Bề mặt đá.
- Miệng hố va chạm.
- Ánh sáng và bóng đổ rõ rệt.

**Uranus & Neptune**
- Khí quyển xanh.
- Chuyển động mây.
- Các dải khí không quá nổi bật.

**Sun**
- Granulation.
- Stellar Corona.
- Solar Flares.
- Prominences.
- Surface Turbulence.
- Temperature-based Emission.

Không sử dụng các quả cầu đơn sắc làm mô hình cuối cùng.

---

# PHẦN V – BLACK HOLE SYSTEM

## 11. HỐ ĐEN 3D CHÂN THỰC

Tạo BlackHoleRenderer bằng Unity HLSL Shader.

Bao gồm:

- Event Horizon.
- Black Hole Shadow.
- Photon Sphere.
- Gravitational Lensing.
- Accretion Disk.
- Relativistic Doppler Beaming.
- Gravitational Redshift.
- Plasma Turbulence.
- Photon Ring.
- Tidal Disruption.
- Debris Accretion.

Sử dụng ray marching hoặc phương pháp tích phân quỹ đạo tia sáng xấp xỉ.

Không tạo hố đen bằng một quả cầu đen với vòng sáng đơn giản.

Đĩa bồi tụ phải:
- Chuyển động khác nhau theo bán kính.
- Có nhiều lớp vật chất.
- Có vùng nóng và lạnh.
- Có turbulence.
- Có mật độ thay đổi.
- Có Doppler brightening.
- Có ánh sáng HDR.

Không để texture bị lặp thành các đường sọc đồng tâm đều nhau.

## 12. HỐ ĐEN TƯƠNG TÁC VỚI HỆ MẶT TRỜI

Cho phép:

- Spawn Black Hole.
- Replace Sun With Black Hole.
- Black Hole Passing Through Solar System.
- Earth Falling Into Black Hole.
- Neutron Star vs Black Hole.

Khi thêm hố đen:

- Quỹ đạo các hành tinh thay đổi theo hấp dẫn.
- Thiên thể có thể bị bắt giữ hoặc bay thoát.
- Vật chất có thể bị xé nếu ứng suất vượt ngưỡng.
- Vật thể đi qua chân trời sự kiện được hấp thụ.

Nếu thay Mặt Trời bằng hố đen có cùng khối lượng và giữ nguyên vị trí, vận tốc, các hành tinh ở xa phải có chuyển động quỹ đạo ban đầu gần giống trước đó, không tự động rơi hết vào hố đen.

---

# PHẦN VI – THÊM CÁC THIÊN THỂ NGOÀI VŨ TRỤ

## 13. THƯ VIỆN THIÊN THỂ

Tạo Celestial Body Library với:

**Planets**
- Earth-like Planet
- Rocky Planet
- Lava Planet
- Ocean Planet
- Ice Planet
- Gas Giant
- Ice Giant
- Dwarf Planet

**Small Bodies**
- Asteroid
- Comet
- Meteoroid
- Moon
- Debris
- Ring Particles

**Stars**
- Red Dwarf
- Main Sequence Star
- Red Giant
- Blue Giant
- White Dwarf
- Neutron Star
- Pulsar
- Magnetar

**Black Holes**
- Stellar Black Hole
- Intermediate-Mass Black Hole
- Supermassive Black Hole

**Large Structures**
- Star Cluster
- Nebula
- Spiral Galaxy
- Elliptical Galaxy
- Galaxy Cluster

Có thư viện tìm kiếm, hình xem trước, phân loại và nút Spawn.

## 14. THIÊN HÀ 3D

Tạo hệ thống Galaxy Renderer có thể mô phỏng và hiển thị:

- Milky Way.
- Andromeda-like Galaxy.
- Spiral Galaxy.
- Elliptical Galaxy.
- Irregular Galaxy.

Hiển thị:
- Hàng nghìn điểm sao.
- Nhánh xoắn thiên hà.
- Bụi liên sao.
- Vùng hình thành sao.
- Lõi thiên hà phát sáng.

Sử dụng GPU Instancing và LOD.

Không tính hấp dẫn từng cặp sao trong một thiên hà chứa hàng triệu sao nếu vượt khả năng phần cứng. Sử dụng mô hình thế hấp dẫn xấp xỉ và particle representation.

Cho phép chuyển đổi giữa chế độ mô phỏng hệ hành tinh và chế độ quan sát thiên hà với các mô hình có độ chính xác và thang đo phù hợp.

---

# PHẦN VII – GIAO DIỆN GAME

## 15. GIAO DIỆN COSMIC SANDBOX

Thiết kế giao diện hiện đại, dễ sử dụng.

**Toolbar**
- Add
- Delete
- Replace
- Move
- Focus
- Orbit
- Velocity
- Temperature
- Collision
- Save
- Load

**Object Inspector**
- Name
- Mass
- Radius
- Density
- Temperature
- Velocity
- Rotation
- Atmosphere
- Composition
- Orbit Type
- Eccentricity
- Structural Integrity
- Tidal Stress
- Destruction State

**Time Controller**
- Pause
- Play
- Step
- Slow Motion
- Fast Forward
- Simulation Speed

**Visualization**
- Orbit Trails
- Velocity Vectors
- Gravity Vectors
- Labels
- Habitable Zone
- Temperature Map
- True Size
- Visual Scale

## 16. CAMERA

- Orbit Camera.
- Fly Camera.
- Follow Object.
- Focus Selected.
- Smooth Zoom.
- Cinematic Camera.
- Adaptive Camera Distance.
- Floating Origin.

Khi xem toàn hệ Mặt Trời, các thiên thể nhỏ phải có marker dễ nhìn.

Khi zoom gần, marker được thay bằng mesh 3D chi tiết.

Không để tên các hành tinh đè lên nhau.

---

# PHẦN VIII – GAMEPLAY VÀ KỊCH BẢN

## 17. SCENARIO PRESETS

Tạo các kịch bản:

1. Real Solar System.
2. Earth & Moon.
3. Binary Stars.
4. Asteroid Impact.
5. Earth vs Moon Collision.
6. Jupiter vs Earth.
7. Sun Removed.
8. Replace Sun With Black Hole.
9. Replace Earth With Mars.
10. Black Hole Observatory.
11. Earth Falling Into Black Hole.
12. Neutron Star vs Black Hole.
13. Supernova.
14. Milky Way Galaxy.
15. Galaxy Collision – Visual Approximation.
16. Custom Sandbox.

Các preset phải hoạt động thực sự chứ không chỉ thay đổi tên scene.

---

# PHẦN IX – HIỆU SUẤT

## 18. TỐI ƯU CHO WINDOWS

Phần cứng mục tiêu:

- Intel Core i7-11800H.
- NVIDIA RTX 3050 Ti Laptop GPU.
- RAM 16GB.
- Windows 11.

Tối ưu bằng:

- Unity Jobs.
- Burst.
- GPU Instancing.
- Compute Shaders.
- LOD.
- Frustum Culling.
- Object Pooling.
- Adaptive Physics Timestep.
- Efficient Particle Management.
- Memory Profiling.
- GPU Profiling.

Có ba chế độ:
- Performance.
- Balanced.
- Ultra.

Mục tiêu 60 FPS tại 1080p cho cảnh có số lượng thiên thể vừa phải.

Không đánh đổi độ chính xác vật lý cốt lõi chỉ để tăng FPS. Khi cần, hãy giảm số hạt trực quan và độ phân giải render trước.

---

# PHẦN X – KIỂM TRA VÀ TRIỂN KHAI

## 19. CÁC BÀI TEST BẮT BUỘC

Test 1:
Mở Solar System và kiểm tra hệ Mặt Trời có đầy đủ hành tinh, ánh sáng và shader.

Test 2:
Xóa Sun và quan sát các hành tinh rời khỏi quỹ đạo cũ theo vận tốc và lực hấp dẫn còn lại.

Test 3:
Xóa Earth, thay bằng Mars và kiểm tra quỹ đạo mới.

Test 4:
Spawn Black Hole vào hệ Mặt Trời và kiểm tra lực hấp dẫn tác động lên các hành tinh.

Test 5:
Tạo kịch bản tidal disruption đủ điều kiện. Vật thể phải biến dạng, nứt vỡ và tạo debris.

Test 6:
Thử một hố đen siêu khối lượng cho phép vật thể vượt chân trời sự kiện trước khi bị xé, xác nhận mô phỏng không ép chạy hoạt ảnh phá hủy sai vật lý.

Test 7:
Cho hai hành tinh va chạm và kiểm tra bảo toàn động lượng, hình thành mảnh vỡ.

Test 8:
Tạo sao neutron và kiểm tra thông số vật lý.

Test 9:
Tạo thiên hà có nhiều điểm sao và kiểm tra hiệu suất.

Test 10:
Build Windows x64 và chạy EXE độc lập.

## 20. YÊU CẦU CHUYỂN ĐỔI CODE

Hãy lập bảng mapping từ các script Godot cũ sang Unity C#.

Đảm bảo:

- Không làm mất dữ liệu thiên thể.
- Không làm mất preset.
- Không làm hỏng thuật toán hấp dẫn đang hoạt động.
- Chuyển các shader cần thiết.
- Tạo Unity Prefab tương ứng.
- Tạo scene và hierarchy rõ ràng.
- Thiết lập package dependencies.
- Cung cấp hướng dẫn build.

Không chỉ đổi đuôi file từ .gd thành .cs.

Phải chuyển đổi kiến trúc thực sự.

## 21. TRIỂN KHAI THEO GIAI ĐOẠN

Phase 1 – Migration
- Đọc và phân tích dự án Godot.
- Tạo Unity Project.
- Chuyển dữ liệu và N-body physics.
- Chuyển các scene cơ bản.
- Tạo camera và UI.
- Đảm bảo hệ Mặt Trời chạy được.

Phase 2 – Interactive Sandbox
- Add / Delete / Replace Object.
- Clone Orbit.
- Scenario Presets.
- Save / Load.
- Sun Removed Physics Test.

Phase 3 – Destruction Physics
- Collision.
- Tidal Deformation.
- Fragmentation.
- Debris.
- Planetary Heating.
- Black Hole Accretion.

Phase 4 – Graphics
- Planet Shader.
- Star Shader.
- Atmosphere.
- Lighting.
- Black Hole Rendering.
- Space Background.

Phase 5 – Advanced Space Objects
- Neutron Stars.
- Pulsars.
- Comets.
- Asteroid Belts.
- Galaxies.
- Supernovae.

Phase 6 – Optimization
- Jobs / Burst.
- GPU Instancing.
- Performance Settings.
- Debugging.
- Windows EXE Build.

Mỗi Phase phải có phiên bản game chạy được trước khi tiếp tục.

## 22. KẾT QUẢ CUỐI CÙNG

Tôi muốn có một game Windows thực sự tên COSMIC SANDBOX 3D, được phát triển bằng Unity 6.

Game phải có:

- Hệ Mặt Trời 3D chi tiết.
- Vật lý hấp dẫn N-body.
- Thêm, xóa và thay thế thiên thể.
- Hố đen và sao neutron.
- Thiên thạch và sao chổi.
- Hệ thống phá hủy hành tinh theo giai đoạn khi điều kiện vật lý phù hợp.
- Va chạm tạo mảnh vỡ.
- Mô phỏng mất quỹ đạo khi xóa sao trung tâm.
- Thiên hà 3D.
- Camera tự do.
- Giao diện sandbox.
- Save / Load.
- Cài đặt đồ họa.
- Khả năng xuất Windows EXE.

Yêu cầu AI:

1. Phân tích dự án Godot hiện tại.
2. Lập kế hoạch chuyển đổi sang Unity.
3. Xác định các thành phần có thể giữ và các phần phải viết lại.
4. Tạo cấu trúc Unity Project hoàn chỉnh.
5. Viết C# source code thực tế.
6. Tạo scene, prefab, shader và UI cần thiết.
7. Kiểm tra các chức năng.
8. Hướng dẫn build Windows EXE.

Không tạo một bản demo sơ sài thay cho dự án hoàn chỉnh.

Không chỉ trả lời bằng lý thuyết.

Không tự tuyên bố đã hoàn thành khi chưa có code và kiểm thử.

Hãy bắt đầu bằng Phase 1, sau đó tiếp tục từng giai đoạn và giữ nguyên tiến độ đã triển khai.
