Hãy trực tiếp xây dựng ứng dụng **Avora AI** trong thư mục dự án **AvoraAI** đang mở trong VS Code, theo toàn bộ yêu cầu dưới đây.

Làm từng giai đoạn, giải thích ngắn gọn bằng tiếng Việt, kiểm tra kết quả và tiếp tục những phần đã đủ thông tin. Không chỉ đưa code để tôi tự chép; hãy tạo và chỉnh sửa các file cần thiết trong dự án.

**1. Phạm vi và quyền thực hiện**

Tôi cho phép bạn:

- Đọc, tạo và chỉnh sửa file trong dự án AvoraAI.
- Chạy các lệnh cần thiết để kiểm tra môi trường, cài dependency của dự án, build, chạy và kiểm thử.
- Kết nối database `AvoraAI_DB` và tạo bảng bằng EF Core Migrations.
- Kiểm tra điện thoại Android đã kết nối và chạy ứng dụng trên thiết bị đó.

Yêu cầu:

- Kiểm tra thư mục và mã nguồn hiện có trước khi làm.
- Nếu đã có phần triển khai, tiếp tục và hoàn thiện, không tự tạo lại toàn bộ.
- Chỉ thao tác với dự án AvoraAI và database AvoraAI_DB.
- Không sửa hoặc xóa dự án, database khác.
- Không tự xóa database để tạo lại nhằm xử lý lỗi.
- Không tự mở cổng SQL Server ra Internet hoặc thay đổi VPN.
- Không đưa bí mật vào Git hoặc log.
- Không dừng sau mỗi bước chỉ để hỏi có làm tiếp không.
- Chỉ hỏi khi thiếu thông tin thực sự ảnh hưởng đến triển khai.
- Các quyền mà công cụ yêu cầu xác nhận vẫn phải được xử lý qua giao diện cấp quyền.

**2. Công nghệ và môi trường**

- Công cụ: VS Code và Codex.
- Frontend: Flutter.
- Backend: ASP.NET Core Web API.
- Database: SQL Server.
- Truy cập dữ liệu: Entity Framework Core.
- Giao diện: tiếng Việt.
- Tôi có điện thoại Android thật, đã kết nối USB và bật chế độ nhà phát triển.
- Không tạo máy ảo Android.

Kiểm tra:

- Flutter và Dart.
- Android SDK và thiết bị qua `flutter devices`.
- Tình trạng môi trường qua `flutter doctor`.
- .NET SDK.
- Kết nối SQL Server.
- Phiên bản dependency tương thích với SDK hiện có.

Không tự nâng cấp toàn bộ môi trường nếu không cần thiết.

**3. SQL Server và database đã có**

Thông tin thực tế:

| Thuộc tính | Giá trị |
|---|---|
| Server Name | `tranxuanthanh\MSSQLSERVER01` |
| Địa chỉ tương đương trên máy tôi | `localhost\MSSQLSERVER01` |
| Authentication | Windows Authentication |
| Database | `AvoraAI_DB` |
| SQL Server | Developer 64-bit |
| Phiên bản đã thấy trong SSMS | `16.0.1000.6` |

Tôi đã tạo database `AvoraAI_DB` trong SSMS.

Hãy:

- Kiểm tra kết nối từ backend.
- Kiểm tra database và các bảng hiện có.
- Dùng EF Core Migrations để tạo/cập nhật cấu trúc bảng.
- Không yêu cầu mật khẩu SQL khi sử dụng Windows Authentication.
- Lưu cấu hình riêng của máy bằng User Secrets.
- Không dùng SQLite thay thế SQL Server.
- Không kết nối Flutter trực tiếp đến SQL Server.

Luồng dữ liệu: Flutter gọi API; backend kiểm tra quyền và đọc/ghi SQL Server.

**4. Nguyên tắc giao diện**

- Toàn bộ nội dung chính hiển thị bằng tiếng Việt.
- Thống nhất màu sắc, kiểu chữ, nút, ô nhập và khoảng cách.
- Nếu tôi đính kèm ảnh phác thảo, bám theo bố cục và hình thức của ảnh.
- Nếu chưa có ảnh trong phiên làm việc, nói rõ chưa có ảnh để đối chiếu; làm theo mô tả bên dưới, không tuyên bố đã giống bản phác thảo.
- Không tự thêm chức năng làm thay đổi yêu cầu.
- Giao diện phù hợp điện thoại Android thật.
- Khi bàn phím mở, nội dung cuộn được và không tràn màn hình.
- Có trạng thái đang tải, trống, lỗi mạng, lỗi nhập liệu và thử lại.
- Không hiển thị dữ liệu giả như dữ liệu thật.
- Các nút phải có hành vi rõ ràng; phần chưa triển khai phải thể hiện đúng tình trạng.

**5. Phân quyền và sở hữu dữ liệu**

Có hai vai trò:

- **User:** sử dụng ứng dụng, quản lý dữ liệu cá nhân.
- **Admin:** quản lý người dùng, thực phẩm, đánh giá và thống kê.

Quy tắc:

- Backend kiểm tra quyền cho mọi API cần bảo vệ.
- User chỉ truy cập dữ liệu của chính mình.
- Xác định người dùng từ token đã xác thực.
- Không tin userId do frontend tùy ý gửi để xác định chủ sở hữu.
- Người đăng ký thông thường không được tự chọn Admin.
- Chuẩn bị cách tạo Admin ban đầu bằng cấu hình riêng hoặc công cụ thiết lập; không hardcode mật khẩu Admin.
- Tài khoản bị khóa phải bị backend từ chối sử dụng theo chính sách phiên đăng nhập.

**6. Đăng nhập**

Màn hình gồm:

- Email hoặc số điện thoại.
- Mật khẩu.
- Nút hiện/ẩn mật khẩu.
- Nút Đăng nhập.
- Quên mật khẩu.
- Dòng “Chưa có tài khoản? Đăng ký”.

Sau đăng nhập:

- Admin → giao diện Admin.
- User chưa hoàn tất hồ sơ → tiếp tục hồ sơ lần đầu.
- User đã hoàn tất hồ sơ → giao diện chính.

Lưu phiên an toàn để mở lại ứng dụng không phải đăng nhập lại khi phiên còn hợp lệ. Xử lý phiên hết hạn, bị thu hồi và lỗi mạng rõ ràng.

**7. Đăng ký**

Cho chọn một trong hai phương thức:

- Email, xác minh OTP qua email.
- Số điện thoại, xác minh OTP qua SMS.

Form gồm:

- Email/số điện thoại.
- Mật khẩu.
- Xác nhận mật khẩu.
- Nút tiếp tục/gửi OTP.
- Đường quay lại đăng nhập.

Xác minh thành công mới kích hoạt tài khoản. Không để đăng ký trùng thông tin liên hệ đã được sử dụng theo quy tắc chuẩn hóa.

Email ưu tiên triển khai thật trước. Khi SMS chưa được cấu hình, không báo đã gửi SMS.

**8. OTP: tất cả đều 60 giây**

Áp dụng cho:

- Xác minh đăng ký.
- Quên mật khẩu.
- Thay đổi email/số điện thoại.
- Xóa tài khoản.

Quy tắc:

- Hết hạn sau 60 giây kể từ khi backend tạo mã.
- Giao diện hiển thị đếm ngược đến hết hạn.
- Thời hạn do backend quyết định; mở lại màn hình không làm mã sống thêm.
- Chỉ dùng một lần.
- Đúng tài khoản và đúng mục đích.
- Gửi lại mã làm mã cũ mất hiệu lực.
- Có giới hạn số lần nhập sai và gửi lại.
- Không lưu mã dạng rõ trong database.
- Không trả OTP trong API.
- Không ghi OTP vào log thật.
- Không chấp nhận mã hết hạn, đã dùng hoặc sai mục đích.
- Khi gửi email/SMS thất bại, không trả thông báo gửi thành công.

Màn hình OTP có:

- Thông tin nơi nhận được che một phần khi phù hợp.
- Ô nhập mã.
- Đếm ngược.
- Xác nhận.
- Gửi lại.
- Quay lại.

**9. SMTP: cấu hình đầy đủ, mật khẩu nhập cuối cùng**

Thông tin đã xác định:

| Trường | Giá trị |
|---|---|
| Tên người gửi | Avora AI |
| Email người gửi | `zbin789x@gmail.com` |
| Username SMTP | `zbin789x@gmail.com` |
| Host | `smtp.gmail.com` |
| Port | `587` |
| Bảo mật | STARTTLS |
| Password | Tôi nhập mật khẩu ứng dụng Google sau |

Tôi đã tạo mật khẩu ứng dụng Google nhưng chưa nhập vào dự án.

Hãy làm hoàn chỉnh trước:

- SMTP service.
- Cấu hình và kiểm tra cấu hình.
- Mẫu email tiếng Việt mang tên Avora AI.
- Nội dung có mã OTP, mục đích và thời hạn 60 giây.
- Tích hợp vào các luồng OTP.
- Xử lý lỗi kết nối, xác thực SMTP và gửi thất bại.
- Thông báo phù hợp khi chưa có mật khẩu.
- Kiểm thử logic bằng cơ chế kiểm thử tách biệt môi trường thật.

Chuẩn bị User Secrets:

- Khởi tạo User Secrets cho backend.
- Điền các thông số đã biết.
- Mật khẩu để chưa cấu hình, không tự đặt mật khẩu giả.
- Chuẩn bị script hoặc cách nhập mật khẩu trực tiếp trên máy có ẩn ký tự.
- Không đưa mật khẩu vào lịch sử lệnh, chat, log hoặc file Git theo dõi.
- Không in toàn bộ User Secrets để kiểm tra.
- Chỉ kiểm tra trường cần thiết đã được cấu hình hay chưa.

**Không dừng các phần khác vì chưa có mật khẩu SMTP.**

Sau khi hoàn thành những phần có thể làm:

1. Hướng dẫn tôi nhập mật khẩu ứng dụng Google trên máy.
2. Chờ tôi xác nhận đã nhập.
3. Kiểm tra gửi OTP thật đến địa chỉ nhận thử tôi chỉ định.
4. Chỉ báo gửi email thật thành công khi có kết quả thực tế.

Trước đó báo rõ: “Đã triển khai mã nguồn SMTP; chưa xác nhận gửi email thật vì đang chờ mật khẩu ứng dụng.”

SMS phải có nhà cung cấp riêng. Chuẩn bị cấu trúc tích hợp, nhưng không giả lập rồi báo gửi SMS thật.

**10. Hồ sơ lần đầu: 3 trang**

**Trang 1 — Thông tin cá nhân và cơ thể**

- Họ tên.
- Ngày sinh.
- Giới tính.
- Chiều cao, cm.
- Cân nặng hiện tại, kg.
- Mục tiêu: giảm cân, giữ cân hoặc tăng cân.
- Cân nặng mong muốn nếu có.
- Ô “Đặc điểm tăng cân” do người dùng tự nhập.
- Gợi ý: dễ tăng cân, khó tăng cân hoặc bình thường.

Không tự suy ra chỉ số dinh dưỡng từ ô “Đặc điểm tăng cân”.

**Trang 2 — Thói quen ăn uống**

- Số bữa ăn mỗi ngày.
- Ăn chay hoặc ăn bình thường.
- Danh sách nguyên liệu/thực phẩm dị ứng.
- Lựa chọn “Không có dị ứng”.
- Cho phép nhập thêm nguyên liệu dị ứng.

Không để trạng thái “Không có dị ứng” đồng thời mâu thuẫn với danh sách dị ứng đã chọn.

**Trang 3 — Vận động và hoàn tất**

- Ít vận động.
- Vận động nhẹ.
- Vận động vừa.
- Vận động nhiều.
- Xem lại thông tin trước khi hoàn tất.

Quy tắc giao diện và lưu:

- Hiển thị tiến độ 1/3, 2/3, 3/3.
- Nút **Tiếp tục nằm ở góc trên bên phải**.
- Trang cuối dùng nút **Hoàn tất** ở vị trí tương ứng.
- Các trang sau có nút quay lại.
- Quay lại không mất dữ liệu.
- Lưu tiến độ theo tài khoản để tiếp tục khi chưa hoàn tất.
- Chỉ đánh dấu hoàn tất sau khi lưu dữ liệu hợp lệ thành công.
- Lần đăng nhập sau không yêu cầu điền lại nếu đã hoàn tất.

**11. Giao diện chính**

Thanh điều hướng phía dưới gồm đúng thứ tự:

1. Trang chủ.
2. Tủ lạnh.
3. Cá nhân.

Giữ trạng thái hợp lý khi chuyển tab.

Trang chủ:

- Là trang đầu tiên khi User đã hoàn tất hồ sơ.
- Nội dung chi tiết chưa chốt.
- Trước mắt tạo khung giao diện và lối vào chức năng đã thống nhất.
- Không tự hiển thị mục tiêu calo, thực đơn, chỉ số sức khỏe hoặc kết quả AI giả.

**12. Tủ lạnh**

Chức năng:

- Xem danh sách.
- Thêm.
- Sửa.
- Xóa.

Quy tắc:

- Lưu nguyên liệu/thực phẩm **chưa chế biến** đang có.
- Chỉ nhập/chọn **tên thực phẩm**.
- Không yêu cầu số lượng, khối lượng hoặc quản lý tồn kho.
- Mỗi User có danh sách riêng.
- Khi chọn từ danh mục hệ thống, chỉ hiện thực phẩm đủ điều kiện cung cấp cho User.
- Cho phép tự ghi tên nguyên liệu, nhưng tên tự ghi không tự trở thành thực phẩm đã xác minh.
- Phân biệt bản ghi liên kết danh mục với tên tự ghi.
- Không dùng dữ liệu chưa xác minh để tính dinh dưỡng.

**13. Cá nhân và chỉnh sửa hồ sơ**

Trang Cá nhân có:

- Xem hồ sơ.
- Chỉnh sửa hồ sơ.
- Bảo mật tài khoản.
- Món yêu thích.
- Đăng xuất.

Cho phép sửa thông tin đã khai báo:

- Họ tên, ngày sinh, giới tính.
- Chiều cao, cân nặng.
- Mục tiêu và cân nặng mong muốn.
- Đặc điểm tăng cân.
- Số bữa/ngày.
- Chế độ ăn.
- Dị ứng.
- Mức vận động.

Có nút Lưu thay đổi. Kiểm tra trường bắt buộc và cho phép xóa nội dung không bắt buộc.

Dữ liệu phải lưu vào SQL Server theo tài khoản, không chỉ giữ trong bộ nhớ Flutter.

**14. Bảo mật và khôi phục tài khoản**

Các chức năng:

- Xem email/số điện thoại và trạng thái xác minh.
- Đổi mật khẩu.
- Thay đổi email/số điện thoại.
- Quên mật khẩu.
- Đặt lại mật khẩu.
- Xóa tài khoản.
- Đăng xuất.

Thay đổi thông tin liên hệ:

- Xác minh quyền sở hữu tài khoản.
- Xác minh thông tin mới bằng OTP.
- Không thay thông tin cũ trước khi hoàn tất.
- Kiểm tra thông tin mới chưa thuộc tài khoản khác.

Đổi mật khẩu và đặt lại mật khẩu phải có chính sách xử lý phiên cũ rõ ràng.

Đăng xuất xóa thông tin phiên trên thiết bị và vô hiệu hóa refresh token tương ứng nếu có.

**15. User tự xóa tài khoản**

Quy trình:

1. Chọn Xóa tài khoản.
2. Hiện thông báo về tài khoản và dữ liệu sẽ bị xóa.
3. Người dùng xác nhận tiếp tục.
4. Gửi OTP đến thông tin liên hệ đã xác minh.
5. Nhập mã và bấm Xác nhận xóa.
6. Backend chỉ thực hiện khi OTP hợp lệ trong 60 giây.
7. Xóa dữ liệu cá nhân liên quan theo thiết kế, vô hiệu hóa phiên và đưa về trang đăng nhập.

Mã sai, hết hạn, đã dùng hoặc hủy thì không xóa.

Thao tác phải nhất quán, không để dữ liệu bị xóa một phần khi phát sinh lỗi.

**16. Khu vực Admin**

Các trang chính:

- Tổng quan.
- Quản lý người dùng.
- Quản lý thực phẩm đã xác minh.
- Thực phẩm chưa xác minh.
- Quản lý đánh giá.
- Thống kê món yêu thích.
- Thống kê thực phẩm sử dụng.

Dùng dữ liệu thật. Khi chưa có dữ liệu, hiện trạng thái trống hoặc số tổng hợp thực tế.

**17. Admin quản lý người dùng**

- Danh sách.
- Tìm kiếm.
- Xem chi tiết.
- Thêm.
- Sửa.
- Xóa.
- Khóa/mở khóa.

Thông tin được xem:

- Hồ sơ.
- Email/số điện thoại.
- Vai trò.
- Ngày tạo.
- Trạng thái xác minh.
- Trạng thái hoạt động/khóa.

Không xem mật khẩu, mã OTP hoặc token bí mật.

Admin thêm User không được tự coi thông tin liên hệ là đã xác minh.

Admin xóa User:

- Có xác nhận.
- Ghi lý do.
- Ghi lịch sử quản trị.
- Là luồng riêng với User tự xóa bằng OTP.

**18. Admin quản lý thực phẩm**

Danh mục hiện tại sử dụng thực phẩm **chưa chế biến**.

Admin được:

- Xem, tìm kiếm.
- Thêm, sửa, xóa.
- Nhập 8 chỉ tiêu.
- Nhập nguồn.
- Kiểm tra và xác minh nguồn.
- Xem chỉ tiêu thiếu.

Mỗi thực phẩm có:

- Tên.
- Trạng thái chưa chế biến.
- Cơ sở tính thống nhất: trên 100 g phần ăn được.
- 8 giá trị dinh dưỡng.
- Nguồn đối chiếu.
- Trạng thái xác minh.
- Thông tin người/thời điểm xác minh khi phù hợp.

Nếu nhiều chỉ tiêu lấy từ nhiều nguồn, phải truy được nguồn của từng chỉ tiêu.

Không tự tạo số liệu hoặc thực phẩm mẫu để làm đầy danh mục. Khi được cung cấp file dữ liệu, kiểm tra và báo cấu trúc, số bản ghi, trường thiếu trước khi nhập.

**19. Danh sách 8 chỉ tiêu bắt buộc**

| STT | Chỉ tiêu | Đơn vị |
|---|---|---|
| 1 | Năng lượng | kcal |
| 2 | Protein — Chất đạm | g |
| 3 | Carbohydrate | g |
| 4 | Chất béo tổng | g |
| 5 | Chất xơ | g |
| 6 | Đường tổng | g |
| 7 | Chất béo bão hòa | g |
| 8 | Natri | mg |

Quy tắc:

- Khi thêm mới, cả 8 ô để trống.
- Thiếu dữ liệu lưu `NULL`; không tự điền 0.
- Số 0 hợp lệ nếu có nguồn xác nhận.
- Không chấp nhận số âm hoặc sai định dạng.
- Ô thiếu hiển thị “Chưa có thông tin — Chưa xác minh”.
- Có số liệu chưa đồng nghĩa nguồn đã được xác minh.
- Chỉ tiêu chỉ đánh dấu “Đã xác minh” khi dữ liệu hợp lệ và nguồn đã kiểm tra.
- **Đủ 8/8 chỉ tiêu hợp lệ và đã kiểm tra nguồn mới được dùng trong tối ưu AI.**
- Thiếu một chỉ tiêu hoặc chưa đạt điều kiện nguồn thì chỉ Admin thấy trong danh mục chưa xác minh.
- Xóa hoặc sửa số liệu/nguồn làm mất điều kiện thì trạng thái phải cập nhật lại.
- Khi sửa một giá trị đã xác minh, phải kiểm tra lại giá trị bị sửa.

**20. Món ăn, yêu thích và đánh giá**

Phân biệt:

- Thực phẩm: nguyên liệu chưa chế biến.
- Món ăn: có công thức và thành phần nguyên liệu.

User:

- Xem chi tiết món.
- Yêu thích/bỏ yêu thích.
- Xem danh sách yêu thích.
- Đánh giá 1–5 sao.
- Nhận xét tùy chọn.
- Cập nhật đánh giá của mình.

Mỗi User chỉ có một trạng thái yêu thích và một đánh giá hiện hành cho cùng một món; tránh tạo trùng do bấm nhiều lần.

Admin:

- Xem số lượt yêu thích.
- Xếp hạng món.
- Xem điểm trung bình, số đánh giá và nhận xét.
- Quản lý nhận xét không phù hợp.
- Lọc theo khoảng thời gian.

Danh mục món, công thức và cách bố trí chi tiết trên Trang chủ chưa chốt. Tạo cấu trúc và trạng thái trống nếu chưa có dữ liệu; không bịa công thức hoặc dinh dưỡng món.

**21. Thống kê thực phẩm sử dụng**

Mục tiêu:

- Thực phẩm dùng nhiều.
- Số lần sử dụng.
- Số người sử dụng.
- Thống kê theo ngày, tháng hoặc khoảng thời gian.

Thêm nguyên liệu vào tủ lạnh **không đồng nghĩa đã sử dụng**.

Hành động ghi nhận “đã sử dụng” chưa chốt. Không tự dùng lượt thêm tủ lạnh thay thế. Có thể chuẩn bị khung, nhưng ghi rõ phần nghiệp vụ đang chờ chốt và không tạo số thống kê giả.

**22. Định hướng AI cho giai đoạn sau**

Định hướng: **Hybrid GA–PSO**.

- GA chọn tổ hợp thực phẩm, ưu tiên nguyên liệu có tên trong tủ lạnh.
- PSO tối ưu khẩu phần gram theo mục tiêu cá nhân và dữ liệu đã xác minh.
- Không dùng khối lượng tồn kho vì tủ lạnh chỉ lưu tên.
- Phân biệt nguyên liệu chưa chế biến và món đã nấu.
- Không tự suy ra hệ số biến đổi dinh dưỡng khi chế biến.

Chưa triển khai kết quả AI trong giai đoạn này. Trước mắt hoàn thiện nền tảng, dữ liệu và giao diện đã chốt. Không giả lập kết quả AI như kết quả thật.

**23. Cấu trúc thư mục**

Cấu trúc chính:

- `frontend/`
- `backend/AvoraAI.API/`
- `backend/AvoraAI.API.Tests/`
- `database/`
- `docs/`
- `README.md`
- `.gitignore`

Flutter:

- `lib/main.dart`
- `lib/app.dart`
- `lib/config/`
- `lib/models/`
- `lib/services/`
- `lib/providers/` hoặc một giải pháp quản lý trạng thái nhất quán.
- `lib/widgets/`
- `lib/screens/auth/`
- `lib/screens/onboarding/`
- `lib/screens/user/`
- `lib/screens/user/fridge/`
- `lib/screens/user/personal/`
- `lib/screens/user/dishes/`
- `lib/screens/admin/`
- `lib/screens/admin/users/`
- `lib/screens/admin/foods/`
- `lib/screens/admin/reviews/`
- `lib/screens/admin/statistics/`
- `assets/`
- `test/`

Backend:

- `Controllers/`
- `Controllers/Admin/`
- `Models/`
- `DTOs/`
- `Services/`
- `Data/`
- `Data/Configurations/`
- `Authorization/`
- `Middleware/`
- `Migrations/`
- `Program.cs`
- `appsettings.json` không chứa bí mật.

Các nhóm model dự kiến:

- User.
- UserProfile và tiến độ onboarding.
- OtpChallenge.
- RefreshToken hoặc bản ghi phiên phù hợp.
- FridgeItem.
- Food.
- FoodNutrition.
- NutritionSource và liên kết nguồn chỉ tiêu.
- Dish.
- DishIngredient.
- Favorite.
- Rating.
- FoodUsage khi nghiệp vụ đã chốt.
- AdminActionLog.

Có thể điều chỉnh tên kỹ thuật để phù hợp thiết kế, nhưng không bỏ chức năng.

Thiết kế rõ khóa chính, khóa ngoại, ràng buộc, chỉ mục và hành vi xóa. Không nhét toàn bộ logic vào một file.

**24. Các màn hình cần có**

| Khu vực | Màn hình |
|---|---|
| Tài khoản | Đăng nhập, đăng ký, OTP, quên mật khẩu, đặt lại mật khẩu |
| Hồ sơ lần đầu | Trang 1 thông tin cơ thể, trang 2 ăn uống, trang 3 vận động và xem lại |
| Giao diện chính | Trang chủ, Tủ lạnh, Cá nhân |
| Tủ lạnh | Danh sách, thêm/sửa nguyên liệu, xác nhận xóa |
| Hồ sơ | Xem, chỉnh sửa |
| Bảo mật | Thông tin liên hệ, đổi liên hệ, đổi mật khẩu, xóa tài khoản |
| Món ăn | Chi tiết, yêu thích, đánh giá |
| Admin | Tổng quan |
| Admin người dùng | Danh sách, chi tiết, thêm/sửa, khóa/mở khóa, xóa |
| Admin thực phẩm | Danh sách đã xác minh, danh sách chưa xác minh, form 8 chỉ tiêu và nguồn |
| Admin đánh giá | Danh sách và quản lý nhận xét |
| Admin thống kê | Yêu thích, thực phẩm sử dụng theo phần nghiệp vụ đã đủ |

**25. Dữ liệu, phiên và kết nối điện thoại**

- Lưu dữ liệu thật trong SQL Server.
- Mật khẩu được băm bằng cơ chế phù hợp.
- Token lưu bằng secure storage trên Flutter.
- Xử lý access token và refresh token nhất quán nếu dùng cơ chế refresh.
- Phiên bị thu hồi, tài khoản khóa hoặc bị xóa phải mất quyền truy cập.
- Lỗi mạng tạm thời không tự xóa phiên hợp lệ.
- Địa chỉ API Flutter cấu hình tập trung và có thể thay đổi theo môi trường.
- Không hardcode IP rải rác.
- Khi chạy điện thoại thật, dùng địa chỉ truy cập được đến backend; localhost trên điện thoại không phải máy tính.
- Không đưa chuỗi kết nối SQL hoặc mật khẩu SMTP vào ứng dụng Flutter.

**26. Làm việc nhóm và Git**

- Mã nguồn và migrations được quản lý bằng Git.
- Chuẩn bị `.gitignore` đúng.
- Có cấu hình mẫu không chứa bí mật.
- Có hướng dẫn từng thành viên cấu hình máy riêng.
- Database hiện ở máy tôi; chưa cấu hình truy cập từ xa.
- Không báo các thành viên đã kết nối được khi chưa kiểm tra.
- Khi dùng database chung, chỉ định một người áp dụng migrations.
- Không đưa dữ liệu tài khoản thật, OTP hoặc token vào dữ liệu mẫu trong Git.

**27. Kiểm thử bắt buộc theo chức năng**

Backend:

- Đăng ký và xác minh.
- Đăng nhập đúng/sai.
- Phân quyền User/Admin.
- Ngăn truy cập dữ liệu người khác.
- OTP hết hạn, dùng lại, sai mục đích, gửi lại và nhập sai.
- Xử lý chưa cấu hình SMTP/gửi thất bại.
- Hồ sơ lưu và tiếp tục đúng tiến độ.
- Tủ lạnh riêng theo tài khoản.
- Thực phẩm đủ 8 chỉ tiêu, thiếu chỉ tiêu, giá trị 0 và thiếu nguồn.
- Không truy cập thực phẩm chưa xác minh bằng API User.
- Khóa tài khoản và thu hồi phiên.
- Xóa tài khoản với OTP và hành vi xóa dữ liệu liên quan.
- Ngăn bản ghi yêu thích/đánh giá trùng.

Flutter:

- Kiểm tra nhập liệu.
- Điều hướng theo vai trò và tình trạng hồ sơ.
- Quay lại onboarding không mất dữ liệu.
- Các trạng thái tải, trống và lỗi.
- Khôi phục phiên, đăng xuất.
- Bố cục khi bàn phím mở.
- Kết nối API và chạy trên điện thoại thật khi có thiết bị.

Chạy build, test và `flutter analyze` phù hợp. Báo đúng kiểm thử nào đã chạy, kiểm thử nào chưa chạy được.

Không báo đã gửi email thật, đã kết nối SMS hoặc đã thử trên điện thoại nếu chưa làm được.

**28. Tài liệu cần tạo**

Trong `docs/`:

- `requirements.md`: yêu cầu đầy đủ.
- `screen-map.md`: màn hình và điều hướng.
- `database-design.md`: bảng, quan hệ và ràng buộc.
- `nutrition-fields.md`: 8 chỉ tiêu, đơn vị, cơ sở tính và xác minh.
- `api-endpoints.md`: API và quyền truy cập.
- `setup.md`: chạy backend/frontend, SQL Server và điện thoại.
- `smtp-setup.md`: nhập mật khẩu ứng dụng sau và kiểm tra email.
- `team-workflow.md`: hướng dẫn Git, cấu hình riêng và migrations.
- `progress.md`: trạng thái thực hiện, đã kiểm thử và phần còn chờ.

Không ghi bí mật thật vào tài liệu.

**29. Thứ tự triển khai**

1. Kiểm tra môi trường, mã nguồn và điện thoại.
2. Ghi lại yêu cầu, sơ đồ màn hình và kế hoạch ngắn gọn.
3. Chuẩn bị cấu trúc frontend/backend.
4. Kết nối AvoraAI_DB và áp dụng migrations cần thiết.
5. Hoàn thiện mã nguồn email OTP, đăng ký, đăng nhập và phân quyền.
6. Làm hồ sơ lần đầu 3 trang.
7. Làm Trang chủ dạng khung, Tủ lạnh, Cá nhân và bảo mật.
8. Làm Admin quản lý người dùng.
9. Làm quản lý thực phẩm với 8 chỉ tiêu và nguồn.
10. Làm yêu thích, đánh giá và thống kê đã đủ định nghĩa.
11. Kiểm thử, sửa lỗi, chạy trên điện thoại thật.
12. Hoàn thiện hướng dẫn và cách nhập mật khẩu SMTP.
13. Khi tôi nhập xong mật khẩu, kiểm tra gửi email OTP thật.

**30. Cách báo cáo và điều kiện hoàn thành**

Sau mỗi giai đoạn báo ngắn gọn:

- Đã làm.
- Đã kiểm thử và kết quả.
- Phần còn thiếu cấu hình hoặc chờ nghiệp vụ.
- Bước tiếp theo.

Không coi việc tạo đủ file là đã hoàn thành chức năng. Các luồng đã đủ yêu cầu phải hoạt động xuyên suốt từ Flutter đến API và SQL Server.

Các phần được phép chờ:

- Mật khẩu SMTP và kiểm tra gửi email thật.
- Nhà cung cấp SMS.
- Ảnh giao diện chưa được cung cấp.
- Nội dung chi tiết Trang chủ.
- Danh mục/công thức món chưa có dữ liệu.
- Định nghĩa hành động “sử dụng thực phẩm”.
- Thuật toán AI giai đoạn sau.
- Kết nối database từ xa cho nhóm.

Tiếp tục các phần độc lập khi gặp mục đang chờ; không dùng mục đó làm lý do dừng toàn bộ dự án.

**Bắt đầu kiểm tra và triển khai ngay trong thư mục AvoraAI đang mở. Riêng mật khẩu SMTP, để tôi nhập sau khi bạn hoàn thiện các phần có thể thực hiện.**
