using System.Drawing;
using System.Drawing.Imaging;
using Windows.Foundation;
using Windows.Media;
using Windows.Media.Control;
using Windows.Storage.Streams;

namespace MediaBridge;

public sealed class MediaInfo
{
    public bool is_playing { get; set; }
    public string title { get; set; } = "";
    public string artist { get; set; } = "";
    public string album { get; set; } = "";
    public string app { get; set; } = "";
    public int position { get; set; }
    public int duration { get; set; }
    public string cover_path { get; set; } = "";
    public string cover_jpg { get; set; } = "";
    public string cover_base64 { get; set; } = "";
    public int cover_ver { get; set; }
    public bool has_cover { get; set; }
    public int[] cover_color { get; set; } = { 255, 45, 85 };
    public double[] waveform { get; set; } = { 0, 0, 0, 0, 0 };
    public int volume { get; set; } = 100;
    public bool shuffle { get; set; }
    public int repeat { get; set; }
    public bool is_liked { get; set; }
}

internal static class WinRtAsync
{
    public static async Task<T?> WithTimeout<T>(IAsyncOperation<T> op, int timeoutMs)
    {
        try
        {
            var task = op.AsTask();
            var completed = await Task.WhenAny(task, Task.Delay(timeoutMs));
            if (completed != task) return default;
            return await task;
        }
        catch
        {
            return default;
        }
    }
}

public static class MediaSessionService
{
    private static readonly string TempDir = Path.Combine(Path.GetTempPath(), "dynamic_island_covers");
    private const string ScriptsDir = @"C:\Umbrella\scripts";
    private static readonly string UmbrellaDir = Path.Combine(ScriptsDir, "dynamic_island_covers");
    private static bool _coverDirsReady;

    private static void PrepareCoverDirs()
    {
        if (_coverDirsReady) return;
        _coverDirsReady = true;
        try { Directory.CreateDirectory(TempDir); } catch { }
        if (Directory.Exists(ScriptsDir))
        {
            try { Directory.CreateDirectory(UmbrellaDir); } catch { }
            foreach (var dir in new[] { ScriptsDir, UmbrellaDir, Path.GetTempPath(), TempDir })
            {
                try
                {
                    foreach (var f in Directory.GetFiles(dir, "dynamic_island_cover*.*")) File.Delete(f);
                }
                catch { }
            }
        }
    }

    private static void DropOldCovers(string dir, int keepVer)
    {
        try
        {
            if (!Directory.Exists(dir)) return;
            string keep = $"dynamic_island_cover_{keepVer}.";
            string prev = $"dynamic_island_cover_{keepVer - 1}.";
            foreach (var f in Directory.GetFiles(dir, "dynamic_island_cover*.*"))
            {
                string name = Path.GetFileName(f);
                if (name.StartsWith(keep, StringComparison.Ordinal) || name.StartsWith(prev, StringComparison.Ordinal)) continue;
                File.Delete(f);
            }
        }
        catch { }
    }

    private static string _coverJpg = "";
    private static string _coverPng = "";
    private static string _lastSavedTrack = "";
    private static int _coverVersion;
    private static string _coverBase64 = "";
    private static int[] _coverColor = { 255, 45, 85 };
    private static bool _hasCover;
    private static MediaInfo? _lastValidData;
    public static bool CurrentIsLiked;

    private static string _coverAttemptTrack = "";
    private static int _coverAttemptCount;
    private static DateTime _lastCoverAttempt = DateTime.MinValue;
    private static volatile bool _coverFetchInFlight;
    private const int MaxCoverAttempts = 6;
    private static readonly TimeSpan CoverRetryInterval = TimeSpan.FromSeconds(1.5);

    private static int _audioInactiveStreak;
    private const int AudioInactiveStreakThreshold = 3;

    private static GlobalSystemMediaTransportControlsSessionManager? _manager;
    private static Task<GlobalSystemMediaTransportControlsSessionManager?>? _managerRequest;
    private static readonly object ManagerLock = new();
    private static DateTime _managerRetryAfter = DateTime.MinValue;

    public static string ManagerState { get; private set; } = "";

    private static async Task<GlobalSystemMediaTransportControlsSessionManager?> GetManagerAsync()
    {
        var cached = _manager;
        if (cached != null) return cached;

        Task<GlobalSystemMediaTransportControlsSessionManager?> request;
        lock (ManagerLock)
        {
            if (_managerRequest == null)
            {
                if (DateTime.UtcNow < _managerRetryAfter) return null;
                _managerRequest = WinRtAsync.WithTimeout(GlobalSystemMediaTransportControlsSessionManager.RequestAsync(), 1500);
            }
            request = _managerRequest;
        }

        var mgr = await request;
        lock (ManagerLock)
        {
            if (mgr != null)
            {
                _manager = mgr;
                ManagerState = "ok";
            }
            else
            {
                ManagerState = "timeout";
                _managerRetryAfter = DateTime.UtcNow.AddSeconds(10);
            }
            if (ReferenceEquals(_managerRequest, request)) _managerRequest = null;
        }
        return mgr;
    }

    private static void DropManager()
    {
        lock (ManagerLock)
        {
            _manager = null;
            ManagerState = "lost";
        }
    }

    private static double _posAnchorSeconds;
    private static DateTime _posAnchorWallClock = DateTime.UtcNow;
    private static double _lastRawPos = double.MinValue;
    private static string _posAnchorTrack = "";

    private static string GetMediaSessionFamily(GlobalSystemMediaTransportControlsSession? session)
    {
        if (session == null) return "";
        string appId = session.SourceAppUserModelId?.ToLowerInvariant() ?? "";
        if (appId.Contains("dotify")) return "dotify";
        if (appId.Contains("spotify")) return "spotify";
        if (appId.Contains("yandex")) return "yandex";
        if (appId.Contains("aimp")) return "aimp";
        if (appId.Contains("foobar")) return "foobar";
        if (appId.Contains("apple") || appId.Contains("itunes")) return "apple";
        if (appId.Contains("zen") || appId == "f0dc299d809b9700") return "zen";
        if (appId.Contains("chrome")) return "chrome";
        if (appId.Contains("edge") || appId.Contains("msedge")) return "msedge";
        if (appId.Contains("firefox")) return "firefox";
        if (appId.Contains("opera")) return "opera";
        if (appId.Contains("brave")) return "brave";
        if (appId.Contains("vivaldi")) return "vivaldi";
        return "";
    }

    private static GlobalSystemMediaTransportControlsSession? FindBestSession(GlobalSystemMediaTransportControlsSessionManager? mgr)
    {
        if (mgr == null) return null;

        var sessions = mgr.GetSessions();
        if (sessions == null || sessions.Count == 0) return mgr.GetCurrentSession();

        GlobalSystemMediaTransportControlsSession? dedicatedPlaying = null, dedicatedPaused = null;
        GlobalSystemMediaTransportControlsSession? browserPlaying = null, browserPaused = null;
        GlobalSystemMediaTransportControlsSession? anyPlaying = null, anyPaused = null;

        foreach (var s in sessions)
        {
            string appId = s.SourceAppUserModelId?.ToLowerInvariant() ?? "";
            var pb = s.GetPlaybackInfo();
            bool isPlaying = pb != null && pb.PlaybackStatus == GlobalSystemMediaTransportControlsSessionPlaybackStatus.Playing;

            bool isBrowser = appId.Contains("zen") || appId.Contains("chrome") || appId.Contains("edge") ||
                              appId.Contains("msedge") || appId.Contains("firefox") || appId.Contains("opera") ||
                              appId.Contains("brave") || appId.Contains("vivaldi") || appId == "f0dc299d809b9700";

            bool isDedicated = !isBrowser && (appId.Contains("dotify") || appId.Contains("spotify") ||
                                appId.Contains("yandex") || appId.Contains("applemusic") ||
                                appId.Contains("itunes") || appId.Contains("aimp") ||
                                appId.Contains("foobar") || appId.Contains("tidal") ||
                                appId.Contains("deezer") || appId.Contains("winamp") ||
                                appId.Contains("musicbee"));

            if (isDedicated)
            {
                if (isPlaying) dedicatedPlaying ??= s; else dedicatedPaused ??= s;
            }
            else if (isBrowser)
            {
                if (isPlaying) browserPlaying ??= s; else browserPaused ??= s;
            }
            else
            {
                if (isPlaying) anyPlaying ??= s; else anyPaused ??= s;
            }
        }

        if (dedicatedPlaying != null) return dedicatedPlaying;
        if (dedicatedPaused != null) return dedicatedPaused;
        if (browserPlaying != null) return browserPlaying;
        if (anyPlaying != null) return anyPlaying;
        if (browserPaused != null) return browserPaused;
        if (anyPaused != null) return anyPaused;

        return mgr.GetCurrentSession() ?? sessions[0];
    }

    private static int[] Legible(double r, double g, double b)
    {
        double max = Math.Max(r, Math.Max(g, b));
        double min = Math.Min(r, Math.Min(g, b));
        if (max <= 0) return new[] { 235, 235, 245 };
        double s = (max - min) / max;
        double v = max / 255.0;
        double ns = Math.Clamp(s, 0.35, 0.85);
        double nv = Math.Max(v, 0.85);
        double scale = nv * 255.0 / max;
        double[] c = { r * scale, g * scale, b * scale };
        double top = nv * 255.0;
        double bottom = top * (1 - ns);
        double curBottom = min * scale;
        double span = top - curBottom;
        for (int i = 0; i < 3; i++)
        {
            double t = span <= 0 ? 1 : (c[i] - curBottom) / span;
            c[i] = bottom + (top - bottom) * t;
        }
        return new[] { (int)Math.Round(c[0]), (int)Math.Round(c[1]), (int)Math.Round(c[2]) };
    }

    private static int[] ExtractDominantColor(string imagePath)
    {
        try
        {
            if (!File.Exists(imagePath)) return new[] { 255, 45, 85 };
            using var bmp = new Bitmap(imagePath);
            const int bins = 36;
            var weight = new double[bins];
            var sumR = new double[bins];
            var sumG = new double[bins];
            var sumB = new double[bins];
            int total = 0;
            int step = Math.Max(1, Math.Min(bmp.Width, bmp.Height) / 48);
            for (int x = 0; x < bmp.Width; x += step)
            {
                for (int y = 0; y < bmp.Height; y += step)
                {
                    var p = bmp.GetPixel(x, y);
                    total++;
                    double r = p.R / 255.0, g = p.G / 255.0, b = p.B / 255.0;
                    double max = Math.Max(r, Math.Max(g, b));
                    double min = Math.Min(r, Math.Min(g, b));
                    double s = max <= 0 ? 0 : (max - min) / max;
                    if (s < 0.25 || max < 0.2) continue;
                    double h;
                    double d = max - min;
                    if (max == r) h = 60 * (((g - b) / d) % 6);
                    else if (max == g) h = 60 * (((b - r) / d) + 2);
                    else h = 60 * (((r - g) / d) + 4);
                    if (h < 0) h += 360;
                    int bin = (int)(h / (360.0 / bins)) % bins;
                    double w = s * s * max;
                    weight[bin] += w;
                    sumR[bin] += p.R * w;
                    sumG[bin] += p.G * w;
                    sumB[bin] += p.B * w;
                }
            }
            double all = 0;
            for (int i = 0; i < bins; i++) all += weight[i];
            if (total == 0 || all / total < 0.02) return new[] { 235, 235, 245 };
            int best = 0;
            double bestW = -1;
            for (int i = 0; i < bins; i++)
            {
                double w = weight[(i + bins - 1) % bins] + weight[i] + weight[(i + 1) % bins];
                if (w > bestW) { bestW = w; best = i; }
            }
            double cw = 0, cr = 0, cg = 0, cb = 0;
            for (int k = -1; k <= 1; k++)
            {
                int i = (best + k + bins) % bins;
                cw += weight[i]; cr += sumR[i]; cg += sumG[i]; cb += sumB[i];
            }
            return Legible(cr / cw, cg / cw, cb / cw);
        }
        catch
        {
            return new[] { 255, 45, 85 };
        }
    }

    private static async Task<bool> FetchCoverAsync(GlobalSystemMediaTransportControlsSessionMediaProperties? props)
    {
        PrepareCoverDirs();
        int ver = _coverVersion + 1;
        string targetJpg = Path.Combine(TempDir, $"dynamic_island_cover_{ver}.jpg");
        string targetPng = Path.Combine(TempDir, $"dynamic_island_cover_{ver}.png");

        bool umbAvailable = Directory.Exists(UmbrellaDir);
        string umbJpg = umbAvailable ? Path.Combine(UmbrellaDir, $"dynamic_island_cover_{ver}.jpg") : "";
        string umbPng = umbAvailable ? Path.Combine(UmbrellaDir, $"dynamic_island_cover_{ver}.png") : "";

        bool saved = false;

        if (props?.Thumbnail != null)
        {
            try
            {
                var stream = await WinRtAsync.WithTimeout(props.Thumbnail.OpenReadAsync(), 600);
                if (stream != null)
                {
                    using var readStream = stream.AsStreamForRead();
                    using var ms = new MemoryStream();
                    await readStream.CopyToAsync(ms);
                    byte[] bytes = ms.ToArray();

                    File.WriteAllBytes(targetJpg, bytes);
                    if (!string.IsNullOrEmpty(umbJpg))
                    {
                        try
                        {
                            File.WriteAllBytes(umbJpg, bytes);
                        }
                        catch { }
                    }

                    try
                    {
                        using var imgMs = new MemoryStream(bytes);
                        using var img = Image.FromStream(imgMs);
                        img.Save(targetPng, ImageFormat.Png);
                        if (!string.IsNullOrEmpty(umbPng))
                        {
                            img.Save(umbPng, ImageFormat.Png);
                        }
                    }
                    catch { }

                    saved = true;
                }
            }
            catch { }
        }

        if (saved && File.Exists(targetJpg))
        {
            _coverVersion = ver;
            try
            {
                if (umbAvailable) DropOldCovers(UmbrellaDir, ver);
                DropOldCovers(TempDir, ver);

                byte[] fileBytes = File.Exists(targetPng) ? File.ReadAllBytes(targetPng) : File.ReadAllBytes(targetJpg);
                _coverBase64 = Convert.ToBase64String(fileBytes);
                _coverColor = ExtractDominantColor(targetJpg);
                _coverJpg = targetJpg;
                _coverPng = targetPng;
                _hasCover = true;
                return true;
            }
            catch
            {
                _coverBase64 = "";
                _coverJpg = "";
                _coverPng = "";
                _hasCover = false;
                return false;
            }
        }
        else
        {
            _coverBase64 = "";
            _coverJpg = "";
            _coverPng = "";
            _hasCover = false;
            return false;
        }
    }

    public static async Task<MediaInfo?> GetMediaInfoAsync()
    {
        try
        {
            var mgr = await GetManagerAsync();
            if (mgr == null) return _lastValidData;

            GlobalSystemMediaTransportControlsSession? session;
            try
            {
                session = FindBestSession(mgr);
            }
            catch
            {
                DropManager();
                return _lastValidData;
            }
            if (session == null) return _lastValidData;

            var props = await WinRtAsync.WithTimeout(session.TryGetMediaPropertiesAsync(), 350);
            if (props == null) return _lastValidData;

            var playback = session.GetPlaybackInfo();
            var timeline = session.GetTimelineProperties();

            bool isPlaying = playback != null && playback.PlaybackStatus == GlobalSystemMediaTransportControlsSessionPlaybackStatus.Playing;
            bool isShuffle = playback?.IsShuffleActive ?? false;
            int repeatMode = playback?.AutoRepeatMode switch
            {
                MediaPlaybackAutoRepeatMode.List => 1,
                MediaPlaybackAutoRepeatMode.Track => 2,
                _ => 0
            };

            string title = props.Title?.Trim() ?? "";
            string artist = props.Artist?.Trim() ?? "";
            string album = props.AlbumTitle?.Trim() ?? "";
            string trackKeyForTiming = $"{artist} - {title}";

            int dur = timeline != null ? (int)timeline.EndTime.TotalSeconds : 0;
            int pos = 0;
            if (timeline != null)
            {
                double rawPos = timeline.Position.TotalSeconds;
                bool trackChanged = trackKeyForTiming != _posAnchorTrack;
                bool rawPosChanged = Math.Abs(rawPos - _lastRawPos) > 0.05;

                if (!isPlaying || trackChanged || rawPosChanged)
                {
                    _posAnchorSeconds = rawPos;
                    _posAnchorWallClock = DateTime.UtcNow;
                    _posAnchorTrack = trackKeyForTiming;
                }
                _lastRawPos = rawPos;

                double posSeconds = _posAnchorSeconds;
                if (isPlaying)
                {
                    posSeconds += (DateTime.UtcNow - _posAnchorWallClock).TotalSeconds;
                }
                pos = (int)Math.Max(0, Math.Min(posSeconds, dur > 0 ? dur : posSeconds));
            }
            string trackKey = trackKeyForTiming;

            if (trackKey != _lastSavedTrack && title != "")
            {
                if (trackKey != _coverAttemptTrack)
                {
                    _coverAttemptTrack = trackKey;
                    _coverAttemptCount = 0;
                    _lastCoverAttempt = DateTime.MinValue;
                }

                bool dueForAttempt = !_coverFetchInFlight &&
                                      _coverAttemptCount < MaxCoverAttempts &&
                                      DateTime.UtcNow - _lastCoverAttempt >= CoverRetryInterval;

                if (dueForAttempt)
                {
                    _coverAttemptCount++;
                    _lastCoverAttempt = DateTime.UtcNow;
                    _coverFetchInFlight = true;
                    string attemptTrack = trackKey;
                    var propsForFetch = props;
                    _ = Task.Run(async () =>
                    {
                        try
                        {
                            if (await FetchCoverAsync(propsForFetch))
                            {
                                _lastSavedTrack = attemptTrack;
                            }
                        }
                        finally
                        {
                            _coverFetchInFlight = false;
                        }
                    });
                }
            }

            string appId = session.SourceAppUserModelId ?? "";
            bool hasCover = _hasCover && (_coverBase64 != "" || (_coverPng != "" && File.Exists(_coverPng)));
            string targetFam = GetMediaSessionFamily(session);
            if (isPlaying && targetFam != "" && AppAudioControl.IsMusicPlayerFamily(targetFam))
            {
                int audioState = AppAudioControl.GetFamilyAudioState(targetFam);
                if (audioState == 0)
                {
                    _audioInactiveStreak++;
                    if (_audioInactiveStreak >= AudioInactiveStreakThreshold) isPlaying = false;
                }
                else
                {
                    _audioInactiveStreak = 0;
                }
            }
            else
            {
                _audioInactiveStreak = 0;
            }

            float[] bars = isPlaying ? Meter.GetBars() : new float[] { 0, 0, 0, 0, 0 };
            float appVol = AppAudioControl.GetAppVolume(targetFam);
            int volInt = (int)Math.Round(appVol * 100);

            var res = new MediaInfo
            {
                is_playing = isPlaying,
                title = title,
                artist = artist,
                album = album,
                app = appId,
                position = pos,
                duration = dur,
                cover_path = _coverPng.Replace('\\', '/'),
                cover_jpg = _coverJpg.Replace('\\', '/'),
                cover_base64 = _coverBase64,
                cover_ver = hasCover ? _coverVersion : 0,
                has_cover = hasCover,
                cover_color = _coverColor,
                waveform = Array.ConvertAll(bars, x => (double)x),
                volume = volInt,
                shuffle = isShuffle,
                repeat = repeatMode,
                is_liked = CurrentIsLiked
            };

            if (title != "" || isPlaying) _lastValidData = res;
            return res;
        }
        catch
        {
            return _lastValidData;
        }
    }

    public static MediaInfo? LastValidData => _lastValidData;

    public static async Task<bool> SeekAsync(double seconds)
    {
        try
        {
            var mgr = await GetManagerAsync();
            if (mgr == null) return false;
            GlobalSystemMediaTransportControlsSession? session;
            try { session = FindBestSession(mgr); }
            catch { DropManager(); return false; }
            if (session == null) return false;

            var timeline = session.GetTimelineProperties();
            double start = timeline?.StartTime.TotalSeconds ?? 0;
            double end = timeline?.EndTime.TotalSeconds ?? 0;
            double target = Math.Max(0.0, seconds);
            if (end > start) target = Math.Min(target, Math.Max(0.0, end - start - 0.5));

            long ticks = Math.Max(1_000_000L, (long)((start + target) * 10_000_000));
            bool ok = await WinRtAsync.WithTimeout(session.TryChangePlaybackPositionAsync(ticks), 800);
            if (ok)
            {
                _posAnchorSeconds = target;
                _posAnchorWallClock = DateTime.UtcNow;
            }
            return ok;
        }
        catch
        {
            return false;
        }
    }

    public static async Task<float?> HandleMediaCommandAsync(string cmd)
    {
        try
        {
            var mgr = await GetManagerAsync();
            GlobalSystemMediaTransportControlsSession? session = null;
            if (mgr != null)
            {
                try { session = FindBestSession(mgr); }
                catch { DropManager(); }
            }
            string targetFam = session != null ? GetMediaSessionFamily(session) : "";

            if (cmd == "volup") return AppAudioControl.StepAppVolume(0.04f, targetFam);
            if (cmd == "voldown") return AppAudioControl.StepAppVolume(-0.04f, targetFam);

            if (cmd == "like")
            {
                bool? res = await SpotifyLike.ToggleLikeAsync();
                CurrentIsLiked = res ?? !CurrentIsLiked;
                return null;
            }

            if (session != null)
            {
                switch (cmd)
                {
                    case "playpause":
                        var pb = session.GetPlaybackInfo();
                        var status = pb?.PlaybackStatus;
                        IAsyncOperation<bool>? t = null;
                        if (status == GlobalSystemMediaTransportControlsSessionPlaybackStatus.Playing)
                            t = session.TryPauseAsync();
                        else if (status is GlobalSystemMediaTransportControlsSessionPlaybackStatus.Paused or GlobalSystemMediaTransportControlsSessionPlaybackStatus.Stopped)
                            t = session.TryPlayAsync();
                        t ??= session.TryTogglePlayPauseAsync();
                        await WinRtAsync.WithTimeout(t, 350);
                        break;
                    case "next":
                        await WinRtAsync.WithTimeout(session.TrySkipNextAsync(), 350);
                        break;
                    case "prev":
                        await WinRtAsync.WithTimeout(session.TrySkipPreviousAsync(), 350);
                        break;
                    case "shuffle":
                        try
                        {
                            var pbS = session.GetPlaybackInfo();
                            bool cur = pbS?.IsShuffleActive ?? false;
                            await WinRtAsync.WithTimeout(session.TryChangeShuffleActiveAsync(!cur), 350);
                        }
                        catch { }
                        break;
                    case "repeat":
                        try
                        {
                            var pbR = session.GetPlaybackInfo();
                            var curRep = pbR?.AutoRepeatMode ?? MediaPlaybackAutoRepeatMode.None;
                            var nextRep = curRep switch
                            {
                                MediaPlaybackAutoRepeatMode.None => MediaPlaybackAutoRepeatMode.List,
                                MediaPlaybackAutoRepeatMode.List => MediaPlaybackAutoRepeatMode.Track,
                                _ => MediaPlaybackAutoRepeatMode.None
                            };
                            await WinRtAsync.WithTimeout(session.TryChangeAutoRepeatModeAsync(nextRep), 350);
                        }
                        catch { }
                        break;
                }
            }
        }
        catch { }
        return null;
    }
}
