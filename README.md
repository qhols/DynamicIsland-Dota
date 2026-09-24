# Dynamic Island for Dota 2

iPhone style dynamic island for dota, made for umbrella. one small pill at the top of the screen that shows what matters right now and gets out of the way when nothing does.

## Download

- [script](https://github.com/qhols/DynamicIsland-Dota/releases/latest/download/dynamic_island.lua)
- [media bridge](https://github.com/qhols/DynamicIsland-Dota/releases/latest/download/media_bridge.exe)
- [media bridge source](media_bridge)
- [start the bridge together with dota](docs/autostart.md)
- [fonts](https://github.com/qhols/DynamicIsland-Dota/releases/download/v2.0.0/fonts.zip)

## What's in it

- clock, kda, gold, net worth, cs, fps, ping, pick what you want and drag them around
- music player: cover, track, seek by dragging the bar, volume on scroll, spotify likes
- fight radar that pops up during fights
- alerts for runes, stacks, lotus, neutrals, tormentor, roshan and aegis, kill streaks, buybacks, towers, couriers, enemy tps, invis and key items
- every alert has its own priority and duration, lower ones go to a small bubble next to the island instead of covering your music
- rampage timer after an ultra kill
- match flow in the menu: queue timer, accept countdown, who accepted, loading, draft with picks and bans
- do not disturb and your own reminders (like "smoke at 12:00")
- system alerts: headphones or speakers switching, windows sound muted, laptop charging and low battery
- notification center with your last alerts, even the ones do not disturb kept quiet
- updates right from the island: a new version shows up in the menu and installs in one click
- english and russian, switches live with the umbrella language

## Install

1. put `dynamic_island.lua` into your umbrella `scripts` folder
2. get `media_bridge.exe` from [releases](https://github.com/qhols/DynamicIsland-Dota/releases/latest) and run it. it handles music, sounds and the update check, sounds are already inside
3. turn it on in umbrella: General > Dynamic Island

The script works without the bridge, you just won't have music and sounds.

## Bridge with dota

To start it together with dota, put it in front of `%command%` in steam launch options (Dota 2 > Properties):

```
"C:\path\to\media_bridge.exe" %command%
```

It closes by itself a few seconds after dota closes. Run it with `--stay` if you want it to keep running.

Step by step guide (english and russian): [docs/autostart.md](docs/autostart.md)

## Spotify likes

Needs [spicetify](https://spicetify.app) and spotify started with `--remote-debugging-port=9222`. The bridge adds that flag to your spotify shortcuts and `spotify:` links on its own, so after the first restart it just works. If spotify was started without it, the island tells you.

## Controls

- hover the island to expand it, or press and hold if you pick that in the settings
- scroll down on the expanded island for the notification center
- drag the progress bar to seek
- scroll over the player for volume
- right click the island with the umbrella menu open for the widget editor
- ctrl + drag to move it
- double click a side bubble to close it

## Building the bridge

Needs the [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0).

```powershell
./media_bridge/csharp/build.ps1
```

Details and endpoints are in [media_bridge/README.md](media_bridge/README.md).
