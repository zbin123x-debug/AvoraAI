using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Options;
using MimeKit;

namespace AvoraAI.API.Services;

public sealed class SmtpOptions
{
    public string Host { get; set; } = "smtp.gmail.com";
    public int Port { get; set; } = 587;
    public string SenderName { get; set; } = "Avora AI";
    public string SenderEmail { get; set; } = "zbin789x@gmail.com";
    public string Username { get; set; } = "zbin789x@gmail.com";
    public string? Password { get; set; }
}

public interface IOtpSender { Task SendAsync(string destination, string purpose, string code, CancellationToken ct); }

public sealed class EmailOtpSender(IOptions<SmtpOptions> options, ILogger<EmailOtpSender> logger) : IOtpSender
{
    public async Task SendAsync(string destination, string purpose, string code, CancellationToken ct)
    {
        var s = options.Value;
        if (string.IsNullOrWhiteSpace(s.Password)) throw new InvalidOperationException("SMTP chưa được cấu hình mật khẩu ứng dụng. Hãy nhập bằng User Secrets theo docs/smtp-setup.md.");
        var mail = new MimeMessage();
        mail.From.Add(new MailboxAddress(s.SenderName, s.SenderEmail));
        mail.To.Add(MailboxAddress.Parse(destination));
        mail.Subject = "Mã xác minh Avora AI";
        mail.Body = new BodyBuilder { TextBody = $"Xin chào,\n\nMã OTP Avora AI của bạn là: {code}\nMục đích: {PurposeName(purpose)}.\nMã có hiệu lực trong 60 giây và chỉ sử dụng được một lần.\n\nNếu bạn không thực hiện yêu cầu này, hãy bỏ qua email.\nAvora AI" }.ToMessageBody();
        try
        {
            using var client = new SmtpClient();
            await client.ConnectAsync(s.Host, s.Port, SecureSocketOptions.StartTls, ct);
            await client.AuthenticateAsync(s.Username, s.Password, ct);
            await client.SendAsync(mail, ct);
            await client.DisconnectAsync(true, ct);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            logger.LogWarning("Không gửi được email OTP. Loại lỗi: {ErrorType}", ex.GetType().Name);
            throw new InvalidOperationException("Không gửi được email xác minh. Hãy kiểm tra cấu hình SMTP và thử lại.");
        }
    }

    private static string PurposeName(string purpose) => purpose switch
    {
        "Register" => "xác minh đăng ký", "PasswordReset" => "đặt lại mật khẩu",
        "ContactChange" => "thay đổi email", "PasswordChange" => "đổi mật khẩu tài khoản",
        "AdminPhoneChange" => "thay đổi số điện thoại", "AccountDeletion" => "xóa tài khoản", _ => "xác minh tài khoản"
    };
}
