local MenuTextOffsetY = 0.0
local MenuIconOffsetY = 0.0

local DynamicIsland = {}

local Translations = {
    en = {
        tab = {
            general = "General",
            settings = "Settings",
            combat = "Combat & Map",
            alerts = "Alerts",
            runes = "Runes & Objectives",
            events = "Events",
            timings = "Timings",
            media = "Media & Visuals",
            parameters = "Parameters",
            haptics = "Haptic Engine",
            tactile = "Tactile Feedback"
        },
        main = {
            enabled = "Enable Island",
            only_in_game = "Only In-Game",
            preset = "Position Preset",
            offset_y = "Vertical Offset (Y)",
            offset_x = "Horizontal Offset (X)",
            scale = "Island Scale",
            custom_label = "Hero Tag",
            bg_color = "Island Background Color",
            pure_glass = "Aka Glass",
            widget_editor = "Widget Editor (RMB)",
            reset_pos = "Reset Position"
        },
        preset = {
            top_center = "Top Center",
            custom = "Custom (Draggable)",
            top_left = "Top Left",
            top_right = "Top Right",
            screen_center = "Screen Center",
            bottom_center = "Bottom Center"
        },
        combat = {
            fight_hud = "Live Combat Radar",
            fight_scope = "Fight Scope",
            scope_local = "Local Hero Only",
            scope_any = "Any Fight on Map",
            min_heroes = "Min Heroes in Fight",
            fight_radius = "Fight Detection Radius",
            radar_zoom = "Radar Zoom Range",
            fight_timeout = "Fight Completion Timeout",
            kills = "Kill Streaks",
            invis = "Enemy Invis & Smoke",
            teleports = "Enemy Teleports",
            key_enemy_items = "Key Enemy Items",
            couriers = "Courier Under Attack",
            towers = "Tower Under Attack",
            buybacks = "Player Buybacks",
            low_hp = "Low HP Kill Opportunities",
            level_up = "Hero Level Up",
            courier_delivery = "Courier Delivery Activity",
            pause_alert = "Pause Notification Pill"
        },
        runes = {
            active_runes = "Active Power Runes",
            water_runes = "Water Runes",
            bounty_runes = "Bounty Runes",
            wisdom_runes = "Wisdom Runes",
            rune_pickups = "Rune Pickups",
            rune_world_spawn = "Rune World Spawns",
            lotus = "Lotus Pools",
            tormentor = "Tormentor Objective",
            roshan = "Roshan & Aegis"
        },
        timings = {
            toast_duration = "Toast Duration",
            power_rune_time = "Power Runes Lead Time",
            water_rune_time = "Water Runes Lead Time",
            bounty_rune_time = "Bounty Runes Lead Time",
            wisdom_rune_time = "Wisdom Runes Lead Time",
            lotus_time = "Lotus Fruit Lead Time",
            tormentor1_time = "Tormentor 1st Warning",
            tormentor2_time = "Tormentor 2nd Warning"
        },
        media = {
            enabled = "Media Sync",
            spotify_like = "Spotify Like Button",
            volume_wheel = "Scroll Wheel Volume Control",
            marquee_speed = "Marquee Speed",
            secondary_bubble = "Satellite Bubble",
            shadow = "Soft Shadows",
            blur = "Backdrop Glass Blur",
            hints = "Control Hints",
            accent_color = "Primary Theme Color",
            export_cfg = "Export All Settings to File",
            import_cfg = "Import All Settings from File"
        },
        courier = {
            delivering = "Delivering Items",
            delivered = "Delivered!",
            eta = "ETA",
            speed = "Speed",
            hp = "HP"
        },
        island = {
            in_menu = "In Menu",
            finding_match = "Finding Match ",
            match_found = "Match Found!",
            main_menu = "Main Menu",
            match = "Match ",
            clock = "Clock",
            kda = "KDA",
            gold = "Gold",
            networth = "NW",
            lasthits = "CS",
            hero = "Hero",
            fps = "FPS",
            ping = "Ping",
            music = "Music",
            fight = "Fight",
            map = "Map",
            success = "Success!",
            notification = "ALERT",
            track = "Track",
            volume = "Volume",
            paused = "Paused"
        },
        haptics = {
            enabled = "Enable Haptic Engine",
            visual = "Visual Haptics (Squish & Bounce)",
            audio = "Acoustic Taptic Clicks",
            volume = "Taptic Click Volume",
            intensity = "Kinetic Intensity",
            combat_filter = "Combat Anti-Spam Filter",
            audio_ducking = "Audio Auto-Ducking",
            ducking_amount = "Ducking Strength",
            ducking_alerts = "Ducking: Critical Alerts",
            ducking_courier = "Ducking: Courier",
            ducking_notifs = "Ducking: Notifications",
            ducking_motion = "Ducking: Island Motion",
            ducking_taptics = "Ducking: Clicks & Taptics",
            test_ducking = "Audition Ducking"
        }
    },
    ru = {
        tab = {
            general = "Главная",
            settings = "Настройки",
            combat = "Бой и Карта",
            alerts = "Оповещения",
            runes = "Руны и Объекты",
            events = "События",
            media = "Медиа и Визуал",
            parameters = "Параметры",
            haptics = "Тактильный отклик",
            tactile = "Параметры тактилки"
        },
        main = {
            enabled = "Включить Island",
            only_in_game = "Только в игре",
            preset = "Пресет позиции",
            offset_y = "Смещение (Y)",
            offset_x = "Смещение (X)",
            scale = "Масштаб",
            custom_label = "Тег героя",
            bg_color = "Цвет фона островка",
            pure_glass = "Стиль стекла",
            widget_editor = "Редактор виджетов (ПКМ)",
            reset_pos = "Сбросить позицию"
        },
        preset = {
            top_center = "Сверху по центру",
            custom = "Своя (Ctrl + ЛКМ)",
            top_left = "Сверху слева",
            top_right = "Сверху справа",
            screen_center = "По центру экрана",
            bottom_center = "Снизу по центру"
        },
        combat = {
            fight_hud = "Радар боя (Fight HUD)",
            fight_scope = "Область боя",
            scope_local = "Только вокруг своего героя",
            scope_any = "Любой бой на карте",
            min_heroes = "Мин. героев для драки",
            fight_radius = "Радиус захвата драки",
            radar_zoom = "Масштаб радара",
            fight_timeout = "Задержка закрытия после драки",
            kills = "Серии убийств",
            invis = "Невидимость и Smoke врага",
            teleports = "Телепорты врагов",
            key_enemy_items = "Важные предметы врага",
            couriers = "Атака курьера",
            towers = "Атака вышек",
            buybacks = "Выкупы игроков",
            low_hp = "Добивание Low HP",
            level_up = "Повышение уровня",
            courier_delivery = "Активность доставки курьера",
            pause_alert = "Оповещение паузы игры"
        },
        runes = {
            active_runes = "Активные руны (Power)",
            water_runes = "Водные руны",
            bounty_runes = "Руны богатства (Bounty)",
            wisdom_runes = "Руны мудрости (Wisdom)",
            rune_pickups = "Подбор рун союзником",
            rune_world_spawn = "Появление рун на карте",
            lotus = "Пруды лотосов",
            tormentor = "Терзатель",
            roshan = "Рошан и Эгида"
        },
        timings = {
            toast_duration = "Длительность уведомлений",
            power_rune_time = "Пре-таймер: Power руны",
            water_rune_time = "Пре-таймер: Водные руны",
            bounty_rune_time = "Пре-таймер: Bounty руны",
            wisdom_rune_time = "Пре-таймер: Wisdom руны",
            lotus_time = "Пре-таймер: Лотосы",
            tormentor1_time = "1-е опов. Терзателя",
            tormentor2_time = "2-е опов. Терзателя"
        },
        media = {
            enabled = "Медиа плеер",
            spotify_like = "Лайк трека Spotify",
            volume_wheel = "Громкость колесиком мыши",
            marquee_speed = "Скорость бегущей строки",
            secondary_bubble = "Второй островок/баббл",
            shadow = "Мягкие тени",
            blur = "Размытие фона (Blur)",
            hints = "Подсказки управления",
            accent_color = "Основной цвет темы",
            export_cfg = "Экспорт всех настроек в файл",
            import_cfg = "Импорт всех настроек из файла"
        },
        courier = {
            delivering = "Доставка вещей",
            delivered = "Доставлено!",
            eta = "ETA",
            speed = "Скор.",
            hp = "ХП"
        },
        island = {
            in_menu = "В меню",
            finding_match = "Поиск матча ",
            match_found = "Матч найден!",
            main_menu = "Главное меню",
            match = "Матч ",
            clock = "Часы",
            kda = "КДА",
            gold = "Золото",
            networth = "NW",
            lasthits = "CS",
            hero = "Герой",
            fps = "ФПС",
            ping = "Пинг",
            music = "Музыка",
            fight = "Драка",
            map = "Карта",
            success = "Успешно!",
            notification = "ОПОВЕЩЕНИЕ",
            track = "Трек",
            volume = "Громкость",
            paused = "Пауза"
        },
        haptics = {
            enabled = "Включить тактильный движок",
            visual = "Визуальная тактильность (Сквиш)",
            audio = "Акустические микро-клики",
            volume = "Громкость щелчков",
            intensity = "Сила кинетического импульса",
            combat_filter = "Умный фильтр в драках",
            audio_ducking = "Затихание остальных звуков",
            ducking_amount = "Сила затихания",
            ducking_alerts = "Затихание: Важные алерты",
            ducking_courier = "Затихание: Курьер",
            ducking_notifs = "Затихание: Уведомления",
            ducking_motion = "Затихание: Движение острова",
            ducking_taptics = "Затихание: Клики и кнопки",
            test_ducking = "Проверить звук"
        }
    }
}

local localization = qLocalization and qLocalization.new and qLocalization.new(Translations)
local Menu = localization and localization.WrapLibrary(Menu) or Menu

local function L(key, fallbackEn)
    if localization then
        local val = localization.Localize(key)
        if val ~= key then
            return val
        end
        if fallbackEn then
            local lang = localization.GetLanguage and localization.GetLanguage() or "en"
            return (lang == "ru") and key or fallbackEn
        end
        return val
    end
    return fallbackEn or key
end

local function FadeColor(c, a)
    if not c then return Color(255, 255, 255, 255) end
    local alpha = math.min(255, math.max(0, math.floor((c.a or 255) * a)))
    return Color(c.r, c.g, c.b, alpha)
end

local AnimWidget, AnimWidgetFound = nil, false
local function AnimScale()
    if not AnimWidgetFound then
        AnimWidgetFound = true
        AnimWidget = Menu.Find("SettingsHidden", "", "", "", "Main", "Animation Duration")
    end
    local d = AnimWidget and AnimWidget:Get()
    if not d then return 1.5 end
    return math.min(1000, math.max(10, d)) * 1.5 / 200
end

local function LerpColor(c1, c2, t)
    local f = math.min(1.0, math.max(0.0, t))
    local r = math.floor(c1.r + (c2.r - c1.r) * f)
    local g = math.floor(c1.g + (c2.g - c1.g) * f)
    local b = math.floor(c1.b + (c2.b - c1.b) * f)
    local a = math.floor((c1.a or 255) + ((c2.a or 255) - (c1.a or 255)) * f)
    return Color(r, g, b, a)
end

local MotionEngine = {
    Profiles = {
        EXPAND = { omega = 26.0, zeta = 0.76 },
        COLLAPSE = { omega = 30.0, zeta = 0.88 },
        BOUNCE = { omega = 28.0, zeta = 0.65 },
        NOTCH = { omega = 36.0, zeta = 0.80 },
        BOUNDARY_BUMP = { omega = 32.0, zeta = 0.62 },
        POP = { omega = 28.0, zeta = 0.72 },
        SUBTLE = { omega = 22.0, zeta = 0.90 },
        SQUISH = { omega = 32.0, zeta = 0.72 },
        BUTTON = { omega = 32.0, zeta = 0.65 },
        RUBBER_BAND = { omega = 28.0, zeta = 0.65 },
        SHARED_ELEM = { omega = 24.0, zeta = 0.82 }
    },
    CurrentProfile = "EXPAND",
    SmoothedDt = 0.016
}

function MotionEngine.SolveSpring(pos, vel, target, dt, omega, zeta, eps)
    local x0 = pos - target
    local isNormalized = (eps and eps < 0.05) or (math.abs(target) <= 2.0 and math.abs(pos) <= 2.0 and (not eps or eps < 0.1))
    local threshold = eps or (isNormalized and 0.005 or 0.25)
    local velThreshold = eps and (eps * 2.0) or (isNormalized and 0.01 or 0.5)
    if math.abs(x0) < threshold and math.abs(vel) < velThreshold then
        return target, 0
    end
    local z = zeta or 0.78
    local w0 = omega or 24.0
    local wd = w0 * math.sqrt(math.max(0.0001, 1.0 - z * z))
    local decay = math.exp(-z * w0 * dt)
    local a = x0
    local b = (vel + z * w0 * x0) / wd
    local sinVal = math.sin(wd * dt)
    local cosVal = math.cos(wd * dt)
    local newPos = target + decay * (a * cosVal + b * sinVal)
    local newVel = decay * (vel * cosVal - (z * w0 * b + wd * a) * sinVal)
    if math.abs(newPos - target) < threshold and math.abs(newVel) < velThreshold then
        return target, 0
    end
    return newPos, newVel
end

function MotionEngine.GetProfile(name)
    return MotionEngine.Profiles[name] or MotionEngine.Profiles.EXPAND
end

function MotionEngine.UpdateSmoothedDt(rawDt)
    local clamped = math.max(0.005, math.min(0.04, rawDt or 0.016))
    MotionEngine.SmoothedDt = MotionEngine.SmoothedDt + (clamped - MotionEngine.SmoothedDt) * 0.35
    return MotionEngine.SmoothedDt
end

local SolveDampedSpring = MotionEngine.SolveSpring

local Config = {
    Fonts = {
        Main = nil,
        Bold = nil
    },
    Colors = {
        Bg = Color(0, 0, 0, 245),
        Border = Color(255, 255, 255, 28),
        Shadow = Color(0, 0, 0, 135),
        TextPrimary = Color(255, 255, 255, 255),
        TextSecondary = Color(160, 160, 170, 255),
        TextMuted = Color(120, 120, 130, 255),
        Accent = Color(52, 199, 89, 255),
        Red = Color(255, 69, 58, 255),
        Orange = Color(255, 159, 10, 255),
        Yellow = Color(255, 214, 10, 255),
        Blue = Color(10, 132, 255, 255),
        ManaBlue = Color(0, 170, 255, 255),
        Purple = Color(191, 90, 242, 255),
        TrackProgressBg = Color(255, 255, 255, 40),
        GridOverlay = Color(0, 0, 0, 95),
        GridLine = Color(255, 255, 255, 18),
        GridAxis = Color(52, 199, 89, 140),
        GridHighlight = Color(52, 199, 89, 220),
        PMenuIslandBorder = Color(255, 255, 255, 65),
        
        ChipActive = Color(255, 255, 255, 52),
        ChipActiveBorder = Color(255, 255, 255, 225),
        ChipInactive = Color(255, 255, 255, 10),
        ChipInactiveBorder = Color(255, 255, 255, 24),
        
        InspectorBg = Color(10, 12, 18, 195),
        InspectorBorder = Color(255, 255, 255, 42),
        BtnBg = Color(255, 255, 255, 14),
        BtnBgActive = Color(255, 255, 255, 55),
        BtnBorder = Color(255, 255, 255, 28),
        BtnBorderActive = Color(255, 255, 255, 220),
        
        HintBg = Color(8, 10, 14, 180),
        HintBorder = Color(255, 255, 255, 25),

        SegTrack = Color(255, 255, 255, 20),
        SegThumb = Color(255, 255, 255, 58),
        SegThumbBorder = Color(255, 255, 255, 90),
        Grabber = Color(255, 255, 255, 60),
        TextInverse = Color(18, 18, 24, 255)
    },
    Dimensions = {
        CompactW = 120,
        CompactH = 34,
        CompactRadius = 17,
        
        CompactMediaW = 205,
        CompactMediaH = 34,
        CompactMediaRadius = 17,
        
        CompactFightW = 200,
        CompactFightH = 34,
        CompactFightRadius = 17,
        
        NotificationW = 250,
        NotificationH = 36,
        NotificationRadius = 18,
        
        ExpandedW = 335,
        ExpandedH = 88,
        ExpandedRadius = 26,
        
        LargeMediaW = 360,
        LargeMediaH = 148,
        LargeMediaRadius = 28,
        
        LargeFightW = 365,
        LargeFightH = 148,
        LargeFightRadius = 28,
        
        LargeW = 340,
        LargeH = 105,
        LargeRadius = 24,
        
        GamePausedW = 180,
        GamePausedH = 34,
        GamePausedRadius = 17,
        
        CourierDeliveryW = 230,
        CourierDeliveryH = 34,
        CourierDeliveryRadius = 17,
        
        CourierDeliveredW = 180,
        CourierDeliveredH = 34,
        CourierDeliveredRadius = 17,
        
        CourierLargeW = 340,
        CourierLargeH = 115,
        CourierLargeRadius = 24,
        
        FloorHeight = 34
    }
}

local StateMachine = {
    States = {
        COMPACT_IDLE = 1,
        COMPACT_MEDIA = 2,
        NOTIFICATION = 3,
        LARGE_MEDIA = 4,
        LARGE_IDLE = 5,
        COMPACT_FIGHT = 6,
        LARGE_FIGHT = 7,
        MENU_IDLE = 8,
        MENU_SEARCHING = 9,
        MENU_MATCH_FOUND = 10,
        GAME_PAUSED = 11,
        COURIER_DELIVERY = 12,
        COURIER_DELIVERED = 13,
        COURIER_LARGE = 14
    },
    Current = 1,
    TargetState = 1,
    PreviousState = 1,
    StateStartTime = 0,
    HoverStartTime = 0,
    UnhoverStartTime = 0,
    IsHovered = false,
    LastDrawTime = 0,
    
    Transition = {
        Active = false,
        FromState = 1,
        ToState = 1,
        Progress = 1.0,
        Duration = 0.32,
        StartTime = 0
    },
    
    Spring = {
        W = { value = 120, vel = 0, target = 120 },
        H = { value = 34, vel = 0, target = 34 },
        Radius = { value = 17, vel = 0, target = 17 },
        Squish = { value = 0, vel = 0, target = 0 }
    }
}

local ButtonSprings = {
    MediaPlay = { scale = 1.0, vel = 0 },
    MediaNext = { scale = 1.0, vel = 0 },
    MediaPrev = { scale = 1.0, vel = 0 },
    MediaLike = { scale = 1.0, vel = 0 },
    MediaShuffle = { scale = 1.0, vel = 0 },
    MediaRepeat = { scale = 1.0, vel = 0 },
    SatellitePrev = { scale = 1.0, vel = 0 },
    SatellitePlay = { scale = 1.0, vel = 0 },
    SatelliteNext = { scale = 1.0, vel = 0 }
}

local ThemeSpring = {
    factor = 0.0,
    vel = 0.0,
    target = 0.0
}

local TrackTransition = {
    Active = false,
    StartTime = 0,
    Duration = 0.28,
    Direction = 1,
    OldTitle = "",
    OldArtist = "",
    OldCoverHandle = nil,
    OldCoverColor = nil
}

local FightTracker = {
    Active = false,
    StartTime = 0,
    LastCombatTime = 0,
    Center = { x = 0, y = 0 },
    Allies = {},
    Enemies = {},
    AllyCount = 0,
    EnemyCount = 0,
    AlliesKilled = 0,
    EnemiesKilled = 0,
    HeroAliveState = {},
    Landmark = "",
    HeroHPMap = {},
    LastDamageTimes = {},
    SatelliteHover = false,
    SatelliteExpanded = false
}

local PauseTracker = {
    IsPaused = false,
    PauseStartTime = 0
}

local CourierTracker = {
    Delivering = false,
    Delivered = false,
    DeliveredStartTime = 0,
    DeliveredDuration = 1.5,
    DeliveryOrderedTime = 0,
    StartDistance = 0,
    CurrentDistance = 0,
    Progress = 0.0,
    Speed = 380,
    ETA = 0,
    Hp = 0,
    MaxHp = 1,
    HpPercent = 1.0,
    Inventory = {},
    LastItemCount = 0,
    CachedCourier = nil,
    BasePos = nil,
    IsGoingToStash = false
}

local VolumeState = {
    Current = 50,
    CurrentVel = 0.0,
    Target = 50,
    Alpha = 0.0,
    LastActive = 0,
    Visible = false,
    Overstretch = 0.0,
    OverstretchVel = 0.0,
    LastSoundTime = 0,
    LastBumpTime = 0
}

local DragState = {
    IsDragging = false,
    OffsetX = 0,
    OffsetY = 0,
    CustomX = -1,
    CustomY = -1,
    GridSize = 16
}

local HUDCustomizer = {
    IsOpen = false,
    InspectedChip = nil,
    DraggedId = nil,
    DragStartX = 0,
    DragCurrentX = 0,
    ActiveChips = { "clock", "kda" },
    AvailableChips = {
        { id = "clock", label = L("island.clock", "Clock") },
        { id = "kda", label = L("island.kda", "KDA") },
        { id = "gold", label = L("island.gold", "Gold") },
        { id = "networth", label = L("island.networth", "NW") },
        { id = "lasthits", label = L("island.lasthits", "LH") },
        { id = "heroname", label = L("island.hero", "Hero") },
        { id = "fps", label = L("island.fps", "FPS") },
        { id = "ping", label = L("island.ping", "Ping") }
    },
    WidgetConfigs = {
        clock = { bold = true, colorMode = 1, format = 1, showIcon = true },
        kda = { bold = false, colorMode = 1, format = 1, showIcon = true },
        gold = { bold = false, colorMode = 1, format = 1, showIcon = true },
        networth = { bold = false, colorMode = 1, format = 1, showIcon = true },
        lasthits = { bold = false, colorMode = 1, format = 1, showIcon = true },
        heroname = { bold = false, colorMode = 1, format = 1, showIcon = true },
        fps = { bold = false, colorMode = 1, format = 1, showIcon = true },
        ping = { bold = false, colorMode = 1, format = 1, showIcon = true }
    },
    DrawerBounds = {},
    PillBounds = {},
    InspectorBounds = {},
    TotalUIBounds = {},
    Anim = {
        t = 0, h = 0, hVel = 0, LastId = false, Chips = {},
        SegWeight = { v = 0, vel = 0 },
        SegColor = { v = 0, vel = 0 },
        SegFormat = { v = 0, vel = 0 },
        Knob = { v = 0, vel = 0 }
    }
}

local PerformanceData = {
    FPS = 60,
    Ping = 30,
    LastFPSUpdate = 0,
    FrameCount = 0
}

local MediaData = {
    IsPlaying = false,
    Title = "",
    Artist = "",
    Album = "",
    Position = 0,
    Duration = 0,
    App = "",
    LastPollTime = 0,
    PollInterval = 0.35,
    LocalTimeAtPoll = 0,
    HasReceivedData = false,
    LastTrackKey = "",
    LastPlayTime = 0,
    LastPauseTime = 0,
    CoverPath = "",
    CoverJpg = "",
    CoverBase64 = "",
    CoverColor = Color(255, 45, 85, 255),
    CoverVersion = -1,
    CoverImageHandle = nil,
    HasCover = false,
    IsLiked = false,
    LikedTracks = {},
    Shuffle = false,
    RepeatMode = 0,
    RealBars = { 0, 0, 0, 0, 0 },
    SmoothBars = { 0, 0, 0, 0, 0 }
}

local HeroData = {
    Local = nil,
    Level = 0,
    Kills = 0,
    Deaths = 0,
    Assists = 0,
    Gold = 0,
    NetWorth = 0,
    LastHits = 0,
    Denies = 0,
    HeroName = "",
    LastKilled = {
        Name = "",
        MaxHP = 0,
        Level = 0,
        Items = {}
    },
    EnemyInventoryCache = {},
    EnemyHeroes = {},
    LowHPCache = {}
}

local GameTracker = {
    Roshan = {
        IsAlive = true,
        DeathTime = 0,
        AegisExpiryTime = 0,
        RespawnMinTime = 0,
        RespawnMaxTime = 0,
        HasAegis = false,
        LastAttackAlert = 0,
        Dismissed = false
    },
    Towers = {
        LastHP = {},
        LastAlert = {}
    },
    Couriers = {
        LastHP = {},
        LastAlert = 0
    },
    Runes = {
        WarnedMilestones = {},
        KnownWorldRunes = {}
    },
    Neutrals = {
        Tier1 = false,
        Tier2 = false,
        Tier3 = false,
        Tier4 = false,
        Tier5 = false
    },
    Lotus = {
        LastAlertTime = 0
    },
    Tormentor = {
        Warned1 = false,
        Warned2 = false
    },
    Buybacks = {},
    LastScanTime = 0
}

local NotificationQueue = {
    List = {},
    Active = nil,
    StartTime = 0,
    LastDismissed = nil
}

local SatelliteBounds = nil
local SatelliteSubBounds = {}
local ImageCache = {}

local ButtonHits = {
    MediaPrev = nil,
    MediaPlay = nil,
    MediaNext = nil,
    MediaLike = nil,
    MediaShuffle = nil,
    MediaRepeat = nil,
    SatellitePrev = nil,
    SatellitePlay = nil,
    SatelliteNext = nil
}

local MouseInput = {
    LeftPressed = false,
    LeftLastPressed = false,
    RightPressed = false,
    RightLastPressed = false
}

local KeyItemColors = {
    ["item_blink"] = { name = "Blink Dagger", col = Color(70, 225, 255, 255) },
    ["item_black_king_bar"] = { name = "BKB", col = Color(255, 210, 30, 255) },
    ["item_sheepstick"] = { name = "Scythe of Vyse", col = Color(140, 230, 255, 255) },
    ["item_orchid"] = { name = "Orchid", col = Color(255, 50, 90, 255) },
    ["item_bloodthorn"] = { name = "Bloodthorn", col = Color(255, 30, 70, 255) },
    ["item_rapier"] = { name = "Divine Rapier", col = Color(255, 215, 0, 255) },
    ["item_ultimate_scepter"] = { name = "Aghanim Scepter", col = Color(120, 160, 255, 255) },
    ["item_refresher"] = { name = "Refresher Orb", col = Color(75, 245, 135, 255) },
    ["item_radiance"] = { name = "Radiance", col = Color(255, 175, 20, 255) },
    ["item_heart"] = { name = "Heart of Tarrasque", col = Color(255, 45, 65, 255) },
    ["item_assault"] = { name = "Assault Cuirass", col = Color(255, 130, 35, 255) },
    ["item_butterfly"] = { name = "Butterfly", col = Color(105, 240, 110, 255) },
    ["item_nullifier"] = { name = "Nullifier", col = Color(255, 195, 45, 255) },
    ["item_satanic"] = { name = "Satanic", col = Color(235, 30, 50, 255) },
    ["item_aeon_disk"] = { name = "Aeon Disk", col = Color(120, 235, 255, 255) },
    ["item_silver_edge"] = { name = "Silver Edge", col = Color(195, 95, 255, 255) },
    ["item_invis_sword"] = { name = "Shadow Blade", col = Color(170, 85, 255, 255) },
    ["item_monkey_king_bar"] = { name = "MKB", col = Color(255, 160, 30, 255) },
    ["item_abyssal_blade"] = { name = "Abyssal Blade", col = Color(185, 75, 75, 255) },
    ["item_manta"] = { name = "Manta Style", col = Color(85, 185, 255, 255) },
    ["item_greater_crit"] = { name = "Daedalus", col = Color(255, 55, 55, 255) },
    ["item_desolator"] = { name = "Desolator", col = Color(255, 40, 40, 255) },
    ["item_moon_shard"] = { name = "Moon Shard", col = Color(215, 155, 255, 255) }
}

local StrictInvisModifiers = {
    ["modifier_item_invisibility_edge_windwalk"] = { name = "Shadow Blade", icon = "panorama/images/items/invis_sword_png.vtex_c", col = Color(160, 90, 255, 255) },
    ["modifier_item_silver_edge_windwalk"] = { name = "Silver Edge", icon = "panorama/images/items/silver_edge_png.vtex_c", col = Color(220, 100, 255, 255) },
    ["modifier_item_smoke_of_deceit"] = { name = "Smoke of Deceit", icon = "panorama/images/items/smoke_of_deceit_png.vtex_c", col = Color(255, 140, 40, 255) },
    ["modifier_clinkz_skeleton_walk"] = { name = "Skeleton Walk", icon = "panorama/images/spellicons/clinkz_skeleton_walk_png.vtex_c", col = Color(255, 100, 40, 255) },
    ["modifier_clinkz_strafe_invis"] = { name = "Skeleton Walk", icon = "panorama/images/spellicons/clinkz_skeleton_walk_png.vtex_c", col = Color(255, 100, 40, 255) },
    ["modifier_nyx_assassin_vendetta"] = { name = "Vendetta", icon = "panorama/images/spellicons/nyx_assassin_vendetta_png.vtex_c", col = Color(230, 60, 60, 255) },
    ["modifier_mirana_moonlight_shadow"] = { name = "Moonlight Shadow", icon = "panorama/images/spellicons/mirana_moonlight_shadow_png.vtex_c", col = Color(100, 200, 255, 255) }
}

local RuneInfoList = {
    [Enum.RuneType.DOTA_RUNE_DOUBLEDAMAGE] = { en = "Double Damage", ru = "Двойной урон", col = Color(65, 140, 255, 255), path = "panorama/images/spellicons/rune_doubledamage_png.vtex_c", svg = "rune_dd" },
    [Enum.RuneType.DOTA_RUNE_HASTE] = { en = "Haste", ru = "Ускорение", col = Color(255, 65, 65, 255), path = "panorama/images/spellicons/rune_haste_png.vtex_c", svg = "rune_haste" },
    [Enum.RuneType.DOTA_RUNE_ILLUSION] = { en = "Illusion", ru = "Иллюзии", col = Color(255, 205, 45, 255), path = "panorama/images/spellicons/rune_illusion_png.vtex_c", svg = "rune_dd" },
    [Enum.RuneType.DOTA_RUNE_INVISIBILITY] = { en = "Invisibility", ru = "Невидимость", col = Color(170, 85, 255, 255), path = "panorama/images/spellicons/rune_invis_png.vtex_c", svg = "rune_invis" },
    [Enum.RuneType.DOTA_RUNE_REGENERATION] = { en = "Regeneration", ru = "Регенерация", col = Color(85, 255, 125, 255), path = "panorama/images/spellicons/rune_regen_png.vtex_c", svg = "rune_regen" },
    [Enum.RuneType.DOTA_RUNE_BOUNTY] = { en = "Bounty", ru = "Богатство", col = Color(255, 175, 10, 255), path = "panorama/images/items/courier_gold_png.vtex_c", svg = "bounty" },
    [Enum.RuneType.DOTA_RUNE_ARCANE] = { en = "Arcane", ru = "Волшебство", col = Color(235, 85, 255, 255), path = "panorama/images/spellicons/rune_arcane_png.vtex_c", svg = "rune_arcane" },
    [Enum.RuneType.DOTA_RUNE_WATER] = { en = "Water", ru = "Вода", col = Color(0, 215, 255, 255), path = "panorama/images/items/bottle_water_png.vtex_c", svg = "rune_water" },
    [Enum.RuneType.DOTA_RUNE_XP] = { en = "Wisdom", ru = "Мудрость", col = Color(185, 105, 255, 255), path = "panorama/images/spellicons/rune_xp_png.vtex_c", svg = "rune_wisdom" },
    [Enum.RuneType.DOTA_RUNE_SHIELD] = { en = "Shield", ru = "Щит", col = Color(255, 225, 105, 255), path = "panorama/images/spellicons/rune_shield_png.vtex_c", svg = "rune_shield" }
}

local RuneModifierMap = {
    ["modifier_rune_doubledamage"] = Enum.RuneType.DOTA_RUNE_DOUBLEDAMAGE,
    ["modifier_rune_haste"] = Enum.RuneType.DOTA_RUNE_HASTE,
    ["modifier_rune_regen"] = Enum.RuneType.DOTA_RUNE_REGENERATION,
    ["modifier_rune_arcane"] = Enum.RuneType.DOTA_RUNE_ARCANE,
    ["modifier_rune_shield"] = Enum.RuneType.DOTA_RUNE_SHIELD,
    ["modifier_rune_water"] = Enum.RuneType.DOTA_RUNE_WATER,
    ["modifier_rune_invis"] = Enum.RuneType.DOTA_RUNE_INVISIBILITY,
    ["modifier_rune_illusion"] = Enum.RuneType.DOTA_RUNE_ILLUSION
}

local MapLandmarks = {
    { name = L("Верхний Рошан (Река)", "Top Roshan (River)"), pos = { x = -2400, y = 1800 } },
    { name = L("Нижний Рошан (Река)", "Bot Roshan (River)"), pos = { x = 2400, y = -1800 } },
    { name = L("Верхняя руна реки", "Top River Rune"), pos = { x = -1600, y = 1200 } },
    { name = L("Нижняя руна реки", "Bot River Rune"), pos = { x = 1200, y = -1600 } },
    { name = L("Центр реки", "River Center"), pos = { x = -100, y = -100 } },
    
    { name = L("Тройка Света", "Radiant Triangle"), pos = { x = -3400, y = -1800 } },
    { name = L("Тройка Тьмы", "Dire Triangle"), pos = { x = 3400, y = 1800 } },
    { name = L("Лес Света", "Radiant Jungle"), pos = { x = 2200, y = -4400 } },
    { name = L("Лес Тьмы", "Dire Jungle"), pos = { x = -2200, y = 4400 } },
    
    { name = L("Терзатель Света", "Radiant Tormentor"), pos = { x = 3800, y = -5800 } },
    { name = L("Терзатель Тьмы", "Dire Tormentor"), pos = { x = -3800, y = 5800 } },
    { name = L("Пруд Лотосов (Топ)", "Lotus Pool (Top)"), pos = { x = -6000, y = 5600 } },
    { name = L("Пруд Лотосов (Бот)", "Lotus Pool (Bot)"), pos = { x = 6000, y = -5600 } },
    { name = L("Святилище Мудрости (Свет)", "Wisdom Shrine (Radiant)"), pos = { x = -7600, y = -3600 } },
    { name = L("Святилище Мудрости (Тьма)", "Wisdom Shrine (Dire)"), pos = { x = 7600, y = 3600 } },
    { name = L("Парный Портал (Топ)", "Twin Gate (Top)"), pos = { x = -7800, y = 7400 } },
    { name = L("Парный Портал (Бот)", "Twin Gate (Bot)"), pos = { x = 7800, y = -7400 } },
    
    { name = L("Мид линия", "Mid lane"), pos = { x = 0, y = 0 } },
    { name = L("Топ линия", "Top lane"), pos = { x = -5500, y = 4800 } },
    { name = L("Бот линия", "Bot lane"), pos = { x = 5200, y = -5200 } },
    { name = L("База Сил Света", "Radiant Base"), pos = { x = -6500, y = -6500 } },
    { name = L("База Сил Тьмы", "Dire Base"), pos = { x = 6500, y = 6500 } }
}

local VectorIcons = {
    ["bounty"] = '<svg viewBox="0 0 24 24" width="24" height="24"><circle cx="12" cy="12" r="10" fill="#FFB300"/><circle cx="12" cy="12" r="7.5" fill="#FF8F00"/><text x="12" y="16" font-size="11" font-weight="900" font-family="sans-serif" text-anchor="middle" fill="#FFF">$</text></svg>',
    ["lotus"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M12 2C8 6 3 11 3 16a9 9 0 0 0 18 0C21 11 16 6 12 2z" fill="#FF69B4"/><circle cx="12" cy="15" r="4.5" fill="#FFD700"/></svg>',
    ["wisdom"] = '<svg viewBox="0 0 24 24" width="24" height="24"><polygon points="12,2 22,8.5 22,15.5 12,22 2,15.5 2,8.5" fill="#8A2BE2"/><text x="12" y="15" font-size="10" font-weight="bold" font-family="sans-serif" text-anchor="middle" fill="#FFF">XP</text></svg>',
    ["rune_wisdom"] = '<svg viewBox="0 0 24 24" width="24" height="24"><polygon points="12,2 21.5,8 18,21 6,21 2.5,8" fill="#7B1FA2" stroke="#BA68C8" stroke-width="1.2"/><polygon points="12,5 18,9.5 15.5,18.5 8.5,18.5 6,9.5" fill="#9C27B0"/><polygon points="12,7 15.5,10 14,16 10,16 8.5,10" fill="#E1BEE7"/></svg>',
    ["rune_water"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M12 2.5 C12 2.5 4.5 11.5 4.5 16 C4.5 20.1 7.9 23.5 12 23.5 C16.1 23.5 19.5 20.1 19.5 16 C19.5 11.5 12 2.5 12 2.5 Z" fill="#00B0FF" stroke="#80D8FF" stroke-width="1.2"/><path d="M9 13.5 C9 13.5 7.5 16.5 7.5 18 C7.5 19.4 8.6 20.5 10 20.5" fill="none" stroke="#FFFFFF" stroke-width="1.5" stroke-linecap="round"/></svg>',
    ["rune_dd"] = '<svg viewBox="0 0 24 24" width="24" height="24"><circle cx="12" cy="12" r="10" fill="#2196F3"/><path fill="#FFF" d="M13 10V3L4 14h7v7l9-11h-7z"/></svg>',
    ["rune_haste"] = '<svg viewBox="0 0 24 24" width="24" height="24"><circle cx="12" cy="12" r="10" fill="#F44336"/><path fill="#FFF" d="M12 4l-1.41 1.41L16.17 11H4v2h12.17l-5.58 5.59L12 20l8-8z"/></svg>',
    ["rune_invis"] = '<svg viewBox="0 0 24 24" width="24" height="24"><circle cx="12" cy="12" r="10" fill="#9C27B0"/><path fill="#FFF" d="M12 6.5C8 6.5 4.5 9 3 12c1.5 3 5 5.5 9 5.5s7.5-2.5 9-5.5c-1.5-3-5-5.5-9-5.5zm0 9a3.5 3.5 0 1 1 0-7 3.5 3.5 0 0 1 0 7z"/></svg>',
    ["rune_regen"] = '<svg viewBox="0 0 24 24" width="24" height="24"><circle cx="12" cy="12" r="10" fill="#4CAF50"/><path fill="#FFF" d="M12 19.5l-1.2-1.1C6.5 14.5 3.5 11.8 3.5 8.5 3.5 5.8 5.6 3.7 8.3 3.7c1.5 0 3 .7 3.7 1.8.7-1.1 2.2-1.8 3.7-1.8 2.7 0 4.8 2.1 4.8 4.8 0 3.3-3 6-7.3 9.9L12 19.5z"/></svg>',
    ["rune_arcane"] = '<svg viewBox="0 0 24 24" width="24" height="24"><circle cx="12" cy="12" r="10" fill="#E91E63"/><path fill="#FFF" d="M13.5 2s.7 2.3.7 4.2c0 1.8-1.2 3.3-3 3.3-1.8 0-3.2-1.5-3.2-3.3l.03-.3C5.5 7.8 4.5 10.5 4.5 13.5c0 3.9 3.1 7 7 7s7-3.1 7-7c0-4.7-2.3-8.9-5-11.5z"/></svg>',
    ["rune_shield"] = '<svg viewBox="0 0 24 24" width="24" height="24"><circle cx="12" cy="12" r="10" fill="#FFC107"/><path fill="#FFF" d="M12 3L4.5 6.5v5.3c0 4.9 3.4 9.5 7.5 10.7 4.1-1.2 7.5-5.8 7.5-10.7V6.5L12 3z"/></svg>',
    ["buyback"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path fill="#FFD700" d="M17.65 6.35C16.2 4.9 14.21 4 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08c-.82 2.33-3.04 4-5.65 4-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z"/></svg>',
    ["swords"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path fill="#FFFFFF" d="M21 3a1 1 0 0 0-1.4 0L14 8.6l-1.3-1.3a1 1 0 0 0-1.4 1.4l1.3 1.3-7.2 7.2a1 1 0 0 0 0 1.4l1.4 1.4-3.5 3.5a1 1 0 1 0 1.4 1.4l3.5-3.5 1.4 1.4a1 1 0 0 0 1.4 0l7.2-7.2 1.3 1.3a1 1 0 0 0 1.4-1.4l-1.3-1.3 5.6-5.6A1 1 0 0 0 21 3zM3 3a1 1 0 0 0 0 1.4l5.6 5.6-1.3 1.3a1 1 0 0 0 1.4 1.4l1.3-1.3 7.2 7.2a1 1 0 0 0 1.4 0l1.4-1.4 3.5 3.5a1 1 0 0 0 1.4-1.4l-3.5-3.5 1.4-1.4a1 1 0 0 0 0-1.4l-7.2-7.2 1.3-1.3a1 1 0 0 0-1.4-1.4l-1.3 1.3L4.4 3A1 1 0 0 0 3 3z"/></svg>',
    ["flame"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path fill="#FFFFFF" d="M12 2C9.5 5.5 8 8.5 8 11.5c0 1.2.3 2.3.8 3.3-.5-.4-.9-.9-1.2-1.5-.4-.9-.6-1.9-.6-2.9C5.3 12.2 4 14.5 4 17c0 4.4 3.6 8 8 8s8-3.6 8-8c0-4.5-3.5-8.5-8-15zm1 18.5c-2.5 0-4.5-2-4.5-4.5 0-1.5.8-2.9 2-3.7.3.8.8 1.5 1.5 2 .7.5 1.5.8 2.4.8.4 0 .7-.1 1.1-.2-.4 3.2-2.3 5.6-2.5 5.6z"/></svg>',
    ["media_prev"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path fill="#FFFFFF" d="M11 17.5V6.5c0-.8-.9-1.2-1.5-.7L2.4 11.3c-.5.4-.5 1.1 0 1.5l7.1 5.5c.6.5 1.5.1 1.5-.8zm10.5 0V6.5c0-.8-.9-1.2-1.5-.7L12.9 11.3c-.5.4-.5 1.1 0 1.5l7.1 5.5c.6.5 1.5.1 1.5-.8z"/></svg>',
    ["media_next"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path fill="#FFFFFF" d="M13 6.5v11c0 .8.9 1.2 1.5.7l7.1-5.5c.5-.4.5-1.1 0-1.5l-7.1-5.5c-.6-.5-1.5-.1-1.5.8zM2.5 6.5v11c0 .8.9 1.2 1.5.7l7.1-5.5c.5-.4.5-1.1 0-1.5L4 5.7c-.6-.5-1.5-.1-1.5.8z"/></svg>',
    ["media_play"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path fill="#FFFFFF" d="M6.5 5.2c0-.9 1-1.5 1.8-1l12.4 6.8c.8.4.8 1.6 0 2.1L8.3 19.8c-.8.5-1.8-.1-1.8-1V5.2z"/></svg>',
    ["media_pause"] = '<svg viewBox="0 0 24 24" width="24" height="24"><rect x="5" y="4" width="4.5" height="16" rx="2" fill="#FFFFFF"/><rect x="14.5" y="4" width="4.5" height="16" rx="2" fill="#FFFFFF"/></svg>',
    
    ["heart_outline"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" fill="none" stroke="#FFF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["heart_fill"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" fill="#FFF"/></svg>',
    ["shuffle"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M16 3h5v5M4 20l7.5-7.5M21 3l-7.5 7.5M4 4l16 16M21 16v5h-5" fill="none" stroke="#FFF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["repeat"] = '<svg viewBox="0 0 24 24" width="24" height="24"><polyline points="17 1 21 5 17 9" fill="none" stroke="#FFF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M3 11V9a4 4 0 0 1 4-4h14M7 23l-4-4 4-4" fill="none" stroke="#FFF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M21 13v2a4 4 0 0 1-4 4H3" fill="none" stroke="#FFF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    
    ["clock"] = '<svg viewBox="0 0 24 24" width="24" height="24"><circle cx="12" cy="12" r="9" fill="none" stroke="#FFF" stroke-width="1.8"/><polyline points="12,7 12,12 15.5,14" fill="none" stroke="#FFF" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["kda"] = '<svg viewBox="0 0 24 24" width="24" height="24"><circle cx="12" cy="12" r="8" fill="none" stroke="#FFF" stroke-width="1.8"/><line x1="12" y1="1" x2="12" y2="5" stroke="#FFF" stroke-width="1.8" stroke-linecap="round"/><line x1="12" y1="19" x2="12" y2="23" stroke="#FFF" stroke-width="1.8" stroke-linecap="round"/><line x1="1" y1="12" x2="5" y2="12" stroke="#FFF" stroke-width="1.8" stroke-linecap="round"/><line x1="19" y1="12" x2="23" y2="12" stroke="#FFF" stroke-width="1.8" stroke-linecap="round"/><circle cx="12" cy="12" r="2" fill="#FFF"/></svg>',
    ["gold"] = '<svg viewBox="0 0 24 24" width="24" height="24"><circle cx="12" cy="12" r="9" fill="none" stroke="#FFF" stroke-width="1.8"/><path d="M12 6.5v11M14.5 9.2a2.2 2.2 0 0 0-2.2-2.2H11a2 2 0 0 0 0 4h2a2 2 0 0 1 0 4h-1.3a2.2 2.2 0 0 1-2.2-2.2" fill="none" stroke="#FFF" stroke-width="1.8" stroke-linecap="round"/></svg>',
    ["networth"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M3.5 4.5v15a1 1 0 0 0 1 1h15" fill="none" stroke="#FFF" stroke-width="1.8" stroke-linecap="round"/><path d="M7 14.5l4-4.5 3.5 3.5 5.5-6.5M16.5 7H20v3.5" fill="none" stroke="#FFF" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["lasthits"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M14.5 4l5.5 5.5-9 9-4 1 1-4 9-9zM13 5.5l5.5 5.5" fill="none" stroke="#FFF" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["heroname"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M3.5 18.5h17M4.5 15.5l2.5-8 5 4 5-4 2.5 8H4.5z" fill="none" stroke="#FFF" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["fps"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M12 4a9 9 0 0 0-9 9c0 3.2 1.7 6 4.3 7.6M16.7 20.6A9 9 0 0 0 21 13a9 9 0 0 0-9-9" fill="none" stroke="#FFF" stroke-width="1.8" stroke-linecap="round"/><line x1="12" y1="13" x2="16.5" y2="8.5" stroke="#FFF" stroke-width="1.8" stroke-linecap="round"/><circle cx="12" cy="13" r="1.8" fill="#FFF"/></svg>',
    ["ping"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M4 8.5a11.5 11.5 0 0 1 16 0" fill="none" stroke="#FFF" stroke-width="1.8" stroke-linecap="round"/><path d="M7.5 12.5a6.5 6.5 0 0 1 9 0" fill="none" stroke="#FFF" stroke-width="1.8" stroke-linecap="round"/><circle cx="12" cy="17.5" r="1.8" fill="#FFF"/></svg>',
    ["home"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M3 10.5L12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1v-9.5z" fill="none" stroke="#FFF" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["search"] = '<svg viewBox="0 0 24 24" width="24" height="24"><circle cx="10.5" cy="10.5" r="6.5" fill="none" stroke="#FFF" stroke-width="2.2"/><line x1="15.5" y1="15.5" x2="21" y2="21" stroke="#FFF" stroke-width="2.2" stroke-linecap="round"/></svg>',
    ["check"] = '<svg viewBox="0 0 24 24" width="24" height="24"><polyline points="4,12 9,17 20,6" fill="none" stroke="#34C759" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["courier"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path fill="#FFD60A" d="M19.38 6.81l-6.5-3.61a1.76 1.76 0 0 0-1.76 0l-6.5 3.61A1.76 1.76 0 0 0 3.75 8.35v7.3a1.76 1.76 0 0 0 .87 1.54l6.5 3.61a1.76 1.76 0 0 0 1.76 0l6.5-3.61a1.76 1.76 0 0 0 .87-1.54v-7.3a1.76 1.76 0 0 0-.87-1.54zm-7.38-2.1l6.12 3.4-2.6 1.45-6.13-3.41 2.61-1.44zm-7 4.19l6.13 3.41v6.86L5 15.76V8.9zm8 10.27v-6.86l6.13-3.41v6.86l-6.13 3.41z"/></svg>',
    ["pause"] = '<svg viewBox="0 0 24 24" width="24" height="24"><circle cx="12" cy="12" r="11" fill="#FF9500"/><rect x="7.5" y="6.5" width="3" height="11" rx="1.5" fill="#FFFFFF"/><rect x="13.5" y="6.5" width="3" height="11" rx="1.5" fill="#FFFFFF"/></svg>',
    ["volume"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path fill="#FFFFFF" d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/></svg>',
    ["apple_check"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path fill="#34C759" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1.2 15.2l-4.5-4.5 1.41-1.41 3.09 3.08 7.09-7.09 1.41 1.41-8.5 8.51z"/></svg>'
}

local PowerRunesCycleList = {
    { path = "panorama/images/spellicons/rune_doubledamage_png.vtex_c", svg = "rune_dd", col = Color(60, 140, 255, 255) },
    { path = "panorama/images/spellicons/rune_haste_png.vtex_c", svg = "rune_haste", col = Color(255, 65, 65, 255) },
    { path = "panorama/images/spellicons/rune_invis_png.vtex_c", svg = "rune_invis", col = Color(170, 85, 255, 255) },
    { path = "panorama/images/spellicons/rune_arcane_png.vtex_c", svg = "rune_arcane", col = Color(235, 85, 255, 255) },
    { path = "panorama/images/spellicons/rune_regen_png.vtex_c", svg = "rune_regen", col = Color(85, 255, 125, 255) },
    { path = "panorama/images/spellicons/rune_shield_png.vtex_c", svg = "rune_shield", col = Color(255, 215, 60, 255) }
}

local UI = nil


local function CleanUnescapedString(s)
    if not s or s == "" then return "" end
    local res = s
    res = string.gsub(res, "\\u0027", "'")
    res = string.gsub(res, "\\u0022", '"')
    res = string.gsub(res, "\\u0026", "&")
    res = string.gsub(res, "\\u003c", "<")
    res = string.gsub(res, "\\u003e", ">")
    return res
end

local ConfigSavePaths = { "dynamic_island_config.json", "C:/Umbrella/scripts/dynamic_island_config.json", "scripts/dynamic_island_config.json" }

local PALETTE = {
    { r = 255, g = 69,  b = 58,  hex = "FF453A" },
    { r = 255, g = 159, b = 10,  hex = "FF9F0A" },
    { r = 255, g = 214, b = 10,  hex = "FFD60A" },
    { r = 48,  g = 209, b = 88,  hex = "30D158" },
    { r = 99,  g = 230, b = 226, hex = "63E6E2" },
    { r = 10,  g = 132, b = 255, hex = "0A84FF" },
    { r = 191, g = 90,  b = 242, hex = "BF5AF2" },
    { r = 255, g = 55,  b = 95,  hex = "FF375F" },
    { r = 255, g = 255, b = 255, hex = "FFFFFF" }
}

local function HexToColor(hex)
    if not hex or #hex < 6 then return nil end
    local r = tonumber(string.sub(hex, 1, 2), 16)
    local g = tonumber(string.sub(hex, 3, 4), 16)
    local b = tonumber(string.sub(hex, 5, 6), 16)
    if r and g and b then
        return Color(r, g, b, 255)
    end
    return nil
end

local function GetDefaultWidgetColor(chipId)
    if chipId == "gold" then return Color(255, 215, 30, 255), "FFD71E"
    elseif chipId == "kda" then return Color(52, 199, 89, 255), "34C759"
    elseif chipId == "clock" then return Color(255, 180, 40, 255), "FFB428"
    elseif chipId == "networth" then return Color(70, 225, 255, 255), "46E1FF"
    elseif chipId == "lasthits" then return Color(255, 150, 50, 255), "FF9632"
    elseif chipId == "heroname" then return Color(195, 110, 255, 255), "C36EFF"
    elseif chipId == "fps" then return Color(48, 209, 88, 255), "30D158"
    elseif chipId == "ping" then return Color(10, 132, 255, 255), "0A84FF"
    end
    return Color(0, 195, 255, 255), "00C3FF"
end

local function HSVtoRGB(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b = 0, 0, 0
    if h < 60 then r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end
    return math.floor((r + m) * 255), math.floor((g + m) * 255), math.floor((b + m) * 255)
end

local function RGBtoHSV(r, g, b)
    r, g, b = r / 255, g / 255, b / 255
    local maxC = math.max(r, g, b)
    local minC = math.min(r, g, b)
    local delta = maxC - minC
    local h, s, v = 0, 0, maxC
    if maxC > 0 then
        s = delta / maxC
    else
        return 0, 0, 0
    end
    if delta == 0 then
        h = 0
    elseif maxC == r then
        h = ((g - b) / delta) % 6
    elseif maxC == g then
        h = (b - r) / delta + 2
    else
        h = (r - g) / delta + 4
    end
    h = h * 60
    if h < 0 then h = h + 360 end
    return h, s, v
end

local function RGBtoHue(r, g, b)
    r, g, b = r / 255, g / 255, b / 255
    local maxC = math.max(r, g, b)
    local minC = math.min(r, g, b)
    local delta = maxC - minC
    if delta == 0 then return 0 end
    local h = 0
    if maxC == r then
        h = ((g - b) / delta) % 6
    elseif maxC == g then
        h = (b - r) / delta + 2
    else
        h = (r - g) / delta + 4
    end
    h = h * 60
    if h < 0 then h = h + 360 end
    return h
end

local function SaveAllConfig()
    local paths = ConfigSavePaths
    for _, path in ipairs(paths) do
        local f = io.open(path, "w")
        if f then
            local activeStr = table.concat(HUDCustomizer.ActiveChips, ",")
            f:write("active=" .. activeStr .. "\n")
            f:write(string.format("drag_center=%d,%d\n", math.floor(DragState.CustomX or -1), math.floor(DragState.CustomY or -1)))
            
            for id, cfg in pairs(HUDCustomizer.WidgetConfigs) do
                f:write(string.format("cfg_%s=%s,%d,%d,%s,%s\n", id, cfg.bold and "1" or "0", cfg.colorMode or 1, cfg.format or 1, cfg.showIcon and "1" or "0", cfg.customHex or ""))
            end
            
            if UI then
                if UI.Main then
                    if UI.Main.Enabled then f:write("ui_enabled=" .. (UI.Main.Enabled:Get() and "1" or "0") .. "\n") end
                    if UI.Main.OnlyInGame then f:write("ui_only_game=" .. (UI.Main.OnlyInGame:Get() and "1" or "0") .. "\n") end
                    if UI.Main.Preset then f:write("ui_preset=" .. tostring(UI.Main.Preset:Get()) .. "\n") end
                    if UI.Main.OffsetY then f:write("ui_offset_y=" .. tostring(UI.Main.OffsetY:Get()) .. "\n") end
                    if UI.Main.OffsetX then f:write("ui_offset_x=" .. tostring(UI.Main.OffsetX:Get()) .. "\n") end
                    if UI.Main.Scale then f:write("ui_scale=" .. tostring(UI.Main.Scale:Get()) .. "\n") end
                    if UI.Main.CustomLabel then f:write("ui_label=" .. tostring(UI.Main.CustomLabel:Get() or "") .. "\n") end
                    if UI.Main.PureGlass then f:write("ui_pure_glass=" .. (UI.Main.PureGlass:Get() and "1" or "0") .. "\n") end
                    if UI.Main.IslandBgColor then
                        local c = UI.Main.IslandBgColor:Get()
                        f:write(string.format("ui_bg_col=%d,%d,%d,%d\n", math.floor(c.r), math.floor(c.g), math.floor(c.b), math.floor(c.a or 255)))
                    end
                end
                if UI.Combat then
                    if UI.Combat.FightHUD then f:write("ui_c_fighthud=" .. (UI.Combat.FightHUD:Get() and "1" or "0") .. "\n") end
                    if UI.Combat.FightScope then f:write("ui_c_fightscope=" .. tostring(UI.Combat.FightScope:Get()) .. "\n") end
                    if UI.Combat.MinHeroes then f:write("ui_c_minheroes=" .. tostring(UI.Combat.MinHeroes:Get()) .. "\n") end
                    if UI.Combat.FightRadius then f:write("ui_c_fightradius=" .. tostring(UI.Combat.FightRadius:Get()) .. "\n") end
                    if UI.Combat.RadarZoom then f:write("ui_c_radarzoom=" .. tostring(UI.Combat.RadarZoom:Get()) .. "\n") end
                    if UI.Combat.FightTimeout then f:write("ui_c_fighttimeout=" .. tostring(UI.Combat.FightTimeout:Get()) .. "\n") end
                    if UI.Combat.Kills then f:write("ui_c_kills=" .. (UI.Combat.Kills:Get() and "1" or "0") .. "\n") end
                    if UI.Combat.Invis then f:write("ui_c_invis=" .. (UI.Combat.Invis:Get() and "1" or "0") .. "\n") end
                    if UI.Combat.Teleports then f:write("ui_c_tp=" .. (UI.Combat.Teleports:Get() and "1" or "0") .. "\n") end
                    if UI.Combat.KeyEnemyItems then f:write("ui_c_items=" .. (UI.Combat.KeyEnemyItems:Get() and "1" or "0") .. "\n") end
                    if UI.Combat.Couriers then f:write("ui_c_courier=" .. (UI.Combat.Couriers:Get() and "1" or "0") .. "\n") end
                    if UI.Combat.Towers then f:write("ui_c_tower=" .. (UI.Combat.Towers:Get() and "1" or "0") .. "\n") end
                    if UI.Combat.Buybacks then f:write("ui_c_bb=" .. (UI.Combat.Buybacks:Get() and "1" or "0") .. "\n") end
                    if UI.Combat.LowHP then f:write("ui_c_lowhp=" .. (UI.Combat.LowHP:Get() and "1" or "0") .. "\n") end
                    if UI.Combat.LevelUp then f:write("ui_c_lvl=" .. (UI.Combat.LevelUp:Get() and "1" or "0") .. "\n") end
                end
                if UI.Runes then
                    if UI.Runes.ActiveRunes then f:write("ui_r_active=" .. (UI.Runes.ActiveRunes:Get() and "1" or "0") .. "\n") end
                    if UI.Runes.WaterRunes then f:write("ui_r_water=" .. (UI.Runes.WaterRunes:Get() and "1" or "0") .. "\n") end
                    if UI.Runes.BountyRunes then f:write("ui_r_bounty=" .. (UI.Runes.BountyRunes:Get() and "1" or "0") .. "\n") end
                    if UI.Runes.WisdomRunes then f:write("ui_r_wisdom=" .. (UI.Runes.WisdomRunes:Get() and "1" or "0") .. "\n") end
                    if UI.Runes.RunePickups then f:write("ui_r_pick=" .. (UI.Runes.RunePickups:Get() and "1" or "0") .. "\n") end
                    if UI.Runes.RuneWorldSpawn then f:write("ui_r_world=" .. (UI.Runes.RuneWorldSpawn:Get() and "1" or "0") .. "\n") end
                    if UI.Runes.Lotus then f:write("ui_r_lotus=" .. (UI.Runes.Lotus:Get() and "1" or "0") .. "\n") end
                    if UI.Runes.Tormentor then f:write("ui_r_torm=" .. (UI.Runes.Tormentor:Get() and "1" or "0") .. "\n") end
                    if UI.Runes.Roshan then f:write("ui_r_rosh=" .. (UI.Runes.Roshan:Get() and "1" or "0") .. "\n") end
                end
                if UI.Timings then
                    if UI.Timings.ToastDuration then f:write("ui_t_dur=" .. tostring(UI.Timings.ToastDuration:Get()) .. "\n") end
                    if UI.Timings.PowerRuneTime then f:write("ui_t_power=" .. tostring(UI.Timings.PowerRuneTime:Get()) .. "\n") end
                    if UI.Timings.WaterRuneTime then f:write("ui_t_water=" .. tostring(UI.Timings.WaterRuneTime:Get()) .. "\n") end
                    if UI.Timings.BountyRuneTime then f:write("ui_t_bounty=" .. tostring(UI.Timings.BountyRuneTime:Get()) .. "\n") end
                    if UI.Timings.WisdomRuneTime then f:write("ui_t_wisdom=" .. tostring(UI.Timings.WisdomRuneTime:Get()) .. "\n") end
                    if UI.Timings.LotusTime then f:write("ui_t_lotus=" .. tostring(UI.Timings.LotusTime:Get()) .. "\n") end
                    if UI.Timings.Tormentor1Time then f:write("ui_t_torm1=" .. tostring(UI.Timings.Tormentor1Time:Get()) .. "\n") end
                    if UI.Timings.Tormentor2Time then f:write("ui_t_torm2=" .. tostring(UI.Timings.Tormentor2Time:Get()) .. "\n") end
                end
                if UI.Media then
                    if UI.Media.Enabled then f:write("ui_m_enabled=" .. (UI.Media.Enabled:Get() and "1" or "0") .. "\n") end
                    if UI.Media.SpotifyLike then f:write("ui_m_like=" .. (UI.Media.SpotifyLike:Get() and "1" or "0") .. "\n") end
                    if UI.Media.MarqueeSpeed then f:write("ui_m_speed=" .. tostring(UI.Media.MarqueeSpeed:Get()) .. "\n") end
                    if UI.Media.SecondaryBubble then f:write("ui_m_bubble=" .. (UI.Media.SecondaryBubble:Get() and "1" or "0") .. "\n") end
                    if UI.Media.Shadow then f:write("ui_m_shadow=" .. (UI.Media.Shadow:Get() and "1" or "0") .. "\n") end
                    if UI.Media.Blur then f:write("ui_m_blur=" .. (UI.Media.Blur:Get() and "1" or "0") .. "\n") end
                    if UI.Media.Hints then f:write("ui_m_hints=" .. (UI.Media.Hints:Get() and "1" or "0") .. "\n") end
                    if UI.Media.AccentColor then
                        local c = UI.Media.AccentColor:Get()
                        f:write(string.format("ui_m_accent=%d,%d,%d,%d\n", math.floor(c.r), math.floor(c.g), math.floor(c.b), math.floor(c.a or 255)))
                    end
                end
                if UI.Haptics then
                    if UI.Haptics.Enabled then f:write("ui_h_enabled=" .. (UI.Haptics.Enabled:Get() and "1" or "0") .. "\n") end
                    if UI.Haptics.VisualFeedback then f:write("ui_h_visual=" .. (UI.Haptics.VisualFeedback:Get() and "1" or "0") .. "\n") end
                    if UI.Haptics.AudioFeedback then f:write("ui_h_audio=" .. (UI.Haptics.AudioFeedback:Get() and "1" or "0") .. "\n") end
                    if UI.Haptics.Volume then f:write("ui_h_vol=" .. tostring(UI.Haptics.Volume:Get()) .. "\n") end
                    if UI.Haptics.Intensity then f:write("ui_h_int=" .. tostring(UI.Haptics.Intensity:Get()) .. "\n") end
                    if UI.Haptics.CombatFilter then f:write("ui_h_combat=" .. (UI.Haptics.CombatFilter:Get() and "1" or "0") .. "\n") end
                    if UI.Haptics.AudioDucking then f:write("ui_h_duck=" .. (UI.Haptics.AudioDucking:Get() and "1" or "0") .. "\n") end
                    if UI.Haptics.DuckingAmount then f:write("ui_h_duck_amt=" .. tostring(UI.Haptics.DuckingAmount:Get()) .. "\n") end
                    if UI.Haptics.DuckingAlerts then f:write("ui_h_duck_alerts=" .. (UI.Haptics.DuckingAlerts:Get() and "1" or "0") .. "\n") end
                    if UI.Haptics.DuckingCourier then f:write("ui_h_duck_courier=" .. (UI.Haptics.DuckingCourier:Get() and "1" or "0") .. "\n") end
                    if UI.Haptics.DuckingNotifs then f:write("ui_h_duck_notifs=" .. (UI.Haptics.DuckingNotifs:Get() and "1" or "0") .. "\n") end
                    if UI.Haptics.DuckingMotion then f:write("ui_h_duck_motion=" .. (UI.Haptics.DuckingMotion:Get() and "1" or "0") .. "\n") end
                    if UI.Haptics.DuckingTaptics then f:write("ui_h_duck_taptics=" .. (UI.Haptics.DuckingTaptics:Get() and "1" or "0") .. "\n") end
                end
            end
            f:close()
        end
    end
end

local function LoadAllConfig()
    local paths = ConfigSavePaths
    local f = nil
    for _, path in ipairs(paths) do
        f = io.open(path, "r")
        if f then break end
    end
    if not f then return end
    
    for line in f:lines() do
        local activeMatch = string.match(line, "^active=([%w_,]+)")
        local dragMatchX, dragMatchY = string.match(line, "^drag_center=([%-]?%d+),([%-]?%d+)")
        if activeMatch then
            local newActive = {}
            for item in string.gmatch(activeMatch, "[%w_]+") do
                table.insert(newActive, item)
            end
            if #newActive > 0 then
                HUDCustomizer.ActiveChips = newActive
            end
        elseif dragMatchX and dragMatchY then
            DragState.CustomX = tonumber(dragMatchX) or -1
            DragState.CustomY = tonumber(dragMatchY) or -1
        else
            local id, boldStr, colStr, fmtStr, iconStr, hexStr = string.match(line, "^cfg_([%w_]+)=(%d),(%d),(%d),?(%d?),?([%w]*)")
            if id and HUDCustomizer.WidgetConfigs[id] then
                HUDCustomizer.WidgetConfigs[id].bold = (boldStr == "1")
                HUDCustomizer.WidgetConfigs[id].colorMode = tonumber(colStr) or 1
                HUDCustomizer.WidgetConfigs[id].format = tonumber(fmtStr) or 1
                if iconStr and iconStr ~= "" then
                    HUDCustomizer.WidgetConfigs[id].showIcon = (iconStr == "1")
                end
                if hexStr and #hexStr == 6 then
                    HUDCustomizer.WidgetConfigs[id].customHex = hexStr
                    HUDCustomizer.WidgetConfigs[id].customColor = HexToColor(hexStr)
                end
            elseif UI then
                local k, v = string.match(line, "^([%w_]+)=(.*)$")
                if k and v then
                    if k == "ui_enabled" and UI.Main and UI.Main.Enabled then UI.Main.Enabled:Set(v == "1")
                    elseif k == "ui_only_game" and UI.Main and UI.Main.OnlyInGame then UI.Main.OnlyInGame:Set(v == "1")
                    elseif k == "ui_preset" and UI.Main and UI.Main.Preset then UI.Main.Preset:Set(tonumber(v) or 0)
                    elseif k == "ui_offset_y" and UI.Main and UI.Main.OffsetY then UI.Main.OffsetY:Set(tonumber(v) or 20)
                    elseif k == "ui_offset_x" and UI.Main and UI.Main.OffsetX then UI.Main.OffsetX:Set(tonumber(v) or 0)
                    elseif k == "ui_scale" and UI.Main and UI.Main.Scale then UI.Main.Scale:Set(tonumber(v) or 100)
                    elseif k == "ui_label" and UI.Main and UI.Main.CustomLabel then UI.Main.CustomLabel:Set(v)
                    elseif k == "ui_pure_glass" and UI.Main and UI.Main.PureGlass then UI.Main.PureGlass:Set(v == "1")
                    elseif k == "ui_bg_col" and UI.Main and UI.Main.IslandBgColor then
                        local r, g, b, a = string.match(v, "^(%d+),(%d+),(%d+),(%d+)$")
                        if r then UI.Main.IslandBgColor:Set(Color(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0, tonumber(a) or 245)) end
                    elseif k == "ui_c_fighthud" and UI.Combat and UI.Combat.FightHUD then UI.Combat.FightHUD:Set(v == "1")
                    elseif k == "ui_c_fightscope" and UI.Combat and UI.Combat.FightScope then UI.Combat.FightScope:Set(tonumber(v) or 0)
                    elseif k == "ui_c_minheroes" and UI.Combat and UI.Combat.MinHeroes then UI.Combat.MinHeroes:Set(tonumber(v) or 2)
                    elseif k == "ui_c_fightradius" and UI.Combat and UI.Combat.FightRadius then UI.Combat.FightRadius:Set(tonumber(v) or 1600)
                    elseif k == "ui_c_radarzoom" and UI.Combat and UI.Combat.RadarZoom then UI.Combat.RadarZoom:Set(tonumber(v) or 2000)
                    elseif k == "ui_c_fighttimeout" and UI.Combat and UI.Combat.FightTimeout then UI.Combat.FightTimeout:Set(tonumber(v) or 4)
                    elseif k == "ui_r_active" and UI.Runes and UI.Runes.ActiveRunes then UI.Runes.ActiveRunes:Set(v == "1")
                    elseif k == "ui_r_water" and UI.Runes and UI.Runes.WaterRunes then UI.Runes.WaterRunes:Set(v == "1")
                    elseif k == "ui_r_bounty" and UI.Runes and UI.Runes.BountyRunes then UI.Runes.BountyRunes:Set(v == "1")
                    elseif k == "ui_r_wisdom" and UI.Runes and UI.Runes.WisdomRunes then UI.Runes.WisdomRunes:Set(v == "1")
                    elseif k == "ui_r_pick" and UI.Runes and UI.Runes.RunePickups then UI.Runes.RunePickups:Set(v == "1")
                    elseif k == "ui_r_world" and UI.Runes and UI.Runes.RuneWorldSpawn then UI.Runes.RuneWorldSpawn:Set(v == "1")
                    elseif k == "ui_r_lotus" and UI.Runes and UI.Runes.Lotus then UI.Runes.Lotus:Set(v == "1")
                    elseif k == "ui_r_torm" and UI.Runes and UI.Runes.Tormentor then UI.Runes.Tormentor:Set(v == "1")
                    elseif k == "ui_r_rosh" and UI.Runes and UI.Runes.Roshan then UI.Runes.Roshan:Set(v == "1")
                    elseif k == "ui_c_kills" and UI.Combat and UI.Combat.Kills then UI.Combat.Kills:Set(v == "1")
                    elseif k == "ui_c_invis" and UI.Combat and UI.Combat.Invis then UI.Combat.Invis:Set(v == "1")
                    elseif k == "ui_c_tp" and UI.Combat and UI.Combat.Teleports then UI.Combat.Teleports:Set(v == "1")
                    elseif k == "ui_c_items" and UI.Combat and UI.Combat.KeyEnemyItems then UI.Combat.KeyEnemyItems:Set(v == "1")
                    elseif k == "ui_c_courier" and UI.Combat and UI.Combat.Couriers then UI.Combat.Couriers:Set(v == "1")
                    elseif k == "ui_c_tower" and UI.Combat and UI.Combat.Towers then UI.Combat.Towers:Set(v == "1")
                    elseif k == "ui_c_bb" and UI.Combat and UI.Combat.Buybacks then UI.Combat.Buybacks:Set(v == "1")
                    elseif k == "ui_c_lowhp" and UI.Combat and UI.Combat.LowHP then UI.Combat.LowHP:Set(v == "1")
                    elseif k == "ui_c_lvl" and UI.Combat and UI.Combat.LevelUp then UI.Combat.LevelUp:Set(v == "1")
                    elseif k == "ui_t_dur" and UI.Timings and UI.Timings.ToastDuration then UI.Timings.ToastDuration:Set(tonumber(v) or 4)
                    elseif k == "ui_t_power" and UI.Timings and UI.Timings.PowerRuneTime then UI.Timings.PowerRuneTime:Set(tonumber(v) or 20)
                    elseif k == "ui_t_water" and UI.Timings and UI.Timings.WaterRuneTime then UI.Timings.WaterRuneTime:Set(tonumber(v) or 20)
                    elseif k == "ui_t_bounty" and UI.Timings and UI.Timings.BountyRuneTime then UI.Timings.BountyRuneTime:Set(tonumber(v) or 10)
                    elseif k == "ui_t_wisdom" and UI.Timings and UI.Timings.WisdomRuneTime then UI.Timings.WisdomRuneTime:Set(tonumber(v) or 20)
                    elseif k == "ui_t_lotus" and UI.Timings and UI.Timings.LotusTime then UI.Timings.LotusTime:Set(tonumber(v) or 20)
                    elseif k == "ui_t_torm1" and UI.Timings and UI.Timings.Tormentor1Time then UI.Timings.Tormentor1Time:Set(tonumber(v) or 120)
                    elseif k == "ui_t_torm2" and UI.Timings and UI.Timings.Tormentor2Time then UI.Timings.Tormentor2Time:Set(tonumber(v) or 20)
                    elseif k == "ui_m_enabled" and UI.Media and UI.Media.Enabled then UI.Media.Enabled:Set(v == "1")
                    elseif k == "ui_m_like" and UI.Media and UI.Media.SpotifyLike then UI.Media.SpotifyLike:Set(v == "1")
                    elseif k == "ui_m_speed" and UI.Media and UI.Media.MarqueeSpeed then UI.Media.MarqueeSpeed:Set(tonumber(v) or 45)
                    elseif k == "ui_m_bubble" and UI.Media and UI.Media.SecondaryBubble then UI.Media.SecondaryBubble:Set(v == "1")
                    elseif k == "ui_m_shadow" and UI.Media and UI.Media.Shadow then UI.Media.Shadow:Set(v == "1")
                    elseif k == "ui_m_blur" and UI.Media and UI.Media.Blur then UI.Media.Blur:Set(v == "1")
                    elseif k == "ui_m_hints" and UI.Media and UI.Media.Hints then UI.Media.Hints:Set(v == "1")
                    elseif k == "ui_m_accent" and UI.Media and UI.Media.AccentColor then
                        local r, g, b, a = string.match(v, "^(%d+),(%d+),(%d+),(%d+)$")
                        if r then UI.Media.AccentColor:Set(Color(tonumber(r) or 52, tonumber(g) or 199, tonumber(b) or 89, tonumber(a) or 255)) end
                    elseif k == "ui_h_enabled" and UI.Haptics and UI.Haptics.Enabled then UI.Haptics.Enabled:Set(v == "1")
                    elseif k == "ui_h_visual" and UI.Haptics and UI.Haptics.VisualFeedback then UI.Haptics.VisualFeedback:Set(v == "1")
                    elseif k == "ui_h_audio" and UI.Haptics and UI.Haptics.AudioFeedback then UI.Haptics.AudioFeedback:Set(v == "1")
                    elseif k == "ui_h_vol" and UI.Haptics and UI.Haptics.Volume then UI.Haptics.Volume:Set(tonumber(v) or 50)
                    elseif k == "ui_h_int" and UI.Haptics and UI.Haptics.Intensity then UI.Haptics.Intensity:Set(tonumber(v) or 100)
                    elseif k == "ui_h_combat" and UI.Haptics and UI.Haptics.CombatFilter then UI.Haptics.CombatFilter:Set(v == "1")
                    elseif k == "ui_h_duck" and UI.Haptics and UI.Haptics.AudioDucking then UI.Haptics.AudioDucking:Set(v == "1")
                    elseif k == "ui_h_duck_amt" and UI.Haptics and UI.Haptics.DuckingAmount then UI.Haptics.DuckingAmount:Set(tonumber(v) or 50)
                    elseif k == "ui_h_duck_alerts" and UI.Haptics and UI.Haptics.DuckingAlerts then UI.Haptics.DuckingAlerts:Set(v == "1")
                    elseif k == "ui_h_duck_courier" and UI.Haptics and UI.Haptics.DuckingCourier then UI.Haptics.DuckingCourier:Set(v == "1")
                    elseif k == "ui_h_duck_notifs" and UI.Haptics and UI.Haptics.DuckingNotifs then UI.Haptics.DuckingNotifs:Set(v == "1")
                    elseif k == "ui_h_duck_motion" and UI.Haptics and UI.Haptics.DuckingMotion then UI.Haptics.DuckingMotion:Set(v == "1")
                    elseif k == "ui_h_duck_taptics" and UI.Haptics and UI.Haptics.DuckingTaptics then UI.Haptics.DuckingTaptics:Set(v == "1")
                    end
                end
            end
        end
    end
    f:close()
end

local function GetPrimaryThemeColor()
    if Menu.Style then
        local ok, col = pcall(Menu.Style, "primary")
        if ok and col then return col end
    end
    return (UI and UI.Media and UI.Media.AccentColor) and UI.Media.AccentColor:Get() or Config.Colors.Accent
end

local function GetActualMatchTime()
    local gStartTime = GameRules.GetGameStartTime and GameRules.GetGameStartTime() or 0
    local curGameTime = GameRules.GetGameTime and GameRules.GetGameTime() or 0
    if gStartTime > 0 then
        return curGameTime - gStartTime
    end
    if GameRules.GetDOTATime then
        local ok, dt = pcall(GameRules.GetDOTATime, false, true)
        if ok and dt then return dt end
    end
    return curGameTime
end

local function GetVectorIcon(name)
    if not name or not VectorIcons[name] then return nil end
    local cacheKey = "svg_apple_v35_" .. name
    local h = ImageCache[cacheKey]
    if h ~= nil then return h or nil end
    local ok, handle = pcall(Render.LoadSvgString, VectorIcons[name], Vec2(48, 48), "vec_sym_apple_v35_" .. name)
    if ok and handle and handle ~= 0 then
        ImageCache[cacheKey] = handle
        return handle
    end
    ImageCache[cacheKey] = false
    return nil
end

local function GetCachedImage(path, fallbackSvgKey)
    if path and path ~= "" then
        local h = ImageCache[path]
        if h ~= nil and h ~= false then return h end
        if h == nil then
            local ok, handle = pcall(Render.LoadImage, path)
            if ok and handle and handle ~= 0 then
                ImageCache[path] = handle
                return handle
            end
            ImageCache[path] = false
        end
    end
    if fallbackSvgKey then
        return GetVectorIcon(fallbackSvgKey)
    end
    return nil
end

local function LoadScriptFonts()
    Config.Fonts.Main = Render.LoadFont("SF Pro Display", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400)
    Config.Fonts.Bold = Render.LoadFont("SF Pro Display", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700)
end

local Haptic = {
    Types = {
        TAP_LIGHT = 1,
        TAP_MEDIUM = 2,
        SNAP_EXPAND = 3,
        SNAP_COLLAPSE = 4,
        RATCHET_NOTCH = 5,
        BOUNDARY_BUMP = 6,
        SUCCESS_APPLE_PAY = 7,
        HEARTBEAT = 8,
        STUN_DISRUPT = 9
    },
    State = {
        OffsetX = 0.0,
        OffsetY = 0.0,
        VelX = 0.0,
        VelY = 0.0,
        ScaleX = 1.0,
        ScaleY = 1.0,
        VelScaleX = 0.0,
        VelScaleY = 0.0,
        GlowAlpha = 0.0,
        VelGlow = 0.0,
        GlowColor = Color(255, 255, 255, 0),
        LastHeartbeatTime = 0.0,
        LastLowHPAlertTime = 0.0,
        WasLowHP = false,
        WasStunned = false,
        LastHoverState = false
    },
    Throttle = {
        LastTimes = {},
        MinIntervals = {
            [1] = 0.05,
            [2] = 0.08,
            [3] = 0.15,
            [4] = 0.15,
            [5] = 0.035,
            [6] = 0.12,
            [7] = 0.30,
            [8] = 0.25,
            [9] = 0.40
        }
    },
    Pattern = {
        Active = false,
        Type = 0,
        StartTime = 0.0,
        Step = 0
    }
}

local function HapticPlaySound(appleSoundName, arg2, arg3)
    if not (UI and UI.Haptics and UI.Haptics.AudioFeedback and UI.Haptics.AudioFeedback:Get()) then
        return
    end
    local baseVol = (type(arg2) == "number" and arg2) or (type(arg3) == "number" and arg3) or 0.5
    local userVol = (UI and UI.Haptics and UI.Haptics.Volume) and (UI.Haptics.Volume:Get() / 100.0) or 0.5
    local finalVol = math.max(0.01, math.min(1.0, baseVol * userVol))

    if appleSoundName and appleSoundName ~= "" then
        if HTTP and HTTP.Request then
            local forceParam = (appleSoundName == "match_found") and "&force=1" or ""
            local duckParam = ""
            if UI and UI.Haptics and UI.Haptics.AudioDucking and UI.Haptics.AudioDucking:Get() then
                local shouldDuck = false
                local weight = 0.5
                if appleSoundName == "wheel_notch" or appleSoundName == "wheel_boundary_bump" or appleSoundName == "toast_dismiss" or appleSoundName == "button_dismiss" then
                    shouldDuck = false
                    weight = 0.0
                elseif appleSoundName == "match_found" or appleSoundName == "hero_stunned" or appleSoundName == "low_hp_heartbeat" or appleSoundName == "courier_death_or_fail" then
                    shouldDuck = (not UI.Haptics.DuckingAlerts) or UI.Haptics.DuckingAlerts:Get()
                    weight = 1.0
                elseif appleSoundName == "courier_delivered" then
                    shouldDuck = (not UI.Haptics.DuckingCourier) or UI.Haptics.DuckingCourier:Get()
                    weight = 0.7
                elseif appleSoundName == "notification_toast" or appleSoundName == "game_paused" or appleSoundName == "game_unpaused" or appleSoundName == "timer_chime" then
                    shouldDuck = (not UI.Haptics.DuckingNotifs) or UI.Haptics.DuckingNotifs:Get()
                    weight = (appleSoundName == "timer_chime") and 0.4 or 0.7
                elseif appleSoundName == "island_expand" or appleSoundName == "island_collapse" or appleSoundName == "island_hover" then
                    shouldDuck = UI.Haptics.DuckingMotion and UI.Haptics.DuckingMotion:Get()
                    weight = 0.4
                else
                    shouldDuck = UI.Haptics.DuckingTaptics and UI.Haptics.DuckingTaptics:Get()
                    weight = 0.4
                end

                if shouldDuck then
                    local baseDuckPct = (UI.Haptics.DuckingAmount and UI.Haptics.DuckingAmount:Get() or 50) / 100.0
                    local effDuckPct = math.min(1.0, math.max(0.0, baseDuckPct * weight))
                    if effDuckPct > 0.01 then
                        duckParam = "&duck=" .. string.format("%.2f", effDuckPct)
                    end
                end
            end
            pcall(HTTP.Request, "GET", "http://127.0.0.1:45455/sound?name=" .. appleSoundName .. "&vol=" .. string.format("%.2f", finalVol) .. forceParam .. duckParam, {}, function() end)
        end
    end
end

function Haptic.Trigger(hType, p1, p2)
    local isEnabled = true
    if UI and UI.Haptics and UI.Haptics.Enabled then
        isEnabled = UI.Haptics.Enabled:Get()
    end
    if not isEnabled then return end

    local nowClk = os.clock()
    local minInt = Haptic.Throttle.MinIntervals[hType] or 0.05
    local lastT = Haptic.Throttle.LastTimes[hType] or 0
    if (nowClk - lastT) < minInt then return end
    Haptic.Throttle.LastTimes[hType] = nowClk

    local inCombat = FightTracker and FightTracker.InCombat or false
    local combatFilter = (UI and UI.Haptics and UI.Haptics.CombatFilter) and UI.Haptics.CombatFilter:Get() or true
    if inCombat and combatFilter and (hType == Haptic.Types.TAP_LIGHT) then
        return
    end

    local intensity = (UI and UI.Haptics and UI.Haptics.Intensity) and (UI.Haptics.Intensity:Get() / 100.0) or 1.0
    local visualOn = (UI and UI.Haptics and UI.Haptics.VisualFeedback) and UI.Haptics.VisualFeedback:Get() or true

    if hType == Haptic.Types.TAP_LIGHT then
        if visualOn then
            Haptic.State.VelScaleY = Haptic.State.VelScaleY - 0.35 * intensity
            Haptic.State.VelScaleX = Haptic.State.VelScaleX + 0.18 * intensity
        end
    elseif hType == Haptic.Types.TAP_MEDIUM then
        if visualOn then
            Haptic.State.VelScaleY = Haptic.State.VelScaleY - 0.75 * intensity
            Haptic.State.VelScaleX = Haptic.State.VelScaleX + 0.35 * intensity
            Haptic.State.GlowAlpha = 35 * intensity
            Haptic.State.GlowColor = Color(255, 255, 255, 255)
        end
        HapticPlaySound("button_press", 0.35)
    elseif hType == Haptic.Types.SNAP_EXPAND then
        if visualOn then
            Haptic.State.VelScaleY = Haptic.State.VelScaleY + 0.28 * intensity
            Haptic.State.VelScaleX = Haptic.State.VelScaleX + 0.18 * intensity
            Haptic.State.GlowAlpha = 45 * intensity
            Haptic.State.GlowColor = GetPrimaryThemeColor()
        end
        HapticPlaySound("island_expand", 0.40)
    elseif hType == Haptic.Types.SNAP_COLLAPSE then
        if visualOn then
            Haptic.State.VelScaleY = Haptic.State.VelScaleY - 0.22 * intensity
            Haptic.State.VelScaleX = Haptic.State.VelScaleX - 0.14 * intensity
        end
        HapticPlaySound("island_collapse", 0.30)
    elseif hType == Haptic.Types.RATCHET_NOTCH then
        if visualOn then
            Haptic.State.VelScaleX = Haptic.State.VelScaleX + 0.06 * intensity
            Haptic.State.VelScaleY = Haptic.State.VelScaleY - 0.04 * intensity
            Haptic.State.GlowAlpha = 18 * intensity
            Haptic.State.GlowColor = Color(255, 255, 255, 180)
        end
    elseif hType == Haptic.Types.BOUNDARY_BUMP then
        if visualOn then
            Haptic.State.VelScaleX = Haptic.State.VelScaleX - 0.12 * intensity
            Haptic.State.VelScaleY = Haptic.State.VelScaleY + 0.08 * intensity
            Haptic.State.GlowAlpha = 40 * intensity
            Haptic.State.GlowColor = Color(255, 59, 48, 240)
        end
    elseif hType == Haptic.Types.SUCCESS_APPLE_PAY then
        if visualOn then
            Haptic.State.VelScaleX = Haptic.State.VelScaleX + 1.4 * intensity
            Haptic.State.VelScaleY = Haptic.State.VelScaleY + 1.4 * intensity
            Haptic.State.GlowAlpha = 140 * intensity
            Haptic.State.GlowColor = Color(52, 199, 89, 255)
        end
        HapticPlaySound("courier_delivered", 0.65)
        Haptic.Pattern.Active = true
        Haptic.Pattern.Type = Haptic.Types.SUCCESS_APPLE_PAY
        Haptic.Pattern.StartTime = nowClk
        Haptic.Pattern.Step = 1
    elseif hType == Haptic.Types.HEARTBEAT then
        if visualOn then
            Haptic.State.VelScaleY = Haptic.State.VelScaleY + 0.65 * intensity
            Haptic.State.VelScaleX = Haptic.State.VelScaleX + 0.45 * intensity
            Haptic.State.GlowAlpha = 80 * intensity
            Haptic.State.GlowColor = Color(255, 45, 85, 255)
        end
        if p1 then
            HapticPlaySound("low_hp_heartbeat", 0.35)
        end
        Haptic.Pattern.Active = true
        Haptic.Pattern.Type = Haptic.Types.HEARTBEAT
        Haptic.Pattern.StartTime = nowClk
        Haptic.Pattern.Step = 1
    elseif hType == Haptic.Types.STUN_DISRUPT then
        if visualOn then
            Haptic.State.VelX = Haptic.State.VelX + 35.0 * intensity
            Haptic.State.GlowAlpha = 95 * intensity
            Haptic.State.GlowColor = Color(255, 204, 0, 255)
        end
        HapticPlaySound("hero_stunned", 0.45)
    end
end

function Haptic.Update(dt)
    local isEnabled = true
    if UI and UI.Haptics and UI.Haptics.Enabled then
        isEnabled = UI.Haptics.Enabled:Get()
    end
    if not isEnabled then
        Haptic.State.OffsetX = 0
        Haptic.State.OffsetY = 0
        Haptic.State.ScaleX = 1.0
        Haptic.State.ScaleY = 1.0
        Haptic.State.GlowAlpha = 0
        return
    end

    local nowClk = os.clock()
    local clampedDt = math.max(0.001, math.min(0.05, dt or 0.016))

    local nx, nvx = SolveDampedSpring(Haptic.State.OffsetX, Haptic.State.VelX, 0.0, clampedDt, 38.0, 0.68)
    Haptic.State.OffsetX = nx
    Haptic.State.VelX = nvx

    local ny, nvy = SolveDampedSpring(Haptic.State.OffsetY, Haptic.State.VelY, 0.0, clampedDt, 38.0, 0.68)
    Haptic.State.OffsetY = ny
    Haptic.State.VelY = nvy

    local nsx, nvsx = SolveDampedSpring(Haptic.State.ScaleX, Haptic.State.VelScaleX, 1.0, clampedDt, 34.0, 0.70)
    Haptic.State.ScaleX = nsx
    Haptic.State.VelScaleX = nvsx

    local nsy, nvsy = SolveDampedSpring(Haptic.State.ScaleY, Haptic.State.VelScaleY, 1.0, clampedDt, 34.0, 0.70)
    Haptic.State.ScaleY = nsy
    Haptic.State.VelScaleY = nvsy

    local nga, nvga = SolveDampedSpring(Haptic.State.GlowAlpha, Haptic.State.VelGlow, 0.0, clampedDt, 26.0, 0.75)
    Haptic.State.GlowAlpha = math.max(0.0, nga)
    Haptic.State.VelGlow = nvga

    if Haptic.Pattern.Active then
        local elapsed = nowClk - Haptic.Pattern.StartTime
        if Haptic.Pattern.Type == Haptic.Types.SUCCESS_APPLE_PAY then
            if Haptic.Pattern.Step == 1 and elapsed >= 0.09 then
                Haptic.Pattern.Step = 2
                Haptic.State.VelScaleX = Haptic.State.VelScaleX + 0.6
                Haptic.State.VelScaleY = Haptic.State.VelScaleY + 0.6
                Haptic.State.GlowAlpha = math.max(Haptic.State.GlowAlpha, 90.0)
            elseif elapsed >= 0.35 then
                Haptic.Pattern.Active = false
            end
        elseif Haptic.Pattern.Type == Haptic.Types.HEARTBEAT then
            if Haptic.Pattern.Step == 1 and elapsed >= 0.12 then
                Haptic.Pattern.Step = 2
                Haptic.State.VelScaleY = Haptic.State.VelScaleY + 0.4
                Haptic.State.GlowAlpha = math.max(Haptic.State.GlowAlpha, 50.0)
            elseif elapsed >= 0.30 then
                Haptic.Pattern.Active = false
            end
        else
            if elapsed >= 0.5 then
                Haptic.Pattern.Active = false
            end
        end
    end

    local inGame = Engine.IsInGame and Engine.IsInGame()
    local myHero = HeroData.Local or (Heroes and Heroes.GetLocal and Heroes.GetLocal())
    if inGame and myHero and Entity.IsAlive(myHero) then
        local hp = Entity.GetHealth(myHero) or 0
        local maxHp = Entity.GetMaxHealth(myHero) or 1
        local hpPct = hp / math.max(1, maxHp)

        if hpPct > 0 and hpPct <= 0.32 then
            local period = 0.8 + hpPct * 1.5
            local shouldPlaySound = false
            if not Haptic.State.WasLowHP or (nowClk - Haptic.State.LastLowHPAlertTime >= 25.0) then
                shouldPlaySound = true
                Haptic.State.LastLowHPAlertTime = nowClk
            end
            Haptic.State.WasLowHP = true
            if (nowClk - Haptic.State.LastHeartbeatTime) >= period then
                Haptic.State.LastHeartbeatTime = nowClk
                Haptic.Trigger(Haptic.Types.HEARTBEAT, shouldPlaySound)
            end
        else
            Haptic.State.WasLowHP = false
        end

        local isStunned = NPC.IsStunned and NPC.IsStunned(myHero) or false
        local isSilenced = NPC.IsSilenced and NPC.IsSilenced(myHero) or false
        local isCurrentlyDisabled = isStunned or isSilenced
        if isCurrentlyDisabled and not Haptic.State.WasStunned then
            Haptic.Trigger(Haptic.Types.STUN_DISRUPT)
        end
        Haptic.State.WasStunned = isCurrentlyDisabled
    else
        Haptic.State.WasLowHP = false
        Haptic.State.WasStunned = false
    end
end

function Haptic.ApplyTransform(layout)
    if not layout or layout.w <= 0 or layout.h <= 0 then return end
    local isEnabled = true
    if UI and UI.Haptics and UI.Haptics.Enabled then
        isEnabled = UI.Haptics.Enabled:Get()
    end
    if not isEnabled then return end

    local visualOn = (UI and UI.Haptics and UI.Haptics.VisualFeedback) and UI.Haptics.VisualFeedback:Get() or true
    if not visualOn then return end

    if math.abs(Haptic.State.ScaleX - 1.0) < 0.004 and math.abs(Haptic.State.VelScaleX or 0.0) < 0.02 then
        Haptic.State.ScaleX = 1.0
        Haptic.State.VelScaleX = 0.0
    end
    if math.abs(Haptic.State.ScaleY - 1.0) < 0.004 and math.abs(Haptic.State.VelScaleY or 0.0) < 0.02 then
        Haptic.State.ScaleY = 1.0
        Haptic.State.VelScaleY = 0.0
    end
    if math.abs(Haptic.State.OffsetX) < 0.25 and math.abs(Haptic.State.VelX or 0.0) < 0.5 then
        Haptic.State.OffsetX = 0.0
        Haptic.State.VelX = 0.0
    end
    if math.abs(Haptic.State.OffsetY) < 0.25 and math.abs(Haptic.State.VelY or 0.0) < 0.5 then
        Haptic.State.OffsetY = 0.0
        Haptic.State.VelY = 0.0
    end

    if Haptic.State.ScaleX == 1.0 and Haptic.State.ScaleY == 1.0 and Haptic.State.OffsetX == 0.0 and Haptic.State.OffsetY == 0.0 then
        return
    end

    local origW = layout.w
    local origH = layout.h
    local scaleX = math.max(0.80, math.min(1.25, Haptic.State.ScaleX))
    local scaleY = math.max(0.80, math.min(1.25, Haptic.State.ScaleY))

    local halfW = math.floor((origW * scaleX) * 0.5 + 0.5)
    local halfH = math.floor((origH * scaleY) * 0.5 + 0.5)
    local newW = halfW * 2
    local newH = halfH * 2
    local diffW = math.floor((newW - origW) * 0.5)
    local diffH = math.floor((newH - origH) * 0.5)

    layout.x = math.floor(layout.x + Haptic.State.OffsetX - diffW)
    layout.y = math.floor(layout.y + Haptic.State.OffsetY - diffH)
    layout.w = newW
    layout.h = newH
end

local function InitMenu()
    local tab = Menu.Create("General", "Dynamic Island", "dynamic_island_apple")
    tab:Icon("\u{f0eb}")
    
    local gMain = tab:Create(L("tab.general", "General")):Create("tab.settings")
    local gCombat = tab:Create(L("tab.combat", "Combat & Map")):Create("tab.alerts")
    local gRunes = tab:Create(L("tab.runes", "Runes & Objectives")):Create("tab.events")
    local gTimings = tab:Create(L("tab.timings", "Timings")):Create("tab.seconds")
    local gMedia = tab:Create(L("tab.media", "Media & Visuals")):Create("tab.parameters")
    local gHaptics = tab:Create(L("tab.haptics", "Haptic Engine")):Create("tab.tactile")
    
    UI = {
        Main = {
            Enabled = gMain:Switch("main.enabled", true, "\u{f0eb}"),
            OnlyInGame = gMain:Switch("main.only_in_game", false, "\u{f108}"),
            Preset = gMain:Combo("main.preset", { "preset.top_center", "preset.custom", "preset.top_left", "preset.top_right", "preset.screen_center", "preset.bottom_center" }, 0),
            OffsetY = gMain:Slider("main.offset_y", 0, 1000, 20, "%d px"),
            OffsetX = gMain:Slider("main.offset_x", -960, 960, 0, "%d px"),
            Scale = gMain:Slider("main.scale", 60, 180, 100, "%d%%"),
            CustomLabel = gMain:Input("main.custom_label", ""),
            IslandBgColor = gMain:ColorPicker("main.bg_color", Color(0, 0, 0, 245)),
            PureGlass = gMain:Switch("main.pure_glass", false, "\u{f06e}"),
            ToggleHUDMode = gMain:Button("main.widget_editor", function()
                HUDCustomizer.IsOpen = not HUDCustomizer.IsOpen
                HUDCustomizer.InspectedChip = nil
            end),
            ResetPos = gMain:Button("main.reset_pos", function()
                DragState.CustomX = -1
                DragState.CustomY = -1
                UI.Main.Preset:Set(0)
                UI.Main.OffsetY:Set(20)
                UI.Main.OffsetX:Set(0)
                SaveAllConfig()
            end),
        },
        Combat = {
            FightHUD = gCombat:Switch("combat.fight_hud", true, "\u{f06e}"),
            FightScope = gCombat:Combo("combat.fight_scope", { "combat.scope_local", "combat.scope_any" }, 0),
            MinHeroes = gCombat:Slider("combat.min_heroes", 1, 10, 2, "%d"),
            FightRadius = gCombat:Slider("combat.fight_radius", 1000, 3000, 1600, "%d px"),
            RadarZoom = gCombat:Slider("combat.radar_zoom", 1000, 3500, 2000, "%d px"),
            FightTimeout = gCombat:Slider("combat.fight_timeout", 2, 10, 4, "%d s"),
            Kills = gCombat:Switch("combat.kills", true, "\u{f0e7}"),
            Invis = gCombat:Switch("combat.invis", true, "\u{f06e}"),
            Teleports = gCombat:Switch("combat.teleports", true, "\u{f3c5}"),
            KeyEnemyItems = gCombat:Switch("combat.key_enemy_items", true, "\u{f06e}"),
            Couriers = gCombat:Switch("combat.couriers", true, "\u{f48b}"),
            CourierDelivery = gCombat:Switch("combat.courier_delivery", true, "\u{f48b}"),
            PauseAlert = gCombat:Switch("combat.pause_alert", true, "\u{f04c}"),
            Towers = gCombat:Switch("combat.towers", true, "\u{f1ad}"),
            Buybacks = gCombat:Switch("combat.buybacks", true, "\u{f2f9}"),
            LowHP = gCombat:Switch("combat.low_hp", true, "\u{f21e}"),
            LevelUp = gCombat:Switch("combat.level_up", true, "\u{f201}")
        },
        Runes = {
            ActiveRunes = gRunes:Switch("runes.active_runes", true, "\u{f0e7}"),
            WaterRunes = gRunes:Switch("runes.water_runes", true, "\u{f043}"),
            BountyRunes = gRunes:Switch("runes.bounty_runes", true, "\u{f155}"),
            WisdomRunes = gRunes:Switch("runes.wisdom_runes", true, "\u{f19d}"),
            RunePickups = gRunes:Switch("runes.rune_pickups", true, "\u{f21b}"),
            RuneWorldSpawn = gRunes:Switch("runes.rune_world_spawn", true, "\u{f279}"),
            Lotus = gRunes:Switch("runes.lotus", true, "\u{f06c}"),
            Tormentor = gRunes:Switch("runes.tormentor", true, "\u{f005}"),
            Roshan = gRunes:Switch("runes.roshan", true, "\u{f6e3}")
        },
        Timings = {
            ToastDuration = gTimings:Slider("timings.toast_duration", 2, 8, 4, "%d s"),
            PowerRuneTime = gTimings:Slider("timings.power_rune_time", 5, 60, 20, "%d s"),
            WaterRuneTime = gTimings:Slider("timings.water_rune_time", 5, 60, 20, "%d s"),
            BountyRuneTime = gTimings:Slider("timings.bounty_rune_time", 5, 45, 10, "%d s"),
            WisdomRuneTime = gTimings:Slider("timings.wisdom_rune_time", 5, 60, 20, "%d s"),
            LotusTime = gTimings:Slider("timings.lotus_time", 5, 60, 20, "%d s"),
            Tormentor1Time = gTimings:Slider("timings.tormentor1_time", 30, 180, 120, "%d s"),
            Tormentor2Time = gTimings:Slider("timings.tormentor2_time", 5, 60, 20, "%d s")
        },
        Media = {
            Enabled = gMedia:Switch("media.enabled", true, "\u{f001}"),
            SpotifyLike = gMedia:Switch("media.spotify_like", true, "\u{f004}"),
            VolumeWheel = gMedia:Switch("media.volume_wheel", true, "\u{f028}"),
            MarqueeSpeed = gMedia:Slider("media.marquee_speed", 20, 100, 45, "%d px/s"),
            SecondaryBubble = gMedia:Switch("media.secondary_bubble", true, "\u{f111}"),
            Shadow = gMedia:Switch("media.shadow", true, "\u{f186}"),
            Blur = gMedia:Switch("media.blur", true, "\u{f06e}"),
            Hints = gMedia:Switch("media.hints", true, "\u{f05a}"),
            AccentColor = gMedia:ColorPicker("media.accent_color", Config.Colors.Accent),
            ExportCfg = gMedia:Button("media.export_cfg", function()
                SaveAllConfig()
            end),
            ImportCfg = gMedia:Button("media.import_cfg", function()
                LoadAllConfig()
            end)
        },
        Haptics = {
            Enabled = gHaptics:Switch("haptics.enabled", true, "\u{f11e}"),
            VisualFeedback = gHaptics:Switch("haptics.visual", true, "\u{f06e}"),
            AudioFeedback = gHaptics:Switch("haptics.audio", true, "\u{f028}"),
            Volume = gHaptics:Slider("haptics.volume", 0, 100, 50, "%d%%"),
            Intensity = gHaptics:Slider("haptics.intensity", 50, 150, 100, "%d%%"),
            CombatFilter = gHaptics:Switch("haptics.combat_filter", true, "\u{f0e7}"),
            AudioDucking = gHaptics:Switch("haptics.audio_ducking", true, "\u{f026}"),
            DuckingAmount = gHaptics:Slider("haptics.ducking_amount", 0, 100, 50, "%d%%"),
            DuckingAlerts = gHaptics:Switch("haptics.ducking_alerts", true, "\u{f0f3}"),
            DuckingCourier = gHaptics:Switch("haptics.ducking_courier", true, "\u{f48b}"),
            DuckingNotifs = gHaptics:Switch("haptics.ducking_notifs", true, "\u{f05a}"),
            DuckingMotion = gHaptics:Switch("haptics.ducking_motion", false, "\u{f065}"),
            DuckingTaptics = gHaptics:Switch("haptics.ducking_taptics", false, "\u{f0a7}"),
            TestDucking = gHaptics:Button("haptics.test_ducking", function()
                if HTTP and HTTP.Request then
                    local userVol = (UI and UI.Haptics and UI.Haptics.Volume) and (UI.Haptics.Volume:Get() / 100.0) or 0.5
                    local baseDuckPct = (UI and UI.Haptics and UI.Haptics.DuckingAmount and UI.Haptics.DuckingAmount:Get() or 50) / 100.0
                    local finalDuck = string.format("%.2f", baseDuckPct)
                    pcall(HTTP.Request, "GET", "http://127.0.0.1:45455/sound?name=courier_delivered&vol=" .. string.format("%.2f", userVol) .. "&force=1&duck=" .. finalDuck, {}, function() end)
                end
            end)
        }
    }
end

local function TriggerStateTransition(nextState)
    if StateMachine.TargetState == nextState then return end
    
    local fromLarge = (StateMachine.TargetState == StateMachine.States.LARGE_IDLE or StateMachine.TargetState == StateMachine.States.LARGE_MEDIA or StateMachine.TargetState == StateMachine.States.LARGE_FIGHT or StateMachine.TargetState == StateMachine.States.COURIER_LARGE)
    local toLarge = (nextState == StateMachine.States.LARGE_IDLE or nextState == StateMachine.States.LARGE_MEDIA or nextState == StateMachine.States.LARGE_FIGHT or nextState == StateMachine.States.COURIER_LARGE)

    StateMachine.PreviousState = StateMachine.TargetState
    StateMachine.TargetState = nextState
    StateMachine.StateStartTime = os.clock()
    
    StateMachine.Transition.Active = true
    StateMachine.Transition.FromState = StateMachine.PreviousState
    StateMachine.Transition.ToState = nextState
    StateMachine.Transition.StartTime = os.clock()
    StateMachine.Transition.Progress = 0.0
    
    if toLarge and not fromLarge then
        MotionEngine.CurrentProfile = "EXPAND"
        StateMachine.Spring.Squish.value = 0.3
        StateMachine.Spring.Squish.vel = 1.8
        if Haptic and Haptic.Trigger then
            Haptic.Trigger(Haptic.Types.SNAP_EXPAND)
        end
    elseif fromLarge and not toLarge then
        MotionEngine.CurrentProfile = "COLLAPSE"
        StateMachine.Spring.Squish.value = -0.2
        StateMachine.Spring.Squish.vel = -1.2
        if Haptic and Haptic.Trigger then
            Haptic.Trigger(Haptic.Types.SNAP_COLLAPSE)
        end
    elseif nextState == StateMachine.States.NOTIFICATION then
        MotionEngine.CurrentProfile = "POP"
        StateMachine.Spring.Squish.value = 0.2
        StateMachine.Spring.Squish.vel = 1.2
        if Haptic and Haptic.Trigger then
            Haptic.Trigger(Haptic.Types.TAP_MEDIUM)
        end
    else
        MotionEngine.CurrentProfile = "SUBTLE"
        StateMachine.Spring.Squish.value = 0.0
        StateMachine.Spring.Squish.vel = 0.0
        if Haptic and Haptic.Trigger then
            Haptic.Trigger(Haptic.Types.TAP_LIGHT)
        end
    end
    
    if nextState == StateMachine.States.GAME_PAUSED then
        HapticPlaySound("game_paused", 0.45)
    elseif StateMachine.PreviousState == StateMachine.States.GAME_PAUSED then
        HapticPlaySound("game_unpaused", 0.45)
    elseif nextState == StateMachine.States.MENU_MATCH_FOUND then
        HapticPlaySound("match_found", 0.60)
    end
end

local CleanHeroNameCache = {}
local function CleanHeroName(raw)
    if not raw or raw == "" then return L("Вражеский герой", "Enemy Hero") end
    if CleanHeroNameCache[raw] then return CleanHeroNameCache[raw] end
    if Engine.GetDisplayNameByUnitName then
        local ok, dn = pcall(Engine.GetDisplayNameByUnitName, raw)
        if ok and dn and dn ~= "" then
            CleanHeroNameCache[raw] = dn
            return dn
        end
    end
    local name = raw
    local prefix = "npc_dota_hero_"
    local pos = string.find(name, prefix, 1, true)
    if pos then
        name = string.sub(name, pos + string.len(prefix))
    end
    local res = {}
    for part in string.gmatch(name, "[^_]+") do
        local cap = string.upper(string.sub(part, 1, 1)) .. string.sub(part, 2)
        table.insert(res, cap)
    end
    local formatted = table.concat(res, " ")
    if formatted == "Nevermore" then formatted = "Shadow Fiend"
    elseif formatted == "Zuus" then formatted = "Zeus"
    elseif formatted == "Windrunner" then formatted = "Windranger"
    elseif formatted == "Rattletrap" then formatted = "Clockwerk"
    elseif formatted == "Shredder" then formatted = "Timbersaw"
    elseif formatted == "Skeleton King" then formatted = "Wraith King"
    elseif formatted == "Wisp" then formatted = "Io"
    elseif formatted == "Furion" then formatted = "Nature's Prophet"
    elseif formatted == "Obsidian Destroyer" then formatted = "Outworld Destroyer"
    elseif formatted == "Doom Bringer" then formatted = "Doom"
    elseif formatted == "Treant" then formatted = "Treant Protector"
    elseif formatted == "Magnataur" then formatted = "Magnus"
    elseif formatted == "Abyssal Underlord" then formatted = "Underlord"
    elseif formatted == "Vengefulspirit" then formatted = "Vengeful Spirit"
    end
    CleanHeroNameCache[raw] = formatted
    return formatted
end

local function GetPlayerDisplayName(ent)
    if not ent then return L("Вражеский герой", "Enemy Hero") end
    if Entity.IsHero and Entity.IsHero(ent) then
        local allPlayers = Players.GetAll()
        for _, pl in ipairs(allPlayers) do
            local td = Player.GetTeamData(pl)
            local rawUnit = NPC.GetUnitName(ent)
            if td and td.selected_hero_id and rawUnit then
                local pName = Player.GetName(pl)
                if pName and pName ~= "" then
                    return pName
                end
            end
        end
    end
    return CleanHeroName(NPC.GetUnitName(ent))
end

local TowerNameMap = {
    ["goodguys_tower1_mid"] = { ru = "Мид Т1 Света", en = "Radiant Mid T1" },
    ["goodguys_tower2_mid"] = { ru = "Мид Т2 Света", en = "Radiant Mid T2" },
    ["goodguys_tower3_mid"] = { ru = "Мид Т3 Света", en = "Radiant Mid T3" },
    ["goodguys_tower1_top"] = { ru = "Топ Т1 Света", en = "Radiant Top T1" },
    ["goodguys_tower2_top"] = { ru = "Топ Т2 Света", en = "Radiant Top T2" },
    ["goodguys_tower3_top"] = { ru = "Топ Т3 Света", en = "Radiant Top T3" },
    ["goodguys_tower1_bot"] = { ru = "Бот Т1 Света", en = "Radiant Bot T1" },
    ["goodguys_tower2_bot"] = { ru = "Бот Т2 Света", en = "Radiant Bot T2" },
    ["goodguys_tower3_bot"] = { ru = "Бот Т3 Света", en = "Radiant Bot T3" },
    ["badguys_tower1_mid"] = { ru = "Мид Т1 Тьмы", en = "Dire Mid T1" },
    ["badguys_tower2_mid"] = { ru = "Мид Т2 Тьмы", en = "Dire Mid T2" },
    ["badguys_tower3_mid"] = { ru = "Мид Т3 Тьмы", en = "Dire Mid T3" },
    ["badguys_tower1_top"] = { ru = "Топ Т1 Тьмы", en = "Dire Top T1" },
    ["badguys_tower2_top"] = { ru = "Топ Т2 Тьмы", en = "Dire Top T2" },
    ["badguys_tower3_top"] = { ru = "Топ Т3 Тьмы", en = "Dire Top T3" },
    ["badguys_tower1_bot"] = { ru = "Бот Т1 Тьмы", en = "Dire Bot T1" },
    ["badguys_tower2_bot"] = { ru = "Бот Т2 Тьмы", en = "Dire Bot T2" },
    ["badguys_tower3_bot"] = { ru = "Бот Т3 Тьмы", en = "Dire Bot T3" }
}

local function GetClosestLandmark(pos)
    if not pos then return L("Линия", "Lane") end
    
    if Towers and Towers.GetAll then
        local allTowers = Towers.GetAll()
        local bestTowerName = nil
        local bestTowerDist = 1600 * 1600
        for _, tw in ipairs(allTowers) do
            if tw and Entity.IsAlive(tw) then
                local tPos = Entity.GetAbsOrigin(tw)
                local dx = pos.x - tPos.x
                local dy = pos.y - tPos.y
                local d = dx * dx + dy * dy
                if d < bestTowerDist then
                    local rawName = NPC.GetUnitName(tw) or ""
                    for key, entry in pairs(TowerNameMap) do
                        if string.find(rawName, key) then
                            bestTowerDist = d
                            bestTowerName = L(entry.ru, entry.en)
                            break
                        end
                    end
                end
            end
        end
        if bestTowerName then return bestTowerName end
    end
    
    local closestName = L("Линия", "Lane")
    local closestDist = 999999999
    for _, lm in ipairs(MapLandmarks) do
        local dx = pos.x - lm.pos.x
        local dy = pos.y - lm.pos.y
        local d = dx * dx + dy * dy
        if d < closestDist then
            closestDist = d
            closestName = lm.name
        end
    end
    return closestName
end

local CleanItemNameCache = {}
local function CleanItemName(raw)
    if not raw or raw == "" then return "" end
    if CleanItemNameCache[raw] then return CleanItemNameCache[raw] end
    if KeyItemColors[raw] then
        CleanItemNameCache[raw] = KeyItemColors[raw].name
        return KeyItemColors[raw].name
    end
    local name = raw
    local prefix = "item_"
    if string.sub(name, 1, 5) == prefix then
        name = string.sub(name, 6)
    end
    local res = {}
    for part in string.gmatch(name, "[^_]+") do
        local cap = string.upper(string.sub(part, 1, 1)) .. string.sub(part, 2)
        table.insert(res, cap)
    end
    local result = table.concat(res, " ")
    CleanItemNameCache[raw] = result
    return result
end

local function GetItemSignatureColor(rawItemName)
    if not rawItemName or rawItemName == "" then return Config.Colors.Blue end
    if KeyItemColors[rawItemName] then return KeyItemColors[rawItemName].col end
    return Config.Colors.Blue
end

local function GetItemTexturePath(rawItemName)
    if not rawItemName or rawItemName == "" then return nil end
    local clean = rawItemName
    if string.sub(clean, 1, 5) == "item_" then
        clean = string.sub(clean, 6)
    end
    return "panorama/images/items/" .. clean .. "_png.vtex_c"
end

local function FormatTime(seconds)
    local s = math.max(0, math.floor(seconds or 0))
    local m = math.floor(s / 60)
    local rem = s % 60
    return string.format("%02d:%02d", m, rem)
end

local function FormatNegativeTime(seconds)
    local s = math.max(0, math.floor(seconds or 0))
    local m = math.floor(s / 60)
    local rem = s % 60
    return string.format("-%d:%02d", m, rem)
end

function DynamicIsland.PushNotification(notif)
    if not notif then return end
    if not notif.Duration and UI and UI.Timings and UI.Timings.ToastDuration then
        notif.Duration = UI.Timings.ToastDuration:Get()
    end
    HapticPlaySound("notification_toast", 0.45)
    if notif.Priority == "high" then
        NotificationQueue.Active = notif
        NotificationQueue.StartTime = os.clock()
        TriggerStateTransition(StateMachine.States.NOTIFICATION)
        StateMachine.Spring.Squish.value = 1.0
        StateMachine.Spring.Squish.vel = 5.0
        if Haptic and Haptic.Trigger then
            Haptic.Trigger(Haptic.Types.SNAP_EXPAND)
        end
    else
        table.insert(NotificationQueue.List, notif)
    end
end

local function SendMediaCommand(cmd)
    local port = 45455
    local url = string.format("http://127.0.0.1:%d/media/%s", port, cmd)
    pcall(HTTP.Request, "GET", url, {}, function(res)
        if res and res.response and res.response ~= "" then
            local vStr = string.match(res.response, '"volume"%s*:%s*(%d+)')
            if vStr then
                local v = tonumber(vStr)
                if v then
                    local nowClk = os.clock()
                    if not VolumeState.Visible or (nowClk - (VolumeState.LastActive or 0)) > 1.2 then
                        VolumeState.Target = v
                    end
                end
            end
        end
    end, "media_cmd")
end

local function GetScriptRelPath()
    if Engine and Engine.GetCheatDirectory then
        local ok, cd = pcall(Engine.GetCheatDirectory)
        if ok and cd and cd ~= "" then
            local root = cd:gsub("/", "\\")
            local clean = root:gsub("^%a:\\", ""):gsub("\\", "/")
            return "../../../../../../../../" .. clean .. "scripts/"
        end
    end
    return "../../../../../../../../Umbrella/scripts/"
end

local function TryLoadAlbumImage(coverPath, coverJpg, coverBase64, curVer)
    if not curVer or curVer <= 0 then return nil end
    if coverBase64 and coverBase64 ~= "" then
        local vStr = tostring(curVer)
        local svgPng = string.format('<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><image href="data:image/png;base64,%s" width="100" height="100"/></svg>', coverBase64)
        local ok1, handle1 = pcall(Render.LoadSvgString, svgPng, Vec2(100, 100), "album_cover_png_" .. vStr)
        if ok1 and handle1 and handle1 > 0 then
            return handle1
        end
        local svgJpg = string.format('<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><image href="data:image/jpeg;base64,%s" width="100" height="100"/></svg>', coverBase64)
        local ok2, handle2 = pcall(Render.LoadSvgString, svgJpg, Vec2(100, 100), "album_cover_jpg_" .. vStr)
        if ok2 and handle2 and handle2 > 0 then
            return handle2
        end
    end
    local cheatDir = (Engine and Engine.GetCheatDirectory and Engine.GetCheatDirectory() or "C:/Umbrella/") .. "scripts/"
    local vStr = tostring(curVer)
    local paths = {
        coverPath,
        coverJpg,
        cheatDir .. "dynamic_island_cover_" .. vStr .. ".png",
        cheatDir .. "dynamic_island_cover.png",
        cheatDir .. "dynamic_island_cover.jpg",
        "dynamic_island_cover_" .. vStr .. ".png",
        "dynamic_island_cover.png"
    }
    for _, p in ipairs(paths) do
        if p and p ~= "" then
            local f = io.open(p, "rb")
            if f then
                f:close()
                local ok, handle = pcall(Render.LoadImage, p)
                if ok and handle and handle > 0 then
                    return handle
                end
            end
        end
    end
    return nil
end

local function IsMediaActive()
    if not UI or not UI.Media.Enabled:Get() then return false end
    if not MediaData.HasReceivedData then return false end
    if MediaData.Title == "" and MediaData.LastTrackKey == "" then return false end
    if MediaData.IsPlaying then return true end
    local clk = os.clock()
    if MediaData.LastPauseTime > 0 and (clk - MediaData.LastPauseTime) <= 3.2 then
        return true
    end
    return false
end

local function PollMediaBridge()
    if not UI or not UI.Media.Enabled:Get() then return end
    local clk = os.clock()
    if clk - MediaData.LastPollTime < MediaData.PollInterval then return end
    MediaData.LastPollTime = clk
    
    local port = 45455
    local url = string.format("http://127.0.0.1:%d/media", port)
    
    pcall(HTTP.Request, "GET", url, {}, function(res)
        if not res or not res.response or res.response == "" then return end
        local body = res.response
        
        local isPlaying = string.find(body, '"is_playing"%s*:%s*true') ~= nil
        local title = string.match(body, '"title"%s*:%s*"([^"]*)"') or ""
        local artist = string.match(body, '"artist"%s*:%s*"([^"]*)"') or ""
        local album = string.match(body, '"album"%s*:%s*"([^"]*)"') or ""
        local app = string.match(body, '"app"%s*:%s*"([^"]*)"') or ""

        local coverPath = string.match(body, '"cover_path"%s*:%s*"([^"]*)"') or ""
        local coverJpg = string.match(body, '"cover_jpg"%s*:%s*"([^"]*)"') or ""
        local coverBase64 = ""
        local b64Pos = string.find(body, '"cover_base64"%s*:%s*"')
        if b64Pos then
            local _, vStart = string.find(body, '"cover_base64"%s*:%s*"')
            local vEnd = string.find(body, '"', vStart + 1, true)
            if vEnd then
                coverBase64 = string.sub(body, vStart + 1, vEnd - 1)
            end
        end
        local coverVerStr = string.match(body, '"cover_ver"%s*:%s*([%d]+)')
        local hasCover = string.find(body, '"has_cover"%s*:%s*true') ~= nil
        local posStr = string.match(body, '"position"%s*:%s*([%d%.]+)')
        local durStr = string.match(body, '"duration"%s*:%s*([%d%.]+)')
        local isShuffle = string.find(body, '"shuffle"%s*:%s*true') ~= nil
        local repStr = string.match(body, '"repeat"%s*:%s*([%d]+)')
        local volStr = string.match(body, '"volume"%s*:%s*([%d]+)')
        local nowClk = os.clock()
        if volStr and (not VolumeState.Visible or (nowClk - (VolumeState.LastActive or 0)) > 1.2) then
            local v = tonumber(volStr)
            if v then
                VolumeState.Target = v
                if VolumeState.Alpha <= 0.01 then
                    VolumeState.Current = v
                    VolumeState.CurrentVel = 0.0
                end
            end
        end
        local manualGrace = (MediaData.LastManualToggle and (nowClk - MediaData.LastManualToggle) < 0.8)
        if not manualGrace then
            if isPlaying then
                MediaData.LastPlayTime = nowClk
                MediaData.LastPauseTime = 0
                MediaData.IsPlaying = true
            else
                if MediaData.IsPlaying then
                    MediaData.LastPauseTime = nowClk
                elseif MediaData.LastPauseTime == 0 and MediaData.LastPlayTime > 0 then
                    MediaData.LastPauseTime = nowClk
                end
                MediaData.IsPlaying = false
            end
        end
        
        local cleanTitle = CleanUnescapedString(title)
        local cleanArtist = CleanUnescapedString(artist)
        local newTrackKey = cleanTitle .. " - " .. cleanArtist
        
        if cleanTitle ~= "" and newTrackKey ~= MediaData.LastTrackKey and MediaData.LastTrackKey ~= "" then
            TrackTransition.Active = true
            TrackTransition.StartTime = nowClk
            TrackTransition.OldTitle = MediaData.Title
            TrackTransition.OldArtist = MediaData.Artist
            TrackTransition.OldCoverHandle = MediaData.CoverImageHandle
            TrackTransition.OldCoverColor = MediaData.CoverColor
            MediaData.CoverImageHandle = nil
            MediaData.CoverVersion = -1
        end
        
        if cleanTitle ~= "" then
            MediaData.Title = cleanTitle
            MediaData.LastTrackKey = newTrackKey
        end
        if cleanArtist ~= "" then
            MediaData.Artist = cleanArtist
        end
        if album ~= "" then
            MediaData.Album = CleanUnescapedString(album)
        end
        MediaData.App = app
        MediaData.Position = tonumber(posStr) or 0
        MediaData.Duration = tonumber(durStr) or 0
        MediaData.LocalTimeAtPoll = nowClk
        MediaData.HasReceivedData = true
        MediaData.HasCover = hasCover
        MediaData.CoverPath = coverPath
        MediaData.CoverJpg = coverJpg
        MediaData.CoverBase64 = coverBase64
        MediaData.Shuffle = isShuffle
        MediaData.RepeatMode = tonumber(repStr) or 0
        
        if string.find(body, '"is_liked"') then
            MediaData.IsLiked = (string.find(body, '"is_liked"%s*:%s*true') ~= nil)
            if cleanTitle ~= "" then
                MediaData.LikedTracks[newTrackKey] = MediaData.IsLiked
            end
        end
        
        local colorMatch = string.match(body, '"cover_color"%s*:%s*%[([%d, %s]+)%]')
        if colorMatch then
            local rgb = {}
            for num in string.gmatch(colorMatch, "[%d]+") do
                table.insert(rgb, tonumber(num))
            end
            if #rgb >= 3 then
                MediaData.CoverColor = Color(rgb[1], rgb[2], rgb[3], 255)
            end
        end
        
        if not MediaData.IsPlaying then
            MediaData.RealBars = { 0, 0, 0, 0, 0 }
        else
            local waveMatch = string.match(body, '"waveform"%s*:%s*%[([^%]]*)%]')
            if waveMatch then
                local idx = 1
                for num in string.gmatch(waveMatch, "[%d%.]+") do
                    MediaData.RealBars[idx] = tonumber(num) or 0
                    idx = idx + 1
                    if idx > 5 then break end
                end
            end
        end
        
        local curVer = tonumber(coverVerStr) or 0
        if curVer ~= MediaData.CoverVersion or not MediaData.CoverImageHandle then
            MediaData.CoverVersion = curVer
            if hasCover and curVer > 0 then
                local img = TryLoadAlbumImage(coverPath, coverJpg, coverBase64, curVer)
                if img then
                    MediaData.CoverImageHandle = img
                end
            else
                MediaData.CoverImageHandle = nil
            end
        end
    end, "media_poll")
end

local function ProcessFightDetector()
    if not UI or not UI.Combat or not UI.Combat.FightHUD:Get() then
        if FightTracker.Active then
            FightTracker.Active = false
        end
        return
    end
    
    local my = HeroData.Local or Heroes.GetLocal()
    if not my then return end
    
    local allHeroes = Heroes.GetAll()
    local nowTime = GameRules.GetGameTime()
    local myTeam = Entity.GetTeamNum(my)
    local scope = UI.Combat.FightScope:Get()
    local minHeroesReq = UI.Combat.MinHeroes:Get()
    local radius = UI.Combat.FightRadius:Get()
    
    for _, h in ipairs(allHeroes) do
        if Entity.IsHero(h) and not Entity.IsDormant(h) and Entity.IsAlive(h) then
            local idx = Entity.GetIndex(h)
            local curHp = Entity.GetHealth(h)
            local prevHp = FightTracker.HeroHPMap[idx]
            if prevHp and curHp < prevHp then
                local hTeam = Entity.GetTeamNum(h)
                local hPos = Entity.GetAbsOrigin(h)
                for _, eh in ipairs(allHeroes) do
                    if Entity.IsHero(eh) and Entity.IsAlive(eh) and not Entity.IsDormant(eh) and Entity.GetTeamNum(eh) ~= hTeam then
                        local ehPos = Entity.GetAbsOrigin(eh)
                        local dx = hPos.x - ehPos.x
                        local dy = hPos.y - ehPos.y
                        local distSq = dx * dx + dy * dy
                        local isMelee = not (NPC.IsRanged and NPC.IsRanged(eh))
                        local maxRange = isMelee and 220 or 500
                        if distSq <= (maxRange * maxRange) and NPC.IsAttacking and NPC.IsAttacking(eh) then
                            FightTracker.LastDamageTimes[idx] = nowTime
                            FightTracker.LastDamageTimes[Entity.GetIndex(eh)] = nowTime
                            break
                        end
                    end
                end
            end
            FightTracker.HeroHPMap[idx] = curHp
        end
    end
    
    local candidates = {}
    for _, h in ipairs(allHeroes) do
        if Entity.IsHero(h) and Entity.IsAlive(h) and not Entity.IsDormant(h) then
            local idx = Entity.GetIndex(h)
            local lastHurt = FightTracker.LastDamageTimes[idx] or 0
            local isHurtRecent = (nowTime - lastHurt) <= 2.8
            local pos = Entity.GetAbsOrigin(h)
            table.insert(candidates, { hero = h, idx = idx, pos = pos, team = Entity.GetTeamNum(h), hurt = isHurtRecent })
        end
    end
    
    local bestCluster = nil
    local bestScore = 0
    
    if scope == 0 then
        local myPos = Entity.GetAbsOrigin(my)
        local cAllies = {}
        local cEnemies = {}
        local hurtCount = 0
        
        for _, c in ipairs(candidates) do
            local dx = c.pos.x - myPos.x
            local dy = c.pos.y - myPos.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= radius then
                if c.team == myTeam then
                    table.insert(cAllies, c.hero)
                else
                    table.insert(cEnemies, c.hero)
                end
                if c.hurt then hurtCount = hurtCount + 1 end
            end
        end
        
        local totalInFight = #cAllies + #cEnemies
        if totalInFight >= minHeroesReq and #cEnemies >= 1 and #cAllies >= 1 and hurtCount >= 1 then
            local heroesEngaged = false
            for _, a in ipairs(cAllies) do
                local aPos = Entity.GetAbsOrigin(a)
                for _, e in ipairs(cEnemies) do
                    local ePos = Entity.GetAbsOrigin(e)
                    local dx = aPos.x - ePos.x
                    local dy = aPos.y - ePos.y
                    if (dx * dx + dy * dy) <= (1100 * 1100) then
                        heroesEngaged = true
                        break
                    end
                end
                if heroesEngaged then break end
            end
            if heroesEngaged then
                bestCluster = { center = myPos, allies = cAllies, enemies = cEnemies }
            end
        end
    else
        for _, seed in ipairs(candidates) do
            local cAllies = {}
            local cEnemies = {}
            local hurtCount = 0
            local sumX = 0
            local sumY = 0
            local cnt = 0
            
            for _, other in ipairs(candidates) do
                local dx = other.pos.x - seed.pos.x
                local dy = other.pos.y - seed.pos.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist <= radius then
                    if other.team == myTeam then
                        table.insert(cAllies, other.hero)
                    else
                        table.insert(cEnemies, other.hero)
                    end
                    if other.hurt then hurtCount = hurtCount + 1 end
                    sumX = sumX + other.pos.x
                    sumY = sumY + other.pos.y
                    cnt = cnt + 1
                end
            end
            
            local totalInFight = #cAllies + #cEnemies
            if totalInFight >= minHeroesReq and #cAllies >= 1 and #cEnemies >= 1 and hurtCount >= 1 then
                local heroesEngaged = false
                for _, a in ipairs(cAllies) do
                    local aPos = Entity.GetAbsOrigin(a)
                    for _, e in ipairs(cEnemies) do
                        local ePos = Entity.GetAbsOrigin(e)
                        local dx = aPos.x - ePos.x
                        local dy = aPos.y - ePos.y
                        if (dx * dx + dy * dy) <= (1100 * 1100) then
                            heroesEngaged = true
                            break
                        end
                    end
                    if heroesEngaged then break end
                end
                if heroesEngaged then
                    local score = totalInFight * 10 + hurtCount * 5
                    if score > bestScore then
                        bestScore = score
                        bestCluster = { center = { x = sumX / cnt, y = sumY / cnt }, allies = cAllies, enemies = cEnemies }
                    end
                end
            end
        end
    end
    
    if bestCluster then
        FightTracker.LastCombatTime = nowTime
        FightTracker.Center = bestCluster.center
        FightTracker.Allies = bestCluster.allies
        FightTracker.Enemies = bestCluster.enemies
        FightTracker.AllyCount = #bestCluster.allies
        FightTracker.EnemyCount = #bestCluster.enemies
        FightTracker.Landmark = GetClosestLandmark(bestCluster.center)
        
        if not FightTracker.Active then
            FightTracker.Active = true
            FightTracker.StartTime = nowTime
            FightTracker.AlliesKilled = 0
            FightTracker.EnemiesKilled = 0
            FightTracker.HeroAliveState = {}
            for _, h in ipairs(allHeroes) do
                if Entity.IsHero(h) then
                    FightTracker.HeroAliveState[h] = Entity.IsAlive(h)
                end
            end
        else
            for _, h in ipairs(allHeroes) do
                if Entity.IsHero(h) and not Entity.IsDormant(h) then
                    local isAlive = Entity.IsAlive(h)
                    local wasAlive = FightTracker.HeroAliveState[h]
                    if wasAlive == true and not isAlive then
                        local hPos = Entity.GetAbsOrigin(h)
                        local dx = hPos.x - FightTracker.Center.x
                        local dy = hPos.y - FightTracker.Center.y
                        if (dx * dx + dy * dy) <= (radius * radius * 1.5) then
                            if Entity.GetTeamNum(h) == myTeam then
                                FightTracker.AlliesKilled = FightTracker.AlliesKilled + 1
                            else
                                FightTracker.EnemiesKilled = FightTracker.EnemiesKilled + 1
                            end
                        end
                    end
                    FightTracker.HeroAliveState[h] = isAlive
                end
            end
        end
        
        if not NotificationQueue.Active and StateMachine.TargetState ~= StateMachine.States.NOTIFICATION then
            if StateMachine.TargetState ~= StateMachine.States.COMPACT_FIGHT and StateMachine.TargetState ~= StateMachine.States.LARGE_FIGHT then
                TriggerStateTransition(StateMachine.States.COMPACT_FIGHT)
            end
        end
    else
        if FightTracker.Active then
            local fightTimeout = (UI and UI.Combat and UI.Combat.FightTimeout) and UI.Combat.FightTimeout:Get() or 4.0
            if (nowTime - FightTracker.LastCombatTime) >= fightTimeout then
                FightTracker.Active = false
                
                local ek = FightTracker.EnemiesKilled
                local ak = FightTracker.AlliesKilled
                local summaryTitle = L("Стычка окончена", "Skirmish Concluded")
                local summarySub = L("Все участники разошлись", "All combatants retreated")
                local summaryCol = Config.Colors.Yellow
                
                if ek > ak then
                    summaryTitle = L("Победа в файте!", "Fight Won!")
                    summarySub = string.format(L("Врагов убито: %d  •  Потерь: %d", "Enemies slain: %d  •  Losses: %d"), ek, ak)
                    summaryCol = Config.Colors.Accent
                elseif ak > ek then
                    summaryTitle = L("Файт проигран", "Fight Lost")
                    summarySub = string.format(L("Потери команды: %d  •  Убито: %d", "Team losses: %d  •  Kills: %d"), ak, ek)
                    summaryCol = Config.Colors.Red
                elseif ek > 0 and ek == ak then
                    summaryTitle = L("Размен в файте", "Even Trade")
                    summarySub = string.format(L("Размен %d в %d", "Traded %d for %d"), ek, ak)
                    summaryCol = Config.Colors.Orange
                end
                
                DynamicIsland.PushNotification({
                    Type = "fight_summary",
                    Tag = L("ИТОГИ СРАЖЕНИЯ", "FIGHT OUTCOME"),
                    Title = summaryTitle,
                    Subtitle = summarySub,
                    AccentColor = summaryCol,
                    IconType = "svg",
                    FallbackSvg = "swords",
                    Duration = 3.5
                })
                
                local mediaActive = IsMediaActive()
                local target = mediaActive and StateMachine.States.COMPACT_MEDIA or StateMachine.States.COMPACT_IDLE
                TriggerStateTransition(target)
            end
        end
    end
end

local function ProcessGameEvents()
    local now = GameRules.GetGameTime()
    if now - GameTracker.LastScanTime < 0.1 then return end
    GameTracker.LastScanTime = now
    
    local localHero = HeroData.Local
    if not localHero then return end
    
    local localPlayer = Players.GetLocal()
    if localPlayer then
        local teamData = Player.GetTeamData(localPlayer)
        if teamData then
            HeroData.Kills = teamData.kills or 0
            HeroData.Deaths = teamData.deaths or 0
            HeroData.Assists = teamData.assists or 0
        end
        
        local okTP, tp = pcall(Player.GetTeamPlayer, localPlayer)
        if okTP and tp then
            HeroData.Gold = (tp.reliable_gold or 0) + (tp.unreliable_gold or 0)
            HeroData.NetWorth = tp.networth or 0
            HeroData.LastHits = tp.lasthit_count or 0
            HeroData.Denies = tp.deny_count or 0
        else
            local okTG, tg = pcall(Player.GetTotalGold, localPlayer)
            if okTG and tg then HeroData.Gold = tg end
        end
        
        local okPD, pd = pcall(Player.GetPlayerData, localPlayer)
        if okPD and pd and pd.Ping then
            PerformanceData.Ping = pd.Ping
        end
    end
    
    if UI.Combat.LevelUp:Get() then
        local curLevel = NPC.GetCurrentLevel(localHero)
        if HeroData.Level > 0 and curLevel > HeroData.Level then
            local heroRaw = NPC.GetUnitName(localHero)
            DynamicIsland.PushNotification({
                Type = "level",
                Tag = L("НОВЫЙ УРОВЕНЬ", "LEVEL UP"),
                Title = string.format(L("Уровень %d получен", "Level %d Reached"), curLevel),
                Subtitle = CleanHeroName(HeroData.HeroName),
                AccentColor = Config.Colors.Yellow,
                IconType = "hero",
                Icon = "panorama/images/heroes/icons/" .. heroRaw .. "_png.vtex_c",
                Duration = 3.0
            })
        end
        HeroData.Level = curLevel
    end
    
    if UI.Combat.Kills:Get() and localPlayer then
        local teamData = Player.GetTeamData(localPlayer)
        if teamData then
            local curKills = teamData.kills or 0
            if curKills > HeroData.Kills then
                local diff = curKills - HeroData.Kills
                local streakTitle = L("Враг повержен!", "Enemy Slain!")
                if diff >= 5 then streakTitle = "RAMPAGE!"
                elseif diff == 4 then streakTitle = "Ultra Kill!"
                elseif diff == 3 then streakTitle = "Triple Kill!"
                elseif diff == 2 then streakTitle = "Double Kill!"
                elseif curKills == 1 then streakTitle = "First Blood!"
                elseif curKills >= 10 then streakTitle = "HOLY SHIT! (" .. curKills .. " Kills)"
                elseif curKills >= 8 then streakTitle = "BEYOND GODLIKE!"
                elseif curKills >= 6 then streakTitle = "Monster Kill!"
                elseif curKills >= 4 then streakTitle = "Dominating!"
                elseif curKills >= 3 then streakTitle = "Killing Spree!"
                end
                
                local killedHeroName = L("Враг", "Enemy")
                local killedRaw = ""
                local allHeroes = Heroes.GetAll()
                for _, h in pairs(allHeroes) do
                    if Entity.GetTeamNum(h) ~= Entity.GetTeamNum(localHero) then
                        local hId = tostring(h)
                        local wasAlive = HeroData.EnemyHeroes[hId] == nil or HeroData.EnemyHeroes[hId] == true
                        local isNowAlive = Entity.IsAlive(h)
                        if wasAlive and not isNowAlive then
                            killedRaw = NPC.GetUnitName(h)
                            killedHeroName = CleanHeroName(killedRaw)
                            HeroData.LastKilled.Name = killedHeroName
                            HeroData.LastKilled.MaxHP = Entity.GetMaxHealth(h)
                            HeroData.LastKilled.Level = NPC.GetCurrentLevel(h)
                            HeroData.LastKilled.Items = {}
                            for idx = 0, 5 do
                                local it = NPC.GetItemByIndex(h, idx)
                                if it then
                                    local iname = Ability.GetName(it)
                                    if iname and iname ~= "" then
                                        table.insert(HeroData.LastKilled.Items, CleanItemName(iname))
                                    end
                                end
                            end
                            break
                        end
                    end
                end
                
                DynamicIsland.PushNotification({
                    Type = "kill",
                    Tag = L("СЕРИЯ УБИЙСТВ", "KILL STREAK"),
                    Title = streakTitle,
                    Subtitle = L("Уничтожен ", "Eliminated ") .. killedHeroName,
                    AccentColor = Config.Colors.Red,
                    IconType = "hero",
                    Icon = killedRaw ~= "" and ("panorama/images/heroes/icons/" .. killedRaw .. "_png.vtex_c") or nil,
                    Duration = 3.8
                })
            end
        end
    end
    
    local allHeroesList = Heroes.GetAll()
    for _, h in pairs(allHeroesList) do
        if Entity.GetTeamNum(h) ~= Entity.GetTeamNum(localHero) then
            local hId = tostring(h)
            HeroData.EnemyHeroes[hId] = Entity.IsAlive(h)
            
            if UI.Combat.KeyEnemyItems:Get() and Entity.IsAlive(h) then
                if not HeroData.EnemyInventoryCache[hId] then
                    HeroData.EnemyInventoryCache[hId] = {}
                end
                for idx = 0, 5 do
                    local it = NPC.GetItemByIndex(h, idx)
                    if it then
                        local rawName = Ability.GetName(it)
                        if rawName and KeyItemColors[rawName] and not HeroData.EnemyInventoryCache[hId][rawName] then
                            HeroData.EnemyInventoryCache[hId][rawName] = true
                            local hName = CleanHeroName(NPC.GetUnitName(h))
                            local itemCol = GetItemSignatureColor(rawName)
                            DynamicIsland.PushNotification({
                                Type = "enemy_item",
                                Tag = L("ПРЕДМЕТ ВРАГА", "ITEM ALERT"),
                                Title = KeyItemColors[rawName].name,
                                Subtitle = hName .. L(" купил предмет", " purchased item"),
                                AccentColor = itemCol,
                                IconType = "item",
                                Icon = GetItemTexturePath(rawName),
                                Duration = 4.0
                            })
                        end
                    end
                end
            end
        end
    end
    
    if UI.Runes.RuneWorldSpawn:Get() and Runes.GetAll then
        local currentRunes = Runes.GetAll()
        local activeSet = {}
        for _, r in pairs(currentRunes) do
            if r then
                local idx = Entity.GetIndex(r)
                if idx then
                    activeSet[idx] = true
                    if not GameTracker.Runes.KnownWorldRunes[idx] then
                        GameTracker.Runes.KnownWorldRunes[idx] = true
                        local rType = Rune.GetRuneType(r)
                        local rPos = Entity.GetAbsOrigin(r)
                        local rInfo = RuneInfoList[rType] or { en = "Rune", ru = "Руна", col = Color(255, 220, 0, 255), path = "panorama/images/spellicons/rune_doubledamage_png.vtex_c", svg = "rune_dd" }
                        local locText = L("появилась на реке", "spawned in river")
                        if rPos then
                            if rType == Enum.RuneType.DOTA_RUNE_XP then
                                locText = L("появилась у Алтаря", "spawned at Shrine")
                            elseif rType ~= Enum.RuneType.DOTA_RUNE_BOUNTY then
                                locText = rPos.y > 0 and L("появилась Сверху (Топ)", "spawned Top River") or L("появилась Снизу (Бот)", "spawned Bottom River")
                            end
                        end
                        DynamicIsland.PushNotification({
                            Type = "rune_world",
                            Tag = L("ПОЯВЛЕНИЕ РУНЫ", "RUNE SPAWNED"),
                            Title = L(rInfo.ru, rInfo.en),
                            Subtitle = locText,
                            AccentColor = rInfo.col,
                            IconType = "rune",
                            Icon = rInfo.path,
                            FallbackSvg = rInfo.svg,
                            Duration = 3.8
                        })
                    end
                end
            end
        end
        for k in pairs(GameTracker.Runes.KnownWorldRunes) do
            if not activeSet[k] then GameTracker.Runes.KnownWorldRunes[k] = nil end
        end
    end
    
    local matchTime = GetActualMatchTime()
    if matchTime and matchTime > -90 then
        local tf = math.floor(matchTime)
        local powerLead = UI.Timings.PowerRuneTime:Get()
        local waterLead = UI.Timings.WaterRuneTime:Get()
        local bountyLead = UI.Timings.BountyRuneTime:Get()
        local wisdomLead = UI.Timings.WisdomRuneTime:Get()
        local tLead1 = UI.Timings.Tormentor1Time:Get()
        local tLead2 = UI.Timings.Tormentor2Time:Get()
        
        if tf > 0 then
            local nm = math.floor(tf / 60) + 1
            local sl = nm * 60 - tf
            
            if UI.Runes.WisdomRunes:Get() and sl == wisdomLead and nm % 7 == 0 then
                local key = "w_" .. nm
                if not GameTracker.Runes.WarnedMilestones[key] then
                    GameTracker.Runes.WarnedMilestones[key] = true
                    DynamicIsland.PushNotification({
                        Type = "rune",
                        Tag = L("МУДРОСТЬ", "WISDOM RUNE"),
                        Title = string.format(L("Руны мудрости через %dс", "Wisdom Runes in %ds"), wisdomLead),
                        Subtitle = L("Боковые алтари мудрости", "Side lane shrines"),
                        AccentColor = Color(165, 75, 255, 255),
                        IconType = "rune",
                        Icon = "panorama/images/spellicons/rune_xp_png.vtex_c",
                        FallbackSvg = "rune_wisdom",
                        Duration = 4.0
                    })
                end
            end
            
            if UI.Runes.WaterRunes:Get() and (nm == 2 or nm == 4) and sl == waterLead then
                local key = "water_" .. nm
                if not GameTracker.Runes.WarnedMilestones[key] then
                    GameTracker.Runes.WarnedMilestones[key] = true
                    DynamicIsland.PushNotification({
                        Type = "rune",
                        Tag = L("РУНА ВОДЫ", "WATER RUNE"),
                        Title = string.format(L("Руны воды через %dс", "Water Runes in %ds"), waterLead),
                        Subtitle = L("Точки спавна на реке", "River spawn points"),
                        AccentColor = Color(0, 215, 255, 255),
                        IconType = "rune",
                        FallbackSvg = "rune_water",
                        Duration = 3.5
                    })
                end
            end
            
            if UI.Runes.ActiveRunes:Get() and nm >= 6 and nm % 2 == 0 and sl == powerLead then
                local key = "power_" .. nm
                if not GameTracker.Runes.WarnedMilestones[key] then
                    GameTracker.Runes.WarnedMilestones[key] = true
                    DynamicIsland.PushNotification({
                        Type = "power_rune_cycle",
                        Tag = L("АКТИВНАЯ РУНА", "POWER RUNE"),
                        Title = string.format(L("Руны усиления через %dс", "Power Runes in %ds"), powerLead),
                        Subtitle = L("Точки спавна на реке", "River spawn points"),
                        AccentColor = Color(60, 140, 255, 255),
                        Duration = 4.0
                    })
                end
            end
            
            if UI.Runes.BountyRunes:Get() and nm % 3 == 0 and sl == bountyLead then
                local bKey = "bounty_" .. nm
                if not GameTracker.Runes.WarnedMilestones[bKey] then
                    GameTracker.Runes.WarnedMilestones[bKey] = true
                    DynamicIsland.PushNotification({
                        Type = "rune",
                        Tag = L("БОГАТСТВО", "BOUNTY RUNE"),
                        Title = string.format(L("Руны богатства через %dс", "Bounty Runes in %ds"), bountyLead),
                        Subtitle = L("Точки спавна богатства", "Bounty spawn spots"),
                        AccentColor = Color(255, 200, 20, 255),
                        IconType = "rune",
                        Icon = "panorama/images/items/courier_gold_png.vtex_c",
                        FallbackSvg = "bounty",
                        Duration = 3.5
                    })
                end
            end
            
            if tf >= (1200 - tLead1) and tf <= (1200 - tLead1 + 2) and UI.Runes.Tormentor:Get() and not GameTracker.Tormentor.Warned1 then
                GameTracker.Tormentor.Warned1 = true
                local minStr = FormatTime(tLead1)
                DynamicIsland.PushNotification({
                    Type = "tormentor",
                    Tag = L("ТЕРЗАТЕЛЬ", "OBJECTIVE"),
                    Title = string.format(L("Терзатель скоро (%s)", "Tormentor Soon (%s)"), minStr),
                    Subtitle = L("Появление ровно в 20:00", "Spawns at 20:00"),
                    AccentColor = Color(0, 210, 255, 255),
                    IconType = "item",
                    Icon = "panorama/images/items/aghanims_shard_png.vtex_c",
                    Duration = 4.5
                })
            elseif tf >= (1200 - tLead2) and tf <= (1200 - tLead2 + 2) and UI.Runes.Tormentor:Get() and not GameTracker.Tormentor.Warned2 then
                GameTracker.Tormentor.Warned2 = true
                DynamicIsland.PushNotification({
                    Type = "tormentor",
                    Tag = L("ТЕРЗАТЕЛЬ", "OBJECTIVE"),
                    Title = string.format(L("Терзатель через %dс", "Tormentor in %ds"), tLead2),
                    Subtitle = L("Появление на 20:00", "Spawns at 20:00"),
                    AccentColor = Color(0, 210, 255, 255),
                    IconType = "item",
                    Icon = "panorama/images/items/aghanims_shard_png.vtex_c",
                    Duration = 4.5
                })
            end
        elseif tf <= -bountyLead and tf >= -(bountyLead + 2) and UI.Runes.BountyRunes:Get() and not GameTracker.Runes.WarnedMilestones["start_bounty"] then
            GameTracker.Runes.WarnedMilestones["start_bounty"] = true
            DynamicIsland.PushNotification({
                Type = "rune",
                Tag = L("БОГАТСТВО", "BOUNTY RUNE"),
                Title = string.format(L("Руны богатства через %dс", "Bounty Runes in %ds"), bountyLead),
                Subtitle = L("Стартовые руны", "Initial bounty spawns"),
                AccentColor = Color(255, 200, 20, 255),
                IconType = "rune",
                Icon = "panorama/images/items/courier_gold_png.vtex_c",
                FallbackSvg = "bounty",
                Duration = 4.0
            })
        end
    end
    
    local sec = math.floor(GetActualMatchTime())
    if sec >= 420 and not GameTracker.Neutrals.Tier1 then
        GameTracker.Neutrals.Tier1 = true
        DynamicIsland.PushNotification({
            Type = "neutral",
            Tag = L("НЕЙТРАЛКИ", "NEUTRALS UNLOCKED"),
            Title = L("Tier 1 Нейтралки доступны", "Tier 1 Neutrals Ready"),
            Subtitle = L("Время матча 7:00", "7:00 match time reached"),
            AccentColor = Color(160, 210, 80, 255),
            Duration = 4.0
        })
    elseif sec >= 1020 and not GameTracker.Neutrals.Tier2 then
        GameTracker.Neutrals.Tier2 = true
        DynamicIsland.PushNotification({
            Type = "neutral",
            Tag = L("НЕЙТРАЛКИ", "NEUTRALS UNLOCKED"),
            Title = L("Tier 2 Нейтралки доступны", "Tier 2 Neutrals Ready"),
            Subtitle = L("Время матча 17:00", "17:00 match time reached"),
            AccentColor = Color(75, 185, 255, 255),
            Duration = 4.0
        })
    elseif sec >= 1620 and not GameTracker.Neutrals.Tier3 then
        GameTracker.Neutrals.Tier3 = true
        DynamicIsland.PushNotification({
            Type = "neutral",
            Tag = L("НЕЙТРАЛКИ", "NEUTRALS UNLOCKED"),
            Title = L("Tier 3 Нейтралки доступны", "Tier 3 Neutrals Ready"),
            Subtitle = L("Время матча 27:00", "27:00 match time reached"),
            AccentColor = Color(175, 90, 255, 255),
            Duration = 4.0
        })
    elseif sec >= 2220 and not GameTracker.Neutrals.Tier4 then
        GameTracker.Neutrals.Tier4 = true
        DynamicIsland.PushNotification({
            Type = "neutral",
            Tag = L("НЕЙТРАЛКИ", "NEUTRALS UNLOCKED"),
            Title = L("Tier 4 Нейтралки доступны", "Tier 4 Neutrals Ready"),
            Subtitle = L("Время матча 37:00", "37:00 match time reached"),
            AccentColor = Color(255, 170, 30, 255),
            Duration = 4.0
        })
    elseif sec >= 3600 and not GameTracker.Neutrals.Tier5 then
        GameTracker.Neutrals.Tier5 = true
        DynamicIsland.PushNotification({
            Type = "neutral",
            Tag = L("НЕЙТРАЛКИ", "NEUTRALS UNLOCKED"),
            Title = L("Tier 5 Нейтралки доступны", "Tier 5 Neutrals Ready"),
            Subtitle = L("Время матча 60:00", "60:00 match time reached"),
            AccentColor = Color(255, 45, 65, 255),
            Duration = 5.0
        })
    end
    
    if UI.Runes.Lotus:Get() and sec > 0 then
        local lotusLead = UI.Timings.LotusTime:Get()
        if (sec + lotusLead) % 180 <= 1 and (sec - GameTracker.Lotus.LastAlertTime > 60) then
            GameTracker.Lotus.LastAlertTime = sec
            DynamicIsland.PushNotification({
                Type = "lotus",
                Tag = L("ЛОТОС", "LOTUS POOL"),
                Title = string.format(L("Лотосы через %dс", "Lotus Fruit in %ds"), lotusLead),
                Subtitle = L("Боковые пруды лотосов", "Side lane pools"),
                AccentColor = Color(255, 120, 180, 255),
                IconType = "rune",
                Icon = "panorama/images/items/great_famango_png.vtex_c",
                FallbackSvg = "lotus",
                Duration = 3.5
            })
        end
    end
    
    if UI.Combat.Couriers:Get() and Couriers.GetAll then
        local couriers = Couriers.GetAll()
        for _, c in pairs(couriers) do
            if Entity.GetTeamNum(c) == Entity.GetTeamNum(localHero) then
                local cId = tostring(c)
                local hp = Entity.GetHealth(c)
                local maxHp = Entity.GetMaxHealth(c)
                local prevHp = GameTracker.Couriers.LastHP[cId] or hp
                if hp < prevHp and (now - GameTracker.Couriers.LastAlert > 15.0) then
                    GameTracker.Couriers.LastAlert = now
                    DynamicIsland.PushNotification({
                        Type = "courier",
                        Tag = L("КУРЬЕР", "COURIER WARNING"),
                        Title = L("Курьер атакован!", "Courier Under Attack!"),
                        Subtitle = string.format(L("Осталось %d HP", "%d HP remaining"), hp),
                        AccentColor = Config.Colors.Red,
                        Duration = 4.0
                    })
                end
                GameTracker.Couriers.LastHP[cId] = hp
            end
        end
    end
    
    if UI.Combat.Towers:Get() then
        local towers = NPCs.GetAll(Enum.UnitTypeFlags.TYPE_TOWER)
        for _, t in pairs(towers) do
            local tHandle = tostring(t)
            local hp = Entity.GetHealth(t)
            local maxHp = Entity.GetMaxHealth(t)
            local prevHp = GameTracker.Towers.LastHP[tHandle] or hp
            
            if hp < prevHp and Entity.GetTeamNum(t) == Entity.GetTeamNum(localHero) then
                local lastAlert = GameTracker.Towers.LastAlert[tHandle] or 0
                if now - lastAlert > 20.0 then
                    local tPos = Entity.GetAbsOrigin(t)
                    local nearby = Heroes.GetAll()
                    local hasEnemyNear = false
                    for _, eh in pairs(nearby) do
                        if Entity.GetTeamNum(eh) ~= Entity.GetTeamNum(localHero) and Entity.IsAlive(eh) then
                            local dist = (Entity.GetAbsOrigin(eh) - tPos):Length2D()
                            if dist < 1100 then
                                hasEnemyNear = true
                                break
                            end
                        end
                    end
                    if hasEnemyNear then
                        GameTracker.Towers.LastAlert[tHandle] = now
                        local pct = math.floor((hp / maxHp) * 100)
                        DynamicIsland.PushNotification({
                            Type = "tower",
                            Tag = L("ВЫШКА", "TOWER DEFENSE"),
                            Title = L("Вышка атакована", "Ally Tower Attacked"),
                            Subtitle = string.format(L("Здоровье упало до %d%%", "Health dropped to %d%%"), pct),
                            AccentColor = Config.Colors.Orange,
                            IconType = "item",
                            Icon = "panorama/images/items/tpscroll_png.vtex_c",
                            Duration = 3.5
                        })
                    end
                end
            end
            GameTracker.Towers.LastHP[tHandle] = hp
        end
    end
    
    if UI.Combat.LowHP:Get() then
        local enemyHeroes = Heroes.GetAll()
        for _, eh in pairs(enemyHeroes) do
            if Entity.GetTeamNum(eh) ~= Entity.GetTeamNum(localHero) and Entity.IsAlive(eh) then
                local ehId = tostring(eh)
                local hp = Entity.GetHealth(eh)
                if hp <= 350 and hp > 0 then
                    local lastWarn = HeroData.LowHPCache[ehId] or 0
                    if now - lastWarn > 18.0 then
                        HeroData.LowHPCache[ehId] = now
                        local rawName = NPC.GetUnitName(eh)
                        local name = CleanHeroName(rawName)
                        DynamicIsland.PushNotification({
                            Type = "low_hp",
                            Tag = L("LOW HP ВРАГ", "KILL OPPORTUNITY"),
                            Title = name .. " Low HP!",
                            Subtitle = string.format(L("Осталось %d HP", "%d HP remaining"), hp),
                            AccentColor = Config.Colors.Red,
                            IconType = "hero",
                            Icon = "panorama/images/heroes/icons/" .. rawName .. "_png.vtex_c",
                            Duration = 3.2
                        })
                    end
                end
            end
        end
    end
end

function DynamicIsland.OnEntityHurt(data)
    if not data then return end
    local src = data.source
    local tgt = data.target
    if src and tgt and Entity.IsHero(src) and Entity.IsHero(tgt) and not Entity.IsSameTeam(src, tgt) then
        local nowTime = GameRules.GetGameTime()
        local tIdx = Entity.GetIndex(tgt)
        local sIdx = Entity.GetIndex(src)
        if tIdx then FightTracker.LastDamageTimes[tIdx] = nowTime end
        if sIdx then FightTracker.LastDamageTimes[sIdx] = nowTime end
    end
end

function DynamicIsland.OnProjectile(data)
    if not data then return end
    local src = data.source
    local tgt = data.target
    if src and tgt and Entity.IsHero(src) and Entity.IsHero(tgt) and not Entity.IsSameTeam(src, tgt) then
        local nowTime = GameRules.GetGameTime()
        local tIdx = Entity.GetIndex(tgt)
        local sIdx = Entity.GetIndex(src)
        if tIdx then FightTracker.LastDamageTimes[tIdx] = nowTime end
        if sIdx then FightTracker.LastDamageTimes[sIdx] = nowTime end
    end
end

function DynamicIsland.OnModifierCreate(ent, mod)
    if not UI or not UI.Main.Enabled:Get() or not ent or not mod or not Entity.IsNPC(ent) then return end
    local my = HeroData.Local or Heroes.GetLocal()
    if not my then return end
    
    local mn = Modifier.GetName(mod)
    if not mn then return end
    
    local isHero = Entity.IsHero(ent)
    local isEnemy = not Entity.IsSameTeam(my, ent)
    
    if isHero and UI.Runes.RunePickups:Get() then
        local rType = RuneModifierMap[mn]
        if rType then
            local rInfo = RuneInfoList[rType] or { en = "Rune", ru = "Руна", col = Color(255, 220, 0, 255), path = "panorama/images/spellicons/rune_doubledamage_png.vtex_c", svg = "rune_dd" }
            local hName = GetPlayerDisplayName(ent)
            DynamicIsland.PushNotification({
                Type = "rune_pickup",
                Tag = L("ПОДБОР РУНЫ", "RUNE PICKUP"),
                Title = hName,
                Subtitle = L("подобрал ", "picked up ") .. L(rInfo.ru, rInfo.en),
                AccentColor = rInfo.col,
                IconType = "rune",
                Icon = rInfo.path,
                FallbackSvg = rInfo.svg,
                Duration = 3.8
            })
            return
        end
    end
    
    if isHero and isEnemy and UI.Combat.Invis:Get() then
        local d = StrictInvisModifiers[mn]
        if d then
            local heroName = GetPlayerDisplayName(ent)
            DynamicIsland.PushNotification({
                Type = "invis",
                Tag = L("ИНВИЗ ВРАГА", "INVISIBILITY ALERT"),
                Title = heroName .. " — " .. d.name,
                Subtitle = L("Враг ушел в невидимость", "Enemy entered stealth"),
                AccentColor = d.col,
                IconType = "item",
                Icon = d.icon,
                FallbackSvg = "rune_invis",
                Duration = 4.0
            })
            return
        end
    end
    
    if isHero and isEnemy and UI.Combat.Teleports:Get() and mn == "modifier_teleporting" then
        local heroName = GetPlayerDisplayName(ent)
        local targetPos = Entity.GetAbsOrigin(ent)
        local landmark = GetClosestLandmark(targetPos)
        DynamicIsland.PushNotification({
            Type = "teleport",
            Tag = L("ТЕЛЕПОРТ ВРАГА", "TELEPORT WARNING"),
            Title = heroName .. L(" телепортируется", " Teleporting"),
            Subtitle = L("Телепорт к ", "Teleporting to ") .. landmark,
            AccentColor = Color(100, 200, 255, 255),
            IconType = "item",
            Icon = "panorama/images/items/tpscroll_png.vtex_c",
            Duration = 3.8
        })
        return
    end
    
    if isHero and UI.Runes.Roshan:Get() and mn == "modifier_item_aegis" then
        local heroName = GetPlayerDisplayName(ent)
        local accent = isEnemy and Config.Colors.Red or Config.Colors.Accent
        DynamicIsland.PushNotification({
            Type = "aegis",
            Tag = L("АЕГИС ПОДОБРАН", "AEGIS CLAIMED"),
            Title = heroName .. L(" поднял Аегис", " Claimed Aegis"),
            Subtitle = isEnemy and L("Враг получил бессмертие", "Enemy secured immortal") or L("Союзник получил бессмертие", "Ally secured immortal"),
            AccentColor = accent,
            IconType = "item",
            Icon = "panorama/images/items/aegis_png.vtex_c",
            Duration = 4.5
        })
        return
    end
end

function DynamicIsland.OnStartSound(data)
    if not UI or not UI.Main.Enabled:Get() or not UI.Runes.Roshan:Get() or not data or not data.name then return end
    local snd = string.lower(data.name)
    if string.find(snd, "roshan") or string.find(snd, "rosh") then
        local now = GameRules.GetGameTime()
        if now - GameTracker.Roshan.LastAttackAlert > 15.0 then
            GameTracker.Roshan.LastAttackAlert = now
            DynamicIsland.PushNotification({
                Type = "roshan_attack",
                Tag = L("ЛОГОВО РОШАНА", "ROSHAN PIT ALERT"),
                Title = L("Рошан атакован!", "Roshan Under Attack!"),
                Subtitle = L("Звуки битвы в логове", "Combat audio detected in pit"),
                AccentColor = Config.Colors.Red,
                IconType = "item",
                Icon = "panorama/images/items/aegis_png.vtex_c",
                Duration = 4.5
            })
        end
    end
end

function DynamicIsland.OnFireEventClient(data)
    if not UI or not UI.Main.Enabled:Get() or not data or not data.name then return end
    
    if data.name == "dota_buyback" and UI.Combat.Buybacks:Get() then
        local pid = Event.GetInt(data.event, "player_id")
        local pName = L("Игрок", "Player")
        local allPlayers = Players.GetAll()
        for _, pl in ipairs(allPlayers) do
            local pd = Player.GetPlayerData(pl)
            if pd and pd.PlayerID == pid then
                pName = Player.GetName(pl) or pd.PlayerName or L("Враг", "Enemy")
                break
            end
        end
        DynamicIsland.PushNotification({
            Type = "buyback",
            Tag = L("ВЫКУП", "BUYBACK ALERT"),
            Title = pName .. L(" выкупился!", " Bought Back!"),
            Subtitle = L("Герой вернулся в игру", "Hero returned to match"),
            AccentColor = Color(255, 215, 0, 255),
            IconType = "svg",
            FallbackSvg = "buyback",
            Duration = 4.0
        })
        return
    end
    
    if data.name == "dota_roshan_kill" and UI.Runes.Roshan:Get() then
        GameTracker.Roshan.DeathTime = GameRules.GetGameTime()
        GameTracker.Roshan.AegisExpiryTime = GameTracker.Roshan.DeathTime + 300
        GameTracker.Roshan.RespawnMinTime = GameTracker.Roshan.DeathTime + 480
        GameTracker.Roshan.RespawnMaxTime = GameTracker.Roshan.DeathTime + 660
        GameTracker.Roshan.Dismissed = false
        DynamicIsland.PushNotification({
            Type = "roshan_kill",
            Tag = L("РОШАН УБИТ", "ROSHAN SLAIN"),
            Title = L("Рошан убит!", "Roshan Killed!"),
            Subtitle = L("Аегис выпал в логове", "Aegis dropped in pit"),
            AccentColor = Color(255, 60, 60, 255),
            IconType = "item",
            Icon = "panorama/images/items/aegis_png.vtex_c",
            Duration = 4.5
        })
    end
end

function DynamicIsland.OnEntityCreate(ent)
    if not UI or not UI.Main.Enabled:Get() or not UI.Runes.Tormentor:Get() or not ent or not Entity.IsNPC(ent) then return end
    local name = NPC.GetUnitName(ent)
    if name == "npc_dota_miniboss" then
        DynamicIsland.PushNotification({
            Type = "tormentor",
            Tag = L("ТЕРЗАТЕЛЬ", "TORMENTOR SPAWN"),
            Title = L("Терзатель появился!", "Tormentor Spawned!"),
            Subtitle = L("Объект доступен на карте", "Objective available"),
            AccentColor = Color(0, 210, 255, 255),
            IconType = "item",
            Icon = "panorama/images/items/aghanims_shard_png.vtex_c",
            Duration = 4.5
        })
    end
end

function DynamicIsland.OnEntityDestroy(ent)
    if not UI or not UI.Main.Enabled:Get() or not UI.Runes.Tormentor:Get() or not ent or not Entity.IsNPC(ent) then return end
    local name = NPC.GetUnitName(ent)
    if name == "npc_dota_miniboss" then
        DynamicIsland.PushNotification({
            Type = "tormentor",
            Tag = L("ТЕРЗАТЕЛЬ", "TORMENTOR DEFEATED"),
            Title = L("Терзатель повержен!", "Tormentor Defeated!"),
            Subtitle = L("Осколок выдан команде", "Shard granted to team"),
            AccentColor = Color(75, 245, 135, 255),
            IconType = "item",
            Icon = "panorama/images/items/aghanims_shard_png.vtex_c",
            Duration = 4.0
        })
    end
end

local function GetIslandLayout()
    local scr = Render.ScreenSize()
    local scale = (UI and UI.Main and UI.Main.Scale) and (UI.Main.Scale:Get() / 100.0) or 1.0
    local preset = (UI and UI.Main and UI.Main.Preset) and UI.Main.Preset:Get() or 0
    local manualX = (UI and UI.Main and UI.Main.OffsetX) and UI.Main.OffsetX:Get() or 0
    local manualY = (UI and UI.Main and UI.Main.OffsetY) and UI.Main.OffsetY:Get() or 20
    
    local squishOffset = StateMachine.Spring.Squish.value * 2.5 * scale
    local rawW = math.max(60, StateMachine.Spring.W.value * scale)
    local w = math.floor(rawW + 0.5)
    if w % 2 ~= 0 then w = w + 1 end
    local rawH = (StateMachine.Spring.H.value + squishOffset) * scale
    local h = math.floor(math.max(Config.Dimensions.FloorHeight * scale, rawH) + 0.5)
    if h % 2 ~= 0 then h = h + 1 end
    local r = math.floor(math.min(h * 0.5, StateMachine.Spring.Radius.value * scale) + 0.5)
    
    local centerX = scr.x * 0.5 + manualX
    local x = math.floor(centerX - w * 0.5)
    local y = math.floor(manualY)
    
    if preset == 1 and DragState.CustomX >= 0 and DragState.CustomY >= 0 then
        x = math.floor(DragState.CustomX - w * 0.5)
        y = math.floor(DragState.CustomY)
    elseif preset == 2 then
        x = math.floor(32 + manualX)
        y = math.floor(manualY)
    elseif preset == 3 then
        x = math.floor(scr.x - w - 32 + manualX)
        y = math.floor(manualY)
    elseif preset == 4 then
        x = math.floor(centerX - w * 0.5)
        y = math.floor((scr.y - h) * 0.5 + manualY - 20)
    elseif preset == 5 then
        x = math.floor(centerX - w * 0.5)
        y = math.floor(scr.y - h - 35 + manualY - 20)
    end
    
    local res = {
        x = x,
        y = y,
        w = w,
        h = h,
        r = r,
        scale = scale
    }
    if Haptic and Haptic.ApplyTransform then
        Haptic.ApplyTransform(res)
    end
    return res
end

local function GetChipContent(chipId)
    local cfg = HUDCustomizer.WidgetConfigs[chipId] or { bold = false, colorMode = 1, format = 1, showIcon = true }
    local font = cfg.bold and Config.Fonts.Bold or Config.Fonts.Main
    local col = Config.Colors.TextPrimary
    
    if cfg.colorMode == 2 then
        col = Config.Colors.TextSecondary
    elseif cfg.colorMode == 3 then
        if cfg.customColor then
            col = cfg.customColor
        else
            col = GetDefaultWidgetColor(chipId)
        end
    end
    
    local svgKey = (cfg.showIcon ~= false) and chipId or nil
    
    if chipId == "clock" then
        local pat = "%H:%M"
        if cfg.format == 2 then pat = "%I:%M"
        elseif cfg.format == 3 then pat = "%H:%M:%S" end
        return { isClock = false, svgKey = svgKey, text = os.date(pat), font = font, color = col }
    elseif chipId == "kda" then
        local txt = string.format("%d/%d/%d", HeroData.Kills, HeroData.Deaths, HeroData.Assists)
        if cfg.format == 2 then txt = string.format("%d/%d", HeroData.Kills, HeroData.Deaths) end
        return { isClock = false, svgKey = svgKey, text = txt, font = font, color = col }
    elseif chipId == "gold" then
        local txt = string.format("%d", HeroData.Gold)
        if cfg.format == 1 then txt = string.format("%d G", HeroData.Gold)
        elseif cfg.format == 3 then txt = string.format("%.1fk G", HeroData.Gold / 1000.0) end
        return { isClock = false, svgKey = svgKey, text = txt, font = font, color = col }
    elseif chipId == "networth" then
        local txt = HeroData.NetWorth > 0 and string.format("%.1fk NW", HeroData.NetWorth / 1000.0) or string.format("%d NW", HeroData.Gold)
        if cfg.format == 2 then txt = HeroData.NetWorth > 0 and string.format("%.1fk", HeroData.NetWorth / 1000.0) or string.format("%d", HeroData.Gold)
        elseif cfg.format == 3 then txt = string.format("%d NW", HeroData.NetWorth) end
        return { isClock = false, svgKey = svgKey, text = txt, font = font, color = col }
    elseif chipId == "lasthits" then
        local txt = string.format("%d LH", HeroData.LastHits)
        if cfg.format == 2 then txt = string.format("%d", HeroData.LastHits)
        elseif cfg.format == 3 then txt = string.format("%d/%d", HeroData.LastHits, HeroData.Denies) end
        return { isClock = false, svgKey = svgKey, text = txt, font = font, color = col }
    elseif chipId == "heroname" then
        local custom = (UI and UI.Main and UI.Main.CustomLabel) and UI.Main.CustomLabel:Get() or ""
        local nameStr = (custom and custom ~= "") and custom or CleanHeroName(HeroData.HeroName)
        if nameStr == "" then nameStr = L("Герой", "Hero") end
        if cfg.format == 2 then
            nameStr = string.sub(nameStr, 1, 3):upper()
        end
        return { isClock = false, svgKey = svgKey, text = nameStr, font = font, color = col }
    elseif chipId == "fps" then
        local txt = string.format("%d FPS", PerformanceData.FPS)
        if cfg.format == 2 then txt = string.format("%d", PerformanceData.FPS) end
        return { isClock = false, svgKey = svgKey, text = txt, font = font, color = col }
    elseif chipId == "ping" then
        local txt = string.format("%d ms", PerformanceData.Ping)
        if cfg.format == 2 then txt = string.format("%d", PerformanceData.Ping) end
        return { isClock = false, svgKey = svgKey, text = txt, font = font, color = col }
    end
    return { isClock = false, svgKey = nil, text = "Chip", font = font, color = col }
end

local function HasFindingMatchClass(panel)
    local cur = panel
    local depth = 0
    while cur and cur:IsValid() and depth < 6 do
        if cur:HasClass("FindingMatch") then
            return true
        end
        cur = cur:GetParent()
        depth = depth + 1
    end
    return false
end

local function GetMatchSearchInfo()
    if not Panorama or not Panorama.GetPanelByName then
        return false, "0:00"
    end
    
    local isSearching = false
    local p = Panorama.GetPanelByName("SearchingTime")
    if p and p:IsValid() and HasFindingMatchClass(p) then
        isSearching = true
    end
    
    if not isSearching then
        local play = Panorama.GetPanelByName("DOTAPlay", true)
        if play and play:IsValid() and play:HasClass("FindingMatch") then
            isSearching = true
        end
    end
    
    if not isSearching then
        local btn = Panorama.GetPanelByName("PlayButton")
        if btn and btn:IsValid() and btn:HasClass("FindingMatch") then
            isSearching = true
        end
    end
    
    if isSearching then
        local t = p and p:IsValid() and p:GetText() or ""
        if t and t ~= "" then
            return true, t
        end
        return true, "0:00"
    end
    
    return false, "0:00"
end

local function CalculateMenuIdleWidth(scale)
    local fontBold = Config.Fonts.Bold
    local tSize = Render.TextSize(fontBold, 11 * scale, L("island.in_menu", "In Menu"))
    local clockText = os.date("%H:%M")
    local clkSize = Render.TextSize(fontBold, 11 * scale, clockText)
    local iconExtra = (12 + 5) * scale * 2
    local dotExtra = (7 + 1.6 * 2 + 7) * scale
    return iconExtra + tSize.x + dotExtra + clkSize.x
end

local function CalculateMenuSearchingWidth(scale, timeStr)
    local fontBold = Config.Fonts.Bold
    local label = L("island.finding_match", "Finding Match ") .. (timeStr or "0:00")
    local tSize = Render.TextSize(fontBold, 11 * scale, label)
    local clockText = os.date("%H:%M")
    local clkSize = Render.TextSize(fontBold, 11 * scale, clockText)
    local iconExtra = (12 + 5) * scale * 2
    local dotExtra = (7 + 1.6 * 2 + 7) * scale
    return iconExtra + tSize.x + dotExtra + clkSize.x
end

local function CalculateMenuMatchFoundWidth(scale)
    local fontBold = Config.Fonts.Bold
    local tSize = Render.TextSize(fontBold, 11.5 * scale, L("island.match_found", "Match Found!"))
    local iconExtra = (13 + 6) * scale
    return iconExtra + tSize.x
end

local function GetChipStandardWidth(chipId, scale)
    local cfg = HUDCustomizer.WidgetConfigs[chipId] or { showIcon = true }
    local iconW = (cfg.showIcon ~= false) and (18 * scale) or 0
    local c = GetChipContent(chipId)
    local tSize = Render.TextSize(c.font, 11 * scale, c.text)
    return math.ceil(iconW + tSize.x)
end

local function CalculateIdleContentWidth(scale)
    local totalW = 0
    local count = #HUDCustomizer.ActiveChips
    for idx, id in ipairs(HUDCustomizer.ActiveChips) do
        local chipW = GetChipStandardWidth(id, scale)
        totalW = totalW + chipW
        if idx < count then
            totalW = totalW + 12 * scale
        end
    end
    return totalW
end

local function IsChipInActiveList(chipId)
    for _, id in ipairs(HUDCustomizer.ActiveChips) do
        if id == chipId then return true end
    end
    return false
end

local function ChipAnim(chipId)
    local a = HUDCustomizer.Anim.Chips[chipId]
    if not a then
        a = { fill = IsChipInActiveList(chipId) and 1 or 0, fillVel = 0, scale = 1, scaleVel = 0 }
        HUDCustomizer.Anim.Chips[chipId] = a
    end
    return a
end

local function ToggleChipInActiveList(chipId)
    local foundIdx = nil
    for idx, id in ipairs(HUDCustomizer.ActiveChips) do
        if id == chipId then
            foundIdx = idx
            break
        end
    end
    if foundIdx then
        if #HUDCustomizer.ActiveChips > 1 then
            table.remove(HUDCustomizer.ActiveChips, foundIdx)
            if HUDCustomizer.InspectedChip == chipId then
                HUDCustomizer.InspectedChip = nil
            end
        end
    else
        table.insert(HUDCustomizer.ActiveChips, chipId)
    end
    local a = ChipAnim(chipId)
    a.scale, a.scaleVel = 0.86, -2.2
    SaveAllConfig()
end

local function GetFountainPosition(hero, courier)
    if CourierTracker.BasePos then
        return CourierTracker.BasePos
    end
    if courier and Entity.IsAlive(courier) then
        local cState = Courier.GetCourierState and Courier.GetCourierState(courier) or 0
        if cState == Enum.CourierState.COURIER_STATE_AT_BASE or cState == 1 then
            local pos = Entity.GetAbsOrigin(courier)
            if pos then
                CourierTracker.BasePos = pos
                return pos
            end
        end
    end
    local myHero = hero or HeroData.Local or (Heroes and Heroes.GetLocal and Heroes.GetLocal())
    local team = myHero and Entity.GetTeamNum(myHero) or 2
    if team == 2 or (Enum.TeamNum and team == Enum.TeamNum.TEAM_RADIANT) then
        return Vector(-7200, -6700, 384)
    else
        return Vector(7100, 6500, 384)
    end
end

local function GetLocalCourier()
    if Couriers and Couriers.GetLocal then
        local ok, c = pcall(Couriers.GetLocal)
        if ok and c and Entity.IsAlive(c) then
            CourierTracker.CachedCourier = c
            return c
        end
    end
    local myHero = HeroData.Local or (Heroes and Heroes.GetLocal and Heroes.GetLocal())
    if Couriers and Couriers.GetAll and myHero then
        local myTeam = Entity.GetTeamNum(myHero)
        local myPlayerID = Hero.GetPlayerID and Hero.GetPlayerID(myHero)
        if not myPlayerID and Players and Players.GetLocal and Player and Player.GetPlayerID then
            local lp = Players.GetLocal()
            if lp then myPlayerID = Player.GetPlayerID(lp) end
        end
        local ok, list = pcall(Couriers.GetAll)
        if ok and list then
            for _, c in ipairs(list) do
                if c and Entity.IsAlive(c) then
                    local pid = (Courier and Courier.GetPlayerID) and Courier.GetPlayerID(c) or nil
                    if myPlayerID and pid and pid == myPlayerID then
                        CourierTracker.CachedCourier = c
                        return c
                    end
                end
            end
            for _, c in ipairs(list) do
                if c and Entity.IsAlive(c) then
                    if myTeam and Entity.GetTeamNum(c) == myTeam then
                        CourierTracker.CachedCourier = c
                        return c
                    end
                end
            end
            for _, c in ipairs(list) do
                if c and Entity.IsAlive(c) then
                    CourierTracker.CachedCourier = c
                    return c
                end
            end
        end
    end
    if CourierTracker.CachedCourier and Entity.IsAlive(CourierTracker.CachedCourier) then
        return CourierTracker.CachedCourier
    end
    return nil
end

local function ProcessPauseTracker()
    local paused = GameRules.IsPaused and GameRules.IsPaused() or false
    if paused then
        if not PauseTracker.IsPaused then
            PauseTracker.IsPaused = true
            PauseTracker.PauseStartTime = os.clock()
        end
    else
        if PauseTracker.IsPaused then
            PauseTracker.IsPaused = false
            PauseTracker.PauseStartTime = 0
        end
    end
end

function DynamicIsland.OnPrepareUnitOrders(data)
    if HUDCustomizer.IsOpen and Menu.Opened and Menu.Opened() then
        return false
    end
    if data then
        if data.ability then
            local abName = Ability.GetName(data.ability)
            if abName and (abName == "courier_take_stash_and_transfer_items" or abName == "courier_transfer_items" or abName == "courier_take_stash_items") then
                local nowClk = os.clock()
                CourierTracker.DeliveryOrderedTime = nowClk
                CourierTracker.Delivering = true
                CourierTracker.Delivered = false
                CourierTracker.Progress = 0.0
                local c = GetLocalCourier()
                local myHero = HeroData.Local or (Heroes and Heroes.GetLocal and Heroes.GetLocal())
                local dist = 1000
                if c and myHero then
                    local cO = Entity.GetAbsOrigin(c)
                    local hO = Entity.GetAbsOrigin(myHero)
                    local basePos = GetFountainPosition(myHero, c)
                    local cState = Courier.GetCourierState and Courier.GetCourierState(c) or 0
                    local isAtBase = (cState == Enum.CourierState.COURIER_STATE_AT_BASE or cState == 1)
                    local hasStash = false
                    for i = 9, 14 do
                        local it = NPC.GetItemByIndex(myHero, i)
                        if it then
                            local n = Ability.GetName(it)
                            if n and n ~= "" then hasStash = true break end
                        end
                    end
                    local hasCourierItems = false
                    for i = 0, 8 do
                        local it = NPC.GetItemByIndex(c, i)
                        if it then
                            local n = Ability.GetName(it)
                            if n and n ~= "" then hasCourierItems = true break end
                        end
                    end
                    local needsStash = hasStash or (not hasCourierItems)
                    if cO and hO then
                        if not isAtBase and basePos and needsStash and (abName ~= "courier_transfer_items") then
                            local dBase = (cO - basePos):Length()
                            local dHero = (basePos - hO):Length()
                            dist = dBase + dHero
                            CourierTracker.IsGoingToStash = true
                        else
                            dist = (cO - hO):Length()
                            CourierTracker.IsGoingToStash = false
                        end
                    end
                end
                CourierTracker.StartDistance = math.max(dist, 500)
                if StateMachine.TargetState ~= StateMachine.States.COURIER_DELIVERY and StateMachine.TargetState ~= StateMachine.States.COURIER_LARGE then
                    TriggerStateTransition(StateMachine.States.COURIER_DELIVERY)
                end
            elseif abName and (abName == "courier_return_to_base" or abName == "courier_go_to_secretshop") then
                if CourierTracker.Delivering then
                    CourierTracker.Delivering = false
                    CourierTracker.Delivered = false
                    CourierTracker.DeliveryOrderedTime = 0
                    CourierTracker.StartDistance = 0
                    CourierTracker.Progress = 0.0
                    CourierTracker.IsGoingToStash = false
                end
            end
        end
        if data.npc and Entity.IsAlive(data.npc) and Courier and Courier.IsFlyingCourier then
            local isCourierUnit = false
            if Couriers and Couriers.Contains and Couriers.Contains(data.npc) then
                isCourierUnit = true
            elseif NPC.GetUnitName(data.npc) and string.find(NPC.GetUnitName(data.npc), "courier") then
                isCourierUnit = true
            end
            if isCourierUnit then
                local myHero = HeroData.Local or (Heroes and Heroes.GetLocal and Heroes.GetLocal())
                if data.target and myHero and data.target == myHero and data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET then
                    local nowClk = os.clock()
                    CourierTracker.DeliveryOrderedTime = nowClk
                    CourierTracker.Delivering = true
                    CourierTracker.Delivered = false
                    CourierTracker.Progress = 0.0
                    CourierTracker.IsGoingToStash = false
                    local cO = Entity.GetAbsOrigin(data.npc)
                    local hO = Entity.GetAbsOrigin(myHero)
                    local dist = (cO and hO) and (cO - hO):Length() or 1000
                    CourierTracker.StartDistance = math.max(dist, 500)
                    if StateMachine.TargetState ~= StateMachine.States.COURIER_DELIVERY and StateMachine.TargetState ~= StateMachine.States.COURIER_LARGE then
                        TriggerStateTransition(StateMachine.States.COURIER_DELIVERY)
                    end
                elseif data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_STOP or data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION then
                    if CourierTracker.Delivering then
                        CourierTracker.Delivering = false
                        CourierTracker.Delivered = false
                        CourierTracker.DeliveryOrderedTime = 0
                        CourierTracker.StartDistance = 0
                        CourierTracker.Progress = 0.0
                        CourierTracker.IsGoingToStash = false
                    end
                end
            end
        end
        if data.npc and data.target and Entity.IsHero(data.npc) and Entity.IsHero(data.target) and not Entity.IsSameTeam(data.npc, data.target) then
            local order = data.order
            if order == Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET or order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET then
                local nowTime = GameRules.GetGameTime()
                local nIdx = Entity.GetIndex(data.npc)
                local tIdx = Entity.GetIndex(data.target)
                if nIdx then FightTracker.LastDamageTimes[nIdx] = nowTime end
                if tIdx then FightTracker.LastDamageTimes[tIdx] = nowTime end
            end
        end
    end
    return true
end

local function ProcessCourierTracker()
    local isEnabled = true
    if UI and UI.Combat and UI.Combat.CourierDelivery then
        isEnabled = UI.Combat.CourierDelivery:Get()
    end
    if not isEnabled then
        CourierTracker.Delivering = false
        CourierTracker.Delivered = false
        CourierTracker.IsGoingToStash = false
        return
    end

    local nowClk = os.clock()

    if CourierTracker.Delivered then
        if (nowClk - CourierTracker.DeliveredStartTime) > CourierTracker.DeliveredDuration then
            CourierTracker.Delivered = false
            CourierTracker.IsGoingToStash = false
            if StateMachine.TargetState == StateMachine.States.COURIER_DELIVERED then
                local mediaActive = (MediaData.IsPlaying or (MediaData.LastPauseTime > 0 and (nowClk - MediaData.LastPauseTime) <= 6.0)) and (MediaData.Title ~= "")
                local desired = (mediaActive and not HUDCustomizer.IsOpen) and StateMachine.States.COMPACT_MEDIA or StateMachine.States.COMPACT_IDLE
                TriggerStateTransition(desired)
            end
        end
    end

    local c = GetLocalCourier()
    if not c or not Entity.IsAlive(c) then
        return
    end

    local cState = Courier.GetCourierState and Courier.GetCourierState(c) or 0
    local cTarget = Courier.GetCourierStateEntity and Courier.GetCourierStateEntity(c) or nil
    local myHero = HeroData.Local or (Heroes and Heroes.GetLocal and Heroes.GetLocal())

    if cState == Enum.CourierState.COURIER_STATE_AT_BASE or cState == 1 then
        local cO = Entity.GetAbsOrigin(c)
        if cO then
            CourierTracker.BasePos = cO
        end
    end

    local isTargetMe = false
    if myHero then
        if not cTarget then
            isTargetMe = true
        else
            if cTarget == myHero then
                isTargetMe = true
            elseif Entity and Entity.GetIndex then
                local tIdx = Entity.GetIndex(cTarget)
                local mIdx = Entity.GetIndex(myHero)
                if tIdx and mIdx and tIdx == mIdx then
                    isTargetMe = true
                end
            end
        end
    end

    local cOrigin = Entity.GetAbsOrigin(c)
    local hOrigin = myHero and Entity.GetAbsOrigin(myHero)
    local basePos = GetFountainPosition(myHero, c)
    local distHero = (cOrigin and hOrigin) and (cOrigin - hOrigin):Length() or 0
    local distBase = (cOrigin and basePos) and (cOrigin - basePos):Length() or 0
    local distBaseToHero = (basePos and hOrigin) and (basePos - hOrigin):Length() or 0
    local speed = NPC.GetMoveSpeed(c) or 380
    if speed <= 0 then speed = 380 end

    local hasStashItems = false
    local stashItems = {}
    if myHero then
        for i = 9, 14 do
            local it = NPC.GetItemByIndex(myHero, i)
            if it then
                local name = Ability.GetName(it)
                if name and name ~= "" then
                    hasStashItems = true
                    table.insert(stashItems, {
                        name = name,
                        icon = GetItemTexturePath(name)
                    })
                end
            end
        end
    end

    local items = {}
    local itemCount = 0
    for i = 0, 8 do
        local it = NPC.GetItemByIndex(c, i)
        if it then
            local name = Ability.GetName(it)
            if name and name ~= "" then
                itemCount = itemCount + 1
                table.insert(items, {
                    name = name,
                    icon = GetItemTexturePath(name)
                })
            end
        end
    end

    if itemCount > 0 then
        CourierTracker.Inventory = items
    elseif hasStashItems and #stashItems > 0 then
        CourierTracker.Inventory = stashItems
    else
        CourierTracker.Inventory = items
    end

    CourierTracker.Hp = Entity.GetHealth(c) or 0
    CourierTracker.MaxHp = Entity.GetMaxHealth(c) or 1
    CourierTracker.HpPercent = math.max(0, math.min(1.0, CourierTracker.Hp / math.max(1, CourierTracker.MaxHp)))
    CourierTracker.Speed = speed
    CourierTracker.CurrentDistance = distHero

    local isDead = (cState == Enum.CourierState.COURIER_STATE_DEAD or cState == 5)
    local isDeliveringState = (cState == Enum.CourierState.COURIER_STATE_DELIVERING_ITEMS or cState == 3)
    local isMovingState = (cState == Enum.CourierState.COURIER_STATE_MOVING or cState == 2)
    local isReturningState = (cState == Enum.CourierState.COURIER_STATE_RETURNING_TO_BASE or cState == 4)
    local isAtBaseState = (cState == Enum.CourierState.COURIER_STATE_AT_BASE or cState == 1)

    if not CourierTracker.Delivering and not CourierTracker.Delivered and not isDead then
        if isDeliveringState or (isMovingState and isTargetMe and distHero > 450) then
            CourierTracker.Delivering = true
            CourierTracker.DeliveryOrderedTime = nowClk
            CourierTracker.IsGoingToStash = false
            CourierTracker.StartDistance = math.max(distHero, 500)
            CourierTracker.Progress = 0.0
            if StateMachine.TargetState ~= StateMachine.States.COURIER_DELIVERY and StateMachine.TargetState ~= StateMachine.States.COURIER_LARGE then
                TriggerStateTransition(StateMachine.States.COURIER_DELIVERY)
            end
        end
    end

    if CourierTracker.Delivering then
        if isDeliveringState or (isMovingState and isTargetMe and not isReturningState and distHero > 450) then
            CourierTracker.IsGoingToStash = false
        elseif isReturningState and (hasStashItems or itemCount == 0) then
            CourierTracker.IsGoingToStash = true
        end

        local remainingDist = distHero
        if CourierTracker.IsGoingToStash then
            remainingDist = distBase + distBaseToHero
        else
            remainingDist = distHero
        end

        if remainingDist > CourierTracker.StartDistance then
            CourierTracker.StartDistance = remainingDist
        end

        local prog = 1.0 - (remainingDist / math.max(1, CourierTracker.StartDistance))
        local clampedProg = math.max(0.0, math.min(1.0, prog))
        CourierTracker.Progress = math.max(CourierTracker.Progress, clampedProg)
        CourierTracker.ETA = math.ceil(remainingDist / math.max(100, speed))

        if isDead or (myHero and not Entity.IsAlive(myHero)) then
            CourierTracker.Delivering = false
            CourierTracker.DeliveryOrderedTime = 0
            CourierTracker.StartDistance = 0
            CourierTracker.Progress = 0.0
            CourierTracker.IsGoingToStash = false
        elseif not CourierTracker.IsGoingToStash and distHero <= 450 and (nowClk - CourierTracker.DeliveryOrderedTime > 1.0) then
            CourierTracker.Delivering = false
            CourierTracker.DeliveryOrderedTime = 0
            CourierTracker.StartDistance = 0
            CourierTracker.Progress = 1.0
            CourierTracker.Delivered = true
            CourierTracker.DeliveredStartTime = nowClk
            CourierTracker.IsGoingToStash = false
            if Haptic and Haptic.Trigger then
                Haptic.Trigger(Haptic.Types.SUCCESS_APPLE_PAY)
            end
            if StateMachine.TargetState ~= StateMachine.States.COURIER_DELIVERED then
                TriggerStateTransition(StateMachine.States.COURIER_DELIVERED)
            end
        elseif isReturningState and not CourierTracker.IsGoingToStash and (nowClk - CourierTracker.DeliveryOrderedTime > 4.0) and distHero > 800 then
            CourierTracker.Delivering = false
            CourierTracker.DeliveryOrderedTime = 0
            CourierTracker.StartDistance = 0
            CourierTracker.Progress = 0.0
            CourierTracker.IsGoingToStash = false
        elseif isReturningState and not hasStashItems and itemCount == 0 and (nowClk - CourierTracker.DeliveryOrderedTime > 3.5) then
            CourierTracker.Delivering = false
            CourierTracker.DeliveryOrderedTime = 0
            CourierTracker.StartDistance = 0
            CourierTracker.Progress = 0.0
            CourierTracker.IsGoingToStash = false
        elseif CourierTracker.IsGoingToStash and isAtBaseState and not hasStashItems and itemCount == 0 and (nowClk - CourierTracker.DeliveryOrderedTime > 3.0) then
            CourierTracker.Delivering = false
            CourierTracker.DeliveryOrderedTime = 0
            CourierTracker.StartDistance = 0
            CourierTracker.Progress = 0.0
            CourierTracker.IsGoingToStash = false
        elseif (nowClk - CourierTracker.DeliveryOrderedTime > 120.0) then
            CourierTracker.Delivering = false
            CourierTracker.DeliveryOrderedTime = 0
            CourierTracker.StartDistance = 0
            CourierTracker.Progress = 0.0
            CourierTracker.IsGoingToStash = false
        end
    end
end

function DynamicIsland.OnKeyEvent(data)
    if HUDCustomizer.IsOpen and Menu.Opened and Menu.Opened() then
        if data.key == Enum.ButtonCode.KEY_MOUSE1 or data.key == Enum.ButtonCode.KEY_MOUSE2 or data.key == Enum.ButtonCode.MOUSE_LEFT or data.key == Enum.ButtonCode.MOUSE_RIGHT then
            return false
        end
    end
    
    local isUp = (data.key == Enum.ButtonCode.KEY_MWHEELUP or data.key == 124 or data.event == Enum.EKeyEvent.EKeyEvent_SCROLL_UP or data.event == 1)
    local isDown = (data.key == Enum.ButtonCode.KEY_MWHEELDOWN or data.key == 125 or data.event == Enum.EKeyEvent.EKeyEvent_SCROLL_DOWN or data.event == 0)
    
    if isUp or isDown then
        if not IsMediaActive() then
            return true
        end
        local layout = GetIslandLayout()
        if layout and layout.w > 0 and layout.h > 0 then
            local cx, cy = Input.GetCursorPos()
            local pad = 12
            if cx >= (layout.x - pad) and cx <= (layout.x + layout.w + pad) and
               cy >= (layout.y - pad) and cy <= (layout.y + layout.h + pad) then
                local nowClk = os.clock()
                if isUp then
                    if VolumeState.Target >= 100 then
                        VolumeState.Overstretch = math.min(10, (VolumeState.Overstretch or 0) + 2.5)
                        if (nowClk - (VolumeState.LastBumpTime or 0)) >= 0.20 then
                            VolumeState.LastBumpTime = nowClk
                            SendMediaCommand("volup?bump=1")
                            if Haptic and Haptic.Trigger then
                                Haptic.Trigger(Haptic.Types.BOUNDARY_BUMP, 1)
                            end
                        end
                    else
                        VolumeState.Target = math.min(100, VolumeState.Target + 4)
                        if (nowClk - (VolumeState.LastSoundTime or 0)) >= 0.038 then
                            VolumeState.LastSoundTime = nowClk
                            SendMediaCommand("volup")
                            if Haptic and Haptic.Trigger then
                                Haptic.Trigger(Haptic.Types.RATCHET_NOTCH, 1, VolumeState.Target)
                            end
                        else
                            SendMediaCommand("volup?nosound=1")
                        end
                    end
                else
                    if VolumeState.Target <= 0 then
                        VolumeState.Overstretch = math.max(-10, (VolumeState.Overstretch or 0) - 2.5)
                        if (nowClk - (VolumeState.LastBumpTime or 0)) >= 0.20 then
                            VolumeState.LastBumpTime = nowClk
                            SendMediaCommand("voldown?bump=1")
                            if Haptic and Haptic.Trigger then
                                Haptic.Trigger(Haptic.Types.BOUNDARY_BUMP, -1)
                            end
                        end
                    else
                        VolumeState.Target = math.max(0, VolumeState.Target - 4)
                        if (nowClk - (VolumeState.LastSoundTime or 0)) >= 0.038 then
                            VolumeState.LastSoundTime = nowClk
                            SendMediaCommand("voldown")
                            if Haptic and Haptic.Trigger then
                                Haptic.Trigger(Haptic.Types.RATCHET_NOTCH, -1, VolumeState.Target)
                            end
                        else
                            SendMediaCommand("voldown?nosound=1")
                        end
                    end
                end
                MouseInput.LastKeyEventWheelTime = nowClk
                VolumeState.LastActive = nowClk
                VolumeState.Visible = true
                return false
            end
        end
    end
    
    return true
end

local function HandleInteractions()
    if not UI or not UI.Main.Enabled:Get() then return end
    
    local nowClk = os.clock()
    local mediaActive = IsMediaActive()
    local inCombat = FightTracker.Active

    local isLMouseDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) or Input.IsKeyDown(Enum.ButtonCode.MOUSE_LEFT)
    local isRMouseDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE2) or Input.IsKeyDown(Enum.ButtonCode.MOUSE_RIGHT)
    local isLeftClicked = isLMouseDown and not MouseInput.LeftPressed
    local isRightClicked = isRMouseDown and not MouseInput.RightPressed

    MouseInput.LeftPressed = isLMouseDown
    MouseInput.RightPressed = isRMouseDown

    local cx, cy = Input.GetCursorPos()

    local isWheelUp = Input.IsKeyDown(Enum.ButtonCode.KEY_MWHEELUP) or Input.IsKeyDown(124)
    local isWheelDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MWHEELDOWN) or Input.IsKeyDown(125)


    if NotificationQueue.Active then
        local elapsed = nowClk - NotificationQueue.StartTime
        if elapsed >= NotificationQueue.Active.Duration then
            NotificationQueue.LastDismissed = NotificationQueue.Active
            NotificationQueue.Active = nil
            if #NotificationQueue.List > 0 then
                NotificationQueue.Active = table.remove(NotificationQueue.List, 1)
                NotificationQueue.StartTime = nowClk
                TriggerStateTransition(StateMachine.States.NOTIFICATION)
            else
                local target = inCombat and StateMachine.States.COMPACT_FIGHT or (mediaActive and StateMachine.States.COMPACT_MEDIA or StateMachine.States.COMPACT_IDLE)
                TriggerStateTransition(target)
            end
        else
            if StateMachine.TargetState ~= StateMachine.States.NOTIFICATION then
                TriggerStateTransition(StateMachine.States.NOTIFICATION)
            end
        end
    elseif #NotificationQueue.List > 0 then
        NotificationQueue.Active = table.remove(NotificationQueue.List, 1)
        NotificationQueue.StartTime = nowClk
        TriggerStateTransition(StateMachine.States.NOTIFICATION)
    end
    
    local isMenuOpen = Menu.Opened and Menu.Opened()
    if not isMenuOpen and HUDCustomizer.IsOpen then
        HUDCustomizer.IsOpen = false
        HUDCustomizer.InspectedChip = nil
    end
    
    local isCtrlOnly = Input.IsKeyDown(Enum.ButtonCode.KEY_LCONTROL) or Input.IsKeyDown(Enum.ButtonCode.KEY_RCONTROL)
    local layout = GetIslandLayout()
    
    local padHit = 6
    local isHover = (cx >= layout.x - padHit and cx <= layout.x + layout.w + padHit and cy >= layout.y - padHit and cy <= layout.y + layout.h + padHit)
    
    if isHover and IsMediaActive() then
        if (nowClk - (MouseInput.LastKeyEventWheelTime or 0)) > 0.15 then
            if isWheelUp and not MouseInput.LastWheelUp then
                if VolumeState.Target >= 100 then
                    VolumeState.Overstretch = math.min(10, (VolumeState.Overstretch or 0) + 2.5)
                    if (nowClk - (VolumeState.LastBumpTime or 0)) >= 0.20 then
                        VolumeState.LastBumpTime = nowClk
                        SendMediaCommand("volup?bump=1")
                        if Haptic and Haptic.Trigger then
                            Haptic.Trigger(Haptic.Types.BOUNDARY_BUMP, 1)
                        end
                    end
                else
                    VolumeState.Target = math.min(100, VolumeState.Target + 4)
                    if (nowClk - (VolumeState.LastSoundTime or 0)) >= 0.038 then
                        VolumeState.LastSoundTime = nowClk
                        SendMediaCommand("volup")
                        if Haptic and Haptic.Trigger then
                            Haptic.Trigger(Haptic.Types.RATCHET_NOTCH, 1, VolumeState.Target)
                        end
                    else
                        SendMediaCommand("volup?nosound=1")
                    end
                end
                VolumeState.LastActive = nowClk
                VolumeState.Visible = true
            end
            if isWheelDown and not MouseInput.LastWheelDown then
                if VolumeState.Target <= 0 then
                    VolumeState.Overstretch = math.max(-10, (VolumeState.Overstretch or 0) - 2.5)
                    if (nowClk - (VolumeState.LastBumpTime or 0)) >= 0.20 then
                        VolumeState.LastBumpTime = nowClk
                        SendMediaCommand("voldown?bump=1")
                        if Haptic and Haptic.Trigger then
                            Haptic.Trigger(Haptic.Types.BOUNDARY_BUMP, -1)
                        end
                    end
                else
                    VolumeState.Target = math.max(0, VolumeState.Target - 4)
                    if (nowClk - (VolumeState.LastSoundTime or 0)) >= 0.038 then
                        VolumeState.LastSoundTime = nowClk
                        SendMediaCommand("voldown")
                        if Haptic and Haptic.Trigger then
                            Haptic.Trigger(Haptic.Types.RATCHET_NOTCH, -1, VolumeState.Target)
                        end
                    else
                        SendMediaCommand("voldown?nosound=1")
                    end
                end
                VolumeState.LastActive = nowClk
                VolumeState.Visible = true
            end
        end
    end
    MouseInput.LastWheelUp = isWheelUp
    MouseInput.LastWheelDown = isWheelDown
    
    local isHoverSatellite = false
    if SatelliteBounds and cx >= SatelliteBounds.x1 and cx <= SatelliteBounds.x2 and cy >= SatelliteBounds.y1 and cy <= SatelliteBounds.y2 then
        isHoverSatellite = true
    end
    FightTracker.SatelliteHover = isHoverSatellite
    
    if isMenuOpen and isCtrlOnly then
        if isHover and isLMouseDown and not DragState.IsDragging then
            DragState.IsDragging = true
            DragState.OffsetX = cx - (layout.x + layout.w / 2)
            DragState.OffsetY = cy - layout.y
        end
    end
    
    if DragState.IsDragging then
        if not isLMouseDown or not isMenuOpen then
            DragState.IsDragging = false
            SaveAllConfig()
        else
            local gridSize = (DragState.GridSize) or 16
            local rawX = cx - DragState.OffsetX
            local rawY = cy - DragState.OffsetY
            DragState.CustomX = math.floor((rawX + gridSize / 2) / gridSize) * gridSize
            DragState.CustomY = math.floor((rawY + gridSize / 2) / gridSize) * gridSize
            if UI.Main.Preset:Get() ~= 1 then
                UI.Main.Preset:Set(1)
            end
            local target = inCombat and StateMachine.States.COMPACT_FIGHT or (mediaActive and StateMachine.States.COMPACT_MEDIA or StateMachine.States.COMPACT_IDLE)
            TriggerStateTransition(target)
        end
    end
    
    if isLeftClicked and isHoverSatellite then
        if inCombat then
            if ButtonHits.SatellitePrev and cx >= ButtonHits.SatellitePrev.x1 and cx <= ButtonHits.SatellitePrev.x2 and cy >= ButtonHits.SatellitePrev.y1 and cy <= ButtonHits.SatellitePrev.y2 then
                SendMediaCommand("prev")
                ButtonSprings.SatellitePrev.scale = 0.72
                ButtonSprings.SatellitePrev.vel = -2.5
                if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_MEDIUM) end
                return
            elseif ButtonHits.SatellitePlay and cx >= ButtonHits.SatellitePlay.x1 and cx <= ButtonHits.SatellitePlay.x2 and cy >= ButtonHits.SatellitePlay.y1 and cy <= ButtonHits.SatellitePlay.y2 then
                local nowClk = os.clock()
                MediaData.LastManualToggle = nowClk
                if MediaData.IsPlaying then
                    MediaData.IsPlaying = false
                    MediaData.LastPauseTime = nowClk
                    MediaData.RealBars = { 0, 0, 0, 0, 0 }
                else
                    MediaData.IsPlaying = true
                    MediaData.LastPlayTime = nowClk
                    MediaData.LastPauseTime = 0
                end
                SendMediaCommand("playpause")
                ButtonSprings.SatellitePlay.scale = 0.72
                ButtonSprings.SatellitePlay.vel = -2.5
                if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_MEDIUM) end
                return
            elseif ButtonHits.SatelliteNext and cx >= ButtonHits.SatelliteNext.x1 and cx <= ButtonHits.SatelliteNext.x2 and cy >= ButtonHits.SatelliteNext.y1 and cy <= ButtonHits.SatelliteNext.y2 then
                SendMediaCommand("next")
                ButtonSprings.SatelliteNext.scale = 0.72
                ButtonSprings.SatelliteNext.vel = -2.5
                if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_MEDIUM) end
                return
            end
        else
            GameTracker.Roshan.Dismissed = true
        end
        return
    end
    
    if isLeftClicked and isHover and StateMachine.TargetState == StateMachine.States.NOTIFICATION and not isCtrlOnly then
        NotificationQueue.LastDismissed = NotificationQueue.Active
        NotificationQueue.Active = nil
        HapticPlaySound("toast_dismiss", 0.45)
        if StateMachine.Spring and StateMachine.Spring.Squish then
            StateMachine.Spring.Squish.value = -0.32
            StateMachine.Spring.Squish.vel = -2.2
        end
        if Haptic and Haptic.State then
            Haptic.State.GlowAlpha = 70
            Haptic.State.GlowColor = Color(255, 255, 255, 255)
        end
        if #NotificationQueue.List > 0 then
            NotificationQueue.Active = table.remove(NotificationQueue.List, 1)
            NotificationQueue.StartTime = nowClk
            TriggerStateTransition(StateMachine.States.NOTIFICATION)
        else
            local target = inCombat and StateMachine.States.COMPACT_FIGHT or (mediaActive and StateMachine.States.COMPACT_MEDIA or StateMachine.States.COMPACT_IDLE)
            TriggerStateTransition(target)
        end
        return
    end
    
    if isMenuOpen and isRightClicked then
        if isHover then
            HUDCustomizer.IsOpen = not HUDCustomizer.IsOpen
            HUDCustomizer.InspectedChip = nil
            local target = inCombat and StateMachine.States.COMPACT_FIGHT or (mediaActive and StateMachine.States.COMPACT_MEDIA or StateMachine.States.COMPACT_IDLE)
            TriggerStateTransition(target)
            if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_MEDIUM) end
        elseif HUDCustomizer.IsOpen then
            local clickedDrawerChip = false
            for _, b in ipairs(HUDCustomizer.DrawerBounds) do
                if cx >= b.x1 and cx <= b.x2 and cy >= b.y1 and cy <= b.y2 then
                    HUDCustomizer.InspectedChip = (HUDCustomizer.InspectedChip == b.id) and nil or b.id
                    clickedDrawerChip = true
                    if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
                    break
                end
            end
            if not clickedDrawerChip then
                HUDCustomizer.IsOpen = false
                HUDCustomizer.InspectedChip = nil
                if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
            end
        end
    elseif isMenuOpen and HUDCustomizer.IsOpen and isLeftClicked then
        local clickedInspector = false
        for _, b in ipairs(HUDCustomizer.InspectorBounds) do
            if cx >= b.x1 and cx <= b.x2 and cy >= b.y1 and cy <= b.y2 then
                local id = HUDCustomizer.InspectedChip
                local cfg = HUDCustomizer.WidgetConfigs[id]
                if cfg and b.action == "set_bold" then
                    cfg.bold = (b.val == 1)
                    SaveAllConfig()
                    if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_MEDIUM) end
                elseif cfg and b.action == "set_color" then
                    cfg.colorMode = b.val
                    if b.val == 3 and not cfg.customColor then
                        local dCol, dHex = GetDefaultWidgetColor(id)
                        cfg.customColor = dCol
                        cfg.customHex = dHex
                    end
                    if b.val ~= 3 then
                        HUDCustomizer.ColorPickerOpen = false
                    end
                    SaveAllConfig()
                    if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_MEDIUM) end
                elseif b.action == "toggle_color_picker" then
                    HUDCustomizer.ColorPickerOpen = not HUDCustomizer.ColorPickerOpen
                    if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
                elseif b.action == "close_color_picker" then
                    HUDCustomizer.ColorPickerOpen = false
                    SaveAllConfig()
                    if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
                elseif cfg and b.action == "drag_hue" then
                    HUDCustomizer.DraggingHue = { barX = b.barX, barW = b.barW, id = id }
                    local frac = math.min(1, math.max(0, (cx - b.barX) / b.barW))
                    local h = frac * 360
                    local curCol = cfg.customColor or GetDefaultWidgetColor(id)
                    local _, curSat, curVal = RGBtoHSV(curCol.r, curCol.g, curCol.b)
                    if curSat < 0.15 then curSat = 0.85 end
                    if curVal < 0.25 then curVal = 1.0 end
                    local hr, hg, hb = HSVtoRGB(h, curSat, curVal)
                    cfg.colorMode = 3
                    cfg.customColor = Color(hr, hg, hb, 255)
                    cfg.customHex = string.format("%02X%02X%02X", hr, hg, hb)
                    SaveAllConfig()
                    if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
                elseif cfg and b.action == "drag_pop_sv" then
                    HUDCustomizer.DraggingPopSV = { x = b.x, y = b.y, w = b.w, h = b.h, id = b.id }
                    local curCol = cfg.customColor or GetDefaultWidgetColor(b.id)
                    local curHue = RGBtoHue(curCol.r, curCol.g, curCol.b)
                    local s = math.min(1, math.max(0, (cx - b.x) / b.w))
                    local v = math.min(1, math.max(0, 1.0 - (cy - b.y) / b.h))
                    local hr, hg, hb = HSVtoRGB(curHue, s, v)
                    cfg.colorMode = 3
                    cfg.customColor = Color(hr, hg, hb, 255)
                    cfg.customHex = string.format("%02X%02X%02X", hr, hg, hb)
                    SaveAllConfig()
                elseif cfg and b.action == "drag_pop_hue" then
                    HUDCustomizer.DraggingPopHue = { x = b.x, w = b.w, id = b.id }
                    local h = math.min(1, math.max(0, (cx - b.x) / b.w)) * 360
                    local curCol = cfg.customColor or GetDefaultWidgetColor(b.id)
                    local _, curSat, curVal = RGBtoHSV(curCol.r, curCol.g, curCol.b)
                    if curSat < 0.15 then curSat = 0.85 end
                    if curVal < 0.25 then curVal = 1.0 end
                    local hr, hg, hb = HSVtoRGB(h, curSat, curVal)
                    cfg.colorMode = 3
                    cfg.customColor = Color(hr, hg, hb, 255)
                    cfg.customHex = string.format("%02X%02X%02X", hr, hg, hb)
                    SaveAllConfig()
                elseif cfg and b.action == "drag_pop_val" then
                    HUDCustomizer.DraggingPopVal = { x = b.x, w = b.w, id = b.id }
                    local v = math.min(1, math.max(0, (cx - b.x) / b.w))
                    local curCol = cfg.customColor or GetDefaultWidgetColor(b.id)
                    local curHue, curSat = RGBtoHSV(curCol.r, curCol.g, curCol.b)
                    if curSat < 0.15 then curSat = 0.85 end
                    local hr, hg, hb = HSVtoRGB(curHue, curSat, v)
                    cfg.colorMode = 3
                    cfg.customColor = Color(hr, hg, hb, 255)
                    cfg.customHex = string.format("%02X%02X%02X", hr, hg, hb)
                    SaveAllConfig()
                elseif cfg and b.action == "pop_pick_quick" then
                    cfg.colorMode = 3
                    cfg.customColor = Color(b.r, b.g, b.b, 255)
                    cfg.customHex = b.hex
                    SaveAllConfig()
                    if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
                elseif cfg and b.action == "pop_reset" then
                    local dCol, dHex = GetDefaultWidgetColor(b.id)
                    cfg.colorMode = 3
                    cfg.customColor = dCol
                    cfg.customHex = dHex
                    SaveAllConfig()
                    if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
                elseif b.action == "pop_noop" then
                elseif cfg and b.action == "set_format" then
                    cfg.format = b.val
                    SaveAllConfig()
                    if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_MEDIUM) end
                elseif cfg and b.action == "toggle_icon" then
                    cfg.showIcon = not (cfg.showIcon ~= false)
                    SaveAllConfig()
                    if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_MEDIUM) end
                elseif b.action == "close_inspector" then
                    HUDCustomizer.InspectedChip = nil
                    if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
                end
                clickedInspector = true
                break
            end
        end
        
        if not clickedInspector then
            if HUDCustomizer.ColorPickerOpen then
                HUDCustomizer.ColorPickerOpen = false
            end
            for _, b in ipairs(HUDCustomizer.DrawerBounds) do
                if cx >= b.x1 and cx <= b.x2 and cy >= b.y1 and cy <= b.y2 then
                    if b.action == "toggle" then
                        ToggleChipInActiveList(b.id)
                        if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_MEDIUM) end
                    end
                    break
                end
            end
            
            for idx, b in ipairs(HUDCustomizer.PillBounds) do
                if not DragState.IsDragging and cx >= b.x1 and cx <= b.x2 and cy >= b.y1 and cy <= b.y2 then
                    HUDCustomizer.DraggedId = b.id
                    HUDCustomizer.DragStartX = cx
                    HUDCustomizer.DragCurrentX = cx
                    break
                end
            end
        end
    end
    
    if isMenuOpen and HUDCustomizer.IsOpen and (HUDCustomizer.DraggingHue or HUDCustomizer.DraggingPopSV or HUDCustomizer.DraggingPopHue or HUDCustomizer.DraggingPopVal) then
        if not isLMouseDown then
            HUDCustomizer.DraggingHue = nil
            HUDCustomizer.DraggingPopSV = nil
            HUDCustomizer.DraggingPopHue = nil
            HUDCustomizer.DraggingPopVal = nil
            SaveAllConfig()
        else
            if HUDCustomizer.DraggingHue then
                local dh = HUDCustomizer.DraggingHue
                local cfg = HUDCustomizer.WidgetConfigs[dh.id]
                if cfg then
                    local frac = math.min(1, math.max(0, (cx - dh.barX) / dh.barW))
                    local h = frac * 360
                    local curCol = cfg.customColor or GetDefaultWidgetColor(dh.id)
                    local _, curSat, curVal = RGBtoHSV(curCol.r, curCol.g, curCol.b)
                    if curSat < 0.15 then curSat = 0.85 end
                    if curVal < 0.25 then curVal = 1.0 end
                    local hr, hg, hb = HSVtoRGB(h, curSat, curVal)
                    cfg.colorMode = 3
                    cfg.customColor = Color(hr, hg, hb, 255)
                    cfg.customHex = string.format("%02X%02X%02X", hr, hg, hb)
                end
            elseif HUDCustomizer.DraggingPopSV then
                local d = HUDCustomizer.DraggingPopSV
                local cfg = HUDCustomizer.WidgetConfigs[d.id]
                if cfg then
                    local curCol = cfg.customColor or GetDefaultWidgetColor(d.id)
                    local curHue = RGBtoHue(curCol.r, curCol.g, curCol.b)
                    local s = math.min(1, math.max(0, (cx - d.x) / d.w))
                    local v = math.min(1, math.max(0, 1.0 - (cy - d.y) / d.h))
                    local hr, hg, hb = HSVtoRGB(curHue, s, v)
                    cfg.colorMode = 3
                    cfg.customColor = Color(hr, hg, hb, 255)
                    cfg.customHex = string.format("%02X%02X%02X", hr, hg, hb)
                end
            elseif HUDCustomizer.DraggingPopHue then
                local d = HUDCustomizer.DraggingPopHue
                local cfg = HUDCustomizer.WidgetConfigs[d.id]
                if cfg then
                    local h = math.min(1, math.max(0, (cx - d.x) / d.w)) * 360
                    local curCol = cfg.customColor or GetDefaultWidgetColor(d.id)
                    local _, curSat, curVal = RGBtoHSV(curCol.r, curCol.g, curCol.b)
                    if curSat < 0.15 then curSat = 0.85 end
                    if curVal < 0.25 then curVal = 1.0 end
                    local hr, hg, hb = HSVtoRGB(h, curSat, curVal)
                    cfg.colorMode = 3
                    cfg.customColor = Color(hr, hg, hb, 255)
                    cfg.customHex = string.format("%02X%02X%02X", hr, hg, hb)
                end
            elseif HUDCustomizer.DraggingPopVal then
                local d = HUDCustomizer.DraggingPopVal
                local cfg = HUDCustomizer.WidgetConfigs[d.id]
                if cfg then
                    local v = math.min(1, math.max(0, (cx - d.x) / d.w))
                    local curCol = cfg.customColor or GetDefaultWidgetColor(d.id)
                    local curHue, curSat = RGBtoHSV(curCol.r, curCol.g, curCol.b)
                    if curSat < 0.15 then curSat = 0.85 end
                    local hr, hg, hb = HSVtoRGB(curHue, curSat, v)
                    cfg.colorMode = 3
                    cfg.customColor = Color(hr, hg, hb, 255)
                    cfg.customHex = string.format("%02X%02X%02X", hr, hg, hb)
                end
            end
        end
    end

    if isMenuOpen and HUDCustomizer.IsOpen and HUDCustomizer.DraggedId then
        if not isLMouseDown then
            HUDCustomizer.DraggedId = nil
            SaveAllConfig()
        else
            HUDCustomizer.DragCurrentX = cx
            local curIdx = nil
            for idx, id in ipairs(HUDCustomizer.ActiveChips) do
                if id == HUDCustomizer.DraggedId then
                    curIdx = idx
                    break
                end
            end
            
            if curIdx then
                for otherIdx, b in ipairs(HUDCustomizer.PillBounds) do
                    if otherIdx ~= curIdx then
                        local midX = (b.x1 + b.x2) / 2
                        if (curIdx < otherIdx and cx > midX) or (curIdx > otherIdx and cx < midX) then
                            local temp = HUDCustomizer.ActiveChips[curIdx]
                            HUDCustomizer.ActiveChips[curIdx] = HUDCustomizer.ActiveChips[otherIdx]
                            HUDCustomizer.ActiveChips[otherIdx] = temp
                            break
                        end
                    end
                end
            end
        end
    end
    
    local inGame = Engine.IsInGame and Engine.IsInGame()
    if not inGame then
        if not NotificationQueue.Active then
            local canAccept = Engine.CanAcceptMatch and Engine.CanAcceptMatch()
            if canAccept then
                if StateMachine.TargetState ~= StateMachine.States.MENU_MATCH_FOUND then
                    TriggerStateTransition(StateMachine.States.MENU_MATCH_FOUND)
                end
            else
                local isSearching, searchTimer = GetMatchSearchInfo()
                if isSearching then
                    if StateMachine.TargetState ~= StateMachine.States.MENU_SEARCHING then
                        TriggerStateTransition(StateMachine.States.MENU_SEARCHING)
                    end
                else
                    if StateMachine.TargetState ~= StateMachine.States.MENU_IDLE then
                        TriggerStateTransition(StateMachine.States.MENU_IDLE)
                    end
                end
            end
        else
            if StateMachine.TargetState ~= StateMachine.States.NOTIFICATION then
                TriggerStateTransition(StateMachine.States.NOTIFICATION)
            end
        end
    else
        local pauseEnabled = (UI and UI.Combat and UI.Combat.PauseAlert) and UI.Combat.PauseAlert:Get() or true
        if PauseTracker.IsPaused and pauseEnabled then
            if StateMachine.TargetState ~= StateMachine.States.GAME_PAUSED then
                TriggerStateTransition(StateMachine.States.GAME_PAUSED)
            end
        elseif CourierTracker.Delivered then
            if (nowClk - CourierTracker.DeliveredStartTime) <= CourierTracker.DeliveredDuration then
                if StateMachine.TargetState ~= StateMachine.States.COURIER_DELIVERED then
                    TriggerStateTransition(StateMachine.States.COURIER_DELIVERED)
                end
            else
                CourierTracker.Delivered = false
            end
        elseif CourierTracker.Delivering then
            if StateMachine.TargetState ~= StateMachine.States.COURIER_DELIVERY and StateMachine.TargetState ~= StateMachine.States.COURIER_LARGE then
                TriggerStateTransition(StateMachine.States.COURIER_DELIVERY)
            end
        elseif not NotificationQueue.Active then
            if inCombat then
                if StateMachine.TargetState ~= StateMachine.States.COMPACT_FIGHT and StateMachine.TargetState ~= StateMachine.States.LARGE_FIGHT then
                    TriggerStateTransition(StateMachine.States.COMPACT_FIGHT)
                end
            elseif StateMachine.TargetState == StateMachine.States.NOTIFICATION or StateMachine.TargetState == StateMachine.States.MENU_IDLE or StateMachine.TargetState == StateMachine.States.MENU_SEARCHING or StateMachine.TargetState == StateMachine.States.MENU_MATCH_FOUND or StateMachine.TargetState == StateMachine.States.GAME_PAUSED or StateMachine.TargetState == StateMachine.States.COURIER_DELIVERED or StateMachine.TargetState == StateMachine.States.COURIER_DELIVERY or StateMachine.TargetState == StateMachine.States.COURIER_LARGE then
                local desired = (mediaActive and not HUDCustomizer.IsOpen) and StateMachine.States.COMPACT_MEDIA or StateMachine.States.COMPACT_IDLE
                TriggerStateTransition(desired)
            elseif StateMachine.TargetState == StateMachine.States.COMPACT_IDLE or StateMachine.TargetState == StateMachine.States.COMPACT_MEDIA or StateMachine.TargetState == StateMachine.States.COMPACT_FIGHT then
                local desired = (mediaActive and not HUDCustomizer.IsOpen) and StateMachine.States.COMPACT_MEDIA or StateMachine.States.COMPACT_IDLE
                if StateMachine.TargetState ~= desired then
                    TriggerStateTransition(desired)
                end
            elseif StateMachine.TargetState == StateMachine.States.LARGE_IDLE or StateMachine.TargetState == StateMachine.States.LARGE_MEDIA or StateMachine.TargetState == StateMachine.States.LARGE_FIGHT then
                local desiredLarge = mediaActive and StateMachine.States.LARGE_MEDIA or StateMachine.States.LARGE_IDLE
                if StateMachine.TargetState ~= desiredLarge then
                    TriggerStateTransition(desiredLarge)
                end
            end
        else
            if StateMachine.TargetState ~= StateMachine.States.NOTIFICATION then
                TriggerStateTransition(StateMachine.States.NOTIFICATION)
            end
        end
    end
    
    if StateMachine.TargetState == StateMachine.States.COMPACT_IDLE then
        local contentW = CalculateIdleContentWidth(layout.scale)
        local targetUnscaled = (contentW / layout.scale) + 26
        Config.Dimensions.CompactTargetW = math.max(80, targetUnscaled)
        Config.Dimensions.CompactTargetH = Config.Dimensions.CompactH
        Config.Dimensions.CompactTargetR = Config.Dimensions.CompactRadius
    elseif StateMachine.TargetState == StateMachine.States.MENU_IDLE then
        local contentW = CalculateMenuIdleWidth(layout.scale)
        Config.Dimensions.CompactTargetW = math.max(120, (contentW / layout.scale) + 26)
        Config.Dimensions.CompactTargetH = Config.Dimensions.CompactH
        Config.Dimensions.CompactTargetR = Config.Dimensions.CompactRadius
    elseif StateMachine.TargetState == StateMachine.States.MENU_SEARCHING then
        local _, timeStr = GetMatchSearchInfo()
        local contentW = CalculateMenuSearchingWidth(layout.scale, timeStr)
        Config.Dimensions.CompactTargetW = math.max(160, (contentW / layout.scale) + 26)
        Config.Dimensions.CompactTargetH = Config.Dimensions.CompactH
        Config.Dimensions.CompactTargetR = Config.Dimensions.CompactRadius
    elseif StateMachine.TargetState == StateMachine.States.MENU_MATCH_FOUND then
        local contentW = CalculateMenuMatchFoundWidth(layout.scale)
        Config.Dimensions.CompactTargetW = math.max(180, (contentW / layout.scale) + 30)
        Config.Dimensions.CompactTargetH = Config.Dimensions.CompactH + 2
        Config.Dimensions.CompactTargetR = Config.Dimensions.CompactRadius
    elseif StateMachine.TargetState == StateMachine.States.COMPACT_MEDIA then
        Config.Dimensions.CompactTargetW = Config.Dimensions.CompactMediaW
        Config.Dimensions.CompactTargetH = Config.Dimensions.CompactMediaH
        Config.Dimensions.CompactTargetR = Config.Dimensions.CompactMediaRadius
    elseif StateMachine.TargetState == StateMachine.States.COMPACT_FIGHT then
        Config.Dimensions.CompactTargetW = Config.Dimensions.CompactFightW
        Config.Dimensions.CompactTargetH = Config.Dimensions.CompactFightH
        Config.Dimensions.CompactTargetR = Config.Dimensions.CompactFightRadius
    elseif StateMachine.TargetState == StateMachine.States.NOTIFICATION then
        Config.Dimensions.CompactTargetW = Config.Dimensions.NotificationW
        Config.Dimensions.CompactTargetH = Config.Dimensions.NotificationH
        Config.Dimensions.CompactTargetR = Config.Dimensions.NotificationRadius
    elseif StateMachine.TargetState == StateMachine.States.LARGE_MEDIA then
        Config.Dimensions.CompactTargetW = Config.Dimensions.LargeMediaW
        Config.Dimensions.CompactTargetH = Config.Dimensions.LargeMediaH
        Config.Dimensions.CompactTargetR = Config.Dimensions.LargeMediaRadius
    elseif StateMachine.TargetState == StateMachine.States.LARGE_FIGHT then
        Config.Dimensions.CompactTargetW = Config.Dimensions.LargeFightW
        Config.Dimensions.CompactTargetH = Config.Dimensions.LargeFightH
        Config.Dimensions.CompactTargetR = Config.Dimensions.LargeFightRadius
    elseif StateMachine.TargetState == StateMachine.States.LARGE_IDLE then
        Config.Dimensions.CompactTargetW = Config.Dimensions.LargeW
        Config.Dimensions.CompactTargetH = Config.Dimensions.LargeH
        Config.Dimensions.CompactTargetR = Config.Dimensions.LargeRadius
    elseif StateMachine.TargetState == StateMachine.States.GAME_PAUSED then
        local fontBold = Config.Fonts.Bold
        local fontMain = Config.Fonts.Main
        local elapsed = PauseTracker.PauseStartTime > 0 and math.floor(os.clock() - PauseTracker.PauseStartTime) or 0
        local pText = L("island.paused", "Paused")
        local timeText = string.format("%d:%02d", math.floor(elapsed / 60), elapsed % 60)
        local tSize1 = Render.TextSize(fontMain, 11 * layout.scale, pText)
        local tSizeDot = Render.TextSize(fontMain, 11 * layout.scale, " \u{2022} ")
        local tSize2 = Render.TextSize(fontBold, 11.5 * layout.scale, timeText)
        local totalContentW = 10 * layout.scale + 18 * layout.scale + 8 * layout.scale + tSize1.x + tSizeDot.x + tSize2.x + 16 * layout.scale
        Config.Dimensions.CompactTargetW = math.max(120, math.floor(totalContentW / layout.scale))
        Config.Dimensions.CompactTargetH = Config.Dimensions.GamePausedH
        Config.Dimensions.CompactTargetR = Config.Dimensions.GamePausedRadius
    elseif StateMachine.TargetState == StateMachine.States.COURIER_DELIVERY then
        Config.Dimensions.CompactTargetW = Config.Dimensions.CourierDeliveryW
        Config.Dimensions.CompactTargetH = Config.Dimensions.CourierDeliveryH
        Config.Dimensions.CompactTargetR = Config.Dimensions.CourierDeliveryRadius
    elseif StateMachine.TargetState == StateMachine.States.COURIER_DELIVERED then
        local fontBold = Config.Fonts.Bold
        local txt = L("courier.delivered", "Delivered!")
        local tSize = Render.TextSize(fontBold, 11.5 * layout.scale, txt)
        Config.Dimensions.CompactTargetW = math.max(160, (tSize.x / layout.scale) + 60)
        Config.Dimensions.CompactTargetH = Config.Dimensions.CourierDeliveredH
        Config.Dimensions.CompactTargetR = Config.Dimensions.CourierDeliveredRadius
    elseif StateMachine.TargetState == StateMachine.States.COURIER_LARGE then
        Config.Dimensions.CompactTargetW = Config.Dimensions.CourierLargeW
        Config.Dimensions.CompactTargetH = Config.Dimensions.CourierLargeH
        Config.Dimensions.CompactTargetR = Config.Dimensions.CourierLargeRadius
    end
    
    if HUDCustomizer.IsOpen then return end
    
    local openOnHover = true
    local hoverDelaySec = 0.10
    
    if isHover and not isCtrlOnly then
        if not StateMachine.IsHovered then
            StateMachine.IsHovered = true
            StateMachine.HoverStartTime = nowClk
            if Haptic and Haptic.Trigger then
                Haptic.Trigger(Haptic.Types.TAP_LIGHT)
            end
        end
        StateMachine.UnhoverStartTime = 0
        
        if openOnHover then
            if StateMachine.TargetState == StateMachine.States.COMPACT_FIGHT then
                if (nowClk - StateMachine.HoverStartTime) >= hoverDelaySec then
                    TriggerStateTransition(StateMachine.States.LARGE_FIGHT)
                end
            elseif StateMachine.TargetState == StateMachine.States.COURIER_DELIVERY then
                if (nowClk - StateMachine.HoverStartTime) >= hoverDelaySec then
                    TriggerStateTransition(StateMachine.States.COURIER_LARGE)
                end
            elseif StateMachine.TargetState == StateMachine.States.COMPACT_IDLE or StateMachine.TargetState == StateMachine.States.COMPACT_MEDIA then
                if (nowClk - StateMachine.HoverStartTime) >= hoverDelaySec then
                    local nextL = mediaActive and StateMachine.States.LARGE_MEDIA or StateMachine.States.LARGE_IDLE
                    TriggerStateTransition(nextL)
                end
            end
        end
    else
        if StateMachine.IsHovered then
            StateMachine.IsHovered = false
            StateMachine.UnhoverStartTime = nowClk
        end
        StateMachine.HoverStartTime = 0
        
        if openOnHover then
            if StateMachine.TargetState == StateMachine.States.LARGE_FIGHT then
                if StateMachine.UnhoverStartTime > 0 and (nowClk - StateMachine.UnhoverStartTime) >= 0.22 then
                    TriggerStateTransition(StateMachine.States.COMPACT_FIGHT)
                end
            elseif StateMachine.TargetState == StateMachine.States.COURIER_LARGE then
                if StateMachine.UnhoverStartTime > 0 and (nowClk - StateMachine.UnhoverStartTime) >= 0.22 then
                    TriggerStateTransition(StateMachine.States.COURIER_DELIVERY)
                end
            elseif StateMachine.TargetState == StateMachine.States.LARGE_MEDIA or StateMachine.TargetState == StateMachine.States.LARGE_IDLE then
                if StateMachine.UnhoverStartTime > 0 and (nowClk - StateMachine.UnhoverStartTime) >= 0.22 then
                    local nextC = mediaActive and StateMachine.States.COMPACT_MEDIA or StateMachine.States.COMPACT_IDLE
                    TriggerStateTransition(nextC)
                end
            end
        end
    end
    
    if isLeftClicked and isHover and not isCtrlOnly and StateMachine.TargetState == StateMachine.States.MENU_MATCH_FOUND then
        if Engine.AcceptMatch then
            pcall(Engine.AcceptMatch, 1)
        end
    end
    
    if isLeftClicked and (isHover or isHoverSatellite) and not isCtrlOnly then
        local clickedButton = false
        if (StateMachine.TargetState == StateMachine.States.LARGE_MEDIA or FightTracker.SatelliteExpanded) and mediaActive then
            if ButtonHits.MediaPrev and cx >= ButtonHits.MediaPrev.x1 and cx <= ButtonHits.MediaPrev.x2 and cy >= ButtonHits.MediaPrev.y1 and cy <= ButtonHits.MediaPrev.y2 then
                ButtonSprings.MediaPrev.scale = 0.80
                TrackTransition.Direction = -1
                SendMediaCommand("prev")
                clickedButton = true
            elseif ButtonHits.MediaPlay and cx >= ButtonHits.MediaPlay.x1 and cx <= ButtonHits.MediaPlay.x2 and cy >= ButtonHits.MediaPlay.y1 and cy <= ButtonHits.MediaPlay.y2 then
                ButtonSprings.MediaPlay.scale = 0.80
                MediaData.LastManualToggle = nowClk
                if MediaData.IsPlaying then
                    MediaData.IsPlaying = false
                    MediaData.LastPauseTime = nowClk
                    MediaData.RealBars = { 0, 0, 0, 0, 0 }
                else
                    MediaData.IsPlaying = true
                    MediaData.LastPlayTime = nowClk
                    MediaData.LastPauseTime = 0
                end
                SendMediaCommand("playpause")
                clickedButton = true
            elseif ButtonHits.MediaNext and cx >= ButtonHits.MediaNext.x1 and cx <= ButtonHits.MediaNext.x2 and cy >= ButtonHits.MediaNext.y1 and cy <= ButtonHits.MediaNext.y2 then
                ButtonSprings.MediaNext.scale = 0.80
                TrackTransition.Direction = 1
                SendMediaCommand("next")
                clickedButton = true
            elseif ButtonHits.MediaShuffle and cx >= ButtonHits.MediaShuffle.x1 and cx <= ButtonHits.MediaShuffle.x2 and cy >= ButtonHits.MediaShuffle.y1 and cy <= ButtonHits.MediaShuffle.y2 then
                ButtonSprings.MediaShuffle.scale = 0.80
                MediaData.Shuffle = not MediaData.Shuffle
                SendMediaCommand("shuffle")
                clickedButton = true
            elseif ButtonHits.MediaRepeat and cx >= ButtonHits.MediaRepeat.x1 and cx <= ButtonHits.MediaRepeat.x2 and cy >= ButtonHits.MediaRepeat.y1 and cy <= ButtonHits.MediaRepeat.y2 then
                ButtonSprings.MediaRepeat.scale = 0.80
                MediaData.RepeatMode = (MediaData.RepeatMode + 1) % 3
                SendMediaCommand("repeat")
                clickedButton = true
            elseif ButtonHits.MediaLike and cx >= ButtonHits.MediaLike.x1 and cx <= ButtonHits.MediaLike.x2 and cy >= ButtonHits.MediaLike.y1 and cy <= ButtonHits.MediaLike.y2 then
                ButtonSprings.MediaLike.scale = 0.65
                local isNowLiked = not MediaData.IsLiked
                MediaData.IsLiked = isNowLiked
                if MediaData.LastTrackKey ~= "" then
                    MediaData.LikedTracks[MediaData.LastTrackKey] = isNowLiked
                end
                
                SendMediaCommand("like")
                DynamicIsland.PushNotification({
                    Type = "spotify_like",
                    Tag = "SPOTIFY",
                    Title = isNowLiked and L("Любимые треки", "Liked Songs") or L("Удалено из избранного", "Removed from Favorites"),
                    Subtitle = isNowLiked and L("Сохранено в библиотеку", "Saved to Library") or L("Удалено из Spotify", "Removed from Spotify"),
                    AccentColor = Color(255, 255, 255, 255),
                    IconType = "svg",
                    FallbackSvg = isNowLiked and "heart_fill" or "heart_outline",
                    Duration = 2.5
                })
                return
            end
        end
        if clickedButton and Haptic and Haptic.Trigger then
            Haptic.Trigger(Haptic.Types.TAP_MEDIUM)
        end
    end
end

local function DrawAppleWaveform(x, y, maxH, count, isPlaying, scale, customColor, alphaMul)
    local aMul = alphaMul or 1.0
    local now = os.clock()
    local barW = math.max(1, math.floor(2.4 * scale))
    local barGap = math.max(1, math.floor(1.8 * scale))
    local baseCol = customColor or MediaData.CoverColor or GetPrimaryThemeColor()
    local baseFreqs = { 3.2, 4.8, 6.1, 4.9, 7.4 }
    local phaseOffsets = { 0.41, 1.93, 3.52, 5.18, 1.15 }
    local harmonicMults = { 1.618, 1.414, 1.732, 1.528, 1.667 }
    local beat = (math.sin(now * 4.2) * 0.28 + 0.72)
    local volMul = math.max(0.45, math.min(1.0, ((MediaData.Volume or 100) / 100.0)))
    
    for i = 1, count do
        local bx = math.floor(x + (i - 1) * (barW + barGap))
        local targetH = 2.0 * scale
        
        if isPlaying then
            local f = baseFreqs[i] or (3.5 + i * 0.9)
            local ph = phaseOffsets[i] or (i * 1.25)
            local hm = harmonicMults[i] or 1.618
            local w1 = math.sin(now * f + ph)
            local w2 = math.sin(now * (f * hm) + ph * 1.37)
            local w3 = math.cos(now * (f * 0.618) - ph * 0.73)
            local combined = (w1 * 0.45 + w2 * 0.35 + w3 * 0.20)
            local norm = (combined + 1.0) * 0.5
            local shaped = (norm * norm) * beat * volMul
            targetH = (2.2 + shaped * (maxH - 3.2)) * scale
        end
        
        local curH = MediaData.SmoothBars[i] or targetH
        local smoothSpeed = 0.25
        if isPlaying then
            smoothSpeed = (targetH > curH) and 0.52 or 0.24
        end
        curH = curH + (targetH - curH) * smoothSpeed
        MediaData.SmoothBars[i] = curH
        
        local intH = math.max(2, math.floor(curH))
        local by = math.floor(y + (maxH * scale - intH) / 2)
        
        local shift = (i - math.floor((count + 1) / 2)) * 10
        local cr = math.min(255, math.max(0, baseCol.r + shift))
        local cg = math.min(255, math.max(0, baseCol.g + shift))
        local cb = math.min(255, math.max(0, baseCol.b + shift))
        local col = FadeColor(Color(cr, cg, cb, 255), aMul)
        local cornerR = math.max(1, math.floor(barW / 2))
        
        Render.FilledRect(Vec2(bx, by), Vec2(bx + barW, by + intH), col, cornerR)
    end
end

local function RenderMarqueeText(font, size, text, boxX, boxY, boxW, color, scale, rightFadeOnly)
    local fullSize = Render.TextSize(font, size, text)
    local ix = math.floor(boxX)
    local iy = math.floor(boxY)
    local iw = math.floor(boxW)
    
    if fullSize.x <= iw then
        Render.Text(font, size, text, Vec2(ix, iy), color)
        return
    end
    
    local speed = (UI and UI.Media and UI.Media.MarqueeSpeed) and UI.Media.MarqueeSpeed:Get() or 45
    local spacer = "      "
    local spacerSize = Render.TextSize(font, size, spacer)
    local totalCycle = fullSize.x + spacerSize.x
    
    local now = os.clock()
    local offset = math.floor((now * speed) % totalCycle)
    
    Render.PushClip(Vec2(ix, iy - 2), Vec2(ix + iw, iy + size + 4))
    
    local x1 = ix - offset
    Render.Text(font, size, text, Vec2(x1, iy), color)
    
    local x2 = x1 + totalCycle
    if x2 < ix + iw then
        Render.Text(font, size, text, Vec2(x2, iy), color)
    end
    
    Render.PopClip()
end

local function DrawAlbumThumbnail(x, y, size, radius, alphaMul, scaleMul, customHandle, customCol)
    local aMul = alphaMul or 1.0
    local sMul = scaleMul or 1.0
    local isz = math.floor(size * sMul + 0.5)
    local ix = math.floor(x + (size - isz) * 0.5)
    local iy = math.floor(y + (size - isz) * 0.5)
    local ir = math.floor(radius * sMul + 0.5)
    
    local imgH = customHandle or MediaData.CoverImageHandle
    if imgH and imgH > 0 then
        Render.Image(imgH, Vec2(ix, iy), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), aMul), ir)
    else
        local baseCol = customCol or MediaData.CoverColor or Config.Colors.Red
        Render.FilledRect(Vec2(ix, iy), Vec2(ix + isz, iy + isz), FadeColor(baseCol, aMul), ir)
        local iconR = isz * 0.28
        Render.FilledCircle(Vec2(ix + isz / 2, iy + isz / 2), iconR, FadeColor(Color(255, 255, 255, 220), aMul), 0, 1.0, 24)
    end
end

local function RenderMenuIdlePill(layout, alphaMul, yOffset)
    local aMul = alphaMul or 1.0
    local yOff = yOffset or 0
    local scale = layout.scale
    local fontBold = Config.Fonts.Bold
    local textCol = FadeColor(Color(255, 255, 255, 255), aMul)
    local dotCol = FadeColor(Color(255, 255, 255, 140), aMul)
    
    local txtMenu = L("island.in_menu", "In Menu")
    local txtClock = os.date("%H:%M")
    
    local sMenu = Render.TextSize(fontBold, 11 * scale, txtMenu)
    local sClock = Render.TextSize(fontBold, 11 * scale, txtClock)
    
    local iconSz = math.floor(12 * scale)
    local iconGap = math.floor(5 * scale)
    local dotR = math.floor(1.6 * scale)
    local dotPad = math.floor(7 * scale)
    
    local totalW = iconSz + iconGap + sMenu.x + dotPad + (dotR * 2) + dotPad + iconSz + iconGap + sClock.x
    local curX = math.floor(layout.x + (layout.w - totalW) / 2)
    local midY = math.floor(layout.y + layout.h / 2 + yOff)
    local iconY = math.floor(midY - iconSz / 2 + MenuIconOffsetY * scale)
    local ty = math.floor(midY - sMenu.y / 2 + MenuTextOffsetY * scale)
    
    local hHome = GetVectorIcon("home")
    if hHome then
        Render.Image(hHome, Vec2(curX, iconY), Vec2(iconSz, iconSz), textCol, 0)
    end
    curX = curX + iconSz + iconGap
    
    Render.Text(fontBold, 11 * scale, txtMenu, Vec2(curX, ty), textCol)
    curX = curX + sMenu.x + dotPad
    
    Render.FilledCircle(Vec2(curX + dotR, midY), dotR, dotCol, 0, 1.0, 16)
    curX = curX + (dotR * 2) + dotPad
    
    local hClock = GetVectorIcon("clock")
    if hClock then
        Render.Image(hClock, Vec2(curX, iconY), Vec2(iconSz, iconSz), textCol, 0)
    end
    curX = curX + iconSz + iconGap
    
    Render.Text(fontBold, 11 * scale, txtClock, Vec2(curX, ty), textCol)
end

local function RenderMenuSearchingPill(layout, alphaMul, yOffset)
    local aMul = alphaMul or 1.0
    local yOff = yOffset or 0
    local scale = layout.scale
    local fontBold = Config.Fonts.Bold
    local searchCol = FadeColor(Color(220, 238, 255, 255), aMul)
    local textCol = FadeColor(Color(255, 255, 255, 255), aMul)
    local dotCol = FadeColor(Color(255, 255, 255, 140), aMul)
    
    local _, timeStr = GetMatchSearchInfo()
    local txtSearch = L("island.finding_match", "Finding Match ") .. (timeStr or "0:00")
    local txtClock = os.date("%H:%M")
    
    local sSearch = Render.TextSize(fontBold, 11 * scale, txtSearch)
    local sClock = Render.TextSize(fontBold, 11 * scale, txtClock)
    
    local iconSz = math.floor(12 * scale)
    local iconGap = math.floor(5 * scale)
    local dotR = math.floor(1.6 * scale)
    local dotPad = math.floor(7 * scale)
    
    local totalW = iconSz + iconGap + sSearch.x + dotPad + (dotR * 2) + dotPad + iconSz + iconGap + sClock.x
    local curX = math.floor(layout.x + (layout.w - totalW) / 2)
    local midY = math.floor(layout.y + layout.h / 2 + yOff)
    local iconY = math.floor(midY - iconSz / 2 + MenuIconOffsetY * scale)
    local ty = math.floor(midY - sSearch.y / 2 + MenuTextOffsetY * scale)
    
    local hSearch = GetVectorIcon("search")
    if hSearch then
        Render.Image(hSearch, Vec2(curX, iconY), Vec2(iconSz, iconSz), searchCol, 0)
    end
    curX = curX + iconSz + iconGap
    
    Render.Text(fontBold, 11 * scale, txtSearch, Vec2(curX, ty), searchCol)
    curX = curX + sSearch.x + dotPad
    
    Render.FilledCircle(Vec2(curX + dotR, midY), dotR, dotCol, 0, 1.0, 16)
    curX = curX + (dotR * 2) + dotPad
    
    local hClock = GetVectorIcon("clock")
    if hClock then
        Render.Image(hClock, Vec2(curX, iconY), Vec2(iconSz, iconSz), textCol, 0)
    end
    curX = curX + iconSz + iconGap
    
    Render.Text(fontBold, 11 * scale, txtClock, Vec2(curX, ty), textCol)
end

local function RenderMenuMatchFoundPill(layout, alphaMul, yOffset)
    local aMul = alphaMul or 1.0
    local yOff = yOffset or 0
    local scale = layout.scale
    local fontBold = Config.Fonts.Bold
    
    local pulse = 0.8 + 0.2 * math.sin(os.clock() * 8.0)
    local greenCol = FadeColor(Color(52, 199, 89, math.floor(255 * pulse)), aMul)
    
    local txtFound = L("island.match_found", "Match Found!")
    local sFound = Render.TextSize(fontBold, 11.5 * scale, txtFound)
    
    local iconSz = math.floor(13 * scale)
    local iconGap = math.floor(6 * scale)
    
    local totalW = iconSz + iconGap + sFound.x
    local curX = math.floor(layout.x + (layout.w - totalW) / 2)
    local midY = math.floor(layout.y + layout.h / 2 + yOff)
    local iconY = math.floor(midY - iconSz / 2 + MenuIconOffsetY * scale)
    local ty = math.floor(midY - sFound.y / 2 + MenuTextOffsetY * scale)
    
    local hCheck = GetVectorIcon("check")
    if hCheck then
        Render.Image(hCheck, Vec2(curX, iconY), Vec2(iconSz, iconSz), greenCol, 0)
    end
    curX = curX + iconSz + iconGap
    
    Render.Text(fontBold, 11.5 * scale, txtFound, Vec2(curX, ty), greenCol)
end

local function RenderModularIdlePill(layout, alphaMul, yOffset)
    local aMul = alphaMul or 1.0
    local yOff = yOffset or 0
    local scale = layout.scale
    local renderedChips = {}
    
    for idx, id in ipairs(HUDCustomizer.ActiveChips) do
        local c = GetChipContent(id)
        local chipW = GetChipStandardWidth(id, scale)
        local iconExtra = c.svgKey and ((13 + 5) * scale) or 0
        table.insert(renderedChips, { id = id, isClock = c.isClock, svgKey = c.svgKey, text = c.text, font = c.font, color = FadeColor(c.color, aMul), width = chipW, iconExtra = iconExtra })
    end
    
    local totalContentW = 0
    for idx, chip in ipairs(renderedChips) do
        totalContentW = totalContentW + chip.width
        if idx < #renderedChips then
            totalContentW = totalContentW + 12 * scale
        end
    end
    
    local startX = math.floor(layout.x + (layout.w - totalContentW) / 2)
    local curX = startX
    local midY = math.floor(layout.y + layout.h / 2 + yOff)
    
    HUDCustomizer.PillBounds = {}
    
    for idx, chip in ipairs(renderedChips) do
        local chipStartX = curX
        local isBeingDragged = (HUDCustomizer.IsOpen and HUDCustomizer.DraggedId == chip.id)
        
        table.insert(HUDCustomizer.PillBounds, {
            x1 = chipStartX - 4 * scale,
            y1 = layout.y + 2 * scale,
            x2 = chipStartX + chip.width + 4 * scale,
            y2 = layout.y + layout.h - 2 * scale,
            id = chip.id
        })
        
        local drawX = isBeingDragged and math.floor(HUDCustomizer.DragCurrentX - chip.width / 2) or chipStartX
        
        local refSize = Render.TextSize(chip.font, 11 * scale, "0123456789")
        local ty = math.floor(midY - refSize.y / 2 + MenuTextOffsetY * scale)
        if chip.svgKey then
            local iconHandle = GetVectorIcon(chip.svgKey)
            local iconSz = math.floor(13 * scale)
            local iconX = drawX
            local iconY = math.floor(midY - iconSz / 2 + MenuIconOffsetY * scale)
            if iconHandle then
                Render.Image(iconHandle, Vec2(iconX, iconY), Vec2(iconSz, iconSz), chip.color, 0)
            end
            
            local tx = drawX + iconSz + math.floor(5 * scale)
            Render.Text(chip.font, 11 * scale, chip.text, Vec2(tx, ty), chip.color)
            curX = curX + chip.width
        else
            local tx = drawX
            Render.Text(chip.font, 11 * scale, chip.text, Vec2(tx, ty), chip.color)
            curX = curX + chip.width
        end
        
        if idx < #renderedChips then
            local dotR = 1.6 * scale
            local dotX = curX + 6 * scale
            Render.FilledCircle(Vec2(dotX, midY), dotR, FadeColor(Config.Colors.TextMuted, aMul), 0, 1.0, 12)
            curX = dotX + 6 * scale
        end
    end
end

local function IsPureGlass()
    return UI.Main.PureGlass:Get()
end

local function IslandSurface(p1, p2, radius, borderCol, thickness, aMul)
    local a = aMul or 1.0
    if IsPureGlass() or UI.Media.Blur:Get() then
        Render.Blur(p1, p2, 1.2, 1.2, radius, Enum.DrawFlags.None)
    end
    if not IsPureGlass() then
        Render.FilledRect(p1, p2, FadeColor(UI.Main.IslandBgColor:Get(), a), radius)
    end
    local curBorder = borderCol
    if StateMachine.TargetState == StateMachine.States.MENU_MATCH_FOUND then
        local p = 0.55 + 0.45 * math.sin(os.clock() * 8.0)
        curBorder = Color(52, 199, 89, math.floor(255 * p))
    end
    Render.Rect(p1, p2, FadeColor(curBorder, a), radius, Enum.DrawFlags.None, thickness or 1.0)
end

local function DrawerSurface(p1, p2, radius, aMul)
    -- solid opaque card: the drawer only lives while the Umbrella menu is
    -- open behind it, so blur/alpha would sample that (animated) background
    local bg = UI.Main.IslandBgColor:Get()
    Render.FilledRect(p1, p2, FadeColor(Color(bg.r, bg.g, bg.b, 255), aMul), radius)
    Render.Rect(p1, p2, FadeColor(Config.Colors.Border, aMul), radius, Enum.DrawFlags.None, 1.0)
end

local function EaseOutCubic(x)
    local u = 1 - math.min(1, math.max(0, x))
    return 1 - u * u * u
end

local function EaseOutBack(x)
    local u = math.min(1, math.max(0, x)) - 1
    return 1 + 2.05 * u * u * u + 1.05 * u * u
end

local function RenderSegmented(x, y, w, h, items, sel, spring, dt, scale, aMul, action)
    local n = #items
    spring.v, spring.vel = SolveDampedSpring(spring.v, spring.vel, sel - 1, dt, 26.0, 0.80)
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), FadeColor(Config.Colors.SegTrack, aMul), h / 2)
    local segW = w / n
    local tx = x + 2 + spring.v * segW
    Render.FilledRect(Vec2(tx, y + 2), Vec2(tx + segW - 4, y + h - 2), FadeColor(Config.Colors.SegThumb, aMul), (h - 4) / 2)
    Render.Rect(Vec2(tx, y + 2), Vec2(tx + segW - 4, y + h - 2), FadeColor(Config.Colors.SegThumbBorder, aMul), (h - 4) / 2, Enum.DrawFlags.None, 1.0)
    for i, it in ipairs(items) do
        local act = (i == sel)
        local f = act and Config.Fonts.Bold or Config.Fonts.Main
        local ts = Render.TextSize(f, 9 * scale, it.label)
        Render.Text(f, 9 * scale, it.label, Vec2(x + (i - 1) * segW + (segW - ts.x) / 2, y + (h - ts.y) / 2 - 1), FadeColor(act and Config.Colors.TextPrimary or Config.Colors.TextMuted, aMul))
        if aMul > 0.6 then
            table.insert(HUDCustomizer.InspectorBounds, { x1 = x + (i - 1) * segW, y1 = y, x2 = x + i * segW, y2 = y + h, action = action, val = it.val })
        end
    end
end

local function RenderSwitch(x, y, w, h, on, spring, dt, aMul)
    spring.v, spring.vel = SolveDampedSpring(spring.v, spring.vel, on and 1 or 0, dt, 26.0, 0.82)
    local t = math.min(1, math.max(0, spring.v))
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), FadeColor(LerpColor(Config.Colors.SegTrack, Config.Colors.Accent, t), aMul), h / 2)
    local kr = h / 2 - 2
    Render.FilledCircle(Vec2(x + 2 + kr + (w - 4 - kr * 2) * t, y + h / 2), kr, FadeColor(Color(255, 255, 255, 255), aMul), 0, 1.0, 24)
end

local SEG_WEIGHT = { { label = "Bold", val = 1 }, { label = "Regular", val = 2 } }
local SEG_COLOR = { { label = L("Белый", "White"), val = 1 }, { label = L("Серый", "Dim"), val = 2 }, { label = L("Свой", "Custom"), val = 3 } }
local SEG_FORMAT = { { label = L("Стандарт", "Standard"), val = 1 }, { label = L("Кратко", "Minimal"), val = 2 }, { label = L("Детали", "Detailed"), val = 3 } }

local function RenderSettingsLabel(x, y, rowH, label, scale, aMul)
    local ts = Render.TextSize(Config.Fonts.Main, 10 * scale, label)
    Render.Text(Config.Fonts.Main, 10 * scale, label, Vec2(x, y + (rowH - ts.y) / 2 - 1), FadeColor(Config.Colors.TextSecondary, aMul))
end

local function RenderWidgetSettings(cx, cw, cy, scale, aMul, dt)
    local id = HUDCustomizer.InspectedChip
    local cfg = HUDCustomizer.WidgetConfigs[id]
    if not cfg then return end

    local anim = HUDCustomizer.Anim
    local padX = 14 * scale

    local label = id
    for _, c in ipairs(HUDCustomizer.AvailableChips) do
        if c.id == id then label = c.label end
    end

    local hdrY = cy + 11 * scale
    Render.Text(Config.Fonts.Bold, 10 * scale, label, Vec2(cx + padX, hdrY), FadeColor(Config.Colors.TextPrimary, aMul))

    local closeR = 9 * scale
    local closeX = cx + cw - padX - closeR
    local closeY = hdrY + 5 * scale
    Render.FilledCircle(Vec2(closeX, closeY), closeR, FadeColor(Config.Colors.SegTrack, aMul), 0, 1.0, 20)
    local xs = Render.TextSize(Config.Fonts.Bold, 9 * scale, "\u{2715}")
    Render.Text(Config.Fonts.Bold, 9 * scale, "\u{2715}", Vec2(closeX - xs.x / 2, closeY - xs.y / 2), FadeColor(Config.Colors.TextSecondary, aMul))
    if aMul > 0.6 then
        table.insert(HUDCustomizer.InspectorBounds, { x1 = closeX - closeR, y1 = closeY - closeR, x2 = closeX + closeR, y2 = closeY + closeR, action = "close_inspector" })
    end

    local rowH = 30 * scale
    local segW = 172 * scale
    local segH = 24 * scale
    local segX = cx + cw - padX - segW
    local rowY = cy + 30 * scale

    RenderSettingsLabel(cx + padX, rowY, rowH, L("Начертание", "Weight"), scale, aMul)
    RenderSegmented(segX, rowY + (rowH - segH) / 2, segW, segH, SEG_WEIGHT, cfg.bold and 1 or 2, anim.SegWeight, dt, scale, aMul, "set_bold")

    rowY = rowY + rowH
    RenderSettingsLabel(cx + padX, rowY, rowH, L("Цвет", "Color"), scale, aMul)
    RenderSegmented(segX, rowY + (rowH - segH) / 2, segW, segH, SEG_COLOR, cfg.colorMode or 1, anim.SegColor, dt, scale, aMul, "set_color")

    if cfg.colorMode == 3 then
        rowY = rowY + rowH
        local curCol = cfg.customColor or GetDefaultWidgetColor(id)
        local curHex = cfg.customHex or select(2, GetDefaultWidgetColor(id))
        
        RenderSettingsLabel(cx + padX, rowY, rowH, L("Палитра", "Palette"), scale, aMul)
        local lblSize = Render.TextSize(Config.Fonts.Main, 10 * scale, L("Палитра", "Palette"))
        
        local prevR = 8 * scale
        local prevX = cx + padX + lblSize.x + 14 * scale
        local prevY = rowY + rowH / 2
        Render.Shadow(Vec2(prevX - prevR, prevY - prevR), Vec2(prevX + prevR, prevY + prevR), Color(0, 0, 0, math.floor(110 * aMul)), 6, prevR, Enum.DrawFlags.ShadowCutOutShapeBackground, Vec2(0, 1))
        Render.FilledCircle(Vec2(prevX, prevY), prevR, FadeColor(curCol, aMul), 0, 1.0, 22)
        local ringCol = HUDCustomizer.ColorPickerOpen and Config.Colors.Accent or Color(255, 255, 255, 170)
        Render.Circle(Vec2(prevX, prevY), prevR + 1.5 * scale, FadeColor(ringCol, aMul), 1.8 * scale)
        if aMul > 0.6 then
            table.insert(HUDCustomizer.InspectorBounds, { 
                x1 = prevX - prevR - 6 * scale, y1 = prevY - prevR - 6 * scale, 
                x2 = prevX + prevR + 6 * scale, y2 = prevY + prevR + 6 * scale, 
                action = "toggle_color_picker",
                px = prevX, py = prevY
            })
        end
        
        local barH = 8 * scale
        local barY = rowY + (rowH - barH) / 2
        local barR = barH / 2
        local segSteps = 48
        local midW = segW - barR * 2
        
        local c0r, c0g, c0b = HSVtoRGB(0, 0.90, 1.0)
        Render.FilledCircle(Vec2(segX + barR, barY + barR), barR, FadeColor(Color(c0r, c0g, c0b, 255), aMul), 0, 1.0, 16)
        local c1r, c1g, c1b = HSVtoRGB(360, 0.90, 1.0)
        Render.FilledCircle(Vec2(segX + segW - barR, barY + barR), barR, FadeColor(Color(c1r, c1g, c1b, 255), aMul), 0, 1.0, 16)
        
        for i = 0, segSteps - 1 do
            local h1 = (i / segSteps) * 360
            local hr, hg, hb = HSVtoRGB(h1, 0.90, 1.0)
            local x1 = segX + barR + (i / segSteps) * midW
            local x2 = segX + barR + ((i + 1) / segSteps) * midW + 0.6
            Render.FilledRect(Vec2(x1, barY), Vec2(x2, barY + barH), FadeColor(Color(hr, hg, hb, 255), aMul), 0)
        end
        Render.Rect(Vec2(segX, barY), Vec2(segX + segW, barY + barH), FadeColor(Color(255, 255, 255, 55), aMul), barR, Enum.DrawFlags.None, 1.0)
        
        local curHue = RGBtoHue(curCol.r, curCol.g, curCol.b)
        local knobX = segX + (curHue / 360) * segW
        local knobY = barY + barH / 2
        local knobR = 6.5 * scale
        
        Render.Shadow(Vec2(knobX - knobR, knobY - knobR), Vec2(knobX + knobR, knobY + knobR), Color(0, 0, 0, math.floor(120 * aMul)), 6, knobR, Enum.DrawFlags.ShadowCutOutShapeBackground, Vec2(0, 1.5))
        Render.FilledCircle(Vec2(knobX, knobY), knobR, FadeColor(Color(255, 255, 255, 255), aMul), 0, 1.0, 20)
        Render.FilledCircle(Vec2(knobX, knobY), knobR - 2.2 * scale, FadeColor(curCol, aMul), 0, 1.0, 16)
        Render.Circle(Vec2(knobX, knobY), knobR, FadeColor(Color(255, 255, 255, 220), aMul), 1.0)
        
        if aMul > 0.6 then
            table.insert(HUDCustomizer.InspectorBounds, { 
                x1 = segX - 4, y1 = barY - 5, 
                x2 = segX + segW + 4, y2 = barY + barH + 5, 
                action = "drag_hue", 
                barX = segX, barW = segW 
            })
        end
    end

    rowY = rowY + rowH
    RenderSettingsLabel(cx + padX, rowY, rowH, L("Формат", "Format"), scale, aMul)
    RenderSegmented(segX, rowY + (rowH - segH) / 2, segW, segH, SEG_FORMAT, cfg.format or 1, anim.SegFormat, dt, scale, aMul, "set_format")

    rowY = rowY + rowH
    RenderSettingsLabel(cx + padX, rowY, rowH, L("Иконка", "Icon"), scale, aMul)
    local swW, swH = 42 * scale, 25 * scale
    local swX = cx + cw - padX - swW
    local swY = rowY + (rowH - swH) / 2
    RenderSwitch(swX, swY, swW, swH, cfg.showIcon ~= false, anim.Knob, dt, aMul)
    if aMul > 0.6 then
        table.insert(HUDCustomizer.InspectorBounds, { x1 = swX, y1 = swY, x2 = swX + swW, y2 = swY + swH, action = "toggle_icon" })
    end
end

local function RenderColorPickerPopover(cx, cy, cardW, scale, dt)
    local anim = HUDCustomizer.Anim
    anim.ColorPickerT = anim.ColorPickerT or 0
    anim.ColorPickerT = math.min(1, math.max(0, anim.ColorPickerT + dt / 0.18 * (HUDCustomizer.ColorPickerOpen and 1 or -1.8)))
    if anim.ColorPickerT <= 0 then return end
    
    local id = HUDCustomizer.InspectedChip
    local cfg = id and HUDCustomizer.WidgetConfigs[id]
    if not cfg then return end
    
    local curCol = cfg.customColor or GetDefaultWidgetColor(id)
    local curHex = cfg.customHex or select(2, GetDefaultWidgetColor(id))
    if not curHex then curHex = string.format("%02X%02X%02X", curCol.r, curCol.g, curCol.b) end
    local curHue, curSat, curVal = RGBtoHSV(curCol.r, curCol.g, curCol.b)
    
    local popW = 216 * scale
    local popH = 196 * scale
    local scr = Render.ScreenSize()
    local scrW, scrH = scr.x, scr.y
    local popX = cx + cardW + 10 * scale
    local popY = cy + 32 * scale
    if popX + popW > scrW - 10 then
        popX = cx - popW - 10 * scale
    end
    if popX < 10 then
        popX = math.floor(cx + (cardW - popW) / 2)
        popY = cy + 180 * scale
    end
    if popY + popH > scrH - 10 then
        popY = scrH - popH - 10
    end
    if popY < 10 then popY = 10 end
    
    local popA = anim.ColorPickerT
    local p1 = Vec2(popX, popY)
    local p2 = Vec2(popX + popW, popY + popH)
    local popRad = 14 * scale
    
    Render.Shadow(p1, p2, Color(0, 0, 0, math.floor(220 * popA)), 28, popRad, Enum.DrawFlags.ShadowCutOutShapeBackground, Vec2(0, 8))
    DrawerSurface(p1, p2, popRad, popA)
    
    local pad = 12 * scale
    local hdrY = popY + 11 * scale
    Render.Text(Config.Fonts.Bold, 10 * scale, L("Выбор цвета", "Color Picker"), Vec2(popX + pad, hdrY), FadeColor(Config.Colors.TextPrimary, popA))
    
    local hexLabel = "#" .. string.upper(curHex)
    local hexSz = Render.TextSize(Config.Fonts.Bold, 8.5 * scale, hexLabel)
    local hexPillW = hexSz.x + 8 * scale
    local hexPillH = 15 * scale
    local hexPillX = popX + pad + 82 * scale
    local hexPillY = hdrY - 1 * scale
    Render.FilledRect(Vec2(hexPillX, hexPillY), Vec2(hexPillX + hexPillW, hexPillY + hexPillH), FadeColor(Config.Colors.SegTrack, popA), 4 * scale)
    Render.Text(Config.Fonts.Bold, 8.5 * scale, hexLabel, Vec2(hexPillX + 4 * scale, hexPillY + 1 * scale), FadeColor(Config.Colors.TextSecondary, popA))
    
    local closeR = 8 * scale
    local closeX = popX + popW - pad - closeR
    local closeY = hdrY + 6 * scale
    Render.FilledCircle(Vec2(closeX, closeY), closeR, FadeColor(Config.Colors.SegTrack, popA), 0, 1.0, 18)
    local xs = Render.TextSize(Config.Fonts.Bold, 8 * scale, "\u{2715}")
    Render.Text(Config.Fonts.Bold, 8 * scale, "\u{2715}", Vec2(closeX - xs.x / 2, closeY - xs.y / 2), FadeColor(Config.Colors.TextSecondary, popA))
    
    if popA > 0.6 then
        table.insert(HUDCustomizer.InspectorBounds, {
            x1 = closeX - closeR - 4, y1 = closeY - closeR - 4,
            x2 = closeX + closeR + 4, y2 = closeY + closeR + 4,
            action = "close_color_picker"
        })
    end
    
    local canvasX = popX + pad
    local canvasY = popY + 28 * scale
    local canvasW = popW - pad * 2
    local canvasH = 82 * scale
    local cStepsX = 18
    local cStepsY = 10
    local stepW = canvasW / cStepsX
    local stepH = canvasH / cStepsY
    
    for xi = 0, cStepsX - 1 do
        local s = xi / (cStepsX - 1)
        for yi = 0, cStepsY - 1 do
            local v = 1.0 - (yi / (cStepsY - 1))
            local cr, cg, cb = HSVtoRGB(curHue, s, v)
            Render.FilledRect(Vec2(canvasX + xi * stepW, canvasY + yi * stepH), Vec2(canvasX + (xi + 1) * stepW + 0.6, canvasY + (yi + 1) * stepH + 0.6), FadeColor(Color(cr, cg, cb, 255), popA), 0)
        end
    end
    Render.Rect(Vec2(canvasX, canvasY), Vec2(canvasX + canvasW, canvasY + canvasH), FadeColor(Color(255, 255, 255, 45), popA), 4 * scale, Enum.DrawFlags.None, 1.0)
    
    local reticleX = canvasX + curSat * canvasW
    local reticleY = canvasY + (1.0 - curVal) * canvasH
    Render.Shadow(Vec2(reticleX - 5 * scale, reticleY - 5 * scale), Vec2(reticleX + 5 * scale, reticleY + 5 * scale), Color(0, 0, 0, math.floor(140 * popA)), 4, 5 * scale, Enum.DrawFlags.ShadowCutOutShapeBackground, Vec2(0, 1))
    Render.FilledCircle(Vec2(reticleX, reticleY), 4.5 * scale, FadeColor(Color(255, 255, 255, 255), popA), 0, 1.0, 18)
    Render.FilledCircle(Vec2(reticleX, reticleY), 2.8 * scale, FadeColor(curCol, popA), 0, 1.0, 16)
    Render.Circle(Vec2(reticleX, reticleY), 4.5 * scale, FadeColor(Color(255, 255, 255, 240), popA), 1.2 * scale)
    
    if popA > 0.6 then
        table.insert(HUDCustomizer.InspectorBounds, {
            x1 = canvasX - 2, y1 = canvasY - 2,
            x2 = canvasX + canvasW + 2, y2 = canvasY + canvasH + 2,
            action = "drag_pop_sv",
            x = canvasX, y = canvasY, w = canvasW, h = canvasH, id = id
        })
    end
    
    local hBarY = canvasY + canvasH + 9 * scale
    local hBarH = 8 * scale
    local hBarR = hBarH / 2
    local hSteps = 36
    local hMidW = canvasW - hBarR * 2
    
    local hc0r, hc0g, hc0b = HSVtoRGB(0, 0.90, 1.0)
    Render.FilledCircle(Vec2(canvasX + hBarR, hBarY + hBarR), hBarR, FadeColor(Color(hc0r, hc0g, hc0b, 255), popA), 0, 1.0, 16)
    local hc1r, hc1g, hc1b = HSVtoRGB(360, 0.90, 1.0)
    Render.FilledCircle(Vec2(canvasX + canvasW - hBarR, hBarY + hBarR), hBarR, FadeColor(Color(hc1r, hc1g, hc1b, 255), popA), 0, 1.0, 16)
    
    for i = 0, hSteps - 1 do
        local h1 = (i / hSteps) * 360
        local hr, hg, hb = HSVtoRGB(h1, 0.90, 1.0)
        local x1 = canvasX + hBarR + (i / hSteps) * hMidW
        local x2 = canvasX + hBarR + ((i + 1) / hSteps) * hMidW + 0.6
        Render.FilledRect(Vec2(x1, hBarY), Vec2(x2, hBarY + hBarH), FadeColor(Color(hr, hg, hb, 255), popA), 0)
    end
    Render.Rect(Vec2(canvasX, hBarY), Vec2(canvasX + canvasW, hBarY + hBarH), FadeColor(Color(255, 255, 255, 45), popA), hBarR, Enum.DrawFlags.None, 1.0)
    
    local hKnobX = canvasX + (curHue / 360) * canvasW
    local hKnobY = hBarY + hBarH / 2
    local hKnobR = 5.5 * scale
    local hHueR, hHueG, hHueB = HSVtoRGB(curHue, 0.90, 1.0)
    Render.Shadow(Vec2(hKnobX - hKnobR, hKnobY - hKnobR), Vec2(hKnobX + hKnobR, hKnobY + hKnobR), Color(0, 0, 0, math.floor(120 * popA)), 5, hKnobR, Enum.DrawFlags.ShadowCutOutShapeBackground, Vec2(0, 1))
    Render.FilledCircle(Vec2(hKnobX, hKnobY), hKnobR, FadeColor(Color(255, 255, 255, 255), popA), 0, 1.0, 18)
    Render.FilledCircle(Vec2(hKnobX, hKnobY), hKnobR - 1.8 * scale, FadeColor(Color(hHueR, hHueG, hHueB, 255), popA), 0, 1.0, 16)
    Render.Circle(Vec2(hKnobX, hKnobY), hKnobR, FadeColor(Color(255, 255, 255, 220), popA), 1.0)
    
    if popA > 0.6 then
        table.insert(HUDCustomizer.InspectorBounds, {
            x1 = canvasX - 2, y1 = hBarY - 4,
            x2 = canvasX + canvasW + 2, y2 = hBarY + hBarH + 4,
            action = "drag_pop_hue",
            x = canvasX, w = canvasW, id = id
        })
    end
    
    local bBarY = hBarY + 14 * scale
    local bBarH = 8 * scale
    local bBarR = bBarH / 2
    local bSteps = 24
    local bMidW = canvasW - bBarR * 2
    
    local bc0r, bc0g, bc0b = HSVtoRGB(curHue, curSat, 0)
    Render.FilledCircle(Vec2(canvasX + bBarR, bBarY + bBarR), bBarR, FadeColor(Color(bc0r, bc0g, bc0b, 255), popA), 0, 1.0, 16)
    local bc1r, bc1g, bc1b = HSVtoRGB(curHue, curSat, 1.0)
    Render.FilledCircle(Vec2(canvasX + canvasW - bBarR, bBarY + bBarR), bBarR, FadeColor(Color(bc1r, bc1g, bc1b, 255), popA), 0, 1.0, 16)
    
    for i = 0, bSteps - 1 do
        local frac = i / (bSteps - 1)
        local br, bg, bb = HSVtoRGB(curHue, curSat, frac)
        local x1 = canvasX + bBarR + (i / bSteps) * bMidW
        local x2 = canvasX + bBarR + ((i + 1) / bSteps) * bMidW + 0.6
        Render.FilledRect(Vec2(x1, bBarY), Vec2(x2, bBarY + bBarH), FadeColor(Color(br, bg, bb, 255), popA), 0)
    end
    Render.Rect(Vec2(canvasX, bBarY), Vec2(canvasX + canvasW, bBarY + bBarH), FadeColor(Color(255, 255, 255, 45), popA), bBarR, Enum.DrawFlags.None, 1.0)
    
    local bKnobX = canvasX + curVal * canvasW
    local bKnobY = bBarY + bBarH / 2
    local bKnobR = 5.5 * scale
    Render.Shadow(Vec2(bKnobX - bKnobR, bKnobY - bKnobR), Vec2(bKnobX + bKnobR, bKnobY + bKnobR), Color(0, 0, 0, math.floor(120 * popA)), 5, bKnobR, Enum.DrawFlags.ShadowCutOutShapeBackground, Vec2(0, 1))
    Render.FilledCircle(Vec2(bKnobX, bKnobY), bKnobR, FadeColor(Color(255, 255, 255, 255), popA), 0, 1.0, 18)
    Render.FilledCircle(Vec2(bKnobX, bKnobY), bKnobR - 1.8 * scale, FadeColor(curCol, popA), 0, 1.0, 16)
    Render.Circle(Vec2(bKnobX, bKnobY), bKnobR, FadeColor(Color(255, 255, 255, 220), popA), 1.0)
    
    if popA > 0.6 then
        table.insert(HUDCustomizer.InspectorBounds, {
            x1 = canvasX - 2, y1 = bBarY - 4,
            x2 = canvasX + canvasW + 2, y2 = bBarY + bBarH + 4,
            action = "drag_pop_val",
            x = canvasX, w = canvasW, id = id
        })
    end
    
    local btmY = bBarY + 17 * scale
    local previewR = 8 * scale
    Render.Shadow(Vec2(canvasX, btmY), Vec2(canvasX + previewR * 2, btmY + previewR * 2), Color(0, 0, 0, math.floor(100 * popA)), 5, previewR, Enum.DrawFlags.ShadowCutOutShapeBackground, Vec2(0, 1))
    Render.FilledCircle(Vec2(canvasX + previewR, btmY + previewR), previewR, FadeColor(curCol, popA), 0, 1.0, 20)
    Render.Circle(Vec2(canvasX + previewR, btmY + previewR), previewR + 1.2 * scale, FadeColor(Color(255, 255, 255, 170), popA), 1.2 * scale)
    
    local QUICK_COLORS = {
        { 255, 255, 255, "FFFFFF" },
        { 255, 214, 10,  "FFD60A" },
        { 48,  209, 88,  "30D158" },
        { 10,  132, 255, "0A84FF" },
        { 191, 90,  242, "BF5AF2" },
        { 255, 69,  58,  "FF453A" }
    }
    local qDotR = 5.5 * scale
    local qStartX = canvasX + previewR * 2 + 8 * scale
    for qi, q in ipairs(QUICK_COLORS) do
        local qx = qStartX + (qi - 1) * (qDotR * 2 + 5 * scale)
        local qy = btmY + previewR
        Render.FilledCircle(Vec2(qx, qy), qDotR, FadeColor(Color(q[1], q[2], q[3], 255), popA), 0, 1.0, 16)
        if curHex == q[4] then
            Render.Circle(Vec2(qx, qy), qDotR + 2 * scale, FadeColor(Color(255, 255, 255, 240), popA), 1.5 * scale)
        end
        if popA > 0.6 then
            table.insert(HUDCustomizer.InspectorBounds, {
                x1 = qx - qDotR - 2, y1 = qy - qDotR - 2,
                x2 = qx + qDotR + 2, y2 = qy + qDotR + 2,
                action = "pop_pick_quick",
                r = q[1], g = q[2], b = q[3], hex = q[4], id = id
            })
        end
    end
    
    local rstText = L("Сброс", "Reset")
    local rstS = Render.TextSize(Config.Fonts.Main, 8.5 * scale, rstText)
    local rstW = rstS.x + 12 * scale
    local rstH = 18 * scale
    local rstX = popX + popW - pad - rstW
    local rstY = btmY + previewR - rstH / 2
    Render.FilledRect(Vec2(rstX, rstY), Vec2(rstX + rstW, rstY + rstH), FadeColor(Config.Colors.SegTrack, popA), rstH / 2)
    Render.Text(Config.Fonts.Main, 8.5 * scale, rstText, Vec2(rstX + (rstW - rstS.x) / 2, rstY + (rstH - rstS.y) / 2 - 1), FadeColor(Config.Colors.TextSecondary, popA))
    
    if popA > 0.6 then
        table.insert(HUDCustomizer.InspectorBounds, {
            x1 = rstX, y1 = rstY, x2 = rstX + rstW, y2 = rstY + rstH,
            action = "pop_reset", id = id
        })
        table.insert(HUDCustomizer.InspectorBounds, {
            x1 = popX, y1 = popY, x2 = popX + popW, y2 = popY + popH,
            action = "pop_noop"
        })
    end
end

local function RenderHUDDrawer(layout, dt)
    local anim = HUDCustomizer.Anim
    if not HUDCustomizer.IsOpen and anim.t <= 0 then
        anim.h, anim.hVel = 0, 0
        HUDCustomizer.DrawerBounds = {}
        HUDCustomizer.InspectorBounds = {}
        return
    end

    local scale = layout.scale
    anim.t = math.min(1, math.max(0, anim.t + dt / 0.42 * (HUDCustomizer.IsOpen and 1 or -1.4)))

    local emerge = EaseOutCubic(anim.t / 0.55)
    local widen = EaseOutBack((anim.t - 0.28) / 0.72)
    local contentA = math.min(1, math.max(0, (anim.t - 0.58) / 0.42))

    local cardW = math.floor(300 * scale)
    local padX = 14 * scale
    local gap = 7 * scale
    local chipW = (cardW - padX * 2 - gap * 3) / 4
    local chipH = 30 * scale
    local chipsTop = 36 * scale
    local baseH = chipsTop + chipH * 2 + gap + 12 * scale

    local hintsOn = UI.Media.Hints:Get()
    local idInspected = HUDCustomizer.InspectedChip
    local cfgInspected = idInspected and HUDCustomizer.WidgetConfigs[idInspected]
    local isCustomColor = cfgInspected and (cfgInspected.colorMode == 3)
    local extraH = isCustomColor and (30 * scale) or 0
    local targetH = baseH + (idInspected and (162 * scale + extraH) or 0) + (hintsOn and 22 * scale or 0)

    if anim.LastId ~= HUDCustomizer.InspectedChip then
        anim.LastId = HUDCustomizer.InspectedChip
        local cfg = HUDCustomizer.WidgetConfigs[HUDCustomizer.InspectedChip]
        if cfg then
            anim.SegWeight.v, anim.SegWeight.vel = cfg.bold and 0 or 1, 0
            anim.SegColor.v, anim.SegColor.vel = (cfg.colorMode or 1) - 1, 0
            anim.SegFormat.v, anim.SegFormat.vel = (cfg.format or 1) - 1, 0
            anim.Knob.v, anim.Knob.vel = cfg.showIcon ~= false and 1 or 0, 0
        end
    end

    if anim.h <= 0 then
        anim.h, anim.hVel = targetH, 0
    else
        anim.h, anim.hVel = SolveDampedSpring(anim.h, anim.hVel, targetH, dt, 18.0, 0.84)
    end

    local panelW = layout.w + (cardW - layout.w) * widen
    local panelH = anim.h * emerge
    local px = math.floor(layout.x + (layout.w - panelW) / 2)
    local py = math.floor(layout.y + layout.h + 10 * scale * emerge)
    local rad = math.min(22 * scale, panelH / 2)

    local p1 = Vec2(px, py)
    local p2 = Vec2(px + panelW, py + panelH)

    HUDCustomizer.TotalUIBounds = {
        { x1 = layout.x - 4, y1 = layout.y - 4, x2 = layout.x + layout.w + 4, y2 = layout.y + layout.h + 4 },
        { x1 = px - 4, y1 = py - 4, x2 = px + panelW + 4, y2 = py + panelH + 4 }
    }

    Render.Shadow(p1, p2, Color(0, 0, 0, math.floor(200 * emerge)), 26, rad, Enum.DrawFlags.ShadowCutOutShapeBackground, Vec2(0, 6))
    DrawerSurface(p1, p2, rad, emerge)

    HUDCustomizer.DrawerBounds = {}
    HUDCustomizer.InspectorBounds = {}

    Render.PushClip(p1, p2)

    local cx = math.floor(layout.x + (layout.w - cardW) / 2)
    local grabW = 34 * scale
    Render.FilledRect(Vec2(cx + (cardW - grabW) / 2, py + 8 * scale), Vec2(cx + (cardW + grabW) / 2, py + 12 * scale), FadeColor(Config.Colors.Grabber, contentA), 2 * scale)
    Render.Text(Config.Fonts.Bold, 10 * scale, L("Виджеты", "Widgets"), Vec2(cx + padX, py + 19 * scale), FadeColor(Config.Colors.TextSecondary, contentA))

    local chipY = py + chipsTop
    for i, chip in ipairs(HUDCustomizer.AvailableChips) do
        local bx = math.floor(cx + padX + ((i - 1) % 4) * (chipW + gap))
        local by = math.floor(chipY + math.floor((i - 1) / 4) * (chipH + gap))
        local active = IsChipInActiveList(chip.id)

        local ca = ChipAnim(chip.id)
        ca.fill, ca.fillVel = SolveDampedSpring(ca.fill, ca.fillVel, active and 1 or 0, dt, 20.0, 0.86)
        ca.scale, ca.scaleVel = SolveDampedSpring(ca.scale, ca.scaleVel, 1.0, dt, 30.0, 0.52)
        local insetX = chipW * (1 - ca.scale) / 2
        local insetY = chipH * (1 - ca.scale) / 2
        local q1 = Vec2(bx + insetX, by + insetY)
        local q2 = Vec2(bx + chipW - insetX, by + chipH - insetY)
        local qr = (chipH - insetY * 2) / 2

        Render.FilledRect(q1, q2, FadeColor(LerpColor(Config.Colors.ChipInactive, Config.Colors.ChipActiveBorder, ca.fill), contentA), qr)
        Render.Rect(q1, q2, FadeColor(Config.Colors.ChipInactiveBorder, contentA * (1 - ca.fill)), qr, Enum.DrawFlags.None, 1.0)
        if HUDCustomizer.InspectedChip == chip.id then
            Render.Rect(Vec2(q1.x - 2 * scale, q1.y - 2 * scale), Vec2(q2.x + 2 * scale, q2.y + 2 * scale), FadeColor(Config.Colors.Accent, contentA), qr + 2 * scale, Enum.DrawFlags.None, 1.5)
        end

        local f = ca.fill > 0.5 and Config.Fonts.Bold or Config.Fonts.Main
        local ls = Render.TextSize(f, 9.5 * scale, chip.label)
        Render.Text(f, 9.5 * scale, chip.label, Vec2(math.floor(bx + (chipW - ls.x) / 2), math.floor(by + (chipH - ls.y) / 2 - 1)), FadeColor(LerpColor(Config.Colors.TextSecondary, Config.Colors.TextInverse, ca.fill), contentA))

        if contentA > 0.6 then
            table.insert(HUDCustomizer.DrawerBounds, { x1 = bx, y1 = by, x2 = bx + chipW, y2 = by + chipH, id = chip.id, action = "toggle" })
        end
    end

    if HUDCustomizer.InspectedChip then
        RenderWidgetSettings(cx, cardW, py + baseH - 12 * scale, scale, contentA, dt)
    end

    if hintsOn then
        local hint = L("ПКМ \u{2014} настройки  \u{2022}  ЛКМ \u{2014} вкл/выкл  \u{2022}  перетаскивание \u{2014} порядок", "RMB \u{2014} settings  \u{2022}  LMB \u{2014} toggle  \u{2022}  drag \u{2014} reorder")
        local hs = Render.TextSize(Config.Fonts.Main, 8.5 * scale, hint)
        Render.Text(Config.Fonts.Main, 8.5 * scale, hint, Vec2(math.floor(cx + (cardW - hs.x) / 2), math.floor(py + anim.h - 17 * scale)), FadeColor(Config.Colors.TextMuted, contentA))
    end

    Render.PopClip()
    
    if HUDCustomizer.IsOpen and HUDCustomizer.InspectedChip then
        RenderColorPickerPopover(px, py, cardW, scale, dt)
    end
end

local function RenderSecondarySatelliteBubble(layout)
    if not UI.Media.SecondaryBubble:Get() then return end
    if HUDCustomizer.IsOpen then return end
    
    local inCombat = FightTracker.Active
    local scale = layout.scale
    local fontBold = Config.Fonts.Bold
    local fontMain = Config.Fonts.Main
    local now = GameRules.GetGameTime()
    
    if inCombat then
        local hasSatelliteContent = NotificationQueue.Active or IsMediaActive()
        if not hasSatelliteContent then
            SatelliteBounds = nil
            ButtonHits.SatellitePrev = nil
            ButtonHits.SatellitePlay = nil
            ButtonHits.SatelliteNext = nil
            return
        end
        
        local bubbleH = math.floor(Config.Dimensions.CompactH * scale)
        local bubbleR = math.floor(Config.Dimensions.CompactRadius * scale)
        local isHovered = FightTracker.SatelliteHover
        local bubbleW = math.floor(34 * scale)
        if isHovered and IsMediaActive() then
            bubbleW = math.floor(136 * scale)
        end
        local bx = math.floor(layout.x + layout.w + 8 * scale)
        local by = math.floor(layout.y)
        
        SatelliteBounds = { x1 = bx, y1 = by, x2 = bx + bubbleW, y2 = by + bubbleH }
        
        local p1 = Vec2(bx, by)
        local p2 = Vec2(bx + bubbleW, by + bubbleH)
        
        if UI.Media.Shadow:Get() then
            Render.Shadow(p1, p2, Config.Colors.Shadow, 14, bubbleR, Enum.DrawFlags.ShadowCutOutShapeBackground, Vec2(0, 3))
        end
        
        IslandSurface(p1, p2, bubbleR, Config.Colors.Border)
        
        if NotificationQueue.Active then
            ButtonHits.SatellitePrev = nil
            ButtonHits.SatellitePlay = nil
            ButtonHits.SatelliteNext = nil
            local notif = NotificationQueue.Active
            local iconSize = math.floor(16 * scale)
            local iconX = math.floor(bx + 8 * scale)
            local iconY = math.floor(by + (bubbleH - iconSize) / 2)
            local hIcon = GetCachedImage(notif.Icon, notif.FallbackSvg)
            if hIcon then
                Render.Image(hIcon, Vec2(iconX, iconY), Vec2(iconSize, iconSize), Color(255, 255, 255, 255), 3 * scale)
            end
        elseif IsMediaActive() then
            local thumbSize = math.floor(20 * scale)
            local thumbX = math.floor(bx + (isHovered and (7 * scale) or ((bubbleW - thumbSize) / 2)))
            local thumbY = math.floor(by + (bubbleH - thumbSize) / 2)
            DrawAlbumThumbnail(thumbX, thumbY, thumbSize, 4 * scale, 1.0)
            
            if isHovered then
                ButtonHits.SatellitePrev = { x1 = bx + 30 * scale, y1 = by, x2 = bx + 58 * scale, y2 = by + bubbleH }
                ButtonHits.SatellitePlay = { x1 = bx + 60 * scale, y1 = by, x2 = bx + 94 * scale, y2 = by + bubbleH }
                ButtonHits.SatelliteNext = { x1 = bx + 96 * scale, y1 = by, x2 = bx + 130 * scale, y2 = by + bubbleH }
                
                local pScale = ButtonSprings.SatellitePrev.scale
                local plScale = ButtonSprings.SatellitePlay.scale
                local nScale = ButtonSprings.SatelliteNext.scale
                
                local prevSz = math.floor(14 * scale * pScale)
                local hPrev = GetVectorIcon("media_prev")
                if hPrev then
                    local pX = math.floor(bx + 44 * scale - prevSz / 2)
                    local pY = math.floor(by + (bubbleH - prevSz) / 2)
                    Render.Image(hPrev, Vec2(pX, pY), Vec2(prevSz, prevSz), Config.Colors.TextPrimary, 0)
                end
                
                local playSz = math.floor(16 * scale * plScale)
                local playIconName = MediaData.IsPlaying and "media_pause" or "media_play"
                local hPlay = GetVectorIcon(playIconName)
                if hPlay then
                    local plX = math.floor(bx + 77 * scale - playSz / 2)
                    local plY = math.floor(by + (bubbleH - playSz) / 2)
                    Render.Image(hPlay, Vec2(plX, plY), Vec2(playSz, playSz), Config.Colors.TextPrimary, 0)
                end
                
                local nextSz = math.floor(14 * scale * nScale)
                local hNext = GetVectorIcon("media_next")
                if hNext then
                    local nX = math.floor(bx + 112 * scale - nextSz / 2)
                    local nY = math.floor(by + (bubbleH - nextSz) / 2)
                    Render.Image(hNext, Vec2(nX, nY), Vec2(nextSz, nextSz), Config.Colors.TextPrimary, 0)
                end
            else
                ButtonHits.SatellitePrev = nil
                ButtonHits.SatellitePlay = nil
                ButtonHits.SatelliteNext = nil
            end
        end
        return
    end
    
    if StateMachine.TargetState ~= StateMachine.States.COMPACT_IDLE and StateMachine.TargetState ~= StateMachine.States.COMPACT_MEDIA then return end
    if GameTracker.Roshan.Dismissed then return end
    
    local isRoshanActive = GameTracker.Roshan.DeathTime > 0
    if isRoshanActive then
        local bubbleH = math.floor(Config.Dimensions.CompactH * scale)
        local bubbleW = math.floor(58 * scale)
        local bubbleR = math.floor(Config.Dimensions.CompactRadius * scale)
        local bx = math.floor(layout.x + layout.w + 8 * scale)
        local by = math.floor(layout.y)
        
        SatelliteBounds = { x1 = bx, y1 = by, x2 = bx + bubbleW, y2 = by + bubbleH }
        
        local p1 = Vec2(bx, by)
        local p2 = Vec2(bx + bubbleW, by + bubbleH)
        
        if UI.Media.Shadow:Get() then
            Render.Shadow(p1, p2, Config.Colors.Shadow, 14, bubbleR, Enum.DrawFlags.ShadowCutOutShapeBackground, Vec2(0, 3))
        end
        
        IslandSurface(p1, p2, bubbleR, Config.Colors.Border)
        
        local iconSize = math.floor(15 * scale)
        local iconX = math.floor(bx + 7 * scale)
        local iconY = math.floor(by + (bubbleH - iconSize) / 2)
        
        local aegisH = GetCachedImage("panorama/images/items/aegis_png.vtex_c")
        if aegisH then
            Render.Image(aegisH, Vec2(iconX, iconY), Vec2(iconSize, iconSize), Color(255, 255, 255, 255), 3 * scale)
        end
        
        local timeStr = ""
        if now < GameTracker.Roshan.AegisExpiryTime then
            local rem = GameTracker.Roshan.AegisExpiryTime - now
            timeStr = FormatTime(rem)
        else
            local minRem = math.max(0, GameTracker.Roshan.RespawnMinTime - now)
            timeStr = FormatTime(minRem)
        end
        
        local tSize = Render.TextSize(fontBold, 10 * scale, timeStr)
        local tx = math.floor(iconX + iconSize + 5 * scale)
        local ty = math.floor(by + (bubbleH - tSize.y) / 2 - 1)
        Render.Text(fontBold, 10 * scale, timeStr, Vec2(tx, ty), Config.Colors.TextPrimary)
    else
        SatelliteBounds = nil
    end
end

local function RenderMenuClosedHint(layout)
    if not UI.Media.Hints:Get() then return end
    if not Menu.Opened or not Menu.Opened() then return end
    if HUDCustomizer.IsOpen then return end
    if DragState.IsDragging then return end
    
    local scale = layout.scale
    local fontMain = Config.Fonts.Main
    local hintText = L("Ctrl + ЛКМ : Перемещение   •   ПКМ : Редактор виджетов", "Ctrl + LMB : Drag   •   RMB : Quick HUD")
    local htSize = Render.TextSize(fontMain, 9.5 * scale, hintText)
    local hBoxW = math.floor(htSize.x + 18 * scale)
    local hBoxH = math.floor(18 * scale)
    local hBoxX = math.floor(layout.x + (layout.w - hBoxW) / 2)
    local hintY = math.floor(layout.y + layout.h + 8 * scale)
    
    Render.FilledRect(Vec2(hBoxX, hintY), Vec2(hBoxX + hBoxW, hintY + hBoxH), Config.Colors.HintBg, 9 * scale)
    Render.Rect(Vec2(hBoxX, hintY), Vec2(hBoxX + hBoxW, hintY + hBoxH), Config.Colors.HintBorder, 9 * scale, Enum.DrawFlags.None, 1.0)
    Render.Text(fontMain, 9.5 * scale, hintText, Vec2(hBoxX + 9 * scale, hintY + (hBoxH - htSize.y) / 2 - 1), Config.Colors.TextSecondary)
end

local function RenderCompactMedia(layout, alphaMul, yOffset)
    local aMul = alphaMul or 1.0
    local yOff = yOffset or 0
    local scale = layout.scale
    local fontBold = Config.Fonts.Bold
    local textCol = FadeColor(Config.Colors.TextPrimary, aMul)
    local waveCol = MediaData.CoverColor or GetPrimaryThemeColor()
    
    local thumbSize = math.floor(20 * scale)
    local thumbX = math.floor(layout.x + 8 * scale)
    local thumbY = math.floor(layout.y + (layout.h - thumbSize) / 2 + yOff)
    
    local waveCount = 5
    local waveW = math.floor(waveCount * (2.4 * scale) + (waveCount - 1) * (1.8 * scale))
    local waveX = math.floor(layout.x + layout.w - waveW - 10 * scale)
    local waveY = math.floor(layout.y + (layout.h - 18 * scale) / 2 + yOff)
    
    local textStartX = math.floor(thumbX + thumbSize + 8 * scale)
    local textAvailW = math.max(10, math.floor((waveX - 4 * scale) - textStartX))
    
    local displayStr = MediaData.Title ~= "" and MediaData.Title or L("Музыка", "Music")
    if MediaData.Artist ~= "" and MediaData.Title ~= "" then
        displayStr = MediaData.Title .. " • " .. MediaData.Artist
    end
    
    local tH = 12 * scale
    local textY = math.floor(layout.y + (layout.h - tH) / 2 - 1 + yOff)
    
    local nowClk = os.clock()
    if TrackTransition.Active then
        local t = math.min(1.0, (nowClk - TrackTransition.StartTime) / (TrackTransition.Duration * AnimScale()))
        local dir = TrackTransition.Direction
        local outOffset = -dir * (t * 18 * scale)
        local outAlpha = (1.0 - t) * aMul
        local inOffset = dir * ((1.0 - t) * 18 * scale)
        local inAlpha = t * aMul
        
        if outAlpha > 0.02 and TrackTransition.OldTitle ~= "" then
            local oldStr = TrackTransition.OldTitle .. (TrackTransition.OldArtist ~= "" and (" • " .. TrackTransition.OldArtist) or "")
            RenderMarqueeText(fontBold, 12 * scale, oldStr, textStartX + outOffset, textY, textAvailW, FadeColor(Config.Colors.TextPrimary, outAlpha), scale, false)
            DrawAlbumThumbnail(thumbX, thumbY, thumbSize, 5 * scale, outAlpha, 1.0 - t * 0.15, TrackTransition.OldCoverHandle, TrackTransition.OldCoverColor)
        end
        if inAlpha > 0.02 then
            RenderMarqueeText(fontBold, 12 * scale, displayStr, textStartX + inOffset, textY, textAvailW, FadeColor(Config.Colors.TextPrimary, inAlpha), scale, false)
            DrawAlbumThumbnail(thumbX, thumbY, thumbSize, 5 * scale, inAlpha, 0.85 + t * 0.15)
        end
        if t >= 1.0 then
            TrackTransition.Active = false
        end
    else
        RenderMarqueeText(fontBold, 12 * scale, displayStr, textStartX, textY, textAvailW, textCol, scale, false)
        DrawAlbumThumbnail(thumbX, thumbY, thumbSize, 5 * scale, aMul)
    end
    
    DrawAppleWaveform(waveX, waveY, 18, waveCount, MediaData.IsPlaying, scale, waveCol, aMul)
end

local function RenderFightCompact(layout, alphaMul, yOffset)
    local aMul = alphaMul or 1.0
    local yOff = yOffset or 0
    local scale = layout.scale
    local fontBold = Config.Fonts.Bold
    local fontMain = Config.Fonts.Main
    
    local iconSz = math.floor(16 * scale)
    local iconX = math.floor(layout.x + 10 * scale)
    local iconY = math.floor(layout.y + (layout.h - iconSz) / 2 + yOff)
    
    local swordsSvg = GetVectorIcon("swords")
    if swordsSvg then
        Render.Image(swordsSvg, Vec2(iconX, iconY), Vec2(iconSz, iconSz), FadeColor(Color(255, 69, 58, 255), aMul), 0)
    else
        Render.FilledCircle(Vec2(iconX + iconSz / 2, iconY + iconSz / 2), iconSz / 2, FadeColor(Config.Colors.Red, aMul), 0, 1.0, 18)
    end
    
    local scoreStr = string.format("%d v %d", FightTracker.AllyCount, FightTracker.EnemyCount)
    local lmarkStr = FightTracker.Landmark ~= "" and FightTracker.Landmark or "Fight"
    local fullText = scoreStr .. " • " .. lmarkStr
    
    local textStartX = math.floor(iconX + iconSz + 8 * scale)
    local textAvailW = math.max(10, math.floor(layout.x + layout.w - textStartX - 10 * scale))
    local tH = 11.5 * scale
    local textY = math.floor(layout.y + (layout.h - tH) / 2 - 1 + yOff)
    
    RenderMarqueeText(fontBold, 11.5 * scale, fullText, textStartX, textY, textAvailW, FadeColor(Config.Colors.TextPrimary, aMul), scale, false)
end

local CachedDotaMapHandle = nil
local function GetDotaMapTexture()
    if CachedDotaMapHandle ~= nil then return CachedDotaMapHandle end
    local mapCandidates = {
        "dota_map.png",
        "scripts/dota_map.png",
        "C:/Umbrella/scripts/dota_map.png",
        "panorama/images/minimap/dotamap_psd.vtex_c",
        "materials/overviews/dota_737_psd_28d44696.vtex_c",
        "materials/overviews/dota_minimal_737_psd_cc590ee0.vtex_c",
        "materials/overviews/dota_psd.vtex_c",
        "panorama/images/minimap/background_png.vtex_c",
        "panorama/images/textures/minimap_game_png.vtex_c"
    }
    for _, mp in ipairs(mapCandidates) do
        local h = GetCachedImage(mp)
        if h and h > 0 then
            CachedDotaMapHandle = h
            return h
        end
    end
    CachedDotaMapHandle = false
    return nil
end

local function RenderFightLarge(layout, alphaMul, yOffset)
    local aMul = alphaMul or 1.0
    local yOff = yOffset or 0
    local scale = layout.scale
    local fontBold = Config.Fonts.Bold
    local fontMain = Config.Fonts.Main
    local textCol = FadeColor(Config.Colors.TextPrimary, aMul)
    local subCol = FadeColor(Config.Colors.TextSecondary, aMul)
    
    local padX = math.floor(16 * scale)
    local padY = math.floor(14 * scale)
    local radarSz = math.floor(120 * scale)
    local radarX = math.floor(layout.x + layout.w - 14 * scale - radarSz)
    local radarY = math.floor(layout.y + (layout.h - radarSz) / 2 + yOff)
    
    local headerScore = string.format("%d x %d %s", FightTracker.AllyCount, FightTracker.EnemyCount, L("Бой", "Fight"))
    local lmark = FightTracker.Landmark ~= "" and FightTracker.Landmark or L("Карта", "Map")
    
    Render.Text(fontBold, 14 * scale, headerScore, Vec2(layout.x + padX, layout.y + padY + yOff - 2 * scale), textCol)
    Render.Text(fontMain, 10.5 * scale, lmark, Vec2(layout.x + padX, layout.y + padY + 17 * scale + yOff), subCol)
    
    local combatants = {}
    for _, a in ipairs(FightTracker.Allies) do
        table.insert(combatants, { hero = a, isAlly = true })
    end
    for _, e in ipairs(FightTracker.Enemies) do
        table.insert(combatants, { hero = e, isAlly = false })
    end
    
    local rowY = math.floor(layout.y + padY + 38 * scale + yOff)
    local rowPitch = math.floor(44 * scale)
    
    for idx = 1, math.min(2, #combatants) do
        local c = combatants[idx]
        local h = c.hero
        local rawName = NPC.GetUnitName(h)
        local hName = GetPlayerDisplayName(h)
        if not hName or hName == "" then hName = CleanHeroName(rawName) end
        
        local curHp = Entity.GetHealth(h)
        local maxHp = math.max(1, Entity.GetMaxHealth(h))
        local hpPct = math.min(1.0, math.max(0.0, curHp / maxHp))
        
        local curMana = NPC.GetMana(h) or 0
        local maxMana = math.max(1, NPC.GetMaxMana(h) or 1)
        local manaPct = math.min(1.0, math.max(0.0, curMana / maxMana))
        
        local avatarSz = math.floor(24 * scale)
        local ax = math.floor(layout.x + padX)
        local ay = math.floor(rowY + (idx - 1) * rowPitch)
        
        if idx > 1 then
            local divY = math.floor(ay - 7 * scale)
            Render.Line(Vec2(layout.x + padX + 2 * scale, divY), Vec2(radarX - 10 * scale, divY), FadeColor(Color(255, 255, 255, 14), aMul), 1.0)
        end
        
        local heroIconPath = "panorama/images/heroes/icons/" .. rawName .. "_png.vtex_c"
        local hHandle = GetCachedImage(heroIconPath)
        if hHandle then
            Render.Image(hHandle, Vec2(ax, ay), Vec2(avatarSz, avatarSz), FadeColor(Color(255, 255, 255, 255), aMul), 6 * scale)
        else
            local dotCol = c.isAlly and Config.Colors.Accent or Config.Colors.Red
            Render.FilledCircle(Vec2(ax + avatarSz / 2, ay + avatarSz / 2), avatarSz / 2, FadeColor(dotCol, aMul), 0, 1.0, 18)
        end
        
        local nameX = math.floor(ax + avatarSz + 8 * scale)
        local barW = math.floor(126 * scale)
        
        Render.Text(fontBold, 11 * scale, hName, Vec2(nameX, ay - 1 * scale), textCol)
        
        local barY = math.floor(ay + 14 * scale)
        local barH = math.floor(5.5 * scale)
        local hpW = math.floor(barW * 0.50)
        local manaW = math.floor(barW * 0.46)
        local manaX = math.floor(nameX + hpW + 4 * scale)
        
        Render.FilledRect(Vec2(nameX, barY), Vec2(nameX + hpW, barY + barH), FadeColor(Color(32, 34, 42, 220), aMul), 2.5 * scale)
        if hpPct > 0 then
            local hpCol = c.isAlly and Color(48, 209, 88, 255) or Color(255, 69, 58, 255)
            Render.FilledRect(Vec2(nameX, barY), Vec2(nameX + hpW * hpPct, barY + barH), FadeColor(hpCol, aMul), 2.5 * scale)
        end
        
        Render.FilledRect(Vec2(manaX, barY), Vec2(manaX + manaW, barY + barH), FadeColor(Color(32, 34, 42, 220), aMul), 2.5 * scale)
        if manaPct > 0 then
            Render.FilledRect(Vec2(manaX, barY), Vec2(manaX + manaW * manaPct, barY + barH), FadeColor(Color(74, 114, 232, 255), aMul), 2.5 * scale)
        end
    end
    
    local rP1 = Vec2(radarX, radarY)
    local rP2 = Vec2(radarX + radarSz, radarY + radarSz)
    
    local zoomRange = (UI and UI.Combat and UI.Combat.RadarZoom) and UI.Combat.RadarZoom:Get() or 2000
    local fightCenterX = FightTracker.Center.x or 0
    local fightCenterY = FightTracker.Center.y or 0
    
    local worldMin = -8000
    local worldMax = 8000
    local worldSpan = 16000
    
    local uC = math.max(0.0, math.min(1.0, (fightCenterX - worldMin) / worldSpan))
    local vC = math.max(0.0, math.min(1.0, 1.0 - ((fightCenterY - worldMin) / worldSpan)))
    local uHalf = math.max(0.04, (zoomRange / worldSpan))
    local vHalf = math.max(0.04, (zoomRange / worldSpan))
    
    local uvMin = Vec2(math.max(0.0, uC - uHalf), math.max(0.0, vC - vHalf))
    local uvMax = Vec2(math.min(1.0, uC + uHalf), math.min(1.0, vC + vHalf))
    
    local mapH = GetDotaMapTexture()
    
    Render.FilledRect(rP1, rP2, FadeColor(Color(14, 18, 26, 235), aMul), 18 * scale)
    
    Render.PushClip(rP1, rP2)
    
    if mapH and mapH > 0 then
        Render.Image(mapH, rP1, Vec2(radarSz, radarSz), FadeColor(Color(255, 255, 255, 255), aMul), 18 * scale, Enum.DrawFlags.None, uvMin, uvMax)
        Render.FilledRect(rP1, rP2, FadeColor(Color(10, 14, 20, 35), aMul), 18 * scale)
    else
        local riverP1 = Vec2(radarX, radarY + radarSz * 0.75)
        local riverP2 = Vec2(radarX + radarSz, radarY + radarSz * 0.25)
        Render.FilledRect(Vec2(radarX, radarY + radarSz * 0.5), rP2, FadeColor(Color(20, 50, 32, 90), aMul), 0)
        Render.FilledRect(rP1, Vec2(radarX + radarSz, radarY + radarSz * 0.5), FadeColor(Color(48, 22, 26, 90), aMul), 0)
        Render.Line(riverP1, riverP2, FadeColor(Color(24, 100, 175, 110), aMul), 8 * scale)
    end
    
    local midRx = radarX + radarSz / 2
    local midRy = radarY + radarSz / 2
    
    for _, c in ipairs(combatants) do
        local h = c.hero
        if Entity.IsAlive(h) then
            local hPos = Entity.GetAbsOrigin(h)
            local dx = hPos.x - fightCenterX
            local dy = hPos.y - fightCenterY
            
            local nx = (dx / zoomRange) * (radarSz / 2 * 0.84)
            local ny = -(dy / zoomRange) * (radarSz / 2 * 0.84)
            
            local hX = math.floor(midRx + nx)
            local hY = math.floor(midRy + ny)
            
            hX = math.max(radarX + 10, math.min(radarX + radarSz - 10, hX))
            hY = math.max(radarY + 10, math.min(radarY + radarSz - 10, hY))
            
            local tSz = math.floor(18 * scale)
            local rawName = NPC.GetUnitName(h)
            local hIcon = GetCachedImage("panorama/images/heroes/icons/" .. rawName .. "_png.vtex_c")
            local isAlly = c.isAlly
            local arrowCol = isAlly and Color(48, 209, 88, 255) or Color(255, 69, 58, 255)
            
            if Entity.GetRotationPYR then
                local _, yaw, _ = Entity.GetRotationPYR(h)
                if yaw then
                    local rad = math.rad(-yaw)
                    local dirX = math.cos(rad)
                    local dirY = math.sin(rad)
                    
                    local tip = Vec2(hX + dirX * 13 * scale, hY + dirY * 13 * scale)
                    local s1 = Vec2(hX - dirX * 5 * scale - dirY * 7 * scale, hY - dirY * 5 * scale + dirX * 7 * scale)
                    local s2 = Vec2(hX - dirX * 5 * scale + dirY * 7 * scale, hY - dirY * 5 * scale - dirX * 7 * scale)
                    
                    Render.FilledTriangle({ tip, s1, s2 }, FadeColor(arrowCol, aMul))
                end
            end
            
            if hIcon then
                Render.Image(hIcon, Vec2(hX - tSz / 2, hY - tSz / 2), Vec2(tSz, tSz), FadeColor(Color(255, 255, 255, 255), aMul), 0)
            else
                Render.FilledCircle(Vec2(hX, hY), tSz / 2, FadeColor(arrowCol, aMul), 0, 1.0, 16)
            end
        end
    end
    
    Render.PopClip()
    
    Render.Rect(rP1, rP2, FadeColor(Color(255, 255, 255, 38), aMul), 18 * scale, Enum.DrawFlags.None, 1.0)
end

local function RenderNotificationState(layout, alphaMul, yOffset)
    local notif = NotificationQueue.Active or NotificationQueue.LastDismissed
    if not notif then
        if IsMediaActive() then
            RenderCompactMedia(layout, alphaMul, yOffset)
        else
            RenderModularIdlePill(layout, alphaMul, yOffset)
        end
        return
    end
    
    local aMul = alphaMul or 1.0
    local yOff = yOffset or 0
    local scale = layout.scale
    local fontBold = Config.Fonts.Bold
    local fontMain = Config.Fonts.Main
    local textCol = FadeColor(Config.Colors.TextPrimary, aMul)
    local now = os.clock()
    
    if notif.Type == "apple_pay" then
        local appleGreen = Color(52, 199, 89, 255)
        local elapsed = now - (NotificationQueue.StartTime or now)
        local pulseT = math.min(1.0, elapsed * 5.0)
        local checkScale = EaseOutBack(pulseT)
        
        local iconSz = math.floor(24 * scale)
        local iconX = math.floor(layout.x + 12 * scale)
        local iconY = math.floor(layout.y + (layout.h - iconSz) / 2 + yOff)
        
        Render.FilledCircle(Vec2(iconX + iconSz / 2, iconY + iconSz / 2), math.floor(iconSz / 2 * checkScale), FadeColor(appleGreen, aMul), 0, 1.0, 28)
        
        local checkStr = "✓"
        local chkSz = Render.TextSize(fontBold, 12 * scale * checkScale, checkStr)
        Render.Text(fontBold, 12 * scale * checkScale, checkStr, Vec2(math.floor(iconX + (iconSz - chkSz.x) / 2), math.floor(iconY + (iconSz - chkSz.y) / 2 - 1)), FadeColor(Color(255, 255, 255, 255), aMul))
        
        local textX = math.floor(iconX + iconSz + 10 * scale)
        local tagStr = notif.Tag or "APPLE PAY"
        local tagSize = Render.TextSize(fontBold, 8.5 * scale, tagStr)
        local titleStr = notif.Title or L("Успешно!", "Success!")
        local titleSize = Render.TextSize(fontBold, 12 * scale, titleStr)
        
        local totalH = tagSize.y + titleSize.y + 1 * scale
        local startY = math.floor(layout.y + (layout.h - totalH) / 2 + yOff)
        
        Render.Text(fontBold, 8.5 * scale, tagStr, Vec2(textX, startY), FadeColor(appleGreen, aMul))
        Render.Text(fontBold, 12 * scale, titleStr, Vec2(textX, startY + tagSize.y + 1 * scale), textCol)
        return
    end
    
    if notif.Type == "apple_action_dial" then
        local accent = notif.AccentColor or Color(52, 199, 89, 255)
        local isEnabled = (notif.Subtitle == "ENABLED")
        local isTap = (notif.Subtitle == "TRIGGERED")
        
        local iconSz = math.floor(24 * scale)
        local iconX = math.floor(layout.x + 12 * scale)
        local iconY = math.floor(layout.y + (layout.h - iconSz) / 2 + yOff)
        
        Render.FilledCircle(Vec2(iconX + iconSz / 2, iconY + iconSz / 2), math.floor(iconSz / 2), FadeColor(accent, aMul * 0.22), 0, 1.0, 24)
        Render.Circle(Vec2(iconX + iconSz / 2, iconY + iconSz / 2), math.floor(iconSz / 2), FadeColor(accent, aMul * 0.85), 1.2 * scale)
        
        local glyph = isTap and "\u{26A1}" or (isEnabled and "\u{2714}" or "\u{2715}")
        local glyphSz = Render.TextSize(fontBold, 11 * scale, glyph)
        local gw = glyphSz.x
        local gh = glyphSz.y
        Render.Text(fontBold, 11 * scale, glyph, Vec2(math.floor(iconX + (iconSz - gw) / 2), math.floor(iconY + (iconSz - gh) / 2 - 1)), FadeColor(accent, aMul))
        
        local badgeH = math.floor(18 * scale)
        local badgeW = math.floor(38 * scale)
        local badgeX = math.floor(layout.x + layout.w - 12 * scale - badgeW)
        local badgeY = math.floor(layout.y + (layout.h - badgeH) / 2 + yOff)
        local badgeR = math.floor(badgeH / 2)
        
        local badgeBg = isTap and Color(10, 132, 255, 230) or (isEnabled and Color(52, 199, 89, 230) or Color(65, 68, 76, 170))
        local badgeTxt = isTap and "TAP" or (isEnabled and "ON" or "OFF")
        local badgeSz = Render.TextSize(fontBold, 9.5 * scale, badgeTxt)
        local bw = badgeSz.x
        local bh = badgeSz.y
        
        Render.FilledRect(Vec2(badgeX, badgeY), Vec2(badgeX + badgeW, badgeY + badgeH), FadeColor(badgeBg, aMul), badgeR)
        if not isEnabled and not isTap then
            Render.Rect(Vec2(badgeX, badgeY), Vec2(badgeX + badgeW, badgeY + badgeH), FadeColor(Color(255, 255, 255, 40), aMul), badgeR, Enum.DrawFlags.None, 1.0)
        end
        Render.Text(fontBold, 9.5 * scale, badgeTxt, Vec2(math.floor(badgeX + (badgeW - bw) / 2), math.floor(badgeY + (badgeH - bh) / 2)), FadeColor(Color(255, 255, 255, 255), aMul))
        
        local textX = math.floor(iconX + iconSz + 10 * scale)
        local maxTextW = math.floor(badgeX - textX - 8 * scale)
        
        local tagStr = notif.Tag or "ACTION DIAL"
        local tagSize = Render.TextSize(fontMain, 8.5 * scale, tagStr)
        local titleSize = Render.TextSize(fontBold, 11.5 * scale, notif.Title)
        local totalH = tagSize.y + titleSize.y
        local startY = math.floor(layout.y + (layout.h - totalH) / 2 - 1 + yOff)
        
        Render.Text(fontMain, 8.5 * scale, tagStr, Vec2(textX, startY), FadeColor(Color(255, 255, 255, 130), aMul))
        
        local titleStr = notif.Title
        if titleSize.x > maxTextW then
            titleStr = string.sub(titleStr, 1, 18) .. ".."
        end
        Render.Text(fontBold, 11.5 * scale, titleStr, Vec2(textX, startY + tagSize.y), textCol)
        return
    end
    
    local accent = notif.AccentColor or GetPrimaryThemeColor()
    local iconH = math.floor(22 * scale)
    local iconW = math.floor(22 * scale)
    local iconRadius = math.floor(4 * scale)
    local iconHandle = nil
    
    local isPowerRuneRoll = (notif.Type == "power_rune_cycle")
    
    if isPowerRuneRoll then
        local cycleSpeed = 1.8
        local cycleTime = now * cycleSpeed
        local idxA = math.floor(cycleTime) % #PowerRunesCycleList + 1
        local idxB = (idxA % #PowerRunesCycleList) + 1
        local frac = cycleTime - math.floor(cycleTime)
        local smoothFrac = frac * frac * (3.0 - 2.0 * frac)
        
        accent = LerpColor(PowerRunesCycleList[idxA].col, PowerRunesCycleList[idxB].col, smoothFrac)
        
        local iconX = math.floor(layout.x + 10 * scale)
        local iconY = math.floor(layout.y + (layout.h - iconH) / 2 + yOff)
        
        Render.PushClip(Vec2(iconX - 2, iconY - 2), Vec2(iconX + iconW + 2, iconY + iconH + 2))
        
        local hA = GetCachedImage(PowerRunesCycleList[idxA].path, PowerRunesCycleList[idxA].svg)
        local hB = GetCachedImage(PowerRunesCycleList[idxB].path, PowerRunesCycleList[idxB].svg)
        local offA = -smoothFrac * 16 * scale
        local offB = (1.0 - smoothFrac) * 16 * scale
        
        if hA then Render.Image(hA, Vec2(iconX, iconY + offA), Vec2(iconW, iconH), FadeColor(Color(255, 255, 255, 255), (1.0 - smoothFrac) * aMul), math.floor(11 * scale)) end
        if hB then Render.Image(hB, Vec2(iconX, iconY + offB), Vec2(iconW, iconH), FadeColor(Color(255, 255, 255, 255), smoothFrac * aMul), math.floor(11 * scale)) end
        
        Render.PopClip()
    else
        if notif.IconType == "rune" or notif.FallbackSvg == "bounty" or notif.FallbackSvg == "rune_wisdom" or notif.FallbackSvg == "rune_water" or notif.FallbackSvg == "lotus" then
            iconW = math.floor(22 * scale)
            iconH = math.floor(22 * scale)
            iconRadius = math.floor(11 * scale)
            iconHandle = GetCachedImage(notif.Icon, notif.FallbackSvg)
        elseif notif.IconType == "item" then
            iconW = math.floor(26 * scale)
            iconH = math.floor(19 * scale)
            iconHandle = GetCachedImage(notif.Icon, notif.FallbackSvg)
        elseif notif.IconType == "hero" then
            iconW = math.floor(24 * scale)
            iconH = math.floor(24 * scale)
            iconRadius = math.floor(12 * scale)
            iconHandle = GetCachedImage(notif.Icon, notif.FallbackSvg)
        else
            iconHandle = GetCachedImage(notif.Icon, notif.FallbackSvg)
        end
        
        local iconX = math.floor(layout.x + 10 * scale)
        local iconY = math.floor(layout.y + (layout.h - iconH) / 2 + yOff)
        
        if iconHandle then
            Render.Image(iconHandle, Vec2(iconX, iconY), Vec2(iconW, iconH), FadeColor(Color(255, 255, 255, 255), aMul), iconRadius)
        else
            Render.FilledCircle(Vec2(iconX + iconW / 2, iconY + iconH / 2), iconH / 2, FadeColor(accent, aMul), 0, 1.0, 24)
            Render.FilledCircle(Vec2(iconX + iconW / 2, iconY + iconH / 2), math.floor(4 * scale), FadeColor(Color(255, 255, 255, 230), aMul), 0, 1.0, 18)
        end
    end
    
    local textX = math.floor(layout.x + 10 * scale + iconW + 10 * scale)
    local maxTextW = math.floor(layout.x + layout.w - textX - 12 * scale)
    
    local tagStr = notif.Tag or L("ОПОВЕЩЕНИЕ", "NOTIFICATION")
    local tagSize = Render.TextSize(fontMain, 8.5 * scale, tagStr)
    local titleSize = Render.TextSize(fontBold, 12 * scale, notif.Title)
    
    local totalH = tagSize.y + titleSize.y
    local startY = math.floor(layout.y + (layout.h - totalH) / 2 - 1 + yOff)
    
    Render.Text(fontMain, 8.5 * scale, tagStr, Vec2(textX, startY), FadeColor(Color(accent.r, accent.g, accent.b, 240), aMul))
    
    local titleStr = notif.Title
    if titleSize.x > maxTextW then
        titleStr = string.sub(titleStr, 1, 24) .. ".."
    end
    Render.Text(fontBold, 12 * scale, titleStr, Vec2(textX, startY + tagSize.y), textCol)
end

local function RenderLargeMedia(layout, alphaMul, yOffset)
    local aMul = alphaMul or 1.0
    local yOff = yOffset or 0
    local scale = layout.scale
    local fontBold = Config.Fonts.Bold
    local fontMain = Config.Fonts.Main
    local textCol = FadeColor(Config.Colors.TextPrimary, aMul)
    local subCol = FadeColor(Config.Colors.TextSecondary, aMul)
    local waveCol = MediaData.CoverColor or GetPrimaryThemeColor()
    
    local pad = math.floor(16 * scale)
    local artSize = math.floor(48 * scale)
    local artX = math.floor(layout.x + pad)
    local artY = math.floor(layout.y + pad + yOff)
    
    local waveCount = 5
    local waveW = math.floor(waveCount * (2.4 * scale) + (waveCount - 1) * (1.8 * scale))
    local waveX = math.floor(layout.x + layout.w - pad - waveW)
    local waveY = math.floor(artY + 4 * scale)
    DrawAppleWaveform(waveX, waveY, 20, waveCount, MediaData.IsPlaying, scale, waveCol, aMul)
    
    local infoX = math.floor(artX + artSize + 13 * scale)
    local infoY = math.floor(artY + 3 * scale)
    local maxInfoW = math.max(10, math.floor(waveX - infoX - 8 * scale))
    
    local titleStr = MediaData.Title ~= "" and MediaData.Title or L("Трек", "Track")
    local artistStr = MediaData.Artist ~= "" and MediaData.Artist or "Apple Music"
    
    local nowClk = os.clock()
    if TrackTransition.Active then
        local t = math.min(1.0, (nowClk - TrackTransition.StartTime) / (TrackTransition.Duration * AnimScale()))
        local dir = TrackTransition.Direction
        local outOffset = -dir * (t * 22 * scale)
        local outAlpha = (1.0 - t) * aMul
        local inOffset = dir * ((1.0 - t) * 22 * scale)
        local inAlpha = t * aMul
        
        if outAlpha > 0.02 and TrackTransition.OldTitle ~= "" then
            Render.Text(fontBold, 15 * scale, TrackTransition.OldTitle, Vec2(infoX + outOffset, infoY), FadeColor(Config.Colors.TextPrimary, outAlpha))
            Render.Text(fontMain, 12 * scale, TrackTransition.OldArtist, Vec2(infoX + outOffset, infoY + 18 * scale), FadeColor(Config.Colors.TextSecondary, outAlpha))
            DrawAlbumThumbnail(artX, artY, artSize, math.floor(12 * scale), outAlpha, 1.0 - t * 0.15, TrackTransition.OldCoverHandle, TrackTransition.OldCoverColor)
        end
        if inAlpha > 0.02 then
            Render.Text(fontBold, 15 * scale, titleStr, Vec2(infoX + inOffset, infoY), FadeColor(Config.Colors.TextPrimary, inAlpha))
            Render.Text(fontMain, 12 * scale, artistStr, Vec2(infoX + inOffset, infoY + 18 * scale), FadeColor(Config.Colors.TextSecondary, inAlpha))
            DrawAlbumThumbnail(artX, artY, artSize, math.floor(12 * scale), inAlpha, 0.85 + t * 0.15)
        end
    else
        local titleSize = Render.TextSize(fontBold, 15 * scale, titleStr)
        if titleSize.x > maxInfoW then
            RenderMarqueeText(fontBold, 15 * scale, titleStr, infoX, infoY, maxInfoW, textCol, scale, false)
        else
            Render.Text(fontBold, 15 * scale, titleStr, Vec2(infoX, infoY), textCol)
        end
        
        local artSizeText = Render.TextSize(fontMain, 12 * scale, artistStr)
        local artYPos = math.floor(infoY + titleSize.y + 4 * scale)
        if artSizeText.x > maxInfoW then
            RenderMarqueeText(fontMain, 12 * scale, artistStr, infoX, artYPos, maxInfoW, subCol, scale, false)
        else
            Render.Text(fontMain, 12 * scale, artistStr, Vec2(infoX, artYPos), subCol)
        end
        
        DrawAlbumThumbnail(artX, artY, artSize, math.floor(12 * scale), aMul)
    end
    
    local progressY = math.floor(artY + artSize + 14 * scale)
    local progressW = math.floor(layout.w - pad * 2)
    local progressH = math.floor(4.5 * scale)
    
    local curPos = MediaData.Position
    if MediaData.IsPlaying then
        local passed = os.clock() - MediaData.LocalTimeAtPoll
        curPos = curPos + passed
    end
    local duration = math.max(1, MediaData.Duration)
    local progressPct = math.min(1.0, math.max(0.0, curPos / duration))
    
    Render.FilledRect(Vec2(layout.x + pad, progressY), Vec2(layout.x + pad + progressW, progressY + progressH), FadeColor(Config.Colors.TrackProgressBg, aMul), 2.5 * scale)
    if progressPct > 0 then
        Render.FilledRect(Vec2(layout.x + pad, progressY), Vec2(layout.x + pad + progressW * progressPct, progressY + progressH), FadeColor(Config.Colors.TextPrimary, aMul), 2.5 * scale)
    end
    
    local posText = FormatTime(curPos)
    local remSec = math.max(0, duration - curPos)
    local remText = FormatNegativeTime(remSec)
    
    local timeY = math.floor(progressY + 6 * scale)
    Render.Text(fontMain, 9.5 * scale, posText, Vec2(layout.x + pad, timeY), subCol)
    local remSize = Render.TextSize(fontMain, 9.5 * scale, remText)
    Render.Text(fontMain, 9.5 * scale, remText, Vec2(layout.x + layout.w - pad - remSize.x, timeY), subCol)
    
    local ctrlY = math.floor(timeY + 16 * scale)
    local midX = math.floor(layout.x + layout.w / 2)
    
    local playScale = ButtonSprings.MediaPlay.scale
    local playRadius = math.floor(16 * scale * playScale)
    local playX = midX
    local playY = math.floor(ctrlY + 16 * scale)
    
    if MediaData.IsPlaying then
        local bw = math.floor(3.5 * scale * playScale)
        local bh = math.floor(14 * scale * playScale)
        local bx1 = math.floor(playX - 5 * scale * playScale)
        local bx2 = math.floor(playX + 2 * scale * playScale)
        local by = math.floor(playY - bh / 2)
        Render.FilledRect(Vec2(bx1, by), Vec2(bx1 + bw, by + bh), FadeColor(Config.Colors.TextPrimary, aMul), 1.2 * scale)
        Render.FilledRect(Vec2(bx2, by), Vec2(bx2 + bw, by + bh), FadeColor(Config.Colors.TextPrimary, aMul), 1.2 * scale)
    else
        local tw = math.floor(13 * scale * playScale)
        local th = math.floor(15 * scale * playScale)
        local p1 = Vec2(playX - tw / 3, playY - th / 2)
        local p2 = Vec2(playX - tw / 3, playY + th / 2)
        local p3 = Vec2(playX + tw * 2 / 3, playY)
        Render.FilledTriangle({p1, p2, p3}, FadeColor(Config.Colors.TextPrimary, aMul))
    end
    
    ButtonHits.MediaPlay = {
        x1 = playX - 22,
        y1 = playY - 22,
        x2 = playX + 22,
        y2 = playY + 22
    }
    
    local prevScale = ButtonSprings.MediaPrev.scale
    local prevX = math.floor(playX - 54 * scale)
    local prevY = playY
    local triW = math.floor(8 * scale * prevScale)
    local triH = math.floor(11 * scale * prevScale)
    
    local pp1 = Vec2(prevX + triW, prevY - triH / 2)
    local pp2 = Vec2(prevX + triW, prevY + triH / 2)
    local pp3 = Vec2(prevX, prevY)
    Render.FilledTriangle({pp1, pp2, pp3}, FadeColor(Config.Colors.TextPrimary, aMul))
    
    local pp4 = Vec2(prevX, prevY - triH / 2)
    local pp5 = Vec2(prevX, prevY + triH / 2)
    local pp6 = Vec2(prevX - triW, prevY)
    Render.FilledTriangle({pp4, pp5, pp6}, FadeColor(Config.Colors.TextPrimary, aMul))
    
    ButtonHits.MediaPrev = {
        x1 = prevX - 18,
        y1 = prevY - 18,
        x2 = prevX + 18,
        y2 = prevY + 18
    }
    
    local nextScale = ButtonSprings.MediaNext.scale
    local nextX = math.floor(playX + 54 * scale)
    local nextY = playY
    local ntriW = math.floor(8 * scale * nextScale)
    local ntriH = math.floor(11 * scale * nextScale)
    
    local np1 = Vec2(nextX - ntriW, nextY - ntriH / 2)
    local np2 = Vec2(nextX - ntriW, nextY + ntriH / 2)
    local np3 = Vec2(nextX, nextY)
    Render.FilledTriangle({np1, np2, np3}, FadeColor(Config.Colors.TextPrimary, aMul))
    
    local np4 = Vec2(nextX, nextY - ntriH / 2)
    local np5 = Vec2(nextX, nextY + ntriH / 2)
    local np6 = Vec2(nextX + ntriW, nextY)
    Render.FilledTriangle({np4, np5, np6}, FadeColor(Config.Colors.TextPrimary, aMul))
    
    ButtonHits.MediaNext = {
        x1 = nextX - 18,
        y1 = nextY - 18,
        x2 = nextX + 18,
        y2 = nextY + 18
    }
    
    local shufScale = ButtonSprings.MediaShuffle.scale
    local shufX = math.floor(layout.x + pad + 12 * scale)
    local shufY = playY
    local shufH = GetVectorIcon("shuffle")
    if shufH then
        local shufCol = MediaData.Shuffle and Color(255, 255, 255, 255) or Color(255, 255, 255, 90)
        local sSz = 14 * scale * shufScale
        Render.Image(shufH, Vec2(shufX - sSz / 2, shufY - sSz / 2), Vec2(sSz, sSz), FadeColor(shufCol, aMul), 0)
    end
    ButtonHits.MediaShuffle = {
        x1 = shufX - 14 * scale,
        y1 = shufY - 14 * scale,
        x2 = shufX + 14 * scale,
        y2 = shufY + 14 * scale
    }
    
    local repScale = ButtonSprings.MediaRepeat.scale
    local repX = math.floor(prevX - 36 * scale)
    local repY = playY
    local repH = GetVectorIcon("repeat")
    if repH then
        local repCol = (MediaData.RepeatMode > 0) and Color(255, 255, 255, 255) or Color(255, 255, 255, 90)
        local rSz = 14 * scale * repScale
        Render.Image(repH, Vec2(repX - rSz / 2, repY - rSz / 2), Vec2(rSz, rSz), FadeColor(repCol, aMul), 0)
        if MediaData.RepeatMode == 2 then
            Render.Text(fontBold, 7.5 * scale, "1", Vec2(repX + 5 * scale, repY - 7 * scale), FadeColor(Color(255, 255, 255, 255), aMul))
        end
    end
    ButtonHits.MediaRepeat = {
        x1 = repX - 14 * scale,
        y1 = repY - 14 * scale,
        x2 = repX + 14 * scale,
        y2 = repY + 14 * scale
    }
    
    if UI.Media.SpotifyLike:Get() then
        local likeScale = ButtonSprings.MediaLike.scale
        local isLiked = (MediaData.IsLiked == true) or (MediaData.LikedTracks[MediaData.LastTrackKey] == true)
        local likeX = math.floor(layout.x + layout.w - pad - 12 * scale)
        local likeY = playY
        local heartH = GetVectorIcon(isLiked and "heart_fill" or "heart_outline")
        if heartH then
            local heartCol = isLiked and Color(255, 69, 58, 255) or Color(255, 255, 255, 255)
            local lSz = 16 * scale * likeScale
            Render.Image(heartH, Vec2(likeX - lSz / 2, likeY - lSz / 2), Vec2(lSz, lSz), FadeColor(heartCol, aMul), 0)
        end
        ButtonHits.MediaLike = {
            x1 = likeX - 14 * scale,
            y1 = likeY - 14 * scale,
            x2 = likeX + 14 * scale,
            y2 = likeY + 14 * scale
        }
    else
        ButtonHits.MediaLike = nil
    end
end

local function RenderLargeIdle(layout, alphaMul, yOffset)
    local aMul = alphaMul or 1.0
    local yOff = yOffset or 0
    local scale = layout.scale
    local fontBold = Config.Fonts.Bold
    local fontMain = Config.Fonts.Main
    local textCol = FadeColor(Config.Colors.TextPrimary, aMul)
    local subCol = FadeColor(Config.Colors.TextSecondary, aMul)
    
    local pad = math.floor(16 * scale)
    local leftX = math.floor(layout.x + pad)
    local leftY = math.floor(layout.y + pad + yOff)
    
    local timeHM = os.date("%H:%M")
    local timeSec = os.date(":%S")
    
    local hmSize = Render.TextSize(fontBold, 26 * scale, timeHM)
    Render.Text(fontBold, 26 * scale, timeHM, Vec2(leftX, leftY + 2 * scale), textCol)
    
    local secX = math.floor(leftX + hmSize.x + 3 * scale)
    local secY = math.floor(leftY + 11 * scale)
    Render.Text(fontMain, 13 * scale, timeSec, Vec2(secX, secY), subCol)
    
    local matchTime = GetActualMatchTime()
    local subInfo = ""
    if matchTime and matchTime > 0 then
        subInfo = L("Матч ", "Match ") .. FormatTime(matchTime)
    else
        subInfo = L("Главное меню", "Main Menu")
    end
    Render.Text(fontMain, 10.5 * scale, subInfo, Vec2(leftX, leftY + hmSize.y + 7 * scale), FadeColor(Config.Colors.TextMuted, aMul))
    
    local divX = math.floor(layout.x + 140 * scale)
    Render.Line(Vec2(divX, layout.y + 14 * scale + yOff), Vec2(divX, layout.y + layout.h - 14 * scale + yOff), FadeColor(Config.Colors.Border, aMul), 1.0)
    
    local rightX = math.floor(divX + 14 * scale)
    local row1Y = math.floor(layout.y + 16 * scale + yOff)
    local row2Y = math.floor(layout.y + 44 * scale + yOff)
    
    local kdaSvg = GetVectorIcon("kda")
    if kdaSvg then Render.Image(kdaSvg, Vec2(rightX, row1Y), Vec2(12 * scale, 12 * scale), FadeColor(Color(255, 255, 255, 220), aMul), 0) end
    local kdaTxt = string.format("%d / %d / %d", HeroData.Kills, HeroData.Deaths, HeroData.Assists)
    Render.Text(fontBold, 11 * scale, kdaTxt, Vec2(rightX + 16 * scale, row1Y - 1 * scale), textCol)
    
    local goldSvg = GetVectorIcon("gold")
    local goldX = math.floor(rightX + 85 * scale)
    if goldSvg then Render.Image(goldSvg, Vec2(goldX, row1Y), Vec2(12 * scale, 12 * scale), FadeColor(Color(255, 255, 255, 220), aMul), 0) end
    local goldTxt = string.format("%d G", HeroData.Gold)
    Render.Text(fontBold, 11 * scale, goldTxt, Vec2(goldX + 16 * scale, row1Y - 1 * scale), textCol)
    
    local fpsSvg = GetVectorIcon("fps")
    if fpsSvg then Render.Image(fpsSvg, Vec2(rightX, row2Y + 4 * scale), Vec2(12 * scale, 12 * scale), FadeColor(Color(255, 255, 255, 220), aMul), 0) end
    local fpsTxt = string.format("%d FPS", PerformanceData.FPS)
    Render.Text(fontMain, 10.5 * scale, fpsTxt, Vec2(rightX + 16 * scale, row2Y + 3 * scale), FadeColor(Color(255, 255, 255, 240), aMul))
    
    local pingSvg = GetVectorIcon("ping")
    if pingSvg then Render.Image(pingSvg, Vec2(goldX, row2Y + 4 * scale), Vec2(12 * scale, 12 * scale), FadeColor(Color(255, 255, 255, 220), aMul), 0) end
    local pingTxt = string.format("%d ms", PerformanceData.Ping)
    Render.Text(fontMain, 10.5 * scale, pingTxt, Vec2(goldX + 16 * scale, row2Y + 3 * scale), FadeColor(Color(255, 255, 255, 240), aMul))
end

local function RenderGamePausedPill(layout, alphaMul, yOffset)
    local scale = layout.scale
    local yOff = (yOffset or 0) * scale
    local centerY = math.floor(layout.y + layout.h / 2 + yOff)
    local fontBold = Config.Fonts.Bold
    local fontMain = Config.Fonts.Main
    local elapsed = PauseTracker.PauseStartTime > 0 and math.floor(os.clock() - PauseTracker.PauseStartTime) or 0
    local pText = L("island.paused", "Paused")
    local timeText = string.format("%d:%02d", math.floor(elapsed / 60), elapsed % 60)
    local dotStr = " \u{2022} "
    
    local badgeSize = math.floor(18 * scale)
    local badgeX = math.floor(layout.x + 10 * scale)
    local badgeY = math.floor(centerY - badgeSize / 2)
    
    local pauseSvg = GetVectorIcon("pause")
    if pauseSvg then
        Render.Image(pauseSvg, Vec2(badgeX, badgeY), Vec2(badgeSize, badgeSize), FadeColor(Color(255, 255, 255, 255), alphaMul), 0)
    end
    
    local tSize1 = Render.TextSize(fontMain, 11 * scale, pText)
    local tSizeDot = Render.TextSize(fontMain, 11 * scale, dotStr)
    local tSize2 = Render.TextSize(fontBold, 11.5 * scale, timeText)
    
    local textStartX = math.floor(badgeX + badgeSize + 8 * scale)
    local textY1 = math.floor(centerY - tSize1.y / 2 - 1 * scale)
    local textY2 = math.floor(centerY - tSize2.y / 2 - 1 * scale)
    
    Render.Text(fontMain, 11 * scale, pText, Vec2(textStartX, textY1), FadeColor(Color(255, 255, 255, 210), alphaMul))
    Render.Text(fontMain, 11 * scale, dotStr, Vec2(textStartX + tSize1.x, textY1), FadeColor(Color(255, 255, 255, 120), alphaMul))
    Render.Text(fontBold, 11.5 * scale, timeText, Vec2(textStartX + tSize1.x + tSizeDot.x, textY2), FadeColor(Color(255, 255, 255, 255), alphaMul))
end

local function RenderCourierDeliveryPill(layout, alphaMul, yOffset)
    local scale = layout.scale
    local yOff = (yOffset or 0) * scale
    local centerY = math.floor(layout.y + layout.h / 2 + yOff)
    local fontBold = Config.Fonts.Bold
    
    local courierSvg = GetVectorIcon("courier")
    local iconSize = 15 * scale
    local leftX = math.floor(layout.x + 12 * scale)
    if courierSvg then
        Render.Image(courierSvg, Vec2(leftX, centerY - math.floor(iconSize / 2)), Vec2(iconSize, iconSize), FadeColor(Color(255, 204, 0, 255), alphaMul), 0)
    end
    
    local etaStr = (CourierTracker.ETA > 0) and (L("courier.eta", "ETA") .. " " .. FormatTime(CourierTracker.ETA)) or L("courier.delivering", "Delivering")
    local etaSize = Render.TextSize(fontBold, 10.5 * scale, etaStr)
    local rightX = math.floor(layout.x + layout.w - 12 * scale - etaSize.x)
    Render.Text(fontBold, 10.5 * scale, etaStr, Vec2(rightX, centerY - math.floor(etaSize.y / 2) - 1 * scale), FadeColor(Color(255, 255, 255, 235), alphaMul))
    
    local trackStartX = math.floor(leftX + iconSize + 10 * scale)
    local trackEndX = math.floor(rightX - 10 * scale)
    local trackW = trackEndX - trackStartX
    if trackW > 20 * scale then
        local trackH = math.max(3, math.floor(3 * scale))
        local trackY = math.floor(centerY - trackH / 2)
        local trackR = math.floor(trackH / 2)
        Render.FilledRect(Vec2(trackStartX, trackY), Vec2(trackEndX, trackY + trackH), FadeColor(Color(255, 255, 255, 45), alphaMul), trackR)
        
        local fillW = math.floor(trackW * math.max(0, math.min(1.0, CourierTracker.Progress)))
        if fillW > 0 then
            Render.FilledRect(Vec2(trackStartX, trackY), Vec2(trackStartX + fillW, trackY + trackH), FadeColor(Color(52, 199, 89, 220), alphaMul), trackR)
        end
        
        local dotX = math.min(trackEndX, math.max(trackStartX, trackStartX + fillW))
        Render.Circle(Vec2(dotX, centerY), 4.5 * scale, FadeColor(Color(52, 199, 89, 100), alphaMul))
        Render.Circle(Vec2(dotX, centerY), 2.5 * scale, FadeColor(Color(255, 255, 255, 255), alphaMul))
    end
end

local function RenderCourierDeliveredPill(layout, alphaMul, yOffset)
    local scale = layout.scale
    local yOff = (yOffset or 0) * scale
    local centerY = math.floor(layout.y + layout.h / 2 + yOff)
    local fontBold = Config.Fonts.Bold
    
    local nowClk = os.clock()
    local elapsed = math.min(CourierTracker.DeliveredDuration, math.max(0, nowClk - CourierTracker.DeliveredStartTime))
    local t = elapsed / math.max(0.01, CourierTracker.DeliveredDuration)
    
    local bounce = 1.0
    if t < 0.3 then
        bounce = 0.6 + 0.6 * math.sin((t / 0.3) * (math.pi / 2))
    elseif t < 0.65 then
        bounce = 1.2 - 0.2 * ((t - 0.3) / 0.35)
    else
        bounce = 1.0
    end
    
    local flareAlpha = math.floor(math.max(0, 1.0 - t * 1.6) * 180 * alphaMul)
    if flareAlpha > 0 then
        Render.Rect(Vec2(layout.x, layout.y), Vec2(layout.x + layout.w, layout.y + layout.h), Color(52, 199, 89, flareAlpha), layout.r, Enum.DrawFlags.None, 1.5)
    end
    
    local checkSvg = GetVectorIcon("apple_check") or GetVectorIcon("check")
    local iconSize = math.floor(18 * scale * bounce)
    local delivText = L("courier.delivered", "Delivered!")
    local tSize = Render.TextSize(fontBold, 11.5 * scale, delivText)
    local gap = 8 * scale
    local totalW = iconSize + gap + tSize.x
    local startX = math.floor(layout.x + (layout.w - totalW) / 2)
    
    if checkSvg then
        Render.Image(checkSvg, Vec2(startX, centerY - math.floor(iconSize / 2)), Vec2(iconSize, iconSize), FadeColor(Color(255, 255, 255, 255), alphaMul), 0)
    end
    Render.Text(fontBold, 11.5 * scale, delivText, Vec2(startX + iconSize + gap, centerY - math.floor(tSize.y / 2) - 1 * scale), FadeColor(Color(255, 255, 255, 255), alphaMul))
end

local function RenderCourierLarge(layout, alphaMul, yOffset)
    local scale = layout.scale
    local yOff = (yOffset or 0) * scale
    local fontBold = Config.Fonts.Bold
    local fontMain = Config.Fonts.Main
    
    local leftX = math.floor(layout.x + 18 * scale)
    local row1Y = math.floor(layout.y + 14 * scale + yOff)
    
    local courierSvg = GetVectorIcon("courier")
    if courierSvg then
        Render.Image(courierSvg, Vec2(leftX, row1Y), Vec2(16 * scale, 16 * scale), FadeColor(Color(255, 204, 0, 255), alphaMul), 0)
    end
    local titleTxt = L("courier.delivering", "Delivering Items")
    Render.Text(fontBold, 11.5 * scale, titleTxt, Vec2(leftX + 22 * scale, row1Y + 1 * scale), FadeColor(Color(255, 255, 255, 255), alphaMul))
    
    local infoTxt = string.format("%s: %d  |  %s: %d%%", L("courier.speed", "Speed"), math.floor(CourierTracker.Speed), L("courier.hp", "HP"), math.floor(CourierTracker.HpPercent * 100))
    local infoSize = Render.TextSize(fontMain, 10.5 * scale, infoTxt)
    local rightX = math.floor(layout.x + layout.w - 18 * scale - infoSize.x)
    Render.Text(fontMain, 10.5 * scale, infoTxt, Vec2(rightX, row1Y + 2 * scale), FadeColor(Config.Colors.TextMuted, alphaMul))
    
    local trackStartX = math.floor(layout.x + 18 * scale)
    local trackEndX = math.floor(layout.x + layout.w - 18 * scale)
    local trackW = trackEndX - trackStartX
    local trackY = math.floor(layout.y + 40 * scale + yOff)
    local trackH = math.max(3, math.floor(3 * scale))
    Render.FilledRect(Vec2(trackStartX, trackY), Vec2(trackEndX, trackY + trackH), FadeColor(Color(255, 255, 255, 45), alphaMul), math.floor(trackH / 2))
    local fillW = math.floor(trackW * math.max(0, math.min(1.0, CourierTracker.Progress)))
    if fillW > 0 then
        Render.FilledRect(Vec2(trackStartX, trackY), Vec2(trackStartX + fillW, trackY + trackH), FadeColor(Color(52, 199, 89, 220), alphaMul), math.floor(trackH / 2))
    end
    local dotX = math.min(trackEndX, math.max(trackStartX, trackStartX + fillW))
    Render.Circle(Vec2(dotX, trackY + math.floor(trackH / 2)), 4 * scale, FadeColor(Color(52, 199, 89, 100), alphaMul))
    Render.Circle(Vec2(dotX, trackY + math.floor(trackH / 2)), 2.5 * scale, FadeColor(Color(255, 255, 255, 255), alphaMul))
    
    local slotW = math.floor(40 * scale)
    local slotH = math.floor(28 * scale)
    local slotGap = math.floor(8 * scale)
    local totalSlotsW = 6 * slotW + 5 * slotGap
    local slotsStartX = math.floor(layout.x + (layout.w - totalSlotsW) / 2)
    local slotsY = math.floor(layout.y + 54 * scale + yOff)
    
    for i = 1, 6 do
        local sx = math.floor(slotsStartX + (i - 1) * (slotW + slotGap))
        local sy = slotsY
        local it = CourierTracker.Inventory[i]
        if it and it.icon then
            Render.FilledRect(Vec2(sx, sy), Vec2(sx + slotW, sy + slotH), FadeColor(Color(20, 20, 25, 220), alphaMul), 4 * scale)
            Render.Rect(Vec2(sx, sy), Vec2(sx + slotW, sy + slotH), FadeColor(Color(255, 255, 255, 50), alphaMul), 4 * scale, Enum.DrawFlags.None, 1.0)
            local itHandle = GetCachedImage(it.icon)
            if itHandle and itHandle > 0 then
                Render.Image(itHandle, Vec2(sx + 2 * scale, sy + 2 * scale), Vec2(slotW - 4 * scale, slotH - 4 * scale), FadeColor(Color(255, 255, 255, 255), alphaMul), 3 * scale)
            end
        else
            Render.FilledRect(Vec2(sx, sy), Vec2(sx + slotW, sy + slotH), FadeColor(Color(255, 255, 255, 12), alphaMul), 4 * scale)
            Render.Rect(Vec2(sx, sy), Vec2(sx + slotW, sy + slotH), FadeColor(Color(255, 255, 255, 25), alphaMul), 4 * scale, Enum.DrawFlags.None, 1.0)
        end
    end
end

local function RenderVolumeOverlay(layout, alphaMul)
    if alphaMul <= 0.01 then return end
    local scale = layout.scale
    local aMul = math.max(0.0, math.min(1.0, alphaMul))
    
    local compactRatio = math.max(0.0, math.min(1.0, (148 * scale - layout.h) / (114 * scale)))
    local targetCapW = math.floor(math.min(layout.w, 192 * scale))
    local targetCapH = math.floor(math.min(layout.h, 34 * scale))
    local hudW = math.floor(targetCapW + (layout.w - targetCapW) * compactRatio)
    local hudH = math.floor(targetCapH + (layout.h - targetCapH) * compactRatio)
    local hudR = math.floor((targetCapH * 0.5) + (layout.r - (targetCapH * 0.5)) * compactRatio)
    local hudX = math.floor(layout.x + (layout.w - hudW) * 0.5)
    local hudY = math.floor(layout.y + (layout.h - hudH) * 0.5)
    
    Render.FilledRect(Vec2(hudX, hudY), Vec2(hudX + hudW, hudY + hudH), FadeColor(Color(12, 12, 16, 245), aMul), hudR)
    Render.Rect(Vec2(hudX, hudY), Vec2(hudX + hudW, hudY + hudH), FadeColor(Color(255, 255, 255, 26), aMul), hudR, Enum.DrawFlags.None, 1.0)
    
    local centerY = math.floor(hudY + hudH * 0.5)
    local leftPad = math.floor(12 * scale)
    local rightPad = math.floor(14 * scale)
    
    local vol = VolumeState.Current
    local iconSize = math.floor(15 * scale)
    local iconX = hudX + leftPad
    local iconY = centerY - math.floor(iconSize * 0.5)
    
    local volSvg = (vol <= 0.5) and GetVectorIcon("mute") or GetVectorIcon("volume")
    if volSvg then
        Render.Image(volSvg, Vec2(iconX, iconY), Vec2(iconSize, iconSize), FadeColor(Color(255, 255, 255, 235), aMul), 0)
    end
    
    local trackStartX = math.floor(iconX + iconSize + 10 * scale)
    local trackEndX = math.floor(hudX + hudW - rightPad)
    local trackW = trackEndX - trackStartX
    if trackW > 20 * scale then
        local trackH = math.floor(math.max(6, 7.5 * scale))
        local trackY = math.floor(centerY - trackH * 0.5)
        local trackR = math.floor(trackH * 0.5)
        
        Render.FilledRect(Vec2(trackStartX, trackY), Vec2(trackEndX, trackY + trackH), FadeColor(Color(255, 255, 255, 38), aMul), trackR)
        
        local overstretch = VolumeState.Overstretch or 0.0
        local pct = math.max(0.0, math.min(1.0, vol / 100.0))
        local fillW = math.floor(trackW * pct + overstretch * scale + 0.5)
        fillW = math.max(0, math.min(trackW + math.floor(6 * scale), fillW))
        
        if fillW > 0 then
            local fillEnd = math.min(trackEndX + math.floor(math.max(0, overstretch * scale)), trackStartX + fillW)
            Render.FilledRect(Vec2(trackStartX, trackY), Vec2(fillEnd, trackY + trackH), FadeColor(Color(255, 255, 255, 245), aMul), trackR)
        end
    end
end

local function RenderMediaSharedTransition(fromState, toState, layout, progress)
    local scale = layout.scale
    local fontBold = Config.Fonts.Bold
    local fontMain = Config.Fonts.Main
    local waveCol = MediaData.CoverColor or GetPrimaryThemeColor()
    
    local isExpanding = (toState == StateMachine.States.LARGE_MEDIA)
    local t = math.max(0.0, math.min(1.0, progress or 0.0))
    local smoothT = t * t * (3.0 - 2.0 * t)
    
    local artT = isExpanding and smoothT or (1.0 - smoothT)
    local secAlpha = isExpanding and (smoothT * smoothT) or ((1.0 - smoothT) * (1.0 - smoothT))
    
    local cThumbSize = math.floor(20 * scale)
    local cThumbX = math.floor(layout.x + 8 * scale)
    local cThumbY = math.floor(layout.y + (layout.h - cThumbSize) * 0.5)
    local cThumbR = math.floor(5 * scale)
    
    local pad = math.floor(16 * scale)
    local lThumbSize = math.floor(48 * scale)
    local lThumbX = math.floor(layout.x + pad)
    local lThumbY = math.floor(layout.y + pad)
    local lThumbR = math.floor(12 * scale)
    
    local curThumbX = math.floor(cThumbX + (lThumbX - cThumbX) * artT)
    local curThumbY = math.floor(cThumbY + (lThumbY - cThumbY) * artT)
    local curThumbSize = math.floor(cThumbSize + (lThumbSize - cThumbSize) * artT)
    local curThumbR = math.floor(cThumbR + (lThumbR - cThumbR) * artT)
    
    DrawAlbumThumbnail(curThumbX, curThumbY, curThumbSize, curThumbR, 1.0)
    
    local waveCount = 5
    local waveW = math.floor(waveCount * (2.4 * scale) + (waveCount - 1) * (1.8 * scale))
    local cWaveX = math.floor(layout.x + layout.w - waveW - 10 * scale)
    local cWaveY = math.floor(layout.y + (layout.h - 18 * scale) * 0.5)
    
    local lWaveX = math.floor(layout.x + layout.w - pad - waveW)
    local lWaveY = math.floor(lThumbY + 4 * scale)
    
    local curWaveX = math.floor(cWaveX + (lWaveX - cWaveX) * artT)
    local curWaveY = math.floor(cWaveY + (lWaveY - cWaveY) * artT)
    
    DrawAppleWaveform(curWaveX, curWaveY, 18, waveCount, MediaData.IsPlaying, scale, waveCol, 1.0)
    
    local titleStr = MediaData.Title ~= "" and MediaData.Title or L("Музыка", "Music")
    local artistStr = MediaData.Artist ~= "" and MediaData.Artist or ""
    
    local curInfoX = math.floor(curThumbX + curThumbSize + math.floor((8 + 5 * artT) * scale))
    local cTextStartX = curInfoX
    local cTextY = math.floor(layout.y + (34 * scale - 12 * scale) * 0.5 - 1)
    local cTextAvailW = math.max(10, math.floor((curWaveX - 4 * scale) - cTextStartX))
    
    local lInfoX = curInfoX
    local lInfoY = math.floor(curThumbY + 3 * scale)
    local lMaxInfoW = math.max(10, math.floor(curWaveX - lInfoX - 8 * scale))
    
    local compactAlpha = math.max(0.0, 1.0 - artT * 2.5)
    if compactAlpha > 0.01 then
        local compStr = (artistStr ~= "" and titleStr ~= "") and (titleStr .. " \u{2022} " .. artistStr) or titleStr
        RenderMarqueeText(fontBold, 12 * scale, compStr, cTextStartX, cTextY, cTextAvailW, FadeColor(Config.Colors.TextPrimary, compactAlpha), scale, false)
    end
    
    local largeAlpha = math.max(0.0, (artT - 0.25) / 0.75)^1.5
    if largeAlpha > 0.01 then
        local slideY = math.floor((1.0 - (artT - 0.25) / 0.75) * 5 * scale)
        local curLY = lInfoY + slideY
        local lTitleSize = Render.TextSize(fontBold, 15 * scale, titleStr)
        RenderMarqueeText(fontBold, 15 * scale, titleStr, lInfoX, curLY, lMaxInfoW, FadeColor(Config.Colors.TextPrimary, largeAlpha), scale, false)
        if artistStr ~= "" then
            local artY = curLY + lTitleSize.y + 2 * scale
            RenderMarqueeText(fontMain, 12 * scale, artistStr, lInfoX, artY, lMaxInfoW, FadeColor(Config.Colors.TextSecondary, largeAlpha), scale, false)
        end
    end
    
    if secAlpha > 0.01 then
        local progressY = math.floor(lThumbY + lThumbSize + 14 * scale)
        local progressW = math.floor(layout.w - pad * 2)
        local progressH = math.floor(4.5 * scale)
        
        local curPos = MediaData.Position
        if MediaData.IsPlaying then
            local passed = os.clock() - MediaData.LocalTimeAtPoll
            curPos = curPos + passed
        end
        local duration = math.max(1, MediaData.Duration)
        local progressPct = math.min(1.0, math.max(0.0, curPos / duration))
        
        Render.FilledRect(Vec2(layout.x + pad, progressY), Vec2(layout.x + pad + progressW, progressY + progressH), FadeColor(Config.Colors.TrackProgressBg, secAlpha), 2.5 * scale)
        if progressPct > 0 then
            Render.FilledRect(Vec2(layout.x + pad, progressY), Vec2(layout.x + pad + progressW * progressPct, progressY + progressH), FadeColor(Config.Colors.TextPrimary, secAlpha), 2.5 * scale)
        end
        
        local posText = FormatTime(curPos)
        local remSec = math.max(0, duration - curPos)
        local remText = FormatNegativeTime(remSec)
        local timeY = math.floor(progressY + 6 * scale)
        Render.Text(fontMain, 9.5 * scale, posText, Vec2(layout.x + pad, timeY), FadeColor(Config.Colors.TextSecondary, secAlpha))
        local remSize = Render.TextSize(fontMain, 9.5 * scale, remText)
        Render.Text(fontMain, 9.5 * scale, remText, Vec2(layout.x + layout.w - pad - remSize.x, timeY), FadeColor(Config.Colors.TextSecondary, secAlpha))
        
        local ctrlY = math.floor(timeY + 16 * scale)
        local midX = math.floor(layout.x + layout.w / 2)
        local playY = math.floor(ctrlY + 16 * scale)
        
        local bloomT = artT * artT * (3.0 - 2.0 * artT)
        local elemScale = 0.80 + 0.20 * bloomT
        
        local playScale = ButtonSprings.MediaPlay.scale * elemScale
        local playX = midX
        if MediaData.IsPlaying then
            local bw = math.floor(3.5 * scale * playScale)
            local bh = math.floor(14 * scale * playScale)
            local bx1 = math.floor(playX - 5 * scale * playScale)
            local bx2 = math.floor(playX + 2 * scale * playScale)
            local by = math.floor(playY - bh / 2)
            Render.FilledRect(Vec2(bx1, by), Vec2(bx1 + bw, by + bh), FadeColor(Config.Colors.TextPrimary, secAlpha), 1.2 * scale)
            Render.FilledRect(Vec2(bx2, by), Vec2(bx2 + bw, by + bh), FadeColor(Config.Colors.TextPrimary, secAlpha), 1.2 * scale)
        else
            local tw = math.floor(13 * scale * playScale)
            local th = math.floor(15 * scale * playScale)
            local p1 = Vec2(playX - tw / 3, playY - th / 2)
            local p2 = Vec2(playX - tw / 3, playY + th / 2)
            local p3 = Vec2(playX + tw * 2 / 3, playY)
            Render.FilledTriangle({p1, p2, p3}, FadeColor(Config.Colors.TextPrimary, secAlpha))
        end
        
        local prevTargetX = math.floor(playX - 54 * scale)
        local prevScale = ButtonSprings.MediaPrev.scale * elemScale
        local curPrevX = math.floor(midX + (prevTargetX - midX) * bloomT)
        local triW = math.floor(8 * scale * prevScale)
        local triH = math.floor(11 * scale * prevScale)
        local pp1 = Vec2(curPrevX + triW, playY - triH / 2)
        local pp2 = Vec2(curPrevX + triW, playY + triH / 2)
        local pp3 = Vec2(curPrevX, playY)
        Render.FilledTriangle({pp1, pp2, pp3}, FadeColor(Config.Colors.TextPrimary, secAlpha))
        local pp4 = Vec2(curPrevX, playY - triH / 2)
        local pp5 = Vec2(curPrevX, playY + triH / 2)
        local pp6 = Vec2(curPrevX - triW, playY)
        Render.FilledTriangle({pp4, pp5, pp6}, FadeColor(Config.Colors.TextPrimary, secAlpha))
        
        local nextTargetX = math.floor(playX + 54 * scale)
        local nextScale = ButtonSprings.MediaNext.scale * elemScale
        local curNextX = math.floor(midX + (nextTargetX - midX) * bloomT)
        local ntriW = math.floor(8 * scale * nextScale)
        local ntriH = math.floor(11 * scale * nextScale)
        local np1 = Vec2(curNextX - ntriW, playY - ntriH / 2)
        local np2 = Vec2(curNextX - ntriW, playY + ntriH / 2)
        local np3 = Vec2(curNextX, playY)
        Render.FilledTriangle({np1, np2, np3}, FadeColor(Config.Colors.TextPrimary, secAlpha))
        local np4 = Vec2(curNextX, playY - ntriH / 2)
        local np5 = Vec2(curNextX, playY + ntriH / 2)
        local np6 = Vec2(curNextX + ntriW, playY)
        Render.FilledTriangle({np4, np5, np6}, FadeColor(Config.Colors.TextPrimary, secAlpha))
        
        local shufTargetX = math.floor(layout.x + pad + 12 * scale)
        local shufScale = ButtonSprings.MediaShuffle.scale * elemScale
        local curShufX = math.floor(midX + (shufTargetX - midX) * bloomT)
        local shufH = GetVectorIcon("shuffle")
        if shufH then
            local shufCol = MediaData.Shuffle and Color(255, 255, 255, 255) or Color(255, 255, 255, 90)
            local sSz = 14 * scale * shufScale
            Render.Image(shufH, Vec2(curShufX - sSz / 2, playY - sSz / 2), Vec2(sSz, sSz), FadeColor(shufCol, secAlpha), 0)
        end
        
        local repTargetX = math.floor(prevTargetX - 36 * scale)
        local repScale = ButtonSprings.MediaRepeat.scale * elemScale
        local curRepX = math.floor(midX + (repTargetX - midX) * bloomT)
        local repH = GetVectorIcon("repeat")
        if repH then
            local repCol = (MediaData.RepeatMode > 0) and Color(255, 255, 255, 255) or Color(255, 255, 255, 90)
            local rSz = 14 * scale * repScale
            Render.Image(repH, Vec2(curRepX - rSz / 2, playY - rSz / 2), Vec2(rSz, rSz), FadeColor(repCol, secAlpha), 0)
            if MediaData.RepeatMode == 2 then
                Render.Text(fontBold, 7.5 * scale * elemScale, "1", Vec2(curRepX + 5 * scale, playY - 7 * scale), FadeColor(Color(255, 255, 255, 255), secAlpha))
            end
        end
        
        local likeTargetX = math.floor(layout.x + layout.w - pad - 12 * scale)
        local likeScale = ButtonSprings.MediaLike.scale * elemScale
        local curLikeX = math.floor(midX + (likeTargetX - midX) * bloomT)
        local likeSvg = MediaData.IsLiked and GetVectorIcon("heart_filled") or GetVectorIcon("heart_outline")
        if likeSvg then
            local lSz = 14 * scale * likeScale
            local lCol = MediaData.IsLiked and Color(255, 45, 85, 255) or Color(255, 255, 255, 120)
            Render.Image(likeSvg, Vec2(curLikeX - lSz / 2, playY - lSz / 2), Vec2(lSz, lSz), FadeColor(lCol, secAlpha), 0)
        end
    end
end

local function RenderIdleSharedTransition(fromState, toState, layout, progress)
    local scale = layout.scale
    local fontBold = Config.Fonts.Bold
    local fontMain = Config.Fonts.Main
    local isExpanding = (toState == StateMachine.States.LARGE_IDLE)
    local t = math.max(0.0, math.min(1.0, progress or 0.0))
    local smoothT = t * t * (3.0 - 2.0 * t)
    local elemT = isExpanding and smoothT or (1.0 - smoothT)

    local renderedChips = {}
    local compactMap = {}
    local totalCompactW = 0

    for idx, id in ipairs(HUDCustomizer.ActiveChips) do
        local c = GetChipContent(id)
        local chipW = GetChipStandardWidth(id, scale)
        local entry = { id = id, svgKey = c.svgKey, text = c.text, font = c.font, color = c.color, width = chipW, offset = totalCompactW }
        table.insert(renderedChips, entry)
        totalCompactW = totalCompactW + chipW
        if idx < #HUDCustomizer.ActiveChips then
            totalCompactW = totalCompactW + 12 * scale
        end
    end

    local compactStartX = math.floor(layout.x + (layout.w - totalCompactW) / 2)
    local midY = math.floor(layout.y + layout.h / 2)

    for idx, chip in ipairs(renderedChips) do
        compactMap[chip.id] = {
            startX = compactStartX + chip.offset,
            midY = midY,
            chip = chip
        }
    end

    local pad = math.floor(16 * scale)
    local lClockX = math.floor(layout.x + pad)
    local lClockY = math.floor(layout.y + pad + 2 * scale)
    local lFontSize = 26 * scale
    local cFontSize = 11.5 * scale

    local cClockX = compactMap["clock"] and (compactMap["clock"].startX + (compactMap["clock"].chip.svgKey and (18 * scale) or 0)) or math.floor(layout.x + layout.w * 0.5 - 20 * scale)
    local cClockY = math.floor(midY - 5.5 * scale + MenuTextOffsetY * scale)

    local curClockX = math.floor(cClockX + (lClockX - cClockX) * elemT)
    local curClockY = math.floor(cClockY + (lClockY - cClockY) * elemT)
    local curFontSize = cFontSize + (lFontSize - cFontSize) * elemT

    local timeHM = os.date("%H:%M")
    Render.Text(fontBold, curFontSize, timeHM, Vec2(curClockX, curClockY), Config.Colors.TextPrimary)

    local divX = math.floor(layout.x + 140 * scale)
    local rightX = math.floor(divX + 14 * scale)
    local goldX = math.floor(rightX + 85 * scale)
    local row1Y = math.floor(layout.y + 16 * scale)
    local row2Y = math.floor(layout.y + 44 * scale)

    local compactAlpha = math.max(0.0, 1.0 - elemT * 1.5)
    if compactAlpha > 0.01 then
        local curX = compactStartX
        for idx, chip in ipairs(renderedChips) do
            if chip.id ~= "clock" and chip.id ~= "fps" and chip.id ~= "ping" and chip.id ~= "gold" and chip.id ~= "kda" then
                local refSize = Render.TextSize(chip.font, 11 * scale, "0123456789")
                local ty = math.floor(midY - refSize.y / 2 + MenuTextOffsetY * scale)
                if chip.svgKey then
                    local iconHandle = GetVectorIcon(chip.svgKey)
                    local iconSz = math.floor(13 * scale)
                    local iconX = curX
                    local iconY = math.floor(midY - iconSz / 2 + MenuIconOffsetY * scale)
                    if iconHandle then
                        Render.Image(iconHandle, Vec2(iconX, iconY), Vec2(iconSz, iconSz), FadeColor(chip.color, compactAlpha), 0)
                    end
                    local tx = curX + iconSz + math.floor(5 * scale)
                    Render.Text(chip.font, 11 * scale, chip.text, Vec2(tx, ty), FadeColor(chip.color, compactAlpha))
                else
                    Render.Text(chip.font, 11 * scale, chip.text, Vec2(curX, ty), FadeColor(chip.color, compactAlpha))
                end
            end
            curX = curX + chip.width
            if idx < #renderedChips then
                local dotR = 1.6 * scale
                local dotX = curX + 6 * scale
                Render.FilledCircle(Vec2(dotX, midY), dotR, FadeColor(Config.Colors.TextMuted, compactAlpha), 0, 1.0, 12)
                curX = dotX + 6 * scale
            end
        end
    end

    if elemT > 0.01 then
        local divStartY = math.floor(layout.y + 14 * scale)
        local divTotalH = math.max(10, math.floor(layout.h - 28 * scale))
        local divCurH = math.floor(divTotalH * elemT)
        Render.Line(Vec2(divX, divStartY), Vec2(divX, divStartY + divCurH), FadeColor(Config.Colors.Border, elemT), 1.0)

        local hmSize = Render.TextSize(fontBold, curFontSize, timeHM)
        local timeSec = os.date(":%S")
        local secX = math.floor(curClockX + hmSize.x + 3 * scale)
        local secY = math.floor(curClockY + curFontSize * 0.35)
        local secAlpha = math.max(0.0, (elemT - 0.20) / 0.80)^1.5
        if secAlpha > 0.01 then
            Render.Text(fontMain, 13 * scale, timeSec, Vec2(secX, secY), FadeColor(Config.Colors.TextSecondary, secAlpha))
            local matchTime = GetActualMatchTime()
            local subInfo = (matchTime and matchTime > 0) and (L("Матч ", "Match ") .. FormatTime(matchTime)) or L("Главное меню", "Main Menu")
            Render.Text(fontMain, 10.5 * scale, subInfo, Vec2(lClockX, curClockY + hmSize.y + 5 * scale), FadeColor(Config.Colors.TextMuted, secAlpha))
        end

        local unfoldAlpha = math.max(0.0, (elemT - 0.20) / 0.80)^1.5
        local unfoldShiftX = math.floor((1.0 - elemT) * -16 * scale)

        if compactMap["fps"] then
            local startX = compactMap["fps"].startX
            local startY = compactMap["fps"].midY - math.floor(6.5 * scale)
            local targetIconX = rightX
            local targetIconY = row2Y + 4 * scale
            local curIconX = math.floor(startX + (targetIconX - startX) * elemT)
            local curIconY = math.floor(startY + (targetIconY - startY) * elemT)
            local fpsSvg = GetVectorIcon("fps")
            local curFpsCol = LerpColor(compactMap["fps"].chip.color or Color(52, 199, 89, 255), Color(255, 255, 255, 255), elemT)
            if fpsSvg then Render.Image(fpsSvg, Vec2(curIconX, curIconY), Vec2(12 * scale, 12 * scale), FadeColor(curFpsCol, 0.86), 0) end
            local fpsTxt = string.format("%d%s", PerformanceData.FPS, elemT > 0.4 and " FPS" or "")
            Render.Text(elemT > 0.4 and fontMain or fontBold, (11 - 0.5 * elemT) * scale, fpsTxt, Vec2(curIconX + 16 * scale, curIconY - 1 * scale), curFpsCol)
        else
            if unfoldAlpha > 0.01 then
                local uX = rightX + unfoldShiftX
                local fpsSvg = GetVectorIcon("fps")
                if fpsSvg then Render.Image(fpsSvg, Vec2(uX, row2Y + 4 * scale), Vec2(12 * scale, 12 * scale), FadeColor(Color(255, 255, 255, 220), unfoldAlpha), 0) end
                local fpsTxt = string.format("%d FPS", PerformanceData.FPS)
                Render.Text(fontMain, 10.5 * scale, fpsTxt, Vec2(uX + 16 * scale, row2Y + 3 * scale), FadeColor(Color(255, 255, 255, 240), unfoldAlpha))
            end
        end

        if compactMap["ping"] then
            local startX = compactMap["ping"].startX
            local startY = compactMap["ping"].midY - math.floor(6.5 * scale)
            local targetIconX = goldX
            local targetIconY = row2Y + 4 * scale
            local curIconX = math.floor(startX + (targetIconX - startX) * elemT)
            local curIconY = math.floor(startY + (targetIconY - startY) * elemT)
            local pingSvg = GetVectorIcon("ping")
            local curPingCol = LerpColor(compactMap["ping"].chip.color or Color(10, 132, 255, 255), Color(255, 255, 255, 255), elemT)
            if pingSvg then Render.Image(pingSvg, Vec2(curIconX, curIconY), Vec2(12 * scale, 12 * scale), FadeColor(curPingCol, 0.86), 0) end
            local pingTxt = string.format("%d ms", PerformanceData.Ping)
            Render.Text(elemT > 0.4 and fontMain or fontBold, (11 - 0.5 * elemT) * scale, pingTxt, Vec2(curIconX + 16 * scale, curIconY - 1 * scale), curPingCol)
        else
            if unfoldAlpha > 0.01 then
                local uX = goldX + unfoldShiftX
                local pingSvg = GetVectorIcon("ping")
                if pingSvg then Render.Image(pingSvg, Vec2(uX, row2Y + 4 * scale), Vec2(12 * scale, 12 * scale), FadeColor(Color(255, 255, 255, 220), unfoldAlpha), 0) end
                local pingTxt = string.format("%d ms", PerformanceData.Ping)
                Render.Text(fontMain, 10.5 * scale, pingTxt, Vec2(uX + 16 * scale, row2Y + 3 * scale), FadeColor(Color(255, 255, 255, 240), unfoldAlpha))
            end
        end

        if compactMap["kda"] then
            local startX = compactMap["kda"].startX
            local startY = compactMap["kda"].midY - math.floor(6.5 * scale)
            local targetIconX = rightX
            local targetIconY = row1Y
            local curIconX = math.floor(startX + (targetIconX - startX) * elemT)
            local curIconY = math.floor(startY + (targetIconY - startY) * elemT)
            local kdaSvg = GetVectorIcon("kda")
            if kdaSvg then Render.Image(kdaSvg, Vec2(curIconX, curIconY), Vec2(12 * scale, 12 * scale), FadeColor(Color(255, 255, 255, 220), 1.0), 0) end
            local kdaTxt = string.format("%d / %d / %d", HeroData.Kills, HeroData.Deaths, HeroData.Assists)
            Render.Text(fontBold, 11 * scale, kdaTxt, Vec2(curIconX + 16 * scale, curIconY - 1 * scale), Config.Colors.TextPrimary)
        else
            if unfoldAlpha > 0.01 then
                local uX = rightX + unfoldShiftX
                local kdaSvg = GetVectorIcon("kda")
                if kdaSvg then Render.Image(kdaSvg, Vec2(uX, row1Y), Vec2(12 * scale, 12 * scale), FadeColor(Color(255, 255, 255, 220), unfoldAlpha), 0) end
                local kdaTxt = string.format("%d / %d / %d", HeroData.Kills, HeroData.Deaths, HeroData.Assists)
                Render.Text(fontBold, 11 * scale, kdaTxt, Vec2(uX + 16 * scale, row1Y - 1 * scale), FadeColor(Config.Colors.TextPrimary, unfoldAlpha))
            end
        end

        if compactMap["gold"] then
            local startX = compactMap["gold"].startX
            local startY = compactMap["gold"].midY - math.floor(6.5 * scale)
            local targetIconX = goldX
            local targetIconY = row1Y
            local curIconX = math.floor(startX + (targetIconX - startX) * elemT)
            local curIconY = math.floor(startY + (targetIconY - startY) * elemT)
            local goldSvg = GetVectorIcon("gold")
            local curGoldCol = LerpColor(compactMap["gold"].chip.color or Color(255, 215, 30, 255), Color(255, 255, 255, 255), elemT)
            if goldSvg then Render.Image(goldSvg, Vec2(curIconX, curIconY), Vec2(12 * scale, 12 * scale), FadeColor(curGoldCol, 0.86), 0) end
            local goldTxt = string.format("%d G", HeroData.Gold)
            Render.Text(fontBold, 11 * scale, goldTxt, Vec2(curIconX + 16 * scale, curIconY - 1 * scale), curGoldCol)
        else
            if unfoldAlpha > 0.01 then
                local uX = goldX + unfoldShiftX
                local goldSvg = GetVectorIcon("gold")
                if goldSvg then Render.Image(goldSvg, Vec2(uX, row1Y), Vec2(12 * scale, 12 * scale), FadeColor(Color(255, 255, 255, 220), unfoldAlpha), 0) end
                local goldTxt = string.format("%d G", HeroData.Gold)
                Render.Text(fontBold, 11 * scale, goldTxt, Vec2(uX + 16 * scale, row1Y - 1 * scale), FadeColor(Config.Colors.TextPrimary, unfoldAlpha))
            end
        end
    end
end

local function RenderStateLayer(state, layout, alphaMul, yOffset)
    if alphaMul <= 0.01 then return end
    if state == StateMachine.States.COMPACT_IDLE then
        RenderModularIdlePill(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.COMPACT_MEDIA then
        if IsMediaActive() then
            RenderCompactMedia(layout, alphaMul, yOffset)
        else
            RenderModularIdlePill(layout, alphaMul, yOffset)
        end
    elseif state == StateMachine.States.COMPACT_FIGHT then
        if FightTracker.Active then
            RenderFightCompact(layout, alphaMul, yOffset)
        else
            if IsMediaActive() then
                RenderCompactMedia(layout, alphaMul, yOffset)
            else
                RenderModularIdlePill(layout, alphaMul, yOffset)
            end
        end
    elseif state == StateMachine.States.NOTIFICATION then
        RenderNotificationState(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.GAME_PAUSED then
        RenderGamePausedPill(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.COURIER_DELIVERY then
        RenderCourierDeliveryPill(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.COURIER_DELIVERED then
        RenderCourierDeliveredPill(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.COURIER_LARGE then
        RenderCourierLarge(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.LARGE_MEDIA then
        if IsMediaActive() then
            RenderLargeMedia(layout, alphaMul, yOffset)
        else
            RenderLargeIdle(layout, alphaMul, yOffset)
        end
    elseif state == StateMachine.States.LARGE_FIGHT then
        if FightTracker.Active then
            RenderFightLarge(layout, alphaMul, yOffset)
        else
            RenderLargeIdle(layout, alphaMul, yOffset)
        end
    elseif state == StateMachine.States.LARGE_IDLE then
        RenderLargeIdle(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.MENU_IDLE then
        RenderMenuIdlePill(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.MENU_SEARCHING then
        RenderMenuSearchingPill(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.MENU_MATCH_FOUND then
        RenderMenuMatchFoundPill(layout, alphaMul, yOffset)
    end
end

local function RenderDragGuides(layout)
    if not DragState.IsDragging then return end
    
    local scr = Render.ScreenSize()
    Render.FilledRect(Vec2(0, 0), scr, Config.Colors.GridOverlay)
    
    local midScreenX = math.floor(scr.x / 2)
    Render.Line(Vec2(midScreenX, 0), Vec2(midScreenX, scr.y), Config.Colors.GridAxis, 1.0)
    
    local islandCenterX = math.floor(layout.x + layout.w / 2)
    local islandCenterY = math.floor(layout.y + layout.h / 2)
    Render.Line(Vec2(islandCenterX, 0), Vec2(islandCenterX, scr.y), Config.Colors.GridHighlight, 1.0)
    Render.Line(Vec2(0, islandCenterY), Vec2(scr.x, islandCenterY), Config.Colors.GridHighlight, 1.0)
    
    local guideCol = Config.Colors.GridHighlight
    Render.Rect(Vec2(layout.x - 3, layout.y - 3), Vec2(layout.x + layout.w + 3, layout.y + layout.h + 3), guideCol, layout.r + 3, Enum.DrawFlags.None, 1.5)
    
    local fontBold = Config.Fonts.Bold
    local hintText = string.format("X: %d   Y: %d", math.floor(layout.x), math.floor(layout.y))
    local hSize = Render.TextSize(fontBold, 11, hintText)
    local hx = math.floor(layout.x + (layout.w - hSize.x) / 2)
    local hy = math.floor(layout.y + layout.h + 8)
    Render.Text(fontBold, 11, hintText, Vec2(hx, hy), Config.Colors.TextPrimary)
end

local LastMenuOpenState = false
local LastRenderTime = 0
local LastUpdateTime = 0

function DynamicIsland.OnDraw()
    if not UI or not UI.Main.Enabled:Get() then return end
    local inGame = Engine.IsInGame and Engine.IsInGame()
    if UI.Main.OnlyInGame:Get() and not inGame then return end
    
    local curClock = os.clock()
    if math.abs(curClock - LastRenderTime) < 0.001 then return end
    LastRenderTime = curClock
    
    if Menu.Opened then
        local isOpened = Menu.Opened()
        if LastMenuOpenState and not isOpened then
            SaveAllConfig()
        end
        LastMenuOpenState = isOpened
    end
    
    local curClock = os.clock()
    local dt = 0.016
    if StateMachine.LastDrawTime > 0 then
        dt = math.min(0.04, math.max(0.001, curClock - StateMachine.LastDrawTime))
    end
    StateMachine.LastDrawTime = curClock
    dt = dt / AnimScale()
    
    if VolumeState.Visible then
        local nowC = os.clock()
        if nowC - VolumeState.LastActive > 1.2 then
            VolumeState.Alpha = math.max(0.0, VolumeState.Alpha - dt * 4.0)
            if VolumeState.Alpha <= 0.01 then
                VolumeState.Visible = false
                VolumeState.Overstretch = 0.0
                VolumeState.OverstretchVel = 0.0
            end
        else
            VolumeState.Alpha = math.min(1.0, VolumeState.Alpha + dt * 8.0)
        end
        local nC, nVC = MotionEngine.SolveSpring(VolumeState.Current or 50.0, VolumeState.CurrentVel or 0.0, VolumeState.Target or 50.0, dt, 42.0, 0.88, 0.1)
        VolumeState.Current = nC
        VolumeState.CurrentVel = nVC
        local nO, nVO = MotionEngine.SolveSpring(VolumeState.Overstretch or 0.0, VolumeState.OverstretchVel or 0.0, 0.0, dt, 32.0, 0.72, 0.15)
        VolumeState.Overstretch = nO
        VolumeState.OverstretchVel = nVO
    end
    
    local isPureGlass = IsPureGlass()
    local currentBg = UI.Main.IslandBgColor:Get()
    local targetFactor = ThemeSpring.target
    if not isPureGlass and currentBg then
        local lum = (currentBg.r * 0.299 + currentBg.g * 0.587 + currentBg.b * 0.114)
        -- hysteresis: hold the current palette inside the dead zone so the
        -- spring never flaps when the bg luminance sits near the threshold
        if targetFactor > 0.5 then
            if lum < 120 then targetFactor = 0.0 end
        else
            if lum > 150 then targetFactor = 1.0 end
        end
    else
        targetFactor = 0.0
    end
    ThemeSpring.target = targetFactor

    local nF, nV = SolveDampedSpring(ThemeSpring.factor, ThemeSpring.vel, targetFactor, dt, 14.0, 0.80)
    ThemeSpring.factor = nF
    ThemeSpring.vel = nV

    local f = math.min(1.0, math.max(0.0, ThemeSpring.factor))
    Config.Colors.TextPrimary = LerpColor(Color(255, 255, 255, 255), Color(18, 18, 24, 255), f)
    Config.Colors.TextSecondary = LerpColor(Color(160, 160, 170, 255), Color(65, 65, 75, 230), f)
    Config.Colors.TextMuted = LerpColor(Color(120, 120, 130, 255), Color(110, 110, 120, 200), f)
    Config.Colors.Border = LerpColor(Color(255, 255, 255, 28), Color(0, 0, 0, 35), f)
    Config.Colors.TrackProgressBg = LerpColor(Color(255, 255, 255, 40), Color(0, 0, 0, 28), f)
    Config.Colors.ChipActive = LerpColor(Color(255, 255, 255, 52), Color(0, 0, 0, 35), f)
    Config.Colors.ChipActiveBorder = LerpColor(Color(255, 255, 255, 225), Color(0, 0, 0, 180), f)
    Config.Colors.ChipInactive = LerpColor(Color(255, 255, 255, 10), Color(0, 0, 0, 10), f)
    Config.Colors.ChipInactiveBorder = LerpColor(Color(255, 255, 255, 24), Color(0, 0, 0, 24), f)
    Config.Colors.TextInverse = LerpColor(Color(18, 18, 24, 255), Color(255, 255, 255, 255), f)
    
    PerformanceData.FrameCount = PerformanceData.FrameCount + 1
    if curClock - PerformanceData.LastFPSUpdate >= 0.5 then
        local elapsed = curClock - PerformanceData.LastFPSUpdate
        PerformanceData.FPS = math.floor(PerformanceData.FrameCount / elapsed)
        PerformanceData.FrameCount = 0
        PerformanceData.LastFPSUpdate = curClock
    end
    
    local scale = (UI and UI.Main and UI.Main.Scale) and (UI.Main.Scale:Get() / 100.0) or 1.0
    
    local targetW = Config.Dimensions.CompactTargetW or Config.Dimensions.CompactW
    local targetH = Config.Dimensions.CompactTargetH or Config.Dimensions.CompactH
    local targetR = Config.Dimensions.CompactTargetR or Config.Dimensions.CompactRadius
    
    local prof = MotionEngine.GetProfile(MotionEngine.CurrentProfile)
    local smoothDt = MotionEngine.UpdateSmoothedDt(dt)
    
    local newW, newVelW = MotionEngine.SolveSpring(StateMachine.Spring.W.value, StateMachine.Spring.W.vel, targetW, smoothDt, prof.omega, prof.zeta)
    StateMachine.Spring.W.value = newW
    StateMachine.Spring.W.vel = newVelW
    
    local newH, newVelH = MotionEngine.SolveSpring(StateMachine.Spring.H.value, StateMachine.Spring.H.vel, targetH, smoothDt, prof.omega, prof.zeta)
    StateMachine.Spring.H.value = newH
    StateMachine.Spring.H.vel = newVelH
    
    local newR, newVelR = MotionEngine.SolveSpring(StateMachine.Spring.Radius.value, StateMachine.Spring.Radius.vel, targetR, smoothDt, prof.omega * 1.1, prof.zeta)
    StateMachine.Spring.Radius.value = newR
    StateMachine.Spring.Radius.vel = newVelR
    
    local squishProf = MotionEngine.GetProfile("SQUISH")
    local newSq, newVelSq = MotionEngine.SolveSpring(StateMachine.Spring.Squish.value, StateMachine.Spring.Squish.vel, 0, smoothDt, squishProf.omega, squishProf.zeta)
    StateMachine.Spring.Squish.value = newSq
    StateMachine.Spring.Squish.vel = newVelSq
    
    local btnProf = MotionEngine.GetProfile("BUTTON")
    for btnName, btnData in pairs(ButtonSprings) do
        local nS, nV = MotionEngine.SolveSpring(btnData.scale, btnData.vel, 1.0, smoothDt, btnProf.omega, btnProf.zeta)
        btnData.scale = nS
        btnData.vel = nV
    end
    
    local fromAlpha = 0.0
    local toAlpha = 1.0
    local toYOffset = 0.0
    local fromYOffset = 0.0
    
    if StateMachine.Transition.Active then
        local elapsed = curClock - StateMachine.Transition.StartTime
        local animDur = math.max(0.18, StateMachine.Transition.Duration * AnimScale())
        local t = math.min(1.0, elapsed / animDur)
        StateMachine.Transition.Progress = t
        
        local smoothT = t * t * (3.0 - 2.0 * t)
        fromAlpha = math.max(0.0, 1.0 - (smoothT / 0.65))
        toAlpha = math.max(0.0, math.min(1.0, (smoothT - 0.20) / 0.80))
        
        fromYOffset = -(smoothT * 5.0 * scale)
        toYOffset = ((1.0 - smoothT) * 5.0 * scale)
        
        if t >= 1.0 then
            StateMachine.Transition.Active = false
            StateMachine.Current = StateMachine.TargetState
            fromAlpha = 0.0
            toAlpha = 1.0
            toYOffset = 0.0
            fromYOffset = 0.0
            NotificationQueue.LastDismissed = nil
        end
    else
        StateMachine.Current = StateMachine.TargetState
        toAlpha = 1.0
        fromAlpha = 0.0
        toYOffset = 0.0
        fromYOffset = 0.0
    end
    
    if Haptic and Haptic.Update then
        Haptic.Update(dt)
    end
    
    local layout = GetIslandLayout()
    if layout.w <= 0 or layout.h <= 0 then return end
    
    RenderDragGuides(layout)
    
    local p1 = Vec2(layout.x, layout.y)
    local p2 = Vec2(layout.x + layout.w, layout.y + layout.h)
    
    if UI.Media.Shadow:Get() then
        Render.Shadow(p1, p2, Config.Colors.Shadow, 16, layout.r, Enum.DrawFlags.ShadowCutOutShapeBackground, Vec2(0, 3))
    end
    
    IslandSurface(p1, p2, layout.r, HUDCustomizer.IsOpen and Config.Colors.PMenuIslandBorder or Config.Colors.Border, HUDCustomizer.IsOpen and 1.2 or 1.0)
    
    if Haptic and Haptic.State and Haptic.State.GlowAlpha > 1.0 then
        local gAlpha = math.min(255, math.floor(Haptic.State.GlowAlpha))
        local gCol = Haptic.State.GlowColor or Color(255, 255, 255, 255)
        local tactileBorderCol = Color(gCol.r, gCol.g, gCol.b, math.floor(gCol.a * (gAlpha / 255)))
        Render.Rect(p1, p2, tactileBorderCol, layout.r, Enum.DrawFlags.None, 1.8)
    end
    
    Render.PushClip(p1, p2)
    
    if StateMachine.Transition.Active then
        local fState = StateMachine.Transition.FromState
        local tState = StateMachine.Transition.ToState
        if (fState == StateMachine.States.COMPACT_MEDIA and tState == StateMachine.States.LARGE_MEDIA) or
           (fState == StateMachine.States.LARGE_MEDIA and tState == StateMachine.States.COMPACT_MEDIA) then
            RenderMediaSharedTransition(fState, tState, layout, StateMachine.Transition.Progress)
        elseif (fState == StateMachine.States.COMPACT_IDLE and tState == StateMachine.States.LARGE_IDLE) or
               (fState == StateMachine.States.LARGE_IDLE and tState == StateMachine.States.COMPACT_IDLE) then
            RenderIdleSharedTransition(fState, tState, layout, StateMachine.Transition.Progress)
        else
            if fromAlpha > 0.01 then
                RenderStateLayer(fState, layout, fromAlpha, fromYOffset)
            end
            if toAlpha > 0.01 then
                RenderStateLayer(tState, layout, toAlpha, toYOffset)
            end
        end
    else
        RenderStateLayer(StateMachine.Current, layout, 1.0, 0.0)
    end
    
    if VolumeState.Visible and VolumeState.Alpha > 0.01 then
        RenderVolumeOverlay(layout, VolumeState.Alpha)
    end
    
    Render.PopClip()
    
    RenderSecondarySatelliteBubble(layout)
    RenderMenuClosedHint(layout)
    RenderHUDDrawer(layout, dt)
end

function DynamicIsland.OnUpdate()
    local curClock = os.clock()
    if math.abs(curClock - LastUpdateTime) < 0.001 then return end
    LastUpdateTime = curClock
    
    local inGame = Engine.IsInGame and Engine.IsInGame()
    if inGame then
        HeroData.Local = (Heroes and Heroes.GetLocal) and Heroes.GetLocal() or nil
        if HeroData.Local and HeroData.HeroName == "" then
            HeroData.HeroName = NPC.GetUnitName(HeroData.Local)
        end
        if HeroData.Local then
            ProcessFightDetector()
        end
        ProcessGameEvents()
        ProcessPauseTracker()
        ProcessCourierTracker()
    else
        HeroData.Local = nil
        PauseTracker.IsPaused = false
        PauseTracker.PauseStartTime = 0
        CourierTracker.Delivering = false
        CourierTracker.Delivered = false
        CourierTracker.IsGoingToStash = false
        CourierTracker.Progress = 0.0
        CourierTracker.StartDistance = 0
        CourierTracker.BasePos = nil
        CourierTracker.CachedCourier = nil
    end
    HandleInteractions()
    PollMediaBridge()
end

function DynamicIsland.OnScriptsLoaded()
    LoadScriptFonts()
    InitMenu()
    LoadAllConfig()
    
    local inGame = Engine.IsInGame and Engine.IsInGame()
    if inGame then
        HeroData.Local = Heroes.GetLocal()
        if HeroData.Local then
            HeroData.HeroName = NPC.GetUnitName(HeroData.Local)
            HeroData.Level = NPC.GetCurrentLevel(HeroData.Local)
        end
        StateMachine.Current = StateMachine.States.COMPACT_IDLE
        StateMachine.TargetState = StateMachine.States.COMPACT_IDLE
    else
        HeroData.Local = nil
        CourierTracker.BasePos = nil
        CourierTracker.CachedCourier = nil
        StateMachine.Current = StateMachine.States.MENU_IDLE
        StateMachine.TargetState = StateMachine.States.MENU_IDLE
    end
    
    StateMachine.Spring.W.value = Config.Dimensions.CompactW
    StateMachine.Spring.H.value = Config.Dimensions.CompactH
    StateMachine.Spring.Radius.value = Config.Dimensions.CompactRadius
    StateMachine.Spring.Squish.value = 0
    
    PollMediaBridge()
end

DynamicIsland.OnFrame = DynamicIsland.OnDraw
DynamicIsland.OnUpdateEx = DynamicIsland.OnUpdate
DynamicIsland.HapticPlaySound = HapticPlaySound
DynamicIslandGlobal = DynamicIsland

return DynamicIsland
