# Thiết kế database

Database mục tiêu: `AvoraAI_DB` trên instance `localhost\MSSQLSERVER01`, Windows Authentication. Các migration được quản lý bằng Git.

| Bảng | Vai trò và ràng buộc |
|---|---|
| Users | username/email/điện thoại duy nhất khi khác NULL; mật khẩu băm; vai trò và trạng thái xác minh/khóa. Username hiện dùng cho Admin |
| Profiles | 1–1 với User, xóa cascade; lưu ba bước onboarding và dị ứng JSON |
| OtpChallenges | mã băm, đích nhận, mục đích, hết hạn, lượt sai, đã dùng; chỉ lưu hash |
| RefreshSessions | hash refresh token, hạn dùng và thu hồi; quan hệ User cascade |
| FridgeItems | nguyên liệu theo User, tên duy nhất trong từng User, tùy chọn FoodId |
| Foods / FoodNutrition | thực phẩm chưa chế biến, 8 giá trị nullable (trên 100 g phần ăn được) |
| NutritionSources | nguồn gắn với từng trường dưỡng chất của thực phẩm; trạng thái kiểm tra nguồn |
| Dishes | khung món ăn, chưa nạp dữ liệu |
| Favorites / Ratings | khóa kép User + Dish để tránh bản ghi lặp |
| AdminActionLogs | hành động quản trị và lý do |

Thi?u d??ng ch?t l?u NULL, kh?ng t? g?n 0. B?ng FoodNutrition d?ng FoodId l?m kh?a ch?nh ki?m kh?a ngo?i. Danh m?c API hi?n th? nguy?n li?u ch?a ch? bi?n c? ?? 4 ch? ti?u ??u h?p l?; m?c thi?u ch? ti?u ch? hi?n th? sau x?c minh Admin. T?i ?u AI v?n d?ng y?u c?u 8/8 ch? ti?u v? ngu?n ?? ki?m tra.

Không có bảng FoodUsage vì ý nghĩa nghiệp vụ “đã sử dụng” chưa được chốt.
