using AvoraAI.API.Services;

namespace AvoraAI.API.Tests;

public class PasswordPolicyTests
{
    [Theory]
    [InlineData("AvoraSecure1!", true)]
    [InlineData("avoraSecure1!", false)]
    [InlineData("AvoraSecure!!", false)]
    [InlineData("AvoraSecure12", false)]
    [InlineData("A1!short", false)]
    [InlineData("AvoraSecure1 ", false)]
    public void EnforcesUppercaseStartDigitSymbolAndLength(string password, bool expected)
    {
        Assert.Equal(expected, PasswordPolicy.IsValid(password));
    }
}
