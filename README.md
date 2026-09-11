# dynamic-island

Dynamic Island overlay for Dota 2 on the Umbrella platform.

## Features

- Dynamic Island UI with spring animations (compact pill, notifications, expanded player, status card)
- Customizable HUD widgets: clock, KDA, gold, net worth, last hits, hero name, FPS, ping
- Right-click widget drawer with drag-and-drop reordering and styling options
- Rune spawn reminders and pickup notifications (power, water, bounty, wisdom)
- Objective tracking: Roshan timer with Aegis satellite bubble, Tormentor alerts, Lotus pool timer, neutral item tiers
- Combat alerts: killstreaks, buybacks, tower attacks, courier attacks, low HP targets
- Invisibility detection (Shadow Blade, Silver Edge, Smoke, Vendetta, Moonlight Shadow, etc.) and enemy TP destination alerts
- Enemy key item purchase alerts (BKB, Blink, Hex, Rapier, Refresher, etc.)
- Media player support with real-time waveform, track info, album art, and Spotify like button (via MediaBridge)
- Minimalist status card in idle state (large clock + match stats)
- Draggable with Ctrl + LMB, position presets, automatic config saving to JSON

## Requirements

- Umbrella for Dota 2
- Windows 10 or 11
- `media_bridge.exe` (optional, for media player sync and sound effects)

## Installation

1. Copy dynamic_island.lua to your Umbrella scripts folder (usually C:\Umbrella\scripts).
2. If you want music integration and sound effects, download `media_bridge.exe` and `sounds.zip` from releases, place the `sounds/` folder next to `media_bridge.exe`, and run it (runs silently in the background, single-instance safe).
3. Enable the script in the Umbrella menu.

## Controls

- Left click: expand/collapse player or press media buttons
- Right click: open widget customizer (when Umbrella menu is open)
- Ctrl + Left click drag: move the island anywhere on screen

## Media Bridge

MediaBridge runs a lightweight local server on port 45455 that pulls metadata from Windows media sessions (Spotify, Apple Music, browsers, etc.), handles playback and volume controls, and plays UI sound effects with audio ducking.

- Standalone binary: `media_bridge/media_bridge.exe`
- Script: `media_bridge/media_bridge.ps1`
- Sounds: `media_bridge/sounds/`

