namespace MediaBridge;

public static class LikeState
{
    private static string _player = "";
    private static string _track = "";
    private static DateTime _nextQuery = DateTime.MinValue;
    private static DateTime _holdUntil = DateTime.MinValue;
    private static int _busy;

    public static string PlayerOf(string family, string appId)
    {
        if (YandexLike.IsApp(appId)) return "yandex";
        return family == "spotify" ? "spotify" : "";
    }

    public static void Tick(string player, string trackKey)
    {
        var now = DateTime.UtcNow;
        if (player != _player || trackKey != _track)
        {
            _player = player;
            _track = trackKey;
            MediaSessionService.CurrentIsLiked = false;
            _nextQuery = now.AddSeconds(0.5);
            _holdUntil = DateTime.MinValue;
        }
        if (player == "" || trackKey == "" || (player != "yandex" && !SpotifyFlags.Enabled)) return;
        if (now < _nextQuery || now < _holdUntil) return;
        if (Interlocked.CompareExchange(ref _busy, 1, 0) != 0) return;
        _nextQuery = now.AddSeconds(player == "yandex" ? 2.5 : 15);
        _ = Task.Run(async () =>
        {
            try
            {
                bool? liked = player == "yandex" ? await YandexLike.QueryAsync() : await SpotifyLike.QueryAsync();
                if (liked == null)
                {
                    _nextQuery = DateTime.UtcNow.AddSeconds(8);
                }
                else if (player == _player && trackKey == _track && DateTime.UtcNow >= _holdUntil)
                {
                    MediaSessionService.CurrentIsLiked = liked.Value;
                }
            }
            catch { }
            finally
            {
                Interlocked.Exchange(ref _busy, 0);
            }
        });
    }

    public static async Task<bool> ToggleAsync(string player)
    {
        if (player == "" || (player == "spotify" && !SpotifyFlags.Enabled)) return false;
        string track = _track;
        bool before = MediaSessionService.CurrentIsLiked;
        _holdUntil = DateTime.UtcNow.AddSeconds(3);
        bool? res = player == "yandex" ? await YandexLike.ToggleAsync() : await SpotifyLike.ToggleLikeAsync();
        if (player != _player || track != _track) return res != null;
        MediaSessionService.CurrentIsLiked = res ?? before;
        _holdUntil = DateTime.UtcNow.AddSeconds(1.5);
        _nextQuery = DateTime.MinValue;
        return res != null;
    }
}
