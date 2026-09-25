# Spotify likes on the island

[English](#english) | [Русский](#русский)

## English

The heart button in the island's player adds the current Spotify track to your Liked Songs, or removes it. Music, covers, play/pause, skip and seek work without any of this. Only the heart needs the setup below.

### Why it needs a setup at all

Windows lets other apps control Spotify only like media keys do: play, pause, next, previous. There's no "like this track" command there. So the bridge has to press the like from inside Spotify itself.

Two things make that possible:

- **The debug port.** Spotify on PC is basically a Chrome browser showing the Spotify web page. Chrome has a "remote debugging port": when Spotify starts with the flag `--remote-debugging-port=9222`, another program on your PC can connect to it at `127.0.0.1:9222` and run a command inside the page. `9222` is just the port number.
- **Spicetify.** It's a popular mod for the Spotify desktop app. Among other things it adds proper commands inside Spotify like "is this track liked" and "like this track". The bridge calls exactly those through the port.

You need both. Without Spicetify there's nothing to call, without the port there's no way in.

### What you need

- Spotify installed from [spotify.com/download](https://www.spotify.com/download/), **not** from the Microsoft Store. The Store version lives in a locked system folder, Spicetify and the bridge can't touch it. If you have the Store version, uninstall it and install the one from the site.
- [MediaBridge](https://github.com/qhols/DynamicIsland-Dota/releases/latest) running
- The **Spotify Like Button** switch on in the script menu: Dynamic Island > Media

### 1. Install Spicetify

1. Close Spotify completely: right click its icon in the tray (bottom right, next to the clock) and pick **Quit**. The X on the window only hides it.
2. Open **PowerShell**: press Win, type `powershell`, press Enter. Open it normally, **not** as administrator. Spicetify's own installer warns that running as admin can break the install.
3. Paste this command and press Enter:

```powershell
iwr -useb https://raw.githubusercontent.com/spicetify/cli/main/install.ps1 | iex
```

4. It downloads Spicetify and patches Spotify. At the end it may ask whether to install the **Marketplace** (a store of themes and extensions for Spotify). It's optional, likes work either way.
5. If the installer didn't open Spotify by itself, run this once:

```powershell
spicetify backup apply
```

Official guide with other ways to install: [spicetify.app/docs/getting-started](https://spicetify.app/docs/getting-started)

### 2. Start the bridge and restart Spotify

1. Start `media_bridge.exe` (or launch Dota if you set it up to [start with Dota](autostart.md)).
2. Quit Spotify through the tray again, then open it with its usual shortcut: Start menu, taskbar or desktop.

That's it. You don't have to type the flag anywhere yourself: the bridge adds `--remote-debugging-port=9222` to Spotify's shortcuts in the Start menu, on the taskbar and on the desktop, and to `spotify:` links that open from the browser. It checks them when it starts and then every 10 minutes, so after a Spotify update the flag comes back on its own.

### Check that it works

1. Open the Umbrella menu. If a hint under the island says **Spotify is running without the debug port**, Spotify was started without the flag. Quit it through the tray and open it with a shortcut.
2. If there's no hint, play something, hover the island to open the player and click the heart. A small notification pops up inside Spotify and the island shows **Liked Songs**. Click again to remove it.

### Problems

**The island says "Likes unavailable".** Spotify is running without the port. Quit it through the tray, open it with a shortcut.

**Spotify starts together with Windows.** Autostart doesn't go through the shortcuts, so it starts without the flag. Either turn it off in Spotify: Settings > Startup and window behaviour > Open Spotify automatically after you log into the computer: **No**. Or after Windows starts, quit Spotify once and open it with a shortcut.

**Spotify updated and likes stopped working.** An update can remove the flag from shortcuts and can also remove Spicetify's patch. First restart the bridge (it fixes the shortcuts right away), then quit and reopen Spotify. If it still doesn't work, reapply Spicetify:

```powershell
spicetify backup apply
```

If that errors, update Spicetify and try again:

```powershell
spicetify update
spicetify restore backup apply
```

Right after a big Spotify update Spicetify sometimes needs a day or two to catch up. Until then, likes won't work, everything else will.

**I have the Microsoft Store version.** It won't work. Uninstall it, install Spotify from the site, then go through the steps again.

**I don't want Spicetify.** Just turn off **Spotify Like Button** in the script menu. The player keeps working, the heart disappears.

### Is it safe?

The port is only open on your own PC (`127.0.0.1`), nobody from the internet can connect to it. But while it's open, any program on your PC can control Spotify through it.

If you don't want that, don't use likes:

1. Turn off **Spotify Like Button** in the script menu. The bridge stops adding the flag to Spotify's shortcuts.
2. Remove the flag from the shortcuts by hand: right click the Spotify shortcut > **Properties**, in the **Target** field delete ` --remote-debugging-port=9222` at the end, **OK**. For the taskbar icon: right click it, then right click **Spotify** in the menu that opens > **Properties**.
3. Quit Spotify through the tray and open it again.

### Remove Spicetify

To get vanilla Spotify back, run in PowerShell:

```powershell
spicetify restore
rmdir -r -fo $env:APPDATA\spicetify
rmdir -r -fo $env:LOCALAPPDATA\spicetify
```

More in the [official guide](https://spicetify.app/docs/advanced-usage/uninstallation).

## Русский

Сердечко в плеере островка добавляет текущий трек Spotify в «Любимые треки» или убирает его оттуда. Музыка, обложки, плей/пауза, переключение и перемотка работают и без всего этого. Настройка ниже нужна только для сердечка.

### Зачем вообще что-то настраивать

Windows даёт другим программам управлять Spotify только как медиаклавишам: плей, пауза, следующий, предыдущий. Команды «лайкни этот трек» там нет. Поэтому бридж нажимает лайк изнутри самого Spotify.

Для этого нужны две вещи:

- **Отладочный порт.** Spotify на ПК это по сути браузер Chrome, в котором открыта страница Spotify. У Chrome есть «порт для отладки» (remote debugging port): если Spotify запущен с флагом `--remote-debugging-port=9222`, другая программа на твоём ПК может подключиться к нему по адресу `127.0.0.1:9222` и выполнить команду внутри страницы. `9222` это просто номер порта.
- **Spicetify.** Популярный мод для десктопного Spotify. Кроме прочего, он добавляет внутрь Spotify нормальные команды вроде «лайкнут ли трек» и «лайкнуть трек». Бридж через порт вызывает как раз их.

Нужно и то и другое. Без Spicetify вызывать нечего, без порта не достучаться.

### Что понадобится

- Spotify с сайта [spotify.com/download](https://www.spotify.com/download/), **не** из Microsoft Store. Версия из магазина лежит в закрытой системной папке, ни Spicetify, ни бридж её не трогают. Если у тебя версия из магазина, удали её и поставь с сайта
- Запущенный [MediaBridge](https://github.com/qhols/DynamicIsland-Dota/releases/latest)
- Включённый переключатель **Лайк трека Spotify** в меню скрипта: Dynamic Island > Медиа

### 1. Поставь Spicetify

1. Полностью закрой Spotify: ПКМ по его иконке в трее (справа внизу, возле часов) и **Выйти**. Крестик на окне обычно его только сворачивает, за это отвечает настройка «При нажатии кнопки «Закрыть» сворачивать окно Spotify»
2. Открой **PowerShell**: нажми Win, напиши `powershell`, Enter. Открывай обычно, **не** от имени администратора. Сам установщик Spicetify предупреждает, что от админа установка может сломаться
3. Вставь команду и нажми Enter:

```powershell
iwr -useb https://raw.githubusercontent.com/spicetify/cli/main/install.ps1 | iex
```

4. Он скачает Spicetify и пропатчит Spotify. В конце может спросить, ставить ли **Marketplace** (магазин тем и расширений для Spotify). Это по желанию, лайки работают в любом случае
5. Если установщик сам не открыл Spotify, выполни один раз:

```powershell
spicetify backup apply
```

Официальный гайд и другие способы установки: [spicetify.app/docs/getting-started](https://spicetify.app/docs/getting-started)

### 2. Запусти бридж и перезапусти Spotify

1. Запусти `media_bridge.exe` (или доту, если настроил [запуск вместе с дотой](autostart.md))
2. Снова выйди из Spotify через трей и открой его обычным ярлыком: из Пуска, с панели задач или с рабочего стола

Всё. Руками флаг прописывать не надо: бридж сам дописывает `--remote-debugging-port=9222` в ярлыки Spotify в Пуске, на панели задач и на рабочем столе, а ещё в ссылки `spotify:`, которые открываются из браузера. Проверяет он это при запуске и дальше раз в 10 минут, так что после обновления Spotify флаг вернётся сам.

### Как понять, что работает

1. Открой меню Umbrella. Если под островком висит подсказка **Спотифай запущен без порта**, значит Spotify запущен без флага. Выйди из него через трей и открой ярлыком
2. Если подсказки нет, включи трек, наведи на островок, чтобы открыть плеер, и нажми сердечко. Внутри Spotify всплывёт «Добавлено в Любимые треки», а островок покажет **Любимые треки**. Повторное нажатие уберёт трек обратно

### Если что-то не так

**Островок пишет «Лайки недоступны».** Spotify запущен без порта. Выйди через трей, открой ярлыком.

**Spotify сам стартует вместе с Windows.** Автозапуск идёт мимо ярлыков, поэтому флага там нет. Либо выключи его в Spotify: Настройки > **Настройки запуска** > **Автоматически запускать Spotify после включения компьютера**: **Нет**. Либо после старта Windows один раз выйди из Spotify и открой его ярлыком.

**Spotify обновился, и лайки отвалились.** Обновление может убрать флаг из ярлыков и снести патч Spicetify. Сначала перезапусти бридж (он сразу поправит ярлыки), потом выйди из Spotify и открой заново. Не помогло, переприменяй Spicetify:

```powershell
spicetify backup apply
```

Если выдаёт ошибку, обнови Spicetify и попробуй ещё раз:

```powershell
spicetify update
spicetify restore backup apply
```

Сразу после крупного обновления Spotify разработчикам Spicetify иногда нужен день или два, чтобы догнать его. До этого лайки работать не будут, всё остальное будет.

**У меня версия из Microsoft Store.** Работать не будет. Удали её, поставь Spotify с сайта и пройди шаги заново.

**Не хочу ставить Spicetify.** Просто выключи **Лайк трека Spotify** в меню скрипта. Плеер будет работать как раньше, сердечко пропадёт.

### Это безопасно?

Порт открыт только на твоём же компьютере (`127.0.0.1`), из интернета к нему не подключиться. Но пока он открыт, любая программа на твоём ПК может через него управлять Spotify.

Если это напрягает, не пользуйся лайками:

1. Выключи **Лайк трека Spotify** в меню скрипта. Бридж перестанет дописывать флаг в ярлыки Spotify
2. Убери флаг из ярлыков вручную: ПКМ по ярлыку Spotify > **Свойства**, в поле **Объект** удали в конце ` --remote-debugging-port=9222`, **ОК**. Для значка на панели задач: ПКМ по нему, потом ПКМ по **Spotify** в открывшемся меню > **Свойства**
3. Выйди из Spotify через трей и открой заново

### Как удалить Spicetify

Чтобы вернуть обычный Spotify, выполни в PowerShell:

```powershell
spicetify restore
rmdir -r -fo $env:APPDATA\spicetify
rmdir -r -fo $env:LOCALAPPDATA\spicetify
```

Подробнее в [официальном гайде](https://spicetify.app/docs/advanced-usage/uninstallation).
