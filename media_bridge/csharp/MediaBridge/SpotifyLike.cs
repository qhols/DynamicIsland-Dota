using System.Net.WebSockets;
using System.Text;
using System.Text.RegularExpressions;

namespace MediaBridge;

public static partial class SpotifyLike
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromMilliseconds(400) };

    [GeneratedRegex("\"webSocketDebuggerUrl\"\\s*:\\s*\"(ws://127\\.0\\.0\\.1:9222/devtools/page/[a-zA-Z0-9]+)\"")]
    private static partial Regex DebuggerUrlRegex();

    private static async Task<string?> EvaluateJsAsync(string js, int timeoutMs = 800)
    {
        try
        {
            using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(timeoutMs));

            string json = await Http.GetStringAsync("http://127.0.0.1:9222/json", cts.Token);
            var match = DebuggerUrlRegex().Match(json);
            if (!match.Success) return null;
            string wsUrl = match.Groups[1].Value;

            using var ws = new ClientWebSocket();
            await ws.ConnectAsync(new Uri(wsUrl), cts.Token);

            string escapedJs = JsonEscapeString(js);
            string payload = "{\"id\":1,\"method\":\"Runtime.evaluate\",\"params\":{\"expression\":" + escapedJs + ",\"awaitPromise\":true,\"returnByValue\":true}}";
            await ws.SendAsync(Encoding.UTF8.GetBytes(payload), WebSocketMessageType.Text, true, cts.Token);

            var buffer = new byte[8192];
            var received = new StringBuilder();
            for (int i = 0; i < 5; i++)
            {
                var result = await ws.ReceiveAsync(buffer, cts.Token);
                received.Append(Encoding.UTF8.GetString(buffer, 0, result.Count));
                string cur = received.ToString();
                if (cur.Contains("\"result\":") && cur.Contains('}')) break;
                if (result.EndOfMessage) break;
            }
            return received.ToString();
        }
        catch
        {
            return null;
        }
    }

    public static async Task<bool?> ToggleLikeAsync()
    {
        const string js = "(async () => {" +
            "  try {" +
            "    if (window.Spicetify && window.Spicetify.Platform && window.Spicetify.Platform.LibraryAPI) {" +
            "      const item = Spicetify.Player.data.item;" +
            "      if (!item || !item.uri) return 'NO_ITEM';" +
            "      const uri = item.uri;" +
            "      const lib = Spicetify.Platform.LibraryAPI;" +
            "      const res = await lib.contains(uri);" +
            "      const isLiked = Array.isArray(res) ? res[0] : res;" +
            "      if (isLiked) {" +
            "        await lib.remove({ uris: [uri] });" +
            "        Spicetify.showNotification('Удалено из Любимых треков');" +
            "        return 'REMOVED';" +
            "      } else {" +
            "        await lib.add({ uris: [uri] });" +
            "        Spicetify.showNotification('Добавлено в Любимые треки');" +
            "        return 'ADDED';" +
            "      }" +
            "    }" +
            "    return 'NO_SPICETIFY';" +
            "  } catch { return 'ERR'; }" +
            "})()";

        string? result = await EvaluateJsAsync(js);
        if (result == null) return null;
        if (result.Contains("ADDED")) return true;
        if (result.Contains("REMOVED")) return false;
        return null;
    }

    private static string JsonEscapeString(string s)
    {
        var sb = new StringBuilder(s.Length + 2);
        sb.Append('"');
        foreach (char c in s)
        {
            switch (c)
            {
                case '"': sb.Append("\\\""); break;
                case '\\': sb.Append("\\\\"); break;
                case '\n': sb.Append("\\n"); break;
                case '\r': sb.Append("\\r"); break;
                case '\t': sb.Append("\\t"); break;
                default:
                    if (c < 0x20) sb.Append("\\u").Append(((int)c).ToString("x4"));
                    else sb.Append(c);
                    break;
            }
        }
        sb.Append('"');
        return sb.ToString();
    }
}
