using System.Diagnostics;
using System.Text.Json;

namespace AvoraAI.API.Services;

public sealed class HybridMealOptimizer(IConfiguration configuration, IWebHostEnvironment environment)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task<JsonElement> RecommendAsync(object payload, CancellationToken cancellationToken)
    {
        var deployedScript = Path.Combine(AppContext.BaseDirectory, "Algorithms", "meal_optimizer_adapter.py");
        var sourceScript = Path.GetFullPath(Path.Combine(environment.ContentRootPath, "..", "app", "algorithms", "meal_optimizer_adapter.py"));
        var script = File.Exists(deployedScript) ? deployedScript : sourceScript;
        if (!File.Exists(script)) throw new FileNotFoundException("Meal optimizer adapter is missing.", script);
        var executable = configuration["Python:Executable"];
        if (string.IsNullOrWhiteSpace(executable)) executable = "python";
        var start = new ProcessStartInfo
        {
            FileName = executable,
            WorkingDirectory = Path.GetDirectoryName(script)!,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        start.ArgumentList.Add(script);
        start.Environment["PYTHONUTF8"] = "1";
        using var process = new Process { StartInfo = start };
        try
        {
            if (!process.Start()) throw new InvalidOperationException("Python optimizer process did not start.");
            var stdoutTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
            var stderrTask = process.StandardError.ReadToEndAsync(cancellationToken);
            await process.StandardInput.WriteAsync(JsonSerializer.Serialize(payload, JsonOptions));
            process.StandardInput.Close();
            await process.WaitForExitAsync(cancellationToken);
            var stdout = await stdoutTask;
            var stderr = await stderrTask;
            if (process.ExitCode != 0)
                throw new InvalidOperationException($"Meal optimizer failed with exit code {process.ExitCode}: {stderr.Trim()}");
            using var result = JsonDocument.Parse(stdout);
            return result.RootElement.Clone();
        }
        catch (Exception exception) when (exception is not OperationCanceledException && exception is not FileNotFoundException)
        {
            throw new InvalidOperationException("Không thể chạy bộ tối ưu bữa ăn.", exception);
        }
    }
}
