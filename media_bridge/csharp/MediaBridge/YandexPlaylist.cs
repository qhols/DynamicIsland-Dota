using System.Text.Json;

namespace MediaBridge;

public static class YandexPlaylist
{
    private static string _track = "";
    private static string _cachedTrack = "";
    private static readonly HashSet<string> CachedSelected = new(StringComparer.Ordinal);
    private static string[] _openItems = [];

    private const string OpenScript = "(async () => {" +
        "const bar = document.querySelector('[data-test-id=\"PLAYERBAR_DESKTOP\"]') || document.querySelector('[data-test-id=\"VIBE_PLAYERBAR\"]');" +
        "if (!bar) return JSON.stringify({status:'no_player',items:[]});" +
        "const buttons = [...bar.querySelectorAll('button')];" +
        "const more = bar.querySelector('[data-test-id*=\"CONTEXT_MENU\"], [data-test-id*=\"MORE_BUTTON\"], [aria-haspopup=\"menu\"]') || buttons.find(b => /(more|ещё|еще|дополнительно|меню|options|действия|три точки)/i.test((b.getAttribute('aria-label') || b.getAttribute('title') || '').trim()));" +
        "const visible = e => e.getClientRects().length > 0;" +
        "const findAdd = () => [...document.querySelectorAll('[role=\"menuitem\"],button,[data-test-id*=\"MENU_ITEM\"]')].filter(visible).find(e => /(добавить в плейлист|add to playlist)/i.test((e.textContent || e.getAttribute('aria-label') || '').trim()));" +
        "let add=findAdd(); if(!add){ if (more) more.click(); else { const track=bar.querySelector('[data-test-id*=\"TRACK\"]') || bar; track.dispatchEvent(new MouseEvent('contextmenu',{bubbles:true,cancelable:true,button:2})); } await new Promise(r => setTimeout(r, 250)); add=findAdd(); }" +
        "if (!add) { if(more) more.click(); return JSON.stringify({status:more ? 'no_add' : 'no_menu',items:[]}); }" +
        "add.click(); await new Promise(r => setTimeout(r, 280));" +
        "let layer; for(let n=0;n<5;n++){ layer=[...document.querySelectorAll('[role=\"dialog\"],[role=\"menu\"],[data-radix-popper-content-wrapper],[data-test-id*=\"PLAYLIST_MENU\"],[class*=\"PlaylistMenu\"],[class*=\"PlaylistModal\"]')].filter(visible).pop(); if(layer && layer.querySelector('[role=\"menuitem\"],[role=\"menuitemcheckbox\"],[role=\"option\"],[role=\"checkbox\"],button,[data-test-id*=\"PLAYLIST_ITEM\"],[data-test-id*=\"PLAYLIST_ROW\"]')) break; await new Promise(r=>setTimeout(r,160)); }" +
        "if (!layer) return JSON.stringify({status:'no_list',items:[]});" +
        "const area = layer;" +
        "const rows = [...area.querySelectorAll('[role=\"menuitem\"],[role=\"menuitemcheckbox\"],[role=\"option\"],[role=\"checkbox\"],button,[data-test-id*=\"PLAYLIST_ITEM\"],[data-test-id*=\"PLAYLIST_ROW\"]')].filter(visible).filter(e => !e.querySelector('[role=\"menuitem\"],[role=\"menuitemcheckbox\"],[role=\"option\"],[role=\"checkbox\"],button')) ;" +
        "const checked = e => { const row=e.closest('[role=\"menuitemcheckbox\"],[role=\"checkbox\"],[role=\"menuitem\"],[data-state]') || e; return row.getAttribute('aria-checked') === 'true' || row.getAttribute('data-state') === 'checked' || !!row.querySelector('[aria-checked=\"true\"],[data-state=\"checked\"],input:checked,[data-test-id*=\"CHECKED\"]'); };" +
        "const items = rows.map(e => ({e,name:(e.textContent || '').trim().replace(/\\s+/g,' '),selected:checked(e)})).filter(x => x.name && !/^(создать|create|поиск|search|отмена|cancel|добавить в плейлист|add to playlist)/i.test(x.name));" +
        "window.__diPlaylistOptions = items.map(x => x.e);" +
        "window.__diPlaylistSelected = items.map(x => x.selected);" +
        "return JSON.stringify({status:items.length ? 'ok' : 'empty',items:items.map(x => x.name),selected:items.map(x => x.selected)});" +
        "})()";

    public static async Task<(string status, string[] items, bool[] selected)> OpenAsync()
    {
        var media = await MediaSessionService.GetMediaInfoAsync();
        if (media == null || !YandexLike.IsApp(media.app) || media.title == "") return ("unavailable", [], []);
        _track = media.title + "\n" + media.artist;
        if (_track != _cachedTrack)
        {
            _cachedTrack = _track;
            CachedSelected.Clear();
        }
        string? raw = await DevTools.EvaluateAsync(YandexLike.Port, "music-application://", OpenScript, 2600);
        if (raw == null) return ("offline", [], []);
        try
        {
            using var doc = JsonDocument.Parse(raw);
            var root = doc.RootElement;
            string status = root.GetProperty("status").GetString() ?? "failed";
            string[] items = root.GetProperty("items").EnumerateArray().Select(x => x.GetString() ?? "").Take(100).ToArray();
            bool[] selected = root.TryGetProperty("selected", out var flags) ? flags.EnumerateArray().Select(x => x.ValueKind == JsonValueKind.True).Take(100).ToArray() : [];
            Array.Resize(ref selected, items.Length);
            _openItems = items;
            for (int i = 0; i < items.Length; i++)
            {
                if (selected[i]) CachedSelected.Add(items[i]);
                else if (CachedSelected.Contains(items[i])) selected[i] = true;
            }
            return (status, items, selected);
        }
        catch { return ("failed", [], []); }
    }

    public static async Task<bool> AddAsync(int index)
    {
        if (index < 0 || index >= _openItems.Length || _track == "") return false;
        var media = await MediaSessionService.GetMediaInfoAsync();
        if (media == null || !YandexLike.IsApp(media.app) || media.title + "\n" + media.artist != _track) return false;
        string name = _openItems[index];
        if (CachedSelected.Contains(name))
        {
            _track = "";
            return true;
        }
        bool ok = await ClickPlaylistAsync(index, name, true);
        if (ok)
        {
            CachedSelected.Add(name);
            _track = "";
        }
        return ok;
    }

    public static async Task<bool> RemoveAsync(int index)
    {
        if (index < 0 || index >= _openItems.Length || _track == "" || !CachedSelected.Contains(_openItems[index])) return false;
        var media = await MediaSessionService.GetMediaInfoAsync();
        if (media == null || !YandexLike.IsApp(media.app) || media.title + "\n" + media.artist != _track) return false;
        string name = _openItems[index];
        if (!await ClickPlaylistAsync(index, name, false)) return false;
        CachedSelected.Remove(name);
        return true;
    }

    private static async Task<bool> ClickPlaylistAsync(int index, string name, bool wantSelected)
    {
        string js = "(() => { const items=window.__diPlaylistOptions; const e=items && items[" + index + "]; if (!e || !e.isConnected || !e.getClientRects().length) return 'STALE'; e.click(); window.__diPlaylistOptions=null; return 'OK'; })()";
        string? result = await DevTools.EvaluateAsync(YandexLike.Port, "music-application://", js);
        if (result == "OK") return true;
        var (status, items, selected) = await OpenAsync();
        if (status != "ok") return false;
        int refreshed = Array.IndexOf(items, name);
        if (refreshed < 0) return false;
        if (selected[refreshed] == wantSelected) return true;
        js = "(() => { const items=window.__diPlaylistOptions; const e=items && items[" + refreshed + "]; if (!e || !e.isConnected || !e.getClientRects().length) return 'STALE'; e.click(); window.__diPlaylistOptions=null; return 'OK'; })()";
        return await DevTools.EvaluateAsync(YandexLike.Port, "music-application://", js) == "OK";
    }
}
