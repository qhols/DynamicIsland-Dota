using System.Diagnostics;
using System.Text;
using System.Text.Json;

namespace MediaBridge;

public record UpdateStatus(string status, string state, double progress, string version, string error);

public static class Updater
{
    private const string ReleaseApi = "https://api.github.com/repos/qhols/DynamicIsland-Dota/releases/latest";
    private const string AssetPrefix = "https://github.com/qhols/DynamicIsland-Dota/releases/download/";
    private const string ReleasePage = "https://github.com/qhols/DynamicIsland-Dota/releases/latest";
    private const string ScriptName = "dynamic_island.lua";
    private const string BridgeName = "media_bridge.exe";

    private static readonly object Sync = new();
    private static string _state = "idle";
    private static double _progress;
    private static string _version = "";
    private static string _error = "";
    private static string _newExe = "";

    public static bool TestMode { get; private set; }
    private static bool _testFail;

    public static void SetTest(bool on, bool fail)
    {
        TestMode = on;
        _testFail = fail;
        lock (Sync)
        {
            if (_state is "ready" or "error")
            {
                _state = "idle";
                _progress = 0;
                _error = "";
            }
        }
    }

    public static UpdateStatus Status
    {
        get { lock (Sync) return new UpdateStatus("ok", _state, _progress, _version, _error); }
    }

    private static void Set(string state, double progress, string error = "")
    {
        lock (Sync)
        {
            _state = state;
            _progress = progress;
            _error = error;
        }
    }

    public static void OpenReleasePage()
    {
        try { Process.Start(new ProcessStartInfo(ReleasePage) { UseShellExecute = true }); } catch { }
    }

    public static void Start(string? scriptDir)
    {
        lock (Sync)
        {
            if (_state is "downloading" or "installing" or "ready") return;
            _state = "downloading";
            _progress = 0;
            _error = "";
        }
        _ = Task.Run(() => RunAsync(scriptDir));
    }

    private static async Task RunAsync(string? scriptDir)
    {
        try
        {
            string scriptPath = ResolveScriptPath(scriptDir);
            if (scriptPath == "") { Set("error", 0, "script"); return; }
            if (TestMode)
            {
                await SimulateAsync();
                return;
            }

            using var http = new HttpClient { Timeout = TimeSpan.FromMinutes(3) };
            http.DefaultRequestHeaders.UserAgent.ParseAdd("DynamicIsland-MediaBridge/" + UpdateChecker.BridgeVersion);

            string json = await http.GetStringAsync(ReleaseApi);
            using var doc = JsonDocument.Parse(json);
            string tag = doc.RootElement.TryGetProperty("tag_name", out var t) ? t.GetString() ?? "" : "";
            lock (Sync) _version = tag;

            string luaUrl = "", exeUrl = "";
            long luaSize = 0, exeSize = 0;
            foreach (var asset in doc.RootElement.GetProperty("assets").EnumerateArray())
            {
                string name = asset.GetProperty("name").GetString() ?? "";
                string url = asset.GetProperty("browser_download_url").GetString() ?? "";
                long size = asset.GetProperty("size").GetInt64();
                if (!url.StartsWith(AssetPrefix, StringComparison.Ordinal)) continue;
                if (name == ScriptName) { luaUrl = url; luaSize = size; }
                else if (name == BridgeName) { exeUrl = url; exeSize = size; }
            }
            if (luaUrl == "") { Set("error", 0, "assets"); return; }

            long total = luaSize + exeSize;
            long done = 0;
            byte[] lua = await DownloadAsync(http, luaUrl, luaSize, n => { done += n; Set("downloading", total > 0 ? (double)done / total : 0); });
            byte[]? exe = exeUrl == "" ? null : await DownloadAsync(http, exeUrl, exeSize, n => { done += n; Set("downloading", total > 0 ? (double)done / total : 0); });

            string luaText = Encoding.UTF8.GetString(lua);
            if (lua.Length != luaSize || !luaText.Contains("SCRIPT_VERSION") || !luaText.Contains("return DynamicIsland")) { Set("error", 1, "verify"); return; }
            if (exe != null && (exe.Length != exeSize || exe.Length < 2 || exe[0] != 'M' || exe[1] != 'Z')) { Set("error", 1, "verify"); return; }

            Set("installing", 1);
            try { File.Copy(scriptPath, Path.Combine(Path.GetTempPath(), "dynamic_island_backup.lua"), true); } catch { }
            string tmp = scriptPath + ".tmp";
            await File.WriteAllBytesAsync(tmp, lua);
            File.Move(tmp, scriptPath, true);

            if (exe != null)
            {
                string self = Environment.ProcessPath ?? "";
                if (self != "")
                {
                    string next = self + ".new";
                    await File.WriteAllBytesAsync(next, exe);
                    lock (Sync) _newExe = next;
                }
            }
            Set("ready", 1);
        }
        catch (Exception ex)
        {
            Set("error", 0, ex.GetType().Name);
        }
    }

    private static async Task SimulateAsync()
    {
        lock (Sync) _version = "v9.9.9";
        for (int i = 0; i <= 40; i++)
        {
            if (_testFail && i == 26)
            {
                Set("error", (double)i / 40, "test");
                return;
            }
            Set("downloading", (double)i / 40);
            await Task.Delay(100);
        }
        Set("installing", 1);
        await Task.Delay(1200);
        string self = Environment.ProcessPath ?? "";
        if (self != "")
        {
            string next = self + ".new";
            File.Copy(self, next, true);
            lock (Sync) _newExe = next;
        }
        Set("ready", 1);
    }

    private static string ResolveScriptPath(string? scriptDir)
    {
        foreach (var dir in new[] { scriptDir, @"C:\Umbrella\scripts" })
        {
            if (string.IsNullOrWhiteSpace(dir)) continue;
            try
            {
                string full = Path.GetFullPath(dir);
                string path = Path.Combine(full, ScriptName);
                if (File.Exists(path)) return path;
            }
            catch { }
        }
        return "";
    }

    private static async Task<byte[]> DownloadAsync(HttpClient http, string url, long size, Action<long> onChunk)
    {
        using var resp = await http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
        resp.EnsureSuccessStatusCode();
        await using var stream = await resp.Content.ReadAsStreamAsync();
        using var ms = new MemoryStream(size > 0 ? (int)size : 1 << 20);
        var buffer = new byte[64 * 1024];
        int read;
        while ((read = await stream.ReadAsync(buffer)) > 0)
        {
            ms.Write(buffer, 0, read);
            onChunk(read);
        }
        return ms.ToArray();
    }

    public static void Restart()
    {
        string next;
        lock (Sync) next = _newExe;
        string self = Environment.ProcessPath ?? "";
        if (next == "" || self == "" || !File.Exists(next)) return;
        try
        {
            string old = self + ".old";
            try { if (File.Exists(old)) File.Delete(old); } catch { }
            File.Move(self, old);
            File.Move(next, self);
            var psi = new ProcessStartInfo(self) { UseShellExecute = false, WorkingDirectory = Path.GetDirectoryName(self) ?? "" };
            if (DotaLifetime.Stay) psi.ArgumentList.Add("--stay");
            Process.Start(psi);
            Environment.Exit(0);
        }
        catch (Exception ex)
        {
            Set("error", 1, ex.GetType().Name);
        }
    }
}
