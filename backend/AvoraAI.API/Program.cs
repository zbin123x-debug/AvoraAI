using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using AvoraAI.API.Data;
using AvoraAI.API.Models;
using AvoraAI.API.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);
builder.Services.Configure<SmtpOptions>(builder.Configuration.GetSection("Smtp"));
builder.Services.AddScoped<IOtpSender, EmailOtpSender>();
builder.Services.AddScoped<IPasswordHasher<AppUser>, PasswordHasher<AppUser>>();
builder.Services.AddSingleton<HybridMealOptimizer>();
builder.Services.AddDbContext<AppDbContext>(o => o.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));
var jwtKey = builder.Configuration["Jwt:SigningKey"];
if (!string.IsNullOrWhiteSpace(jwtKey))
{
    var key = new SymmetricSecurityKey(Convert.FromBase64String(jwtKey));
    builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o =>
    {
        o.TokenValidationParameters = new TokenValidationParameters { ValidateIssuer = true, ValidIssuer = "AvoraAI", ValidateAudience = true, ValidAudience = "AvoraAI.Mobile", ValidateIssuerSigningKey = true, IssuerSigningKey = key, ValidateLifetime = true, ClockSkew = TimeSpan.FromSeconds(20), NameClaimType = ClaimTypes.NameIdentifier, RoleClaimType = ClaimTypes.Role };
        o.Events = new JwtBearerEvents
        {
            OnTokenValidated = async context =>
            {
                var id = context.Principal?.FindFirstValue(ClaimTypes.NameIdentifier);
                if (!Guid.TryParse(id, out var userId)) { context.Fail("Token người dùng không hợp lệ."); return; }
                using var scope = context.HttpContext.RequestServices.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                var user = await db.Users.AsNoTracking().Where(x => x.Id == userId).Select(x => new { x.IsActive, x.IsDeleted, x.TokenVersion, x.MustChangePassword }).FirstOrDefaultAsync(context.HttpContext.RequestAborted);
                var tokenVersion = int.TryParse(context.Principal?.FindFirstValue("ver"), out var version) ? version : -1;
                if (user is null || !user.IsActive || user.IsDeleted || user.TokenVersion != tokenVersion) context.Fail("Phiên đã bị thu hồi hoặc tài khoản không còn hoạt động.");
                else if (user.MustChangePassword && !(HttpMethods.IsPost(context.HttpContext.Request.Method) && (string.Equals(context.HttpContext.Request.Path.Value, "/api/me/security/password", StringComparison.OrdinalIgnoreCase) || string.Equals(context.HttpContext.Request.Path.Value, "/api/me/security/password/request", StringComparison.OrdinalIgnoreCase)))) context.Fail("Cần đổi mật khẩu trước khi tiếp tục.");
            }
        };
    });
}
else builder.Services.AddAuthentication();
builder.Services.AddAuthorization();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddCors(o => o.AddDefaultPolicy(p => p.AllowAnyHeader().AllowAnyMethod().SetIsOriginAllowed(_ => true)));

var app = builder.Build();
app.UseSwagger(); app.UseSwaggerUI(); app.UseCors(); app.UseAuthentication(); app.UseAuthorization();

app.MapGet("/api/health", async (AppDbContext db, IConfiguration config) =>
{
    try { var canConnect = await db.Database.CanConnectAsync(); return Results.Ok(new { status = "ok", database = canConnect ? "connected" : "unavailable", smtpPasswordConfigured = !string.IsNullOrWhiteSpace(config["Smtp:Password"]) }); }
    catch { return Results.Ok(new { status = "ok", database = "unavailable", smtpPasswordConfigured = !string.IsNullOrWhiteSpace(config["Smtp:Password"]) }); }
});
app.MapPost("/api/setup/bootstrap-admin", async (BootstrapAdminRequest r, AppDbContext db, IPasswordHasher<AppUser> hasher, IConfiguration config, CancellationToken ct) =>
{
    var expected = config["AdminBootstrap:SetupKey"];
    if (string.IsNullOrWhiteSpace(expected)) return Results.NotFound();
    var expectedBytes = Encoding.UTF8.GetBytes(expected); var suppliedBytes = Encoding.UTF8.GetBytes(r.SetupKey ?? "");
    if (expectedBytes.Length != suppliedBytes.Length || !CryptographicOperations.FixedTimeEquals(expectedBytes, suppliedBytes)) return Results.Unauthorized();
    if (await db.Users.AnyAsync(x => x.Role == "Admin", ct)) return Results.Conflict(new { message = "Admin đã được khởi tạo." });
    var email = NormalizeEmail(r.Email); if (email is null) return Results.BadRequest(new { message = "Email quản trị không hợp lệ." });
    if (!PasswordPolicy.IsValid(r.Password)) return Results.BadRequest(new { message = PasswordPolicy.Requirement });
    if (await db.Users.AnyAsync(x => x.Email == email, ct)) return Results.Conflict(new { message = "Email đã thuộc tài khoản khác." });
    var user = new AppUser { Email = email, Role = "Admin", IsActive = true, IsEmailVerified = true };
    user.PasswordHash = hasher.HashPassword(user, r.Password); db.Users.Add(user); db.Profiles.Add(new UserProfile { UserId = user.Id });
    await db.SaveChangesAsync(ct); return Results.Created("/api/admin/users", new { user.Id, user.Email, user.Role });
});
app.MapPost("/api/setup/bootstrap-admins", async (BootstrapAdminsRequest r, AppDbContext db, IPasswordHasher<AppUser> hasher, IConfiguration config, CancellationToken ct) =>
{
    var expectedBytes = Encoding.UTF8.GetBytes(config["AdminBootstrap:SetupKey"] ?? "");
    var suppliedBytes = Encoding.UTF8.GetBytes(r.SetupKey ?? "");
    if (expectedBytes.Length == 0 || expectedBytes.Length != suppliedBytes.Length || !CryptographicOperations.FixedTimeEquals(expectedBytes, suppliedBytes)) return Results.Unauthorized();
    if (await db.Users.AnyAsync(x => x.Role == "Admin", ct)) return Results.Conflict(new { message = "Admin đã được khởi tạo." });
    if (r.Admins is null || r.Admins.Count is < 1 or > 10) return Results.BadRequest(new { message = "Cần từ 1 đến 10 tài khoản Admin." });
    var users = new List<AppUser>(); var usernames = new HashSet<string>(StringComparer.Ordinal);
    foreach (var item in r.Admins)
    {
        var username = NormalizeUsername(item.Username);
        if (username is null || !PasswordPolicy.IsValid(item.Password) || !usernames.Add(username))
            return Results.BadRequest(new { message = "Tên đăng nhập phải gồm 3–32 chữ cái/số/gạch dưới; mật khẩu phải đạt quy tắc bảo mật; tên đăng nhập không được trùng." });
        users.Add(new AppUser { Username = username, Role = "Admin", IsActive = true, IsEmailVerified = false });
    }
    for (var i = 0; i < users.Count; i++)
    {
        users[i].PasswordHash = hasher.HashPassword(users[i], r.Admins[i].Password);
        db.Users.Add(users[i]); db.Profiles.Add(new UserProfile { UserId = users[i].Id });
    }
    await db.SaveChangesAsync(ct);
    return Results.Created("/api/admin/users", new { admins = users.Select(x => new { x.Id, x.Username, x.Role }) });
});
app.MapPost("/api/setup/bootstrap-superadmin", async (BootstrapSuperAdminRequest r, AppDbContext db, IPasswordHasher<AppUser> hasher, IConfiguration config, CancellationToken ct) =>
{
    var expectedBytes = Encoding.UTF8.GetBytes(config["SuperAdminBootstrap:SetupKey"] ?? "");
    var suppliedBytes = Encoding.UTF8.GetBytes(r.SetupKey ?? "");
    if (expectedBytes.Length == 0 || expectedBytes.Length != suppliedBytes.Length || !CryptographicOperations.FixedTimeEquals(expectedBytes, suppliedBytes)) return Results.Unauthorized();
    if (await db.Users.AnyAsync(x => x.Role == "SuperAdmin", ct)) return Results.Conflict(new { message = "SuperAdmin đã được khởi tạo; không tự đặt lại mật khẩu." });
    var email = NormalizeEmail(r.Email);
    if (email is null) return Results.BadRequest(new { message = "Email SuperAdmin không hợp lệ." });
    if (await db.Users.AnyAsync(x => x.Email == email && !x.IsDeleted, ct)) return Results.Conflict(new { message = "Email đã được sử dụng." });
    if (!PasswordPolicy.IsValid(r.Password)) return Results.BadRequest(new { message = PasswordPolicy.Requirement });
    var user = new AppUser { Email = email, Role = "SuperAdmin", IsActive = true, IsEmailVerified = true, MustChangePassword = true };
    user.PasswordHash = hasher.HashPassword(user, r.Password); db.Users.Add(user); db.Profiles.Add(new UserProfile { UserId = user.Id });
    await db.SaveChangesAsync(ct);
    return Results.Created("/api/superadmin/overview", new { user.Id, user.Email, user.Role, user.MustChangePassword });
});
var auth = app.MapGroup("/api/auth");
auth.MapPost("/register", async (RegisterRequest req, AppDbContext db, IPasswordHasher<AppUser> hasher, IOtpSender sender, CancellationToken ct) =>
{
    var email = NormalizeEmail(req.Email);
    if (email is null) return Results.ValidationProblem(new Dictionary<string, string[]> { ["email"] = ["Email không hợp lệ."] });
    if (!PasswordPolicy.IsValid(req.Password)) return Results.ValidationProblem(new Dictionary<string, string[]> { ["password"] = [PasswordPolicy.Requirement] });
    if (await db.Users.AnyAsync(x => x.Email == email, ct)) return Results.Conflict(new { message = "Email đã được sử dụng." });
    var u = new AppUser { Email = email, IsActive = false, IsEmailVerified = false };
    u.PasswordHash = hasher.HashPassword(u, req.Password);
    db.Users.Add(u); db.Profiles.Add(new UserProfile { UserId = u.Id });
    var (challenge, code) = OtpCodes.Create(null, email, "Register"); db.OtpChallenges.Add(challenge);
    await db.SaveChangesAsync(ct);
    try { await sender.SendAsync(email, "Register", code, ct); }
    catch (InvalidOperationException e)
    {
        db.OtpChallenges.Remove(challenge); db.Users.Remove(u); await db.SaveChangesAsync(ct);
        return Results.Problem(e.Message, statusCode: 503);
    }
    return Results.Accepted(value: new { message = "Đã gửi mã xác minh nếu cấu hình email hoạt động.", expiresInSeconds = 60 });
});

auth.MapPost("/register/resend", async (EmailRequest req, AppDbContext db, IOtpSender sender, CancellationToken ct) =>
{
    var email = NormalizeEmail(req.Email); if (email is null) return Results.BadRequest(new { message = "Email không hợp lệ." });
    var user = await db.Users.FirstOrDefaultAsync(x => x.Email == email && !x.IsEmailVerified, ct);
    if (user is null) return Results.Ok(new { message = "Nếu có yêu cầu đăng ký đang chờ, mã mới sẽ được gửi." });
    var now = DateTime.UtcNow;
    var previous = await db.OtpChallenges.Where(x => x.Destination == email && x.Purpose == "Register" && x.ConsumedAtUtc == null).OrderByDescending(x => x.CreatedAtUtc).FirstOrDefaultAsync(ct);
    if (previous is not null && previous.CreatedAtUtc.AddSeconds(60) > now)
        return Results.Problem($"Vui lòng đợi {(int)Math.Ceiling((previous.CreatedAtUtc.AddSeconds(60) - now).TotalSeconds)} giây rồi thử lại.", statusCode: 429);
    if (previous is not null) previous.ConsumedAtUtc = now;
    var (challenge, code) = OtpCodes.Create(user.Id, email, "Register", now); db.OtpChallenges.Add(challenge); await db.SaveChangesAsync(ct);
    try { await sender.SendAsync(email, "Register", code, ct); } catch (InvalidOperationException e) { return Results.Problem(e.Message, statusCode: 503); }
    return Results.Ok(new { message = "Đã gửi mã xác minh.", expiresInSeconds = 60 });
});

auth.MapPost("/verify-registration", async (VerifyOtpRequest req, AppDbContext db, CancellationToken ct) =>
{
    var email = NormalizeEmail(req.Email); if (email is null) return Results.BadRequest(new { message = "Email không hợp lệ." });
    var challenge = await db.OtpChallenges.Where(x => x.Destination == email && x.Purpose == "Register" && x.ConsumedAtUtc == null).OrderByDescending(x => x.CreatedAtUtc).FirstOrDefaultAsync(ct);
    if (!OtpCodes.Verify(challenge, req.Code)) { await db.SaveChangesAsync(ct); return Results.BadRequest(new { message = "Mã không đúng, đã hết hạn hoặc đã dùng." }); }
    var u = await db.Users.FirstOrDefaultAsync(x => x.Email == email, ct); if (u is null) return Results.BadRequest(new { message = "Không tìm thấy yêu cầu đăng ký." });
    if (challenge!.UserId is Guid challengeUserId && challengeUserId != u.Id) return Results.BadRequest(new { message = "Mã không thuộc tài khoản này." });
    challenge.ConsumedAtUtc = DateTime.UtcNow; u.IsEmailVerified = true; u.IsActive = true; await db.SaveChangesAsync(ct);
    return Results.Ok(new { message = "Tài khoản đã được xác minh. Bạn có thể đăng nhập." });
});

auth.MapPost("/login", async (LoginRequest req, AppDbContext db, IPasswordHasher<AppUser> hasher, IConfiguration config, CancellationToken ct) =>
{
    var email = NormalizeEmail(req.Email); var phone = NormalizePhone(req.Email);
    var u = await db.Users.Include(x => x.Profile).FirstOrDefaultAsync(x => !x.IsDeleted && ((email != null && x.Email == email) || (phone != null && x.Phone == phone)), ct);
    var emailLogin = u is not null && email != null && u.Email == email && (u.Role == "Admin" || u.Role == "SuperAdmin" || u.IsEmailVerified);
    var phoneLogin = u is not null && u.Role == "User" && phone != null && u.Phone == phone && u.IsPhoneVerified;
    var contactLogin = emailLogin || phoneLogin;
    if (u is null || !u.IsActive || u.IsDeleted || !contactLogin || hasher.VerifyHashedPassword(u, u.PasswordHash, req.Password) == PasswordVerificationResult.Failed)
        return Results.Unauthorized();
    var signingKey = config["Jwt:SigningKey"]; if (string.IsNullOrWhiteSpace(signingKey)) return Results.Problem("Backend thiếu khóa ký JWT trong User Secrets.", statusCode: 503);
    var refresh = Convert.ToBase64String(RandomNumberGenerator.GetBytes(48));
    var session = new RefreshSession { UserId = u.Id, TokenHash = Hash(refresh), ExpiresAtUtc = DateTime.UtcNow.AddDays(30) };
    db.RefreshSessions.Add(session); await db.SaveChangesAsync(ct);
    return Results.Ok(new { accessToken = MakeAccessToken(u, signingKey), refreshToken = refresh, expiresInSeconds = 900, role = u.Role, mustChangePassword = u.MustChangePassword, profileComplete = u.Profile?.IsComplete ?? false, onboardingStep = u.Profile?.OnboardingStep ?? 1 });
});

auth.MapPost("/refresh", async (RefreshRequest req, AppDbContext db, IConfiguration config, CancellationToken ct) =>
{
    var hash = Hash(req.RefreshToken); var old = await db.RefreshSessions.Include(x => x.User).ThenInclude(x => x.Profile).FirstOrDefaultAsync(x => x.TokenHash == hash, ct);
    if (old is null || old.RevokedAtUtc != null || old.ExpiresAtUtc <= DateTime.UtcNow || !old.User.IsActive || old.User.IsDeleted || old.User.MustChangePassword) return Results.Unauthorized();
    old.RevokedAtUtc = DateTime.UtcNow; var next = Convert.ToBase64String(RandomNumberGenerator.GetBytes(48));
    db.RefreshSessions.Add(new RefreshSession { UserId = old.UserId, TokenHash = Hash(next), ExpiresAtUtc = DateTime.UtcNow.AddDays(30) }); await db.SaveChangesAsync(ct);
    var key = config["Jwt:SigningKey"]; if (string.IsNullOrWhiteSpace(key)) return Results.Problem("Backend thiếu khóa ký JWT.", statusCode: 503);
    return Results.Ok(new { accessToken = MakeAccessToken(old.User, key), refreshToken = next, expiresInSeconds = 900, role = old.User.Role, mustChangePassword = old.User.MustChangePassword, profileComplete = old.User.Profile?.IsComplete ?? false, onboardingStep = old.User.Profile?.OnboardingStep ?? 1 });
});

auth.MapPost("/logout", async (RefreshRequest req, AppDbContext db, CancellationToken ct) =>
{
    var hash = Hash(req.RefreshToken); var s = await db.RefreshSessions.FirstOrDefaultAsync(x => x.TokenHash == hash, ct);
    if (s is not null) { s.RevokedAtUtc = DateTime.UtcNow; await db.SaveChangesAsync(ct); }
    return Results.NoContent();
});

auth.MapPost("/forgot-password", async (ForgotPasswordRequest req, AppDbContext db, IOtpSender sender, CancellationToken ct) =>
{
    var email = NormalizeEmail(req.Email); if (email is null) return Results.BadRequest(new { message = "Email không hợp lệ." });
    var u = await db.Users.FirstOrDefaultAsync(x => x.Email == email && x.IsActive, ct);
    if (u is null) return Results.Ok(new { message = "Nếu email thuộc tài khoản đã xác minh, hướng dẫn sẽ được gửi." });
    var previous = await db.OtpChallenges.Where(x => x.Destination == email && x.Purpose == "PasswordReset" && x.ConsumedAtUtc == null).OrderByDescending(x => x.CreatedAtUtc).FirstOrDefaultAsync(ct);
    var now = DateTime.UtcNow;
    if (previous is not null && previous.CreatedAtUtc.AddSeconds(60) > now)
        return Results.Problem("Vui lòng đợi mã hiện tại hết hạn rồi thử gửi lại.", statusCode: 429);
    if (previous is not null) previous.ConsumedAtUtc = now;
    var (c, code) = OtpCodes.Create(u.Id, email, "PasswordReset", now); db.OtpChallenges.Add(c); await db.SaveChangesAsync(ct);
    try { await sender.SendAsync(email, "PasswordReset", code, ct); } catch (InvalidOperationException e) { return Results.Problem(e.Message, statusCode: 503); }
    return Results.Ok(new { message = "Đã gửi mã xác minh.", expiresInSeconds = 60 });
});

auth.MapPost("/reset-password", async (ResetPasswordRequest req, AppDbContext db, IPasswordHasher<AppUser> hasher, CancellationToken ct) =>
{
    var email = NormalizeEmail(req.Email); if (email is null) return Results.BadRequest(new { message = "Email không hợp lệ." });
    if (!PasswordPolicy.IsValid(req.NewPassword)) return Results.BadRequest(new { message = PasswordPolicy.Requirement });
    var c = await db.OtpChallenges.Where(x => x.Destination == email && x.Purpose == "PasswordReset" && x.ConsumedAtUtc == null).OrderByDescending(x => x.CreatedAtUtc).FirstOrDefaultAsync(ct);
    if (!OtpCodes.Verify(c, req.Code)) { await db.SaveChangesAsync(ct); return Results.BadRequest(new { message = "Mã không đúng, đã hết hạn hoặc đã dùng." }); }
    var u = await db.Users.FirstOrDefaultAsync(x => x.Email == email, ct); if (u is null) return Results.BadRequest(new { message = "Không tìm thấy tài khoản." });
    if (c!.UserId != u.Id) return Results.BadRequest(new { message = "Mã không thuộc tài khoản này." });
    u.PasswordHash = hasher.HashPassword(u, req.NewPassword); u.TokenVersion++; u.IsEmailVerified = true; c!.ConsumedAtUtc = DateTime.UtcNow;
    foreach (var s in await db.RefreshSessions.Where(x => x.UserId == u.Id && x.RevokedAtUtc == null).ToListAsync(ct)) s.RevokedAtUtc = DateTime.UtcNow;
    await db.SaveChangesAsync(ct); return Results.Ok(new { message = "Đã đổi mật khẩu. Hãy đăng nhập lại." });
});

var me = app.MapGroup("/api/me").RequireAuthorization();
me.MapGet("/profile", async (ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var id = UserId(p); var profile = await db.Profiles.AsNoTracking().FirstOrDefaultAsync(x => x.UserId == id, ct);
    return profile is null ? Results.NotFound() : Results.Ok(new
    {
        profile.UserId, profile.FullName, profile.BirthDate, profile.Gender,
        profile.HeightCm, profile.WeightKg, profile.Goal, profile.TargetWeightKg,
        profile.MealsPerDay, profile.Diet, profile.NoAllergies, profile.AllergiesJson,
        profile.ActivityLevel, profile.OnboardingStep, profile.IsComplete,
        profile.UpdatedAtUtc,
        avatarUrl = profile.AvatarPath is null ? null : $"/api/me/avatar/{id}?v={profile.UpdatedAtUtc.Ticks}"
    });
});
me.MapPut("/profile", async (ProfileRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var id = UserId(p); var x = await db.Profiles.FirstOrDefaultAsync(x => x.UserId == id, ct);
    if (x is null) { x = new UserProfile { UserId = id }; db.Profiles.Add(x); }
    if (r.MealsPerDay is not (3 or 4 or 5))
        return Results.BadRequest(new { message = "Số bữa ăn mỗi ngày chỉ có thể là 3, 4 hoặc 5." });
    if (r.HeightCm is < 50 or > 280 || r.WeightKg is < 15 or > 500 || r.Step is < 1 or > 3 || r.NoAllergies && r.Allergies.Count > 0) return Results.BadRequest(new { message = "Thông tin hồ sơ không hợp lệ hoặc dị ứng đang mâu thuẫn." });
    var before = ProfileSnapshot(x);
    var previousWeightKg = x.WeightKg;
    x.FullName = r.FullName?.Trim(); x.BirthDate = r.BirthDate; x.Gender = r.Gender; x.HeightCm = r.HeightCm; x.WeightKg = r.WeightKg;
    if (r.WeightKg is decimal reportedWeight &&
        (previousWeightKg != reportedWeight ||
         !await db.WeightHistoryEntries.AnyAsync(entry => entry.UserId == id, ct)))
    {
        var recordedOn = DateOnly.FromDateTime(DateTime.Now);
        var weightEntry = await db.WeightHistoryEntries.FirstOrDefaultAsync(
            entry => entry.UserId == id && entry.RecordedOn == recordedOn, ct);
        if (weightEntry is null)
            db.WeightHistoryEntries.Add(new WeightHistoryEntry
            {
                UserId = id, RecordedOn = recordedOn, WeightKg = reportedWeight,
            });
        else
            weightEntry.WeightKg = reportedWeight;
    }
    if (r.Goal is not null) { x.Goal = r.Goal; x.TargetWeightKg = r.TargetWeightKg; }
    x.WeightGainNote = r.WeightGainNote; x.WeightGainTendency = r.WeightGainTendency; x.MealsPerDay = r.MealsPerDay; x.Diet = r.Diet; x.NoAllergies = r.NoAllergies; x.AllergiesJson = System.Text.Json.JsonSerializer.Serialize(r.Allergies); x.ActivityLevel = r.ActivityLevel; x.OnboardingStep = Math.Clamp(r.Step, 1, 3);
    if (r.Step == 3 && (string.IsNullOrWhiteSpace(x.FullName) || x.BirthDate is null || x.HeightCm is null || x.WeightKg is null || x.MealsPerDay is null || string.IsNullOrWhiteSpace(x.Diet) || string.IsNullOrWhiteSpace(x.ActivityLevel))) return Results.BadRequest(new { message = "Hãy hoàn thành các trường bắt buộc trước khi lưu hồ sơ." });
    x.IsComplete = x.IsComplete || r.Step == 3; x.UpdatedAtUtc = DateTime.UtcNow;
    if (p.IsInRole("Admin") || p.IsInRole("SuperAdmin")) db.AdminActionLogs.Add(Audit(id, "UpdateOwnProfile", id, "", before, ProfileSnapshot(x)));
    var activeGoal = await db.UserGoals.Include(g => g.Meals).FirstOrDefaultAsync(g => g.UserId == id && g.IsActive, ct);
    if (activeGoal is not null && x.MealsPerDay is int updatedMealCount &&
        (activeGoal.MealsPerDay != updatedMealCount || activeGoal.Meals.Count != updatedMealCount))
    {
        var existingMeals = activeGoal.Meals.OrderBy(meal => meal.SortOrder).ToList();
        var retainedCount = Math.Min(existingMeals.Count, updatedMealCount);
        activeGoal.MealsPerDay = updatedMealCount;
        var ratios = DailyEnergyEstimator.MealAllocationRatios(updatedMealCount);
        for (var index = 0; index < retainedCount; index++)
        {
            existingMeals[index].MealName = MealName(index + 1, updatedMealCount);
            existingMeals[index].SortOrder = index + 1;
            existingMeals[index].AllocationRatio = ratios[index];
        }
        foreach (var removedMeal in existingMeals.Skip(retainedCount))
        {
            activeGoal.Meals.Remove(removedMeal);
            db.GoalMealAllocations.Remove(removedMeal);
        }
        for (var index = retainedCount; index < updatedMealCount; index++)
        {
            var newMeal = new GoalMealAllocation
            {
                UserGoalId = activeGoal.Id,
                MealName = MealName(index + 1, updatedMealCount),
                SortOrder = index + 1,
                AllocationRatio = ratios[index],
            };
            db.GoalMealAllocations.Add(newMeal);
            activeGoal.Meals.Add(newMeal);
        }
        DailyEnergyEstimator.RefreshMealTargets(x, activeGoal);
    }
    else if (activeGoal is not null) DailyEnergyEstimator.RefreshMealTargets(x, activeGoal);
    await db.SaveChangesAsync(ct);
    return Results.Ok(x);
});
me.MapGet("/weight-history", async (DateOnly? fromDate, DateOnly? toDate, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var id = UserId(p);
    var query = db.WeightHistoryEntries.AsNoTracking().Where(entry => entry.UserId == id);
    if (fromDate is not null) query = query.Where(entry => entry.RecordedOn >= fromDate.Value);
    if (toDate is not null) query = query.Where(entry => entry.RecordedOn <= toDate.Value);
    var entries = await query.OrderBy(entry => entry.RecordedOn)
        .Select(entry => new { entry.Id, entry.RecordedOn, entry.WeightKg })
        .ToListAsync(ct);
    return Results.Ok(entries);
});
me.MapPost("/weight-history", async (WeightHistoryRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var id = UserId(p);
    var today = DateOnly.FromDateTime(DateTime.Now);
    if (r.WeightKg is < 15 or > 500 || r.RecordedOn > today)
        return Results.BadRequest(new { message = "Cân nặng phải từ 15 đến 500 kg và ngày ghi không được ở tương lai." });
    var profile = await db.Profiles.FirstOrDefaultAsync(x => x.UserId == id, ct);
    if (profile is null) return Results.NotFound(new { message = "Không tìm thấy hồ sơ người dùng." });
    var entry = await db.WeightHistoryEntries.FirstOrDefaultAsync(
        x => x.UserId == id && x.RecordedOn == r.RecordedOn, ct);
    if (entry is null)
    {
        entry = new WeightHistoryEntry { UserId = id, RecordedOn = r.RecordedOn, WeightKg = r.WeightKg };
        db.WeightHistoryEntries.Add(entry);
    }
    else entry.WeightKg = r.WeightKg;
    var latest = await db.WeightHistoryEntries
        .Where(x => x.UserId == id)
        .OrderByDescending(x => x.RecordedOn)
        .FirstOrDefaultAsync(ct);
    profile.WeightKg = latest?.RecordedOn >= r.RecordedOn ? latest.WeightKg : r.WeightKg;
    profile.UpdatedAtUtc = DateTime.UtcNow;
    await db.SaveChangesAsync(ct);
    return Results.Ok(new { entry.Id, entry.RecordedOn, entry.WeightKg, currentProfileWeightKg = profile.WeightKg });
});
me.MapPut("/goal", async (GoalRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var id = UserId(p);
    if (r.DurationDays is < 30 or > 720)
        return Results.BadRequest(new { message = "Thời hạn mục tiêu phải từ 1 đến 24 tháng." });
    var profile = await db.Profiles.FirstOrDefaultAsync(x => x.UserId == id, ct);
    if (profile is null || profile.HeightCm is null || profile.WeightKg is null)
        return Results.Conflict(new { message = "Hãy bổ sung chiều cao và cân nặng trong hồ sơ trước." });
    var selectedMealsPerDay = r.MealsPerDay ?? profile.MealsPerDay;
    if (selectedMealsPerDay is null or < 3 or > 5)
        return Results.Conflict(new { message = "Chọn 3, 4 hoặc 5 bữa ăn mỗi ngày." });
    var goal = r.Goal?.Trim();
    if (goal is not ("Giữ cân" or "Giảm cân" or "Tăng cân"))
        return Results.BadRequest(new { message = "Hãy chọn giữ cân, giảm cân hoặc tăng cân." });
    if (goal == "Giữ cân") r = r with { TargetWeightKg = profile.WeightKg };
    else if (r.TargetWeightKg is null or <= 0 ||
        goal == "Giảm cân" && r.TargetWeightKg >= profile.WeightKg ||
        goal == "Tăng cân" && r.TargetWeightKg <= profile.WeightKg)
        return Results.BadRequest(new { message = goal == "Giảm cân"
            ? "Cân nặng mong muốn phải lớn hơn 0 và thấp hơn cân nặng hiện tại."
            : "Cân nặng mong muốn phải cao hơn cân nặng hiện tại." });
    var today = DateOnly.FromDateTime(DateTime.Now);
    var completedMealsToday = await db.ConsumedMealLogs.AsNoTracking()
        .Where(x => x.UserId == id && x.MealDate == today && !x.MealSuggestion.IsExtraMeal)
        .Select(x => x.MealName)
        .Distinct()
        .CountAsync(ct);
    var effectiveStartDate = completedMealsToday >= selectedMealsPerDay.Value
        ? today.AddDays(1)
        : today;
    await using var transaction = await db.Database.BeginTransactionAsync(ct);
    profile.Goal = goal;
    profile.TargetWeightKg = r.TargetWeightKg;
    profile.MealsPerDay = selectedMealsPerDay.Value;
    profile.UpdatedAtUtc = DateTime.UtcNow;
    var previousGoals = await db.UserGoals.Where(x => x.UserId == id && x.IsActive).ToListAsync(ct);
    foreach (var previous in previousGoals) previous.IsActive = false;
    var savedGoal = new UserGoal
    {
        UserId = id,
        Goal = goal!,
        TargetWeightKg = r.TargetWeightKg!.Value,
        MealsPerDay = selectedMealsPerDay.Value,
        EffectiveStartDate = effectiveStartDate,
        DurationDays = r.DurationDays,
    };
    db.UserGoals.Add(savedGoal);
    var meals = BuildMealAllocations(savedGoal);
    DailyEnergyEstimator.RefreshMealTargets(profile, savedGoal.Goal, meals);
    var calorieEstimate = DailyEnergyEstimator.Calculate(profile, savedGoal.Goal);
    db.GoalMealAllocations.AddRange(meals);
    await db.SaveChangesAsync(ct);
    await transaction.CommitAsync(ct);
    return Results.Ok(new
    {
        id = savedGoal.Id,
        profile.Goal,
        profile.TargetWeightKg,
        durationDays = savedGoal.DurationDays,
        effectiveStartDate = savedGoal.EffectiveStartDate,
        targetEndDate = savedGoal.EffectiveStartDate.AddDays(savedGoal.DurationDays - 1),
        appliesToday = savedGoal.EffectiveStartDate == today,
        completedMealsToday,
        profile.WeightKg,
        profile.HeightCm,
        profile.MealsPerDay,
        profile.Diet,
        profile.NoAllergies,
        profile.AllergiesJson,
        profile.UpdatedAtUtc,
        dailyCalorieTarget = calorieEstimate?.TargetKcal,
        maintenanceCalorieEstimate = calorieEstimate?.MaintenanceKcal,
        isAdultCalorieEstimate = calorieEstimate?.IsAdult,
        usesAverageSexEstimate = calorieEstimate?.UsesAverageSexEstimate,
        mealAllocations = meals.Select(x => new
        {
            x.Id, x.MealName, x.SortOrder, x.AllocationRatio,
            hasTargets = x.TargetsJson is not null,
            targets = x.TargetsJson is null ? (JsonElement?)null : JsonSerializer.Deserialize<JsonElement>(x.TargetsJson),
        }),
        targetStatus = meals.All(x => x.TargetsJson is not null) ? "Ready" : "NeedsNutritionTargets",
    });
});
me.MapGet("/goals/current", async (ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var id = UserId(p);
    var today = DateOnly.FromDateTime(DateTime.Now);
    var goal = await EffectiveGoals(db, id, today).FirstOrDefaultAsync(ct);
    if (goal is null) return Results.NotFound(new { message = "ChÆ°a cÃ³ má»¥c tiÃªu Ä‘ang hoáº¡t Ä‘á»™ng." });
    var pendingGoal = await db.UserGoals.AsNoTracking()
        .Where(x => x.UserId == id && x.IsActive && x.EffectiveStartDate > today)
        .OrderBy(x => x.EffectiveStartDate).ThenByDescending(x => x.CreatedAtUtc)
        .FirstOrDefaultAsync(ct);
    var profile = await db.Profiles.FirstOrDefaultAsync(x => x.UserId == id, ct);
    var targetsChanged = profile is not null && DailyEnergyEstimator.RefreshMealTargets(profile, goal);
    if (targetsChanged) await db.SaveChangesAsync(ct);
    var estimate = profile is null ? null : DailyEnergyEstimator.Calculate(profile, goal.Goal);
    return Results.Ok(new
    {
        goal.Id, goal.Goal, goal.TargetWeightKg, goal.MealsPerDay,
        goal.EffectiveStartDate, goal.DurationDays,
        targetEndDate = goal.EffectiveStartDate.AddDays(goal.DurationDays - 1),
        pendingGoal = pendingGoal is null ? null : new
        {
            pendingGoal.Id, pendingGoal.Goal, pendingGoal.TargetWeightKg,
            pendingGoal.EffectiveStartDate, pendingGoal.DurationDays,
            targetEndDate = pendingGoal.EffectiveStartDate.AddDays(pendingGoal.DurationDays - 1),
        },
        dailyCalorieTarget = estimate?.TargetKcal,
        maintenanceCalorieEstimate = estimate?.MaintenanceKcal,
        isAdultCalorieEstimate = estimate?.IsAdult,
        usesAverageSexEstimate = estimate?.UsesAverageSexEstimate,
        targetStatus = estimate is not null && goal.Meals.All(x => x.TargetsJson is not null) ? "Ready" : "NeedsNutritionTargets",
        mealAllocations = goal.Meals.OrderBy(x => x.SortOrder).Select(x => new
        {
            x.Id, x.MealName, x.SortOrder, x.AllocationRatio,
            targets = x.TargetsJson is null ? (JsonElement?)null : JsonSerializer.Deserialize<JsonElement>(x.TargetsJson),
        }),
    });
});
me.MapPost("/meals/generate", async (MealGenerationRequest r, ClaimsPrincipal p, AppDbContext db, HybridMealOptimizer optimizer, CancellationToken ct) =>
{
    var userId = UserId(p);
    if (r.SessionId == Guid.Empty || string.IsNullOrWhiteSpace(r.MealName))
        return Results.BadRequest(new { message = "Chá»n bá»¯a vÃ  mÃ£ phiÃªn gá»£i Ã½ há»£p lá»‡." });
    var goal = await EffectiveGoals(db, userId, r.MealDate).FirstOrDefaultAsync(ct);
    if (goal is null) return Results.Conflict(new { message = "HÃ£y táº¡o má»¥c tiÃªu trÆ°á»›c khi táº¡o mÃ³n AI." });
    var profile = await db.Profiles.AsNoTracking().FirstOrDefaultAsync(x => x.UserId == userId, ct);
    if (profile is not null && DailyEnergyEstimator.RefreshMealTargets(profile, goal))
        await db.SaveChangesAsync(ct);
    var allocation = goal.Meals.FirstOrDefault(x => x.MealName == r.MealName);
    if (allocation is null) return Results.BadRequest(new { message = "Bá»¯a Äƒn khÃ´ng thuá»™c má»¥c tiÃªu hiá»‡n táº¡i." });
    var expectedTargets = new HashSet<string>([
        "energy_kcal", "protein_g", "carbohydrate_g", "total_fat_g",
        "fiber_g", "total_sugars_g", "saturated_fat_g", "sodium_mg"
    ], StringComparer.Ordinal);
    var coreTargets = expectedTargets.Take(4).ToHashSet(StringComparer.Ordinal);
    Dictionary<string, JsonElement> targetFields;
    if (allocation.TargetsJson is null)
    {
        targetFields = [];
    }
    else
    {
        using var targetJson = JsonDocument.Parse(allocation.TargetsJson);
        targetFields = targetJson.RootElement.EnumerateObject()
            .ToDictionary(x => x.Name, x => x.Value.Clone());
    }
    if (targetFields.Count > 0 &&
        (!coreTargets.IsSubsetOf(targetFields.Keys) || targetFields.Keys.Any(key => !expectedTargets.Contains(key))))
        return Results.Conflict(new { message = "Meal targets must include energy, protein, carbohydrate, and fat; other nutrients are optional.", code = "IncompleteMealTargets" });

    var existing = await db.MealSuggestions.FirstOrDefaultAsync(x => x.UserId == userId && x.SessionId == r.SessionId, ct);
    if (existing is not null && (existing.UserGoalId != goal.Id || existing.MealDate != r.MealDate || existing.MealName != r.MealName))
        return Results.Conflict(new { message = "PhiÃªn gá»£i Ã½ Ä‘Ã£ thuá»™c má»¥c tiÃªu hoáº·c bá»¯a Äƒn khÃ¡c." });
    if (existing is not null && !r.ReplaceExisting)
    {
        if (await db.ConsumedMealLogs.AnyAsync(x => x.MealSuggestionId == existing.Id, ct))
            return Results.Conflict(new { message = "Bá»¯a Äƒn nÃ y Ä‘Ã£ Ä‘Æ°á»£c xÃ¡c nháº­n; khÃ´ng thá»ƒ Ä‘á»•i mÃ³n." });
        return Results.Ok(await MealSuggestionDtoAsync(db, existing, ct));
    }
    if (existing is not null && await db.ConsumedMealLogs.AnyAsync(x => x.MealSuggestionId == existing.Id, ct))
        return Results.Conflict(new { message = "Bá»¯a Äƒn Ä‘Ã£ Ä‘Æ°á»£c xÃ¡c nháº­n." });

    if (profile is null || string.IsNullOrWhiteSpace(profile.Diet))
        return Results.Conflict(new { message = "HÃ£y hoÃ n táº¥t cháº¿ Ä‘á»™ Äƒn trong há»“ sÆ¡ trÆ°á»›c." });
    var mealBudgetWasReduced = false;
    var dailyEstimate = DailyEnergyEstimator.Calculate(profile, goal.Goal);
    if (dailyEstimate is not null && targetFields.TryGetValue("energy_kcal", out var allocatedEnergyTarget))
    {
        var consumedOtherMeals = await db.ConsumedMealLogs.AsNoTracking()
            .Where(x => x.UserId == userId && x.MealDate == r.MealDate && x.MealName != r.MealName)
            .Select(x => new { x.MealName, x.MealSuggestion.EstimatedNutrientsJson })
            .ToListAsync(ct);
        var consumedMealNames = consumedOtherMeals.Select(x => x.MealName)
            .ToHashSet(StringComparer.Ordinal);
        var plannedOtherMeals = await db.MealSuggestions.AsNoTracking()
            .Where(x => x.UserId == userId && x.UserGoalId == goal.Id &&
                x.MealDate == r.MealDate && x.MealName != r.MealName)
            .OrderByDescending(x => x.UpdatedAtUtc)
            .Select(x => new { x.MealName, x.EstimatedNutrientsJson })
            .ToListAsync(ct);
        var extraCalorieIntake = await db.ExtraCalorieEntries.AsNoTracking()
            .Where(x => x.UserId == userId && x.MealDate == r.MealDate)
            .SumAsync(x => (decimal?)x.CaloriesKcal, ct) ?? 0m;
        var reservedKcal = extraCalorieIntake
            + consumedOtherMeals.Sum(x => ReadEstimatedEnergyKcal(x.EstimatedNutrientsJson) ?? 0m)
            + plannedOtherMeals
                .Where(x => !consumedMealNames.Contains(x.MealName))
                .GroupBy(x => x.MealName, StringComparer.Ordinal)
                .Select(x => x.First())
                .Sum(x => ReadEstimatedEnergyKcal(x.EstimatedNutrientsJson) ?? 0m);
        var remainingDailyKcal = dailyEstimate.TargetKcal - reservedKcal;
        if (remainingDailyKcal <= 0)
            return Results.Conflict(new { message = "Các bữa đã ghi nhận hoặc lên kế hoạch đã dùng hết mục tiêu calo hôm nay. Hãy giảm khẩu phần hoặc hủy một bữa chưa ăn trước khi tạo thêm món." });

        var allocatedKcal = dailyEstimate.TargetKcal * allocation.AllocationRatio;
        var configuredMaximum = ReadJsonDecimal(allocatedEnergyTarget, "hardMaximum")
            ?? ReadJsonDecimal(allocatedEnergyTarget, "maximum")
            ?? allocatedKcal;
        allocatedKcal = Math.Min(allocatedKcal, configuredMaximum);
        var mealMaximum = Math.Min(allocatedKcal, remainingDailyKcal);
        mealBudgetWasReduced = mealMaximum < allocatedKcal;
        targetFields["energy_kcal"] = JsonSerializer.SerializeToElement(new
        {
            minimum = Math.Min(ReadJsonDecimal(allocatedEnergyTarget, "minimum") ?? mealMaximum, mealMaximum),
            maximum = Math.Min(ReadJsonDecimal(allocatedEnergyTarget, "maximum") ?? mealMaximum, mealMaximum),
            hardMinimum = Math.Min(ReadJsonDecimal(allocatedEnergyTarget, "hardMinimum") ?? mealMaximum, mealMaximum),
            hardMaximum = mealMaximum,
            weight = ReadJsonDecimal(allocatedEnergyTarget, "weight") ?? 100m,
        });
    }
    var allergyIds = profile.NoAllergies
        ? Array.Empty<string>()
        : (JsonSerializer.Deserialize<List<string>>(profile.AllergiesJson) ?? []).Select(NormalizePolicyToken).Where(x => x.Length > 0).ToArray();
    if (!profile.NoAllergies && allergyIds.Length == 0)
        return Results.Conflict(new { message = "HÃ£y xÃ¡c nháº­n khÃ´ng cÃ³ dá»‹ á»©ng hoáº·c bá»• sung danh sÃ¡ch dá»‹ á»©ng." });
    var dietTag = NormalizePolicyToken(profile.Diet);
    var requiredDietTags = dietTag is "khong" or "khonghanche" or "binhthuong" or "anbinhthuong" or "omnivore"
        ? Array.Empty<string>()
        : new[] { dietTag };

    var approvedFoods = await db.Foods.AsNoTracking()
        .Where(x => !x.IsDeleted && x.FoodGroupId != null)
        .Include(x => x.Nutrition)
        .ToListAsync(ct);
    approvedFoods = approvedFoods.Where(HasCoreNutrition).ToList();
    var cookedRice = approvedFoods.FirstOrDefault(x => x.FoodState == "Cooked" &&
        NormalizePolicyToken(x.Name).StartsWith("comtrangchin", StringComparison.Ordinal));
    var fridgeItems = await db.FridgeItems.AsNoTracking()
        .Where(x => x.UserId == userId)
        .Select(x => new { x.FoodId, x.Name })
        .ToListAsync(ct);
    var customPantryNames = fridgeItems
        .Where(x => x.FoodId is null)
        .Select(x => NormalizePolicyToken(x.Name))
        .Where(x => x.Length > 0)
        .ToHashSet(StringComparer.Ordinal);
    var pantryIds = fridgeItems.Where(x => x.FoodId is not null)
        .Select(x => x.FoodId!.Value.ToString())
        .Concat(approvedFoods
            .Where(x => customPantryNames.Contains(NormalizePolicyToken(x.Name)))
            .Select(x => x.Id.ToString()))
        .Distinct(StringComparer.OrdinalIgnoreCase)
        .ToArray();
    var favorites = await db.Favorites.AsNoTracking().Where(x => x.UserId == userId)
        .Select(x => x.DishId.ToString()).ToListAsync(ct);
    var recent = await db.ConsumedMealLogs.AsNoTracking()
        .Where(x => x.UserId == userId && x.MealDate >= r.MealDate.AddDays(-7))
        .Select(x => x.DishId.ToString()).Distinct().ToListAsync(ct);
    var excluded = existing is null ? new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        : (JsonSerializer.Deserialize<List<string>>(existing.ExcludedDishIdsJson) ?? []).ToHashSet(StringComparer.OrdinalIgnoreCase);
    if (existing is not null)
    {
        excluded.Add(existing.DishId.ToString());
        if (r.ExcludeDishIds is not null) excluded.UnionWith(r.ExcludeDishIds.Select(x => x.ToString()));
    }

    var published = await db.Dishes.AsNoTracking()
        .Where(x => !x.IsDeleted && x.Status == "Published")
        .Include(x => x.Ingredients).ThenInclude(x => x.Food)
        .ToListAsync(ct);
    var foodsPayload = approvedFoods.Select(x => new
    {
        foodId = x.Id.ToString(), groupId = x.FoodGroupId?.ToString(), name = x.Name,
        approvedForAi = true,
        allergenIds = cookedRice?.Id == x.Id ? Array.Empty<string>() : ParseJsonIds(x.AllergenIdsJson),
        verifiedPer100g = new Dictionary<string, decimal?>
        {
            ["energy_kcal"] = x.Nutrition?.EnergyKcal, ["protein_g"] = x.Nutrition?.ProteinG,
            ["carbohydrate_g"] = x.Nutrition?.CarbohydrateG, ["total_fat_g"] = x.Nutrition?.FatG,
            ["fiber_g"] = x.Nutrition?.FiberG, ["total_sugars_g"] = x.Nutrition?.SugarG,
            ["saturated_fat_g"] = x.Nutrition?.SaturatedFatG, ["sodium_mg"] = x.Nutrition?.SodiumMg,
        },
    }).ToArray();
    var recipesPayload = published.Select(x =>
    {
        var ingredients = x.Ingredients.OrderBy(i => i.SortOrder).Select(i =>
        {
            var standardG = ParseGrams(i.AmountInstruction);
            return new
            {
                foodId = i.FoodId?.ToString(),
                standardG,
                minG = standardG is null ? (decimal?)null : standardG.Value * 0.6m,
                maxG = standardG is null ? (decimal?)null : standardG.Value * 3m,
            };
        }).ToList();
        var includesRice = cookedRice is not null && !HasStarchStaple(x);
        if (includesRice)
            ingredients.Add(new { foodId = (string?)cookedRice!.Id.ToString(), standardG = (decimal?)150m, minG = (decimal?)100m, maxG = (decimal?)350m });
        return new
        {
            recipeId = x.Id.ToString(), name = x.Name, cookingNotes = x.CookingNotes ?? "",
            approvedForAi = true, dietTags = ParseJsonIds(x.DietTagsJson),
            mealTags = Array.Empty<string>(), allergenIds = ParseJsonIds(x.AllergenIdsJson),
            ingredients,
        };
    }).ToArray();
    var result = await optimizer.RecommendAsync(new
    {
        foods = foodsPayload, recipes = recipesPayload, targets = targetFields,
        meal = r.MealName, pantryFoodIds = pantryIds, allergyIds,
        requiredDietTags, avoidFoodIds = Array.Empty<string>(),
        excludeRecipeIds = excluded.ToArray(), favoriteRecipeIds = favorites,
        recentRecipeIds = recent, dishCount = 1, seed = RandomNumberGenerator.GetInt32(int.MaxValue),
    }, ct);
    var status = result.TryGetProperty("status", out var statusValue) ? statusValue.GetString() : null;
    var suggested = result.TryGetProperty("dishes", out var dishList) && dishList.ValueKind == JsonValueKind.Array
        ? dishList.EnumerateArray().FirstOrDefault() : default;
    if (mealBudgetWasReduced && status == "NO_FEASIBLE_RESULT_WITHIN_BUDGET")
        return Results.Conflict(new { message = "Không tìm được món phù hợp với lượng calo còn lại hôm nay. Hãy giảm khẩu phần ở bữa khác hoặc chọn món nhẹ hơn." });
    if (status != "OK" || suggested.ValueKind != JsonValueKind.Object)
        return Results.Conflict(new { message = r.ReplaceExisting ? "ChÆ°a cÃ³ mÃ³n khÃ¡c phÃ¹ há»£p cho bá»¯a nÃ y." : "ChÆ°a cÃ³ mÃ³n phÃ¹ há»£p cho bá»¯a nÃ y." });
    if (!Guid.TryParse(suggested.GetProperty("recipeId").GetString(), out var dishId))
        return Results.Problem("Bá»™ tá»‘i Æ°u tráº£ vá» mÃ£ mÃ³n khÃ´ng há»£p lá»‡.");
    var portionJson = suggested.GetProperty("ingredients").GetRawText();
    var estimateJson = result.TryGetProperty("estimatedNutrients", out var estimated) && estimated.ValueKind == JsonValueKind.Object
        ? estimated.GetRawText() : "{}";
    if (existing is null)
    {
        existing = new MealSuggestion
        {
            UserId = userId, UserGoalId = goal.Id, SessionId = r.SessionId,
            MealDate = r.MealDate, MealName = r.MealName, DishId = dishId,
            PersonalizedIngredientsJson = portionJson, EstimatedNutrientsJson = estimateJson,
            ExcludedDishIdsJson = "[]",
        };
        db.MealSuggestions.Add(existing);
    }
    else
    {
        excluded.Add(existing.DishId.ToString());
        existing.DishId = dishId;
        existing.PersonalizedIngredientsJson = portionJson;
        existing.EstimatedNutrientsJson = estimateJson;
        existing.ExcludedDishIdsJson = JsonSerializer.Serialize(excluded);
        existing.UpdatedAtUtc = DateTime.UtcNow;
    }
    await db.SaveChangesAsync(ct);
    return Results.Ok(await MealSuggestionDtoAsync(db, existing, ct));
});
me.MapGet("/meals/suggestion", async (DateOnly date, string mealName, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var userId = UserId(p);
    var goal = await EffectiveGoals(db, userId, date).Select(x => new { x.Id }).FirstOrDefaultAsync(ct);
    if (goal is null) return Results.NotFound();
    var suggestion = await db.MealSuggestions.AsNoTracking()
        .Where(x => x.UserId == userId && x.UserGoalId == goal.Id && x.MealDate == date && x.MealName == mealName)
        .OrderByDescending(x => x.UpdatedAtUtc)
        .FirstOrDefaultAsync(ct);
    return suggestion is null ? Results.NotFound() : Results.Ok(await MealSuggestionDtoAsync(db, suggestion, ct));
});
me.MapPut("/meals/{suggestionId:guid}/portions", async (Guid suggestionId, UpdateMealPortionsRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var userId = UserId(p);
    var suggestion = await db.MealSuggestions.FirstOrDefaultAsync(x => x.Id == suggestionId && x.UserId == userId, ct);
    if (suggestion is null) return Results.NotFound();
    if (await db.ConsumedMealLogs.AnyAsync(x => x.MealSuggestionId == suggestionId, ct))
        return Results.Conflict(new { message = "Bữa ăn đã được lưu; không thể sửa khẩu phần." });
    if (r.Ingredients is null || r.Ingredients.Count is < 1 or > 50 || r.Ingredients.Any(x => x.FoodId == Guid.Empty || x.Grams <= 0 || x.Grams > 5000m))
        return Results.BadRequest(new { message = "Khẩu phần phải có từ 1 đến 50 nguyên liệu, mỗi lượng từ 0 đến 5000 g." });

    var ids = r.Ingredients.Select(x => x.FoodId).Distinct().ToArray();
    var foods = await db.Foods.AsNoTracking().Include(x => x.Nutrition)
        .Where(x => ids.Contains(x.Id) && !x.IsDeleted && x.FoodGroupId != null)
        .ToListAsync(ct);
    if (foods.Count != ids.Length || foods.Any(x => !HasCoreNutrition(x)))
        return Results.BadRequest(new { message = "Có nguyên liệu không tồn tại hoặc thiếu dữ liệu dinh dưỡng cơ bản." });

    var byId = foods.ToDictionary(x => x.Id);
    var fridgeItems = await db.FridgeItems.AsNoTracking()
        .Where(x => x.UserId == userId)
        .Select(x => new { x.FoodId, x.Name })
        .ToListAsync(ct);
    var customPantryNames = fridgeItems
        .Where(x => x.FoodId is null)
        .Select(x => NormalizePolicyToken(x.Name))
        .Where(x => x.Length > 0)
        .ToHashSet(StringComparer.Ordinal);
    var pantryIds = fridgeItems.Where(x => x.FoodId is not null)
        .Select(x => x.FoodId!.Value)
        .Concat(foods
            .Where(x => customPantryNames.Contains(NormalizePolicyToken(x.Name)))
            .Select(x => x.Id))
        .ToHashSet();
    var portions = r.Ingredients.Select(line =>
    {
        var food = byId[line.FoodId];
        return new
        {
            foodId = food.Id.ToString(), name = food.Name, grams = line.Grams,
            inPantry = pantryIds.Contains(food.Id),
        };
    }).ToArray();
    decimal? Sum(Func<FoodNutrition, decimal?> select)
    {
        decimal total = 0;
        foreach (var line in r.Ingredients)
        {
            var value = select(byId[line.FoodId].Nutrition!);
            if (value is null) return null;
            total += value.Value * line.Grams / 100m;
        }
        return Math.Round(total, 2);
    }
    var estimate = new Dictionary<string, decimal?>
    {
        ["energy_kcal"] = Sum(x => x.EnergyKcal), ["protein_g"] = Sum(x => x.ProteinG),
        ["carbohydrate_g"] = Sum(x => x.CarbohydrateG), ["total_fat_g"] = Sum(x => x.FatG),
        ["fiber_g"] = Sum(x => x.FiberG), ["total_sugars_g"] = Sum(x => x.SugarG),
        ["saturated_fat_g"] = Sum(x => x.SaturatedFatG), ["sodium_mg"] = Sum(x => x.SodiumMg),
    };
    var profile = await db.Profiles.AsNoTracking().FirstOrDefaultAsync(x => x.UserId == userId, ct);
    var goal = await db.UserGoals.AsNoTracking()
        .FirstOrDefaultAsync(x => x.Id == suggestion.UserGoalId && x.UserId == userId, ct);
    var dailyEstimate = profile is null || goal is null ? null : DailyEnergyEstimator.Calculate(profile, goal.Goal);
    if (dailyEstimate is not null && estimate["energy_kcal"] is decimal proposedKcal)
    {
        if (goal is not null && suggestion.MealName == "Tối" && goal.MealsPerDay is 4 or 5)
        {
            var dinnerRatio = DailyEnergyEstimator.MealAllocationRatios(goal.MealsPerDay)[^1];
            var dinnerMaximum = dailyEstimate.TargetKcal * dinnerRatio;
            if (proposedKcal > dinnerMaximum)
                return Results.Conflict(new { message = $"Bữa tối được giới hạn khoảng {Math.Round(dinnerMaximum)} kcal với kế hoạch {goal.MealsPerDay} bữa/ngày. Hãy giảm khẩu phần." });
        }
        var consumedOtherMeals = await db.ConsumedMealLogs.AsNoTracking()
            .Where(x => x.UserId == userId && x.MealDate == suggestion.MealDate && x.MealName != suggestion.MealName)
            .Select(x => new { x.MealName, x.MealSuggestion.EstimatedNutrientsJson })
            .ToListAsync(ct);
        var consumedMealNames = consumedOtherMeals.Select(x => x.MealName)
            .ToHashSet(StringComparer.Ordinal);
        var plannedOtherMeals = await db.MealSuggestions.AsNoTracking()
            .Where(x => x.UserId == userId && x.UserGoalId == suggestion.UserGoalId &&
                x.MealDate == suggestion.MealDate && x.MealName != suggestion.MealName)
            .OrderByDescending(x => x.UpdatedAtUtc)
            .Select(x => new { x.MealName, x.EstimatedNutrientsJson })
            .ToListAsync(ct);
        var extraCalorieIntake = await db.ExtraCalorieEntries.AsNoTracking()
            .Where(x => x.UserId == userId && x.MealDate == suggestion.MealDate)
            .SumAsync(x => (decimal?)x.CaloriesKcal, ct) ?? 0m;
        var reservedKcal = extraCalorieIntake
            + consumedOtherMeals.Sum(x => ReadEstimatedEnergyKcal(x.EstimatedNutrientsJson) ?? 0m)
            + plannedOtherMeals
                .Where(x => !consumedMealNames.Contains(x.MealName))
                .GroupBy(x => x.MealName, StringComparer.Ordinal)
                .Select(x => x.First())
                .Sum(x => ReadEstimatedEnergyKcal(x.EstimatedNutrientsJson) ?? 0m);
        if (reservedKcal + proposedKcal > dailyEstimate.TargetKcal)
            return Results.Conflict(new { message = $"Khẩu phần này sẽ vượt mục tiêu calo hôm nay khoảng {Math.Ceiling(reservedKcal + proposedKcal - dailyEstimate.TargetKcal)} kcal. Hãy giảm lượng nguyên liệu hoặc điều chỉnh một bữa chưa ăn khác." });
    }
    suggestion.PersonalizedIngredientsJson = JsonSerializer.Serialize(portions);
    suggestion.EstimatedNutrientsJson = JsonSerializer.Serialize(estimate);
    suggestion.UpdatedAtUtc = DateTime.UtcNow;
    await db.SaveChangesAsync(ct);
    return Results.Ok(await MealSuggestionDtoAsync(db, suggestion, ct));
});
me.MapPost("/meals/{suggestionId:guid}/confirm", async (Guid suggestionId, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var userId = UserId(p);
    var suggestion = await db.MealSuggestions.FirstOrDefaultAsync(x => x.Id == suggestionId && x.UserId == userId, ct);
    if (suggestion is null) return Results.NotFound();
    var saved = await db.ConsumedMealLogs.FirstOrDefaultAsync(x => x.MealSuggestionId == suggestionId && x.UserId == userId, ct);
    if (saved is null)
    {
        saved = new ConsumedMealLog
        {
            UserId = userId, MealSuggestionId = suggestionId, DishId = suggestion.DishId,
            MealDate = suggestion.MealDate, MealName = suggestion.MealName,
            ConsumedIngredientsJson = suggestion.PersonalizedIngredientsJson,
        };
        db.ConsumedMealLogs.Add(saved);
        await db.SaveChangesAsync(ct);
    }
    return Results.Ok(new { saved.Id, saved.MealDate, saved.MealName, saved.DishId, saved.ConfirmedAtUtc });
});
me.MapDelete("/meals/{suggestionId:guid}/confirm", async (Guid suggestionId, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var userId = UserId(p);
    var calorieEntry = await db.ExtraCalorieEntries.FirstOrDefaultAsync(x => x.Id == suggestionId && x.UserId == userId, ct);
    if (calorieEntry is not null)
    {
        db.ExtraCalorieEntries.Remove(calorieEntry);
        await db.SaveChangesAsync(ct);
        return Results.Ok(new { isConfirmed = false });
    }
    var suggestionExists = await db.MealSuggestions.AnyAsync(x => x.Id == suggestionId && x.UserId == userId, ct);
    if (!suggestionExists) return Results.NotFound();
    var saved = await db.ConsumedMealLogs.FirstOrDefaultAsync(x => x.MealSuggestionId == suggestionId && x.UserId == userId, ct);
    if (saved is not null)
    {
        db.ConsumedMealLogs.Remove(saved);
        await db.SaveChangesAsync(ct);
    }
    return Results.Ok(new { isConfirmed = false });
});
me.MapPost("/extra-meals", async (ExtraMealRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var userId = UserId(p);
    if (r.CaloriesKcal is < 1 or > 10000)
        return Results.BadRequest(new { message = "Nhập lượng calo từ 1 đến 10000 kcal." });
    var entry = new ExtraCalorieEntry
    {
        UserId = userId,
        MealDate = DateOnly.FromDateTime(DateTime.Now),
        CaloriesKcal = r.CaloriesKcal,
    };
    db.ExtraCalorieEntries.Add(entry);
    await db.SaveChangesAsync(ct);
    return Results.Ok(new { id = entry.Id, mealDate = entry.MealDate, mealName = "Bữa phụ ngoài", caloriesKcal = entry.CaloriesKcal });
});
me.MapPut("/extra-meals/{suggestionId:guid}", async (Guid suggestionId, ExtraMealRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var userId = UserId(p);
    if (r.CaloriesKcal is < 1 or > 10000)
        return Results.BadRequest(new { message = "Nhập lượng calo từ 1 đến 10000 kcal." });
    var entry = await db.ExtraCalorieEntries.FirstOrDefaultAsync(x => x.Id == suggestionId && x.UserId == userId, ct);
    if (entry is not null)
    {
        entry.CaloriesKcal = r.CaloriesKcal;
        entry.UpdatedAtUtc = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
        return Results.Ok(new { id = entry.Id, mealDate = entry.MealDate, mealName = "Bữa phụ ngoài", caloriesKcal = entry.CaloriesKcal });
    }

    // Keep extra meals created by the earlier dish-based form editable.
    var suggestion = await db.MealSuggestions.FirstOrDefaultAsync(
        x => x.Id == suggestionId && x.UserId == userId && x.IsExtraMeal, ct);
    if (suggestion is null) return Results.NotFound();
    var consumedLog = await db.ConsumedMealLogs.FirstOrDefaultAsync(
        x => x.MealSuggestionId == suggestionId && x.UserId == userId, ct);
    if (consumedLog is null) return Results.Conflict(new { message = "Bữa phụ đã bị hủy lưu; hãy thêm lại nếu muốn ghi nhận." });

    suggestion.MealName = "Bữa phụ ngoài";
    suggestion.MealTime = null;
    suggestion.ServingWeightGrams = null;
    suggestion.PersonalizedIngredientsJson = "[]";
    suggestion.EstimatedNutrientsJson = JsonSerializer.Serialize(new
    {
        energy_kcal = r.CaloriesKcal,
        protein_g = (decimal?)null,
        carbohydrate_g = (decimal?)null,
        total_fat_g = (decimal?)null,
    });
    suggestion.UpdatedAtUtc = DateTime.UtcNow;
    consumedLog.MealName = "Bữa phụ ngoài";
    consumedLog.ConsumedIngredientsJson = "[]";
    await db.SaveChangesAsync(ct);
    return Results.Ok(new { id = suggestion.Id, mealDate = suggestion.MealDate, mealName = suggestion.MealName, caloriesKcal = r.CaloriesKcal });
});
me.MapGet("/meals/log", async (DateOnly? date, DateOnly? fromDate, DateOnly? toDate, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var userId = UserId(p);
    var query = db.ConsumedMealLogs.AsNoTracking().Where(x => x.UserId == userId);
    if (date is not null) query = query.Where(x => x.MealDate == date.Value);
    if (fromDate is not null) query = query.Where(x => x.MealDate >= fromDate.Value);
    if (toDate is not null) query = query.Where(x => x.MealDate <= toDate.Value);
    var logs = await query.OrderBy(x => x.MealDate).ThenBy(x => x.MealName)
        .Select(x => new
        {
            x.Id, x.MealSuggestionId, x.MealDate, x.MealName, x.DishId, x.ConsumedIngredientsJson,
            x.ConfirmedAtUtc, DishName = x.Dish.Name,
            x.MealSuggestion.IsExtraMeal, x.MealSuggestion.MealTime,
            x.MealSuggestion.ServingWeightGrams,
            EstimatedNutrientsJson = x.MealSuggestion.EstimatedNutrientsJson,
        })
        .ToListAsync(ct);
    var response = logs.Select(x => (object)new
    {
        x.Id, x.MealSuggestionId, x.MealDate, x.MealName, x.DishId, x.ConsumedIngredientsJson,
        x.ConfirmedAtUtc, x.DishName,
        x.IsExtraMeal, isCalorieOnly = x.IsExtraMeal && HasUnknownMealMacros(x.EstimatedNutrientsJson),
        mealTime = x.MealTime?.ToString("HH:mm"),
        weightGrams = x.ServingWeightGrams,
        estimatedNutrients = JsonSerializer.Deserialize<JsonElement>(x.EstimatedNutrientsJson),
    }).ToList();
    var extraCalories = await db.ExtraCalorieEntries.AsNoTracking().Where(x => x.UserId == userId)
        .Where(x => date == null || x.MealDate == date.Value)
        .Where(x => fromDate == null || x.MealDate >= fromDate.Value)
        .Where(x => toDate == null || x.MealDate <= toDate.Value)
        .OrderBy(x => x.MealDate).ThenBy(x => x.CreatedAtUtc).ToListAsync(ct);
    response.AddRange(extraCalories.Select(x => (object)new
    {
        id = x.Id,
        mealSuggestionId = x.Id,
        x.MealDate,
        mealName = "Bữa phụ ngoài",
        dishId = (Guid?)null,
        consumedIngredientsJson = "[]",
        confirmedAtUtc = x.CreatedAtUtc,
        dishName = "Bữa phụ ngoài",
        isExtraMeal = true,
        isCalorieOnly = true,
        mealTime = (string?)null,
        weightGrams = (decimal?)null,
        estimatedNutrients = new
        {
            energy_kcal = x.CaloriesKcal,
            protein_g = (decimal?)null,
            carbohydrate_g = (decimal?)null,
            total_fat_g = (decimal?)null,
        },
    }));
    return Results.Ok(response);
});
me.MapGet("/avatar/{ownerId:guid}", async (Guid ownerId, ClaimsPrincipal p, AppDbContext db, IWebHostEnvironment env, HttpContext context, CancellationToken ct) =>
{
    var id = UserId(p);
    if (id != ownerId) return Results.NotFound();
    var filename = await db.Profiles.AsNoTracking().Where(x => x.UserId == id).Select(x => x.AvatarPath).FirstOrDefaultAsync(ct);
    if (filename is null) return Results.NotFound();
    var path = Path.Combine(env.ContentRootPath, "Uploads", "Avatars", filename);
    if (!File.Exists(path)) return Results.NotFound();
    var contentType = Path.GetExtension(filename).ToLowerInvariant() switch { ".png" => "image/png", ".webp" => "image/webp", _ => "image/jpeg" };
    context.Response.Headers.CacheControl = "private, no-store";
    return Results.File(path, contentType);
});
me.MapPost("/avatar", async (HttpRequest request, ClaimsPrincipal p, AppDbContext db, IWebHostEnvironment env, CancellationToken ct) =>
{
    const int maxBytes = 5 * 1024 * 1024;
    if (request.ContentLength is > maxBytes) return Results.BadRequest(new { message = "Ảnh đại diện không được vượt quá 5 MB." });
    await using var memory = new MemoryStream();
    var buffer = new byte[64 * 1024];
    int read;
    while ((read = await request.Body.ReadAsync(buffer, ct)) > 0)
    {
        if (memory.Length + read > maxBytes) return Results.BadRequest(new { message = "Ảnh đại diện không được vượt quá 5 MB." });
        await memory.WriteAsync(buffer.AsMemory(0, read), ct);
    }
    var bytes = memory.ToArray();
    string? extension = null;
    if (bytes.Length >= 8 && bytes.AsSpan(0, 8).SequenceEqual(new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 })) extension = ".png";
    else if (bytes.Length >= 3 && bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255) extension = ".jpg";
    else if (bytes.Length >= 12 && Encoding.ASCII.GetString(bytes, 0, 4) == "RIFF" && Encoding.ASCII.GetString(bytes, 8, 4) == "WEBP") extension = ".webp";
    if (extension is null) return Results.BadRequest(new { message = "Chỉ hỗ trợ ảnh JPEG, PNG hoặc WebP hợp lệ." });

    var id = UserId(p);
    var profile = await db.Profiles.FirstOrDefaultAsync(x => x.UserId == id, ct);
    if (profile is null) return Results.NotFound(new { message = "Chưa tìm thấy hồ sơ tài khoản." });
    var directory = Path.Combine(env.ContentRootPath, "Uploads", "Avatars");
    Directory.CreateDirectory(directory);
    var filename = $"{id:N}_{Guid.NewGuid():N}{extension}";
    var newPath = Path.Combine(directory, filename);
    var previous = profile.AvatarPath;
    await File.WriteAllBytesAsync(newPath, bytes, ct);
    try
    {
        profile.AvatarPath = filename;
        profile.UpdatedAtUtc = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
    }
    catch
    {
        File.Delete(newPath);
        throw;
    }
    if (previous is not null)
    {
        var oldPath = Path.Combine(directory, previous);
        if (File.Exists(oldPath)) File.Delete(oldPath);
    }
    return Results.Ok(new { avatarUrl = $"/api/me/avatar/{id}?v={profile.UpdatedAtUtc.Ticks}", profile.UpdatedAtUtc });
});
me.MapGet("/security", async (ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var id = UserId(p); var u = await db.Users.AsNoTracking().Where(x => x.Id == id).Select(x => new { x.Email, x.Phone, x.IsEmailVerified, x.IsPhoneVerified }).FirstOrDefaultAsync(ct);
    return u is null ? Results.NotFound() : Results.Ok(u);
});
me.MapPost("/security/password/request", async (ClaimsPrincipal p, AppDbContext db, IOtpSender sender, CancellationToken ct) =>
{
    var id = UserId(p); var u = await db.Users.FirstOrDefaultAsync(x => x.Id == id, ct); if (u is null) return Results.NotFound();
    if (string.IsNullOrWhiteSpace(u.Email)) return Results.Conflict(new { message = "Tài khoản cần có email để nhận OTP đổi mật khẩu." });
    var previous = await db.OtpChallenges.Where(x => x.UserId == id && x.Purpose == "PasswordChange" && x.ConsumedAtUtc == null).OrderByDescending(x => x.CreatedAtUtc).FirstOrDefaultAsync(ct);
    var now = DateTime.UtcNow;
    if (previous is not null && previous.CreatedAtUtc.AddSeconds(60) > now) return Results.Problem("Vui lòng đợi mã hiện tại hết hạn rồi thử lại.", statusCode: 429);
    if (previous is not null) previous.ConsumedAtUtc = now;
    var (challenge, code) = OtpCodes.Create(id, u.Email, "PasswordChange", now); db.OtpChallenges.Add(challenge); await db.SaveChangesAsync(ct);
    try { await sender.SendAsync(u.Email, "PasswordChange", code, ct); }
    catch (InvalidOperationException e) { db.OtpChallenges.Remove(challenge); await db.SaveChangesAsync(ct); return Results.Problem(e.Message, statusCode: 503); }
    return Results.Ok(new { message = "Đã gửi mã đổi mật khẩu tới email của tài khoản.", expiresInSeconds = 60 });
});
me.MapPost("/security/password", async (PasswordChangeRequest r, ClaimsPrincipal p, AppDbContext db, IPasswordHasher<AppUser> hasher, CancellationToken ct) =>
{
    var id = UserId(p); var u = await db.Users.FirstOrDefaultAsync(x => x.Id == id, ct); if (u is null) return Results.NotFound();
    if (hasher.VerifyHashedPassword(u, u.PasswordHash, r.CurrentPassword) == PasswordVerificationResult.Failed) return Results.BadRequest(new { message = "Mật khẩu hiện tại không đúng." });
    if (!PasswordPolicy.IsValid(r.NewPassword)) return Results.BadRequest(new { message = PasswordPolicy.Requirement });
    var passwordChallenge = await db.OtpChallenges.Where(x => x.UserId == id && x.Destination == u.Email && x.Purpose == "PasswordChange" && x.ConsumedAtUtc == null).OrderByDescending(x => x.CreatedAtUtc).FirstOrDefaultAsync(ct);
    if (string.IsNullOrWhiteSpace(r.Code) || !OtpCodes.Verify(passwordChallenge, r.Code)) { await db.SaveChangesAsync(ct); return Results.BadRequest(new { message = "Mã OTP đổi mật khẩu không đúng, đã hết hạn hoặc đã dùng." }); }
    passwordChallenge!.ConsumedAtUtc = DateTime.UtcNow;
    u.IsEmailVerified = true;
    u.PasswordHash = hasher.HashPassword(u, r.NewPassword); u.TokenVersion++;
    var wasForced = u.MustChangePassword; u.MustChangePassword = false;
    foreach (var s in await db.RefreshSessions.Where(x => x.UserId == id && x.RevokedAtUtc == null).ToListAsync(ct)) s.RevokedAtUtc = DateTime.UtcNow;
    if (u.Role is "Admin" or "SuperAdmin") db.AdminActionLogs.Add(new AdminActionLog { AdminUserId = id, Action = wasForced ? "FirstPasswordChanged" : "PasswordChanged", Reason = "Mật khẩu được cập nhật; không lưu giá trị mật khẩu." });
    await db.SaveChangesAsync(ct); return Results.Ok(new { message = "Đã đổi mật khẩu. Hãy đăng nhập lại trên thiết bị." });
});
me.MapPost("/security/email/request", async (EmailChangeRequest r, ClaimsPrincipal p, AppDbContext db, IPasswordHasher<AppUser> hasher, IOtpSender sender, CancellationToken ct) =>
{
    var id = UserId(p); var u = await db.Users.FirstOrDefaultAsync(x => x.Id == id, ct); if (u is null) return Results.NotFound();
    var email = NormalizeEmail(r.NewEmail);
    if (email is null || hasher.VerifyHashedPassword(u, u.PasswordHash, r.Password) == PasswordVerificationResult.Failed) return Results.BadRequest(new { message = "Email mới hoặc mật khẩu không hợp lệ." });
    if (await db.Users.AnyAsync(x => x.Email == email && x.Id != id, ct)) return Results.Conflict(new { message = "Email đã được tài khoản khác sử dụng." });
    var previous = await db.OtpChallenges.Where(x => x.UserId == id && x.Purpose == "ContactChange" && x.ConsumedAtUtc == null).OrderByDescending(x => x.CreatedAtUtc).FirstOrDefaultAsync(ct);
    var now = DateTime.UtcNow;
    if (previous is not null && previous.CreatedAtUtc.AddSeconds(60) > now) return Results.Problem("Vui lòng đợi mã hiện tại hết hạn rồi thử lại.", statusCode: 429);
    if (previous is not null) previous.ConsumedAtUtc = now;
    var (challenge, code) = OtpCodes.Create(id, email, "ContactChange", now); db.OtpChallenges.Add(challenge); await db.SaveChangesAsync(ct);
    try { await sender.SendAsync(email, "ContactChange", code, ct); } catch (InvalidOperationException e) { return Results.Problem(e.Message, statusCode: 503); }
    return Results.Ok(new { message = "Đã gửi mã xác minh tới email mới.", expiresInSeconds = 60 });
});
me.MapPost("/security/email/confirm", async (ContactOtpRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var id = UserId(p); var email = NormalizeEmail(r.NewEmail); if (email is null) return Results.BadRequest();
    var challenge = await db.OtpChallenges.Where(x => x.UserId == id && x.Destination == email && x.Purpose == "ContactChange" && x.ConsumedAtUtc == null).OrderByDescending(x => x.CreatedAtUtc).FirstOrDefaultAsync(ct);
    if (!OtpCodes.Verify(challenge, r.Code)) { await db.SaveChangesAsync(ct); return Results.BadRequest(new { message = "Mã không đúng, đã hết hạn hoặc đã dùng." }); }
    if (await db.Users.AnyAsync(x => x.Email == email && x.Id != id, ct)) return Results.Conflict(new { message = "Email đã được tài khoản khác sử dụng." });
    var u = await db.Users.FirstAsync(x => x.Id == id, ct); var before = new { u.Email, u.IsEmailVerified }; u.Email = email; u.IsEmailVerified = true; challenge!.ConsumedAtUtc = DateTime.UtcNow;
    foreach (var s in await db.RefreshSessions.Where(x => x.UserId == id && x.RevokedAtUtc == null).ToListAsync(ct)) s.RevokedAtUtc = DateTime.UtcNow;
    u.TokenVersion++;
    if (u.Role is "Admin" or "SuperAdmin") db.AdminActionLogs.Add(Audit(id, "ChangeOwnAdminEmail", id, "Email đã xác minh bằng OTP.", before, new { u.Email, u.IsEmailVerified }));
    await db.SaveChangesAsync(ct); return Results.Ok(new { message = "Email đã được thay đổi. Hãy đăng nhập lại." });
});
me.MapPost("/security/phone/request", async (PhoneChangeRequest r, ClaimsPrincipal p, AppDbContext db, IPasswordHasher<AppUser> hasher, IOtpSender sender, CancellationToken ct) =>
{
    var id = UserId(p); var u = await db.Users.FirstOrDefaultAsync(x => x.Id == id, ct); if (u is null) return Results.NotFound();
    if (u.Role is not ("Admin" or "SuperAdmin")) return Results.BadRequest(new { message = "Đổi số điện thoại OTP chỉ áp dụng cho tài khoản quản trị." });
    var phone = NormalizePhone(r.NewPhone);
    if (phone is null || string.IsNullOrWhiteSpace(u.Email) || hasher.VerifyHashedPassword(u, u.PasswordHash, r.Password) == PasswordVerificationResult.Failed) return Results.BadRequest(new { message = "Số điện thoại hoặc mật khẩu không hợp lệ." });
    if (phone == u.Phone) return Results.BadRequest(new { message = "Số điện thoại này đang được sử dụng." });
    if (await db.Users.AnyAsync(x => x.Id != id && !x.IsDeleted && x.Phone == phone, ct)) return Results.Conflict(new { message = "Số điện thoại đã được tài khoản khác sử dụng." });
    var previous = await db.OtpChallenges.Where(x => x.UserId == id && x.Purpose == "AdminPhoneChange" && x.ConsumedAtUtc == null).OrderByDescending(x => x.CreatedAtUtc).FirstOrDefaultAsync(ct);
    var now = DateTime.UtcNow;
    if (previous is not null && previous.CreatedAtUtc.AddSeconds(60) > now) return Results.Problem("Vui lòng đợi mã hiện tại hết hạn rồi thử lại.", statusCode: 429);
    if (previous is not null) previous.ConsumedAtUtc = now;
    var (challenge, code) = OtpCodes.Create(id, phone, "AdminPhoneChange", now); db.OtpChallenges.Add(challenge); await db.SaveChangesAsync(ct);
    try { await sender.SendAsync(u.Email, "AdminPhoneChange", code, ct); }
    catch (InvalidOperationException e) { db.OtpChallenges.Remove(challenge); await db.SaveChangesAsync(ct); return Results.Problem(e.Message, statusCode: 503); }
    return Results.Ok(new { message = "Đã gửi OTP xác nhận số điện thoại tới email hiện tại.", expiresInSeconds = 60 });
});
me.MapPost("/security/phone/confirm", async (PhoneOtpRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var id = UserId(p); var u = await db.Users.FirstOrDefaultAsync(x => x.Id == id, ct); if (u is null) return Results.NotFound();
    if (u.Role is not ("Admin" or "SuperAdmin")) return Results.BadRequest(new { message = "Đổi số điện thoại OTP chỉ áp dụng cho tài khoản quản trị." });
    var phone = NormalizePhone(r.NewPhone); if (phone is null) return Results.BadRequest(new { message = "Số điện thoại không hợp lệ." });
    var challenge = await db.OtpChallenges.Where(x => x.UserId == id && x.Destination == phone && x.Purpose == "AdminPhoneChange" && x.ConsumedAtUtc == null).OrderByDescending(x => x.CreatedAtUtc).FirstOrDefaultAsync(ct);
    if (!OtpCodes.Verify(challenge, r.Code)) { await db.SaveChangesAsync(ct); return Results.BadRequest(new { message = "Mã OTP không đúng, đã hết hạn hoặc đã dùng." }); }
    if (await db.Users.AnyAsync(x => x.Id != id && !x.IsDeleted && x.Phone == phone, ct)) return Results.Conflict(new { message = "Số điện thoại đã được tài khoản khác sử dụng." });
    var before = new { u.Phone, u.IsPhoneVerified };
    u.Phone = phone; u.IsPhoneVerified = true; u.TokenVersion++; challenge!.ConsumedAtUtc = DateTime.UtcNow;
    foreach (var s in await db.RefreshSessions.Where(x => x.UserId == id && x.RevokedAtUtc == null).ToListAsync(ct)) s.RevokedAtUtc = DateTime.UtcNow;
    if (u.Role is "Admin" or "SuperAdmin") db.AdminActionLogs.Add(Audit(id, "ChangeOwnAdminPhone", id, "Số điện thoại được xác minh bằng OTP gửi tới email hiện tại.", before, new { u.Phone, u.IsPhoneVerified }));
    await db.SaveChangesAsync(ct); return Results.Ok(new { message = "Số điện thoại đã được cập nhật. Hãy đăng nhập lại." });
});
me.MapPost("/account/delete/request", async (ClaimsPrincipal p, AppDbContext db, IOtpSender sender, CancellationToken ct) =>
{
    var id = UserId(p); var u = await db.Users.FirstOrDefaultAsync(x => x.Id == id && x.IsEmailVerified && x.Email != null, ct);
    if (u is null) return Results.Conflict(new { message = "Cần email đã xác minh để nhận mã xác nhận xóa tài khoản." });
    var previous = await db.OtpChallenges.Where(x => x.UserId == id && x.Purpose == "AccountDeletion" && x.ConsumedAtUtc == null).OrderByDescending(x => x.CreatedAtUtc).FirstOrDefaultAsync(ct);
    var now = DateTime.UtcNow;
    if (previous is not null && previous.CreatedAtUtc.AddSeconds(60) > now) return Results.Problem("Vui lòng đợi mã hiện tại hết hạn rồi thử lại.", statusCode: 429);
    if (previous is not null) previous.ConsumedAtUtc = now;
    var (challenge, code) = OtpCodes.Create(id, u.Email!, "AccountDeletion", now); db.OtpChallenges.Add(challenge); await db.SaveChangesAsync(ct);
    try { await sender.SendAsync(u.Email!, "AccountDeletion", code, ct); } catch (InvalidOperationException e) { return Results.Problem(e.Message, statusCode: 503); }
    return Results.Ok(new { message = "Đã gửi mã xác nhận xóa tài khoản.", expiresInSeconds = 60 });
});
me.MapPost("/account/delete/confirm", async (OtpCodeRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var id = UserId(p); var user = await db.Users.FirstOrDefaultAsync(x => x.Id == id, ct); if (user is null) return Results.NotFound();
    var challenge = await db.OtpChallenges.Where(x => x.UserId == id && x.Purpose == "AccountDeletion" && x.ConsumedAtUtc == null).OrderByDescending(x => x.CreatedAtUtc).FirstOrDefaultAsync(ct);
    if (!OtpCodes.Verify(challenge, r.Code)) { await db.SaveChangesAsync(ct); return Results.BadRequest(new { message = "Mã không đúng, đã hết hạn hoặc đã dùng." }); }
    await using var transaction = await db.Database.BeginTransactionAsync(ct);
    db.Users.Remove(user); await db.SaveChangesAsync(ct); await transaction.CommitAsync(ct);
    return Results.Ok(new { message = "Tài khoản và dữ liệu cá nhân liên quan đã được xóa." });
});

var fridge = app.MapGroup("/api/me/fridge").RequireAuthorization();
fridge.MapGet("", async (ClaimsPrincipal p, AppDbContext db, CancellationToken ct) => { var owner = UserId(p); return Results.Ok(await db.FridgeItems.AsNoTracking().Where(x => x.UserId == owner).OrderBy(x => x.Name).ToListAsync(ct)); });
fridge.MapPost("", async (FridgeRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var name = System.Text.RegularExpressions.Regex.Replace(r.Name.Trim(), @"\s+", " "); if (name.Length is 0 or > 160) return Results.BadRequest(new { message = "Tên thực phẩm cần từ 1 đến 160 ký tự." });
    var owner = UserId(p);
    Guid? foodId = null;
    if (r.FoodId is not null) { var f = await db.Foods.AsNoTracking().Include(x => x.Nutrition).FirstOrDefaultAsync(x => x.Id == r.FoodId && !x.IsDeleted && x.FoodState == "Unprocessed", ct); if (f is null || !CanUseInCatalog(f)) return Results.BadRequest(new { message = "Thực phẩm chưa đủ dữ liệu đã xác minh hoặc không tồn tại." }); foodId = f.Id; name = System.Text.RegularExpressions.Regex.Replace(f.Name.Trim(), @"\s+", " "); }
    if (await db.FridgeItems.AnyAsync(x => x.UserId == owner && x.Name.ToUpper() == name.ToUpper(), ct)) return Results.Conflict(new { message = "Tên này đã có trong tủ lạnh." });
    var item = new FridgeItem { UserId = owner, Name = name, FoodId = foodId }; db.FridgeItems.Add(item); await db.SaveChangesAsync(ct); return Results.Created($"/api/me/fridge/{item.Id}", item);
});
fridge.MapPut("/{id:guid}", async (Guid id, FridgeRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var owner = UserId(p); var item = await db.FridgeItems.FirstOrDefaultAsync(x => x.Id == id && x.UserId == owner, ct); if (item is null) return Results.NotFound();
    var name = System.Text.RegularExpressions.Regex.Replace(r.Name.Trim(), @"\s+", " "); if (name.Length is 0 or > 160) return Results.BadRequest();
    if (r.FoodId is Guid fId) { var f = await db.Foods.Include(x => x.Nutrition).FirstOrDefaultAsync(x => x.Id == fId && !x.IsDeleted && x.FoodState == "Unprocessed", ct); if (f is null || !CanUseInCatalog(f)) return Results.BadRequest(new { message = "Thực phẩm chưa đủ dữ liệu đã xác minh." }); name = System.Text.RegularExpressions.Regex.Replace(f.Name.Trim(), @"\s+", " "); item.FoodId = f.Id; }
    else item.FoodId = null;
    if (await db.FridgeItems.AnyAsync(x => x.UserId == item.UserId && x.Id != id && x.Name.ToUpper() == name.ToUpper(), ct)) return Results.Conflict();
    item.Name = name;
    await db.SaveChangesAsync(ct); return Results.Ok(item);
});
fridge.MapDelete("/{id:guid}", async (Guid id, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var owner = UserId(p); var item = await db.FridgeItems.FirstOrDefaultAsync(x => x.Id == id && x.UserId == owner, ct); if (item is null) return Results.NotFound(); db.Remove(item); await db.SaveChangesAsync(ct); return Results.NoContent();
});

var foods = app.MapGroup("/api/foods");
foods.MapGet("", async (AppDbContext db, CancellationToken ct) =>
{
    var rows = await LoadFoodsWithSources(
        db.Foods.AsNoTracking().Where(x => !x.IsDeleted && x.FoodState == "Unprocessed"),
        db, ct, includeFoodGroup: true);
    var eligible = rows.Where(CanUseInCatalog).ToList();
    return Results.Ok(eligible);
});
foods.MapGet("/{id:guid}/image", async (Guid id, AppDbContext db, IWebHostEnvironment env, HttpContext context, CancellationToken ct) =>
{
    var food = await db.Foods.AsNoTracking().Include(x => x.Nutrition).FirstOrDefaultAsync(x => x.Id == id && !x.IsDeleted && x.FoodState == "Unprocessed", ct);
    if (food is null || !CanUseInCatalog(food) || food.ImagePath is null) return Results.NotFound();
    var filename = food.ImagePath;
    var path = Path.Combine(env.ContentRootPath, "Uploads", "Foods", filename);
    if (!File.Exists(path)) return Results.NotFound();
    context.Response.Headers.CacheControl = "private, no-store";
    return Results.File(path, FoodImageContentType(filename));
});
var dishes = app.MapGroup("/api/dishes").RequireAuthorization();
dishes.MapGet("", async (string? search, string? category, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var query = db.Dishes.AsNoTracking().Where(x => !x.IsDeleted && x.Status == "Published");
    if (!string.IsNullOrWhiteSpace(search)) query = query.Where(x => x.Name.Contains(search.Trim()));
    if (!string.IsNullOrWhiteSpace(category)) query = query.Where(x => x.Category == category.Trim());
    var items = await query.AsSplitQuery().Include(x => x.Ingredients).ThenInclude(x => x.Food).Include(x => x.Steps).OrderBy(x => x.Name).ToListAsync(ct);
    var ids = items.Select(x => x.Id).ToArray();
    var ratings = await db.Ratings.AsNoTracking().Where(x => ids.Contains(x.DishId)).ToListAsync(ct);
    var userId = UserId(p);
    return Results.Ok(items.Select(x => DishDtoWithRatings(x, ratings.Where(r => r.DishId == x.Id).ToList(), userId)));
});
dishes.MapGet("/{id:guid}", async (Guid id, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var dish = await db.Dishes.AsNoTracking().Where(x => x.Id == id && !x.IsDeleted && x.Status == "Published")
        .AsSplitQuery()
        .Include(x => x.Ingredients).ThenInclude(x => x.Food).Include(x => x.Steps).FirstOrDefaultAsync(ct);
    if (dish is null) return Results.NotFound();
    var ratings = await db.Ratings.AsNoTracking().Where(x => x.DishId == id).ToListAsync(ct);
    return Results.Ok(DishDtoWithRatings(dish, ratings, UserId(p)));
});
dishes.MapGet("/{id:guid}/ratings", async (Guid id, AppDbContext db, CancellationToken ct) =>
{
    if (!await db.Dishes.AnyAsync(x => x.Id == id && !x.IsDeleted && x.Status == "Published", ct)) return Results.NotFound();
    var ratings = await db.Ratings.AsNoTracking().Where(x => x.DishId == id)
        .OrderByDescending(x => x.UpdatedAtUtc)
        .Select(x => new { x.Stars, x.Comment, x.UpdatedAtUtc })
        .ToListAsync(ct);
    return Results.Ok(new
    {
        ratingCount = ratings.Count,
        averageRating = ratings.Count == 0 ? (decimal?)null : Math.Round(ratings.Average(x => (decimal)x.Stars), 1),
        ratings,
    });
});
dishes.MapGet("/{id:guid}/image", async (Guid id, AppDbContext db, IWebHostEnvironment env, HttpContext context, CancellationToken ct) =>
{
    var filename = await db.Dishes.AsNoTracking().Where(x => x.Id == id && !x.IsDeleted && x.Status == "Published").Select(x => x.ImagePath).FirstOrDefaultAsync(ct);
    if (filename is null) return Results.NotFound();
    var path = Path.Combine(env.ContentRootPath, "Uploads", "Dishes", filename);
    if (!File.Exists(path)) return Results.NotFound();
    context.Response.Headers.CacheControl = "public, max-age=3600";
    return Results.File(path, FoodImageContentType(filename));
});
var adminDishes = app.MapGroup("/api/admin/dishes").RequireAuthorization(p => p.RequireRole("Admin", "SuperAdmin"));
adminDishes.MapGet("/food-options", async (AppDbContext db, CancellationToken ct) => Results.Ok(await db.Foods.AsNoTracking().Where(x => !x.IsDeleted).OrderBy(x => x.Name).Select(x => new DishFoodOption(x.Id, x.Name, x.FoodGroup == null ? null : x.FoodGroup.Name, x.Basis)).ToListAsync(ct)));
adminDishes.MapGet("", async (string? status, string? search, string? method, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var query = db.Dishes.AsNoTracking().Include(x => x.Ingredients).ThenInclude(x => x.Food).Include(x => x.Steps).AsQueryable();
    if (string.Equals(status, "Trash", StringComparison.OrdinalIgnoreCase))
    {
        query = query.Where(x => x.IsDeleted);
        if (!p.IsInRole("SuperAdmin")) { var actorId = UserId(p); query = query.Where(x => x.DeletedByUserId == actorId); }
    }
    else
    {
        query = query.Where(x => !x.IsDeleted);
        if (!string.IsNullOrWhiteSpace(status) && !string.Equals(status, "All", StringComparison.OrdinalIgnoreCase)) query = query.Where(x => x.Status == status);
    }
    if (!string.IsNullOrWhiteSpace(search)) query = query.Where(x => x.Name.Contains(search));
    if (!string.IsNullOrWhiteSpace(method))
    {
        if (method == "Khác") query = query.Where(x => x.CookingMethod != null && x.CookingMethod != "Luộc" && x.CookingMethod != "Hấp" && x.CookingMethod != "Xào" && x.CookingMethod != "Nướng");
        else query = query.Where(x => x.CookingMethod == method);
    }
    var dishes = await query.OrderByDescending(x => x.UpdatedAtUtc).ToListAsync(ct);
    if (!string.Equals(status, "Trash", StringComparison.OrdinalIgnoreCase))
        return Results.Ok(dishes.Select(x => DishDto(x)));
    if (!p.IsInRole("SuperAdmin"))
        return Results.Ok(dishes.Select(x => DishDto(x)));

    var deleterIds = dishes.Where(x => x.DeletedByUserId.HasValue)
        .Select(x => x.DeletedByUserId!.Value).Distinct().ToArray();
    var deleters = await db.Users.AsNoTracking().Where(x => deleterIds.Contains(x.Id))
        .Select(x => new { x.Id, x.Username, x.Email, FullName = x.Profile == null ? null : x.Profile.FullName })
        .ToDictionaryAsync(x => x.Id, ct);
    return Results.Ok(dishes.Select(dish =>
    {
        var actor = dish.DeletedByUserId is Guid actorId && deleters.TryGetValue(actorId, out var found) ? found : null;
        return DishDto(dish, actor?.FullName ?? actor?.Username ?? actor?.Email, actor?.Email);
    }));
});
adminDishes.MapGet("/{id:guid}", async (Guid id, AppDbContext db, CancellationToken ct) =>
{
    var dish = await db.Dishes.AsNoTracking().Where(x => x.Id == id).Include(x => x.Ingredients).ThenInclude(x => x.Food).Include(x => x.Steps).FirstOrDefaultAsync(ct);
    return dish is null ? Results.NotFound() : Results.Ok(DishDto(dish));
});
adminDishes.MapPost("", async (DishWriteRequest request, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var dish = new Dish();
    db.Dishes.Add(dish);
    var error = await ApplyDishWriteAsync(dish, request, db, ct);
    if (error is not null) return Results.BadRequest(new { message = error });
    var action = dish.Status == "Published" ? "PublishDish" : "SaveDishDraft";
    db.AdminActionLogs.Add(Audit(UserId(p), action, dish.Id, "Tạo món ăn.", null, new { dish.Name, dish.Status, Ingredients = dish.Ingredients.Count, Steps = await db.DishSteps.CountAsync(x => x.DishId == dish.Id, ct) }));
    await db.SaveChangesAsync(ct);
    var created = await db.Dishes.AsNoTracking().Where(x => x.Id == dish.Id).Include(x => x.Ingredients).ThenInclude(x => x.Food).Include(x => x.Steps).FirstAsync(ct);
    return Results.Created($"/api/admin/dishes/{dish.Id}", DishDto(created));
});
adminDishes.MapPut("/{id:guid}", async (Guid id, DishWriteRequest request, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var dish = await db.Dishes.FirstOrDefaultAsync(x => x.Id == id && !x.IsDeleted, ct);
    if (dish is null) return Results.NotFound();
    var before = new { dish.Name, dish.Status, dish.CookingMethod, IngredientCount = await db.DishIngredients.CountAsync(x => x.DishId == id, ct), StepCount = await db.DishSteps.CountAsync(x => x.DishId == id, ct) };
    await using var transaction = await db.Database.BeginTransactionAsync(ct);
    var error = await ApplyDishWriteAsync(dish, request, db, ct);
    if (error is not null) return Results.BadRequest(new { message = error });
    var action = dish.Status == "Published" && before.Status != "Published" ? "PublishDish" : dish.Status == "Draft" ? "SaveDishDraft" : "UpdateDish";
    db.AdminActionLogs.Add(Audit(UserId(p), action, id, "", before, new { dish.Name, dish.Status, Ingredients = request.FoodIds?.Count ?? 0 }));
    await db.SaveChangesAsync(ct);
    await transaction.CommitAsync(ct);
    var result = await db.Dishes.AsNoTracking().Where(x => x.Id == id).Include(x => x.Ingredients).ThenInclude(x => x.Food).Include(x => x.Steps).FirstAsync(ct);
    return Results.Ok(DishDto(result));
});
adminDishes.MapDelete("/{id:guid}", async (Guid id, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var dish = await db.Dishes.FirstOrDefaultAsync(x => x.Id == id && !x.IsDeleted, ct);
    if (dish is null) return Results.NotFound();
    var before = new { dish.Name, dish.Status };
    dish.IsDeleted = true; dish.DeletedAtUtc = DateTime.UtcNow; dish.DeletedByUserId = UserId(p); dish.UpdatedAtUtc = DateTime.UtcNow;
    db.AdminActionLogs.Add(Audit(UserId(p), "MoveDishToTrash", id, "", before, new { dish.IsDeleted, dish.DeletedAtUtc }));
    await db.SaveChangesAsync(ct); return Results.NoContent();
});
adminDishes.MapPost("/{id:guid}/restore", async (Guid id, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    if (!p.IsInRole("SuperAdmin")) return Results.Forbid();
    var dish = await db.Dishes.FirstOrDefaultAsync(x => x.Id == id && x.IsDeleted, ct);
    if (dish is null) return Results.NotFound();
    dish.IsDeleted = false; dish.Status = "Draft"; dish.DeletedAtUtc = null; dish.DeletedByUserId = null; dish.UpdatedAtUtc = DateTime.UtcNow;
    db.AdminActionLogs.Add(Audit(UserId(p), "RestoreDish", id, "Khôi phục về trạng thái Nháp.", new { IsDeleted = true }, new { IsDeleted = false, dish.Status }));
    await db.SaveChangesAsync(ct); return Results.NoContent();
}).RequireAuthorization(policy => policy.RequireRole("SuperAdmin"));
adminDishes.MapGet("/{id:guid}/image", async (Guid id, AppDbContext db, IWebHostEnvironment env, HttpContext context, CancellationToken ct) =>
{
    var filename = await db.Dishes.AsNoTracking().Where(x => x.Id == id).Select(x => x.ImagePath).FirstOrDefaultAsync(ct);
    if (filename is null) return Results.NotFound();
    var path = Path.Combine(env.ContentRootPath, "Uploads", "Dishes", filename);
    if (!File.Exists(path)) return Results.NotFound();
    context.Response.Headers.CacheControl = "private, no-store";
    return Results.File(path, FoodImageContentType(filename));
});
adminDishes.MapPost("/{id:guid}/image", async (Guid id, HttpRequest request, ClaimsPrincipal p, AppDbContext db, IWebHostEnvironment env, CancellationToken ct) =>
{
    const int maxBytes = 5 * 1024 * 1024;
    if (request.ContentLength is > maxBytes) return Results.BadRequest(new { message = "Ảnh không được vượt quá 5 MB." });
    await using var memory = new MemoryStream(); var buffer = new byte[64 * 1024]; int read;
    while ((read = await request.Body.ReadAsync(buffer, ct)) > 0) { if (memory.Length + read > maxBytes) return Results.BadRequest(new { message = "Ảnh không được vượt quá 5 MB." }); await memory.WriteAsync(buffer.AsMemory(0, read), ct); }
    var bytes = memory.ToArray(); var extension = FoodImageExtension(bytes);
    if (extension is null) return Results.BadRequest(new { message = "Chỉ hỗ trợ ảnh JPEG, PNG hoặc WebP hợp lệ." });
    var dish = await db.Dishes.FirstOrDefaultAsync(x => x.Id == id && !x.IsDeleted, ct); if (dish is null) return Results.NotFound();
    var directory = Path.Combine(env.ContentRootPath, "Uploads", "Dishes"); Directory.CreateDirectory(directory);
    var filename = $"{id:N}_{Guid.NewGuid():N}{extension}"; var newPath = Path.Combine(directory, filename); var previous = dish.ImagePath;
    await File.WriteAllBytesAsync(newPath, bytes, ct);
    try { dish.ImagePath = filename; dish.UpdatedAtUtc = DateTime.UtcNow; db.AdminActionLogs.Add(Audit(UserId(p), "UploadDishImage", id, "", new { HasImage = previous is not null }, new { HasImage = true })); await db.SaveChangesAsync(ct); }
    catch { File.Delete(newPath); throw; }
    if (previous is not null) { var oldPath = Path.Combine(directory, previous); if (File.Exists(oldPath)) File.Delete(oldPath); }
    return Results.Ok(new { imageUrl = $"/api/dishes/{id}/image?v={Guid.NewGuid():N}" });
});
adminDishes.MapDelete("/{id:guid}/image", async (Guid id, ClaimsPrincipal p, AppDbContext db, IWebHostEnvironment env, CancellationToken ct) =>
{
    var dish = await db.Dishes.FirstOrDefaultAsync(x => x.Id == id && !x.IsDeleted, ct); if (dish is null) return Results.NotFound();
    var filename = dish.ImagePath; if (filename is null) return Results.NoContent();
    dish.ImagePath = null; dish.UpdatedAtUtc = DateTime.UtcNow; db.AdminActionLogs.Add(Audit(UserId(p), "RemoveDishImage", id, "", new { HasImage = true }, new { HasImage = false })); await db.SaveChangesAsync(ct);
    var path = Path.Combine(env.ContentRootPath, "Uploads", "Dishes", filename); if (File.Exists(path)) File.Delete(path); return Results.NoContent();
});
me.MapGet("/favorites", async (ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var id = UserId(p);
    var saved = await db.Favorites.AsNoTracking()
        .Where(f => f.UserId == id && !db.Ratings.Any(r =>
            r.UserId == id && r.DishId == f.DishId && r.Stars < 4))
        .Join(db.Dishes.AsNoTracking().Where(d => !d.IsDeleted && d.Status == "Published"),
            f => f.DishId, d => d.Id,
            (f, d) => new { d.Id, d.Name, f.CreatedAtUtc })
        .ToListAsync(ct);
    var highRated = await db.Ratings.AsNoTracking()
        .Where(r => r.UserId == id && r.Stars >= 4)
        .Join(db.Dishes.AsNoTracking().Where(d => !d.IsDeleted && d.Status == "Published"),
            r => r.DishId, d => d.Id,
            (r, d) => new { d.Id, d.Name, CreatedAtUtc = r.UpdatedAtUtc })
        .ToListAsync(ct);
    var items = saved.Concat(highRated)
        .GroupBy(x => x.Id)
        .Select(group => group.OrderByDescending(x => x.CreatedAtUtc).First())
        .OrderByDescending(x => x.CreatedAtUtc)
        .ToList();
    return Results.Ok(items);
});
me.MapPost("/favorites/{dishId:guid}", async (Guid dishId, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var id = UserId(p); if (!await db.Dishes.AnyAsync(x => x.Id == dishId && !x.IsDeleted && x.Status == "Published", ct)) return Results.NotFound();
    if (!await db.Favorites.AnyAsync(x => x.UserId == id && x.DishId == dishId, ct)) { db.Favorites.Add(new Favorite { UserId = id, DishId = dishId }); await db.SaveChangesAsync(ct); }
    return Results.NoContent();
});
me.MapDelete("/favorites/{dishId:guid}", async (Guid dishId, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var id = UserId(p); var item = await db.Favorites.FirstOrDefaultAsync(x => x.UserId == id && x.DishId == dishId, ct); if (item is not null) { db.Remove(item); await db.SaveChangesAsync(ct); }
    return Results.NoContent();
});
me.MapGet("/ratings", async (ClaimsPrincipal p, AppDbContext db, CancellationToken ct) => { var id = UserId(p); return Results.Ok(await db.Ratings.AsNoTracking().Where(x => x.UserId == id).ToListAsync(ct)); });
me.MapPut("/ratings/{dishId:guid}", async (Guid dishId, RatingRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var id = UserId(p); if (r.Stars is < 1 or > 5 || !await db.Dishes.AnyAsync(x => x.Id == dishId && !x.IsDeleted && x.Status == "Published", ct)) return Results.BadRequest(new { message = "Món ăn không tồn tại hoặc số sao phải từ 1 đến 5." });
    var rating = await db.Ratings.FirstOrDefaultAsync(x => x.UserId == id && x.DishId == dishId, ct);
    if (rating is null) { rating = new Rating { UserId = id, DishId = dishId }; db.Ratings.Add(rating); }
    rating.Stars = r.Stars; rating.Comment = string.IsNullOrWhiteSpace(r.Comment) ? null : r.Comment.Trim(); rating.UpdatedAtUtc = DateTime.UtcNow;
    var favorite = await db.Favorites.FirstOrDefaultAsync(x => x.UserId == id && x.DishId == dishId, ct);
    if (r.Stars >= 4)
    {
        if (favorite is null) db.Favorites.Add(new Favorite { UserId = id, DishId = dishId });
    }
    else if (favorite is not null) db.Favorites.Remove(favorite);
    await db.SaveChangesAsync(ct); return Results.Ok(rating);
});
adminDishes.MapPut("/{id:guid}/ai-review", async (Guid id, DishAiReviewRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var dish = await db.Dishes.Include(x => x.Ingredients).FirstOrDefaultAsync(x => x.Id == id && !x.IsDeleted, ct);
    if (dish is null) return Results.NotFound();
    if (r.Approved && (r.AllergenIds is null || r.DietTags is null))
        return Results.BadRequest(new { message = "Äá»ƒ duyá»‡t AI, cáº§n xÃ¡c nháº­n danh sÃ¡ch dá»‹ á»©ng vÃ  cháº¿ Ä‘á»™ Äƒn (cÃ³ thá»ƒ lÃ  danh sÃ¡ch trá»‘ng)." });
    if (r.Approved && (string.IsNullOrWhiteSpace(dish.CookingNotes) || dish.Ingredients.Count == 0 || dish.Ingredients.Any(x => x.FoodId is null)))
        return Results.Conflict(new { message = "MÃ³n cÃ²n thiáº¿u cÃ´ng thá»©c hoáº·c nguyÃªn liá»‡u Ä‘Ã£ liÃªn káº¿t." });
    if (r.Approved)
    {
        var ids = dish.Ingredients.Select(x => x.FoodId!.Value).Distinct().ToArray();
        var foods = await db.Foods.Include(x => x.Nutrition).Include(x => x.Sources)
            .Where(x => ids.Contains(x.Id) && !x.IsDeleted).ToListAsync(ct);
        if (foods.Count != ids.Length || foods.Any(x => !x.IsApprovedForAi || !HasCoreNutrition(x)))
            return Results.Conflict(new { message = "Má»i nguyÃªn liá»‡u pháº£i cÃ³ Ä‘á»§ 4 chá»‰ tiÃªu cá»‘t lÃµi vÃ  Ä‘Æ°á»£c duyá»‡t AI trÆ°á»›c." });
    }
    var before = new { dish.IsApprovedForAi, dish.DietTagsJson, dish.AllergenIdsJson };
    dish.AllergenIdsJson = r.AllergenIds is null ? null : JsonSerializer.Serialize(r.AllergenIds.Select(NormalizePolicyToken).Where(x => x.Length > 0).Distinct());
    dish.DietTagsJson = r.DietTags is null ? null : JsonSerializer.Serialize(r.DietTags.Select(NormalizePolicyToken).Where(x => x.Length > 0).Distinct());
    dish.IsApprovedForAi = r.Approved;
    dish.UpdatedAtUtc = DateTime.UtcNow;
    db.AdminActionLogs.Add(Audit(UserId(p), "ReviewDishForAi", id, "", before, new { dish.IsApprovedForAi, dish.DietTagsJson, dish.AllergenIdsJson }));
    await db.SaveChangesAsync(ct);
    return Results.Ok(new { dish.Id, dish.IsApprovedForAi, dish.DietTagsJson, dish.AllergenIdsJson });
});
var adminFoods = app.MapGroup("/api/admin/foods").RequireAuthorization(p => p.RequireRole("Admin", "SuperAdmin"));
var adminFoodGroups = app.MapGroup("/api/admin/food-groups").RequireAuthorization(p => p.RequireRole("Admin", "SuperAdmin"));
var adminUsers = app.MapGroup("/api/admin/users").RequireAuthorization(p => p.RequireRole("Admin", "SuperAdmin"));
adminUsers.MapGet("", async (string? search, AppDbContext db, CancellationToken ct) =>
{
    var query = db.Users.AsNoTracking().Where(x => x.Role == "User" && !x.IsDeleted); if (!string.IsNullOrWhiteSpace(search)) query = query.Where(x => (x.Email != null && x.Email.Contains(search)) || (x.Phone != null && x.Phone.Contains(search)));
    return Results.Ok(await query.OrderByDescending(x => x.CreatedAtUtc).Select(x => new { x.Id, x.Username, x.Email, x.Phone, x.Role, x.IsActive, x.IsEmailVerified, x.IsPhoneVerified, x.CreatedAtUtc }).ToListAsync(ct));
});
adminUsers.MapGet("/trash", async (ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var query = db.Users.AsNoTracking().Where(x => x.Role == "User" && x.IsDeleted);
    if (!p.IsInRole("SuperAdmin")) { var actorId = UserId(p); query = query.Where(x => x.DeletedByUserId == actorId); }
    var rows = await query.OrderByDescending(x => x.DeletedAtUtc)
        .Select(x => new { x.Id, x.Username, x.Email, x.Phone, FullName = x.Profile == null ? null : x.Profile.FullName, x.CreatedAtUtc, x.DeletedAtUtc, x.DeletionReason, x.DeletedByUserId })
        .ToListAsync(ct);
    var actorIds = p.IsInRole("SuperAdmin") ? rows.Where(x => x.DeletedByUserId.HasValue).Select(x => x.DeletedByUserId!.Value).Distinct().ToArray() : [];
    var actors = await db.Users.AsNoTracking().Where(x => actorIds.Contains(x.Id))
        .Select(x => new { x.Id, x.Username, x.Email, FullName = x.Profile == null ? null : x.Profile.FullName })
        .ToDictionaryAsync(x => x.Id, ct);
    return Results.Ok(rows.Select(user => new
    {
        user.Id, user.Username, user.Email, user.Phone, user.FullName, user.CreatedAtUtc, user.DeletedAtUtc, user.DeletionReason,
        DeletedByName = p.IsInRole("SuperAdmin") && user.DeletedByUserId is Guid actorId && actors.TryGetValue(actorId, out var actor) ? actor.FullName ?? actor.Username ?? actor.Email : null,
        DeletedByEmail = p.IsInRole("SuperAdmin") && user.DeletedByUserId is Guid deletedById && actors.TryGetValue(deletedById, out var deleter) ? deleter.Email : null
    }));
});
adminUsers.MapGet("/{id:guid}", async (Guid id, AppDbContext db, CancellationToken ct) =>
{
    var user = await db.Users.AsNoTracking().Where(x => x.Id == id && x.Role == "User" && !x.IsDeleted).Select(x => new { x.Id, x.Username, x.Email, x.Phone, x.Role, x.IsActive, x.IsEmailVerified, x.IsPhoneVerified, x.CreatedAtUtc, Profile = x.Profile }).FirstOrDefaultAsync(ct);
    return user is null ? Results.NotFound() : Results.Ok(user);
});
adminUsers.MapPatch("/{id:guid}", async (Guid id, AdminUserUpdateRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var u = await db.Users.FirstOrDefaultAsync(x => x.Id == id && x.Role == "User" && !x.IsDeleted, ct); if (u is null) return Results.NotFound();
    if (r.Role != "User") return Results.BadRequest(new { message = "Admin không thể cấp hoặc thay đổi vai trò quản trị." });
    var before = new { u.Role, u.IsActive };
    u.IsActive = r.Active; u.TokenVersion++;
    foreach (var session in await db.RefreshSessions.Where(x => x.UserId == id && x.RevokedAtUtc == null).ToListAsync(ct)) session.RevokedAtUtc = DateTime.UtcNow;
    db.AdminActionLogs.Add(new AdminActionLog { AdminUserId = UserId(p), TargetUserId = id, Action = "UpdateUser", Reason = r.Reason ?? "", BeforeJson = System.Text.Json.JsonSerializer.Serialize(before), AfterJson = System.Text.Json.JsonSerializer.Serialize(new { u.Role, u.IsActive }) });
    await db.SaveChangesAsync(ct); return Results.NoContent();
});
adminUsers.MapDelete("/{id:guid}", async (Guid id, [Microsoft.AspNetCore.Mvc.FromBody] AdminDeleteUserRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    if (id == UserId(p)) return Results.Conflict(new { message = "Không thể tự xóa tài khoản Admin đang đăng nhập." });
    var u = await db.Users.FirstOrDefaultAsync(x => x.Id == id && x.Role == "User" && !x.IsDeleted, ct); if (u is null) return Results.NotFound();
    if (string.IsNullOrWhiteSpace(r.Reason)) return Results.BadRequest(new { message = "Cần ghi lý do xóa tài khoản." });
    await using var transaction = await db.Database.BeginTransactionAsync(ct);
    if (r.Reason.Trim().Length > 500) return Results.BadRequest(new { message = "Deletion reason must be 500 characters or fewer." });
    var before = new { u.Role, u.IsActive, u.IsDeleted };
    u.IsDeleted = true; u.IsActive = false; u.DeletedAtUtc = DateTime.UtcNow; u.DeletedByUserId = UserId(p); u.DeletionReason = r.Reason.Trim(); u.TokenVersion++;
    foreach (var session in await db.RefreshSessions.Where(x => x.UserId == id && x.RevokedAtUtc == null).ToListAsync(ct)) session.RevokedAtUtc = DateTime.UtcNow;
    db.AdminActionLogs.Add(new AdminActionLog { AdminUserId = UserId(p), TargetUserId = id, Action = "DeleteUser", Reason = r.Reason.Trim(), BeforeJson = System.Text.Json.JsonSerializer.Serialize(before), AfterJson = System.Text.Json.JsonSerializer.Serialize(new { u.Role, u.IsActive, u.IsDeleted, u.DeletedAtUtc }) });
    await db.SaveChangesAsync(ct); await transaction.CommitAsync(ct); return Results.NoContent();
});
adminUsers.MapPatch("/{id:guid}/active", async (Guid id, ActiveRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var u = await db.Users.FirstOrDefaultAsync(x => x.Id == id && x.Role == "User" && !x.IsDeleted, ct); if (u is null) return Results.NotFound(); if (!r.Active && string.IsNullOrWhiteSpace(r.Reason)) return Results.BadRequest(new { message = "Cần ghi lý do khóa tài khoản." }); var wasActive = u.IsActive; u.IsActive = r.Active; u.TokenVersion++;
    foreach (var session in await db.RefreshSessions.Where(x => x.UserId == id && x.RevokedAtUtc == null).ToListAsync(ct)) session.RevokedAtUtc = DateTime.UtcNow;
    db.AdminActionLogs.Add(new AdminActionLog { AdminUserId = UserId(p), TargetUserId = id, Action = r.Active ? "UnblockUser" : "BlockUser", Reason = r.Reason ?? "", BeforeJson = System.Text.Json.JsonSerializer.Serialize(new { IsActive = wasActive }), AfterJson = System.Text.Json.JsonSerializer.Serialize(new { u.IsActive }) }); await db.SaveChangesAsync(ct); return Results.NoContent();
});
var admin = app.MapGroup("/api/admin").RequireAuthorization(p => p.RequireRole("Admin"));
adminFoodGroups.MapGet("", async (AppDbContext db, CancellationToken ct) => Results.Ok(await db.FoodGroups.AsNoTracking().OrderBy(x => x.Name).Select(x => new { x.Id, x.Code, x.Name, FoodCount = x.Foods.Count(f => !f.IsDeleted) }).ToListAsync(ct)));
adminFoodGroups.MapPost("", async (FoodGroupRequest r, AppDbContext db, CancellationToken ct) =>
{
    var code = System.Text.RegularExpressions.Regex.Replace(r.Code.Trim().ToUpperInvariant(), @"[^A-Z0-9_]+", "_").Trim('_');
    var name = System.Text.RegularExpressions.Regex.Replace(r.Name.Trim(), @"\s+", " ");
    if (code.Length is 0 or > 40 || name.Length is 0 or > 100) return Results.BadRequest(new { message = "Mã nhóm và tên nhóm không hợp lệ." });
    if (await db.FoodGroups.AnyAsync(x => x.Code == code, ct)) return Results.Conflict(new { message = "Mã nhóm đã tồn tại." });
    var group = new FoodGroup { Code = code, Name = name }; db.FoodGroups.Add(group); await db.SaveChangesAsync(ct);
    return Results.Created($"/api/admin/food-groups/{group.Id}", new { group.Id, group.Code, group.Name, FoodCount = 0 });
});
adminFoodGroups.MapPut("/{id:guid}", async (Guid id, FoodGroupUpdateRequest r, AppDbContext db, CancellationToken ct) =>
{
    var group = await db.FoodGroups.FirstOrDefaultAsync(x => x.Id == id, ct); if (group is null) return Results.NotFound();
    var name = System.Text.RegularExpressions.Regex.Replace(r.Name.Trim(), @"\s+", " "); if (name.Length is 0 or > 100) return Results.BadRequest(new { message = "Tên nhóm không hợp lệ." });
    group.Name = name; await db.SaveChangesAsync(ct); return Results.NoContent();
});
adminFoodGroups.MapDelete("/{id:guid}", async (Guid id, AppDbContext db, CancellationToken ct) =>
{
    var group = await db.FoodGroups.Include(x => x.Foods).FirstOrDefaultAsync(x => x.Id == id, ct); if (group is null) return Results.NotFound();
    if (group.Foods.Count != 0) return Results.Conflict(new { message = "Không thể xóa nhóm còn thực phẩm. Hãy chuyển hoặc xóa thực phẩm trước." });
    db.FoodGroups.Remove(group); await db.SaveChangesAsync(ct); return Results.NoContent();
});
adminFoods.MapGet("/pending", async (AppDbContext db, CancellationToken ct) => Results.Ok(await LoadFoodsWithSources(db.Foods.AsNoTracking().Where(x => !x.IsDeleted && !x.IsVerified), db, ct, includeFoodGroup: true)));
adminFoods.MapGet("/verified", async (AppDbContext db, CancellationToken ct) => Results.Ok(await LoadFoodsWithSources(db.Foods.AsNoTracking().Where(x => !x.IsDeleted && x.IsVerified), db, ct, includeFoodGroup: true)));
adminFoods.MapGet("/trash", async (ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var query = db.Foods.AsNoTracking().Where(x => x.IsDeleted);
    if (!p.IsInRole("SuperAdmin")) { var actorId = UserId(p); query = query.Where(x => x.DeletedByUserId == actorId); }
    var foods = await LoadFoodsWithSources(query.OrderByDescending(x => x.DeletedAtUtc), db, ct, includeFoodGroup: true);
    var deleterIds = p.IsInRole("SuperAdmin")
        ? foods.Where(x => x.DeletedByUserId.HasValue).Select(x => x.DeletedByUserId!.Value).Distinct().ToArray()
        : [];
    var deleters = await db.Users.AsNoTracking().Where(x => deleterIds.Contains(x.Id))
        .Select(x => new { x.Id, x.Username, x.Email }).ToDictionaryAsync(x => x.Id, ct);
    foreach (var food in foods)
    {
        if (p.IsInRole("SuperAdmin") && food.DeletedByUserId is Guid userId && deleters.TryGetValue(userId, out var deleter))
        {
            food.DeletedByName = deleter.Username ?? deleter.Email;
            food.DeletedByEmail = deleter.Email;
        }
    }
    return Results.Ok(foods);
});
adminFoods.MapGet("/{id:guid}", async (Guid id, AppDbContext db, CancellationToken ct) =>
{
    var foods = await LoadFoodsWithSources(db.Foods.AsNoTracking().Where(x => x.Id == id && !x.IsDeleted), db, ct, includeFoodGroup: true, includeSourcesForAll: true);
    return foods.Count == 0 ? Results.NotFound() : Results.Ok(foods[0]);
});
adminFoods.MapGet("/{id:guid}/image", async (Guid id, AppDbContext db, IWebHostEnvironment env, HttpContext context, CancellationToken ct) =>
{
    var filename = await db.Foods.AsNoTracking().Where(x => x.Id == id).Select(x => x.ImagePath).FirstOrDefaultAsync(ct);
    if (filename is null) return Results.NotFound();
    var path = Path.Combine(env.ContentRootPath, "Uploads", "Foods", filename);
    if (!File.Exists(path)) return Results.NotFound();
    context.Response.Headers.CacheControl = "private, no-store";
    return Results.File(path, FoodImageContentType(filename));
});
adminFoods.MapPost("/{id:guid}/image", async (Guid id, HttpRequest request, AppDbContext db, IWebHostEnvironment env, CancellationToken ct) =>
{
    const int maxBytes = 5 * 1024 * 1024;
    if (request.ContentLength is > maxBytes) return Results.BadRequest(new { message = "Ảnh thực phẩm không được vượt quá 5 MB." });
    await using var memory = new MemoryStream();
    var buffer = new byte[64 * 1024];
    int read;
    while ((read = await request.Body.ReadAsync(buffer, ct)) > 0)
    {
        if (memory.Length + read > maxBytes) return Results.BadRequest(new { message = "Ảnh thực phẩm không được vượt quá 5 MB." });
        await memory.WriteAsync(buffer.AsMemory(0, read), ct);
    }
    var bytes = memory.ToArray();
    var extension = FoodImageExtension(bytes);
    if (extension is null) return Results.BadRequest(new { message = "Chỉ hỗ trợ ảnh JPEG, PNG hoặc WebP hợp lệ." });
    var food = await db.Foods.FirstOrDefaultAsync(x => x.Id == id && !x.IsDeleted, ct);
    if (food is null) return Results.NotFound();
    var directory = Path.Combine(env.ContentRootPath, "Uploads", "Foods");
    Directory.CreateDirectory(directory);
    var filename = $"{id:N}_{Guid.NewGuid():N}{extension}";
    var newPath = Path.Combine(directory, filename);
    var previous = food.ImagePath;
    await File.WriteAllBytesAsync(newPath, bytes, ct);
    try
    {
        food.ImagePath = filename;
        await db.SaveChangesAsync(ct);
    }
    catch
    {
        File.Delete(newPath);
        throw;
    }
    if (previous is not null)
    {
        var oldPath = Path.Combine(directory, previous);
        if (File.Exists(oldPath)) File.Delete(oldPath);
    }
    return Results.Ok(new { imageUrl = $"/api/foods/{id}/image?v={Guid.NewGuid():N}" });
});
adminFoods.MapDelete("/{id:guid}/image", async (Guid id, AppDbContext db, IWebHostEnvironment env, CancellationToken ct) =>
{
    var food = await db.Foods.FirstOrDefaultAsync(x => x.Id == id && !x.IsDeleted, ct);
    if (food is null) return Results.NotFound();
    var filename = food.ImagePath;
    if (filename is null) return Results.NoContent();
    food.ImagePath = null;
    await db.SaveChangesAsync(ct);
    var path = Path.Combine(env.ContentRootPath, "Uploads", "Foods", filename);
    if (File.Exists(path)) File.Delete(path);
    return Results.NoContent();
});
adminFoods.MapPost("", async (FoodWriteRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    if (string.IsNullOrWhiteSpace(r.Name) || r.Name.Length > 160 || r.BasisGrams <= 0 || r.Values.Count != 8 || r.Values.Any(v => v < 0) || (!r.IsDraft && r.Values.Take(4).Any(v => v is null))) return Results.BadRequest(new { message = "T\u00ean, kh\u1ed1i l\u01b0\u1ee3ng c\u01a1 s\u1edf ho\u1eb7c 8 ch\u1ec9 ti\u00eau dinh d\u01b0\u1ee1ng kh\u00f4ng h\u1ee3p l\u1ec7; c\u1ea7n nh\u1eadp \u0111\u1ee7 4 ch\u1ec9 ti\u00eau \u0111\u1ea7u khi l\u01b0u c\u00f4ng b\u1ed1." });
    if (r.GroupId is Guid groupId && !await db.FoodGroups.AnyAsync(x => x.Id == groupId, ct)) return Results.BadRequest(new { message = "Nhóm thực phẩm không tồn tại." });
    var food = new Food { Name = r.Name.Trim(), FoodGroupId = r.GroupId, Basis = $"{r.BasisGrams.ToString("0.###", CultureInfo.InvariantCulture)} g phần ăn được", VerifiedByUserId = UserId(p) };
    var nutrition = new FoodNutrition { Food = food };
    var props = NutritionFieldNames().Select(x => typeof(FoodNutrition).GetProperty(x)!).ToArray();
    for (var i = 0; i < props.Length; i++) props[i].SetValue(nutrition, r.Values[i]);
    food.Nutrition = nutrition;
    foreach (var src in r.Sources.Where(s => (!string.IsNullOrWhiteSpace(s.Citation) || !string.IsNullOrWhiteSpace(s.Url)) && !string.IsNullOrWhiteSpace(s.FieldName))) food.Sources.Add(new NutritionSource { FieldName = src.FieldName.Trim(), Citation = src.Citation?.Trim() ?? "", Url = src.Url?.Trim() ?? "", IsChecked = false });
    db.Foods.Add(food); db.AdminActionLogs.Add(Audit(UserId(p), "CreateFood", food.Id, "", null, new { food.Name, food.Basis, food.IsVerified, Sources = food.Sources.Select(x => new { x.FieldName, x.Citation, x.Url }) })); await db.SaveChangesAsync(ct); return Results.Created($"/api/admin/foods/{food.Id}", food);
});
adminFoods.MapPut("/{id:guid}", async (Guid id, FoodWriteRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    if (string.IsNullOrWhiteSpace(r.Name) || r.Name.Length > 160 || r.BasisGrams <= 0 || r.Values.Count != 8 || r.Values.Any(v => v < 0) || (!r.IsDraft && r.Values.Take(4).Any(v => v is null))) return Results.BadRequest(new { message = "T\u00ean, kh\u1ed1i l\u01b0\u1ee3ng c\u01a1 s\u1edf ho\u1eb7c 8 ch\u1ec9 ti\u00eau dinh d\u01b0\u1ee1ng kh\u00f4ng h\u1ee3p l\u1ec7; c\u1ea7n nh\u1eadp \u0111\u1ee7 4 ch\u1ec9 ti\u00eau \u0111\u1ea7u khi l\u01b0u c\u00f4ng b\u1ed1." });
    if (r.GroupId is Guid groupId && !await db.FoodGroups.AnyAsync(x => x.Id == groupId, ct)) return Results.BadRequest(new { message = "Nhóm thực phẩm không tồn tại." });
    var food = await db.Foods.Include(x => x.Nutrition).Include(x => x.Sources).FirstOrDefaultAsync(x => x.Id == id, ct); if (food is null) return Results.NotFound();
    var before = new { food.Name, food.Basis, food.FoodGroupId, food.IsVerified, food.VerifiedAtUtc, Sources = food.Sources.Select(x => new { x.FieldName, x.Citation, x.Url }).ToList() }; food.Name = r.Name.Trim(); food.FoodGroupId = r.GroupId; food.Basis = $"{r.BasisGrams.ToString("0.###", CultureInfo.InvariantCulture)} g phần ăn được"; food.IsVerified = false; food.VerifiedAtUtc = null; food.VerifiedByUserId = null;
    food.Nutrition ??= new FoodNutrition { FoodId = id };
    var props = NutritionFieldNames().Select(x => typeof(FoodNutrition).GetProperty(x)!).ToArray();
    for (var i = 0; i < props.Length; i++) props[i].SetValue(food.Nutrition, r.Values[i]);
    db.NutritionSources.RemoveRange(food.Sources);
    food.Sources.Clear();
    foreach (var src in r.Sources.Where(s => (!string.IsNullOrWhiteSpace(s.Citation) || !string.IsNullOrWhiteSpace(s.Url)) && !string.IsNullOrWhiteSpace(s.FieldName))) food.Sources.Add(new NutritionSource { FieldName = src.FieldName.Trim(), Citation = src.Citation?.Trim() ?? "", Url = src.Url?.Trim() ?? "", IsChecked = false });
    db.AdminActionLogs.Add(Audit(UserId(p), "UpdateFood", id, "", before, new { food.Name, food.Basis, food.IsVerified, food.VerifiedAtUtc, Sources = food.Sources.Select(x => new { x.FieldName, x.Citation, x.Url }) })); await db.SaveChangesAsync(ct); return Results.Ok(new { food.Id, food.Name, food.IsVerified });
});
adminFoods.MapDelete("/{id:guid}", async (Guid id, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var food = await db.Foods.FirstOrDefaultAsync(x => x.Id == id && !x.IsDeleted, ct);
    if (food is null) return Results.NotFound();
    var before = new { food.Name, food.IsVerified, food.HasImage, food.FoodGroupId };
    food.IsDeleted = true;
    food.DeletedAtUtc = DateTime.UtcNow;
    food.DeletedByUserId = UserId(p);
    food.DeletedByRole = p.IsInRole("SuperAdmin") ? "SuperAdmin" : "Admin";
    db.AdminActionLogs.Add(Audit(UserId(p), "MoveFoodToTrash", id, "", before, new { food.IsDeleted, food.DeletedAtUtc, food.DeletedByRole }));
    await db.SaveChangesAsync(ct);
    return Results.NoContent();
});
adminFoods.MapPost("/{id:guid}/restore", async (Guid id, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    if (!p.IsInRole("SuperAdmin")) return Results.Forbid();
    var food = await db.Foods.FirstOrDefaultAsync(x => x.Id == id && x.IsDeleted, ct);
    if (food is null) return Results.NotFound();
    if (await db.Foods.AnyAsync(x => x.Id != id && !x.IsDeleted && x.Name == food.Name, ct))
        return Results.Conflict(new { message = "Da co thuc pham cung ten. Hay doi ten thuc pham hien hanh truoc khi khoi phuc." });
    food.IsDeleted = false;
    food.DeletedAtUtc = null;
    food.DeletedByUserId = null;
    food.DeletedByRole = null;
    db.AdminActionLogs.Add(Audit(UserId(p), "RestoreFood", id, "", new { IsDeleted = true }, new { IsDeleted = false }));
    await db.SaveChangesAsync(ct);
    return Results.NoContent();
}).RequireAuthorization(policy => policy.RequireRole("SuperAdmin"));
adminFoods.MapDelete("/{id:guid}/permanent", async (Guid id, ClaimsPrincipal p, AppDbContext db, IWebHostEnvironment env, CancellationToken ct) =>
{
    var food = await db.Foods.Include(x => x.Sources).FirstOrDefaultAsync(x => x.Id == id && x.IsDeleted, ct);
    if (food is null) return Results.NotFound();
    var filename = food.ImagePath;
    var before = new { food.Name, food.IsVerified, food.FoodGroupId, HasImage = filename is not null, food.DeletedAtUtc, food.DeletedByRole, Sources = food.Sources.Select(x => new { x.FieldName, x.Citation, x.Url }).ToList() };
    db.Foods.Remove(food);
    db.AdminActionLogs.Add(Audit(UserId(p), "PermanentlyDeleteFood", id, "", before, null));
    await db.SaveChangesAsync(ct);
    if (filename is not null)
    {
        var path = Path.Combine(env.ContentRootPath, "Uploads", "Foods", filename);
        if (File.Exists(path)) File.Delete(path);
    }
    return Results.NoContent();
}).RequireAuthorization(policy => policy.RequireRole("SuperAdmin"));
adminFoods.MapPatch("/{id:guid}/sources/{sourceId:guid}", async (Guid id, Guid sourceId, SourceCheckRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var source = await db.NutritionSources.FirstOrDefaultAsync(x => x.Id == sourceId && x.FoodId == id && !db.Foods.Any(f => f.Id == id && f.IsDeleted), ct);
    if (source is null) return Results.NotFound();
    var previous = new { source.IsChecked, source.Citation, source.Url }; source.IsChecked = r.Checked && (!string.IsNullOrWhiteSpace(source.Citation) || !string.IsNullOrWhiteSpace(source.Url)) && Uri.TryCreate(source.Url, UriKind.Absolute, out _);
    source.CheckedAtUtc = source.IsChecked ? DateTime.UtcNow : null;
    var food = await db.Foods.Include(x => x.Nutrition).Include(x => x.Sources).FirstAsync(x => x.Id == id, ct);
    food.IsVerified = false; food.VerifiedAtUtc = null; food.VerifiedByUserId = null;
    db.AdminActionLogs.Add(Audit(UserId(p), "CheckFoodSource", id, "", previous, new { source.IsChecked, source.Citation, source.Url })); await db.SaveChangesAsync(ct);
    return Results.Ok(new { source.IsChecked, source.CheckedAtUtc });
});
adminFoods.MapPost("/{id:guid}/verify", async (Guid id, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var food = await db.Foods.Include(x => x.Nutrition).Include(x => x.Sources).FirstOrDefaultAsync(x => x.Id == id && !x.IsDeleted, ct);
    if (food is null) return Results.NotFound();
    if (food.Nutrition is null) return Results.Conflict(new { message = "Chưa có dữ liệu dinh dưỡng cho thực phẩm này." });
    var fields = NutritionFieldNames().Select(x => typeof(FoodNutrition).GetProperty(x)!).ToArray();
    var sourcedFields = food.Sources.Where(x => x.IsChecked && Uri.TryCreate(x.Url, UriKind.Absolute, out _)).Select(x => x.FieldName).ToHashSet(StringComparer.Ordinal);
    if (HasCoreNutrition(food))
        return Results.Conflict(new { message = "\u0110\u00e3 \u0111\u1ee7 4 ch\u1ec9 ti\u00eau \u0111\u1ea7u; kh\u00f4ng c\u1ea7n x\u00e1c minh \u0111\u1ec3 hi\u1ec3n th\u1ecb." });
    var suppliedFields = fields.Select(field => new { field.Name, Value = (decimal?)field.GetValue(food.Nutrition) })
        .Where(entry => entry.Value is not null).ToArray();
    var invalidValues = suppliedFields.Any(entry => entry.Value!.Value < 0 || !sourcedFields.Contains(entry.Name));
    if (suppliedFields.Length == 0 || invalidValues)
        return Results.Conflict(new { message = "Khi thi\u1ebfu 4 ch\u1ec9 ti\u00eau \u0111\u1ea7u, h\u00e3y ki\u1ec3m tra ngu\u1ed3n cho t\u1eebng ch\u1ec9 ti\u00eau \u0111\u00e3 nh\u1eadp tr\u01b0\u1edbc khi x\u00e1c minh." });
    var before = new { food.IsVerified, food.VerifiedAtUtc };
    food.IsVerified = true; food.VerifiedAtUtc = DateTime.UtcNow; food.VerifiedByUserId = UserId(p);
    db.AdminActionLogs.Add(Audit(UserId(p), "VerifyFood", id, "", before, new { food.IsVerified, food.VerifiedAtUtc }));
    await db.SaveChangesAsync(ct); return Results.Ok(new { food.Id, food.IsVerified, food.VerifiedAtUtc });
});
adminFoods.MapPut("/{id:guid}/ai-review", async (Guid id, FoodAiReviewRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var food = await db.Foods.Include(x => x.Nutrition).Include(x => x.Sources)
        .FirstOrDefaultAsync(x => x.Id == id && !x.IsDeleted, ct);
    if (food is null) return Results.NotFound();
    if (r.Approved && r.AllergenIds is null)
        return Results.BadRequest(new { message = "Äá»ƒ duyá»‡t AI, cáº§n xÃ¡c nháº­n danh sÃ¡ch dá»‹ á»©ng (cÃ³ thá»ƒ lÃ  danh sÃ¡ch trá»‘ng)." });
    if (r.Approved && !HasCoreNutrition(food))
        return Results.Conflict(new { message = "Cáº§n cÃ³ Ä‘á»§ 4 chá»‰ tiÃªu cá»‘t lÃµi trÆ°á»›c khi duyá»‡t AI." });
    var before = new { food.IsApprovedForAi, food.AllergenIdsJson };
    food.AllergenIdsJson = r.AllergenIds is null ? null : JsonSerializer.Serialize(r.AllergenIds.Select(NormalizePolicyToken).Where(x => x.Length > 0).Distinct());
    food.IsApprovedForAi = r.Approved;
    db.AdminActionLogs.Add(Audit(UserId(p), "ReviewFoodForAi", id, "", before, new { food.IsApprovedForAi, food.AllergenIdsJson }));
    await db.SaveChangesAsync(ct);
    return Results.Ok(new { food.Id, food.IsVerified, food.IsApprovedForAi, food.AllergenIdsJson });
});
admin.MapGet("/ratings", async (DateTime? fromUtc, DateTime? toUtc, AppDbContext db, CancellationToken ct) =>
{
    var query = db.Ratings.AsNoTracking().AsQueryable(); if (fromUtc is not null) query = query.Where(x => x.UpdatedAtUtc >= fromUtc); if (toUtc is not null) query = query.Where(x => x.UpdatedAtUtc <= toUtc);
    return Results.Ok(await query.Join(db.Dishes.AsNoTracking(), r => r.DishId, d => d.Id, (r,d) => new { r.UserId, r.DishId, d.Name, r.Stars, r.Comment, r.UpdatedAtUtc }).OrderByDescending(x => x.UpdatedAtUtc).ToListAsync(ct));
});
admin.MapDelete("/ratings/{userId:guid}/{dishId:guid}", async (Guid userId, Guid dishId, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var rating = await db.Ratings.FirstOrDefaultAsync(x => x.UserId == userId && x.DishId == dishId, ct); if (rating is null) return Results.NotFound(); var before = new { rating.Stars, rating.Comment }; db.Ratings.Remove(rating); db.AdminActionLogs.Add(Audit(UserId(p), "DeleteRating", userId, "", before, null)); await db.SaveChangesAsync(ct); return Results.NoContent();
});
admin.MapGet("/statistics/favorites", async (DateTime? fromUtc, DateTime? toUtc, AppDbContext db, CancellationToken ct) =>
{
    var query = db.Favorites.AsNoTracking().AsQueryable(); if (fromUtc is not null) query = query.Where(x => x.CreatedAtUtc >= fromUtc); if (toUtc is not null) query = query.Where(x => x.CreatedAtUtc <= toUtc);
    return Results.Ok(await query.GroupBy(x => x.DishId).Select(g => new { DishId = g.Key, FavoriteCount = g.Count() }).Join(db.Dishes.AsNoTracking(), x => x.DishId, d => d.Id, (x,d) => new { d.Name, x.FavoriteCount }).OrderByDescending(x => x.FavoriteCount).ToListAsync(ct));
});

var superadmin = app.MapGroup("/api/superadmin").RequireAuthorization(p => p.RequireRole("SuperAdmin"));
superadmin.MapGet("/users/trash", async (AppDbContext db, CancellationToken ct) =>
{
    var users = await db.Users.AsNoTracking().Where(x => x.Role == "User" && x.IsDeleted)
        .OrderByDescending(x => x.DeletedAtUtc)
        .Select(x => new { x.Id, x.Username, x.Email, x.Phone, FullName = x.Profile == null ? null : x.Profile.FullName, x.CreatedAtUtc, x.DeletedAtUtc, x.DeletionReason, x.DeletedByUserId })
        .ToListAsync(ct);
    var actorIds = users.Where(x => x.DeletedByUserId.HasValue).Select(x => x.DeletedByUserId!.Value).Distinct().ToArray();
    var actors = await db.Users.AsNoTracking().Where(x => actorIds.Contains(x.Id))
        .Select(x => new { x.Id, x.Username, x.Email, FullName = x.Profile == null ? null : x.Profile.FullName })
        .ToDictionaryAsync(x => x.Id, ct);
    return Results.Ok(users.Select(user => new
    {
        user.Id, user.Username, user.Email, user.Phone, user.FullName, user.CreatedAtUtc, user.DeletedAtUtc, user.DeletionReason,
        DeletedByName = user.DeletedByUserId is Guid actorId && actors.TryGetValue(actorId, out var actor) ? actor.FullName ?? actor.Username ?? actor.Email : null,
        DeletedByEmail = user.DeletedByUserId is Guid deletedById && actors.TryGetValue(deletedById, out var deleter) ? deleter.Email : null
    }));
});
superadmin.MapPost("/users/{id:guid}/restore", async (Guid id, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var user = await db.Users.FirstOrDefaultAsync(x => x.Id == id && x.Role == "User" && x.IsDeleted, ct);
    if (user is null) return Results.NotFound();
    if (await db.Users.AnyAsync(x => x.Id != id && !x.IsDeleted && (user.Email != null && x.Email == user.Email || user.Phone != null && x.Phone == user.Phone || user.Username != null && x.Username == user.Username), ct))
        return Results.Conflict(new { message = "A current account already uses this user's email, phone, or username." });
    user.IsDeleted = false; user.IsActive = false; user.DeletedAtUtc = null; user.DeletedByUserId = null; user.DeletionReason = null; user.TokenVersion++;
    db.AdminActionLogs.Add(Audit(UserId(p), "RestoreUser", id, "Restored user account from trash as inactive.", new { IsDeleted = true }, new { IsDeleted = false, user.IsActive }));
    await db.SaveChangesAsync(ct);
    return Results.NoContent();
});
superadmin.MapGet("/overview", async (AppDbContext db, CancellationToken ct) =>
{
    var admins = db.Users.AsNoTracking().Where(x => x.Role == "Admin" && !x.IsDeleted);
    return Results.Ok(new { totalAdmins = await admins.CountAsync(ct), activeAdmins = await admins.CountAsync(x => x.IsActive, ct), lockedAdmins = await admins.CountAsync(x => !x.IsActive, ct) });
});
superadmin.MapGet("/admins", async (string? search, string? status, int? page, int? pageSize, AppDbContext db, CancellationToken ct) =>
{
    var p = Math.Max(1, page ?? 1); var size = Math.Clamp(pageSize ?? 20, 1, 100);
    var query = db.Users.AsNoTracking().Where(x => x.Role == "Admin");
    query = status?.ToLowerInvariant() switch { "active" => query.Where(x => !x.IsDeleted && x.IsActive), "locked" => query.Where(x => !x.IsDeleted && !x.IsActive), "deleted" => query.Where(x => x.IsDeleted), "all" => query, _ => query.Where(x => !x.IsDeleted) };
    if (!string.IsNullOrWhiteSpace(search)) { var term = search.Trim(); query = query.Where(x => (x.Username != null && x.Username.Contains(term)) || (x.Email != null && x.Email.Contains(term)) || (x.Phone != null && x.Phone.Contains(term)) || (x.Profile != null && x.Profile.FullName != null && x.Profile.FullName.Contains(term))); }
    var total = await query.CountAsync(ct);
    var items = await query.OrderByDescending(x => x.CreatedAtUtc).Skip((p - 1) * size).Take(size)
        .Select(x => new SuperAdminListItem(x.Id, x.Profile == null ? null : x.Profile.FullName, x.Username, x.Email, x.Phone, x.IsEmailVerified, x.IsPhoneVerified, x.IsActive, x.IsDeleted, x.CreatedAtUtc))
        .ToListAsync(ct);
    return Results.Ok(new { items, total, page = p, pageSize = size });
});
superadmin.MapGet("/admins/{id:guid}", async (Guid id, AppDbContext db, CancellationToken ct) =>
{
    var item = await db.Users.AsNoTracking().Where(x => x.Id == id && x.Role == "Admin")
        .Select(x => new { x.Id, FullName = x.Profile == null ? null : x.Profile.FullName, x.Username, x.Email, x.Phone, x.IsEmailVerified, x.IsPhoneVerified, x.IsActive, x.IsDeleted, x.MustChangePassword, x.CreatedAtUtc, x.DeletedAtUtc, x.DeletionReason })
        .FirstOrDefaultAsync(ct);
    return item is null ? Results.NotFound() : Results.Ok(item);
});
superadmin.MapPost("/admins", async (SuperAdminCreateAdminRequest r, ClaimsPrincipal p, AppDbContext db, IPasswordHasher<AppUser> hasher, CancellationToken ct) =>
{
    var email = NormalizeEmail(r.Email); var phone = NormalizePhone(r.Phone);
    if (email is null || string.IsNullOrWhiteSpace(r.FullName) || r.FullName.Trim().Length > 120 || r.Phone is not null && phone is null || !PasswordPolicy.IsValid(r.Password))
        return Results.BadRequest(new { message = "Kiểm tra họ tên, email, số điện thoại và chính sách mật khẩu." });
    if (await db.Users.AnyAsync(x => !x.IsDeleted && (x.Email == email || phone != null && x.Phone == phone), ct)) return Results.Conflict(new { message = "Email hoặc số điện thoại đã được sử dụng." });
    var user = new AppUser { Email = email, Phone = phone, Role = "Admin", IsActive = r.Active, IsEmailVerified = false, IsPhoneVerified = false, MustChangePassword = false };
    user.PasswordHash = hasher.HashPassword(user, r.Password);
    db.Users.Add(user); db.Profiles.Add(new UserProfile { UserId = user.Id, FullName = r.FullName.Trim() });
    db.AdminActionLogs.Add(Audit(UserId(p), "CreateAdmin", user.Id, "Tạo tài khoản Admin.", null, new { user.Email, user.Phone, user.IsActive, user.IsEmailVerified, user.IsPhoneVerified, user.MustChangePassword }));
    await db.SaveChangesAsync(ct);
    return Results.Created($"/api/superadmin/admins/{user.Id}", new { user.Id, FullName = r.FullName.Trim(), user.Email, user.Phone, user.IsEmailVerified, user.IsPhoneVerified, user.IsActive, user.CreatedAtUtc, user.MustChangePassword });
});
superadmin.MapPatch("/admins/{id:guid}", async (Guid id, SuperAdminEditAdminRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var user = await db.Users.Include(x => x.Profile).FirstOrDefaultAsync(x => x.Id == id && x.Role == "Admin" && !x.IsDeleted, ct);
    if (user is null) return Results.NotFound();
    if (string.IsNullOrWhiteSpace(r.FullName) || r.FullName.Trim().Length > 120) return Results.BadRequest(new { message = "Họ tên không hợp lệ." });
    var before = AdminSnapshot(user);
    user.Profile ??= new UserProfile { UserId = user.Id };
    user.Profile.FullName = r.FullName.Trim();
    db.AdminActionLogs.Add(Audit(UserId(p), "UpdateAdmin", id, r.Reason ?? "", before, AdminSnapshot(user)));
    await db.SaveChangesAsync(ct);
    return Results.NoContent();
});
superadmin.MapPatch("/admins/{id:guid}/active", async (Guid id, SuperAdminActiveRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var user = await db.Users.FirstOrDefaultAsync(x => x.Id == id && x.Role == "Admin" && !x.IsDeleted, ct);
    if (user is null) return Results.NotFound();
    if (!r.Active && string.IsNullOrWhiteSpace(r.Reason)) return Results.BadRequest(new { message = "Cần nêu lý do khóa Admin." });
    var before = new { user.IsActive }; user.IsActive = r.Active; user.TokenVersion++;
    await RevokeSessions(db, id, ct);
    db.AdminActionLogs.Add(Audit(UserId(p), r.Active ? "UnlockAdmin" : "LockAdmin", id, r.Reason ?? "", before, new { user.IsActive }));
    await db.SaveChangesAsync(ct);
    return Results.NoContent();
});
superadmin.MapPost("/admins/{id:guid}/delete", async (Guid id, SuperAdminReasonRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var user = await db.Users.FirstOrDefaultAsync(x => x.Id == id && x.Role == "Admin" && !x.IsDeleted, ct);
    if (user is null) return Results.NotFound();
    if (string.IsNullOrWhiteSpace(r.Reason)) return Results.BadRequest(new { message = "Cần nêu lý do xóa mềm Admin." });
    var before = AdminSnapshot(user);
    user.IsDeleted = true; user.IsActive = false; user.DeletedAtUtc = DateTime.UtcNow; user.DeletedByUserId = UserId(p); user.DeletionReason = r.Reason.Trim(); user.TokenVersion++;
    await RevokeSessions(db, id, ct);
    db.AdminActionLogs.Add(Audit(UserId(p), "SoftDeleteAdmin", id, r.Reason.Trim(), before, AdminSnapshot(user)));
    await db.SaveChangesAsync(ct);
    return Results.NoContent();
});
superadmin.MapPost("/admins/{id:guid}/restore", async (Guid id, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var user = await db.Users.FirstOrDefaultAsync(x => x.Id == id && x.Role == "Admin" && x.IsDeleted, ct);
    if (user is null) return Results.NotFound();
    var conflict = await db.Users.AnyAsync(x => x.Id != id && !x.IsDeleted && ((user.Username != null && x.Username == user.Username) || (user.Email != null && x.Email == user.Email) || (user.Phone != null && x.Phone == user.Phone)), ct);
    if (conflict) return Results.Conflict(new { message = "Không thể khôi phục: username hoặc thông tin liên hệ đã được tài khoản khác sử dụng." });
    var before = AdminSnapshot(user);
    user.IsDeleted = false; user.IsActive = true; user.DeletedAtUtc = null; user.DeletedByUserId = null; user.DeletionReason = null; user.TokenVersion++;
    await RevokeSessions(db, id, ct);
    db.AdminActionLogs.Add(Audit(UserId(p), "RestoreAdmin", id, "Khôi phục tài khoản Admin; yêu cầu đăng nhập mới.", before, AdminSnapshot(user)));
    await db.SaveChangesAsync(ct);
    return Results.NoContent();
});
superadmin.MapPost("/admins/{id:guid}/email/request", async (Guid id, SuperAdminEmailRequest r, ClaimsPrincipal p, AppDbContext db, IOtpSender sender, CancellationToken ct) =>
{
    var user = await db.Users.FirstOrDefaultAsync(x => x.Id == id && x.Role == "Admin" && !x.IsDeleted, ct);
    if (user is null) return Results.NotFound();
    var email = NormalizeEmail(r.Email); if (email is null) return Results.BadRequest(new { message = "Email không hợp lệ." });
    if (await db.Users.AnyAsync(x => x.Id != id && !x.IsDeleted && x.Email == email, ct)) return Results.Conflict(new { message = "Email đã được tài khoản khác sử dụng." });
    var previous = await db.OtpChallenges.Where(x => x.UserId == id && x.Purpose == "SuperAdminContact" && x.ConsumedAtUtc == null).OrderByDescending(x => x.CreatedAtUtc).FirstOrDefaultAsync(ct);
    var now = DateTime.UtcNow;
    if (previous is not null && previous.CreatedAtUtc.AddSeconds(60) > now) return Results.Problem("Vui lòng đợi mã hiện tại hết hạn rồi thử lại.", statusCode: 429);
    if (previous is not null) previous.ConsumedAtUtc = now;
    var (challenge, code) = OtpCodes.Create(id, email, "SuperAdminContact", now); db.OtpChallenges.Add(challenge); await db.SaveChangesAsync(ct);
    try { await sender.SendAsync(email, "ContactChange", code, ct); }
    catch (InvalidOperationException e) { db.OtpChallenges.Remove(challenge); await db.SaveChangesAsync(ct); return Results.Problem(e.Message, statusCode: 503); }
    db.AdminActionLogs.Add(Audit(UserId(p), "RequestAdminEmailChange", id, "Gửi OTP tới email mới.", null, new { Email = email })); await db.SaveChangesAsync(ct);
    return Results.Ok(new { message = "Đã gửi mã tới email mới.", expiresInSeconds = 60 });
});
superadmin.MapPost("/admins/{id:guid}/email/confirm", async (Guid id, SuperAdminEmailOtpRequest r, ClaimsPrincipal p, AppDbContext db, CancellationToken ct) =>
{
    var user = await db.Users.Include(x => x.Profile).FirstOrDefaultAsync(x => x.Id == id && x.Role == "Admin" && !x.IsDeleted, ct);
    if (user is null) return Results.NotFound();
    var email = NormalizeEmail(r.Email); if (email is null) return Results.BadRequest(new { message = "Email không hợp lệ." });
    var challenge = await db.OtpChallenges.Where(x => x.UserId == id && x.Destination == email && x.Purpose == "SuperAdminContact" && x.ConsumedAtUtc == null).OrderByDescending(x => x.CreatedAtUtc).FirstOrDefaultAsync(ct);
    if (!OtpCodes.Verify(challenge, r.Code)) { await db.SaveChangesAsync(ct); return Results.BadRequest(new { message = "Mã không đúng, đã hết hạn hoặc đã dùng." }); }
    if (await db.Users.AnyAsync(x => x.Id != id && !x.IsDeleted && x.Email == email, ct)) return Results.Conflict(new { message = "Email đã được tài khoản khác sử dụng." });
    var before = AdminSnapshot(user); user.Email = email; user.IsEmailVerified = true; user.TokenVersion++;
    challenge!.ConsumedAtUtc = DateTime.UtcNow; await RevokeSessions(db, id, ct);
    db.AdminActionLogs.Add(Audit(UserId(p), "ConfirmAdminEmailChange", id, "Email mới đã xác minh bằng OTP.", before, AdminSnapshot(user)));
    await db.SaveChangesAsync(ct);
    return Results.Ok(new { message = "Email Admin đã được xác minh và cập nhật. Các phiên cũ đã bị thu hồi." });
});
superadmin.MapGet("/audit-logs", async (Guid? actorId, string? actor, DateTime? fromUtc, DateTime? toUtc, string? action, string? outcome, int? page, int? pageSize, AppDbContext db, CancellationToken ct) =>
{
    var p = Math.Max(1, page ?? 1); var size = Math.Clamp(pageSize ?? 25, 1, 100);
    var query = db.AdminActionLogs.AsNoTracking().AsQueryable();
    if (actorId is not null) query = query.Where(x => x.AdminUserId == actorId);
    if (!string.IsNullOrWhiteSpace(actor))
    {
        var term = actor.Trim();
        query = query.Where(x => db.Users.Any(u => u.Id == x.AdminUserId &&
            ((u.Username != null && u.Username.Contains(term)) ||
             (u.Email != null && u.Email.Contains(term)) ||
             (u.Profile != null && u.Profile.FullName != null && u.Profile.FullName.Contains(term)))));
    }
    if (fromUtc is not null) query = query.Where(x => x.CreatedAtUtc >= fromUtc);
    if (toUtc is not null) query = query.Where(x => x.CreatedAtUtc <= toUtc);
    if (!string.IsNullOrWhiteSpace(action)) query = query.Where(x => x.Action.Contains(action));
    if (!string.IsNullOrWhiteSpace(outcome)) query = query.Where(x => x.Outcome == outcome);
    var total = await query.CountAsync(ct); var rows = await query.OrderByDescending(x => x.CreatedAtUtc).Skip((p - 1) * size).Take(size).ToListAsync(ct);
    return Results.Ok(new { items = await FormatAuditLogs(db, rows, ct), total, page = p, pageSize = size });
});

app.Run();

static string? NormalizeEmail(string? e) => string.IsNullOrWhiteSpace(e) || e.Length > 320 ? null : e.Trim().ToLowerInvariant();
static string? NormalizeUsername(string? username)
{
    if (string.IsNullOrWhiteSpace(username)) return null;
    var value = username.Trim().ToLowerInvariant();
    return System.Text.RegularExpressions.Regex.IsMatch(value, "^[a-z0-9_]{3,32}$") ? value : null;
}
static string? NormalizePhone(string? phone)
{
    if (string.IsNullOrWhiteSpace(phone)) return null;
    var trimmed = phone.Trim(); var hasPlus = trimmed.StartsWith('+');
    var digits = new string(trimmed.Where(char.IsDigit).ToArray());
    if (digits.Length is < 7 or > 15) return null;
    return (hasPlus ? "+" : "") + digits;
}
static string MealName(int index, int total) => total switch
{
    1 => "Bữa chính",
    3 => index switch { 1 => "Sáng", 2 => "Trưa", _ => "Tối" },
    4 => index switch { 1 => "Sáng", 2 => "Trưa", 3 => "Chiều", _ => "Tối" },
    5 => index switch { 1 => "Sáng", 2 => "Phụ sáng", 3 => "Trưa", 4 => "Phụ chiều", _ => "Tối" },
    _ => $"Bữa {index}",
};
static IOrderedQueryable<UserGoal> EffectiveGoals(AppDbContext db, Guid userId, DateOnly date) =>
    db.UserGoals.Include(x => x.Meals)
        .Where(x => x.UserId == userId && x.EffectiveStartDate <= date)
        .OrderByDescending(x => x.EffectiveStartDate)
        .ThenByDescending(x => x.CreatedAtUtc);
static List<GoalMealAllocation> BuildMealAllocations(UserGoal goal)
{
    var ratios = DailyEnergyEstimator.MealAllocationRatios(goal.MealsPerDay);
    return Enumerable.Range(1, goal.MealsPerDay).Select(index => new GoalMealAllocation
    {
        UserGoalId = goal.Id,
        MealName = MealName(index, goal.MealsPerDay),
        SortOrder = index,
        AllocationRatio = ratios[index - 1],
    }).ToList();
}
static decimal? ReadJsonDecimal(JsonElement element, string property)
{
    return element.ValueKind == JsonValueKind.Object && element.TryGetProperty(property, out var value) &&
        value.ValueKind == JsonValueKind.Number && value.TryGetDecimal(out var number)
        ? number
        : null;
}
static decimal? ReadEstimatedEnergyKcal(string? json)
{
    if (string.IsNullOrWhiteSpace(json)) return null;
    try
    {
        using var document = JsonDocument.Parse(json);
        return ReadJsonDecimal(document.RootElement, "energy_kcal");
    }
    catch (JsonException)
    {
        return null;
    }
}
static bool HasUnknownMealMacros(string? json)
{
    if (string.IsNullOrWhiteSpace(json)) return true;
    try
    {
        using var document = JsonDocument.Parse(json);
        var root = document.RootElement;
        return new[] { "protein_g", "carbohydrate_g", "total_fat_g" }
            .Any(key => !root.TryGetProperty(key, out var value) || value.ValueKind == JsonValueKind.Null);
    }
    catch (JsonException)
    {
        return true;
    }
}
static string NormalizePolicyToken(string value)
{
    var normalized = value.Trim().ToLowerInvariant().Replace('đ', 'd');
    var decomposed = normalized.Normalize(NormalizationForm.FormD);
    var builder = new StringBuilder(decomposed.Length);
    foreach (var c in decomposed)
        if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark && char.IsLetterOrDigit(c)) builder.Append(c);
    return builder.ToString();
}
static string? RemoveRiceAccompanimentNote(string? notes)
{
    if (string.IsNullOrWhiteSpace(notes)) return null;
    var remainingLines = notes.Replace("\r\n", "\n", StringComparison.Ordinal)
        .Split('\n')
        .Where(line =>
        {
            var normalized = NormalizePolicyToken(line);
            return !(normalized.Contains("anken", StringComparison.Ordinal) &&
                normalized.Contains("comtrangchin", StringComparison.Ordinal));
        });
    var result = string.Join(Environment.NewLine, remainingLines).Trim();
    return result.Length == 0 ? null : result;
}

static bool HasStarchStaple(Dish dish) => dish.Ingredients.Any(ingredient =>
    IsStarchStaple(ingredient.IngredientName) ||
    (ingredient.Food is not null && IsStarchStaple(ingredient.Food.Name)));
static bool IsStarchStaple(string? name)
{
    if (string.IsNullOrWhiteSpace(name)) return false;
    var key = NormalizePolicyToken(name);
    if (key.StartsWith("raukhoai", StringComparison.Ordinal) || key.StartsWith("phomai", StringComparison.Ordinal))
        return false;
    return key.Contains("gao", StringComparison.Ordinal)
        || key.Contains("com", StringComparison.Ordinal)
        || key.Contains("bun", StringComparison.Ordinal)
        || key.Contains("pho", StringComparison.Ordinal)
        || key.Contains("mien", StringComparison.Ordinal)
        || key.Contains("hutieu", StringComparison.Ordinal)
        || key.Contains("banhmi", StringComparison.Ordinal)
        || key.Contains("banhpho", StringComparison.Ordinal)
        || key.Contains("banhcanh", StringComparison.Ordinal)
        || key.Contains("banhcuon", StringComparison.Ordinal)
        || key.Contains("khoai", StringComparison.Ordinal)
        || key.StartsWith("nui", StringComparison.Ordinal)
        || (key.StartsWith("mi", StringComparison.Ordinal) && !key.StartsWith("michinh", StringComparison.Ordinal))
        || key.StartsWith("ngo", StringComparison.Ordinal)
        || key.StartsWith("bapngo", StringComparison.Ordinal)
        || key.Contains("yenaomach", StringComparison.Ordinal)
        || key.Contains("botmi", StringComparison.Ordinal)
        || key.Contains("quinoa", StringComparison.Ordinal);
}
static string[]? ParseJsonIds(string? json)
{
    if (json is null) return null;
    try { return JsonSerializer.Deserialize<string[]>(json); }
    catch { return null; }
}
static decimal? ParseGrams(string? amount)
{
    if (string.IsNullOrWhiteSpace(amount)) return null;
    var match = Regex.Match(amount, @"[-+]?[0-9]+(?:[.,][0-9]+)?");
    if (!match.Success) return null;
    return decimal.TryParse(match.Value.Replace(',', '.'), NumberStyles.Number, CultureInfo.InvariantCulture, out var value) ? value : null;
}
static async Task<object> MealSuggestionDtoAsync(AppDbContext db, MealSuggestion suggestion, CancellationToken ct)
{
    var dish = await db.Dishes.AsNoTracking().FirstOrDefaultAsync(x => x.Id == suggestion.DishId, ct);
    var portions = JsonSerializer.Deserialize<JsonElement>(suggestion.PersonalizedIngredientsJson);
    var portionFoodIds = portions.ValueKind == JsonValueKind.Array
        ? portions.EnumerateArray()
            .Where(item => item.TryGetProperty("foodId", out var id) && id.ValueKind == JsonValueKind.String)
            .Select(item => Guid.TryParse(item.GetProperty("foodId").GetString(), out var id) ? id : Guid.Empty)
            .Where(id => id != Guid.Empty)
            .Distinct()
            .ToArray()
        : Array.Empty<Guid>();
    var portionFoods = await db.Foods.AsNoTracking().Include(x => x.Nutrition)
        .Where(x => portionFoodIds.Contains(x.Id))
        .ToDictionaryAsync(x => x.Id, ct);
    var ingredientItems = new List<Dictionary<string, object?>>();
    if (portions.ValueKind == JsonValueKind.Array)
    {
        foreach (var portion in portions.EnumerateArray())
        {
            var item = portion.EnumerateObject().ToDictionary(x => x.Name, x => (object?)x.Value.Clone());
            if (item.TryGetValue("foodId", out var rawId) && rawId is JsonElement idValue &&
                Guid.TryParse(idValue.GetString(), out var foodId) && portionFoods.TryGetValue(foodId, out var food))
            {
                item["nutritionPer100g"] = new Dictionary<string, decimal?>
                {
                    ["energy_kcal"] = food.Nutrition?.EnergyKcal, ["protein_g"] = food.Nutrition?.ProteinG,
                    ["carbohydrate_g"] = food.Nutrition?.CarbohydrateG, ["total_fat_g"] = food.Nutrition?.FatG,
                    ["fiber_g"] = food.Nutrition?.FiberG, ["total_sugars_g"] = food.Nutrition?.SugarG,
                    ["saturated_fat_g"] = food.Nutrition?.SaturatedFatG, ["sodium_mg"] = food.Nutrition?.SodiumMg,
                };
                item["hasImage"] = !string.IsNullOrWhiteSpace(food.ImagePath);
            }
            ingredientItems.Add(item);
        }
    }
    var confirmed = await db.ConsumedMealLogs.AnyAsync(x => x.MealSuggestionId == suggestion.Id, ct);
    var includesRice = portions.ValueKind == JsonValueKind.Array && portions.EnumerateArray().Any(item =>
        item.TryGetProperty("name", out var name) && name.ValueKind == JsonValueKind.String &&
        NormalizePolicyToken(name.GetString() ?? "").StartsWith("comtrangchin", StringComparison.Ordinal));
    var dishName = dish?.Name ?? "Món ăn";
    var cookingNotes = RemoveRiceAccompanimentNote(dish?.CookingNotes);
    if (includesRice)
    {
        dishName += " (ăn kèm cơm)";
    }
    return new
    {
        suggestion.Id,
        suggestion.SessionId,
        suggestion.MealDate,
        suggestion.MealName,
        dishId = suggestion.DishId,
        dishName,
        category = dish?.Category,
        cookingNotes,
        hasImage = !string.IsNullOrWhiteSpace(dish?.ImagePath),
        estimatedNutrients = JsonSerializer.Deserialize<JsonElement>(suggestion.EstimatedNutrientsJson),
        ingredients = ingredientItems,
        isConfirmed = confirmed,
        suggestion.IsExtraMeal,
        mealTime = suggestion.MealTime?.ToString("HH:mm"),
        servingWeightGrams = suggestion.ServingWeightGrams,
    };
}
static Guid UserId(ClaimsPrincipal p) => Guid.Parse(p.FindFirstValue(ClaimTypes.NameIdentifier) ?? p.FindFirstValue(JwtRegisteredClaimNames.Sub)!);
static string Hash(string s) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(s)));
static object AdminSnapshot(AppUser u) => new { u.Username, u.Email, u.Phone, FullName = u.Profile?.FullName, u.IsActive, u.IsDeleted, u.IsEmailVerified, u.IsPhoneVerified, u.MustChangePassword };
static object ProfileSnapshot(UserProfile x) => new { x.FullName, x.BirthDate, x.Gender, x.HeightCm, x.WeightKg, x.Goal, x.TargetWeightKg, x.WeightGainNote, x.WeightGainTendency, x.MealsPerDay, x.Diet, x.NoAllergies, x.AllergiesJson, x.ActivityLevel, x.IsComplete, x.OnboardingStep };
static AdminActionLog Audit(Guid actorId, string action, Guid? targetId, string reason, object? before, object? after) => new()
{
    AdminUserId = actorId, Action = action, TargetUserId = targetId, Reason = reason,
    BeforeJson = before is null ? null : System.Text.Json.JsonSerializer.Serialize(before),
    AfterJson = after is null ? null : System.Text.Json.JsonSerializer.Serialize(after), Outcome = "Succeeded"
};
static async Task RevokeSessions(AppDbContext db, Guid userId, CancellationToken ct)
{
    foreach (var session in await db.RefreshSessions.Where(x => x.UserId == userId && x.RevokedAtUtc == null).ToListAsync(ct)) session.RevokedAtUtc = DateTime.UtcNow;
}
static async Task<List<AuditLogView>> FormatAuditLogs(AppDbContext db, List<AdminActionLog> logs, CancellationToken ct)
{
    var ids = logs.SelectMany(x => x.TargetUserId is Guid target ? new[] { x.AdminUserId, target } : new[] { x.AdminUserId }).Distinct().ToArray();
    var users = await db.Users.AsNoTracking().Where(x => ids.Contains(x.Id)).Select(x => new AuditPerson(x.Id, x.Role, (x.Profile == null ? null : x.Profile.FullName) ?? x.Username ?? x.Email ?? x.Phone)).ToListAsync(ct);
    var lookup = users.ToDictionary(x => x.Id);
    return logs.Select(x =>
    {
        lookup.TryGetValue(x.AdminUserId, out var actor);
        AuditPerson? target = null;
        if (x.TargetUserId is Guid targetId) lookup.TryGetValue(targetId, out target);
        return new AuditLogView(x.Id, x.AdminUserId, actor?.Name ?? "Tài khoản không còn tồn tại", actor?.Role ?? "Unknown", x.TargetUserId, target?.Name, x.Action, x.CreatedAtUtc, x.Outcome, x.Reason, x.BeforeJson, x.AfterJson);
    }).ToList();
}
static string MakeAccessToken(AppUser u, string key)
{
    var claims = new[] { new Claim(ClaimTypes.NameIdentifier, u.Id.ToString()), new Claim(ClaimTypes.Role, u.Role), new Claim("ver", u.TokenVersion.ToString()) };
    var token = new JwtSecurityToken("AvoraAI", "AvoraAI.Mobile", claims, expires: DateTime.UtcNow.AddMinutes(15), signingCredentials: new SigningCredentials(new SymmetricSecurityKey(Convert.FromBase64String(key)), SecurityAlgorithms.HmacSha256));
    return new JwtSecurityTokenHandler().WriteToken(token);
}

static async Task<List<Food>> LoadFoodsWithSources(IQueryable<Food> query, AppDbContext db, CancellationToken ct, bool includeFoodGroup = false, bool includeSourcesForAll = false)
{
    var foods = await query.ToListAsync(ct);
    if (foods.Count == 0) return foods;

    var ids = foods.Select(x => x.Id).ToArray();
    var nutritionRows = await db.FoodNutrition.AsNoTracking().Where(x => ids.Contains(x.FoodId)).ToListAsync(ct);
    var nutritionByFood = nutritionRows.ToDictionary(x => x.FoodId);
    foreach (var nutrition in nutritionRows) nutrition.Food = null!;
    foreach (var food in foods)
        food.Nutrition = nutritionByFood.TryGetValue(food.Id, out var nutrition) ? nutrition : null;

    var sourceIds = includeSourcesForAll ? ids : foods.Where(x => !HasCoreNutrition(x)).Select(x => x.Id).ToArray();
    List<NutritionSource> sources = sourceIds.Length == 0
        ? []
        : await db.NutritionSources.AsNoTracking().Where(x => sourceIds.Contains(x.FoodId)).ToListAsync(ct);
    var sourcesByFood = sources.GroupBy(x => x.FoodId).ToDictionary(x => x.Key, x => (ICollection<NutritionSource>)x.ToList());
    foreach (var source in sources) source.Food = null!;
    foreach (var food in foods)
        food.Sources = sourcesByFood.TryGetValue(food.Id, out var rows) ? rows : [];

    if (includeFoodGroup)
    {
        var groupIds = foods.Where(x => x.FoodGroupId.HasValue).Select(x => x.FoodGroupId!.Value).Distinct().ToArray();
        var groups = await db.FoodGroups.AsNoTracking().Where(x => groupIds.Contains(x.Id)).ToDictionaryAsync(x => x.Id, ct);
        foreach (var food in foods)
            food.FoodGroup = food.FoodGroupId is Guid groupId && groups.TryGetValue(groupId, out var group) ? group : null;
    }
    return foods;
}

static bool HasCoreNutrition(Food food)
{
    var nutrition = food.Nutrition;
    return nutrition is not null
        && nutrition.EnergyKcal is >= 0
        && nutrition.ProteinG is >= 0
        && nutrition.CarbohydrateG is >= 0
        && nutrition.FatG is >= 0;
}

static bool CanUseInCatalog(Food food) => food.IsVerified || HasCoreNutrition(food);

static string? FoodImageExtension(byte[] bytes)
{
    if (bytes.Length >= 8 && bytes.AsSpan(0, 8).SequenceEqual(new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 })) return ".png";
    if (bytes.Length >= 3 && bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255) return ".jpg";
    if (bytes.Length >= 12 && Encoding.ASCII.GetString(bytes, 0, 4) == "RIFF" && Encoding.ASCII.GetString(bytes, 8, 4) == "WEBP") return ".webp";
    return null;
}

static string FoodImageContentType(string filename) => Path.GetExtension(filename).ToLowerInvariant() switch
{
    ".png" => "image/png",
    ".webp" => "image/webp",
    _ => "image/jpeg"
};

static DishResponse DishDto(Dish dish, string? deletedByName = null, string? deletedByEmail = null)
{
    var ingredients = dish.Ingredients
        .Where(x => x.FoodId is null || x.Food is not null && !x.Food.IsDeleted)
        .OrderBy(x => x.SortOrder)
        .Select(x => new DishIngredientResponse(x.FoodId, x.Food?.Name ?? x.IngredientName, x.AmountInstruction))
        .ToList();
    return new DishResponse(dish.Id, dish.Name, dish.Category, dish.CookingNotes, ingredients, dish.Status, dish.IsDeleted, dish.DeletedAtUtc, deletedByName, deletedByEmail);
}

static DishResponse DishDtoWithRatings(Dish dish, List<Rating> ratings, Guid userId)
{
    var mine = ratings.FirstOrDefault(x => x.UserId == userId);
    var breakdown = Enumerable.Range(1, 5).ToDictionary(stars => stars, stars => ratings.Count(x => x.Stars == stars));
    return DishDto(dish) with
    {
        RatingCount = ratings.Count,
        AverageRating = ratings.Count == 0 ? null : Math.Round(ratings.Average(x => (decimal)x.Stars), 1),
        RatingBreakdown = breakdown,
        MyRating = mine?.Stars,
        MyComment = mine?.Comment,
    };
}

static async Task<string?> ApplyDishWriteAsync(Dish dish, DishWriteRequest request, AppDbContext db, CancellationToken ct)
{
    var name = request.Name?.Trim() ?? "";
    if (name.Length is 0 or > 160) return "T\u00ean m\u00f3n b\u1eaft bu\u1ed9c v\u00e0 t\u1ed1i \u0111a 160 k\u00fd t\u1ef1.";
    var notes = request.CookingNotes?.Trim();
    if ((notes?.Length ?? 0) > 8000) return "Ghi ch\u00fa / c\u00e1ch n\u1ea5u t\u1ed1i \u0111a 8000 k\u00fd t\u1ef1.";
    var status = string.Equals(request.Status, "Published", StringComparison.OrdinalIgnoreCase) ? "Published"
        : string.Equals(request.Status, "Draft", StringComparison.OrdinalIgnoreCase) ? "Draft" : null;
    if (status is null) return "Tr\u1ea1ng th\u00e1i ch\u1ec9 \u0111\u01b0\u1ee3c l\u00e0 Nh\u00e1p ho\u1eb7c \u0110\u00e3 c\u00f4ng b\u1ed1.";
    var requestedIngredients = request.Ingredients ?? (request.FoodIds ?? [])
        .Select(foodId => new DishIngredientWrite(foodId, null)).ToList();
    var foodIds = requestedIngredients.Where(x => x.FoodId.HasValue).Select(x => x.FoodId!.Value).ToList();
    if (requestedIngredients.Count == 0 && status == "Published") return "M\u00f3n c\u00f4ng b\u1ed1 c\u1ea7n c\u00f3 nguy\u00ean li\u1ec7u.";
    if (foodIds.Count != foodIds.Distinct().Count()) return "Kh\u00f4ng th\u1ec3 ch\u1ecdn tr\u00f9ng th\u1ef1c ph\u1ea9m.";
    var foods = await db.Foods.AsNoTracking()
        .Where(x => foodIds.Contains(x.Id) && !x.IsDeleted)
        .ToDictionaryAsync(x => x.Id, ct);
    if (foods.Count != foodIds.Count) return "M\u1ed9t ho\u1eb7c nhi\u1ec1u th\u1ef1c ph\u1ea9m kh\u00f4ng c\u00f2n trong danh m\u1ee5c.";
    if (requestedIngredients.Any(x => (x.AmountInstruction?.Length ?? 0) > 120)) return "\u0110\u1ecbnh l\u01b0\u1ee3ng t\u1ed1i \u0111a 120 k\u00fd t\u1ef1.";
    if (requestedIngredients.Any(x => !x.FoodId.HasValue && string.IsNullOrWhiteSpace(x.IngredientName)))
        return "Nguy\u00ean li\u1ec7u ch\u01b0a kh\u1edbp c\u1ea7n gi\u1eef t\u00ean ngu\u1ed3n \u0111\u1ec3 Admin r\u00e0 so\u00e1t.";
    if (status == "Published" && (foodIds.Count == 0 || requestedIngredients.Any(x => !x.FoodId.HasValue)))
        return "Kh\u00f4ng th\u1ec3 c\u00f4ng b\u1ed1 m\u00f3n c\u00f3 nguy\u00ean li\u1ec7u ch\u01b0a li\u00ean k\u1ebft FoodID.";
    if (status == "Published" && requestedIngredients.Any(x => !IsStandardGramAmount(x.AmountInstruction)))
        return "M\u1ed7i nguy\u00ean li\u1ec7u c\u1ea7n c\u00f3 gram chu\u1ea9n l\u1edbn h\u01a1n 0 tr\u01b0\u1edbc khi c\u00f4ng b\u1ed1.";

    dish.Name = name;
    dish.CookingNotes = string.IsNullOrWhiteSpace(notes) ? null : notes;
    dish.Status = status;
    dish.UpdatedAtUtc = DateTime.UtcNow;

    // Replace only catalog-linked ingredient rows; retain legacy unlinked rows and all old recipe fields.
    await db.DishIngredients.Where(x => x.DishId == dish.Id && x.FoodId != null).ExecuteDeleteAsync(ct);
    var linkedIngredients = requestedIngredients.Select((item, index) => new DishIngredient
    {
        Id = Guid.NewGuid(), DishId = dish.Id, FoodId = item.FoodId,
        IngredientName = item.FoodId is Guid foodId ? foods[foodId].Name : item.IngredientName!.Trim(),
        AmountInstruction = string.IsNullOrWhiteSpace(item.AmountInstruction) ? null : item.AmountInstruction.Trim(),
        SortOrder = index
    }).ToList();
    db.DishIngredients.AddRange(linkedIngredients);
    dish.Ingredients = linkedIngredients;
    return null;
}

static bool IsStandardGramAmount(string? amount)
{
    if (string.IsNullOrWhiteSpace(amount) ||
        !Regex.IsMatch(amount, @"^\s*\d+(?:[.,]\d+)?\s*g\s*$", RegexOptions.IgnoreCase)) return false;
    var grams = ParseGrams(amount);
    return grams is > 0;
}

static string[] NutritionFieldNames() => [
    "EnergyKcal", "ProteinG", "CarbohydrateG", "FatG", "FiberG", "SugarG",
    "SaturatedFatG", "SodiumMg"
];

record RegisterRequest(string Email, string Password);
record EmailRequest(string Email);
record BootstrapAdminRequest(string SetupKey, string Email, string Password);
record BootstrapAdminsRequest(string SetupKey, List<BootstrapAdminUserRequest> Admins);
record BootstrapAdminUserRequest(string Username, string Password);
record BootstrapSuperAdminRequest(string SetupKey, string Email, string Password);
record VerifyOtpRequest(string Email, string Code);
record LoginRequest(string Email, string Password);
record RefreshRequest(string RefreshToken);
record ForgotPasswordRequest(string Email);
record ResetPasswordRequest(string Email, string Code, string NewPassword);
record PasswordChangeRequest(string CurrentPassword, string NewPassword, string? Code);
record EmailChangeRequest(string NewEmail, string Password);
record ContactOtpRequest(string NewEmail, string Code);
record PhoneChangeRequest(string NewPhone, string Password);
record PhoneOtpRequest(string NewPhone, string Code);
record OtpCodeRequest(string Code);
record FridgeRequest(string Name, Guid? FoodId);
record GoalRequest(string? Goal, decimal? TargetWeightKg, int DurationDays = 90, int? MealsPerDay = null);
record MealGenerationRequest(Guid SessionId, DateOnly MealDate, string MealName, bool ReplaceExisting = false, List<Guid>? ExcludeDishIds = null);
record ExtraMealRequest(decimal CaloriesKcal);
record WeightHistoryRequest(decimal WeightKg, DateOnly RecordedOn);
record UpdateMealPortionsRequest(List<MealPortionRequest>? Ingredients);
record MealPortionRequest(Guid FoodId, decimal Grams);
record FoodAiReviewRequest(bool Approved, List<string>? AllergenIds);
record DishAiReviewRequest(bool Approved, List<string>? AllergenIds, List<string>? DietTags);
record ActiveRequest(bool Active, string? Reason);
record NutritionSourceRequest(string FieldName, string Citation, string? Url);
record FoodWriteRequest(string Name, decimal BasisGrams, List<decimal?> Values, List<NutritionSourceRequest> Sources, Guid? GroupId, bool IsDraft = false);
record FoodGroupRequest(string Code, string Name);
record FoodGroupUpdateRequest(string Name);
record SourceCheckRequest(bool Checked);
record RatingRequest(int Stars, string? Comment);
record DishWriteRequest(string? Name, List<Guid>? FoodIds, string? CookingNotes, string? Status, List<DishIngredientWrite>? Ingredients = null);
record DishIngredientWrite(Guid? FoodId, string? AmountInstruction, string? IngredientName = null);
record DishIngredientResponse(Guid? FoodId, string Name, string? AmountInstruction);
record DishResponse(Guid Id, string Name, string? Category, string? CookingNotes, List<DishIngredientResponse> Ingredients, string Status, bool IsDeleted, DateTime? DeletedAtUtc, string? DeletedByName = null, string? DeletedByEmail = null, int RatingCount = 0, decimal? AverageRating = null, Dictionary<int, int>? RatingBreakdown = null, int? MyRating = null, string? MyComment = null);
record DishFoodOption(Guid Id, string Name, string? GroupName, string Basis);
record AdminUserUpdateRequest(string Role, bool Active, string? Reason);
record AdminDeleteUserRequest(string Reason);
record SuperAdminCreateAdminRequest(string FullName, string Email, string? Phone, string Password, bool Active);
record SuperAdminEditAdminRequest(string FullName, string? Reason);
record SuperAdminActiveRequest(bool Active, string? Reason);
record SuperAdminReasonRequest(string Reason);
record SuperAdminEmailRequest(string Email);
record SuperAdminEmailOtpRequest(string Email, string Code);
record AuditLogView(Guid Id, Guid ActorId, string ActorName, string ActorRole, Guid? TargetId, string? TargetName, string Action, DateTime CreatedAtUtc, string Outcome, string Reason, string? BeforeJson, string? AfterJson);
record AuditPerson(Guid Id, string Role, string? Name);
record SuperAdminListItem(Guid Id, string? FullName, string? Username, string? Email, string? Phone, bool IsEmailVerified, bool IsPhoneVerified, bool IsActive, bool IsDeleted, DateTime CreatedAtUtc);
record ProfileRequest(string? FullName, DateOnly? BirthDate, string? Gender, decimal? HeightCm, decimal? WeightKg, string? Goal, decimal? TargetWeightKg, string? WeightGainNote, string? WeightGainTendency, int? MealsPerDay, string? Diet, bool NoAllergies, List<string> Allergies, string? ActivityLevel, int Step);

public partial class Program { }
