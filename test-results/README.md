# Ảnh kiểm tra mô phỏng

## Godot 4 — Native Phase 1

`godot-menu.png`, `godot-earth.png`, `godot-sun.png` và
`godot-earth-moon.png` là framebuffer của Godot 4.6.3, Vulkan Forward+
trên llvmpipe. Xem `godot-cosmic/VALIDATION.md`; các ảnh này không phải
ảnh từ bản Three.js và không xác nhận FPS trên RTX.

## Cosmic Sandbox — Phase 1

`cosmic-overview.png`, `cosmic-earth.png` và `cosmic-mobile.png` được chụp
trong bộ 14 nhóm kiểm tra trình duyệt của ứng dụng vũ trụ. Chế độ Balanced
tự giảm độ phân giải trên GPU phần mềm, nên ảnh có thể có răng cưa nhiều
hơn khi chạy trên GPU thật.

`cosmic-earth-closeup.png` và `cosmic-sun.png` là ảnh kiểm tra renderer
riêng, hiển thị chi tiết bề mặt và granulation. Chúng không gồm các bảng UI.

## Event Horizon — Phòng quan sát hố đen

Ảnh của phiên bản đã sửa: `edge-view.png`, `top-view.png`, `mobile.png`,
`offline.png` và `screenshot.png`.

Ảnh lưu để đối chiếu quá trình sửa: `before-fix.png`, `initial.png`,
`edge.png`, `top.png`, `fix-edge.png` và `fix-top.png`.

Các ảnh được chụp bằng Chromium với GPU phần mềm SwiftShader. Chúng phục vụ
kiểm tra hình ảnh và chức năng, không phải kết quả đo hiệu năng GPU thực.

Bản HTML hố đen hiện tại nằm tại `dist/blackhole.html`.
`dist/event-horizon-source.zip` giữ bản lưu trước khi bổ sung Cosmic
Sandbox. Hướng dẫn chạy và giới hạn mô hình được ghi trong `USAGE.md`.

Cosmic Sandbox dùng `dist/index.html`, hố đen dùng `dist/blackhole.html`.
Gói mã nguồn chung mới là `dist/cosmic-sandbox-source.zip`; xem
`COSMIC_SANDBOX.md` để chạy trên Windows và đọc giới hạn của Phase 1.
