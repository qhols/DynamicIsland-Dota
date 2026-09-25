using System.Text.RegularExpressions;

namespace MediaBridge;

public static partial class UpdateChecker
{
    public const string BridgeVersion = "2.3.0";
    private const string LatestReleaseUrl = "https://api.github.com/repos/qhols/DynamicIsland-Dota/releases/latest";
    private static readonly TimeSpan Interval = TimeSpan.FromHours(6);
    private static readonly TimeSpan RetryInterval = TimeSpan.FromMinutes(30);

    public static string LatestTag { get; private set; } = "";

    [GeneratedRegex("\"tag_name\"\\s*:\\s*\"([^\"]+)\"")]
    private static partial Regex TagRegex();

    public static void Start()
    {
        _ = Task.Run(async () =>
        {
            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };
            http.DefaultRequestHeaders.UserAgent.ParseAdd("DynamicIsland-MediaBridge/" + BridgeVersion);
            http.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
            while (true)
            {
                bool gotIt = false;
                try
                {
                    string json = await http.GetStringAsync(LatestReleaseUrl);
                    var m = TagRegex().Match(json);
                    if (m.Success)
                    {
                        LatestTag = m.Groups[1].Value;
                        gotIt = true;
                    }
                }
                catch { }
                await Task.Delay(gotIt ? Interval : RetryInterval);
            }
        });
    }
}
