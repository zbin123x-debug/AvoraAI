# SMTP Gmail và OTP

Backend dùng `smtp.gmail.com:587`, STARTTLS, tên hiển thị Avora AI, người gửi `zbin789x@gmail.com`. Mẫu email nêu mục đích và thời hạn 60 giây. OTP là sáu chữ số sinh bằng bộ sinh mật mã; database chỉ giữ SHA-256 có gắn id challenge và mục đích. API không trả OTP.

Thông số SMTP công khai được cấu hình; mật khẩu ứng dụng chưa nhập. Khi thiếu mật khẩu, gửi OTP trả lỗi cấu hình và không báo gửi thành công. Chưa xác nhận email thật.

## Nhập mật khẩu ứng dụng sau

Từ thư mục gốc, chạy `scripts\set-smtp-password.ps1`. Script đọc mật khẩu bằng prompt ẩn, ghi `Smtp:Password` vào User Secrets ngoài repository, không in mật khẩu. Không truyền mật khẩu theo tham số dòng lệnh. Sau đó chỉ kiểm tra cờ cấu hình tại `/api/health`; không in toàn bộ secrets.

Để xác minh email thật, chỉ định địa chỉ nhận thử, chạy API, gọi đăng ký/forgot-password, xác nhận email thực sự nhận được. Nếu có lỗi SMTP, API trả lỗi chung và log chỉ ghi loại exception.

Logic OTP có bài kiểm tra tách biệt SMTP trong `backend/AvoraAI.API.Tests`. Chưa gửi email thật.

SMS chưa có nhà cung cấp và chưa được mô phỏng như gửi thành công.
