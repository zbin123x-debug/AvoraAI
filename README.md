# Avora AI

Ứng dụng Flutter cho Android, ASP.NET Core Web API và SQL Server. Giao diện đang được xây dựng theo mô tả tiếng Việt trong [yêu cầu](docs/requirements.md). Chưa có ảnh phác thảo để đối chiếu.

## Thành phần

- `frontend/`: Flutter Android.
- `backend/AvoraAI.API/`: ASP.NET Core 8 API, EF Core và SQL Server.
- `backend/AvoraAI.API.Tests/`: kiểm thử OTP và chính sách mật khẩu.
- `docs/`: yêu cầu, thiết kế, cài đặt và tiến độ.

Xem [docs/setup.md](docs/setup.md) để chạy. Mật khẩu SMTP và khóa JWT nằm trong User Secrets cục bộ; không commit chúng.

