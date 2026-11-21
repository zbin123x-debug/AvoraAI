# Tiến độ triển khai

## Đã làm

- Khởi tạo Git, Flutter app, ASP.NET Core 8 API, EF Core/SQL Server và tài liệu dự án.
- Áp dụng 12 migration vào đúng database `AvoraAI_DB`; cấu hình kết nối và khóa JWT bằng User Secrets.
- Xây dựng đăng ký email/OTP, đăng nhập, refresh/revoke token, quên/đặt lại mật khẩu, đổi mật khẩu/email, xóa tài khoản có OTP và hồ sơ onboarding.
- X?y d?ng CRUD t? l?nh theo ng??i d?ng; danh m?c th?c ph?m ch?p nh?n ?? b?n ch? ti?u ??u, c?n m?n thi?u ch? ti?u c?n Admin ki?m tra ngu?n v? x?c minh. T?i ?u AI v?n y?u c?u ?? 8 ch? ti?u c?ng ngu?n ?? x?c minh.
- Xây dựng yêu thích, đánh giá, thống kê yêu thích và API Admin cho tài khoản, thực phẩm, nguồn dinh dưỡng, đánh giá; bootstrap Admin dùng khóa thiết lập một lần.
- Xây dựng giao diện Flutter tiếng Việt: đăng nhập/đăng ký, OTP, onboarding, trang chủ, tủ lạnh, hồ sơ/bảo mật, yêu thích và các trang Admin.
- Hoàn thiện trang Admin/SuperAdmin quản lý thực phẩm: lọc theo 9 nhóm, tìm kiếm, quản lý nhóm, thêm/sửa/xóa, lưu nháp, gram, nguồn, ảnh và 12 chỉ tiêu. Chỉ tạo nhóm mặc định, chưa nhập thực phẩm mẫu.
- Bổ sung khu vực SuperAdmin tách quyền khỏi Admin: quản lý tài khoản Admin, khóa/mở khóa, xóa mềm/khôi phục, OTP email, tổng quan và nhật ký kiểm toán; lần đăng nhập đầu buộc đổi mật khẩu.
- Thêm hướng dẫn cấu hình SMTP an toàn qua User Secrets và script thiết lập Admin lần đầu.
- Triển khai Quản lý món ăn: nguyên liệu liên kết `FoodID`, định lượng chỉ để hướng dẫn nấu, các bước có thứ tự, ảnh, mẹo/nguồn, nháp/công bố và thùng rác khôi phục; không đưa dinh dưỡng món hoặc thiết lập GA–PSO vào form.
- Công bố món yêu cầu tên, nguyên liệu còn liên kết hợp lệ và ít nhất một bước nấu; người dùng thường chỉ đọc món đã công bố. Admin/SuperAdmin được quản lý; chỉ SuperAdmin khôi phục; thao tác ghi nhật ký.
- Làm mới trang Cá nhân theo thiết kế tham khảo: avatar và sửa hồ sơ, thông tin cơ thể, thói quen ăn uống, liên kết mục tiêu/bảo mật/xóa tài khoản; dữ liệu liên hệ được che bớt.

## Kiểm tra gần nhất

- `dotnet test backend/AvoraAI.API.Tests/AvoraAI.API.Tests.csproj`: pass 10/10, kiểm tra chính sách mật khẩu và OTP.
- `flutter analyze`: pass, không issue; `flutter test`: pass 1/1.
- `flutter build apk --debug`: build thành công.
- APK debug mới đã cài và mở trên Vsmart Active 1; API đang chạy ở cổng 5080 và ADB reverse đã thiết lập.
- API khởi động tại `http://localhost:5080`; `/api/health` báo `database=connected`, cấu hình SMTP hiện có mật khẩu. Endpoint tủ lạnh khi chưa đăng nhập trả HTTP 401.
- Bản debug mới đã cài và mở `MainActivity` trên Vsmart Active 1 (Android 9); ADB reverse chuyển cổng 5080. Chưa kiểm tra trực quan giao diện vì màn hình thiết bị đang khóa.
- Migration `DishManagement` đã áp dụng vào `AvoraAI_DB`; database hiện không có món cũ cần chuyển trạng thái.
- API smoke test trên database tạm đã đạt các luồng phân quyền, nháp, kiểm tra công bố, FoodID, sửa/sắp xếp bước, tìm/lọc, ảnh, xóa mềm/khôi phục và dữ liệu tồn tại sau khi khởi động lại. Database thử đã xóa sau kiểm tra.
- `flutter analyze`, `flutter test` (4 kiểm thử) và `dotnet build` đều đạt; APK Android debug build thành công và đã cài trên Vsmart Active 1. Chưa xác nhận tràn giao diện bằng mắt vì màn hình điện thoại khóa.
- APK có trang Cá nhân mới đã cài và mở trên Vsmart Active 1; logcat không ghi nhận lỗi tràn bố cục ở lần mở này. Màn hình thiết bị vẫn khóa nên chưa xem trực quan được giao diện.
- Lỗi khởi động ở endpoint xóa user Admin được phát hiện trong lần chạy API và sửa; API đã khởi động thành công sau sửa.
- Quy tắc mật khẩu đã được cập nhật: dài 10–128 ký tự, bắt đầu bằng chữ hoa, có ít nhất một chữ số ASCII và một ký tự đặc biệt ASCII; backend, giao diện và script bootstrap Admin cùng áp dụng.

- Ba tài khoản Admin cũ không có email trong `AvoraAI_DB` đã được xóa vĩnh viễn theo yêu cầu; nhật ký thao tác vẫn được giữ. Admin mới mặc định hoạt động, đăng nhập bằng email ngay mà không xác minh Gmail hay đổi mật khẩu lần đầu; OTP chỉ dùng khi đổi mật khẩu/email/số điện thoại.
- SuperAdmin hiện đăng nhập bằng email; username đã gỡ khỏi tài khoản. Mật khẩu được cập nhật theo yêu cầu và lưu dạng băm; không lưu mật khẩu trong tài liệu. Các phiên cũ đã bị thu hồi.
- Lịch sử bootstrap ban đầu được xác minh trả role SuperAdmin và cờ buộc đổi mật khẩu; khóa bootstrap đã xóa khỏi User Secrets.

## Còn chờ hoặc chưa có

- Cấu hình User Secrets hiện có mật khẩu SMTP; chưa gửi email thật hoặc xác nhận OTP đã được nhận.
- Chưa có dịch vụ SMS hoặc luồng xác minh số điện thoại.
- Chưa nhập dữ liệu món ăn/thực phẩm; danh mục món ăn rỗng và gợi ý AI chưa được nối dịch vụ/model.
- Chưa triển khai định nghĩa nghiệp vụ “đã dùng” và thống kê sử dụng thực phẩm.
- Chưa tạo tài khoản User thật.
- Chưa có kiểm thử end-to-end cho mọi API, email thật, hoặc kiểm thử trực quan khi điện thoại được mở khóa.






- Triển khai thùng rác thực phẩm: Admin chuyển thực phẩm vào thùng rác; SuperAdmin xem, khôi phục hoặc xóa vĩnh viễn. Xóa mềm giữ lại dinh dưỡng, nguồn và ảnh; migration `AddFoodTrash` đã áp dụng vào database phát triển.
- Trash visibility: Admins can inspect deleted foods and see who deleted them; only SuperAdmin can restore or permanently delete.
