# Màn hình và điều hướng

## Tài khoản

- User đăng nhập bằng email/số điện thoại đã xác minh. Admin và SuperAdmin đăng nhập bằng email khi tài khoản được SuperAdmin bật hoạt động; trạng thái OTP email không chặn đăng nhập.
- Admin/SuperAdmin đổi mật khẩu đều xác minh OTP gửi tới email. Admin tạo mới dùng được ngay khi tài khoản được bật, không buộc đổi mật khẩu lần đầu. Đổi email nhận OTP tại email mới; đổi số điện thoại nhận OTP tại email hiện tại.
- Đăng ký email → OTP 6 số → xác minh → quay lại đăng nhập.
- Quên/đặt lại mật khẩu có API và biểu mẫu.
- SMS chưa có nhà cung cấp, vì vậy chưa có luồng gửi SMS.

## Hồ sơ lần đầu

1. Cơ thể: họ tên, ngày sinh, giới tính, chiều cao và cân nặng.
2. Ăn uống: số bữa, chế độ ăn, dị ứng và trạng thái không dị ứng.
3. Vận động: mức hoạt động, xem lại và lưu hoàn tất.

Tiến độ lưu ở hồ sơ SQL Server; mở lại hồ sơ tải lại dữ liệu. Thanh tiêu đề có tiến độ và nút thao tác phía trên bên phải.

## User

Thanh điều hướng dưới có bốn tab: Trang chủ → Mục tiêu → Tủ lạnh → Cá nhân. Trang chủ có ngày tháng tiếng Việt, lời chào theo hồ sơ, ảnh đại diện và hai lối vào Thực phẩm, Món yêu thích. Mục tiêu và Tủ lạnh mở trực tiếp ở tab riêng; các tab giữ trạng thái khi người dùng chuyển qua lại.

- Th?c ph?m l?y danh m?c t? API, ch? hi?n nguy?n li?u ch?a ch? bi?n c? ?? 4 ch? ti?u ??u h?p l?; m?n thi?u m?t trong b?n ch? ti?u c?n Admin ki?m tra ngu?n v? x?c minh. C? t?m ki?m v? th?m v?o t? l?nh.
- Mục tiêu dùng chiều cao, cân nặng và số bữa trong hồ sơ; kiểm tra hướng cân nặng mong muốn và lưu chung vào mục tiêu hồ sơ.
- Kết quả mục tiêu tính BMI hiện tại và tạo đúng số mục bữa ăn. Chưa có bộ tính khẩu phần cá nhân hóa đã kiểm chứng nên không hiển thị gram hoặc calo.
- Tủ lạnh lưu tên nguyên liệu theo tài khoản; có thể thêm từ danh mục hoặc tự nhập, sửa và bỏ khỏi tủ lạnh. Không lưu số lượng hay khẩu phần.
- Cá nhân có chỉnh sửa hồ sơ, bảo mật tài khoản, đổi ảnh đại diện, yêu thích và đăng xuất. Ảnh tải lên được lưu phía API và tham chiếu trong hồ sơ SQL.

## Admin

Khu vực Admin có lối vào Người dùng, Thực phẩm, Đánh giá và Thống kê yêu thích. Giao diện hỗ trợ tìm kiếm/chi tiết/khóa/mở khóa/xóa user, CRUD thực phẩm và kiểm tra nguồn dinh dưỡng, xem/xóa đánh giá và thống kê yêu thích. SuperAdmin duyệt trạng thái hoạt động của Admin. Thống kê thực phẩm đã dùng chưa làm vì nghiệp vụ chưa chốt.

Các màn hình nghiệp vụ còn lại được liệt kê trong [requirements.md](requirements.md). Nội dung Trang chủ và món ăn cố ý không có số liệu mẫu.

## SuperAdmin

Khu vực SuperAdmin gọn trong ba mục: Quản lý Admin, Nhật ký quản trị và Cá nhân/bảo mật. Nhật ký bắt đầu bằng danh sách Admin; chọn một Admin để xem riêng các thao tác do tài khoản đó thực hiện. Admin thông thường chỉ quản lý tài khoản User và không truy cập được API SuperAdmin.


