namespace AvoraAI.API.Services;

public static class PasswordPolicy
{
    public const string Requirement = "Mật khẩu cần dài 10–128 ký tự, bắt đầu bằng chữ hoa, có ít nhất một chữ số và một ký tự đặc biệt.";

    public static bool IsValid(string? password)
    {
        if (string.IsNullOrEmpty(password) || password.Length is < 10 or > 128)
            return false;

        return char.IsUpper(password[0])
            && password.Any(c => c is >= '0' and <= '9')
            && password.Any(IsSpecialAscii);
    }

    private static bool IsSpecialAscii(char c) =>
        c is >= '!' and <= '/' or >= ':' and <= '@' or >= '[' and <= '`' or >= '{' and <= '~';
}
