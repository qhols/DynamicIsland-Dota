using System.Globalization;

namespace MediaBridge;

public static class YandexLike
{
    public const int Port = 9223;
    public const string Flag = "--remote-debugging-port=9223";
    private const string PageUrl = "music-application://";
    private const string Button = "const b = document.querySelector('[data-test-id=\"PLAYERBAR_DESKTOP\"] [data-test-id=\"LIKE_BUTTON\"]')" +
        " || document.querySelector('[data-test-id=\"VIBE_PLAYERBAR\"] [data-test-id=\"LIKE_BUTTON\"]');";

    private const string Slider = "const s = document.querySelector('[data-test-id=\"PLAYERBAR_DESKTOP\"] [data-test-id=\"CHANGE_VOLUME_SLIDER\"]')" +
        " || document.querySelector('[data-test-id=\"VIBE_PLAYERBAR\"] [data-test-id=\"CHANGE_VOLUME_SLIDER\"]')" +
        " || document.querySelector('[data-test-id=\"CHANGE_VOLUME_SLIDER\"]');";

    private static string _state = "none";
    private static DateTime _stateAt = DateTime.MinValue;
    private static float _volume = -1f;
    private static DateTime _volumeAt = DateTime.MinValue;
    private static bool? _shuffle;
    private static int? _repeat;
    private static DateTime _modesAt = DateTime.MinValue;

    public static float? FreshVolume => _volume >= 0f && (DateTime.UtcNow - _volumeAt).TotalSeconds < 12 ? _volume : null;
    public static bool? FreshShuffle => (DateTime.UtcNow - _modesAt).TotalSeconds < 10 ? _shuffle : null;
    public static int? FreshRepeat => (DateTime.UtcNow - _modesAt).TotalSeconds < 10 ? _repeat : null;

    public static async Task<bool> ToggleModeAsync(string mode)
    {
        if (mode is not ("shuffle" or "repeat")) return false;
        string js = "(() => { const bar=document.querySelector('[data-test-id=\"PLAYERBAR_DESKTOP\"]') || document.querySelector('[data-test-id=\"VIBE_PLAYERBAR\"]'); if(!bar) return 'NO_PLAYER';" +
            " const buttons=[...bar.querySelectorAll('button')]; const mode='" + mode + "';" +
            " const b=buttons.find(e => { const key=[e.getAttribute('data-test-id'),e.getAttribute('aria-label'),e.getAttribute('title'),e.innerText].filter(Boolean).join(' ').toLowerCase();" +
            " return mode==='shuffle' ? /(shuffle|перемеш|случайн)/i.test(key) : /(repeat|повтор|зацикл)/i.test(key); });" +
            " if(!b || b.disabled) return 'NO_BUTTON'; b.click(); return 'OK'; })()";
        string? result = await DevTools.EvaluateAsync(Port, PageUrl, js);
        if (result != "OK") return false;
        if (mode == "shuffle") _shuffle = !(_shuffle ?? false);
        else _repeat = ((_repeat ?? 0) + 1) % 3;
        _modesAt = DateTime.UtcNow;
        return true;
    }

    private static void RememberVolume(string? text)
    {
        if (float.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out float v) && v >= 0f && v <= 1f)
        {
            _volume = v;
            _volumeAt = DateTime.UtcNow;
        }
    }

    public static async Task<float?> StepVolumeAsync(float delta)
    {
        string js = "(() => {" + Slider +
            "  if (!s) return 'NO_SLIDER';" +
            "  const cur = parseFloat(s.value) || 0;" +
            "  const next = Math.max(0, Math.min(1, Math.round((cur + (" + delta.ToString("0.###", CultureInfo.InvariantCulture) + ")) * 100) / 100));" +
            "  if (next !== cur) {" +
            "    Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(s, String(next));" +
            "    s.dispatchEvent(new Event('input', { bubbles: true }));" +
            "    s.dispatchEvent(new Event('change', { bubbles: true }));" +
            "  }" +
            "  return 'VOL|' + next;" +
            "})()";
        string? result = await DevTools.EvaluateAsync(Port, PageUrl, js);
        if (result == null || !result.StartsWith("VOL|", StringComparison.Ordinal)) return null;
        RememberVolume(result[4..]);
        return FreshVolume;
    }

    public static bool IsApp(string appId)
    {
        return appId.Contains("yandex", StringComparison.OrdinalIgnoreCase) && appId.Contains("music", StringComparison.OrdinalIgnoreCase);
    }

    public static async Task<string> DebugStateAsync()
    {
        if ((DateTime.UtcNow - _stateAt).TotalSeconds < 5) return _state;
        _stateAt = DateTime.UtcNow;
        if (!IsApp(MediaSessionService.CurrentAppId)) return _state = "none";
        return _state = await DevTools.HasPageAsync(Port, PageUrl) ? "ok" : "closed";
    }

    public static async Task<bool?> QueryAsync()
    {
        const string js = "(() => {" + Button + Slider +
            "  const like = !b ? 'NO_BUTTON' : (b.getAttribute('aria-pressed') === 'true' ? 'LIKED' : 'PLAIN');" +
            "  return like + '|' + (s ? s.value : '');" +
            "})()";
        string? result = await DevTools.EvaluateAsync(Port, PageUrl, js);
        if (result == null) return null;
        int cut = result.IndexOf('|');
        string like = cut >= 0 ? result[..cut] : result;
        if (cut >= 0) RememberVolume(result[(cut + 1)..]);
        if (like == "LIKED") return true;
        if (like == "PLAIN") return false;
        return null;
    }

    public static async Task<bool?> ToggleAsync()
    {
        const string js = "(() => {" + Button +
            "  if (!b || b.disabled) return 'NO_BUTTON';" +
            "  const was = b.getAttribute('aria-pressed') === 'true';" +
            "  b.click();" +
            "  return was ? 'REMOVED' : 'ADDED';" +
            "})()";
        string? result = await DevTools.EvaluateAsync(Port, PageUrl, js);
        if (result == "ADDED") return true;
        if (result == "REMOVED") return false;
        return null;
    }

    public static void Heal()
    {
        string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "YandexMusic");
        if (!Directory.Exists(dir)) return;

        string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        string[] folders =
        {
            Path.Combine(appData, @"Microsoft\Windows\Start Menu\Programs"),
            Path.Combine(appData, @"Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"),
            Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory)
        };
        string prefix = dir + Path.DirectorySeparatorChar;
        foreach (var folder in folders)
        {
            if (!Directory.Exists(folder)) continue;
            foreach (var link in Directory.EnumerateFiles(folder, "*.lnk"))
            {
                string name = Path.GetFileName(link);
                if (!name.Contains("ндекс", StringComparison.Ordinal) && !name.Contains("andex", StringComparison.OrdinalIgnoreCase)) continue;
                try
                {
                    SpotifyFlags.FixShortcut(link, Flag, target =>
                        target.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)
                        && !Path.GetFileName(target).StartsWith("Uninstall", StringComparison.OrdinalIgnoreCase));
                }
                catch { }
            }
        }
    }
}
