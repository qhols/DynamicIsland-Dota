using System.Net.WebSockets;
using System.Text;
using System.Text.Json;

namespace MediaBridge;

public static class DevTools
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromMilliseconds(400) };

    public static async Task<bool> IsOpenAsync(int port)
    {
        try
        {
            using var r = await Http.GetAsync($"http://127.0.0.1:{port}/json/version");
            return r.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }

    public static async Task<bool> HasPageAsync(int port, string urlPrefix)
    {
        try
        {
            string json = await Http.GetStringAsync($"http://127.0.0.1:{port}/json");
            return PickPage(json, port, urlPrefix) != null;
        }
        catch
        {
            return false;
        }
    }

    public static async Task<string?> EvaluateAsync(int port, string urlPrefix, string js, int timeoutMs = 800)
    {
        try
        {
            using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(timeoutMs));

            string json = await Http.GetStringAsync($"http://127.0.0.1:{port}/json", cts.Token);
            string? wsUrl = PickPage(json, port, urlPrefix);
            if (wsUrl == null) return null;

            using var ws = new ClientWebSocket();
            await ws.ConnectAsync(new Uri(wsUrl), cts.Token);

            string payload = "{\"id\":1,\"method\":\"Runtime.evaluate\",\"params\":{\"expression\":\"" + JsonEncodedText.Encode(js) + "\",\"awaitPromise\":true,\"returnByValue\":true}}";
            await ws.SendAsync(Encoding.UTF8.GetBytes(payload), WebSocketMessageType.Text, true, cts.Token);

            var buffer = new byte[16384];
            for (int i = 0; i < 8; i++)
            {
                using var ms = new MemoryStream();
                WebSocketReceiveResult r;
                do
                {
                    r = await ws.ReceiveAsync(buffer, cts.Token);
                    ms.Write(buffer, 0, r.Count);
                } while (!r.EndOfMessage);
                if (r.MessageType == WebSocketMessageType.Close) return null;

                using var doc = JsonDocument.Parse(ms.ToArray());
                var root = doc.RootElement;
                if (!root.TryGetProperty("id", out var id) || id.ValueKind != JsonValueKind.Number || id.GetInt32() != 1) continue;
                if (root.TryGetProperty("result", out var res) && res.TryGetProperty("result", out var inner) && inner.TryGetProperty("value", out var val))
                {
                    return val.ValueKind == JsonValueKind.String ? val.GetString() : val.GetRawText();
                }
                return null;
            }
            return null;
        }
        catch
        {
            return null;
        }
    }

    private static string? PickPage(string json, int port, string urlPrefix)
    {
        using var doc = JsonDocument.Parse(json);
        if (doc.RootElement.ValueKind != JsonValueKind.Array) return null;
        string local = $"ws://127.0.0.1:{port}/devtools/page/";
        foreach (var t in doc.RootElement.EnumerateArray())
        {
            if (!t.TryGetProperty("type", out var type) || type.GetString() != "page") continue;
            if (!t.TryGetProperty("webSocketDebuggerUrl", out var ws)) continue;
            string wsUrl = ws.GetString() ?? "";
            if (!wsUrl.StartsWith(local, StringComparison.Ordinal)) continue;
            string url = t.TryGetProperty("url", out var u) ? u.GetString() ?? "" : "";
            if (urlPrefix != "" && url.StartsWith(urlPrefix, StringComparison.OrdinalIgnoreCase)) return wsUrl;
            if (urlPrefix == "") return wsUrl;
        }
        return null;
    }
}
