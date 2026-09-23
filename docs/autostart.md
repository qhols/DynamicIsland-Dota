# Start the bridge together with Dota

[English](#english) | [Русский](#русский)

## English

The bridge can start itself every time you launch Dota from Steam, and it closes itself a few seconds after Dota closes. You set it up once and forget about it.

### 1. Put the bridge somewhere it will stay

Download `media_bridge.exe` from the [latest release](https://github.com/qhols/DynamicIsland-Dota/releases/latest) and move it to a folder you won't delete or clean up, for example:

```
C:\Umbrella\scripts\media_bridge\media_bridge.exe
```

Don't leave it in Downloads. If you move it later, you'll have to update the path in step 4.

Run it once by double clicking. If Windows SmartScreen or your antivirus asks about it, allow it. Otherwise it can get blocked silently when Steam starts it.

### 2. Copy the full path to the exe

Right click `media_bridge.exe` and pick **Copy as path**. On Windows 10 you have to hold **Shift** while right clicking to see it.

You'll get something like this, quotes included:

```
"C:\Umbrella\scripts\media_bridge\media_bridge.exe"
```

### 3. Open Dota's launch options in Steam

1. Open Steam and go to **Library**
2. Right click **Dota 2** and pick **Properties**
3. On the **General** tab find the **Launch Options** field

### 4. Put the bridge in front of `%command%`

Paste the path, then a space, then `%command%`:

```
"C:\Umbrella\scripts\media_bridge\media_bridge.exe" %command%
```

If you already had launch options (like `-novid` or `-high`), keep them and put them **after** `%command%`:

```
"C:\Umbrella\scripts\media_bridge\media_bridge.exe" %command% -novid -high
```

Things that matter:

- keep the quotes around the path, especially if it has spaces
- write `%command%` exactly like that
- nothing goes before the path

Close the properties window, it saves by itself.

### 5. Launch Dota like always

Hit **Play** in Steam. Steam starts the bridge, and the bridge starts Dota with all your launch options. Nothing else changes.

### Check that it works

- open Task Manager while Dota is running, `media_bridge` should be there
- open the Umbrella menu in game, there should be no "MediaBridge isn't running" hint under the island
- music on the island should work

### Closing

The bridge closes by itself about 6 seconds after Dota closes. If you want it to keep running after that, add `--stay` right after the path:

```
"C:\Umbrella\scripts\media_bridge\media_bridge.exe" --stay %command%
```

### Problems

**Dota doesn't start at all.** Check the path. Paste it (with the quotes) into Win + R and press Enter: the bridge should start. If it doesn't, the path is wrong or the file was moved.

**Dota starts but the bridge doesn't.** Most likely the antivirus or SmartScreen blocked it. Run the exe by hand once and allow it.

**You launch Dota some other way, not with Steam's Play button.** Launch options only apply when Steam starts the game. In that case just run the bridge by hand before Dota, it will still close when Dota closes.

**You want to turn it off.** Clear the launch options field (or leave only your old options) and that's it.

## Русский

Бридж может сам запускаться каждый раз, когда ты открываешь доту через стим, и сам закрываться через пару секунд после того, как дота закрылась. Настраиваешь один раз и забываешь.

### 1. Положи бридж туда, где он будет лежать всегда

Скачай `media_bridge.exe` из [последнего релиза](https://github.com/qhols/DynamicIsland-Dota/releases/latest) и закинь в папку, которую не удалишь и не почистишь, например:

```
C:\Umbrella\scripts\media_bridge\media_bridge.exe
```

В загрузках не оставляй. Если потом переместишь файл, путь в шаге 4 придётся поменять.

Запусти его один раз двойным кликом. Если винда (SmartScreen) или антивирус спросят, разреши. Иначе они могут молча блочить его, когда его будет запускать стим.

### 2. Скопируй полный путь к exe

ПКМ по `media_bridge.exe` и выбери **Копировать как путь**. На Windows 10 надо зажать **Shift**, когда жмёшь ПКМ, иначе этого пункта не будет.

Получится что-то такое, вместе с кавычками:

```
"C:\Umbrella\scripts\media_bridge\media_bridge.exe"
```

### 3. Открой параметры запуска доты в стиме

1. Открой стим и зайди в **Библиотеку**
2. ПКМ по **Dota 2** и выбери **Свойства**
3. Во вкладке **Общие** найди поле **Параметры запуска**

### 4. Поставь бридж перед `%command%`

Вставь путь, потом пробел, потом `%command%`:

```
"C:\Umbrella\scripts\media_bridge\media_bridge.exe" %command%
```

Если у тебя уже были параметры запуска (типа `-novid` или `-high`), оставь их и поставь **после** `%command%`:

```
"C:\Umbrella\scripts\media_bridge\media_bridge.exe" %command% -novid -high
```

Что важно:

- кавычки вокруг пути не убирай, особенно если в пути есть пробелы
- `%command%` пиши ровно так
- перед путём ничего не должно быть

Закрой окно свойств, всё сохраняется само.

### 5. Запускай доту как обычно

Жмёшь **Играть** в стиме. Стим запускает бридж, а бридж запускает доту со всеми твоими параметрами. Больше ничего не меняется.

### Как проверить, что работает

- открой диспетчер задач, пока дота запущена, там должен быть `media_bridge`
- открой меню Umbrella в игре, под островком не должно быть подсказки, что MediaBridge не запущен
- музыка на островке должна работать

### Закрытие

Бридж сам закрывается примерно через 6 секунд после того, как закрылась дота. Если хочешь, чтобы он продолжал работать, добавь `--stay` сразу после пути:

```
"C:\Umbrella\scripts\media_bridge\media_bridge.exe" --stay %command%
```

### Если что-то не так

**Дота вообще не запускается.** Проверь путь. Вставь его (с кавычками) в Win + R и нажми Enter, бридж должен запуститься. Если нет, путь неправильный или файл переехал.

**Дота запускается, а бридж нет.** Скорее всего, его заблокировал антивирус или SmartScreen. Запусти exe руками один раз и разреши.

**Ты запускаешь доту не через кнопку «Играть» в стиме.** Параметры запуска работают только когда игру запускает стим. Тогда просто запускай бридж руками перед дотой, закрываться вместе с ней он всё равно будет.

**Хочешь выключить.** Очисти поле параметров запуска (или оставь там только свои старые параметры), и всё.
