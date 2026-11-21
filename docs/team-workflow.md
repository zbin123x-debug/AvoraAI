# Làm việc nhóm và Git

- Commit source, migration, tài liệu; không commit User Secrets, `secrets.json`, token, OTP hay dữ liệu tài khoản.
- Mỗi máy thành viên tự cài .NET/Flutter/Android SDK và thiết lập User Secrets riêng. Database hiện chỉ có trên máy chủ dự án này, chưa bật truy cập từ xa.
- Khi cùng dùng database, chỉ định một người áp dụng migration; các thành viên còn lại cập nhật code.
- Cấu hình API bằng `--dart-define=API_BASE_URL=...`, không ghi địa chỉ LAN cố định vào source.
- Không dùng dữ liệu mẫu chứa thông tin cá nhân thật.
