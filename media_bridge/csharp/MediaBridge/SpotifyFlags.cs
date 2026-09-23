using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Reflection;
using System.Text;
using Microsoft.Win32;

namespace MediaBridge;

public static class SpotifyFlags
{
    public const string Flag = "--remote-debugging-port=9222";
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromMilliseconds(400) };
    private static string _state = "none";
    private static DateTime _stateAt = DateTime.MinValue;

    public static void StartHealer()
    {
        _ = Task.Run(async () =>
        {
            while (true)
            {
                try { Heal(); } catch { }
                await Task.Delay(TimeSpan.FromMinutes(10));
            }
        });
    }

    public static async Task<string> DebugStateAsync()
    {
        if ((DateTime.UtcNow - _stateAt).TotalSeconds < 5) return _state;
        _stateAt = DateTime.UtcNow;
        var procs = Process.GetProcessesByName("Spotify");
        bool running = procs.Length > 0;
        foreach (var p in procs) p.Dispose();
        if (!running) return _state = "none";
        try
        {
            using var r = await Http.GetAsync("http://127.0.0.1:9222/json/version");
            _state = r.IsSuccessStatusCode ? "ok" : "closed";
        }
        catch
        {
            _state = "closed";
        }
        return _state;
    }

    private static void Heal()
    {
        string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        if (!File.Exists(Path.Combine(appData, "Spotify", "Spotify.exe"))) return;

        string[] links =
        {
            Path.Combine(appData, @"Microsoft\Windows\Start Menu\Programs\Spotify.lnk"),
            Path.Combine(appData, @"Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Spotify.lnk"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "Spotify.lnk")
        };
        foreach (var link in links)
        {
            if (File.Exists(link))
            {
                try { FixShortcut(link); } catch { }
            }
        }

        using var key = Registry.CurrentUser.OpenSubKey(@"Software\Classes\spotify\shell\open\command", true);
        if (key?.GetValue("") is string cmd
            && cmd.Contains("spotify.exe", StringComparison.OrdinalIgnoreCase)
            && !cmd.Contains("remote-debugging-port", StringComparison.OrdinalIgnoreCase))
        {
            string fixedCmd = cmd.Contains("--protocol-uri", StringComparison.Ordinal)
                ? cmd.Replace("--protocol-uri", Flag + " --protocol-uri")
                : cmd + " " + Flag;
            key.SetValue("", fixedCmd);
        }
    }

    private static void FixShortcut(string path)
    {
        var shellType = Type.GetTypeFromProgID("WScript.Shell");
        if (shellType == null) return;
        object? shell = Activator.CreateInstance(shellType);
        if (shell == null) return;
        object? link = null;
        try
        {
            link = shellType.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { path });
            if (link == null) return;
            var linkType = link.GetType();
            string target = linkType.InvokeMember("TargetPath", BindingFlags.GetProperty, null, link, null) as string ?? "";
            if (!target.EndsWith("Spotify.exe", StringComparison.OrdinalIgnoreCase)) return;
            string current = linkType.InvokeMember("Arguments", BindingFlags.GetProperty, null, link, null) as string ?? "";
            if (current.Contains("remote-debugging-port", StringComparison.OrdinalIgnoreCase)) return;
            linkType.InvokeMember("Arguments", BindingFlags.SetProperty, null, link, new object[] { (current + " " + Flag).Trim() });
            linkType.InvokeMember("Save", BindingFlags.InvokeMethod, null, link, null);
        }
        finally
        {
            if (link != null) Marshal.ReleaseComObject(link);
            Marshal.ReleaseComObject(shell);
        }
    }
}
