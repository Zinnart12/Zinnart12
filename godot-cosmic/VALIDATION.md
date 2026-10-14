# Validation — Godot 4.6.3 / Phase 1

Đã chạy trong môi trường Linux cloud, ngày 14/10/2026 (giờ Việt Nam).

| Kiểm tra | Kết quả |
| --- | --- |
| Import editor, đăng ký GDScript và scene | Đạt, Godot 4.6.3 Standard |
| PhysicsTests.gd | 16 đạt, 0 lỗi |
| SceneTests.gd | 16 đạt, 0 lỗi |
| GraphicsTests.gd | 7 đạt, 0 lỗi |
| Renderer thực | Vulkan 1.4.305, Forward+ |
| GPU kiểm tra | llvmpipe / LLVM 19.1.7 (phần mềm) |
| Windows export release | Đạt, Windows x86-64 EXE + embedded PCK |
| Gói PCK trong Windows EXE | Load và chạy menu bằng Godot Linux headless thành công |
| Windows 10 chạy EXE thực tế | Chưa thực hiện trong cloud Linux |
| Benchmark RTX 3050 Ti 1080p/60 FPS | Chưa thực hiện |

Kiểm tra vật lý gồm một năm Trái Đất, một chu kỳ Mặt Trăng, tăng khối
lượng Mặt Trời, vận tốc thoát, quỹ đạo elip 5 năm, swept contact, bảo toàn
khối lượng/thể tích/động lượng, nhiệt va chạm, thời gian theo ngân sách,
độ phân giải 1 mét ở khoảng cách AU, ổn định cả 10 thiên thể, validation,
lưu native giữ bit double và yêu cầu thời gian ở 1/30/60/120 FPS.

Sai số năng lượng tương đối cực đại của bài quỹ đạo elip 5 năm, e=0.6:
**3.69211861 × 10⁻⁶**, dưới ngưỡng kiểm tra 8 × 10⁻⁵. Đây là kết quả của
bài kiểm tra cụ thể, không phải giới hạn sai số cho mọi kịch bản.

Các test lưu dùng file riêng, không ghi đè bản lưu người chơi.

Scene/UI tests gọi các signal điều khiển thật và xác minh trạng thái:
main menu vào game, pause, slider khối lượng, floating origin, true size,
lưu/tải, presets, chất lượng, từ chối dữ liệu sai. Graphics tests chụp
framebuffer thật; so ảnh Earth khi mesh hiện/ẩn để tránh coi UI hoặc sao
nền là bằng chứng hành tinh đã render. Kiểm tra granulation còn chi tiết
sau tone mapping và đồ họa thực sự dùng Forward+.

Ảnh kiểm tra tại `../test-results/godot-menu.png`, `godot-earth.png`,
`godot-sun.png`, `godot-earth-moon.png`.

Không dùng Compatibility để thay thế phép kiểm tra Forward+. Các thư viện
Mesa Vulkan và Xvfb được tải bằng APT với metadata/checksum đã kiểm tra,
giải nén vào cache riêng trong workspace. Audio Dummy chỉ dùng trong
kiểm tra cloud không có thiết bị âm thanh.

Export templates chính thức 4.6.3 được tải từ release của Godot,
SHA-256 đã xác minh:

```text
Godot_v4.6.3-stable_export_templates.tpz
3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8
```

Gói Windows không được ký bằng chứng thư thương mại. Nội dung EXE dùng
template chính thức và PCK xuất từ dự án, không có launcher HTML.
