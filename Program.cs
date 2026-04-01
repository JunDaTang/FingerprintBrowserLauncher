using System.Diagnostics;
using System.Net.Http;
using System.Text.Json;
using System.Text.Json.Serialization;

public class LauncherConfig
{
    [JsonPropertyName("browserPath")]
    public string BrowserPath { get; set; } = "";

    [JsonPropertyName("defaultProfile")]
    public string DefaultProfile { get; set; } = "default";

    [JsonPropertyName("appendUrlAtEnd")]
    public bool AppendUrlAtEnd { get; set; } = true;

    [JsonPropertyName("autoDetectByIp")]
    public bool AutoDetectByIp { get; set; } = false;

    [JsonPropertyName("ipInfoUrl")]
    public string IpInfoUrl { get; set; } = "https://ipapi.co/json/";

    [JsonPropertyName("ipLookupTimeoutSeconds")]
    public int IpLookupTimeoutSeconds { get; set; } = 2;

    [JsonPropertyName("countryProfileMap")]
    public Dictionary<string, string> CountryProfileMap { get; set; } = new();

    [JsonPropertyName("profiles")]
    public Dictionary<string, BrowserProfile> Profiles { get; set; } = new();
}

public class BrowserProfile
{
    [JsonPropertyName("args")]
    public List<string> Args { get; set; } = new();
}

public class IpInfoResponse
{
    [JsonPropertyName("country_code")]
    public string? CountryCode { get; set; }

    [JsonPropertyName("country")]
    public string? Country { get; set; }

    [JsonPropertyName("timezone")]
    public string? Timezone { get; set; }

    [JsonPropertyName("ip")]
    public string? Ip { get; set; }
}

public class DetectionResult
{
    public string? CountryCode { get; set; }
    public string? Ip { get; set; }
    public string? Timezone { get; set; }
    public string? SelectedProfile { get; set; }
    public string? Error { get; set; }
}

internal class Program
{
    static int Main(string[] args)
    {
        try
        {
            string exeDir = AppContext.BaseDirectory;
            string configPath = Path.Combine(exeDir, "config.json");

            if (!File.Exists(configPath))
            {
                Console.Error.WriteLine("config.json not found: " + configPath);
                return 2;
            }

            var json = File.ReadAllText(configPath);
            var config = JsonSerializer.Deserialize<LauncherConfig>(json, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true,
                ReadCommentHandling = JsonCommentHandling.Skip,
                AllowTrailingCommas = true
            });

            if (config == null)
            {
                Console.Error.WriteLine("Failed to parse config.json");
                return 3;
            }

            if (string.IsNullOrWhiteSpace(config.BrowserPath) || !File.Exists(config.BrowserPath))
            {
                Console.Error.WriteLine("BrowserPath is invalid: " + config.BrowserPath);
                return 4;
            }

            string? manualProfileName = null;
            var passthroughArgs = new List<string>();

            for (int i = 0; i < args.Length; i++)
            {
                if (string.Equals(args[i], "--profile", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
                {
                    manualProfileName = args[i + 1];
                    i++;
                    continue;
                }

                passthroughArgs.Add(args[i]);
            }

            string profileName = manualProfileName ?? config.DefaultProfile;
            DetectionResult? detection = null;

            if (manualProfileName == null && config.AutoDetectByIp)
            {
                detection = TryDetectProfileByIp(config);
                if (!string.IsNullOrWhiteSpace(detection?.SelectedProfile))
                {
                    profileName = detection!.SelectedProfile!;
                }
            }

            Console.WriteLine($"[Launcher] Manual profile: {(manualProfileName ?? "<none>")}");
            if (detection != null)
            {
                Console.WriteLine($"[Launcher] Detected IP: {detection.Ip ?? "<unknown>"}");
                Console.WriteLine($"[Launcher] Detected country: {detection.CountryCode ?? "<unknown>"}");
                Console.WriteLine($"[Launcher] Detected timezone: {detection.Timezone ?? "<unknown>"}");
                if (!string.IsNullOrWhiteSpace(detection.Error))
                    Console.WriteLine($"[Launcher] Detection error: {detection.Error}");
            }
            Console.WriteLine($"[Launcher] Selected profile: {profileName}");

            if (!config.Profiles.TryGetValue(profileName, out var profile))
            {
                Console.Error.WriteLine($"Profile not found: {profileName}");
                return 5;
            }

            var finalArgs = new List<string>();
            finalArgs.AddRange(profile.Args);

            if (passthroughArgs.Count > 0)
            {
                if (config.AppendUrlAtEnd)
                    finalArgs.AddRange(passthroughArgs);
                else
                    finalArgs.InsertRange(0, passthroughArgs);
            }

            var psi = new ProcessStartInfo
            {
                FileName = config.BrowserPath,
                UseShellExecute = false
            };

            foreach (var arg in finalArgs)
            {
                psi.ArgumentList.Add(arg);
            }

            Process.Start(psi);
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(ex.ToString());
            return 10;
        }
    }

    static DetectionResult TryDetectProfileByIp(LauncherConfig config)
    {
        var result = new DetectionResult();

        try
        {
            using var httpClient = new HttpClient();
            httpClient.Timeout = TimeSpan.FromSeconds(Math.Max(1, config.IpLookupTimeoutSeconds));
            httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("FingerprintBrowserLauncher/1.0");

            using var response = httpClient.GetAsync(config.IpInfoUrl).GetAwaiter().GetResult();
            response.EnsureSuccessStatusCode();

            string body = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
            var ipInfo = JsonSerializer.Deserialize<IpInfoResponse>(body, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            result.Ip = ipInfo?.Ip;
            result.Timezone = ipInfo?.Timezone;
            result.CountryCode = ipInfo?.CountryCode?.Trim().ToUpperInvariant();

            if (!string.IsNullOrWhiteSpace(result.CountryCode)
                && config.CountryProfileMap.TryGetValue(result.CountryCode, out var mappedProfile)
                && !string.IsNullOrWhiteSpace(mappedProfile))
            {
                result.SelectedProfile = mappedProfile;
            }
        }
        catch (Exception ex)
        {
            result.Error = ex.Message;
        }

        return result;
    }
}
