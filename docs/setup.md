# Thiết lập môi trường

## Backend

Yêu cầu .NET 8 SDK trở lên và SQL Server instance hiện có. Cấu hình kết nối cục bộ đã lưu bằng `dotnet user-secrets`; không đưa vào appsettings.

```powershell
cd backend/AvoraAI.API
dotnet restore
dotnet ef database update
dotnet run --urls http://0.0.0.0:5080
```

Backend được nhắm `AvoraAI_DB` qua Windows Authentication. Chỉ chạy `database update` với database này; không drop database. Kiểm tra `/api/health` và `/swagger`.

Tạo tài khoản Admin trong khu vực SuperAdmin. Nhập email và mật khẩu ban đầu; tài khoản mặc định hoạt động và đăng nhập được ngay bằng email, không cần xác minh Gmail hoặc đổi mật khẩu lần đầu. SuperAdmin có thể khóa/mở tài khoản. Khi Admin đổi mật khẩu, email hoặc số điện thoại thì OTP được gửi tới email tương ứng.

Khởi tạo SuperAdmin một lần: chạy `scripts\bootstrap-superadmin.ps1 -PrepareKeyOnly`, khởi động lại API, rồi chạy `scripts\bootstrap-superadmin.ps1` từ thư mục gốc, nhập email và mật khẩu khởi tạo qua prompt ẩn. SuperAdmin đăng nhập bằng email và buộc đổi mật khẩu ở lần đăng nhập đầu tiên. Script gửi yêu cầu qua loopback và xóa khóa thiết lập khỏi User Secrets. Mật khẩu không nằm trong mã nguồn hoặc tài liệu.

## Flutter

```powershell
cd frontend
flutter pub get
flutter analyze
flutter test
```

Máy ảo Android dùng địa chỉ bridge mặc định `http://10.0.2.2:5080`. Trên điện thoại thật, truyền địa chỉ LAN của máy chạy backend, ví dụ `--dart-define=API_BASE_URL=http://192.168.1.20:5080`. Điện thoại và máy tính cần cùng mạng; không mở SQL Server ra Internet. Trong phiên triển khai, Flutter đã nhận thiết bị Vsmart Active 1 (Android 9), cài và khởi chạy APK. Khi chạy bằng USB, có thể dùng `adb reverse tcp:5080 tcp:5080` và API URL `http://127.0.0.1:5080`; không mở SQL Server ra Internet. Màn hình điện thoại đang khóa nên chưa kiểm tra thao tác trực quan sau khi khởi chạy.

Kết nối bằng USB và bật USB debugging, chấp nhận hộp thoại RSA trên máy, sau đó xác nhận `flutter devices` thấy thiết bị. Flutter doctor có cảnh báo nhiều bản adb; SDK Android vẫn được nhận diện.

## Lệnh migration

Các migration nằm trong `Data/Migrations`; sáu migration đã được áp dụng cho `AvoraAI_DB`. Khi thay đổi model, tạo migration mới, xem file SQL/migration trước khi apply. Với database nhóm, chỉ một thành viên chạy migration.


