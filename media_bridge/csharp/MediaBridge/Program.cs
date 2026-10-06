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
public record StatusResponse(string status, string version, string latest_version, int sounds_loaded, string sound_output, string sound_error, string media_sessions, string spotify_debug, string yandex_debug, bool fonts_ok);

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

            if (path == "/media")
            {
                MediaSessionService.SetScriptsDir(request.QueryString["dir"]);
                FontInstaller.CopyToCheat(MediaSessionService.ScriptsDirectory);
                SpotifyFlags.SetEnabled(request.QueryString["likes"]);
                var data = await MediaSessionService.GetMediaInfoAsync() ?? new MediaInfo
                {
                    is_playing = false,
                    volume = -100,
                    is_liked = MediaSessionService.CurrentIsLiked
                };
                await WriteJsonAsync(response, data, AppJson.Context.MediaInfo);
            }
            else if (path == "/media/seek")
            {
                bool ok = false;
                if (double.TryParse(request.QueryString["pos"], NumberStyles.Float, CultureInfo.InvariantCulture, out double pos))
                {
                    ok = await MediaSessionService.SeekAsync(pos);
                }
                await WriteJsonAsync(response, new SoundResponse(ok ? "ok" : "failed"), AppJson.Context.SoundResponse);
            }
            else if (path == "/playlist/open")
            {
                var (status, items, selected) = await YandexPlaylist.OpenAsync();
                await WriteJsonAsync(response, new PlaylistResponse(status, items.Select(Uri.EscapeDataString).ToArray(), selected), AppJson.Context.PlaylistResponse);
            }
            else if (path == "/playlist/add")
            {
                bool ok = int.TryParse(request.QueryString["index"], out int index) && await YandexPlaylist.AddAsync(index);
                await WriteJsonAsync(response, new SoundResponse(ok ? "ok" : "failed"), AppJson.Context.SoundResponse);
            }
            else if (path == "/playlist/remove")
            {
                bool ok = int.TryParse(request.QueryString["index"], out int index) && await YandexPlaylist.RemoveAsync(index);
                await WriteJsonAsync(response, new SoundResponse(ok ? "ok" : "failed"), AppJson.Context.SoundResponse);
            }
            else if (path is "/media/playpause" or "/media/next" or "/media/prev" or "/media/shuffle"
                     or "/media/repeat" or "/media/like" or "/media/volup" or "/media/voldown")
            {
                string cmd = path[7..];
                bool bump = request.QueryString["bump"] == "1";
                bool noSound = request.QueryString["nosound"] == "1";

                if ((cmd == "volup" || cmd == "voldown") && !noSound)
                {
                    double notchVol = bump ? 0.65 : 0.45;
                    if (double.TryParse(request.QueryString["vol"], NumberStyles.Float, CultureInfo.InvariantCulture, out double parsedNotch))
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

                await WriteJsonAsync(response, new CommandResponse(commandOk ? "ok" : "failed", volInt, MediaSessionService.CurrentIsLiked, AppAudioControl.LastTarget), AppJson.Context.CommandResponse);
            }
            else if (path == "/sound")
            {
                string? soundName = request.QueryString["name"];
                double vol = 0.5;
                if (double.TryParse(request.QueryString["vol"], NumberStyles.Float, CultureInfo.InvariantCulture, out double parsedVol))
                {
                    vol = Math.Max(0.01, Math.Min(1.0, parsedVol));
                }
                bool force = request.QueryString["force"] == "1";

                if (double.TryParse(request.QueryString["duck"], NumberStyles.Float, CultureInfo.InvariantCulture, out double parsedDuck))
                {
                    double duckVal = Math.Max(0.0, Math.Min(1.0, parsedDuck));
                    if (duckVal > 0.01)
                    {
                        int dur = soundName != null && SoundEngine.Durations.TryGetValue(soundName, out int d) ? d : 800;
                        AppAudioControl.DuckAllAudio((float)duckVal, dur);
                    }
                }

                if (soundName != null) SoundEngine.Play(soundName, vol, force);
                await WriteJsonAsync(response, new SoundResponse("ok"), AppJson.Context.SoundResponse);
            }
            else if (path == "/update/start")
            {
                Updater.Start(request.QueryString["dir"], request.QueryString["path"]);
                await WriteJsonAsync(response, Updater.Status, AppJson.Context.UpdateStatus);
            }
            else if (path == "/update/test")
            {
                Updater.SetTest(request.QueryString["on"] == "1", request.QueryString["fail"] == "1");
                await WriteJsonAsync(response, Updater.Status, AppJson.Context.UpdateStatus);
            }
            else if (path == "/update/status")
            {
                await WriteJsonAsync(response, Updater.Status, AppJson.Context.UpdateStatus);
            }
            else if (path == "/update/restart")
            {
                await WriteJsonAsync(response, Updater.Status, AppJson.Context.UpdateStatus);
                _ = Task.Run(async () => { await Task.Delay(300); Updater.Restart(); });
            }
            else if (path == "/fonts")
            {
                await WriteJsonAsync(response, FontInstaller.Status, AppJson.Context.FontStatus);
            }
            else if (path == "/fonts/install")
            {
                FontInstaller.Start();
                await WriteJsonAsync(response, FontInstaller.Status, AppJson.Context.FontStatus);
            }
            else if (path == "/open")
            {
                Updater.OpenReleasePage(request.QueryString["url"]);
                await WriteJsonAsync(response, new SoundResponse("ok"), AppJson.Context.SoundResponse);
            }
            else if (path == "/reveal")
            {
                await WriteJsonAsync(response, new SoundResponse(LogReveal.Reveal(MediaSessionService.ScriptsDirectory)), AppJson.Context.SoundResponse);
            }
            else if (path == "/system")
            {
                await WriteJsonAsync(response, SystemWatcher.Current, AppJson.Context.SystemInfo);
            }
            else if (path == "/key")
            {
                bool ok = int.TryParse(request.QueryString["vk"], out int vk) && KeyPress.Allowed(vk);
                string how = ok ? KeyPress.Tap(vk, request.QueryString["global"] == "1") : "denied";
                await WriteJsonAsync(response, new SoundResponse(how), AppJson.Context.SoundResponse);
            }
            else if (path == "/level")
            {
                await WriteJsonAsync(response, new LevelResponse(LevelMeter.Snapshot(), LevelMeter.Source, LevelMeter.Sessions, Math.Round(LevelMeter.Peak, 3)), AppJson.Context.LevelResponse);
            }
            else if (path == "/lyrics")
            {
                double.TryParse(request.QueryString["dur"], NumberStyles.Float, CultureInfo.InvariantCulture, out double dur);
                string text = await Lyrics.GetAsync(request.QueryString["artist"] ?? "", request.QueryString["title"] ?? "", request.QueryString["album"] ?? "", dur);
                byte[] buffer = Encoding.UTF8.GetBytes(text);
                response.ContentType = "text/plain; charset=utf-8";
                response.ContentLength64 = buffer.Length;
                await response.OutputStream.WriteAsync(buffer);
                response.OutputStream.Close();
            }
            else if (path == "/diag/audio")
            {
                await WriteJsonAsync(response, new AudioDiag("ok", MediaSessionService.CurrentAppId, MediaSessionService.CurrentFamily, AppAudioControl.DescribeSessions()), AppJson.Context.AudioDiag);
            }
            else if (path == "/focus")
            {
                await WriteJsonAsync(response, new FocusResponse("ok", AppAudioControl.IsDotaFocused()), AppJson.Context.FocusResponse);
            }
            else if (path == "/status")
            {
                await WriteJsonAsync(response, new StatusResponse("ok", UpdateChecker.BridgeVersion, Updater.TestMode ? "v9.9.9" : UpdateChecker.LatestTag, SoundEngine.LoadedCount, SoundEngine.OutputKind, SoundEngine.LastError, MediaSessionService.ManagerState, await SpotifyFlags.DebugStateAsync(), await YandexLike.DebugStateAsync(), FontInstaller.Installed), AppJson.Context.StatusResponse);
            }
            else
            {
                response.StatusCode = 404;
                response.OutputStream.Close();
            }
        }
        catch (Exception ex)
        {
            Log(ex.ToString());
            try { response.OutputStream.Close(); } catch { }
        }
    }

    private static async Task WriteJsonAsync<T>(HttpListenerResponse response, T data, JsonTypeInfo<T> typeInfo)
    {
        byte[] buffer = JsonSerializer.SerializeToUtf8Bytes(data, typeInfo);
        response.ContentType = "application/json; charset=utf-8";
        response.ContentLength64 = buffer.Length;
        await response.OutputStream.WriteAsync(buffer);
        response.OutputStream.Close();
    }
}
