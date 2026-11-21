# API hiện có

Backend mặc định chạy tại `http://localhost:5080`; Swagger tại `/swagger`. API cần cấu hình User Secrets trong môi trường Development để kết nối database và ký JWT.

| Method | Endpoint | Quyền | Mô tả |
|---|---|---|---|
| GET | `/api/health` | Công khai | Trạng thái API, DB và cờ SMTP đã cấu hình (không trả secret) |
| POST | `/api/setup/bootstrap-admins` | Khóa thiết lập một lần | Luồng bootstrap username cũ; Admin tạo theo luồng này cần gắn và xác minh email trước khi đăng nhập |
| POST | `/api/setup/bootstrap-admin` | Khóa thiết lập một lần | Tạo Admin ban đầu bằng email |
| POST | `/api/setup/bootstrap-superadmin` | Khóa thiết lập một lần | Khởi tạo duy nhất SuperAdmin; bắt buộc đổi mật khẩu ở lần đăng nhập đầu |
| POST | `/api/auth/register`, `/api/auth/register/resend`, `/api/auth/verify-registration` | Công khai | Đăng ký và xác minh email bằng OTP |
| POST | `/api/auth/login`, `/api/auth/refresh`, `/api/auth/logout` | Công khai | User dùng email/điện thoại đã xác minh; Admin/SuperAdmin dùng email khi tài khoản được bật; xoay refresh token và thu hồi phiên |
| POST | `/api/auth/forgot-password`, `/api/auth/reset-password` | Công khai | Đặt lại mật khẩu qua OTP email |
| GET/PUT | `/api/me/profile` | User | Đọc/cập nhật hồ sơ onboarding theo token |
| GET/POST/PUT/DELETE | `/api/me/fridge` | User | CRUD nguyên liệu của người dùng hiện tại |
| GET | `/api/me/security` | Đã đăng nhập | Thông tin bảo mật/liên hệ |
| POST | `/api/me/security/password/request`, `/api/me/security/password` | Admin/SuperAdmin | Gửi OTP email và đổi mật khẩu sau xác minh; User đổi trực tiếp |
| POST | `/api/me/security/email/request`, `/api/me/security/email/confirm` | Đã đăng nhập | Đổi email sau OTP gửi tới email mới |
| POST | `/api/me/security/phone/request`, `/api/me/security/phone/confirm` | Admin/SuperAdmin | Đổi số điện thoại sau OTP gửi tới email hiện tại |
| POST | `/api/me/account/delete/request`, `/api/me/account/delete/confirm` | User | Xóa tài khoản sau OTP |
| GET | `/api/foods` | Công khai | Danh sách thực phẩm đã xác minh |
| GET | `/api/dishes`, `/api/dishes/{id}` | Công khai | Danh mục món ăn (hiện chưa có dữ liệu) |
| GET/POST/DELETE | `/api/me/favorites`, `/api/me/favorites/{dishId}` | User | Xem, thêm và bỏ món yêu thích |
| GET/PUT | `/api/me/ratings`, `/api/me/ratings/{dishId}` | User | Xem và tạo/cập nhật đánh giá 1–5 sao |
| GET | `/api/admin/users`, `/api/admin/users/{id}` | Admin | Tìm kiếm/danh sách và chi tiết user |
| PATCH/DELETE | `/api/admin/users/{id}`, `/api/admin/users/{id}/active` | Admin | Chỉ quản lý tài khoản User; yêu cầu lý do khi khóa/xóa |
| GET/POST/PUT/DELETE | `/api/admin/foods`, `/api/admin/foods/{id}` | Admin, SuperAdmin | CRUD thực phẩm và ảnh |
| GET/POST/PUT/DELETE | `/api/admin/food-groups`, `/api/admin/food-groups/{id}` | Admin, SuperAdmin | Quản lý nhóm; 9 nhóm mặc định, mã nhóm giữ cố định; chỉ xóa được nhóm trống |
| GET | `/api/admin/foods/pending`, `/api/admin/foods/verified` | Admin, SuperAdmin | Danh sách theo trạng thái xác minh |
| PATCH/POST | `/api/admin/foods/{id}/sources/{sourceId}`, `/api/admin/foods/{id}/verify` | Admin, SuperAdmin | Xác minh nguồn từng trường và xác minh thực phẩm theo 12 chỉ tiêu |

`FoodWriteRequest` nhận `groupId` và `isDraft`; lưu nháp cho phép để trống chỉ tiêu để cập nhật sau. Database có nhóm mặc định nhưng không có thực phẩm mẫu.
| GET/DELETE | `/api/admin/ratings`, `/api/admin/ratings/{userId}/{dishId}` | Admin | Xem theo thời gian và xóa đánh giá |
| GET | `/api/admin/statistics/favorites` | Admin | Thống kê xếp hạng món theo lượt yêu thích, có lọc thời gian |
| GET | `/api/superadmin/overview` | SuperAdmin | Số lượng Admin tổng, hoạt động và bị khóa |
| GET/POST | `/api/superadmin/admins`, `/api/superadmin/admins/{id}` | SuperAdmin | Danh sách, chi tiết và tạo tài khoản Admin |
| PATCH | `/api/superadmin/admins/{id}`, `/api/superadmin/admins/{id}/active` | SuperAdmin | Cập nhật hồ sơ hoặc khóa/mở khóa Admin kèm lý do |
| POST | `/api/superadmin/admins/{id}/delete`, `/api/superadmin/admins/{id}/restore` | SuperAdmin | Xóa mềm và khôi phục Admin; dữ liệu nghiệp vụ được giữ lại |
| POST | `/api/superadmin/admins/{id}/email/request`, `/api/superadmin/admins/{id}/email/confirm` | SuperAdmin | Gắn email cho Admin sau OTP |
| GET | `/api/superadmin/audit-logs` | SuperAdmin | Nhật ký có lọc người thao tác, hành động, thời gian và kết quả |

## Chưa có trong API

Chưa có SMS/xác minh số điện thoại, dữ liệu món ăn, gợi ý AI và nghiệp vụ ghi nhận thực phẩm đã dùng. Tài liệu này mô tả API hiện có; chưa phải hợp đồng production đầy đủ.

| GET | `/api/admin/foods/trash` | Admin, SuperAdmin | Xem thùng rác thực phẩm đã xóa mềm |
| DELETE | `/api/admin/foods/{id}` | Admin, SuperAdmin | Chuyển thực phẩm vào thùng rác, giữ lại dữ liệu và ảnh |
| POST | `/api/admin/foods/{id}/restore` | Chỉ SuperAdmin | Khôi phục thực phẩm trong thùng rác |
| DELETE | `/api/admin/foods/{id}/permanent` | Chỉ SuperAdmin | Xóa vĩnh viễn thực phẩm, nguồn, dinh dưỡng và ảnh |
