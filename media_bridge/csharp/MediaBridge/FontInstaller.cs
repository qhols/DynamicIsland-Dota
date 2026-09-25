using System.IO.Compression;
using System.Runtime.InteropServices;
using Microsoft.Win32;

namespace MediaBridge;

public record FontStatus(string status, bool installed, string state, string error);

public static class FontInstaller
{
    private const string FontsZip = "https://github.com/qhols/DynamicIsland-Dota/releases/download/v2.0.0/fonts.zip";
    private const string RegPath = @"Software\Microsoft\Windows NT\CurrentVersion\Fonts";

    private static readonly (string File, string Name)[] Needed =
    {
        ("SFProText-Regular.ttf", "SF Pro Text Regular"),
        ("SFProText-Medium.ttf", "SF Pro Text Medium"),
        ("SFProText-Semibold.ttf", "SF Pro Text Semibold"),
        ("SFPRODISPLAYMEDIUM.OTF", "SF Pro Display Medium"),
    };

    private static readonly object Sync = new();
    private static string _state = "idle";
    private static string _error = "";
    private static bool? _installed;
    private static DateTime _checkedAt = DateTime.MinValue;

    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
    private static extern int AddFontResourceW(string file);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr SendMessageTimeoutW(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam, uint flags, uint timeout, out IntPtr result);

    public static bool Installed
    {
        get
        {
            lock (Sync)
            {
                if (_installed == null || DateTime.UtcNow - _checkedAt > TimeSpan.FromSeconds(10))
                {
                    _installed = Check();
                    _checkedAt = DateTime.UtcNow;
                }
                return _installed.Value;
            }
        }
    }

    public static FontStatus Status
    {
        get
        {
            bool installed = Installed;
            lock (Sync) return new FontStatus("ok", installed, _state, _error);
        }
    }

    private static bool Check()
    {
        var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var root in new[] { Registry.CurrentUser, Registry.LocalMachine })
        {
            try
            {
                using var key = root.OpenSubKey(RegPath);
                if (key == null) continue;
                foreach (var v in key.GetValueNames())
                {
                    int p = v.IndexOf(" (", StringComparison.Ordinal);
                    names.Add(p > 0 ? v[..p] : v);
                }
            }
            catch { }
        }
        foreach (var (_, name) in Needed)
        {
            if (!names.Contains(name)) return false;
        }
        return true;
    }

    public static void Start()
    {
        lock (Sync)
        {
            if (_state == "installing") return;
            _state = "installing";
            _error = "";
        }
        _ = Task.Run(RunAsync);
    }

    private static async Task RunAsync()
    {
        try
        {
            using var http = new HttpClient { Timeout = TimeSpan.FromMinutes(2) };
            http.DefaultRequestHeaders.UserAgent.ParseAdd("DynamicIsland-MediaBridge/" + UpdateChecker.BridgeVersion);
            byte[] zipBytes = await http.GetByteArrayAsync(FontsZip);

            string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Microsoft\Windows\Fonts");
            Directory.CreateDirectory(dir);

            using var zip = new ZipArchive(new MemoryStream(zipBytes), ZipArchiveMode.Read);
            using var key = Registry.CurrentUser.CreateSubKey(RegPath);
            foreach (var (file, name) in Needed)
            {
                var entry = zip.Entries.FirstOrDefault(e => string.Equals(e.Name, file, StringComparison.OrdinalIgnoreCase));
                if (entry == null) throw new FileNotFoundException(file);
                string target = Path.Combine(dir, file);
                if (!File.Exists(target))
                {
                    await using var src = entry.Open();
                    await using var dst = File.Create(target);
                    await src.CopyToAsync(dst);
                }
                key.SetValue(name + " (TrueType)", target);
                AddFontResourceW(target);
            }
            SendMessageTimeoutW((IntPtr)0xFFFF, 0x001D, IntPtr.Zero, IntPtr.Zero, 0x0002, 1000, out _);

            lock (Sync)
            {
                _installed = Check();
                _checkedAt = DateTime.UtcNow;
                _state = _installed == true ? "done" : "error";
                if (_installed != true) _error = "check";
            }
        }
        catch (Exception ex)
        {
            lock (Sync)
            {
                _state = "error";
                _error = ex.GetType().Name;
            }
        }
    }
}
