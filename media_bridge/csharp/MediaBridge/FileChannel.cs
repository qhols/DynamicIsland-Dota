using System.Collections.Specialized;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Web;

namespace MediaBridge;

internal static class FileChannel
{
    private static readonly object Sync = new();
    private static string _dir = "";
    private static bool _started;
    private static long _levelWantUntil;
    private static long _seq;
    private static Task _chain = Task.CompletedTask;

    public static string Dir => _dir;

    public static void Start(string scriptsDir, Action<string> log)
    {
        if (string.IsNullOrWhiteSpace(scriptsDir)) return;
        string dir;
        try
        {
            dir = Path.Combine(scriptsDir, "di_bridge");
            Directory.CreateDirectory(dir);
        }
        catch (Exception ex)
        {
            log("file channel: " + ex.Message);
            return;
        }
        lock (Sync)
        {
            _dir = dir;
            if (_started) return;
            _started = true;
        }
        _ = Task.Run(() => WriterLoop(log));
        _ = Task.Run(() => CommandLoop(log));
    }

    public static void WantLevel() => Interlocked.Exchange(ref _levelWantUntil, Environment.TickCount64 + 2500);

    private static readonly Regex Base64Field = new("\"cover_base64\":\"[^\"]*\"", RegexOptions.Compiled);

    private static async Task WriterLoop(Action<string> log)
    {
        string media = "", system = "", status = "", level = "";
        long nextMedia = 0, nextSystem = 0, nextStatus = 0, lastWrite = 0;
        int lastCoverVer = -1;
        string lastBody = "";
        while (true)
        {
            try
            {
                long now = Environment.TickCount64;
                if (now >= nextMedia)
                {
                    nextMedia = now + 200;
                    var info = await MediaSessionService.GetMediaInfoAsync() ?? new MediaInfo { is_playing = false, volume = -100, is_liked = MediaSessionService.CurrentIsLiked };
                    if (info.has_cover && info.cover_ver != lastCoverVer && !string.IsNullOrEmpty(info.cover_base64))
                    {
                        string ctmp = Path.Combine(_dir, "cover.tmp");
                        string cdst = Path.Combine(_dir, "cover.txt");
                        File.WriteAllText(ctmp, info.cover_ver.ToString() + "\n" + info.cover_base64, new UTF8Encoding(false));
                        try
                        {
                            File.Move(ctmp, cdst, true);
                            lastCoverVer = info.cover_ver;
                        }
                        catch (IOException) { }
                    }
                    media = Base64Field.Replace(JsonSerializer.Serialize(info, AppJson.Context.MediaInfo), "\"cover_base64\":\"\"");
                }
                if (now >= nextSystem)
                {
                    nextSystem = now + 400;
                    system = JsonSerializer.Serialize(SystemWatcher.Current, AppJson.Context.SystemInfo);
                }
                if (now >= nextStatus)
                {
                    nextStatus = now + 2000;
                    status = await Program.StatusJsonAsync();
                }
                if (Interlocked.Read(ref _levelWantUntil) > now)
                {
                    level = JsonSerializer.Serialize(new LevelResponse(LevelMeter.Snapshot(), LevelMeter.Source, LevelMeter.Sessions, Math.Round(LevelMeter.Peak, 3)), AppJson.Context.LevelResponse);
                }
                else
                {
                    level = "";
                }
                string body = "media\t" + media + "\nsystem\t" + system + "\nstatus\t" + status + "\nlevel\t" + level + "\n";
                if (body != lastBody || now - lastWrite > 400)
                {
                    long seq = Interlocked.Increment(ref _seq);
                    string text = "seq\t" + seq.ToString() + "\n" + body;
                    string dir = _dir;
                    string tmp = Path.Combine(dir, "state.tmp");
                    string dst = Path.Combine(dir, "state.txt");
                    File.WriteAllText(tmp, text, new UTF8Encoding(false));
                    try
                    {
                        File.Move(tmp, dst, true);
                        lastBody = body;
                        lastWrite = now;
                    }
                    catch (IOException) { }
                }
            }
            catch (Exception ex)
            {
                log("file channel writer: " + ex.Message);
                await Task.Delay(500);
            }
            await Task.Delay(50);
        }
    }

    private static async Task CommandLoop(Action<string> log)
    {
        while (true)
        {
            try
            {
                string dir = _dir;
                string src = Path.Combine(dir, "cmd.txt");
                string work = Path.Combine(dir, "cmd.work");
                if (File.Exists(src))
                {
                    bool moved = false;
                    try
                    {
                        File.Move(src, work, true);
                        moved = true;
                    }
                    catch (IOException) { }
                    if (moved)
                    {
                        string[] lines = File.ReadAllLines(work);
                        try { File.Delete(work); } catch { }
                        foreach (string raw in lines)
                        {
                            string line = raw.Trim();
                            if (line.Length == 0) continue;
                            int qi = line.IndexOf('?');
                            string path = (qi >= 0 ? line[..qi] : line).ToLowerInvariant();
                            NameValueCollection q = qi >= 0 ? HttpUtility.ParseQueryString(line[(qi + 1)..]) : new NameValueCollection();
                            if (path == "/levelwant")
                            {
                                WantLevel();
                                continue;
                            }
                            string p = path;
                            NameValueCollection qq = q;
                            async Task Run()
                            {
                                try { await Program.HandleCore(p, qq); }
                                catch (Exception ex) { log("file channel cmd " + p + ": " + ex.Message); }
                            }
                            if (p == "/sound")
                            {
                                _ = Task.Run(Run);
                            }
                            else
                            {
                                _chain = _chain.ContinueWith(_ => Run()).Unwrap();
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                log("file channel reader: " + ex.Message);
                await Task.Delay(300);
            }
            await Task.Delay(15);
        }
    }
}
