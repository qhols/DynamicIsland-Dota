using System.Diagnostics;
using System.Globalization;
using System.Net;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.Json.Serialization.Metadata;

namespace MediaBridge;

public record CommandResponse(string status, int volume, bool is_liked);
public record FocusResponse(string status, bool focused);
public record SoundResponse(string status);
public record StatusResponse(string status, int sounds_loaded, string sound_output, string sound_error, string media_sessions);

[JsonSerializable(typeof(MediaInfo))]
[JsonSerializable(typeof(CommandResponse))]
[JsonSerializable(typeof(FocusResponse))]
[JsonSerializable(typeof(SoundResponse))]
[JsonSerializable(typeof(StatusResponse))]
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

    private static async Task Main()
    {
        string exeDir = AppContext.BaseDirectory;
        _logPath = ResolveLogPath(exeDir);

        CleanupOtherInstances();

        using var singleInstanceMutex = new Mutex(false, "Global\\DynamicIslandMediaBridge");
        if (!singleInstanceMutex.WaitOne(0))
        {
            return;
        }

        SoundEngine.Init(exeDir);
        AppAudioControl.StartFocusWatcher();

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

            _ = HandleRequestAsync(context);
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
                var data = await MediaSessionService.GetMediaInfoAsync() ?? MediaSessionService.LastValidData ?? new MediaInfo
                {
                    is_playing = false,
                    volume = 100,
                    is_liked = MediaSessionService.CurrentIsLiked
                };
                await WriteJsonAsync(response, data, AppJson.Context.MediaInfo);
            }
            else if (path is "/media/playpause" or "/media/next" or "/media/prev" or "/media/shuffle"
                     or "/media/repeat" or "/media/like" or "/media/volup" or "/media/voldown")
            {
                string cmd = path[7..];
                bool bump = request.QueryString["bump"] == "1";
                bool noSound = request.QueryString["nosound"] == "1";

                if ((cmd == "volup" || cmd == "voldown") && !noSound)
                {
                    SoundEngine.Play(bump ? "wheel_boundary_bump" : "wheel_notch", bump ? 0.65 : 0.45);
                }

                float? curVol = await MediaSessionService.HandleMediaCommandAsync(cmd);
                curVol ??= AppAudioControl.GetAppVolume();
                int volInt = (int)Math.Round(curVol.Value * 100);

                await WriteJsonAsync(response, new CommandResponse("ok", volInt, MediaSessionService.CurrentIsLiked), AppJson.Context.CommandResponse);
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
            else if (path == "/focus")
            {
                await WriteJsonAsync(response, new FocusResponse("ok", AppAudioControl.IsDotaFocused()), AppJson.Context.FocusResponse);
            }
            else if (path == "/status")
            {
                await WriteJsonAsync(response, new StatusResponse("ok", SoundEngine.LoadedCount, SoundEngine.OutputKind, SoundEngine.LastError, MediaSessionService.ManagerState), AppJson.Context.StatusResponse);
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
