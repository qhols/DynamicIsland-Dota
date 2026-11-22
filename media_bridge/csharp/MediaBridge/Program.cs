using System.Diagnostics;
using System.Globalization;
using System.Net;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.Json.Serialization.Metadata;

namespace MediaBridge;

public record CommandResponse(string status, int volume, bool is_liked, string target);
public record AudioDiag(string status, string app, string family, string sessions);
public record PlaylistResponse(string status, string[] items, bool[] selected);
public record FocusResponse(string status, bool focused);
public record SoundResponse(string status);
public record LevelResponse(double[] l, string src, int n, double p);
public record StatusResponse(string status, string version, string latest_version, int sounds_loaded, string sound_output, string sound_error, string media_sessions, string spotify_debug, string yandex_debug, bool fonts_ok, string channel);

[JsonSerializable(typeof(MediaInfo))]
[JsonSerializable(typeof(CommandResponse))]
[JsonSerializable(typeof(FocusResponse))]
[JsonSerializable(typeof(SoundResponse))]
[JsonSerializable(typeof(StatusResponse))]
[JsonSerializable(typeof(SystemInfo))]
[JsonSerializable(typeof(UpdateStatus))]
[JsonSerializable(typeof(FontStatus))]
[JsonSerializable(typeof(LevelResponse))]
[JsonSerializable(typeof(AudioDiag))]
[JsonSerializable(typeof(PlaylistResponse))]
internal partial class AppJsonContext : JsonSerializerContext { }

internal static class AppJson
{
    public static readonly AppJsonContext Context = new(new JsonSerializerOptions
    {
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
    });
}

internal static class Program
{
    private static string _logPath = "";

    private static async Task Main(string[] args)
    {
        string exeDir = AppContext.BaseDirectory;
        _logPath = ResolveLogPath(exeDir);

        string[] gameArgs = DotaLifetime.ParseFlags(args);
        DotaLifetime.LaunchGame(gameArgs, Log);

        CleanupOtherInstances();

        using var singleInstanceMutex = new Mutex(false, "Global\\DynamicIslandMediaBridge");
        bool owned;
        try { owned = singleInstanceMutex.WaitOne(0); }
        catch (AbandonedMutexException) { owned = true; }
        if (!owned)
        {
            return;
        }

        SoundEngine.Init(exeDir);
        AppAudioControl.StartFocusWatcher();
        SystemWatcher.Start();
        UpdateChecker.Start();
        SpotifyFlags.StartHealer();
        DotaLifetime.StartExitWatcher();

        var listener = new HttpListener();
        listener.Prefixes.Add("http://127.0.0.1:45455/");
        listener.Start();

        while (true)
        {
            HttpListenerContext context;
            try
            {
                context = await listener.GetContextAsync();
            }
            catch (Exception ex)
            {
                Log(ex.ToString());
                await Task.Delay(100);
                continue;
            }

            _ = Task.Run(() => HandleRequestAsync(context));
        }
    }

    private static string ResolveLogPath(string exeDir)
    {
        const string umbrellaLog = @"C:\Umbrella\scripts\media_bridge\bridge_error.log";
        try
        {
            string umbrellaDir = Path.GetDirectoryName(umbrellaLog)!;
            if (Directory.Exists(umbrellaDir)) return umbrellaLog;
        }
        catch { }
        return Path.Combine(exeDir, "bridge_error.log");
    }

    private static void Log(string message)
    {
        try
        {
            File.AppendAllText(_logPath, $"[{DateTime.Now}] {message}{Environment.NewLine}");
        }
        catch { }
    }

    private static void CleanupOtherInstances()
    {
        try
        {
            int currentPid = Environment.ProcessId;
            foreach (var p in Process.GetProcessesByName("media_bridge"))
            {
                if (p.Id != currentPid)
                {
                    try { p.Kill(); } catch { }
                }
            }
            Thread.Sleep(150);
        }
        catch { }
    }

    internal record Reply(int Code, string ContentType, byte[] Body);

    private static Reply Json<T>(T data, JsonTypeInfo<T> typeInfo) => new(200, "application/json; charset=utf-8", JsonSerializer.SerializeToUtf8Bytes(data, typeInfo));

    internal static async Task<string> StatusJsonAsync()
    {
        var st = new StatusResponse("ok", UpdateChecker.BridgeVersion, Updater.TestMode ? "v9.9.9" : UpdateChecker.LatestTag, SoundEngine.LoadedCount, SoundEngine.OutputKind, SoundEngine.LastError, MediaSessionService.ManagerState, await SpotifyFlags.DebugStateAsync(), await YandexLike.DebugStateAsync(), FontInstaller.Installed, FileChannel.Dir);
        return JsonSerializer.Serialize(st, AppJson.Context.StatusResponse);
    }

    private static async Task HandleRequestAsync(HttpListenerContext context)
    {
        var request = context.Request;
        var response = context.Response;
        try
        {
            response.KeepAlive = false;
            response.Headers.Add("Access-Control-Allow-Origin", "*");
            response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
            response.Headers.Add("Access-Control-Allow-Headers", "Content-Type");
            if (request.HttpMethod == "OPTIONS")
            {
                response.StatusCode = 200;
                response.OutputStream.Close();
                return;
            }
            string path = (request.Url?.LocalPath ?? "").ToLowerInvariant();
            Reply r = await HandleCore(path, request.QueryString);
            response.StatusCode = r.Code;
            if (r.Body.Length > 0)
            {
                response.ContentType = r.ContentType;
                response.ContentLength64 = r.Body.Length;
                await response.OutputStream.WriteAsync(r.Body);
            }
            response.OutputStream.Close();
        }
        catch (Exception ex)
        {
            Log(ex.ToString());
            try { response.OutputStream.Close(); } catch { }
        }
    }

    internal static async Task<Reply> HandleCore(string path, System.Collections.Specialized.NameValueCollection q)
    {
        if (path == "/media")
        {
            MediaSessionService.SetScriptsDir(q["dir"]);
            FontInstaller.CopyToCheat(MediaSessionService.ScriptsDirectory);
            SpotifyFlags.SetEnabled(q["likes"]);
            var data = await MediaSessionService.GetMediaInfoAsync() ?? new MediaInfo
            {
                is_playing = false,
                volume = -100,
                is_liked = MediaSessionService.CurrentIsLiked
            };
            return Json(data, AppJson.Context.MediaInfo);
        }
        if (path == "/media/seek")
        {
            bool ok = false;
            if (double.TryParse(q["pos"], NumberStyles.Float, CultureInfo.InvariantCulture, out double pos))
            {
                ok = await MediaSessionService.SeekAsync(pos);
            }
            return Json(new SoundResponse(ok ? "ok" : "failed"), AppJson.Context.SoundResponse);
        }
        if (path == "/playlist/open")
        {
            var (status, items, selected) = await YandexPlaylist.OpenAsync();
            return Json(new PlaylistResponse(status, items.Select(Uri.EscapeDataString).ToArray(), selected), AppJson.Context.PlaylistResponse);
        }
        if (path == "/playlist/add")
        {
            bool ok = int.TryParse(q["index"], out int index) && await YandexPlaylist.AddAsync(index);
            return Json(new SoundResponse(ok ? "ok" : "failed"), AppJson.Context.SoundResponse);
        }
        if (path == "/playlist/remove")
        {
            bool ok = int.TryParse(q["index"], out int index) && await YandexPlaylist.RemoveAsync(index);
            return Json(new SoundResponse(ok ? "ok" : "failed"), AppJson.Context.SoundResponse);
        }
        if (path is "/media/playpause" or "/media/next" or "/media/prev" or "/media/shuffle"
                 or "/media/repeat" or "/media/like" or "/media/volup" or "/media/voldown")
        {
            string cmd = path[7..];
            bool bump = q["bump"] == "1";
            bool noSound = q["nosound"] == "1";
            if ((cmd == "volup" || cmd == "voldown") && !noSound)
            {
                double notchVol = bump ? 0.65 : 0.45;
                if (double.TryParse(q["vol"], NumberStyles.Float, CultureInfo.InvariantCulture, out double parsedNotch))
                {
                    notchVol = Math.Max(0.01, Math.Min(1.0, parsedNotch));
                }
                SoundEngine.Play(bump ? "wheel_boundary_bump" : "wheel_notch", notchVol);
            }
            bool yandexMode = (cmd is "shuffle" or "repeat") && YandexLike.IsApp(MediaSessionService.CurrentAppId);
            bool commandOk = cmd == "like" ? await MediaSessionService.ToggleLikeAsync()
                : !yandexMode || await YandexLike.ToggleModeAsync(cmd);
            float? curVol = cmd == "like" || yandexMode ? null : await MediaSessionService.HandleMediaCommandAsync(cmd);
            curVol ??= AppAudioControl.GetAppVolume(MediaSessionService.CurrentFamily);
            int volInt = (int)Math.Round(curVol.Value * 100);
            return Json(new CommandResponse(commandOk ? "ok" : "failed", volInt, MediaSessionService.CurrentIsLiked, AppAudioControl.LastTarget), AppJson.Context.CommandResponse);
        }
        if (path == "/sound")
        {
            string? soundName = q["name"];
            double vol = 0.5;
            if (double.TryParse(q["vol"], NumberStyles.Float, CultureInfo.InvariantCulture, out double parsedVol))
            {
                vol = Math.Max(0.01, Math.Min(1.0, parsedVol));
            }
            bool force = q["force"] == "1";
            if (double.TryParse(q["duck"], NumberStyles.Float, CultureInfo.InvariantCulture, out double parsedDuck))
            {
                double duckVal = Math.Max(0.0, Math.Min(1.0, parsedDuck));
                if (duckVal > 0.01)
                {
                    int dur = soundName != null && SoundEngine.Durations.TryGetValue(soundName, out int d) ? d : 800;
                    AppAudioControl.DuckAllAudio((float)duckVal, dur);
                }
            }
            if (soundName != null) SoundEngine.Play(soundName, vol, force);
            return Json(new SoundResponse("ok"), AppJson.Context.SoundResponse);
        }
        if (path == "/update/start")
        {
            Updater.Start(q["dir"], q["path"]);
            return Json(Updater.Status, AppJson.Context.UpdateStatus);
        }
        if (path == "/update/test")
        {
            Updater.SetTest(q["on"] == "1", q["fail"] == "1");
            return Json(Updater.Status, AppJson.Context.UpdateStatus);
        }
        if (path == "/update/status")
        {
            return Json(Updater.Status, AppJson.Context.UpdateStatus);
        }
        if (path == "/update/restart")
        {
            _ = Task.Run(async () => { await Task.Delay(300); Updater.Restart(); });
            return Json(Updater.Status, AppJson.Context.UpdateStatus);
        }
        if (path == "/fonts")
        {
            return Json(FontInstaller.Status, AppJson.Context.FontStatus);
        }
        if (path == "/fonts/install")
        {
            FontInstaller.Start();
            return Json(FontInstaller.Status, AppJson.Context.FontStatus);
        }
        if (path == "/open")
        {
            Updater.OpenReleasePage(q["url"]);
            return Json(new SoundResponse("ok"), AppJson.Context.SoundResponse);
        }
        if (path == "/reveal")
        {
            return Json(new SoundResponse(LogReveal.Reveal(MediaSessionService.ScriptsDirectory)), AppJson.Context.SoundResponse);
        }
        if (path == "/system")
        {
            return Json(SystemWatcher.Current, AppJson.Context.SystemInfo);
        }
        if (path == "/key")
        {
            bool ok = int.TryParse(q["vk"], out int vk) && KeyPress.Allowed(vk);
            string how = ok ? KeyPress.Tap(vk, q["global"] == "1") : "denied";
            return Json(new SoundResponse(how), AppJson.Context.SoundResponse);
        }
        if (path == "/level")
        {
            return Json(new LevelResponse(LevelMeter.Snapshot(), LevelMeter.Source, LevelMeter.Sessions, Math.Round(LevelMeter.Peak, 3)), AppJson.Context.LevelResponse);
        }
        if (path == "/lyrics")
        {
            double.TryParse(q["dur"], NumberStyles.Float, CultureInfo.InvariantCulture, out double dur);
            string text = await Lyrics.GetAsync(q["artist"] ?? "", q["title"] ?? "", q["album"] ?? "", dur);
            return new Reply(200, "text/plain; charset=utf-8", Encoding.UTF8.GetBytes(text));
        }
        if (path == "/diag/audio")
        {
            return Json(new AudioDiag("ok", MediaSessionService.CurrentAppId, MediaSessionService.CurrentFamily, AppAudioControl.DescribeSessions()), AppJson.Context.AudioDiag);
        }
        if (path == "/focus")
        {
            return Json(new FocusResponse("ok", AppAudioControl.IsDotaFocused()), AppJson.Context.FocusResponse);
        }
        if (path == "/status")
        {
            if (!string.IsNullOrWhiteSpace(q["dir"]))
            {
                MediaSessionService.SetScriptsDir(q["dir"]);
                FontInstaller.CopyToCheat(MediaSessionService.ScriptsDirectory);
                FileChannel.Start(MediaSessionService.ScriptsDirectory, Log);
            }
            if (q["likes"] != null) SpotifyFlags.SetEnabled(q["likes"]);
            return new Reply(200, "application/json; charset=utf-8", Encoding.UTF8.GetBytes(await StatusJsonAsync()));
        }
        return new Reply(404, "text/plain", Array.Empty<byte>());
    }
}
