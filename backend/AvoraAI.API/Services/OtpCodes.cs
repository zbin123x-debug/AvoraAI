using System.Security.Cryptography;
using System.Text;
using AvoraAI.API.Models;

namespace AvoraAI.API.Services;

public static class OtpCodes
{
    public static (OtpChallenge Challenge, string Code) Create(Guid? userId, string destination, string purpose, DateTime? now = null)
    {
        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        var challenge = new OtpChallenge
        {
            UserId = userId, Destination = destination, Purpose = purpose,
            ExpiresAtUtc = (now ?? DateTime.UtcNow).AddSeconds(60)
        };
        challenge.CodeHash = Hash(challenge.Id, purpose, code);
        return (challenge, code);
    }

    public static bool Verify(OtpChallenge? challenge, string? code, DateTime? now = null)
    {
        if (challenge is null || challenge.ConsumedAtUtc is not null || challenge.ExpiresAtUtc <= (now ?? DateTime.UtcNow) || challenge.FailedAttempts >= 5)
            return false;
        var validFormat = code is not null && System.Text.RegularExpressions.Regex.IsMatch(code, "^\\d{6}$");
        var candidate = Hash(challenge.Id, challenge.Purpose, validFormat ? code! : "------");
        var expected = Convert.FromHexString(challenge.CodeHash);
        var actual = Convert.FromHexString(candidate);
        if (!CryptographicOperations.FixedTimeEquals(expected, actual))
        {
            challenge.FailedAttempts++;
            return false;
        }
        return validFormat;
    }

    private static string Hash(Guid id, string purpose, string code) => Convert.ToHexString(
        SHA256.HashData(Encoding.UTF8.GetBytes($"{id:N}:{purpose}:{code}")));
}
