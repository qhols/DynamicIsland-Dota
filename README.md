# Dynamic Island for Dota 2

iPhone style dynamic island for dota, made for umbrella. one small pill at the top of the screen that shows what matters right now and gets out of the way when nothing does.

## Download

- [script](https://github.com/qhols/DynamicIsland-Dota/releases/latest/download/dynamic_island.lua)
- [media bridge](https://github.com/qhols/DynamicIsland-Dota/releases/latest/download/media_bridge.exe)
- [media bridge source](media_bridge)
- [start the bridge together with dota](docs/autostart.md)
- [set up spotify likes](docs/spotify-likes.md)
- [fonts](https://github.com/qhols/DynamicIsland-Dota/releases/download/v2.0.0/fonts.zip)

## What's in it

- hello screen and a setup assistant on first launch: bridge, size, look, alerts, likes and focus in a few taps
- real iphone proportions and motion: sizes and springs measured from slow motion of a real iphone, every animation redone frame by frame
- an empty pill by default like on iphone, or turn on widgets: clock, kda, gold, net worth, cs, fps, ping, pick what you want and drag them around, recolor them with an ios color picker (grid, spectrum, sliders)
- music player: cover, track, live waveform from what's actually playing, seek by dragging the bar, volume on scroll, spotify likes, optionally in the main menu too
- synced lyrics for any player, line by line under the track, tap a line to jump there, or show the current line right in the small island
- two activities at once like on iphone: music in the pill and a fight, courier, pause or timer in the bubble next to it, the rest waits its turn
- fight radar on the map that pops up during fights, illusions and clones don't count
- courier on the map: path, eta and the items it carries
- alerts for runes, stacks, lotus, neutrals, tormentor, roshan and aegis, kill streaks, buybacks, towers, couriers, enemy tps, invis and key items
- every alert has its own priority, duration and sound switch, lower ones go to a small bubble next to the island instead of covering your music
- alert sounds and interface sounds are separate, each with its own volume
- rampage timer after an ultra kill
- match flow in the menu: queue timer, match found rings like an incoming call, accept countdown, who accepted, loading, draft with picks and bans
- do not disturb and up to 300 of your own reminders with repeats (like "smoke at 12:00")
- system alerts: headphones or speakers switching, windows sound muted, laptop charging and low battery
- accessibility like ios: reduce motion, bold text, increase contrast
- widgets from other scripts show up in the widget editor next to the built in ones
- notification center with your last alerts, even the ones do not disturb kept quiet, repeats stack up
- zero lag: the bridge talks to the island through files instead of umbrella's slow http queue, controls and sounds answer right away
- updates right from the island: a new version shows up in the menu and installs in one click
- no sf pro or icons yet? the island offers to install the fonts in one click, no admin rights needed. the icons are real sf symbols
- debug log for bug reports: turn on debug, reproduce, send the file (extra > diagnostics has a snapshot)
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

Step by step guide with spicetify install and troubleshooting (english and russian): [docs/spotify-likes.md](docs/spotify-likes.md)

## Controls

- tap the island to open it, click anywhere else to close it (hover or press and hold are in the settings)
- scroll down on the expanded island for the notification center
- drag the progress bar to seek
- scroll over the player for volume
- right click the island with the umbrella menu open for the widget editor
- ctrl + drag moves it up and down, it always stays centered
- swipe a live activity sideways to swap it with the side bubble
- swipe a notification or a side bubble sideways to close it
- press and hold the side bubble to swap it with the main pill

## For script authors

Other scripts can send notifications and live activities to the island through the `DynamicIsland` global: permission prompt like on iPhone, alert levels, action buttons, timers and progress, and their own widgets for the widget editor. Guide: [docs/sdk.md](docs/sdk.md), working example: [examples/di_sdk_demo.lua](examples/di_sdk_demo.lua).

## Building the bridge

Needs the [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0).

```powershell
./media_bridge/csharp/build.ps1
```

Details and endpoints are in [media_bridge/README.md](media_bridge/README.md).
