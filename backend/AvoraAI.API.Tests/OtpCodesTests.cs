using AvoraAI.API.Services;

namespace AvoraAI.API.Tests;

public class OtpCodesTests
{
    [Fact]
    public void Code_IsValidOnlyForItsChallengeAndWindow()
    {
        var now = DateTime.UtcNow;
        var (challenge, code) = OtpCodes.Create(Guid.NewGuid(), "user@example.com", "Register", now);

        Assert.DoesNotContain(code, challenge.CodeHash);
        Assert.True(OtpCodes.Verify(challenge, code, now.AddSeconds(59)));
        Assert.False(OtpCodes.Verify(challenge, code, now.AddSeconds(60)));
        Assert.False(OtpCodes.Verify(challenge, code, now.AddSeconds(61)));
    }

    [Fact]
    public void WrongCodesAreCountedAndLockedAfterFiveAttempts()
    {
        var now = DateTime.UtcNow;
        var (challenge, code) = OtpCodes.Create(null, "user@example.com", "Register", now);
        var wrongCode = code == "000000" ? "000001" : "000000";

        for (var i = 0; i < 5; i++) Assert.False(OtpCodes.Verify(challenge, wrongCode, now));
        Assert.Equal(5, challenge.FailedAttempts);
        Assert.False(OtpCodes.Verify(challenge, code, now));
    }

    [Fact]
    public void ChallengePurposeIsBoundIntoTheHash()
    {
        var now = DateTime.UtcNow;
        var (challenge, code) = OtpCodes.Create(null, "user@example.com", "Register", now);
        challenge.Purpose = "PasswordReset";

        Assert.False(OtpCodes.Verify(challenge, code, now));
        Assert.Equal(1, challenge.FailedAttempts);
    }
}
