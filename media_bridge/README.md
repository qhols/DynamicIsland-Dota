# media bridge

Small background app for the island. Reads what's playing on windows, controls playback and volume, plays the ui sounds, watches the sound output and battery, checks for updates and installs them. No window, around 50 mb of ram, listens on `127.0.0.1:45455`.

Works with anything that shows up in the windows media overlay: spotify, yandex music, browsers, dotify and so on. How good seek and the progress bar are depends on the player, some of them barely report their position.

## Run

Just start `media_bridge.exe`. Only one copy runs at a time, starting it again replaces the old one.

- `media_bridge.exe %command%` in steam launch options starts dota through it
- it quits when dota closes, `--stay` turns that off
- sounds are built in, a `sounds` folder next to the exe overrides them by file name

## Endpoints

| path | what |
| --- | --- |
| `/media` | current track, cover, position, volume, waveform |
| `/media/playpause`, `/next`, `/prev` | playback |
| `/media/shuffle`, `/repeat` | toggles |
| `/media/seek?pos=<seconds>` | seek |
| `/media/volup`, `/voldown` | volume +-5% |
| `/media/like` | spotify like (spicetify + debug port) |
| `/sound?name=&vol=&duck=` | play a ui sound |
| `/focus` | is dota in front |
| `/status` | version, latest release, sound and spotify state |
| `/system` | default sound output, mute, battery |
| `/update/start?dir=<scripts folder>` | download the latest release and install the script |
| `/update/status` | download progress and state |
| `/update/restart` | swap in the new exe and restart |
| `/open` | open the latest release page |

## Build

```powershell
./csharp/build.ps1
```

Keep `BuiltInComInteropSupport` on, trimming turns com off and then sounds, volume and ducking silently stop working.

## Release

Bump `BridgeVersion` in `UpdateChecker.cs` and `SCRIPT_VERSION` in the script, tag the release like `v2.0.1`.
