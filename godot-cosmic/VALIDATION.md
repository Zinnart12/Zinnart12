# Validation — Godot 4.6.3 / Graphics & Black Hole Update

Kiểm tra trong Linux cloud ngày 14/10/2026 (giờ Việt Nam). Source sửa trực
tiếp dự án native, không đổi GravitySolver.gd và không bỏ ba preset gốc.

| Kiểm tra | Kết quả |
| --- | --- |
| Editor import / đăng ký GDScript / scene | Đạt, Godot 4.6.3 Standard |
| PhysicsTests.gd | 16 đạt, 0 lỗi |
| SceneTests.gd | 16 đạt, 0 lỗi |
| CompactPhysicsTests.gd | 22 đạt, 0 lỗi |
| CompactSceneTests.gd | 22 đạt, 0 lỗi |
| GraphicsTests.gd | 18 đạt, 0 lỗi |
| Tổng kiểm tra chức năng | **94 đạt, 0 lỗi** |
| Renderer thật | Vulkan 1.4.305, Forward+ |
| GPU kiểm tra | llvmpipe / LLVM 19.1.7 (phần mềm) |
| Windows export release | Windows x86-64 EXE, embedded PCK |
| Windows 10 chạy EXE trực tiếp | Chưa thực hiện trong Linux cloud |
| RTX 3050 Ti / 1080p / 60 FPS | Chưa benchmark |

## Kiểm tra vật lý

Giữ lại 16 kiểm tra nền tảng: một năm Earth, chu kỳ Moon, đổi khối lượng
Sun, escape velocity, quỹ đạo elip 5 năm, tiếp xúc swept, mass/volume/momentum,
nhiệt va chạm, thời gian theo ngân sách, độ phân giải 1 m ở AU, 10-body
stability, validation, FPS-independent requested time và native save double.
Sai số năng lượng lớn nhất bài elip 5 năm e=0.6 vẫn là **3.69211861e-6**.

Compact tests kiểm tra Rs cho 10 solar masses (**29.5334 km**), phân biệt
photon sphere/shadow, capture nội bộ và swept crossing, không bắt giữ khi
chỉ chạm bán kính hành tinh ở ngoài Rs, accreted mass/Rs/momentum, stress
vượt resistance tạo tám mảnh tiếp tục chịu lực, bảo toàn mass/momentum,
Earth nguyên vẹn vượt horizon của hố đen 1e9 solar masses, flux SI giảm còn
1/4 khi khoảng cách gấp đôi, dữ liệu sáu presets, neutron capture, lưu
compact properties, từ chối radius hố đen sai và precession.

Weak-field 1PN precession ở semimajor axis 100 Rs, e=0.2:
**0.0948353157 rad/orbit**, so với công thức bậc đầu **0.0981747704**;
ngưỡng kiểm tra 15%. Kết quả này không xác nhận quỹ đạo GR trong strong field.

## Kiểm tra giao diện và đồ họa

Scene tests dùng nút/signal thực: menu, pause, mass slider, camera WASD,
floating origin, true size, presets, renderer quality, lưu/tải và từ chối
restore sai. Compact scene tests thêm Add Object tạo Sagittarius A* với
ray renderer, tìm kiếm ID, disk checkbox, horizon theo mass, delete/save/load,
marker picking, focus đúng clipping, cả hai sao trong khung, đủ sáu presets,
ray budget 112→320, exposure/TAA, velocity/strength edits, invalid edits (bao gồm horizon dưới độ phân giải), paused Step đồng bộ danh sách sau capture.
Test lưu dùng file riêng, không ghi đè save người chơi.

Graphics tests chạy **Forward+ Vulkan thật**, chụp framebuffer. Không dùng
Compatibility để thay thế. Pixel bề mặt được lấy theo projection mesh và
ẩn label/marker, khắc phục phép đo cũ có thể lẫn UI. Đã kiểm tra:

- Cả 10 bodies có marker trong Solar overview; True Size Earth vẫn render
  bề mặt và snapshot SI không đổi khi focus.
- Day-side Earth sáng rõ hơn night-side; cloud/surface/ocean có variation;
  so mesh hiện/ẩn chứng minh pixel không đến từ UI hoặc sao nền.
- Sun và cả hai binary-star interiors đều phát sáng và giữ granulation.
- Earth–Moon material pipeline hoạt động.
- Black-hole center tối, plasma sáng; giảm nhiệt độ plasma từ 16.000 K
  xuống 8.000 K giảm radiance theo T⁴ ngoài việc đổi palette; thay thời gian thay đổi pixel của khí;
  tắt disk loại phát xạ plasma.
- Chế độ ray debug trên **chính GPU shader**: b=2.4 Rs bị bắt giữ,
  b=3.0 Rs thoát, bao quanh giá trị analytic shadow **2.598 Rs**.
- Neutron surface và magnetic-axis beam renderer chạy không lỗi frustum.
- Performance/Ultra/MSAA/TAA tác động lên viewport Forward+ thật.

Các ảnh ở `../test-results/godot-*.png`, bao gồm Solar overview, Earth,
True Size Earth, Sun, Binary Stars, Earth–Moon, Black Hole, plasma flow,
no-disk, Pulsar và UI black-hole preset. Đây là ảnh Godot native, không phải
ảnh Three.js hoặc ảnh được tạo bằng công cụ sinh hình.

## Export và giới hạn

Export dùng template chính thức **4.6.3**, archive SHA-256 đã xác minh:

```text
Godot_v4.6.3-stable_export_templates.tpz
3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8
```

Kiểm tra PE32+ Windows x86-64, CRC toàn ZIP và byte EXE trong ZIP khớp output
export. Gói source được import và chạy test từ thư mục giải nén mới, không
phụ thuộc `.godot` cache có sẵn. Embedded PCK được kiểm tra bằng Godot Linux
với menu và các scene/presets. PCK xuất ra còn render shadow/plasma qua
Forward+ Vulkan với pixel checks đạt; đó là kiểm tra resources/GDScript/shader,
**không phải chạy Windows executable bằng hệ điều hành Windows**.

Mesa Vulkan/Xvfb dùng metadata/checksum APT đã xác minh, cache riêng trong
workspace. Dummy audio chỉ phục vụ cloud không có thiết bị âm thanh.
EXE chưa có chữ ký chứng thư thương mại. Hai file license đi cùng ZIP.
Chưa có kết quả FPS trên GPU mục tiêu và không xác nhận 60 FPS từ llvmpipe.
Các giới hạn Newton/1PN, tidal threshold, finite rays/screen reprojection,
spin metadata, MHD/EOS/merger được nêu trong README.md.
