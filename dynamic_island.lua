local math, string, table, os, io, utf8 = (function(...)
    local out = {}
    for i, lib in ipairs({ ... }) do
        local c = {}
        for k, v in pairs(lib) do c[k] = v end
        out[i] = c
    end
    return table.unpack(out, 1, 6)
end)(math, string, table, os, io, utf8 or {})
local pairs, ipairs, type, tostring, tonumber, pcall, error, setmetatable = pairs, ipairs, type, tostring, tonumber, pcall, error, setmetatable

--[[
     ~ qLocalization
     ~ automatic localization wrapper for Lua menu interfaces

     ~ author: qfun (qfun_g9s)
]]

local qLocalization = (function()
	local lib = {}

	local a = function(...)
		return ...
	end

	local state = {
		lang = Menu.Find("SettingsHidden", "", "", "", "Main", "Language"),
		instances = {},
	}

	local setters = {
		ToolTip = "tooltip",
	}
	local fast_methods = { Get = true, Set = true, Opened = true, IsOpened = true }

	local helpers
	do
		helpers = {
			resolve = a(function(root, path)
				for key in string.gmatch(path, "[^.]+") do
					if type(root) ~= "table" then
						return
					end

					root = root[key]
				end

				return root
			end),

			is_object = a(function(value)
				return type(value) == "table" or type(value) == "userdata"
			end),

			has_method = a(function(object, name)
				return helpers.is_object(object) and type(object[name]) == "function"
			end),

			is_menu_object = a(function(value)
				return helpers.has_method(value, "Name") and helpers.has_method(value, "Type")
			end),

			is_list = a(function(value)
				if type(value) ~= "table" or #value == 0 then
					return false
				end

				for i = 1, #value do
					if type(value[i]) ~= "string" then
						return false
					end
				end

				return true
			end),

			is_indexed_list = a(function(object)
				return helpers.has_method(object, "List") and not helpers.has_method(object, "ListEnabled")
			end),
		}
	end

	function lib.new(translations)
		local languages = {}

		for i, name in ipairs(state.lang and state.lang:List() or {}) do
			local code = string.match(name, "%a+")

			if code and translations[code] then
				languages[i - 1] = code
			end
		end

		local localization = {
			translations = translations,
			languages = languages,
			objects = {},
		}

		local methods
		do
			methods = {
				get_language = a(function(language_index)
					if language_index == nil and state.lang then
						language_index = state.lang:Get()
					end

					return localization.languages[language_index] or "en"
				end),

				localize = a(function(path, language_index)
					if type(path) ~= "string" then
						return path
					end

					local language = methods.get_language(language_index)

					return helpers.resolve(localization.translations[language], path)
						or helpers.resolve(localization.translations.en, path)
						or path
				end),

				has = a(function(path)
					if type(path) ~= "string" then
						return false
					end

					return helpers.resolve(localization.translations.en, path) ~= nil
						or helpers.resolve(localization.translations[methods.get_language()], path) ~= nil
				end),

				localize_items = a(function(items, language_index)
					local result, localized = {}, false

					for i = 1, #items do
						local value = items[i]

						if methods.has(value) then
							result[i] = methods.localize(value, language_index)
							localized = true
						else
							result[i] = value
						end
					end

					return result, localized
				end),

				apply = a(function(object, kind, path, language_index)
					if kind == "label" then
						object:ForceLocalization(methods.localize(path, language_index))
					elseif kind == "tooltip" then
						object:ToolTip(methods.localize(path, language_index))
					elseif kind == "items" then
						local value = object:Get()

						object:Update((methods.localize_items(path, language_index)))
						object:Set(value)
					end
				end),

				track = a(function(object, kind, path, apply_now)
					local record = localization.objects[object]

					if record == nil then
						record = {}
						localization.objects[object] = record
					end

					record[kind] = path

					if apply_now then
						methods.apply(object, kind, path)
					end
				end),

				register = a(function(object, path)
					if not methods.has(path) or not helpers.has_method(object, "ForceLocalization") then
						return
					end

					methods.track(object, "label", path, true)
				end),

				update = a(function(language_index)
					for object, record in pairs(localization.objects) do
						for kind, path in pairs(record) do
							methods.apply(object, kind, path, language_index)
						end
					end
				end),

				wrap = a(function(target, bind_self)
					if not helpers.is_object(target) then
						return target
					end

					local proxy
					local cache = {}

					proxy = setmetatable({}, {
						__index = function(_, key)
							local member = target[key]

							if type(member) ~= "function" then
								return member
							end

							local hit = cache[key]
							if hit then
								return hit
							end

							local fn
							if fast_methods[key] then
								if bind_self then
									fn = function(self, ...)
										if self == proxy then
											return member(target, ...)
										end
										return member(self, ...)
									end
								else
									fn = member
								end
								cache[key] = fn
								return fn
							end

							fn = function(...)
								local args = table.pack(...)

								if bind_self and args[1] == proxy then
									table.remove(args, 1)
									args.n = args.n - 1
								end

								if key == "Switch" and args.n < 2 then
									args[2] = false
									args.n = 2
								end

								local name_path, item_paths

								if setters[key] then
									if methods.has(args[1]) then
										methods.track(target, setters[key], args[1], false)

										args[1] = methods.localize(args[1])
									end
								else
									local name_index = bind_self and 1 or args.n

									if methods.has(args[name_index]) then
										name_path = args[name_index]
									end

									local items_index

									if key == "Combo" then
										items_index = 2
									elseif key == "Update" and helpers.is_indexed_list(target) then
										items_index = 1
									end

									if items_index ~= nil and helpers.is_list(args[items_index]) then
										local items, localized = methods.localize_items(args[items_index])

										if localized then
											item_paths = args[items_index]
											args[items_index] = items
										end
									end
								end

								local results

								if bind_self then
									results = table.pack(member(target, table.unpack(args, 1, args.n)))
								else
									results = table.pack(member(table.unpack(args, 1, args.n)))
								end

								for i = 1, results.n do
									local result = results[i]

									if helpers.is_menu_object(result) then
										if name_path then
											methods.register(result, name_path)
										end

										if item_paths then
											methods.track(result, "items", item_paths, false)
											item_paths = nil
										end

										results[i] = methods.wrap(result, true)
									end
								end

								if item_paths then
									methods.track(target, "items", item_paths, false)
								end

								return table.unpack(results, 1, results.n)
							end
							cache[key] = fn
							return fn
						end,

						__newindex = function(_, key, value)
							target[key] = value
						end,
					})

					return proxy
				end),
			}
		end

		state.instances[methods] = true

		return {
			GetLanguage = methods.get_language,

			Get = methods.localize,
			Localize = methods.localize,

			Update = methods.update,
			Register = methods.register,

			Wrap = methods.wrap,

			WrapLibrary = function(library)
				return methods.wrap(library, false)
			end,
		}
	end

	if state.lang then
		state.lang:SetCallback(function(this)
			local language_index = this:Get()

			for methods in pairs(state.instances) do
				methods.update(language_index)
			end
		end, true)
	else
		Log.Write("[qLocalization] Language widget not found, using English fallback")
	end

	return lib
end)()

local MenuTextOffsetY = 0.0
local MenuIconOffsetY = 0.0
local ClipDepth = { n = 0 }
local Render = setmetatable({}, { __index = setmetatable({
    PushClip = function(...)
        ClipDepth.n = ClipDepth.n + 1
        return Render.PushClip(...)
    end,
    PopClip = function(...)
        ClipDepth.n = math.max(0, ClipDepth.n - 1)
        return Render.PopClip(...)
    end
}, { __index = Render }) })

local function PublishIsland(api)
    DynamicIsland = api
end

local function ReadIsland()
    return DynamicIsland
end

local DynamicIsland = {}

local localization = qLocalization.new({
    en = {
        di_ui_spotify_no_port = "Spotify is running without the debug port, likes won't work. Restart it",
        di_ui_yandex_no_port = "Yandex Music is running without the debug port, likes won't work. Restart it",
        di_ui_like_failed = "Could not change the like. Check MediaBridge and restart Yandex Music",
        di_playlist_title = "Add to playlist",
        di_playlist_loading = "Loading playlists...",
        di_playlist_empty = "No playlists found",
        di_playlist_failed = "Could not open playlists in Yandex Music",
        di_playlist_add_failed = "Could not add the track",
        di_playlist_tip = "Add the current Yandex Music track\nto one of your playlists",
        di_media_center_short_title = "Center Short Track Titles",
        di_media_center_short_title_tip = "Center a short track title\nin the small island",
        di_media_show_artist = "Show Artist",
        di_media_show_artist_tip = "Show the artist with the title\nin the small island",
        di_ui_restart_yandex = "Quit Yandex Music from the tray and open it from the taskbar or Start",
        di_ui_yandex_music = "Yandex Music",
        di_ui_removed_from_yandex = "Removed from Yandex Music",
        di_ui_likes_unavailable = "Likes unavailable",
        di_ui_restart_spotify = "Restart Spotify from the taskbar or Start",
        di_rampage_timer = "Rampage timer",
        di_rampage_timer_tip = "After an Ultra Kill, shows how long\nyou have left to get the Rampage",
        di_streak_mega_kill = "Mega Kill!",
        di_streak_unstoppable = "Unstoppable!",
        di_streak_wicked_sick = "Wicked Sick!",
        di_streak_godlike = "Godlike!",
        di_group_live = "Live Activities",
        di_group_alerts_all = "All Alerts",
        di_toast_duration_tip = "Used by every alert that has\nno duration of its own",
        di_alert_duration = "Duration",
        di_alert_duration_tip = "0 uses the shared duration\nfrom the top of the page",
        di_dur_default = "Shared",
        di_reminder_duration = "Reminder Duration",
        di_look_customize = "Customize look",
        di_gear_look = "Island look",
        di_group_island = "Island",
        di_group_look = "Appearance",
        di_group_combat_alerts = "In Combat",
        di_group_map_alerts = "Map & Objectives",
        di_group_media = "Music",
        di_group_haptics = "Feedback",
        di_group_ducking = "Ducking",
        di_gear_more = "More",
        di_gear_position = "Position",
        di_gear_radar = "Radar",
        di_gear_alert = "Options",
        di_gear_media = "Player",
        di_gear_visual = "Visual",
        di_gear_audio = "Sound",
        di_gear_ducking = "Ducking",
        di_alert_priority = "Priority",
        di_alert_priority_tip = "When alerts collide,\nthe higher one shows first",
        di_media_priority_tip = "Alerts at or below this priority\nwon't cover the player",
        di_runes_neutrals = "Neutral Item Tiers",
        di_runes_neutrals_tip = "A new tier of neutral items is open",
        di_tab_focus = "Focus",
        di_tab_focus_group = "Do Not Disturb",
        di_tab_reminders_group = "Reminders",
        di_focus_key = "Toggle key",
        di_focus_key_tip = "Or tap the Do Not Disturb tile\nin the expanded island",
        di_focus_until = "Turn off",
        di_focus_until_tip = "When Do Not Disturb\nturns itself off",
        di_focus_until_off = "When I turn it off",
        di_focus_until_10 = "In 10 minutes",
        di_focus_until_20 = "In 20 minutes",
        di_focus_until_match = "When the match ends",
        di_focus_urgent = "Let urgent alerts through",
        di_focus_urgent_tip = "Alerts with priority 5\nstill show up",
        di_focus_moon_tint = "Moon in artwork color",
        di_focus_moon_tint_tip = "While music plays, the moon\ntakes the color of the cover",
        di_focus_name = "Do Not Disturb",
        di_focus_on = "On",
        di_focus_off = "Off",
        di_focus_summary_tag = "Do Not Disturb",
        di_focus_summary = "Alerts hidden: %d",
        di_focus_summary_sub = "Notifications are back on",
        di_rem_tag = "REMINDER",
        di_rem_default = "Reminder %d",
        di_rem_text_tip = "What the island shows",
        di_rem_every_tip = "Repeat every N minutes,\n0 means once",
        di_priority_reminder = "Custom Reminder",
        di_rem_1 = "Reminder 1",
        di_rem_gear_1 = "Reminder 1",
        di_rem1_text = "Text",
        di_rem1_min = "Minute",
        di_rem1_sec = "Second",
        di_rem1_every = "Repeat every, min",
        di_rem_2 = "Reminder 2",
        di_rem_gear_2 = "Reminder 2",
        di_rem2_text = "Text",
        di_rem2_min = "Minute",
        di_rem2_sec = "Second",
        di_rem2_every = "Repeat every, min",
        di_rem_3 = "Reminder 3",
        di_rem_gear_3 = "Reminder 3",
        di_rem3_text = "Text",
        di_rem3_min = "Minute",
        di_rem3_sec = "Second",
        di_rem3_every = "Repeat every, min",
        di_rem_4 = "Reminder 4",
        di_rem_gear_4 = "Reminder 4",
        di_rem4_text = "Text",
        di_rem4_min = "Minute",
        di_rem4_sec = "Second",
        di_rem4_every = "Repeat every, min",
        di_rune_names_double_damage = "Double Damage",
        di_rune_names_haste = "Haste",
        di_rune_names_illusion = "Illusion",
        di_rune_names_invisibility = "Invisibility",
        di_rune_names_regeneration = "Regeneration",
        di_rune_names_bounty = "Bounty",
        di_rune_names_arcane = "Arcane",
        di_rune_names_water = "Water",
        di_rune_names_wisdom = "Wisdom",
        di_rune_names_shield = "Shield",
        di_rune_names_rune = "Rune",
        di_towers_goodguys_tower1_mid = "Radiant Mid T1",
        di_towers_goodguys_tower2_mid = "Radiant Mid T2",
        di_towers_goodguys_tower3_mid = "Radiant Mid T3",
        di_towers_goodguys_tower1_top = "Radiant Top T1",
        di_towers_goodguys_tower2_top = "Radiant Top T2",
        di_towers_goodguys_tower3_top = "Radiant Top T3",
        di_towers_goodguys_tower1_bot = "Radiant Bot T1",
        di_towers_goodguys_tower2_bot = "Radiant Bot T2",
        di_towers_goodguys_tower3_bot = "Radiant Bot T3",
        di_towers_badguys_tower1_mid = "Dire Mid T1",
        di_towers_badguys_tower2_mid = "Dire Mid T2",
        di_towers_badguys_tower3_mid = "Dire Mid T3",
        di_towers_badguys_tower1_top = "Dire Top T1",
        di_towers_badguys_tower2_top = "Dire Top T2",
        di_towers_badguys_tower3_top = "Dire Top T3",
        di_towers_badguys_tower1_bot = "Dire Bot T1",
        di_towers_badguys_tower2_bot = "Dire Bot T2",
        di_towers_badguys_tower3_bot = "Dire Bot T3",
        di_landmarks_top_roshan_river = "Top Roshan (River)",
        di_landmarks_bot_roshan_river = "Bot Roshan (River)",
        di_landmarks_top_river_rune = "Top River Rune",
        di_landmarks_bot_river_rune = "Bot River Rune",
        di_landmarks_river_center = "River Center",
        di_landmarks_radiant_triangle = "Radiant Triangle",
        di_landmarks_dire_triangle = "Dire Triangle",
        di_landmarks_radiant_jungle = "Radiant Jungle",
        di_landmarks_dire_jungle = "Dire Jungle",
        di_landmarks_radiant_tormentor = "Radiant Tormentor",
        di_landmarks_dire_tormentor = "Dire Tormentor",
        di_landmarks_lotus_pool_top = "Lotus Pool (Top)",
        di_landmarks_lotus_pool_bot = "Lotus Pool (Bot)",
        di_landmarks_wisdom_shrine_radiant = "Wisdom Shrine (Radiant)",
        di_landmarks_wisdom_shrine_dire = "Wisdom Shrine (Dire)",
        di_landmarks_twin_gate_top = "Twin Gate (Top)",
        di_landmarks_twin_gate_bot = "Twin Gate (Bot)",
        di_landmarks_mid_lane = "Mid lane",
        di_landmarks_top_lane = "Top lane",
        di_landmarks_bot_lane = "Bot lane",
        di_landmarks_radiant_base = "Radiant Base",
        di_landmarks_dire_base = "Dire Base",
        di_drawer_bold = "Bold",
        di_drawer_regular = "Regular",
        di_drawer_white = "White",
        di_drawer_dim = "Dim",
        di_drawer_custom = "Custom",
        di_drawer_standard = "Standard",
        di_drawer_minimal = "Minimal",
        di_drawer_detailed = "Detailed",
        di_streak_rampage = "Rampage!",
        di_streak_ultra_kill = "Ultra Kill!",
        di_streak_triple_kill = "Triple Kill!",
        di_streak_double_kill = "Double Kill!",
        di_streak_first_blood = "First Blood!",
        di_streak_beyond_godlike = "Beyond Godlike!",
        di_streak_monster_kill = "Monster Kill!",
        di_streak_dominating = "Dominating!",
        di_streak_killing_spree = "Killing Spree!",
        di_ui_courier_delivering_short = "Delivering",
        di_ui_enemy_hero = "Enemy Hero",
        di_ui_lane = "Lane",
        di_ui_bridge_offline = "MediaBridge isn't running, music and sounds are off",
        di_ui_bridge_stalled = "Umbrella is holding back MediaBridge answers, music will catch up",
        di_ui_media_service_down = "Windows media service isn't responding, restart your PC",
        di_ui_update_available = "Update available: ",
        di_ui_skirmish_concluded = "Skirmish Concluded",
        di_ui_all_combatants_retreated = "All combatants retreated",
        di_ui_fight_won = "Fight Won",
        di_ui_enemies_slain_n_losses_n = "Enemies slain: %d  •  Losses: %d",
        di_ui_fight_lost = "Fight Lost",
        di_ui_team_losses_n_kills_n = "Team losses: %d  •  Kills: %d",
        di_ui_even_trade = "Even Trade",
        di_ui_traded_n_for_n = "Traded %d for %d",
        di_ui_fight_outcome = "Fight Outcome",
        di_ui_level_up = "Level Up",
        di_ui_level_n_reached = "Level %d Reached",
        di_ui_enemy_slain = "Enemy Slain",
        di_ui_enemy = "Enemy",
        di_ui_kill_streak = "Kill Streak",
        di_ui_eliminated = "Eliminated ",
        di_ui_item_alert = "Enemy Item",
        di_ui_purchased_item = " purchased item",
        di_ui_spawned_in_river = "spawned in river",
        di_ui_spawned_at_shrine = "spawned at Shrine",
        di_ui_spawned_top_river = "spawned Top River",
        di_ui_spawned_bottom_river = "spawned Bottom River",
        di_ui_rune_spawned = "Rune",
        di_ui_stack = "Stack",
        di_ui_stack_in_n_s = "Stack in %ds",
        di_ui_pull_the_camp_at_n_53 = "Pull the camp at %d:53",
        di_ui_wisdom_rune = "Wisdom Rune",
        di_ui_wisdom_runes_in_n_s = "Wisdom Runes in %ds",
        di_ui_side_lane_shrines = "Side lane shrines",
        di_ui_water_rune = "Water Rune",
        di_ui_water_runes_in_n_s = "Water Runes in %ds",
        di_ui_river_spawn_points = "River spawn points",
        di_ui_power_rune = "Power Rune",
        di_ui_power_runes_in_n_s = "Power Runes in %ds",
        di_ui_bounty_rune = "Bounty Rune",
        di_ui_bounty_runes_in_n_s = "Bounty Runes in %ds",
        di_ui_bounty_spawn_spots = "Bounty spawn spots",
        di_ui_objective = "Tormentor",
        di_ui_tormentor_soon_s = "Tormentor Soon (%s)",
        di_ui_spawns_at_20_00 = "Spawns at 20:00",
        di_ui_tormentor_in_n_s = "Tormentor in %ds",
        di_ui_spawns_at_20_00_2 = "Spawns at 20:00",
        di_ui_initial_bounty_spawns = "Initial bounty spawns",
        di_ui_neutrals_unlocked = "Neutral Items",
        di_ui_tier_1_neutrals_ready = "Tier 1 Neutrals Ready",
        di_ui_n_7_00_match_time_reached = "7:00 match time reached",
        di_ui_tier_2_neutrals_ready = "Tier 2 Neutrals Ready",
        di_ui_n_17_00_match_time_reached = "17:00 match time reached",
        di_ui_tier_3_neutrals_ready = "Tier 3 Neutrals Ready",
        di_ui_n_27_00_match_time_reached = "27:00 match time reached",
        di_ui_tier_4_neutrals_ready = "Tier 4 Neutrals Ready",
        di_ui_n_37_00_match_time_reached = "37:00 match time reached",
        di_ui_tier_5_neutrals_ready = "Tier 5 Neutrals Ready",
        di_ui_n_60_00_match_time_reached = "60:00 match time reached",
        di_ui_lotus_pool = "Lotus Pool",
        di_ui_lotus_fruit_in_n_s = "Lotus Fruit in %ds",
        di_ui_side_lane_pools = "Side lane pools",
        di_ui_courier_warning = "Courier",
        di_ui_courier_under_attack = "Courier Under Attack",
        di_ui_n_hp_remaining = "%d HP remaining",
        di_ui_tower_defense = "Tower",
        di_ui_ally_tower_attacked = "Ally Tower Attacked",
        di_ui_health_dropped_to_n_pct = "Health dropped to %d%%",
        di_ui_kill_opportunity = "Kill Opportunity",
        di_ui_rune_pickup = "Rune Pickup",
        di_ui_picked_up = "picked up ",
        di_ui_invisibility_alert = "Invisibility",
        di_ui_enemy_entered_stealth = "Enemy entered stealth",
        di_ui_teleport_warning = "Enemy Teleport",
        di_ui_teleporting = " Teleporting",
        di_ui_teleporting_to = "Teleporting to ",
        di_ui_aegis_claimed = "Aegis Claimed",
        di_ui_claimed_aegis = " Claimed Aegis",
        di_ui_enemy_secured_immortal = "Enemy secured immortal",
        di_ui_ally_secured_immortal = "Ally secured immortal",
        di_ui_roshan_pit_alert = "Roshan Pit",
        di_ui_roshan_under_attack = "Roshan Under Attack",
        di_ui_combat_audio_detected_in_pit = "Combat audio detected in pit",
        di_ui_roshan_health = "Health: %d",
        di_ui_player = "Player",
        di_ui_buyback_alert = "Buyback",
        di_ui_bought_back = " Bought Back",
        di_ui_hero_returned_to_match = "Hero returned to match",
        di_ui_roshan_slain = "Roshan",
        di_ui_roshan_killed = "Roshan Killed",
        di_ui_aegis_dropped_in_pit = "Aegis dropped in pit",
        di_ui_tormentor_spawn = "Tormentor",
        di_ui_tormentor_spawned = "Tormentor Spawned",
        di_ui_objective_available = "Objective available",
        di_ui_tormentor_defeated = "Tormentor",
        di_ui_tormentor_defeated_2 = "Tormentor Defeated",
        di_ui_shard_granted_to_team = "Shard granted to team",
        di_ui_hero = "Hero",
        di_ui_main_menu = "Main Menu",
        di_ui_finding_match = "Finding Match",
        di_ui_liked_songs = "Liked Songs",
        di_ui_removed_from_favorites = "Removed from Favorites",
        di_ui_saved_to_library = "Saved to Library",
        di_ui_removed_from_spotify = "Removed from Spotify",
        di_ui_accepted = "Accepted",
        di_ui_match_found = "Match Found",
        di_ui_weight = "Font",
        di_ui_color = "Color",
        di_ui_format = "Style",
        di_ui_icon = "Icon",
        di_ui_color_picker = "Colors",
        di_ui_reset = "Reset",
        di_ui_widgets = "Widgets",
        di_cp_grid = "Grid",
        di_cp_spectrum = "Spectrum",
        di_cp_sliders = "Sliders",
        di_cp_red = "RED",
        di_cp_green = "GREEN",
        di_cp_blue = "BLUE",
        di_cp_hex = "Hex Color",
        di_main_hello = "Hello on Launch",
        di_main_hello_tip = "The iPhone style hello\nwhen Dota starts",
        di_main_setup = "Run Setup Again",
        di_main_setup_tip = "Opens the setup assistant again.\nWorks in the main menu",
        di_hello_swipe = "Swipe up to get started",
        di_su_continue = "Continue",
        di_su_later = "Set Up Later",
        di_su_skip = "Skip",
        di_su_finish = "Get Started",
        di_su_bridge_t = "Media Bridge",
        di_su_bridge_d = "A tiny helper that runs next to Dota. It brings music, one-click updates, fonts and system alerts to the island.",
        di_su_bridge_on = "Bridge is running",
        di_su_bridge_check = "Looking for the bridge…",
        di_su_bridge_off = "Bridge not found",
        di_su_bridge_how = "Download media_bridge.exe from the latest release and add this to Dota launch options in Steam:",
        di_su_bridge_skip = "Continue Without Bridge",
        di_su_fonts_t = "Fonts and Icons",
        di_su_fonts_d = "The island uses Apple's own typeface and symbols. They install for your account only, no admin rights needed.",
        di_su_position_t = "Position and Size",
        di_su_position_d = "Pick where the island lives. Changes show up right away.",
        di_su_pos_top = "Top",
        di_su_pos_left = "Top Left",
        di_su_pos_right = "Top Right",
        di_su_size = "Size",
        di_su_pos_hint = "Later you can drag it anywhere with Ctrl + LMB while the menu is open.",
        di_su_look_t = "Appearance",
        di_su_look_d = "Choose how the island looks. You can change it any time in the menu.",
        di_su_look_dark = "Dark",
        di_su_look_light = "Light",
        di_su_look_glass = "Glass",
        di_su_alerts_t = "Notifications",
        di_su_alerts_d = "How much the island should tell you during a match.",
        di_su_al_min_t = "Minimal",
        di_su_al_min_d = "Kills, runes, lotuses and low HP",
        di_su_al_mid_t = "Balanced",
        di_su_al_mid_d = "Everything except stack timers",
        di_su_al_all_t = "Everything",
        di_su_al_all_d = "Every alert the island has",
        di_su_likes_t = "Spotify Likes",
        di_su_likes_d = "Like tracks right from the island. It needs Spicetify, the guide takes two minutes.",
        di_su_likes_guide = "How to Set Up",
        di_su_focus_t = "Focus",
        di_su_focus_d = "Focus mutes minor alerts so nothing distracts you. Pick a key to toggle it.",
        di_su_focus_key = "Hotkey",
        di_su_focus_press = "Press a key…",
        di_su_focus_none = "Not Set",
        di_su_focus_hint = "Esc cancels, Backspace clears",
        di_su_done_t = "You're All Set",
        di_su_done_d = "The island is ready. Everything here can be changed later in the menu.",
        di_ui_done = "Done",
        di_ui_on_island_hdr = "ON ISLAND",
        di_ui_add_hdr = "ADD WIDGETS",
        di_ui_show_on_island = "Show on Island",
        di_ui_controls_hint = "Ctrl + LMB: move  \u{2022}  RMB: widgets",
        di_ui_music = "Music",
        di_ui_fight = "Fight",
        di_br_title = "MediaBridge isn't running",
        di_br_sub = "No music, sounds or updates without it",
        di_fonts_title = "SF Pro fonts are missing",
        di_fonts_sub = "The island looks off without them",
        di_fonts_install = "Install",
        di_fonts_installing = "Installing fonts…",
        di_fonts_done = "Fonts installed",
        di_fonts_failed = "Couldn't install fonts",
        di_fonts_failed_sub = "Get them from the link in the README",
        di_main_debug = "Debug log",
        di_main_debug_tip = "Writes a detailed log of what the island does.\nTurn it on, repeat the problem, send the file",
        di_main_debug_open = "Show Debug Log",
        di_main_debug_open_tip = "Opens the folder with the log file.\nNeeds MediaBridge",
        di_tab_diag = "Diagnostics",
        di_tab_access = "Accessibility",
        di_group_access = "Accessibility",
        di_access_motion = "Reduce Motion",
        di_access_motion_tip = "No bouncing, bubbles fade in place,\nno squeeze, shake or rolling digits",
        di_access_bold = "Bold Text",
        di_access_bold_tip = "All text on the island\nbecomes one weight heavier",
        di_access_contrast = "Increase Contrast",
        di_access_contrast_tip = "Brighter secondary text, borders and fills,\nhigh contrast system colors",
        di_group_diag = "Diagnostics",
        di_diag_snapshot = "Save Snapshot to Log",
        di_diag_snapshot_tip = "Writes everything the island knows into the log.\nPress it while the problem is on screen",
        di_ui_module_off = "Part of the island turned off after an error. Turn on Debug log and send dynamic_island_debug.log",
        di_main_demo = "Show all screens",
        di_main_demo_tip = "Plays every screen of the island in a row\nto see how it all looks",
        di_upd_available = "Update available",
        di_upd_manual = "Download it from GitHub",
        di_upd_bridge_title = "Update MediaBridge",
        di_upd_bridge_sub = "New features need the new version",
        di_upd_later = "Later",
        di_upd_install = "Update",
        di_upd_ok = "OK",
        di_upd_downloading = "Downloading…",
        di_upd_installing = "Installing…",
        di_upd_ready = "Update installed",
        di_upd_ready_sub = "Restart scripts to finish",
        di_upd_restart = "Restart",
        di_upd_failed = "Couldn't update",
        di_upd_failed_sub = "Check your connection and try again",
        di_upd_retry = "Try Again",
        di_wn_title = "What's New",
        di_wn_continue = "Continue",
        di_wn_1_t = "Activities side by side",
        di_wn_1_d = "Two live activities at once, like on iPhone",
        di_wn_2_t = "Synced lyrics",
        di_wn_2_d = "Line by line, in the player and the small island",
        di_wn_3_t = "Accessibility",
        di_wn_3_d = "Reduce Motion, Bold Text, Increase Contrast",
        di_wn_4_t = "Widgets for scripts",
        di_wn_4_d = "Other scripts add their own chips",
        di_nc_title = "Notifications",
        di_nc_clear = "Clear",
        di_sdk_perm_sub = "Would Like to Send You Notifications",
        di_sdk_allow = "Allow",
        di_sdk_deny = "Don't Allow",
        di_main_sdk_reset = "Reset Script Permissions",
        di_main_sdk_reset_tip = "Forgets which scripts you allowed,\nthey will ask again",
        di_group_sdk = "Scripts",
        di_sdk_none = "No scripts have asked yet",
        di_sdk_focus = "Allow in Focus",
        di_sdk_focus_tip = "Its time-sensitive alerts show\neven in Do Not Disturb",
        di_nc_empty = "No notifications",
        di_nc_now = "now",
        di_nc_min = "%dm",
        di_nc_hour = "%dh",
        di_main_expand = "Expand island",
        di_main_expand_hover = "On hover",
        di_main_expand_hold = "Press and hold",
        di_main_expand_tip = "Hover opens the island under the cursor,\nhold opens it after a long press like on iPhone",
        di_group_system = "System",
        di_sys_output = "Audio output",
        di_sys_output_tip = "Shows the new device when Windows\nswitches sound output. Needs MediaBridge",
        di_sys_mute = "Sound on and off",
        di_sys_mute_tip = "Shows when Windows sound\nis muted or unmuted. Needs MediaBridge",
        di_sys_battery = "Battery",
        di_sys_battery_tip = "Laptops only: charging and low battery.\nNeeds MediaBridge",
        di_sys_headphones = "Headphones",
        di_sys_speakers = "Speakers",
        di_sys_display = "Display",
        di_sys_sound = "Sound",
        di_sys_muted = "Muted",
        di_sys_unmuted = "On",
        di_sys_battery_tag = "Battery",
        di_sys_charging = "Charging, %d%%",
        di_sys_low = "Low Battery, %d%%",
        di_num_sep = ",",
        di_ui_map = "Map",
        di_ui_notification = "Notification",
        di_ui_track = "Track",
        di_ui_match = "Match ",
        di_tab_general = "General",
        di_tab_alerts = "Alerts",
        di_tab_media = "Media",
        di_tab_haptics = "Haptic Engine",
        di_main_enabled = "Enable Island",
        di_main_enabled_tip = "Turns the whole island on or off.\nMore settings are in the gear",
        di_main_only_in_game = "Only In-Game",
        di_main_only_in_game_tip = "Hide the island in the main menu,\nshow it only in a match",
        di_main_preset = "Position Preset",
        di_main_preset_tip = "Where the island sits.\nCtrl and drag moves it anywhere",
        di_main_offset_y = "Vertical Offset (Y)",
        di_main_offset_y_tip = "Distance from the top of the screen",
        di_main_offset_x = "Horizontal Offset (X)",
        di_main_offset_x_tip = "Shift left or right from the preset",
        di_main_scale = "Island Scale",
        di_main_scale_tip = "Size of the island and everything in it",
        di_main_custom_label = "Hero Tag",
        di_main_custom_label_tip = "Shown instead of the hero name\nin the Hero widget",
        di_main_bg_color = "Island Background Color",
        di_main_bg_color_tip = "Island color. On a light color\nthe text turns dark",
        di_main_bg_opacity = "Background Opacity",
        di_main_bg_opacity_tip = "Transparency of the colored island\nwhen glass mode is off",
        di_main_pure_glass = "Glass Mode",
        di_main_pure_glass_tip = "A see-through glass island\ninstead of a solid one",
        di_main_border_thickness = "Border Thickness",
        di_main_border_thickness_tip = "Thin outline around the island,\n0 turns it off",
        di_main_widget_editor = "Widget Editor (RMB)",
        di_main_widget_editor_tip = "Choose and arrange the widgets in the island.\nRight click on the island opens it too",
        di_main_reset_pos = "Reset Position",
        di_main_reset_pos_tip = "Puts the island back\nto the top center",
        di_preset_top_center = "Top Center",
        di_preset_custom = "Custom (Draggable)",
        di_preset_top_left = "Top Left",
        di_preset_top_right = "Top Right",
        di_preset_screen_center = "Screen Center",
        di_preset_bottom_center = "Bottom Center",
        di_combat_fight_hud = "Live Combat Radar",
        di_combat_fight_hud_tip = "A live radar of the fight\nwith the heroes of both teams",
        di_combat_fight_scope = "Fight Scope",
        di_combat_fight_scope_tip = "Only fights around your hero\nor any fight on the map",
        di_combat_scope_local = "Local Hero Only",
        di_combat_scope_any = "Any Fight on Map",
        di_combat_min_heroes = "Min Heroes in Fight",
        di_combat_min_heroes_tip = "How many heroes must fight\nfor the radar to show up",
        di_combat_fight_radius = "Fight Detection Radius",
        di_combat_fight_radius_tip = "How close heroes must be\nto count as one fight",
        di_combat_radar_zoom = "Radar Zoom Range",
        di_combat_radar_zoom_tip = "How much of the map\nthe radar shows",
        di_combat_fight_timeout = "Fight Completion Timeout",
        di_combat_fight_timeout_tip = "How long the radar stays\nafter the fight ends",
        di_combat_fight_large_w = "Fight Card Width",
        di_combat_fight_large_w_tip = "Width of the expanded radar",
        di_combat_fight_large_h = "Fight Card Height",
        di_combat_fight_large_h_tip = "Height of the expanded radar",
        di_combat_kills = "Kill Streaks",
        di_combat_kills_tip = "Your hero's kill streaks:\ndouble, triple, ultra, rampage",
        di_combat_invis = "Enemy Invis & Smoke",
        di_combat_invis_tip = "An enemy went invisible\nor used Smoke",
        di_combat_teleports = "Enemy Teleports",
        di_combat_teleports_tip = "An enemy hero started a teleport",
        di_combat_key_enemy_items = "Key Enemy Items",
        di_combat_key_enemy_items_tip = "An enemy got Blink, BKB, Hex\nor another key item",
        di_combat_couriers = "Courier Under Attack",
        di_combat_couriers_tip = "Your courier is taking damage",
        di_combat_towers = "Tower Under Attack",
        di_combat_towers_tip = "Your tower is taking damage",
        di_combat_buybacks = "Player Buybacks",
        di_combat_buybacks_tip = "A player bought back",
        di_combat_low_hp = "Low HP Kill Opportunities",
        di_combat_low_hp_tip = "An enemy hero has 350 HP or less,\ntime to finish him",
        di_combat_level_up = "Hero Level Up",
        di_combat_level_up_tip = "Your hero got a new level",
        di_combat_courier_delivery = "Courier Delivery Activity",
        di_combat_courier_delivery_tip = "A live activity while the courier\ncarries your items",
        di_combat_pause_alert = "Pause Notification Pill",
        di_combat_pause_alert_tip = "Shows when the game is paused",
        di_match_alert = "Match Found",
        di_match_alert_tip = "Accept countdown in the menu.\nPriority, Focus and sound in the gear",
        di_courier_faceid = "Face ID on Delivery",
        di_courier_faceid_tip = "Face ID animation when the\ncourier brings your items",
        di_courier_sound = "Delivery Sound",
        di_courier_sound_tip = "Sound when the courier brings your items\nor dies on the way",
        di_match_faceid = "Face ID on Accept",
        di_match_faceid_tip = "Face ID animation when\nyou accept a match",
        di_runes_active_runes = "Active Power Runes",
        di_runes_active_runes_tip = "Reminder before power runes spawn",
        di_runes_water_runes = "Water Runes",
        di_runes_water_runes_tip = "Reminder before water runes spawn\nin the first minutes",
        di_runes_bounty_runes = "Bounty Runes",
        di_runes_bounty_runes_tip = "Reminder before bounty runes spawn",
        di_runes_wisdom_runes = "Wisdom Runes",
        di_runes_wisdom_runes_tip = "Reminder before wisdom runes spawn",
        di_runes_rune_pickups = "Rune Pickups",
        di_runes_rune_pickups_tip = "Which hero picked up a rune",
        di_runes_rune_world_spawn = "Rune World Spawns",
        di_runes_rune_world_spawn_tip = "A rune appeared on the map",
        di_runes_lotus = "Lotus Pools",
        di_runes_lotus_tip = "Reminder before lotus pools fill",
        di_runes_tormentor = "Tormentor Objective",
        di_runes_tormentor_tip = "Tormentor spawn and kill",
        di_runes_roshan = "Roshan & Aegis",
        di_runes_roshan_tip = "Roshan kill, Aegis\nand Roshan under attack",
        di_runes_stacks = "Camp Stack Reminder",
        di_runes_stacks_tip = "Reminder to stack camps\nbefore the minute mark",
        di_timings_toast_duration = "Alert Duration",
        di_timings_stack_time = "Stack Reminder Lead (pull at :53)",
        di_timings_stack_until = "Remind Until Minute",
        di_timings_stack_until_tip = "Stack reminders stop after this minute.\nWhole match means no limit",
        di_stack_until_always = "Whole match",
        di_stack_until_min = "%d min",
        di_timings_power_rune_time = "Power Runes Lead Time",
        di_timings_water_rune_time = "Water Runes Lead Time",
        di_timings_bounty_rune_time = "Bounty Runes Lead Time",
        di_timings_wisdom_rune_time = "Wisdom Runes Lead Time",
        di_timings_lotus_time = "Lotus Fruit Lead Time",
        di_timings_tormentor1_time = "Tormentor 1st Warning",
        di_timings_tormentor2_time = "Tormentor 2nd Warning",
        di_media_enabled = "Media Sync",
        di_media_enabled_tip = "The music player in the island.\nNeeds MediaBridge",
        di_media_spotify_like = "Track Like Button",
        di_media_spotify_like_tip = "The heart likes the song in Spotify\nor Yandex Music. Needs MediaBridge",
        di_media_volume_wheel = "Scroll Wheel Volume Control",
        di_media_volume_wheel_tip = "Scroll over the island to change\nthe player's volume",
        di_media_lyrics = "Synced Lyrics",
        di_gear_lyrics = "Lyrics",
        di_media_lyrics_compact = "Lyrics in the Small Island",
        di_media_lyrics_compact_tip = "Shows the line being sung instead of\nthe song name in the small island",
        di_media_lyrics_tip = "Song text in time with the music, from lrclib.net.\nThe quote button opens it, click a line to jump",
        di_media_marquee_speed = "Marquee Speed",
        di_media_marquee_speed_tip = "How fast long titles scroll",
        di_media_compact_title = "Track Title in Compact View",
        di_media_compact_title_tip = "Song name in the small island,\nnot only the cover and the wave",
        di_media_artwork_tint = "Wave Color From Artwork",
        di_media_artwork_tint_tip = "The music wave takes\nthe color of the cover",
        di_media_secondary_bubble = "Satellite Bubble",
        di_media_secondary_bubble_tip = "Minor alerts drop into a side bubble\ninstead of covering the player",
        di_media_in_menu = "Show in Main Menu",
        di_media_in_menu_tip = "Music takes the island in the main menu too.\nMatch search moves to the second bubble",
        di_media_shadow = "Soft Shadows",
        di_media_shadow_tip = "Soft shadow under the island\nand its bubbles",
        di_media_blur = "Backdrop Glass Blur",
        di_media_blur_tip = "Blurs the game behind the island",
        di_media_hints = "Control Hints",
        di_media_hints_tip = "Control hints under the island\nwhile the Umbrella menu is open",
        di_media_accent_color = "Primary Theme Color",
        di_media_accent_color_tip = "Color of the music wave when\nthe cover color is off",
        di_media_export_cfg = "Export All Settings to File",
        di_media_export_cfg_tip = "Saves every setting\nto the island's config file",
        di_media_import_cfg = "Import All Settings from File",
        di_media_import_cfg_tip = "Loads every setting back\nfrom the island's config file",
        di_courier_delivering = "Delivering Items",
        di_courier_delivered = "Delivered",
        di_courier_eta = "ETA",
        di_courier_speed = "Speed",
        di_courier_hp = "HP",
        di_island_clock = "Clock",
        di_island_kda = "KDA",
        di_island_gold = "Gold",
        di_island_networth = "Net Worth",
        di_island_lasthits = "Last Hits",
        di_island_hero = "Hero",
        di_island_fps = "FPS",
        di_island_ping = "Ping",
        di_island_paused = "Paused",
        di_haptics_enabled = "Enable Haptic Engine",
        di_haptics_enabled_tip = "Squish, glow and clicks\nwhen the island reacts",
        di_haptics_visual = "Visual Haptics (Squish & Bounce)",
        di_haptics_visual_tip = "The island squishes and glows\non taps and alerts",
        di_haptics_audio = "Interface Sounds",
        di_haptics_audio_tip = "Soft clicks on taps, scrolling\nand expanding",
        di_haptics_volume = "Interface Volume",
        di_haptics_volume_tip = "Volume of interface clicks",
        di_alert_sounds = "Alert Sounds",
        di_alert_sounds_tip = "Sounds of alerts, courier, pause and match found.\nInterface clicks are in Extra, Haptic Engine",
        di_alert_volume = "Alert Volume",
        di_alert_volume_tip = "Volume of alert sounds",
        di_alert_sound = "Sound",
        di_alert_sound_tip = "Play a sound when\nthis alert shows up",
        di_sdk_slot_tip = "Lets this script show notifications,\nactivities and widgets",
        di_rem_time_tip = "Game time of the reminder",
        di_rem_on_tip = "Your own reminder at a game time.\nText and time are in the gear",
        di_lead_tip = "How many seconds before\nto remind you",
        di_haptics_intensity = "Kinetic Intensity",
        di_haptics_intensity_tip = "How strong the squish is",
        di_haptics_combat_filter = "Combat Anti-Spam Filter",
        di_haptics_combat_filter_tip = "Skips light taps during a fight\nso nothing distracts you",
        di_haptics_audio_ducking = "Audio Auto-Ducking",
        di_haptics_audio_ducking_tip = "Other sounds get quieter while the island\nplays its own. Needs MediaBridge",
        di_haptics_ducking_amount = "Ducking Strength",
        di_haptics_ducking_amount_tip = "How much quieter the rest gets",
        di_haptics_ducking_alerts = "Ducking: Critical Alerts",
        di_haptics_ducking_alerts_tip = "Duck for important alerts",
        di_haptics_ducking_courier = "Ducking: Courier",
        di_haptics_ducking_courier_tip = "Duck when the courier delivers",
        di_haptics_ducking_notifs = "Ducking: Notifications",
        di_haptics_ducking_notifs_tip = "Duck for regular notifications",
        di_haptics_ducking_motion = "Ducking: Island Motion",
        di_haptics_ducking_motion_tip = "Duck for expand and collapse sounds",
        di_haptics_ducking_taptics = "Ducking: Clicks & Taptics",
        di_haptics_ducking_taptics_tip = "Duck for clicks and buttons",
        di_haptics_test_ducking = "Audition Ducking",
        di_haptics_test_ducking_tip = "Plays a sound so you can hear\nhow much the rest ducks",
        di_priority_roshan_kill = "Roshan Killed",
        di_priority_aegis = "Aegis Picked Up",
        di_priority_roshan_attack = "Roshan Under Attack",
        di_priority_fight_summary = "Fight Summary",
        di_priority_power_rune_cycle = "Priority"
    },
    ru = {
        di_ui_spotify_no_port = "Спотифай запущен без порта, лайки не работают. Перезапусти его",
        di_ui_yandex_no_port = "Яндекс Музыка запущена без порта, лайки не работают. Перезапусти её",
        di_ui_like_failed = "Не удалось изменить лайк. Проверь MediaBridge и перезапусти Яндекс Музыку",
        di_playlist_title = "Добавить в плейлист",
        di_playlist_loading = "Загружаю плейлисты...",
        di_playlist_empty = "Плейлисты не найдены",
        di_playlist_failed = "Не удалось открыть плейлисты Яндекс Музыки",
        di_playlist_add_failed = "Не удалось добавить трек",
        di_playlist_tip = "Добавить текущий трек Яндекс Музыки\nв один из плейлистов",
        di_media_center_short_title = "Короткий трек по центру",
        di_media_center_short_title_tip = "Выравнивать короткое название трека\nпо центру маленького островка",
        di_media_show_artist = "Показывать исполнителя",
        di_media_show_artist_tip = "Показывает исполнителя с названием трека\nв маленьком островке",
        di_ui_restart_yandex = "Закрой Яндекс Музыку через трей и открой с панели задач или из Пуска",
        di_ui_yandex_music = "Яндекс Музыка",
        di_ui_removed_from_yandex = "Удалено из Яндекс Музыки",
        di_ui_likes_unavailable = "Лайки недоступны",
        di_ui_restart_spotify = "Перезапусти Спотифай с панели задач или из Пуска",
        di_rampage_timer = "Таймер рампаги",
        di_rampage_timer_tip = "После Ультра-убийства показывает,\nсколько осталось до Рампаги",
        di_streak_mega_kill = "Мега-убийство!",
        di_streak_unstoppable = "Неудержимый!",
        di_streak_wicked_sick = "Нечто!",
        di_streak_godlike = "Божественно!",
        di_group_live = "Живые активности",
        di_group_alerts_all = "Все оповещения",
        di_toast_duration_tip = "Для всех оповещений, у которых\nне задана своя длительность",
        di_alert_duration = "Длительность",
        di_alert_duration_tip = "0 значит общая длительность\nсверху страницы",
        di_dur_default = "Общая",
        di_reminder_duration = "Длительность напоминаний",
        di_look_customize = "Настроить внешний вид",
        di_gear_look = "Вид островка",
        di_group_island = "Остров",
        di_group_look = "Внешний вид",
        di_group_combat_alerts = "В бою",
        di_group_map_alerts = "Карта и объекты",
        di_group_media = "Музыка",
        di_group_haptics = "Отклик",
        di_group_ducking = "Приглушение",
        di_gear_more = "Ещё",
        di_gear_position = "Позиция",
        di_gear_radar = "Радар",
        di_gear_alert = "Параметры",
        di_gear_media = "Плеер",
        di_gear_visual = "Визуал",
        di_gear_audio = "Звук",
        di_gear_ducking = "Приглушение",
        di_alert_priority = "Приоритет",
        di_alert_priority_tip = "Если оповещения совпали,\nпервым покажется более важное",
        di_media_priority_tip = "Оповещения с таким приоритетом\nили ниже не перекрывают плеер",
        di_runes_neutrals = "Тиры нейтральных предметов",
        di_runes_neutrals_tip = "Открылся новый тир нейтральных предметов",
        di_tab_focus = "Фокус",
        di_tab_focus_group = "Не беспокоить",
        di_tab_reminders_group = "Напоминания",
        di_focus_key = "Клавиша",
        di_focus_key_tip = "Или плитка Не беспокоить\nв раскрытом островке",
        di_focus_until = "Выключить",
        di_focus_until_tip = "Когда Не беспокоить\nвыключится само",
        di_focus_until_off = "Когда выключу сам",
        di_focus_until_10 = "Через 10 минут",
        di_focus_until_20 = "Через 20 минут",
        di_focus_until_match = "После матча",
        di_focus_urgent = "Пропускать срочные",
        di_focus_urgent_tip = "Оповещения с приоритетом 5\nвсе равно покажутся",
        di_focus_moon_tint = "Луна в цвет обложки",
        di_focus_moon_tint_tip = "Пока играет музыка, луна\nкрасится в цвет обложки",
        di_focus_name = "Не беспокоить",
        di_focus_on = "Вкл",
        di_focus_off = "Выкл",
        di_focus_summary_tag = "Не беспокоить",
        di_focus_summary = "Скрыто уведомлений: %d",
        di_focus_summary_sub = "Уведомления снова включены",
        di_rem_tag = "НАПОМИНАНИЕ",
        di_rem_default = "Напоминание %d",
        di_rem_text_tip = "Что покажет островок",
        di_rem_every_tip = "Повторять каждые N минут,\n0 значит один раз",
        di_priority_reminder = "Своё напоминание",
        di_rem_1 = "Напоминание 1",
        di_rem_gear_1 = "Напоминание 1",
        di_rem1_text = "Текст",
        di_rem1_min = "Минута",
        di_rem1_sec = "Секунда",
        di_rem1_every = "Повтор каждые, мин",
        di_rem_2 = "Напоминание 2",
        di_rem_gear_2 = "Напоминание 2",
        di_rem2_text = "Текст",
        di_rem2_min = "Минута",
        di_rem2_sec = "Секунда",
        di_rem2_every = "Повтор каждые, мин",
        di_rem_3 = "Напоминание 3",
        di_rem_gear_3 = "Напоминание 3",
        di_rem3_text = "Текст",
        di_rem3_min = "Минута",
        di_rem3_sec = "Секунда",
        di_rem3_every = "Повтор каждые, мин",
        di_rem_4 = "Напоминание 4",
        di_rem_gear_4 = "Напоминание 4",
        di_rem4_text = "Текст",
        di_rem4_min = "Минута",
        di_rem4_sec = "Секунда",
        di_rem4_every = "Повтор каждые, мин",
        di_rune_names_double_damage = "Двойной урон",
        di_rune_names_haste = "Ускорение",
        di_rune_names_illusion = "Иллюзии",
        di_rune_names_invisibility = "Невидимость",
        di_rune_names_regeneration = "Регенерация",
        di_rune_names_bounty = "Богатство",
        di_rune_names_arcane = "Волшебство",
        di_rune_names_water = "Вода",
        di_rune_names_wisdom = "Мудрость",
        di_rune_names_shield = "Щит",
        di_rune_names_rune = "Руна",
        di_towers_goodguys_tower1_mid = "Мид Т1 Света",
        di_towers_goodguys_tower2_mid = "Мид Т2 Света",
        di_towers_goodguys_tower3_mid = "Мид Т3 Света",
        di_towers_goodguys_tower1_top = "Топ Т1 Света",
        di_towers_goodguys_tower2_top = "Топ Т2 Света",
        di_towers_goodguys_tower3_top = "Топ Т3 Света",
        di_towers_goodguys_tower1_bot = "Бот Т1 Света",
        di_towers_goodguys_tower2_bot = "Бот Т2 Света",
        di_towers_goodguys_tower3_bot = "Бот Т3 Света",
        di_towers_badguys_tower1_mid = "Мид Т1 Тьмы",
        di_towers_badguys_tower2_mid = "Мид Т2 Тьмы",
        di_towers_badguys_tower3_mid = "Мид Т3 Тьмы",
        di_towers_badguys_tower1_top = "Топ Т1 Тьмы",
        di_towers_badguys_tower2_top = "Топ Т2 Тьмы",
        di_towers_badguys_tower3_top = "Топ Т3 Тьмы",
        di_towers_badguys_tower1_bot = "Бот Т1 Тьмы",
        di_towers_badguys_tower2_bot = "Бот Т2 Тьмы",
        di_towers_badguys_tower3_bot = "Бот Т3 Тьмы",
        di_landmarks_top_roshan_river = "Верхний Рошан (Река)",
        di_landmarks_bot_roshan_river = "Нижний Рошан (Река)",
        di_landmarks_top_river_rune = "Верхняя руна реки",
        di_landmarks_bot_river_rune = "Нижняя руна реки",
        di_landmarks_river_center = "Центр реки",
        di_landmarks_radiant_triangle = "Тройка Света",
        di_landmarks_dire_triangle = "Тройка Тьмы",
        di_landmarks_radiant_jungle = "Лес Света",
        di_landmarks_dire_jungle = "Лес Тьмы",
        di_landmarks_radiant_tormentor = "Терзатель Света",
        di_landmarks_dire_tormentor = "Терзатель Тьмы",
        di_landmarks_lotus_pool_top = "Пруд Лотосов (Топ)",
        di_landmarks_lotus_pool_bot = "Пруд Лотосов (Бот)",
        di_landmarks_wisdom_shrine_radiant = "Святилище Мудрости (Свет)",
        di_landmarks_wisdom_shrine_dire = "Святилище Мудрости (Тьма)",
        di_landmarks_twin_gate_top = "Парный Портал (Топ)",
        di_landmarks_twin_gate_bot = "Парный Портал (Бот)",
        di_landmarks_mid_lane = "Мид линия",
        di_landmarks_top_lane = "Топ линия",
        di_landmarks_bot_lane = "Бот линия",
        di_landmarks_radiant_base = "База Сил Света",
        di_landmarks_dire_base = "База Сил Тьмы",
        di_drawer_bold = "Жирный",
        di_drawer_regular = "Обычный",
        di_drawer_white = "Белый",
        di_drawer_dim = "Серый",
        di_drawer_custom = "Свой",
        di_drawer_standard = "Стандарт",
        di_drawer_minimal = "Кратко",
        di_drawer_detailed = "Детали",
        di_streak_rampage = "Бесчинство!",
        di_streak_ultra_kill = "Ультра-убийство!",
        di_streak_triple_kill = "Тройное убийство!",
        di_streak_double_kill = "Двойное убийство!",
        di_streak_first_blood = "Первая кровь!",
        di_streak_beyond_godlike = "За гранью божественного!",
        di_streak_monster_kill = "Чудовищное убийство!",
        di_streak_dominating = "Доминирование!",
        di_streak_killing_spree = "Серия убийств!",
        di_ui_courier_delivering_short = "Доставка",
        di_ui_enemy_hero = "Вражеский герой",
        di_ui_lane = "Линия",
        di_ui_bridge_offline = "MediaBridge не запущен, музыка и звуки выключены",
        di_ui_bridge_stalled = "Umbrella задерживает ответы MediaBridge, музыка обновится позже",
        di_ui_media_service_down = "Служба медиа Windows не отвечает, перезагрузи ПК",
        di_ui_update_available = "Доступно обновление: ",
        di_ui_skirmish_concluded = "Стычка окончена",
        di_ui_all_combatants_retreated = "Все участники разошлись",
        di_ui_fight_won = "Победа в файте",
        di_ui_enemies_slain_n_losses_n = "Врагов убито: %d  •  Потерь: %d",
        di_ui_fight_lost = "Файт проигран",
        di_ui_team_losses_n_kills_n = "Потери команды: %d  •  Убито: %d",
        di_ui_even_trade = "Размен в файте",
        di_ui_traded_n_for_n = "Размен %d в %d",
        di_ui_fight_outcome = "Итоги боя",
        di_ui_level_up = "Новый уровень",
        di_ui_level_n_reached = "Уровень %d получен",
        di_ui_enemy_slain = "Враг повержен",
        di_ui_enemy = "Враг",
        di_ui_kill_streak = "Серия убийств",
        di_ui_eliminated = "Уничтожен ",
        di_ui_item_alert = "Предмет врага",
        di_ui_purchased_item = " купил предмет",
        di_ui_spawned_in_river = "появилась на реке",
        di_ui_spawned_at_shrine = "появилась у Алтаря",
        di_ui_spawned_top_river = "появилась Сверху (Топ)",
        di_ui_spawned_bottom_river = "появилась Снизу (Бот)",
        di_ui_rune_spawned = "Руна",
        di_ui_stack = "Стак",
        di_ui_stack_in_n_s = "Стак через %dс",
        di_ui_pull_the_camp_at_n_53 = "Агрить кемп на %d:53",
        di_ui_wisdom_rune = "Руна мудрости",
        di_ui_wisdom_runes_in_n_s = "Руны мудрости через %dс",
        di_ui_side_lane_shrines = "Боковые алтари мудрости",
        di_ui_water_rune = "Руна воды",
        di_ui_water_runes_in_n_s = "Руны воды через %dс",
        di_ui_river_spawn_points = "Точки спавна на реке",
        di_ui_power_rune = "Руна усиления",
        di_ui_power_runes_in_n_s = "Руны усиления через %dс",
        di_ui_bounty_rune = "Руна богатства",
        di_ui_bounty_runes_in_n_s = "Руны богатства через %dс",
        di_ui_bounty_spawn_spots = "Точки спавна богатства",
        di_ui_objective = "Терзатель",
        di_ui_tormentor_soon_s = "Терзатель скоро (%s)",
        di_ui_spawns_at_20_00 = "Появится в 20:00",
        di_ui_tormentor_in_n_s = "Терзатель через %dс",
        di_ui_spawns_at_20_00_2 = "Появится в 20:00",
        di_ui_initial_bounty_spawns = "Стартовые руны",
        di_ui_neutrals_unlocked = "Нейтралки",
        di_ui_tier_1_neutrals_ready = "Нейтралки 1 тира доступны",
        di_ui_n_7_00_match_time_reached = "Время матча 7:00",
        di_ui_tier_2_neutrals_ready = "Нейтралки 2 тира доступны",
        di_ui_n_17_00_match_time_reached = "Время матча 17:00",
        di_ui_tier_3_neutrals_ready = "Нейтралки 3 тира доступны",
        di_ui_n_27_00_match_time_reached = "Время матча 27:00",
        di_ui_tier_4_neutrals_ready = "Нейтралки 4 тира доступны",
        di_ui_n_37_00_match_time_reached = "Время матча 37:00",
        di_ui_tier_5_neutrals_ready = "Нейтралки 5 тира доступны",
        di_ui_n_60_00_match_time_reached = "Время матча 60:00",
        di_ui_lotus_pool = "Лотосы",
        di_ui_lotus_fruit_in_n_s = "Лотосы через %dс",
        di_ui_side_lane_pools = "Боковые пруды лотосов",
        di_ui_courier_warning = "Курьер",
        di_ui_courier_under_attack = "Курьер атакован",
        di_ui_n_hp_remaining = "Осталось %d HP",
        di_ui_tower_defense = "Вышка",
        di_ui_ally_tower_attacked = "Вышка атакована",
        di_ui_health_dropped_to_n_pct = "Здоровье упало до %d%%",
        di_ui_kill_opportunity = "Можно добить",
        di_ui_rune_pickup = "Подбор руны",
        di_ui_picked_up = "подобрал ",
        di_ui_invisibility_alert = "Инвиз врага",
        di_ui_enemy_entered_stealth = "Враг ушел в невидимость",
        di_ui_teleport_warning = "Телепорт врага",
        di_ui_teleporting = " телепортируется",
        di_ui_teleporting_to = "Телепорт к ",
        di_ui_aegis_claimed = "Аегис подобран",
        di_ui_claimed_aegis = " поднял Аегис",
        di_ui_enemy_secured_immortal = "Враг получил бессмертие",
        di_ui_ally_secured_immortal = "Союзник получил бессмертие",
        di_ui_roshan_pit_alert = "Логово Рошана",
        di_ui_roshan_under_attack = "Рошан атакован",
        di_ui_combat_audio_detected_in_pit = "Звуки битвы в логове",
        di_ui_roshan_health = "Здоровье: %d",
        di_ui_player = "Игрок",
        di_ui_buyback_alert = "Выкуп",
        di_ui_bought_back = " выкупился",
        di_ui_hero_returned_to_match = "Герой вернулся в игру",
        di_ui_roshan_slain = "Рошан",
        di_ui_roshan_killed = "Рошан убит",
        di_ui_aegis_dropped_in_pit = "Аегис выпал в логове",
        di_ui_tormentor_spawn = "Терзатель",
        di_ui_tormentor_spawned = "Терзатель появился",
        di_ui_objective_available = "Объект доступен на карте",
        di_ui_tormentor_defeated = "Терзатель",
        di_ui_tormentor_defeated_2 = "Терзатель повержен",
        di_ui_shard_granted_to_team = "Осколок выдан команде",
        di_ui_hero = "Герой",
        di_ui_main_menu = "Главное меню",
        di_ui_finding_match = "Поиск матча",
        di_ui_liked_songs = "Любимые треки",
        di_ui_removed_from_favorites = "Удалено из избранного",
        di_ui_saved_to_library = "Сохранено в библиотеку",
        di_ui_removed_from_spotify = "Удалено из Spotify",
        di_ui_accepted = "Принято",
        di_ui_match_found = "Матч найден",
        di_ui_weight = "Шрифт",
        di_ui_color = "Цвет",
        di_ui_format = "Вид",
        di_ui_icon = "Иконка",
        di_ui_color_picker = "Цвета",
        di_ui_reset = "Сброс",
        di_ui_widgets = "Виджеты",
        di_cp_grid = "Сетка",
        di_cp_spectrum = "Спектр",
        di_cp_sliders = "Ползунки",
        di_cp_red = "КРАСНЫЙ",
        di_cp_green = "ЗЕЛЁНЫЙ",
        di_cp_blue = "СИНИЙ",
        di_cp_hex = "Hex-цвет",
        di_main_hello = "Приветствие при запуске",
        di_main_hello_tip = "Приветствие как на айфоне\nпри запуске доты",
        di_main_setup = "Пройти настройку заново",
        di_main_setup_tip = "Заново открывает помощник настройки.\nРаботает в главном меню",
        di_hello_swipe = "Смахни вверх, чтобы начать",
        di_su_continue = "Продолжить",
        di_su_later = "Настроить позже",
        di_su_skip = "Пропустить",
        di_su_finish = "Начать",
        di_su_bridge_t = "Бридж",
        di_su_bridge_d = "Маленькая программа рядом с дотой. Даёт островку музыку, обновления в один клик, шрифты и системные уведомления.",
        di_su_bridge_on = "Бридж запущен",
        di_su_bridge_check = "Ищу бридж…",
        di_su_bridge_off = "Бридж не найден",
        di_su_bridge_how = "Скачай media_bridge.exe из последнего релиза и добавь в параметры запуска доты в Steam:",
        di_su_bridge_skip = "Продолжить без бриджа",
        di_su_fonts_t = "Шрифты и иконки",
        di_su_fonts_d = "Островок рисуется фирменным шрифтом и значками Apple. Ставятся только для твоей учётки, без прав админа.",
        di_su_position_t = "Позиция и размер",
        di_su_position_d = "Выбери, где будет островок. Изменения видно сразу.",
        di_su_pos_top = "Сверху",
        di_su_pos_left = "Слева",
        di_su_pos_right = "Справа",
        di_su_size = "Размер",
        di_su_pos_hint = "Потом его можно перетащить куда угодно: Ctrl + ЛКМ при открытом меню.",
        di_su_look_t = "Оформление",
        di_su_look_d = "Выбери, как выглядит островок. Поменять можно в любой момент в меню.",
        di_su_look_dark = "Тёмное",
        di_su_look_light = "Светлое",
        di_su_look_glass = "Стекло",
        di_su_alerts_t = "Уведомления",
        di_su_alerts_d = "Сколько островок будет подсказывать в катке.",
        di_su_al_min_t = "Минимум",
        di_su_al_min_d = "Убийства, руны, лотосы и мало HP",
        di_su_al_mid_t = "Сбалансированно",
        di_su_al_mid_d = "Всё, кроме таймера стаков",
        di_su_al_all_t = "Всё",
        di_su_al_all_d = "Все уведомления островка",
        di_su_likes_t = "Лайки Spotify",
        di_su_likes_d = "Лайкай треки прямо с островка. Нужен Spicetify, по гайду это пара минут.",
        di_su_likes_guide = "Как настроить",
        di_su_focus_t = "Фокус",
        di_su_focus_d = "Фокус глушит мелкие уведомления, чтобы ничего не отвлекало. Выбери клавишу для него.",
        di_su_focus_key = "Хоткей",
        di_su_focus_press = "Нажми клавишу…",
        di_su_focus_none = "Не назначен",
        di_su_focus_hint = "Esc отмена, Backspace сброс",
        di_su_done_t = "Всё готово",
        di_su_done_d = "Островок готов. Всё можно поменять потом в меню.",
        di_ui_done = "Готово",
        di_ui_on_island_hdr = "НА ОСТРОВКЕ",
        di_ui_add_hdr = "ДОБАВИТЬ",
        di_ui_show_on_island = "На островке",
        di_ui_controls_hint = "Ctrl + ЛКМ: двигать  \u{2022}  ПКМ: виджеты",
        di_ui_music = "Музыка",
        di_ui_fight = "Бой",
        di_br_title = "MediaBridge не запущен",
        di_br_sub = "Без него нет музыки, звуков и обнов",
        di_fonts_title = "Нет шрифтов SF Pro",
        di_fonts_sub = "Без них островок выглядит криво",
        di_fonts_install = "Установить",
        di_fonts_installing = "Установка шрифтов…",
        di_fonts_done = "Шрифты установлены",
        di_fonts_failed = "Не удалось поставить шрифты",
        di_fonts_failed_sub = "Скачай их по ссылке в README",
        di_main_debug = "Лог отладки",
        di_main_debug_tip = "Пишет подробный лог того, что делает островок.\nВключи, повтори проблему и скинь файл",
        di_main_debug_open = "Показать лог",
        di_main_debug_open_tip = "Открывает папку с файлом лога.\nНужен MediaBridge",
        di_tab_diag = "Диагностика",
        di_tab_access = "Универсальный доступ",
        di_group_access = "Универсальный доступ",
        di_access_motion = "Уменьшение движения",
        di_access_motion_tip = "Без пружинок, кружки проявляются на месте,\nбез сжатия, тряски и прокрутки цифр",
        di_access_bold = "Жирный шрифт",
        di_access_bold_tip = "Весь текст на островке\nстановится на ступень жирнее",
        di_access_contrast = "Увеличение контраста",
        di_access_contrast_tip = "Ярче второстепенный текст, обводка и заливки,\nконтрастные системные цвета",
        di_group_diag = "Диагностика",
        di_diag_snapshot = "Сохранить снимок в лог",
        di_diag_snapshot_tip = "Записывает в лог все, что знает островок.\nЖми, пока проблема на экране",
        di_ui_module_off = "Часть островка отключилась из-за ошибки. Включи лог отладки и скинь dynamic_island_debug.log",
        di_main_demo = "Показать все экраны",
        di_main_demo_tip = "Показывает все экраны островка по очереди,\nчтобы посмотреть, как все выглядит",
        di_upd_available = "Доступно обновление",
        di_upd_manual = "Скачай новую версию на GitHub",
        di_upd_bridge_title = "Обнови MediaBridge",
        di_upd_bridge_sub = "Новым функциям нужна новая версия",
        di_upd_later = "Позже",
        di_upd_install = "Обновить",
        di_upd_ok = "Понятно",
        di_upd_downloading = "Загрузка…",
        di_upd_installing = "Установка…",
        di_upd_ready = "Обновление установлено",
        di_upd_ready_sub = "Осталось перезапустить скрипты",
        di_upd_restart = "Перезапустить",
        di_upd_failed = "Не удалось обновить",
        di_upd_failed_sub = "Проверь интернет и попробуй снова",
        di_upd_retry = "Повторить",
        di_wn_title = "Что нового",
        di_wn_continue = "Продолжить",
        di_wn_1_t = "Активности рядом",
        di_wn_1_d = "Две активности сразу, как на iPhone",
        di_wn_2_t = "Текст песен",
        di_wn_2_d = "По строкам, в плеере и в маленьком островке",
        di_wn_3_t = "Универсальный доступ",
        di_wn_3_d = "Уменьшение движения, жирный шрифт, контраст",
        di_wn_4_t = "Виджеты для скриптов",
        di_wn_4_d = "Другие скрипты добавляют свои чипы",
        di_nc_title = "Уведомления",
        di_nc_clear = "Очистить",
        di_sdk_perm_sub = "Хочет отправлять вам уведомления",
        di_sdk_allow = "Разрешить",
        di_sdk_deny = "Запретить",
        di_main_sdk_reset = "Сбросить разрешения скриптов",
        di_main_sdk_reset_tip = "Забывает, каким скриптам ты разрешил,\nони спросят заново",
        di_group_sdk = "Скрипты",
        di_sdk_none = "Скрипты ещё не просили доступ",
        di_sdk_focus = "Разрешить в фокусе",
        di_sdk_focus_tip = "Его срочные оповещения видны\nдаже в Не беспокоить",
        di_nc_empty = "Нет уведомлений",
        di_nc_now = "сейчас",
        di_nc_min = "%d мин",
        di_nc_hour = "%d ч",
        di_main_expand = "Раскрытие",
        di_main_expand_hover = "При наведении",
        di_main_expand_hold = "Удержанием",
        di_main_expand_tip = "Наведение раскрывает островок под курсором,\nудержание после долгого нажатия, как на айфоне",
        di_group_system = "Система",
        di_sys_output = "Вывод звука",
        di_sys_output_tip = "Показывает устройство, когда Windows\nпереключает звук. Нужен MediaBridge",
        di_sys_mute = "Звук вкл/выкл",
        di_sys_mute_tip = "Показывает, когда звук Windows\nвыключают или включают. Нужен MediaBridge",
        di_sys_battery = "Батарея",
        di_sys_battery_tip = "Только для ноутбуков: зарядка\nи низкий заряд. Нужен MediaBridge",
        di_sys_headphones = "Наушники",
        di_sys_speakers = "Динамики",
        di_sys_display = "Монитор",
        di_sys_sound = "Звук",
        di_sys_muted = "Выключен",
        di_sys_unmuted = "Включён",
        di_sys_battery_tag = "Батарея",
        di_sys_charging = "Заряжается, %d%%",
        di_sys_low = "Низкий заряд, %d%%",
        di_num_sep = "\u{00A0}",
        di_ui_map = "Карта",
        di_ui_notification = "Уведомление",
        di_ui_track = "Трек",
        di_ui_match = "Матч ",
        di_tab_general = "Главная",
        di_tab_alerts = "Оповещения",
        di_tab_media = "Медиа",
        di_tab_haptics = "Тактильный отклик",
        di_main_enabled = "Включить Island",
        di_main_enabled_tip = "Включает и выключает весь островок.\nОстальное в шестеренке",
        di_main_only_in_game = "Только в игре",
        di_main_only_in_game_tip = "Прятать островок в главном меню,\nпоказывать только в матче",
        di_main_preset = "Пресет позиции",
        di_main_preset_tip = "Где стоит островок.\nCtrl и перетаскивание ставят его куда угодно",
        di_main_offset_y = "Смещение (Y)",
        di_main_offset_y_tip = "Отступ от верха экрана",
        di_main_offset_x = "Смещение (X)",
        di_main_offset_x_tip = "Сдвиг влево или вправо от пресета",
        di_main_scale = "Масштаб",
        di_main_scale_tip = "Размер островка и всего внутри",
        di_main_custom_label = "Тег героя",
        di_main_custom_label_tip = "Показывается вместо имени героя\nв виджете Герой",
        di_main_bg_color = "Цвет фона островка",
        di_main_bg_color_tip = "Цвет островка. На светлом\nтекст становится темным",
        di_main_bg_opacity = "Прозрачность фона",
        di_main_bg_opacity_tip = "Прозрачность цветного островка,\nкогда режим стекла выключен",
        di_main_pure_glass = "Режим стекла",
        di_main_pure_glass_tip = "Прозрачный стеклянный островок\nвместо сплошного",
        di_main_border_thickness = "Толщина обводки",
        di_main_border_thickness_tip = "Тонкая обводка вокруг островка,\n0 выключает ее",
        di_main_widget_editor = "Редактор виджетов (ПКМ)",
        di_main_widget_editor_tip = "Выбор и порядок виджетов в островке.\nПКМ по островку тоже открывает",
        di_main_reset_pos = "Сбросить позицию",
        di_main_reset_pos_tip = "Возвращает островок\nнаверх по центру",
        di_preset_top_center = "Сверху по центру",
        di_preset_custom = "Своя (Ctrl + ЛКМ)",
        di_preset_top_left = "Сверху слева",
        di_preset_top_right = "Сверху справа",
        di_preset_screen_center = "По центру экрана",
        di_preset_bottom_center = "Снизу по центру",
        di_combat_fight_hud = "Радар боя (Fight HUD)",
        di_combat_fight_hud_tip = "Живой радар драки\nс героями обеих команд",
        di_combat_fight_scope = "Область боя",
        di_combat_fight_scope_tip = "Только драки рядом с твоим героем\nили любые на карте",
        di_combat_scope_local = "Только вокруг своего героя",
        di_combat_scope_any = "Любой бой на карте",
        di_combat_min_heroes = "Мин. героев для драки",
        di_combat_min_heroes_tip = "Сколько героев должно драться,\nчтобы появился радар",
        di_combat_fight_radius = "Радиус захвата драки",
        di_combat_fight_radius_tip = "Насколько близко должны быть герои,\nчтобы считаться одной дракой",
        di_combat_radar_zoom = "Масштаб радара",
        di_combat_radar_zoom_tip = "Какую часть карты\nпоказывает радар",
        di_combat_fight_timeout = "Задержка закрытия после драки",
        di_combat_fight_timeout_tip = "Сколько радар висит\nпосле конца драки",
        di_combat_fight_large_w = "Ширина карточки боя",
        di_combat_fight_large_w_tip = "Ширина раскрытого радара",
        di_combat_fight_large_h = "Высота карточки боя",
        di_combat_fight_large_h_tip = "Высота раскрытого радара",
        di_combat_kills = "Серии убийств",
        di_combat_kills_tip = "Серии убийств твоего героя:\nдабл, трипл, ультра, рампага",
        di_combat_invis = "Невидимость и Smoke врага",
        di_combat_invis_tip = "Враг ушел в невидимость\nили под Smoke",
        di_combat_teleports = "Телепорты врагов",
        di_combat_teleports_tip = "Вражеский герой начал телепорт",
        di_combat_key_enemy_items = "Важные предметы врага",
        di_combat_key_enemy_items_tip = "У врага появился Blink, BKB, Hex\nили другой важный предмет",
        di_combat_couriers = "Атака курьера",
        di_combat_couriers_tip = "Твоего курьера бьют",
        di_combat_towers = "Атака вышек",
        di_combat_towers_tip = "Твою вышку бьют",
        di_combat_buybacks = "Выкупы игроков",
        di_combat_buybacks_tip = "Игрок выкупился",
        di_combat_low_hp = "Добивание Low HP",
        di_combat_low_hp_tip = "У вражеского героя 350 HP или меньше,\nпора добивать",
        di_combat_level_up = "Повышение уровня",
        di_combat_level_up_tip = "Твой герой получил уровень",
        di_combat_courier_delivery = "Активность доставки курьера",
        di_combat_courier_delivery_tip = "Живая активность, пока курьер\nнесет твои предметы",
        di_combat_pause_alert = "Оповещение паузы игры",
        di_combat_pause_alert_tip = "Показывает, когда игра на паузе",
        di_match_alert = "Матч найден",
        di_match_alert_tip = "Отсчёт принятия матча в меню.\nПриоритет, фокус и звук в шестерёнке",
        di_courier_faceid = "Face ID при доставке",
        di_courier_faceid_tip = "Анимация Face ID, когда курьер\nдоставил твои предметы",
        di_courier_sound = "Звук доставки",
        di_courier_sound_tip = "Звук, когда курьер доставил предметы\nили погиб по пути",
        di_match_faceid = "Face ID при принятии",
        di_match_faceid_tip = "Анимация Face ID, когда\nты принимаешь матч",
        di_runes_active_runes = "Активные руны (Power)",
        di_runes_active_runes_tip = "Напоминание перед появлением силовых рун",
        di_runes_water_runes = "Водные руны",
        di_runes_water_runes_tip = "Напоминание перед водными рунами\nв первые минуты",
        di_runes_bounty_runes = "Руны богатства (Bounty)",
        di_runes_bounty_runes_tip = "Напоминание перед рунами богатства",
        di_runes_wisdom_runes = "Руны мудрости (Wisdom)",
        di_runes_wisdom_runes_tip = "Напоминание перед рунами мудрости",
        di_runes_rune_pickups = "Подбор рун союзником",
        di_runes_rune_pickups_tip = "Какой герой подобрал руну",
        di_runes_rune_world_spawn = "Появление рун на карте",
        di_runes_rune_world_spawn_tip = "На карте появилась руна",
        di_runes_lotus = "Пруды лотосов",
        di_runes_lotus_tip = "Напоминание о прудах лотосов",
        di_runes_tormentor = "Терзатель",
        di_runes_tormentor_tip = "Появление и убийство Терзателя",
        di_runes_roshan = "Рошан и Эгида",
        di_runes_roshan_tip = "Убийство Рошана, Эгида\nи атака на Рошана",
        di_runes_stacks = "Напоминание о стаке кемпов",
        di_runes_stacks_tip = "Напоминание застакать кемпы\nперед началом минуты",
        di_timings_toast_duration = "Длительность уведомлений",
        di_timings_stack_time = "Пре-таймер стака (агр на :53)",
        di_timings_stack_until = "Напоминать до минуты",
        di_timings_stack_until_tip = "После этой минуты напоминания о стаках\nпрекращаются. Весь матч значит без ограничения",
        di_stack_until_always = "Весь матч",
        di_stack_until_min = "%d мин",
        di_timings_power_rune_time = "Пре-таймер: Power руны",
        di_timings_water_rune_time = "Пре-таймер: Водные руны",
        di_timings_bounty_rune_time = "Пре-таймер: Bounty руны",
        di_timings_wisdom_rune_time = "Пре-таймер: Wisdom руны",
        di_timings_lotus_time = "Пре-таймер: Лотосы",
        di_timings_tormentor1_time = "1-е опов. Терзателя",
        di_timings_tormentor2_time = "2-е опов. Терзателя",
        di_media_enabled = "Медиа плеер",
        di_media_enabled_tip = "Музыкальный плеер в островке.\nНужен MediaBridge",
        di_media_spotify_like = "Лайк трека",
        di_media_spotify_like_tip = "Сердечко ставит лайк треку в Spotify\nили Яндекс Музыке. Нужен MediaBridge",
        di_media_volume_wheel = "Громкость колесиком мыши",
        di_media_volume_wheel_tip = "Колесико над островком меняет\nгромкость плеера",
        di_media_lyrics = "Текст песен",
        di_gear_lyrics = "Текст песен",
        di_media_lyrics_compact = "Текст в маленьком островке",
        di_media_lyrics_compact_tip = "Показывает строку, которую поют,\nвместо названия трека в маленьком островке",
        di_media_lyrics_tip = "Текст песни в такт музыке, с lrclib.net.\nКавычки открывают его, клик по строке перематывает",
        di_media_marquee_speed = "Скорость бегущей строки",
        di_media_marquee_speed_tip = "Как быстро прокручиваются длинные названия",
        di_media_compact_title = "Название трека в маленьком островке",
        di_media_compact_title_tip = "Название трека в маленьком островке,\nа не только обложка и волна",
        di_media_artwork_tint = "Цвет волны из обложки",
        di_media_artwork_tint_tip = "Волна музыки берет\nцвет обложки",
        di_media_secondary_bubble = "Второй островок/баббл",
        di_media_secondary_bubble_tip = "Мелкие оповещения уходят в кружок сбоку,\nа не закрывают плеер",
        di_media_in_menu = "Показывать в главном меню",
        di_media_in_menu_tip = "Музыка занимает островок и в главном меню.\nПоиск матча уходит во второй пузырь",
        di_media_shadow = "Мягкие тени",
        di_media_shadow_tip = "Мягкая тень под островком\nи кружками",
        di_media_blur = "Размытие фона (Blur)",
        di_media_blur_tip = "Размывает игру под островком",
        di_media_hints = "Подсказки управления",
        di_media_hints_tip = "Подсказки управления под островком,\nпока открыто меню Umbrella",
        di_media_accent_color = "Основной цвет темы",
        di_media_accent_color_tip = "Цвет волны музыки, когда\nцвет из обложки выключен",
        di_media_export_cfg = "Экспорт всех настроек в файл",
        di_media_export_cfg_tip = "Сохраняет все настройки\nв файл настроек островка",
        di_media_import_cfg = "Импорт всех настроек из файла",
        di_media_import_cfg_tip = "Загружает все настройки\nиз файла настроек островка",
        di_courier_delivering = "Доставка вещей",
        di_courier_delivered = "Доставлено",
        di_courier_eta = "Через",
        di_courier_speed = "Скор.",
        di_courier_hp = "ХП",
        di_island_clock = "Часы",
        di_island_kda = "КДА",
        di_island_gold = "Золото",
        di_island_networth = "Нетворс",
        di_island_lasthits = "Добивания",
        di_island_hero = "Герой",
        di_island_fps = "ФПС",
        di_island_ping = "Пинг",
        di_island_paused = "Пауза",
        di_haptics_enabled = "Включить тактильный движок",
        di_haptics_enabled_tip = "Сжатие, свечение и щелчки,\nкогда островок откликается",
        di_haptics_visual = "Визуальная тактильность (Сквиш)",
        di_haptics_visual_tip = "Островок сжимается и светится\nпри нажатиях и оповещениях",
        di_haptics_audio = "Звуки интерфейса",
        di_haptics_audio_tip = "Тихие щелчки при нажатиях,\nпрокрутке и раскрытии",
        di_haptics_volume = "Громкость интерфейса",
        di_haptics_volume_tip = "Громкость щелчков интерфейса",
        di_alert_sounds = "Звуки оповещений",
        di_alert_sounds_tip = "Звуки оповещений, курьера, паузы и матча.\nЩелчки интерфейса в Extra, Тактильный отклик",
        di_alert_volume = "Громкость оповещений",
        di_alert_volume_tip = "Громкость звуков оповещений",
        di_alert_sound = "Звук",
        di_alert_sound_tip = "Проигрывать звук,\nкогда появляется это оповещение",
        di_sdk_slot_tip = "Разрешает скрипту показывать уведомления,\nактивности и виджеты",
        di_rem_time_tip = "Время игры для напоминания",
        di_rem_on_tip = "Свое напоминание на время игры.\nТекст и время в шестеренке",
        di_lead_tip = "За сколько секунд\nнапомнить",
        di_haptics_intensity = "Сила кинетического импульса",
        di_haptics_intensity_tip = "Насколько сильное сжатие",
        di_haptics_combat_filter = "Умный фильтр в драках",
        di_haptics_combat_filter_tip = "Пропускает легкие отклики в драке,\nчтобы ничего не отвлекало",
        di_haptics_audio_ducking = "Затихание остальных звуков",
        di_haptics_audio_ducking_tip = "Остальные звуки тише, пока островок\nиграет свой. Нужен MediaBridge",
        di_haptics_ducking_amount = "Сила затихания",
        di_haptics_ducking_amount_tip = "Насколько тише становится остальное",
        di_haptics_ducking_alerts = "Затихание: Важные алерты",
        di_haptics_ducking_alerts_tip = "Затихать на важных оповещениях",
        di_haptics_ducking_courier = "Затихание: Курьер",
        di_haptics_ducking_courier_tip = "Затихать при доставке курьера",
        di_haptics_ducking_notifs = "Затихание: Уведомления",
        di_haptics_ducking_notifs_tip = "Затихать на обычных уведомлениях",
        di_haptics_ducking_motion = "Затихание: Движение острова",
        di_haptics_ducking_motion_tip = "Затихать на звуках раскрытия и сворачивания",
        di_haptics_ducking_taptics = "Затихание: Клики и кнопки",
        di_haptics_ducking_taptics_tip = "Затихать на щелчках и кнопках",
        di_haptics_test_ducking = "Проверить звук",
        di_haptics_test_ducking_tip = "Проигрывает звук, чтобы услышать,\nнасколько затихает остальное",
        di_priority_roshan_kill = "Убийство Рошана",
        di_priority_aegis = "Подбор Эгиды",
        di_priority_roshan_attack = "Атака на Рошана",
        di_priority_fight_summary = "Итог боя",
        di_priority_power_rune_cycle = "Приоритет"
    },
})
local Menu = localization.WrapLibrary(Menu)

local LCache = { lang = nil, strings = {} }
local function L(key)
    local lang = localization.GetLanguage()
    if lang ~= LCache.lang then
        LCache.lang = lang
        LCache.strings = {}
    end
    local v = LCache.strings[key]
    if v == nil then
        v = localization.Localize(key)
        if type(v) ~= "string" then v = key end
        LCache.strings[key] = v
    end
    return v
end

local function ToggleOn(widget)
    if not widget then return true end
    return widget:Get() == true
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
        SNAPPY = { omega = 21.0, zeta = 0.82 },
        SMOOTH = { omega = 16.0, zeta = 1.0 },
        BOUNCY = { omega = 13.5, zeta = 0.72 }
    },
    CurrentProfile = "BOUNCY",
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
    if MotionEngine.Reduce and z < 1 then z = 1 end
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
    return MotionEngine.Profiles[name] or MotionEngine.Profiles.BOUNCY
end

function MotionEngine.Step(pos, vel, target, dt, name, eps)
    local p = MotionEngine.Profiles[name] or MotionEngine.Profiles.SMOOTH
    return MotionEngine.SolveSpring(pos, vel, target, dt, p.omega, p.zeta, eps)
end

function MotionEngine.UpdateSmoothedDt(rawDt)
    local clamped = math.max(0.005, math.min(0.04, rawDt or 0.016))
    MotionEngine.SmoothedDt = MotionEngine.SmoothedDt + (clamped - MotionEngine.SmoothedDt) * 0.35
    return MotionEngine.SmoothedDt
end

local SolveDampedSpring = MotionEngine.SolveSpring

local Config = {
    Fonts = {
        Regular = nil,
        Medium = nil,
        Semibold = nil,
        Display = nil,
        Lyric = nil,
        Main = nil,
        Bold = nil
    },
    Type = {
        LargeNum = { "Display", 28 },
        Title = { "Semibold", 16 },
        Headline = { "Semibold", 14 },
        Body = { "Regular", 14 },
        Subhead = { "Regular", 13 },
        Footnote = { "Regular", 12 },
        FootnoteEm = { "Semibold", 12 },
        Caption = { "Medium", 11 },
        Caption2 = { "Semibold", 9 }
    },
    Colors = {
        Border = Color(255, 255, 255, 28),
        Shadow = Color(0, 0, 0, 135),
        TextPrimary = Color(255, 255, 255, 255),
        TextSecondary = Color(235, 235, 245, 153),
        TextMuted = Color(235, 235, 245, 77),
        TextQuaternary = Color(235, 235, 245, 46),
        TextInverse = Color(0, 0, 0, 255),
        Separator = Color(84, 84, 88, 153),
        Fill = Color(120, 120, 128, 92),
        FillSecondary = Color(120, 120, 128, 82),
        FillTertiary = Color(118, 118, 128, 61),
        FillQuaternary = Color(118, 118, 128, 46),
        Accent = Color(48, 209, 88, 255),
        Red = Color(255, 69, 58, 255),
        Orange = Color(255, 159, 10, 255),
        Yellow = Color(255, 214, 10, 255),
        Green = Color(48, 209, 88, 255),
        Mint = Color(99, 230, 226, 255),
        Teal = Color(64, 200, 224, 255),
        Cyan = Color(100, 210, 255, 255),
        Blue = Color(10, 132, 255, 255),
        Indigo = Color(94, 92, 230, 255),
        Purple = Color(191, 90, 242, 255),
        Pink = Color(255, 55, 95, 255),
        Brown = Color(172, 142, 104, 255),
        Gray = Color(142, 142, 147, 255),
        TrackProgressBg = Color(120, 120, 128, 92),
        GridOverlay = Color(0, 0, 0, 95),
        GridAxis = Color(48, 209, 88, 140),
        GridHighlight = Color(48, 209, 88, 220),
        PMenuIslandBorder = Color(255, 255, 255, 65),
        ChipActiveBorder = Color(255, 255, 255, 255),
        ChipInactive = Color(118, 118, 128, 61),
        ChipInactiveBorder = Color(255, 255, 255, 0),
        HintBg = Color(28, 28, 30, 220),
        HintBorder = Color(255, 255, 255, 20),
        SegTrack = Color(118, 118, 128, 61),
        SegThumb = Color(99, 99, 102, 255),
        Group = Color(118, 118, 128, 61),
        Grabber = Color(235, 235, 245, 77),
        Placeholder = Color(58, 58, 60, 255)
    },

    Dimensions = {
        CompactW = 120,
        CompactH = 34,
        CompactRadius = 17,

        CompactMediaW = 205,
        CompactMediaBareW = 124,
        CompactMediaH = 34,
        CompactMediaRadius = 17,

        CompactFightW = 200,
        CompactFightH = 34,
        CompactFightRadius = 17,

        NotificationW = 260,
        NotificationH = 44,
        NotificationRadius = 22,

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

local Impl = {}

local Dbg = { On = false, TB = debug and debug.traceback }

Impl.HttpUnsent = {}

function Impl.HttpRequest(method, url, data, cb, tag)
    if not Dbg.On or type(cb) ~= "function" then
        if tag ~= nil then return HTTP.Request(method, url, data, cb, tag) end
        return HTTP.Request(method, url, data, cb)
    end
    local at = os.clock()
    local path = string.match(url, "^https?://[^/]+(/[^?]*)") or url
    local function done(res)
        local took = os.clock() - at
        if took > 1.5 then
            Dbg.Log("http", string.format("slow answer on %s: %.1f s, code %s, error %s %s", path, took, tostring(res and res.code), tostring(res and res.error_code), tostring(res and res.error_message)))
        end
        return cb(res)
    end
    local sent
    if tag ~= nil then sent = HTTP.Request(method, url, data, done, tag) else sent = HTTP.Request(method, url, data, done) end
    if sent == false and at - (Impl.HttpUnsent[path] or 0) > 2 then
        Impl.HttpUnsent[path] = at
        Dbg.Log("http", "request was not sent: " .. path)
    end
    return sent
end

local Fuse = { Count = {}, Off = {}, Logged = 0 }

function Fuse.Fail(name, err)
    local c = (Fuse.Count[name] or 0) + 1
    Fuse.Count[name] = c
    if Dbg.On then
        Dbg.Error(name, err)
    elseif c <= 3 and Fuse.Logged < 60 then
        Fuse.Logged = Fuse.Logged + 1
        Log.Write("[Dynamic Island] " .. name .. ": " .. tostring(err))
    end
    if c == 30 then
        Fuse.Off[name] = true
        if Dbg.On then
            Dbg.Log("error", name .. " turned off after repeated errors", true)
        else
            Log.Write("[Dynamic Island] " .. name .. " turned off after repeated errors")
        end
    end
end

function Fuse.Unwind(depth)
    local base = getmetatable(Render).__index
    while ClipDepth.n > depth do base.PopClip() end
end

function Fuse.Guard(name, fn, ...)
    if Fuse.Off[name] then return end
    local depth = ClipDepth.n
    local ok, err
    if Dbg.On and Dbg.TB then
        ok, err = xpcall(fn, Dbg.Trace, ...)
    else
        ok, err = pcall(fn, ...)
    end
    if not ok then
        Fuse.Unwind(depth)
        Fuse.Fail(name, err)
    end
end

local Perf = { Now = os.clock, Frame = { sum = 0, max = 0, n = 0 }, Update = { sum = 0, max = 0, n = 0 }, At = 0 }
do
    local ok, chronos = pcall(require, "chronos")
    if ok and type(chronos) == "table" and chronos.nanotime then Perf.Now = chronos.nanotime end
end

function Perf.Add(name, dt)
    if Dbg.On then Dbg.PerfAdd(name, dt) end
end

local function TF(role, scale)
    local t = Config.Type[role]
    return Config.Fonts[t[1]], t[2] * (scale or 1)
end

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
        COURIER_LARGE = 14,
        FOCUS_BANNER = 17,
        SHEET = 18,
        NOTIF_CENTER = 19,
        ACTIVITY = 20,
        ACTIVITY_LARGE = 21,
        FACE_ID = 22
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
        Reveal = 1.0,
        Dist0 = nil,
        SharedPair = nil,
        StartTime = 0
    },
    Ghosts = {},

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
    MediaPlaylist = { scale = 1.0, vel = 0 },
    MediaShuffle = { scale = 1.0, vel = 0 },
    MediaRepeat = { scale = 1.0, vel = 0 },
    MediaLyrics = { scale = 1.0, vel = 0 },
    SatellitePrev = { scale = 1.0, vel = 0 },
    SatellitePlay = { scale = 1.0, vel = 0 },
    SatelliteNext = { scale = 1.0, vel = 0 }
}

local ThemeSpring = {
    factor = 0.0,
    vel = 0.0,
    target = 0.0
}

function Impl.OnLight(col)
    local f = ThemeSpring.LastF or 0
    if f <= 0 or not col then return col end
    local k = 1 - 0.3 * f
    return Color(math.floor(col.r * k), math.floor(col.g * k), math.floor(col.b * k), col.a or 255)
end

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
    DeliveredDuration = 2.2,
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
    IsGoingToStash = false,
    ViaStash = false,
    Carry = 0,
    GraceUntil = 0,
    Zone = { R = 1200, Guess = true }
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
        { id = "clock", label = "di_island_clock" },
        { id = "kda", label = "di_island_kda" },
        { id = "gold", label = "di_island_gold" },
        { id = "networth", label = "di_island_networth" },
        { id = "lasthits", label = "di_island_lasthits" },
        { id = "heroname", label = "di_island_hero" },
        { id = "fps", label = "di_island_fps" },
        { id = "ping", label = "di_island_ping" }
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
        t = 0, h = 0, hVel = 0, LastId = false, Pos = {},
        Page = { v = 0, vel = 0 },
        SegWeight = { v = 0, vel = 0 },
        SegFormat = { v = 0, vel = 0 },
        Knob = { v = 0, vel = 0 },
        KnobOn = { v = 0, vel = 0 }
    }
}

local PerformanceData = {
    FPS = 60,
    Ping = 30,
    LastFPSUpdate = 0,
    FrameCount = 0,
    FpsEma = nil,
    FpsShown = false,
    PingShown = false,
    Warn = {}
}

function PerformanceData.Level(kind)
    if kind == "fps" then
        local v = PerformanceData.FPS
        return v < 30 and 2 or (v < 60 and 1 or 0)
    end
    local v = PerformanceData.Ping
    return v > 200 and 2 or (v > 100 and 1 or 0)
end

local MediaData = {
    IsPlaying = false,
    Title = "",
    Artist = "",
    Album = "",
    PosSmooth = 0,
    PosTarget = 0,
    Duration = 0,
    App = "",
    LastPollTime = 0,
    PollInterval = 0.35,
    HasReceivedData = false,
    LastTrackKey = "",
    LastPlayTime = 0,
    LastPauseTime = 0,
    CoverPath = "",
    CoverJpg = "",
    CoverBase64 = "",
    CoverColor = Color(255, 55, 95, 255),
    CoverVersion = -1,
    CoverImageHandle = nil,
    CoverHandleSetAt = 0,
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
        AegisHolder = nil,
        Vis = 0,
        VisClk = 0,
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

local WasInGame = false

local NotifGlyphs = { bell = true, moon = true, swords = true, heart_outline = true, heart_fill = true, stack = true, buyback = true, volume = true, mute = true, headphones = true, display = true, battery_low = true, bolt = true }

local NotificationQueue = {
    List = {},
    Active = nil,
    StartTime = 0,
    LastDismissed = nil
}

local SatelliteBounds = nil
local MenuStateCandidate = { state = nil, since = 0 }

local Focus = { ClickAt = -10, BumpAt = -10, BannerStart = 0, TileVis = 0, Active = false, Mode = 0, Until = 0, StartedAt = 0, Suppressed = 0, BannerUntil = 0, BannerOn = true, Vis = 0, LastDraw = 0, PressAt = -10, ButtonAt = -10, Accent = Color(94, 92, 230, 255) }
local Reminders = { Fired = {} }
local Satellite = { S = {}, Right = { kind = nil, notif = nil } }
local Rampage = { Count = 0, LastKill = -100, Left = 0, SuccessAt = -10, Target = nil, Active = false }
local Success = { Fired = {} }
local Odometer = { States = {}, Widths = {}, WidthCount = 0, Digit = {}, Layouts = {}, LayoutCount = 0 }
local SeekDrag = { Active = false, Frac = 0, Grow = 0, GrowVel = 0, HoldUntil = 0, HoldPos = 0, HoldStart = 0 }
local PlaylistPicker = { Open = false, Loading = false, Busy = false, Items = {}, Selected = {}, Offset = 0, Hits = {}, Error = nil, Track = "", Retries = 0, RetryAt = 0 }

local SCRIPT_VERSION = "2.5.2"

local BridgeStatus = { FirstPoll = 0, LastPoll = 0, LastOk = 0, Version = "", Latest = "", MediaSessions = "" }
local SystemState = { LastPoll = 0, Seen = false }
local Sheet = { Kind = nil, Hits = {}, Dismissed = false, SeenVer = nil, ConfigLoaded = false, MenuSince = nil, Forced = nil, Upd = { State = "idle", Progress = 0, Error = "", Version = "", LastPoll = 0, LastOk = 0 }, Fonts = { State = "idle", LastPoll = 0, LastOk = 0 } }
local NotifCenter = { Items = {}, Hits = {} }
local Demo = { Active = false, Step = 0, At = 0 }
local Hello, Setup, Gesture = {}, {}, {}
local Pointer, Swipe, Sdk = {}, {}, {}
local SatelliteSubBounds = {}
local ImageCache = {}

local ButtonHits = {
    MediaPrev = nil,
    MediaPlay = nil,
    MediaNext = nil,
    MediaLike = nil,
    MediaPlaylist = nil,
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
    RightLastPressed = false,
    Swallow = {},
    LiveAt = 0
}

local KeyItemColors = {
    ["item_blink"] = { name = "Blink Dagger", col = Color(100, 210, 255, 255) },
    ["item_black_king_bar"] = { name = "BKB", col = Color(255, 214, 10, 255) },
    ["item_sheepstick"] = { name = "Scythe of Vyse", col = Color(100, 210, 255, 255) },
    ["item_orchid"] = { name = "Orchid", col = Color(255, 55, 95, 255) },
    ["item_bloodthorn"] = { name = "Bloodthorn", col = Color(255, 55, 95, 255) },
    ["item_rapier"] = { name = "Divine Rapier", col = Color(255, 214, 10, 255) },
    ["item_ultimate_scepter"] = { name = "Aghanim Scepter", col = Color(94, 92, 230, 255) },
    ["item_refresher"] = { name = "Refresher Orb", col = Color(48, 209, 88, 255) },
    ["item_radiance"] = { name = "Radiance", col = Color(255, 159, 10, 255) },
    ["item_heart"] = { name = "Heart of Tarrasque", col = Color(255, 69, 58, 255) },
    ["item_assault"] = { name = "Assault Cuirass", col = Color(255, 159, 10, 255) },
    ["item_butterfly"] = { name = "Butterfly", col = Color(48, 209, 88, 255) },
    ["item_nullifier"] = { name = "Nullifier", col = Color(255, 214, 10, 255) },
    ["item_satanic"] = { name = "Satanic", col = Color(255, 69, 58, 255) },
    ["item_aeon_disk"] = { name = "Aeon Disk", col = Color(100, 210, 255, 255) },
    ["item_silver_edge"] = { name = "Silver Edge", col = Color(191, 90, 242, 255) },
    ["item_invis_sword"] = { name = "Shadow Blade", col = Color(191, 90, 242, 255) },
    ["item_monkey_king_bar"] = { name = "MKB", col = Color(255, 159, 10, 255) },
    ["item_abyssal_blade"] = { name = "Abyssal Blade", col = Color(255, 69, 58, 255) },
    ["item_manta"] = { name = "Manta Style", col = Color(100, 210, 255, 255) },
    ["item_greater_crit"] = { name = "Daedalus", col = Color(255, 69, 58, 255) },
    ["item_desolator"] = { name = "Desolator", col = Color(255, 69, 58, 255) },
    ["item_moon_shard"] = { name = "Moon Shard", col = Color(191, 90, 242, 255) }
}

Impl.StrictInvisModifiers = {
    ["modifier_item_invisibility_edge_windwalk"] = { name = "Shadow Blade", icon = "panorama/images/items/invis_sword_png.vtex_c", col = Color(191, 90, 242, 255) },
    ["modifier_item_silver_edge_windwalk"] = { name = "Silver Edge", icon = "panorama/images/items/silver_edge_png.vtex_c", col = Color(191, 90, 242, 255) },
    ["modifier_item_smoke_of_deceit"] = { name = "Smoke of Deceit", icon = "panorama/images/items/smoke_of_deceit_png.vtex_c", col = Color(255, 159, 10, 255) },
    ["modifier_clinkz_skeleton_walk"] = { name = "Skeleton Walk", icon = "panorama/images/spellicons/clinkz_skeleton_walk_png.vtex_c", col = Color(255, 159, 10, 255) },
    ["modifier_clinkz_strafe_invis"] = { name = "Skeleton Walk", icon = "panorama/images/spellicons/clinkz_skeleton_walk_png.vtex_c", col = Color(255, 159, 10, 255) },
    ["modifier_nyx_assassin_vendetta"] = { name = "Vendetta", icon = "panorama/images/spellicons/nyx_assassin_vendetta_png.vtex_c", col = Color(255, 69, 58, 255) },
    ["modifier_mirana_moonlight_shadow"] = { name = "Moonlight Shadow", icon = "panorama/images/spellicons/mirana_moonlight_shadow_png.vtex_c", col = Color(100, 210, 255, 255) }
}

local RuneInfoList = {
    [Enum.RuneType.DOTA_RUNE_DOUBLEDAMAGE] = { name = "di_rune_names_double_damage", col = Color(10, 132, 255, 255), path = "panorama/images/spellicons/rune_doubledamage_png.vtex_c", svg = "rune_dd" },
    [Enum.RuneType.DOTA_RUNE_HASTE] = { name = "di_rune_names_haste", col = Color(255, 69, 58, 255), path = "panorama/images/spellicons/rune_haste_png.vtex_c", svg = "rune_haste" },
    [Enum.RuneType.DOTA_RUNE_ILLUSION] = { name = "di_rune_names_illusion", col = Color(255, 214, 10, 255), path = "panorama/images/spellicons/rune_illusion_png.vtex_c", svg = "rune_dd" },
    [Enum.RuneType.DOTA_RUNE_INVISIBILITY] = { name = "di_rune_names_invisibility", col = Color(94, 92, 230, 255), path = "panorama/images/spellicons/rune_invis_png.vtex_c", svg = "rune_invis" },
    [Enum.RuneType.DOTA_RUNE_REGENERATION] = { name = "di_rune_names_regeneration", col = Color(48, 209, 88, 255), path = "panorama/images/spellicons/rune_regen_png.vtex_c", svg = "rune_regen" },
    [Enum.RuneType.DOTA_RUNE_BOUNTY] = { name = "di_rune_names_bounty", col = Color(255, 214, 10, 255), path = "panorama/images/items/courier_gold_png.vtex_c", svg = "bounty" },
    [Enum.RuneType.DOTA_RUNE_ARCANE] = { name = "di_rune_names_arcane", col = Color(255, 55, 95, 255), path = "panorama/images/spellicons/rune_arcane_png.vtex_c", svg = "rune_arcane" },
    [Enum.RuneType.DOTA_RUNE_WATER] = { name = "di_rune_names_water", col = Color(100, 210, 255, 255), path = "panorama/images/items/bottle_water_png.vtex_c", svg = "rune_water" },
    [Enum.RuneType.DOTA_RUNE_XP] = { name = "di_rune_names_wisdom", col = Color(191, 90, 242, 255), path = "panorama/images/spellicons/rune_xp_png.vtex_c", svg = "rune_wisdom" },
    [Enum.RuneType.DOTA_RUNE_SHIELD] = { name = "di_rune_names_shield", col = Color(255, 214, 10, 255), path = "panorama/images/spellicons/rune_shield_png.vtex_c", svg = "rune_shield" }
}

Impl.RuneModifierMap = {
    ["modifier_rune_doubledamage"] = Enum.RuneType.DOTA_RUNE_DOUBLEDAMAGE,
    ["modifier_rune_haste"] = Enum.RuneType.DOTA_RUNE_HASTE,
    ["modifier_rune_regen"] = Enum.RuneType.DOTA_RUNE_REGENERATION,
    ["modifier_rune_arcane"] = Enum.RuneType.DOTA_RUNE_ARCANE,
    ["modifier_rune_shield"] = Enum.RuneType.DOTA_RUNE_SHIELD,
    ["modifier_rune_water"] = Enum.RuneType.DOTA_RUNE_WATER,
    ["modifier_rune_invis"] = Enum.RuneType.DOTA_RUNE_INVISIBILITY,
    ["modifier_rune_illusion"] = Enum.RuneType.DOTA_RUNE_ILLUSION
}

Impl.MapLandmarks = {
    { name = "di_landmarks_top_roshan_river", pos = { x = -2400, y = 1800 } },
    { name = "di_landmarks_bot_roshan_river", pos = { x = 2400, y = -1800 } },
    { name = "di_landmarks_top_river_rune", pos = { x = -1600, y = 1200 } },
    { name = "di_landmarks_bot_river_rune", pos = { x = 1200, y = -1600 } },
    { name = "di_landmarks_river_center", pos = { x = -100, y = -100 } },

    { name = "di_landmarks_radiant_triangle", pos = { x = -3400, y = -1800 } },
    { name = "di_landmarks_dire_triangle", pos = { x = 3400, y = 1800 } },
    { name = "di_landmarks_radiant_jungle", pos = { x = 2200, y = -4400 } },
    { name = "di_landmarks_dire_jungle", pos = { x = -2200, y = 4400 } },

    { name = "di_landmarks_radiant_tormentor", pos = { x = 3800, y = -5800 } },
    { name = "di_landmarks_dire_tormentor", pos = { x = -3800, y = 5800 } },
    { name = "di_landmarks_lotus_pool_top", pos = { x = -6000, y = 5600 } },
    { name = "di_landmarks_lotus_pool_bot", pos = { x = 6000, y = -5600 } },
    { name = "di_landmarks_wisdom_shrine_radiant", pos = { x = -7600, y = -3600 } },
    { name = "di_landmarks_wisdom_shrine_dire", pos = { x = 7600, y = 3600 } },
    { name = "di_landmarks_twin_gate_top", pos = { x = -7800, y = 7400 } },
    { name = "di_landmarks_twin_gate_bot", pos = { x = 7800, y = -7400 } },

    { name = "di_landmarks_mid_lane", pos = { x = 0, y = 0 } },
    { name = "di_landmarks_top_lane", pos = { x = -5500, y = 4800 } },
    { name = "di_landmarks_bot_lane", pos = { x = 5200, y = -5200 } },
    { name = "di_landmarks_radiant_base", pos = { x = -6500, y = -6500 } },
    { name = "di_landmarks_dire_base", pos = { x = 6500, y = 6500 } }
}

local VectorIcons = {
    ["bounty"] = { "\u{e000}", 179, -311, 2246, 1755, k = 0.833, fg = Color(255, 159, 10, 255) },
    ["lotus"] = { "\u{e001}", 179, -238, 2370, 1631, k = 0.833, bg = Color(255, 55, 95, 255) },
    ["wisdom"] = { "\u{e002}", 374, -417, 1955, 1948, k = 0.833, bg = Color(191, 90, 242, 255) },
    ["rune_wisdom"] = { "\u{e002}", 374, -417, 1955, 1948, k = 0.833, bg = Color(191, 90, 242, 255) },
    ["rune_water"] = { "\u{e003}", 179, -308, 1601, 1753, k = 0.833, bg = Color(100, 210, 255, 255) },
    ["rune_dd"] = { "\u{e004}", 275, -415, 1732, 1875, k = 0.833, bg = Color(10, 132, 255, 255) },
    ["rune_haste"] = { "\u{e005}", 179, -299, 3224, 1884, k = 0.833, bg = Color(255, 69, 58, 255) },
    ["rune_invis"] = { "\u{e006}", 218, -188, 2938, 1667, k = 0.833, bg = Color(94, 92, 230, 255) },
    ["rune_regen"] = { "\u{e007}", 242, -245, 2263, 1627, k = 0.833, bg = Color(48, 209, 88, 255) },
    ["rune_arcane"] = { "\u{e008}", 204, -356, 2079, 1940, k = 0.833, bg = Color(255, 55, 95, 255) },
    ["rune_shield"] = { "\u{e009}", 377, -295, 2039, 1707, k = 0.833, bg = Color(255, 214, 10, 255) },
    ["buyback"] = { "\u{e00a}", 179, -243, 1966, 1933, k = 0.725, ox = 0.01, oy = -0.025 },
    ["swords"] = { "\u{e00b}", 179, -283, 1878, 1908, k = 0.717 },
    ["flame"] = { "\u{e00b}", 179, -283, 1878, 1908, k = 0.958, oy = 0.062 },
    ["media_prev"] = { "\u{e00c}", 25, -80, 2865, 1527, k = 0.801 },
    ["media_next"] = { "\u{e00d}", 255, -80, 3095, 1527, k = 0.801 },
    ["media_play"] = { "\u{e00e}", 255, -154, 1819, 1595, k = 0.698, ox = 0.083 },
    ["media_pause"] = { "\u{e00f}", 254, -109, 1532, 1552, k = 0.667 },
    ["lyrics"] = { "\u{e010}", 255, -393, 2470, 1714, k = 0.833 },
    ["heart_outline"] = { "\u{e011}", 242, -245, 2263, 1627, k = 0.842, oy = 0.01 },
    ["heart_fill"] = { "\u{e007}", 242, -245, 2263, 1627, k = 0.75, oy = 0.01 },
    ["shuffle"] = { "\u{e012}", 255, -250, 2676, 1683, k = 0.842, oy = -0.042 },
    ["repeat"] = { "\u{e013}", 255, -221, 2497, 1685, k = 0.842 },
    ["clock"] = { "\u{e014}", 179, -311, 2246, 1755, k = 0.842 },
    ["kda"] = { "\u{e015}", 179, -502, 2624, 1944, k = 0.925 },
    ["gold"] = { "\u{e016}", 179, -311, 2246, 1755, k = 0.842 },
    ["networth"] = { "\u{e017}", 255, -215, 2847, 1668, k = 0.779, ox = -0.01 },
    ["lasthits"] = { "\u{e018}", 226, -452, 2759, 1918, k = 0.738, oy = 0.01 },
    ["heroname"] = { "\u{e019}", 255, -220, 2875, 1795, k = 0.8, oy = -0.01 },
    ["fps"] = { "\u{e01a}", 179, -343, 2246, 1723, k = 0.842, oy = -0.053 },
    ["ping"] = { "\u{e01b}", 183, -122, 2516, 1564, k = 0.888, oy = 0.027 },
    ["home"] = { "\u{e01c}", 255, -357, 2696, 1781, k = 0.8 },
    ["search"] = { "\u{e01d}", 230, -240, 2135, 1683, k = 0.8, ox = 0.021, oy = 0.021 },
    ["check"] = { "\u{e01e}", 255, -170, 2023, 1565, k = 0.7, oy = 0.01 },
    ["close"] = { "\u{e01f}", 251, -89, 1870, 1529, k = 0.567 },
    ["chevron"] = { "\u{e020}", 386, -163, 1405, 1607, k = 0.733, ox = 0.031 },
    ["chevron_back"] = { "\u{e021}", 123, -163, 1142, 1607, k = 0.825, ox = -0.031 },
    ["appearance"] = { "\u{e022}", 179, -311, 2246, 1755, k = 0.842 },
    ["plus"] = { "\u{e023}", 255, -115, 1929, 1559, k = 0.708 },
    ["bolt"] = { "\u{e004}", 275, -415, 1732, 1875, k = 0.849 },
    ["music"] = { "\u{e024}", 255, -315, 1503, 1722, k = 0.73, ox = -0.05, oy = -0.023 },
    ["headphones"] = { "\u{e025}", 255, -235, 2377, 1720, k = 0.733 },
    ["display"] = { "\u{e026}", 255, -298, 2661, 1743, k = 0.842, oy = 0.013 },
    ["battery_low"] = { "\u{e027}", 255, -6, 3285, 1449, k = 0.862 },
    ["arrow_down"] = { "\u{e028}", 255, -228, 1804, 1671, k = 0.7, oy = -0.021 },
    ["hold"] = { "\u{e029}", 179, -311, 2246, 1755, k = 0.758 },
    ["moon"] = { "\u{e02a}", 179, -266, 2149, 1714, k = 0.75 },
    ["bell"] = { "\u{e02b}", 209, -351, 2137, 1779, k = 0.721, oy = -0.014 },
    ["courier"] = { "\u{e02c}", 255, -375, 2300, 1811, k = 0.753 },
    ["pause"] = { "\u{e00f}", 254, -109, 1532, 1552, k = 0.667 },
    ["volume"] = { "\u{e02d}", 312, -174, 2630, 1616, k = 0.786, ox = 0.039 },
    ["mute"] = { "\u{e02e}", 112, -294, 2021, 1616, k = 0.796, ox = 0.044 },
    ["apple_check"] = { "\u{e02f}", 179, -311, 2246, 1755, k = 0.833, fg = Color(52, 199, 89, 255) },
    ["stack"] = { "\u{e030}", 245, -428, 2316, 1836, k = 0.692 }
}

local PowerRunesCycleList = {
    { path = "panorama/images/spellicons/rune_doubledamage_png.vtex_c", svg = "rune_dd", col = Color(10, 132, 255, 255) },
    { path = "panorama/images/spellicons/rune_haste_png.vtex_c", svg = "rune_haste", col = Color(255, 69, 58, 255) },
    { path = "panorama/images/spellicons/rune_invis_png.vtex_c", svg = "rune_invis", col = Color(94, 92, 230, 255) },
    { path = "panorama/images/spellicons/rune_arcane_png.vtex_c", svg = "rune_arcane", col = Color(255, 55, 95, 255) },
    { path = "panorama/images/spellicons/rune_regen_png.vtex_c", svg = "rune_regen", col = Color(48, 209, 88, 255) },
    { path = "panorama/images/spellicons/rune_shield_png.vtex_c", svg = "rune_shield", col = Color(255, 214, 10, 255) }
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

Impl.ConfigSavePaths = { "dynamic_island_config.json", "scripts/dynamic_island_config.json" }

function Impl.OpenFile(path, mode)
    local ok, f = pcall(io.open, path, mode)
    if ok then return f end
    return nil
end

Impl.PALETTE = {
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

function Impl.HexToColor(hex)
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
    local wg = Impl.Wg and Impl.Wg.ById[chipId]
    if wg then
        local c = wg.tint
        return Color(c.r, c.g, c.b, 255), string.format("%02X%02X%02X", c.r, c.g, c.b)
    end
    if chipId == "gold" then return Color(255, 214, 10, 255), "FFD60A"
    elseif chipId == "kda" then return Color(48, 209, 88, 255), "30D158"
    elseif chipId == "clock" then return Color(255, 159, 10, 255), "FF9F0A"
    elseif chipId == "networth" then return Color(100, 210, 255, 255), "64D2FF"
    elseif chipId == "lasthits" then return Color(255, 159, 10, 255), "FF9F0A"
    elseif chipId == "heroname" then return Color(191, 90, 242, 255), "BF5AF2"
    elseif chipId == "fps" then return Color(48, 209, 88, 255), "30D158"
    elseif chipId == "ping" then return Color(10, 132, 255, 255), "0A84FF"
    end
    return Color(100, 210, 255, 255), "64D2FF"
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
    local paths = Impl.ConfigSavePaths
    for _, path in ipairs(paths) do
        local f = Impl.OpenFile(path, "w")
        if f then
            local activeStr = table.concat(Impl.WgActiveList(), ",")
            f:write("active=" .. activeStr .. "\n")
            f:write(string.format("drag_center=%d,%d\n", math.floor(DragState.CustomX or -1), math.floor(DragState.CustomY or -1)))
            if Sheet.SeenVer then f:write("seen_ver=" .. Sheet.SeenVer .. "\n") end
            if Sheet.BridgeHintSeen then f:write("bridge_hint=1\n") end
            if Hello.SetupDone then f:write("setup_done=1\n") end
            if CourierTracker.Zone.R and not CourierTracker.Zone.Guess then f:write(string.format("courier_zone=%d,%.3f\n", math.floor(CourierTracker.Zone.R), CourierTracker.Zone.Ratio or 1.5)) end
            if Impl.Ly.Open then f:write("lyrics_open=1\n") end
            if Hello.ChatPrev ~= nil then f:write("hello_chat=" .. (Hello.ChatPrev and "1" or "0") .. "\n") end
            if Hello.StampValue or Hello.SavedStamp then f:write("hello_stamp=" .. tostring(Hello.StampValue or Hello.SavedStamp) .. "\n") end
            if HUDCustomizer.Saved and #HUDCustomizer.Saved > 0 then f:write("saved_colors=" .. table.concat(HUDCustomizer.Saved, ",") .. "\n") end
            if Setup.Resume then f:write("setup_resume=" .. tostring(Setup.Resume) .. "\n") end
            local apps = Sdk.SaveLine()
            if apps then f:write("sdk_apps=" .. apps .. "\n") end
            local focusApps = Sdk.FocusLine()
            if focusApps then f:write("sdk_focus=" .. focusApps .. "\n") end
            local mutedApps = Sdk.SoundLine()
            if mutedApps then f:write("sdk_nosound=" .. mutedApps .. "\n") end

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
                    if UI.Main.BorderThickness then f:write(string.format("ui_border_w=%.1f\n", UI.Main.BorderThickness:Get())) end
                end
                if UI.Combat then
                    if UI.Combat.FightHUD then f:write("ui_c_fighthud=" .. (UI.Combat.FightHUD:Get() and "1" or "0") .. "\n") end
                    if UI.Combat.FightScope then f:write("ui_c_fightscope=" .. tostring(UI.Combat.FightScope:Get()) .. "\n") end
                    if UI.Combat.MinHeroes then f:write("ui_c_minheroes=" .. tostring(UI.Combat.MinHeroes:Get()) .. "\n") end
                    if UI.Combat.FightRadius then f:write("ui_c_fightradius=" .. tostring(UI.Combat.FightRadius:Get()) .. "\n") end
                    if UI.Combat.RadarZoom then f:write("ui_c_radarzoom=" .. tostring(UI.Combat.RadarZoom:Get()) .. "\n") end
                    if UI.Combat.FightTimeout then f:write("ui_c_fighttimeout=" .. tostring(UI.Combat.FightTimeout:Get()) .. "\n") end
                    if UI.Combat.FightLargeW then f:write("ui_c_large_w=" .. tostring(UI.Combat.FightLargeW:Get()) .. "\n") end
                    if UI.Combat.FightLargeH then f:write("ui_c_large_h=" .. tostring(UI.Combat.FightLargeH:Get()) .. "\n") end
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
                    if UI.Timings.StackUntil then f:write("ui_t_stack_until=" .. tostring(UI.Timings.StackUntil:Get()) .. "\n") end
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
                    if UI.Media.InMenu then f:write("ui_m_menu=" .. (UI.Media.InMenu:Get() and "1" or "0") .. "\n") end
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

                for secName, sec in pairs(UI) do
                    if type(sec) == "table" then
                        for name, w in pairs(sec) do
                            local ok, v = pcall(function() return w:Get() end)
                            if ok and type(v) == "boolean" then
                                f:write(string.format("w_%s.%s=%s\n", secName, name, v and "b1" or "b0"))
                            elseif ok and type(v) == "number" then
                                f:write(string.format("w_%s.%s=%s\n", secName, name, tostring(v)))
                            elseif ok and type(v) == "string" and not string.find(v, "[\r\n]") then
                                f:write(string.format("w_%s.%s=s:%s\n", secName, name, v))
                            end
                        end
                    end
                end
            end
            f:close()
            break
        end
    end
end

function Impl.LoadAllConfig()
    local paths = Impl.ConfigSavePaths
    local f = nil
    for _, path in ipairs(paths) do
        f = Impl.OpenFile(path, "r")
        if f then break end
    end
    if not f then return end
    Impl.HadConfig = true

    for line in f:lines() do
        local activeMatch = string.match(line, "^active=([%w_,]+)")
        local dragMatchX, dragMatchY = string.match(line, "^drag_center=([%-]?%d+),([%-]?%d+)")
        local seenMatch = string.match(line, "^seen_ver=([%w%.]+)")
        if seenMatch then
            Sheet.SeenVer = seenMatch
        elseif line == "bridge_hint=1" then
            Sheet.BridgeHintSeen = true
        elseif line == "setup_done=1" then
            Hello.SetupDone = true
        elseif string.sub(line, 1, 13) == "courier_zone=" then
            local zr, zk = string.match(line, "^courier_zone=(%d+),([%d%.]+)$")
            zr, zk = tonumber(zr), tonumber(zk)
            if zr and zk and zr >= 300 and zr <= 4500 and zk >= 1.1 and zk <= 3 then
                CourierTracker.Zone.R = zr
                CourierTracker.Zone.Ratio = zk
                CourierTracker.Zone.Guess = nil
            end
        elseif line == "lyrics_open=1" then
            Impl.Ly.Open = true
        elseif line == "hello_chat=1" or line == "hello_chat=0" then
            Hello.ChatPending = line == "hello_chat=1"
        elseif string.match(line, "^hello_stamp=%-?%d+$") then
            Hello.SavedStamp = tonumber(string.match(line, "^hello_stamp=(%-?%d+)$"))
        elseif string.sub(line, 1, 13) == "saved_colors=" then
            HUDCustomizer.Saved = {}
            for hx in string.gmatch(string.sub(line, 14), "%x%x%x%x%x%x") do
                HUDCustomizer.Saved[#HUDCustomizer.Saved + 1] = string.upper(hx)
            end
        elseif string.sub(line, 1, 9) == "sdk_apps=" then
            Sdk.LoadLine(string.sub(line, 10))
        elseif string.sub(line, 1, 10) == "sdk_focus=" then
            Sdk.LoadFocus(string.sub(line, 11))
        elseif string.sub(line, 1, 12) == "sdk_nosound=" then
            Sdk.LoadSound(string.sub(line, 13))
        elseif string.match(line, "^setup_resume=%d+$") then
            Setup.Resume = tonumber(string.match(line, "^setup_resume=(%d+)$"))
        elseif activeMatch then
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
            if id and not HUDCustomizer.WidgetConfigs[id] and string.sub(id, 1, 4) == "sdk_" then
                HUDCustomizer.WidgetConfigs[id] = { bold = false, colorMode = 1, format = 1, showIcon = true }
            end
            if id and HUDCustomizer.WidgetConfigs[id] then
                HUDCustomizer.WidgetConfigs[id].bold = (boldStr == "1")
                HUDCustomizer.WidgetConfigs[id].colorMode = tonumber(colStr) or 1
                HUDCustomizer.WidgetConfigs[id].format = tonumber(fmtStr) or 1
                if iconStr and iconStr ~= "" then
                    HUDCustomizer.WidgetConfigs[id].showIcon = (iconStr == "1")
                end
                if hexStr and #hexStr == 6 then
                    HUDCustomizer.WidgetConfigs[id].customHex = hexStr
                    HUDCustomizer.WidgetConfigs[id].customColor = Impl.HexToColor(hexStr)
                end
            elseif UI then
                local wSec, wName, wVal = string.match(line, "^w_([%w_]+)%.([%w_]+)=(.*)$")
                local k, v = string.match(line, "^([%w_]+)=(.*)$")
                if wSec then
                    local w = type(UI[wSec]) == "table" and UI[wSec][wName] or nil
                    if w then
                        local val
                        if string.sub(wVal, 1, 2) == "s:" then
                            val = string.sub(wVal, 3)
                        elseif wVal == "b1" or wVal == "b0" then
                            val = wVal == "b1"
                        else
                            val = tonumber(wVal)
                        end
                        if val ~= nil then pcall(function() w:Set(val) end) end
                    end
                elseif k and v then
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
                    elseif k == "ui_border_w" and UI.Main and UI.Main.BorderThickness then UI.Main.BorderThickness:Set(tonumber(v) or 1.0)
                    elseif k == "ui_c_fighthud" and UI.Combat and UI.Combat.FightHUD then UI.Combat.FightHUD:Set(v == "1")
                    elseif k == "ui_c_fightscope" and UI.Combat and UI.Combat.FightScope then UI.Combat.FightScope:Set(tonumber(v) or 0)
                    elseif k == "ui_c_minheroes" and UI.Combat and UI.Combat.MinHeroes then UI.Combat.MinHeroes:Set(tonumber(v) or 2)
                    elseif k == "ui_c_fightradius" and UI.Combat and UI.Combat.FightRadius then UI.Combat.FightRadius:Set(tonumber(v) or 1600)
                    elseif k == "ui_c_radarzoom" and UI.Combat and UI.Combat.RadarZoom then UI.Combat.RadarZoom:Set(tonumber(v) or 2000)
                    elseif k == "ui_c_fighttimeout" and UI.Combat and UI.Combat.FightTimeout then UI.Combat.FightTimeout:Set(tonumber(v) or 4)
                    elseif k == "ui_c_large_w" and UI.Combat and UI.Combat.FightLargeW then UI.Combat.FightLargeW:Set(math.floor(tonumber(v) or 365))
                    elseif k == "ui_c_large_h" and UI.Combat and UI.Combat.FightLargeH then UI.Combat.FightLargeH:Set(math.floor(tonumber(v) or 148))
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
                    elseif k == "ui_t_stack_until" and UI.Timings and UI.Timings.StackUntil then UI.Timings.StackUntil:Set(tonumber(v) or 0)
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
                    elseif k == "ui_m_menu" and UI.Media and UI.Media.InMenu then UI.Media.InMenu:Set(v == "1")
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

local function MediaTint()
    if UI and UI.Media and UI.Media.ArtworkTint and not UI.Media.ArtworkTint:Get() then
        return UI.Media.AccentColor:Get() or Config.Colors.Accent
    end
    return MediaData.CoverColor or Config.Colors.Accent
end

local function CompactMediaTitle()
    return not (UI and UI.Media and UI.Media.CompactTitle) or UI.Media.CompactTitle:Get()
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
    return name and VectorIcons[name] or nil
end

function Impl.IconFont()
    local f = Config.Fonts.Icons
    if not f then return nil end
    if Impl.IonFor ~= f then
        Impl.IonFor = f
        Impl.IonUnit = 1 / 2048
        local ok, ts = pcall(Render.TextSize, f, 100, "\u{e014}")
        if ok and ts and ts.x > 0 then Impl.IonUnit = ts.x / 242500 end
    end
    return f
end

function Impl.DrawIcon(g, x, y, w, h, col)
    local f = Impl.IconFont()
    col = col or Color(255, 255, 255, 255)
    local a = col.a or 255
    if not f or a <= 0 or w <= 0 or h <= 0 then return end
    local box = math.min(w, h)
    local cx, cy = x + w / 2 + box * (g.ox or 0), y + h / 2 + box * (g.oy or 0)
    local fit = box * g.k
    if g.bg then
        Render.FilledCircle(Vec2(cx, cy), fit / 2, Color(g.bg.r, g.bg.g, g.bg.b, math.floor(g.bg.a * a / 255)), 0, 1.0, 32)
        fit = fit * 0.56
        col = Color(255, 255, 255, a)
    elseif g.fg then
        col = Color(math.floor(g.fg.r * col.r / 255), math.floor(g.fg.g * col.g / 255), math.floor(g.fg.b * col.b / 255), a)
    end
    local sc = fit / math.max(g[4] - g[2], g[5] - g[3])
    local size = sc / Impl.IonUnit
    local px = cx - (g[2] + g[4]) * 0.5 * sc
    local py = cy + (g[3] + g[5]) * 0.5 * sc - 1950 * sc
    Render.Text(f, size, g[1], Vec2(math.floor(px + 0.5), math.floor(py + 0.5)), col)
end

function Impl.Img(h, pos, size, col, ...)
    if type(h) == "table" then return Impl.DrawIcon(h, pos.x, pos.y, size.x, size.y, col) end
    return Render.Image(h, pos, size, col, ...)
end

local function GetCachedImage(path, fallbackSvgKey)
    if path and path ~= "" then
        local h = ImageCache[path]
        if h ~= nil and h ~= false then return h end
        local failKey = "\0fail" .. path
        if h == nil or os.clock() - (ImageCache[failKey] or 0) > 3 then
            local ok, handle = pcall(Render.LoadImage, path)
            if ok and handle and handle ~= 0 then
                ImageCache[path] = handle
                ImageCache[failKey] = nil
                return handle
            end
            ImageCache[path] = false
            ImageCache[failKey] = os.clock()
        end
    end
    if fallbackSvgKey then
        return GetVectorIcon(fallbackSvgKey)
    end
    return nil
end

function Impl.AutoSave(now)
    if now - (Impl.SaveCheckAt or 0) < 1 then return end
    Impl.SaveCheckAt = now
    local set, order = Dbg.Settings()
    local parts = {}
    for _, p in ipairs(order) do parts[#parts + 1] = p .. "=" .. set[p] end
    local sig = table.concat(parts, ";")
    if Impl.SaveSig and sig ~= Impl.SaveSig then SaveAllConfig() end
    Impl.SaveSig = sig
end

function Impl.A11yTick()
    local A = UI and UI.Access
    if not A or not A.Motion then return end
    MotionEngine.Reduce = A.Motion:Get()
    Impl.HighContrast = A.Contrast:Get()
    local bold = A.Bold:Get()
    if bold ~= (Impl.Bold or false) then
        Impl.Bold = bold
        Impl.LoadScriptFonts()
    end
end

function Impl.LoadScriptFonts()
    local aa = Enum.FontCreate.FONTFLAG_ANTIALIAS
    local bold = Impl.Bold
    Impl.FontCache = Impl.FontCache or {}
    local function F(name, weight)
        local key = name .. weight
        if not Impl.FontCache[key] then Impl.FontCache[key] = Render.LoadFont(name, aa, weight) end
        return Impl.FontCache[key]
    end
    Config.Fonts.Regular = F("SF Pro Text", bold and 600 or 400)
    Config.Fonts.Medium = F("SF Pro Text", bold and 700 or 500)
    Config.Fonts.Semibold = F("SF Pro Text", bold and 700 or 600)
    Config.Fonts.Display = F("SF Pro Display", bold and 700 or 500)
    Config.Fonts.Lyric = F("SF Pro Display", bold and 800 or 700)
    Config.Fonts.Icons = F("DI Symbols", 400)
    Config.Fonts.Main = Config.Fonts.Regular
    Config.Fonts.Bold = Config.Fonts.Semibold
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
        ERROR = 9
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
            [8] = 0.25
        }
    },
    Pattern = {
        Active = false,
        Type = 0,
        StartTime = 0.0,
        Step = 0
    }
}

Impl.AlertSound = { notification_toast = true, timer_chime = true, courier_delivered = true, courier_death_or_fail = true, low_hp_heartbeat = true, game_paused = true, game_unpaused = true, match_found = true }

local function HapticPlaySound(appleSoundName, arg2, arg3)
    if Haptic.Quiet then return end
    if Impl.BridgeLagging() then return end
    local alert = Impl.AlertSound[appleSoundName] == true
    local H = UI and UI.Haptics
    if alert then
        if not ToggleOn(H and H.AlertSounds) then return end
    else
        if not ToggleOn(H and H.Enabled) then return end
        if not (H and H.AudioFeedback and H.AudioFeedback:Get()) then return end
    end
    local baseVol = (type(arg2) == "number" and arg2) or (type(arg3) == "number" and arg3) or 0.5
    local volW = H and (alert and H.AlertVolume or H.Volume)
    local userVol = volW and (volW:Get() / 100.0) or 0.5
    local finalVol = math.max(0.01, math.min(1.0, baseVol * userVol))

    if appleSoundName and appleSoundName ~= "" then
        if HTTP and HTTP.Request then
            local forceParam = (appleSoundName == "match_found") and "&force=1" or ""
            local duckParam = ""
            if UI and UI.Haptics and UI.Haptics.AudioDucking and UI.Haptics.AudioDucking:Get() then
                local shouldDuck = false
                local weight = 0.5
                if appleSoundName == "wheel_notch" or appleSoundName == "wheel_boundary_bump" or appleSoundName == "toast_dismiss" then
                    shouldDuck = false
                    weight = 0.0
                elseif appleSoundName == "match_found" or appleSoundName == "low_hp_heartbeat" or appleSoundName == "courier_death_or_fail" then
                    shouldDuck = (not UI.Haptics.DuckingAlerts) or UI.Haptics.DuckingAlerts:Get()
                    weight = 1.0
                elseif appleSoundName == "courier_delivered" then
                    shouldDuck = (not UI.Haptics.DuckingCourier) or UI.Haptics.DuckingCourier:Get()
                    weight = 0.7
                elseif appleSoundName == "notification_toast" or appleSoundName == "game_paused" or appleSoundName == "game_unpaused" or appleSoundName == "timer_chime" then
                    shouldDuck = (not UI.Haptics.DuckingNotifs) or UI.Haptics.DuckingNotifs:Get()
                    weight = (appleSoundName == "timer_chime") and 0.4 or 0.7
                elseif appleSoundName == "island_expand" or appleSoundName == "island_collapse" then
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
            pcall(Impl.HttpRequest, "GET", "http://127.0.0.1:45455/sound?name=" .. appleSoundName .. "&vol=" .. string.format("%.2f", finalVol) .. forceParam .. duckParam, {}, function() end)
        end
    end
end

function Haptic.WheelQuery(bump)
    if not ToggleOn(UI and UI.Haptics and UI.Haptics.Enabled) or not ToggleOn(UI and UI.Haptics and UI.Haptics.AudioFeedback) then return "?nosound=1" end
    local userVol = (UI and UI.Haptics and UI.Haptics.Volume) and (UI.Haptics.Volume:Get() / 100.0) or 0.5
    local vol = math.max(0.01, math.min(1.0, (bump and 0.65 or 0.45) * userVol))
    return (bump and "?bump=1&vol=" or "?vol=") .. string.format("%.2f", vol)
end

function Haptic.Silent(hType)
    Haptic.Quiet = true
    Haptic.Trigger(hType)
    Haptic.Quiet = false
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

    local inCombat = FightTracker and FightTracker.Active or false
    local combatFilter = ToggleOn(UI and UI.Haptics and UI.Haptics.CombatFilter)
    if inCombat and combatFilter and (hType == Haptic.Types.TAP_LIGHT) then
        return
    end

    local intensity = (UI and UI.Haptics and UI.Haptics.Intensity) and (UI.Haptics.Intensity:Get() / 100.0) or 1.0
    local visualOn = ToggleOn(UI and UI.Haptics and UI.Haptics.VisualFeedback)

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
            Haptic.State.GlowColor = Color(255, 69, 58, 240)
            if (p1 == 1 or p1 == -1) and not MotionEngine.Reduce then
                Haptic.State.VelX = Haptic.State.VelX + p1 * 220 * intensity
            end
        end
    elseif hType == Haptic.Types.ERROR then
        if visualOn then
            if not MotionEngine.Reduce then Haptic.ShakeAt = nowClk end
            Haptic.ShakeAmp = 7 * intensity
            Haptic.State.GlowAlpha = 45 * intensity
            Haptic.State.GlowColor = Color(255, 69, 58, 240)
        end
        HapticPlaySound("wheel_boundary_bump", 0.45)
    elseif hType == Haptic.Types.SUCCESS_APPLE_PAY then
        if visualOn then
            Haptic.State.VelScaleX = Haptic.State.VelScaleX + 1.4 * intensity
            Haptic.State.VelScaleY = Haptic.State.VelScaleY + 1.4 * intensity
            Haptic.State.GlowAlpha = 140 * intensity
            Haptic.State.GlowColor = Color(48, 209, 88, 255)
        end
        if p1 ~= true then HapticPlaySound("courier_delivered", 0.65) end
        Haptic.Pattern.Active = true
        Haptic.Pattern.Type = Haptic.Types.SUCCESS_APPLE_PAY
        Haptic.Pattern.StartTime = nowClk
        Haptic.Pattern.Step = 1
    elseif hType == Haptic.Types.HEARTBEAT then
        if visualOn then
            Haptic.State.VelScaleY = Haptic.State.VelScaleY + 0.65 * intensity
            Haptic.State.VelScaleX = Haptic.State.VelScaleX + 0.45 * intensity
            Haptic.State.GlowAlpha = 80 * intensity
            Haptic.State.GlowColor = Color(255, 55, 95, 255)
        end
        if p1 and ToggleOn(UI and UI.Sounds and UI.Sounds.LowHp) then
            HapticPlaySound("low_hp_heartbeat", 0.35)
        end
        Haptic.Pattern.Active = true
        Haptic.Pattern.Type = Haptic.Types.HEARTBEAT
        Haptic.Pattern.StartTime = nowClk
        Haptic.Pattern.Step = 1
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
    if Haptic.ShakeAt then
        local t = (nowClk - Haptic.ShakeAt) / AnimScale()
        if t < 0.42 then
            local k = 1 - t / 0.42
            Haptic.State.OffsetX = (Haptic.ShakeAmp or 7) * math.sin(t * math.pi * 2 * 8.5) * k * k
            Haptic.State.VelX = 0
        else
            Haptic.ShakeAt = nil
            Haptic.State.OffsetX, Haptic.State.VelX = 0, 0
        end
    end

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
    else
        Haptic.State.WasLowHP = false
    end
end

function Haptic.ApplyTransform(layout)
    if not layout or layout.w <= 0 or layout.h <= 0 then return end
    local isEnabled = true
    if UI and UI.Haptics and UI.Haptics.Enabled then
        isEnabled = UI.Haptics.Enabled:Get()
    end
    if not isEnabled then return end

    local visualOn = ToggleOn(UI and UI.Haptics and UI.Haptics.VisualFeedback)
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

function Impl.InitMenu()
    local tab = Menu.Create("General", "Dynamic Island", "Dynamic Island")
    tab:Icon("\u{f0eb}")
    local extra = Menu.Create("General", "Dynamic Island", "Dynamic Island Extra")
    extra:Icon("\u{f1de}")

    local pMain = tab:Create(L("di_tab_general"))
    local gIsland = pMain:Create("di_group_island", Enum.GroupSide.Left)
    local gLook = pMain:Create("di_group_look", Enum.GroupSide.Right)
    local lookLabel = gLook:Label("di_look_customize", "\u{f1fc}")
    local gLookGear = lookLabel:Gear("di_gear_look")
    local pAlerts = tab:Create(L("di_tab_alerts"))
    local gAll = pAlerts:Create("di_group_alerts_all", Enum.GroupSide.FullWidth)
    local gCombat = pAlerts:Create("di_group_combat_alerts", Enum.GroupSide.Left)
    local gMap = pAlerts:Create("di_group_map_alerts", Enum.GroupSide.Right)
    local gSystem = pAlerts:Create("di_group_system", Enum.GroupSide.Right)
    local gLive = pAlerts:Create("di_group_live", Enum.GroupSide.Left)
    Sdk.InitMenu(pAlerts)
    local pMedia = tab:Create(L("di_tab_media"))
    local gMedia = pMedia:Create("di_group_media", Enum.GroupSide.Left)

    local pFocus = extra:Create(L("di_tab_focus"))
    local gFocus = pFocus:Create("di_tab_focus_group", Enum.GroupSide.Left)
    local gRem = pFocus:Create("di_tab_reminders_group", Enum.GroupSide.Right)
    local pHaptics = extra:Create(L("di_tab_haptics"))
    local gHaptics = pHaptics:Create("di_group_haptics", Enum.GroupSide.Left)
    local gDuck = pHaptics:Create("di_group_ducking", Enum.GroupSide.Right)
    local pAccess = extra:Create(L("di_tab_access"))
    local gAccess = pAccess:Create("di_group_access", Enum.GroupSide.Left)
    local pDiag = extra:Create(L("di_tab_diag"))
    local gDiag = pDiag:Create("di_group_diag", Enum.GroupSide.Left)
    local snap = gDiag:Button("di_diag_snapshot", function() Dbg.Snapshot() end)
    snap:ToolTip("di_diag_snapshot_tip")

    UI = { Main = {}, Media = {}, Combat = {}, Runes = {}, Timings = {}, Haptics = {}, Priority = {}, Durations = {}, Sounds = {}, Focus = {}, Reminders = {}, System = {}, Access = {} }
    local M, Md, C, R, T, H, P, D = UI.Main, UI.Media, UI.Combat, UI.Runes, UI.Timings, UI.Haptics, UI.Priority, UI.Durations
    UI.Access.Motion = gAccess:Switch("di_access_motion", false, "\u{f021}")
    UI.Access.Motion:ToolTip("di_access_motion_tip")
    UI.Access.Bold = gAccess:Switch("di_access_bold", false, "\u{f032}")
    UI.Access.Bold:ToolTip("di_access_bold_tip")
    UI.Access.Contrast = gAccess:Switch("di_access_contrast", false, "\u{f042}")
    UI.Access.Contrast:ToolTip("di_access_contrast_tip")

    local function prio(gear, key, def)
        local w = gear:Slider(key, 1, 5, def, "%d")
        w:Icon("\u{f160}")
        w:ToolTip("di_alert_priority_tip")
        return w
    end
    local function durFmt(v)
        if v == 0 then return L("di_dur_default") end
        return string.format("%d s", v)
    end
    local function dur(gear, key)
        local w = gear:Slider(key or "di_alert_duration", 0, 10, 0, durFmt)
        w:Icon("\u{f254}")
        w:ToolTip("di_alert_duration_tip")
        return w
    end
    local function snd(gear, key)
        local w = gear:Switch("di_alert_sound", true, "\u{f028}")
        w:ToolTip("di_alert_sound_tip")
        UI.Sounds[key] = w
    end
    local function lead(gear, key, lo, hi, def)
        local w = gear:Slider(key, lo, hi, def, "%d s")
        w:Icon("\u{f017}")
        w:ToolTip("di_lead_tip")
        return w
    end

    M.Enabled = gIsland:Switch("di_main_enabled", true, "\u{f0eb}")
    M.Enabled:ToolTip("di_main_enabled_tip")
    local gMore = M.Enabled:Gear("di_gear_more")
    M.OnlyInGame = gMore:Switch("di_main_only_in_game", false, "\u{f108}")
    M.OnlyInGame:ToolTip("di_main_only_in_game_tip")
    M.ExpandMode = gMore:Combo("di_main_expand", { "di_main_expand_hover", "di_main_expand_hold" }, 0)
    M.ExpandMode:Icon("\u{f065}")
    M.ExpandMode:ToolTip("di_main_expand_tip")
    M.Demo = gMore:Button("di_main_demo", function() Demo.Start() end)
    M.Demo:ToolTip("di_main_demo_tip")
    M.Hello = gMore:Switch("di_main_hello", true, "\u{f256}")
    M.Hello:ToolTip("di_main_hello_tip")
    M.SetupAgain = gMore:Button("di_main_setup", function()
        if not (Engine.IsInGame and Engine.IsInGame()) then Hello.Start(true) end
    end)
    M.SetupAgain:ToolTip("di_main_setup_tip")
    M.SdkReset = gMore:Button("di_main_sdk_reset", function() Sdk.Reset() end)
    M.SdkReset:ToolTip("di_main_sdk_reset_tip")
    M.Debug = gMore:Switch("di_main_debug", false, "\u{f188}")
    M.Debug:ToolTip("di_main_debug_tip")
    M.Debug:SetCallback(function(w)
        if w:Get() then Dbg.Start("switched on") else Dbg.Stop() end
    end)
    M.DebugOpen = gMore:Button("di_main_debug_open", function() Dbg.Reveal() end)
    M.DebugOpen:ToolTip("di_main_debug_open_tip")
    T.ToastDuration = gAll:Slider("di_timings_toast_duration", 1, 10, 4, "%d s")
    T.ToastDuration:Icon("\u{f254}")
    T.ToastDuration:ToolTip("di_toast_duration_tip")
    H.AlertSounds = gAll:Switch("di_alert_sounds", true, "\u{f0f3}")
    H.AlertSounds:ToolTip("di_alert_sounds_tip")
    H.AlertVolume = H.AlertSounds:Gear("di_gear_audio"):Slider("di_alert_volume", 0, 100, 50, "%d%%")
    H.AlertVolume:ToolTip("di_alert_volume_tip")
    M.CustomLabel = gMore:Input("di_main_custom_label", "", "\u{f02b}")
    M.CustomLabel:ToolTip("di_main_custom_label_tip")
    M.ResetPos = gMore:Button("di_main_reset_pos", function()
        DragState.CustomX = -1
        DragState.CustomY = -1
        UI.Main.Preset:Set(0)
        UI.Main.OffsetY:Set(20)
        UI.Main.OffsetX:Set(0)
        SaveAllConfig()
    end)
    M.ResetPos:ToolTip("di_main_reset_pos_tip")
    M.ExportCfg = gMore:Button("di_media_export_cfg", function()
        SaveAllConfig()
    end)
    M.ExportCfg:ToolTip("di_media_export_cfg_tip")
    M.ImportCfg = gMore:Button("di_media_import_cfg", function()
        Impl.LoadAllConfig()
    end)
    M.ImportCfg:ToolTip("di_media_import_cfg_tip")

    M.Preset = gIsland:Combo("di_main_preset", { "di_preset_top_center", "di_preset_custom", "di_preset_top_left", "di_preset_top_right", "di_preset_screen_center", "di_preset_bottom_center" }, 0)
    M.Preset:ToolTip("di_main_preset_tip")
    M.Preset:Icon("\u{f3c5}")
    local gPos = M.Preset:Gear("di_gear_position")
    M.OffsetY = gPos:Slider("di_main_offset_y", 0, 1000, 20, "%d px")
    M.OffsetY:ToolTip("di_main_offset_y_tip")
    M.OffsetY:Icon("\u{f338}")
    M.OffsetX = gPos:Slider("di_main_offset_x", -960, 960, 0, "%d px")
    M.OffsetX:ToolTip("di_main_offset_x_tip")
    M.OffsetX:Icon("\u{f337}")
    M.Scale = gPos:Slider("di_main_scale", 60, 180, 100, "%d%%")
    M.Scale:ToolTip("di_main_scale_tip")
    M.Scale:Icon("\u{f065}")

    M.ToggleHUDMode = gLook:Button("di_main_widget_editor", function()
        HUDCustomizer.IsOpen = not HUDCustomizer.IsOpen
        HUDCustomizer.InspectedChip = nil
        HUDCustomizer.ColorPickerOpen = false
    end)
    M.ToggleHUDMode:ToolTip("di_main_widget_editor_tip")

    M.PureGlass = gLookGear:Switch("di_main_pure_glass", false, "\u{f06e}")
    M.PureGlass:ToolTip("di_main_pure_glass_tip")
    Md.Blur = gLookGear:Switch("di_media_blur", true, "\u{f042}")
    Md.Blur:ToolTip("di_media_blur_tip")
    Md.Shadow = gLookGear:Switch("di_media_shadow", true, "\u{f0c8}")
    Md.Shadow:ToolTip("di_media_shadow_tip")
    M.IslandBgColor = gLookGear:ColorPicker("di_main_bg_color", Color(0, 0, 0, 245), "\u{f53f}")
    M.IslandBgColor:ToolTip("di_main_bg_color_tip")
    M.BgOpacity = gLookGear:Slider("di_main_bg_opacity", 0, 100, 100, "%d%%")
    M.BgOpacity:Icon("\u{f042}")
    M.BgOpacity:ToolTip("di_main_bg_opacity_tip")
    Md.AccentColor = gLookGear:ColorPicker("di_media_accent_color", Config.Colors.Accent, "\u{f53f}")
    Md.AccentColor:ToolTip("di_media_accent_color_tip")
    Md.ArtworkTint = gLookGear:Switch("di_media_artwork_tint", true, "\u{f1fc}")
    Md.ArtworkTint:ToolTip("di_media_artwork_tint_tip")
    M.BorderThickness = gLookGear:Slider("di_main_border_thickness", 0.0, 3.0, 1.0, "%.1f px")
    M.BorderThickness:ToolTip("di_main_border_thickness_tip")
    M.BorderThickness:Icon("\u{f065}")

    C.FightHUD = gLive:Switch("di_combat_fight_hud", true, "\u{f140}")
    C.FightHUD:ToolTip("di_combat_fight_hud_tip")
    local gRadar = C.FightHUD:Gear("di_gear_radar")
    C.FightScope = gRadar:Combo("di_combat_fight_scope", { "di_combat_scope_local", "di_combat_scope_any" }, 0)
    C.FightScope:ToolTip("di_combat_fight_scope_tip")
    C.FightScope:Icon("\u{f05b}")
    C.MinHeroes = gRadar:Slider("di_combat_min_heroes", 1, 10, 2, "%d")
    C.MinHeroes:ToolTip("di_combat_min_heroes_tip")
    C.MinHeroes:Icon("\u{f0c0}")
    C.FightRadius = gRadar:Slider("di_combat_fight_radius", 1000, 3000, 1600, "%d px")
    C.FightRadius:ToolTip("di_combat_fight_radius_tip")
    C.FightRadius:Icon("\u{f1ce}")
    C.RadarZoom = gRadar:Slider("di_combat_radar_zoom", 1000, 3500, 2000, "%d px")
    C.RadarZoom:ToolTip("di_combat_radar_zoom_tip")
    C.RadarZoom:Icon("\u{f00e}")
    C.FightTimeout = gRadar:Slider("di_combat_fight_timeout", 2, 10, 4, "%d s")
    C.FightTimeout:ToolTip("di_combat_fight_timeout_tip")
    C.FightTimeout:Icon("\u{f017}")
    C.FightLargeW = gRadar:Slider("di_combat_fight_large_w", 300, 520, 365, "%d px")
    C.FightLargeW:ToolTip("di_combat_fight_large_w_tip")
    C.FightLargeW:Icon("\u{f337}")
    C.FightLargeH = gRadar:Slider("di_combat_fight_large_h", 110, 220, 148, "%d px")
    C.FightLargeH:ToolTip("di_combat_fight_large_h_tip")
    C.FightLargeH:Icon("\u{f338}")
    P.FightSummary = prio(gRadar, "di_priority_fight_summary", 3)
    D.FightSummary = dur(gRadar)
    snd(gRadar, "FightSummary")

    C.Kills = gCombat:Switch("di_combat_kills", true, "\u{f0e7}")
    C.Kills:ToolTip("di_combat_kills_tip")
    local gKill = C.Kills:Gear("di_gear_alert")
    P.Kill = prio(gKill, "di_alert_priority", 3)
    D.Kill = dur(gKill)
    snd(gKill, "Kill")
    C.RampageTimer = gKill:Switch("di_rampage_timer", true, "\u{f2f2}")
    C.RampageTimer:ToolTip("di_rampage_timer_tip")
    C.Invis = gCombat:Switch("di_combat_invis", true, "\u{f070}")
    C.Invis:ToolTip("di_combat_invis_tip")
    local gInvis = C.Invis:Gear("di_gear_alert")
    P.Invis = prio(gInvis, "di_alert_priority", 4)
    D.Invis = dur(gInvis)
    snd(gInvis, "Invis")
    C.Teleports = gCombat:Switch("di_combat_teleports", true, "\u{f3c5}")
    C.Teleports:ToolTip("di_combat_teleports_tip")
    local gTeleport = C.Teleports:Gear("di_gear_alert")
    P.Teleport = prio(gTeleport, "di_alert_priority", 4)
    D.Teleport = dur(gTeleport)
    snd(gTeleport, "Teleport")
    C.KeyEnemyItems = gCombat:Switch("di_combat_key_enemy_items", true, "\u{f290}")
    C.KeyEnemyItems:ToolTip("di_combat_key_enemy_items_tip")
    local gEnemyItem = C.KeyEnemyItems:Gear("di_gear_alert")
    P.EnemyItem = prio(gEnemyItem, "di_alert_priority", 3)
    D.EnemyItem = dur(gEnemyItem)
    snd(gEnemyItem, "EnemyItem")
    C.Towers = gCombat:Switch("di_combat_towers", true, "\u{f447}")
    C.Towers:ToolTip("di_combat_towers_tip")
    local gTower = C.Towers:Gear("di_gear_alert")
    P.Tower = prio(gTower, "di_alert_priority", 4)
    D.Tower = dur(gTower)
    snd(gTower, "Tower")
    C.Couriers = gCombat:Switch("di_combat_couriers", true, "\u{f48b}")
    C.Couriers:ToolTip("di_combat_couriers_tip")
    local gCourier = C.Couriers:Gear("di_gear_alert")
    P.Courier = prio(gCourier, "di_alert_priority", 3)
    D.Courier = dur(gCourier)
    snd(gCourier, "Courier")
    C.Buybacks = gCombat:Switch("di_combat_buybacks", true, "\u{f2f9}")
    C.Buybacks:ToolTip("di_combat_buybacks_tip")
    local gBuyback = C.Buybacks:Gear("di_gear_alert")
    P.Buyback = prio(gBuyback, "di_alert_priority", 5)
    D.Buyback = dur(gBuyback)
    snd(gBuyback, "Buyback")
    C.LowHP = gCombat:Switch("di_combat_low_hp", true, "\u{f004}")
    C.LowHP:ToolTip("di_combat_low_hp_tip")
    local gLowHp = C.LowHP:Gear("di_gear_alert")
    P.LowHp = prio(gLowHp, "di_alert_priority", 5)
    D.LowHp = dur(gLowHp)
    snd(gLowHp, "LowHp")
    C.LevelUp = gCombat:Switch("di_combat_level_up", true, "\u{f201}")
    C.LevelUp:ToolTip("di_combat_level_up_tip")
    local gLevel = C.LevelUp:Gear("di_gear_alert")
    P.Level = prio(gLevel, "di_alert_priority", 1)
    D.Level = dur(gLevel)
    snd(gLevel, "Level")
    C.CourierDelivery = gLive:Switch("di_combat_courier_delivery", true, "\u{f48b}")
    C.CourierDelivery:ToolTip("di_combat_courier_delivery_tip")
    C.CourierFaceID = gLive:Switch("di_courier_faceid", true, "\u{f118}")
    C.CourierFaceID:ToolTip("di_courier_faceid_tip")
    C.CourierSound = C.CourierDelivery:Gear("di_gear_alert"):Switch("di_courier_sound", true, "\u{f028}")
    C.CourierSound:ToolTip("di_courier_sound_tip")
    C.PauseAlert = gLive:Switch("di_combat_pause_alert", true, "\u{f04c}")
    C.PauseAlert:ToolTip("di_combat_pause_alert_tip")
    C.MatchFound = gLive:Switch("di_match_alert", true, "\u{f11b}")
    C.MatchFound:ToolTip("di_match_alert_tip")
    local gMatch = C.MatchFound:Gear("di_gear_alert")
    P.MatchFound = prio(gMatch, "di_alert_priority", 4)
    snd(gMatch, "MatchFound")
    C.MatchFaceID = gMatch:Switch("di_match_faceid", true, "\u{f118}")
    C.MatchFaceID:ToolTip("di_match_faceid_tip")
    UI.System.Output = gSystem:Switch("di_sys_output", true, "\u{f025}")
    UI.System.Output:ToolTip("di_sys_output_tip")
    UI.System.Mute = gSystem:Switch("di_sys_mute", true, "\u{f6a9}")
    UI.System.Mute:ToolTip("di_sys_mute_tip")
    UI.System.Battery = gSystem:Switch("di_sys_battery", true, "\u{f240}")
    UI.System.Battery:ToolTip("di_sys_battery_tip")

    R.ActiveRunes = gMap:Switch("di_runes_active_runes", true, "\u{f0e7}")
    R.ActiveRunes:ToolTip("di_runes_active_runes_tip")
    local gPower = R.ActiveRunes:Gear("di_gear_alert")
    T.PowerRuneTime = lead(gPower, "di_timings_power_rune_time", 5, 60, 20)
    P.PowerRuneCycle = prio(gPower, "di_priority_power_rune_cycle", 2)
    D.Rune = dur(gPower)
    snd(gPower, "Rune")
    R.WaterRunes = gMap:Switch("di_runes_water_runes", true, "\u{f043}")
    R.WaterRunes:ToolTip("di_runes_water_runes_tip")
    local gWaterRunes = R.WaterRunes:Gear("di_gear_alert")
    T.WaterRuneTime = lead(gWaterRunes, "di_timings_water_rune_time", 5, 60, 20)
    P.WaterRunes = prio(gWaterRunes, "di_alert_priority", 2)
    D.WaterRunes = dur(gWaterRunes)
    snd(gWaterRunes, "WaterRunes")
    R.BountyRunes = gMap:Switch("di_runes_bounty_runes", true, "\u{f155}")
    R.BountyRunes:ToolTip("di_runes_bounty_runes_tip")
    local gBountyRunes = R.BountyRunes:Gear("di_gear_alert")
    T.BountyRuneTime = lead(gBountyRunes, "di_timings_bounty_rune_time", 5, 45, 10)
    P.BountyRunes = prio(gBountyRunes, "di_alert_priority", 2)
    D.BountyRunes = dur(gBountyRunes)
    snd(gBountyRunes, "BountyRunes")
    R.WisdomRunes = gMap:Switch("di_runes_wisdom_runes", true, "\u{f19d}")
    R.WisdomRunes:ToolTip("di_runes_wisdom_runes_tip")
    local gWisdomRunes = R.WisdomRunes:Gear("di_gear_alert")
    T.WisdomRuneTime = lead(gWisdomRunes, "di_timings_wisdom_rune_time", 5, 60, 20)
    P.WisdomRunes = prio(gWisdomRunes, "di_alert_priority", 2)
    D.WisdomRunes = dur(gWisdomRunes)
    snd(gWisdomRunes, "WisdomRunes")
    R.RunePickups = gMap:Switch("di_runes_rune_pickups", true, "\u{f21b}")
    R.RunePickups:ToolTip("di_runes_rune_pickups_tip")
    local gRunePickup = R.RunePickups:Gear("di_gear_alert")
    P.RunePickup = prio(gRunePickup, "di_alert_priority", 2)
    D.RunePickup = dur(gRunePickup)
    snd(gRunePickup, "RunePickup")
    R.RuneWorldSpawn = gMap:Switch("di_runes_rune_world_spawn", true, "\u{f279}")
    R.RuneWorldSpawn:ToolTip("di_runes_rune_world_spawn_tip")
    local gRuneWorld = R.RuneWorldSpawn:Gear("di_gear_alert")
    P.RuneWorld = prio(gRuneWorld, "di_alert_priority", 2)
    D.RuneWorld = dur(gRuneWorld)
    snd(gRuneWorld, "RuneWorld")
    R.Stacks = gMap:Switch("di_runes_stacks", false, "\u{f5fd}")
    R.Stacks:ToolTip("di_runes_stacks_tip")
    local gStack = R.Stacks:Gear("di_gear_alert")
    T.StackTime = lead(gStack, "di_timings_stack_time", 3, 20, 8)
    T.StackUntil = gStack:Slider("di_timings_stack_until", 0, 60, 0, function(v)
        if v == 0 then return L("di_stack_until_always") end
        return string.format(L("di_stack_until_min"), v)
    end)
    T.StackUntil:Icon("\u{f2f2}")
    T.StackUntil:ToolTip("di_timings_stack_until_tip")
    P.Stack = prio(gStack, "di_alert_priority", 2)
    D.Stack = dur(gStack)
    snd(gStack, "Stack")
    R.Lotus = gMap:Switch("di_runes_lotus", true, "\u{f06c}")
    R.Lotus:ToolTip("di_runes_lotus_tip")
    local gLotus = R.Lotus:Gear("di_gear_alert")
    T.LotusTime = lead(gLotus, "di_timings_lotus_time", 5, 60, 20)
    P.Lotus = prio(gLotus, "di_alert_priority", 2)
    D.Lotus = dur(gLotus)
    snd(gLotus, "Lotus")
    R.Neutrals = gMap:Switch("di_runes_neutrals", true, "\u{f466}")
    R.Neutrals:ToolTip("di_runes_neutrals_tip")
    local gNeutral = R.Neutrals:Gear("di_gear_alert")
    P.Neutral = prio(gNeutral, "di_alert_priority", 2)
    D.Neutral = dur(gNeutral)
    snd(gNeutral, "Neutral")
    R.Tormentor = gMap:Switch("di_runes_tormentor", true, "\u{f005}")
    R.Tormentor:ToolTip("di_runes_tormentor_tip")
    local gTorm = R.Tormentor:Gear("di_gear_alert")
    T.Tormentor1Time = lead(gTorm, "di_timings_tormentor1_time", 30, 180, 120)
    T.Tormentor2Time = lead(gTorm, "di_timings_tormentor2_time", 5, 60, 20)
    P.Tormentor = prio(gTorm, "di_alert_priority", 3)
    D.Tormentor = dur(gTorm)
    snd(gTorm, "Tormentor")
    R.Roshan = gMap:Switch("di_runes_roshan", true, "\u{f6e3}")
    R.Roshan:ToolTip("di_runes_roshan_tip")
    local gRosh = R.Roshan:Gear("di_gear_alert")
    P.RoshanKill = prio(gRosh, "di_priority_roshan_kill", 5)
    P.Aegis = prio(gRosh, "di_priority_aegis", 5)
    P.RoshanAttack = prio(gRosh, "di_priority_roshan_attack", 4)
    D.Roshan = dur(gRosh)
    snd(gRosh, "Roshan")

    Md.Enabled = gMedia:Switch("di_media_enabled", true, "\u{f001}")
    Md.Enabled:ToolTip("di_media_enabled_tip")
    local gPlayer = Md.Enabled:Gear("di_gear_media")
    P.Media = gPlayer:Slider("di_alert_priority", 1, 5, 5, "%d")
    P.Media:Icon("\u{f160}")
    P.Media:ToolTip("di_media_priority_tip")
    Md.CompactTitle = gPlayer:Switch("di_media_compact_title", true, "\u{f031}")
    Md.CompactTitle:ToolTip("di_media_compact_title_tip")
    Md.CenterShortTitle = gPlayer:Switch("di_media_center_short_title", false, "\u{f036}")
    Md.CenterShortTitle:ToolTip("di_media_center_short_title_tip")
    Md.ShowArtist = gPlayer:Switch("di_media_show_artist", true, "\u{f007}")
    Md.ShowArtist:ToolTip("di_media_show_artist_tip")
    Md.MarqueeSpeed = gPlayer:Slider("di_media_marquee_speed", 20, 100, 45, "%d px/s")
    Md.MarqueeSpeed:ToolTip("di_media_marquee_speed_tip")
    Md.MarqueeSpeed:Icon("\u{f337}")
    Md.SpotifyLike = gMedia:Switch("di_media_spotify_like", true, "\u{f004}")
    Md.SpotifyLike:ToolTip("di_media_spotify_like_tip")
    Md.Playlist = gMedia:Switch("di_playlist_title", false, "\u{f067}")
    Md.Playlist:ToolTip("di_playlist_tip")
    local gSpotifyLike = Md.SpotifyLike:Gear("di_gear_alert")
    P.SpotifyLike = prio(gSpotifyLike, "di_alert_priority", 1)
    D.SpotifyLike = dur(gSpotifyLike)
    snd(gSpotifyLike, "SpotifyLike")
    Md.VolumeWheel = gMedia:Switch("di_media_volume_wheel", true, "\u{f028}")
    Md.VolumeWheel:ToolTip("di_media_volume_wheel_tip")
    Md.Lyrics = gMedia:Switch("di_media_lyrics", true, "\u{f10d}")
    Md.Lyrics:ToolTip("di_media_lyrics_tip")
    local gLyrics = Md.Lyrics:Gear("di_gear_lyrics")
    Md.LyricsCompact = gLyrics:Switch("di_media_lyrics_compact", false, "\u{f036}")
    Md.LyricsCompact:ToolTip("di_media_lyrics_compact_tip")
    Md.SecondaryBubble = gMedia:Switch("di_media_secondary_bubble", true, "\u{f111}")
    Md.SecondaryBubble:ToolTip("di_media_secondary_bubble_tip")
    Md.InMenu = gMedia:Switch("di_media_in_menu", true, "\u{f015}")
    Md.InMenu:ToolTip("di_media_in_menu_tip")
    Md.Hints = gMedia:Switch("di_media_hints", true, "\u{f05a}")
    Md.Hints:ToolTip("di_media_hints_tip")

    H.Enabled = gHaptics:Switch("di_haptics_enabled", true, "\u{f011}")
    H.Enabled:ToolTip("di_haptics_enabled_tip")
    H.VisualFeedback = gHaptics:Switch("di_haptics_visual", true, "\u{f06e}")
    H.VisualFeedback:ToolTip("di_haptics_visual_tip")
    H.Intensity = H.VisualFeedback:Gear("di_gear_visual"):Slider("di_haptics_intensity", 50, 150, 100, "%d%%")
    H.Intensity:ToolTip("di_haptics_intensity_tip")
    H.Intensity:Icon("\u{f065}")
    H.AudioFeedback = gHaptics:Switch("di_haptics_audio", true, "\u{f028}")
    H.AudioFeedback:ToolTip("di_haptics_audio_tip")
    H.Volume = H.AudioFeedback:Gear("di_gear_audio"):Slider("di_haptics_volume", 0, 100, 50, "%d%%")
    H.Volume:ToolTip("di_haptics_volume_tip")
    H.Volume:Icon("\u{f028}")
    H.CombatFilter = gHaptics:Switch("di_haptics_combat_filter", true, "\u{f0e7}")
    H.CombatFilter:ToolTip("di_haptics_combat_filter_tip")
    H.AudioDucking = gDuck:Switch("di_haptics_audio_ducking", true, "\u{f026}")
    H.AudioDucking:ToolTip("di_haptics_audio_ducking_tip")
    local gDuckGear = H.AudioDucking:Gear("di_gear_ducking")
    H.DuckingAmount = gDuckGear:Slider("di_haptics_ducking_amount", 0, 100, 50, "%d%%")
    H.DuckingAmount:ToolTip("di_haptics_ducking_amount_tip")
    H.DuckingAmount:Icon("\u{f027}")
    H.DuckingAlerts = gDuckGear:Switch("di_haptics_ducking_alerts", true, "\u{f0f3}")
    H.DuckingAlerts:ToolTip("di_haptics_ducking_alerts_tip")
    H.DuckingCourier = gDuckGear:Switch("di_haptics_ducking_courier", true, "\u{f48b}")
    H.DuckingCourier:ToolTip("di_haptics_ducking_courier_tip")
    H.DuckingNotifs = gDuckGear:Switch("di_haptics_ducking_notifs", true, "\u{f05a}")
    H.DuckingNotifs:ToolTip("di_haptics_ducking_notifs_tip")
    H.DuckingMotion = gDuckGear:Switch("di_haptics_ducking_motion", false, "\u{f065}")
    H.DuckingMotion:ToolTip("di_haptics_ducking_motion_tip")
    H.DuckingTaptics = gDuckGear:Switch("di_haptics_ducking_taptics", false, "\u{f0a7}")
    H.DuckingTaptics:ToolTip("di_haptics_ducking_taptics_tip")
    H.TestDucking = gDuckGear:Button("di_haptics_test_ducking", function()
        if HTTP and HTTP.Request then
            local userVol = (UI and UI.Haptics and UI.Haptics.Volume) and (UI.Haptics.Volume:Get() / 100.0) or 0.5
            local baseDuckPct = (UI and UI.Haptics and UI.Haptics.DuckingAmount and UI.Haptics.DuckingAmount:Get() or 50) / 100.0
            local finalDuck = string.format("%.2f", baseDuckPct)
            pcall(Impl.HttpRequest, "GET", "http://127.0.0.1:45455/sound?name=courier_delivered&vol=" .. string.format("%.2f", userVol) .. "&force=1&duck=" .. finalDuck, {}, function() end)
        end
    end)
    H.TestDucking:ToolTip("di_haptics_test_ducking_tip")

    UI.Focus.Key = gFocus:Bind("di_focus_key", Enum.ButtonCode.KEY_NONE, "\u{f186}")
    UI.Focus.Key:ToolTip("di_focus_key_tip")
    UI.Focus.Key:Properties(L("di_focus_name"))
    UI.Focus.Until = gFocus:Combo("di_focus_until", { "di_focus_until_off", "di_focus_until_10", "di_focus_until_20", "di_focus_until_match" }, 0)
    UI.Focus.Until:ToolTip("di_focus_until_tip")
    UI.Focus.Until:Icon("\u{f017}")
    UI.Focus.Urgent = gFocus:Switch("di_focus_urgent", true, "\u{f0f3}")
    UI.Focus.Urgent:ToolTip("di_focus_urgent_tip")
    UI.Focus.MoonTint = gFocus:Switch("di_focus_moon_tint", true, "\u{f53f}")
    UI.Focus.MoonTint:ToolTip("di_focus_moon_tint_tip")

    local RM = UI.Reminders
    for i, key in ipairs({ "di_rem_1", "di_rem_2", "di_rem_3", "di_rem_4" }) do
        local sw = gRem:Switch(key, false, "\u{f0f3}")
        sw:ToolTip("di_rem_on_tip")
        local g = sw:Gear(({ "di_rem_gear_1", "di_rem_gear_2", "di_rem_gear_3", "di_rem_gear_4" })[i])
        RM["On" .. i] = sw
        RM["Text" .. i] = g:Input(({ "di_rem1_text", "di_rem2_text", "di_rem3_text", "di_rem4_text" })[i], "", "\u{f036}")
        RM["Text" .. i]:ToolTip("di_rem_text_tip")
        RM["Min" .. i] = g:Slider(({ "di_rem1_min", "di_rem2_min", "di_rem3_min", "di_rem4_min" })[i], 0, 90, 10 * i, "%d")
        RM["Min" .. i]:Icon("\u{f017}")
        RM["Min" .. i]:ToolTip("di_rem_time_tip")
        RM["Sec" .. i] = g:Slider(({ "di_rem1_sec", "di_rem2_sec", "di_rem3_sec", "di_rem4_sec" })[i], 0, 59, 0, "%d")
        RM["Sec" .. i]:Icon("\u{f017}")
        RM["Sec" .. i]:ToolTip("di_rem_time_tip")
        RM["Every" .. i] = g:Slider(({ "di_rem1_every", "di_rem2_every", "di_rem3_every", "di_rem4_every" })[i], 0, 30, 0, "%d")
        RM["Every" .. i]:Icon("\u{f01e}")
        RM["Every" .. i]:ToolTip("di_rem_every_tip")
    end
    P.Reminder = prio(gRem, "di_priority_reminder", 4)
    D.Reminder = dur(gRem, "di_reminder_duration")
    snd(gRem, "Reminder")

    local function refreshDisabled()
        local hOn = H.Enabled:Get()
        H.VisualFeedback:Disabled(not hOn)
        H.AudioFeedback:Disabled(not hOn)
        H.CombatFilter:Disabled(not hOn)
        H.AudioDucking:Disabled(not hOn)
        local mOn = Md.Enabled:Get()
        Md.SpotifyLike:Disabled(not mOn)
        Md.Playlist:Disabled(not mOn)
        Md.ShowArtist:Disabled(not mOn)
        Md.CenterShortTitle:Disabled(not mOn)
        Md.VolumeWheel:Disabled(not mOn)
        Md.Lyrics:Disabled(not mOn)
        Md.SecondaryBubble:Disabled(not mOn)
        M.BgOpacity:Disabled(M.PureGlass:Get())
    end
    H.Enabled:SetCallback(refreshDisabled, true)
    Md.Enabled:SetCallback(refreshDisabled)
    M.PureGlass:SetCallback(refreshDisabled)

    Md.AccentColor:SetCallback(function(w)
        local c = w:Get()
        if c then Config.Colors.Accent = c end
    end, true)
end

function StateMachine.SharedKind(a, b)
    local S = StateMachine.States
    if (a == S.COMPACT_MEDIA and b == S.LARGE_MEDIA) or (a == S.LARGE_MEDIA and b == S.COMPACT_MEDIA) then return "media" end
    if (a == S.COMPACT_IDLE and b == S.LARGE_IDLE) or (a == S.LARGE_IDLE and b == S.COMPACT_IDLE) then return "idle" end
    return nil
end

function StateMachine.FrameFor(layout, w, h, r)
    local s = layout.scale
    local W = math.floor(w * s + 0.5)
    local H = math.floor(h * s + 0.5)
    if W % 2 ~= 0 then W = W + 1 end
    if H % 2 ~= 0 then H = H + 1 end
    return { x = math.floor(layout.x + layout.w / 2 - W / 2 + 0.5), y = layout.y, w = W, h = H, r = math.floor(math.min(H / 2, (r or h / 2) * s) + 0.5), scale = s }
end

function StateMachine.SharedM(kind)
    local D = Config.Dimensions
    local lo, hi = D.CompactH, D.LargeH
    if kind == "media" then lo, hi = D.CompactMediaH, D.LargeMediaH + (Impl.LyWant() and Impl.LyH or 0) end
    local m = (StateMachine.Spring.H.value - lo) / math.max(1, hi - lo)
    if m < 0.004 then return 0 end
    if m > 0.996 then return 1 end
    return m
end

local function TriggerStateTransition(nextState)
    if StateMachine.TargetState == nextState then return end
    if nextState == StateMachine.States.NOTIFICATION and Impl.FaceLive and Impl.FaceLive() then return end

    local fromLarge = (StateMachine.TargetState == StateMachine.States.LARGE_IDLE or StateMachine.TargetState == StateMachine.States.LARGE_MEDIA or StateMachine.TargetState == StateMachine.States.LARGE_FIGHT or StateMachine.TargetState == StateMachine.States.COURIER_LARGE or StateMachine.TargetState == StateMachine.States.SHEET or StateMachine.TargetState == StateMachine.States.NOTIF_CENTER or StateMachine.TargetState == StateMachine.States.ACTIVITY_LARGE)
    local toLarge = (nextState == StateMachine.States.LARGE_IDLE or nextState == StateMachine.States.LARGE_MEDIA or nextState == StateMachine.States.LARGE_FIGHT or nextState == StateMachine.States.COURIER_LARGE or nextState == StateMachine.States.SHEET or nextState == StateMachine.States.NOTIF_CENTER or nextState == StateMachine.States.ACTIVITY_LARGE)

    local tr = StateMachine.Transition
    local prev = StateMachine.TargetState
    local shared = StateMachine.SharedKind(prev, nextState)
    local ghosts = StateMachine.Ghosts
    local quick = tr.Active and not tr.SharedPair and not shared and (os.clock() - tr.StartTime) < 0.25 * AnimScale() and (tr.Reveal or 0) < 0.6
    if quick then
        StateMachine.PreviousState = prev
        StateMachine.TargetState = nextState
        StateMachine.StateStartTime = os.clock()
        tr.ToState = nextState
        tr.Dist0 = nil
        tr.Shrink = nil
        return
    end
    if tr.Active and tr.SharedPair then
        if shared ~= tr.SharedPair then
            table.insert(ghosts, { shared = tr.SharedPair, m = StateMachine.SharedM(tr.SharedPair), a = 1 })
        end
    elseif not shared then
        local a = tr.Active and (tr.Reveal or 0) or 1
        if a > 0.02 then
            local D = Config.Dimensions
            table.insert(ghosts, { state = prev, a = a, w = D.CompactTargetW or D.CompactW, h = D.CompactTargetH or D.CompactH, r = D.CompactTargetR or D.CompactRadius })
        end
    end
    while #ghosts > 4 do table.remove(ghosts, 1) end

    StateMachine.PreviousState = prev
    StateMachine.TargetState = nextState
    StateMachine.StateStartTime = os.clock()

    tr.Active = true
    tr.FromState = prev
    tr.ToState = nextState
    tr.StartTime = os.clock()
    tr.Progress = 0.0
    tr.Reveal = 0.0
    tr.Dist0 = nil
    tr.Shrink = nil
    tr.SharedPair = shared

    if toLarge and not fromLarge then
        MotionEngine.CurrentProfile = "BOUNCY"
        StateMachine.Spring.Squish.value = 0.3
        StateMachine.Spring.Squish.vel = 1.8
        if Haptic and Haptic.Trigger then
            Haptic.Trigger(Haptic.Types.SNAP_EXPAND)
        end
    elseif fromLarge and not toLarge then
        MotionEngine.CurrentProfile = "SMOOTH"
        StateMachine.Spring.Squish.value = -0.2
        StateMachine.Spring.Squish.vel = -1.2
        if Haptic and Haptic.Trigger then
            Haptic.Trigger(Haptic.Types.SNAP_COLLAPSE)
        end
    elseif nextState == StateMachine.States.NOTIFICATION then
        MotionEngine.CurrentProfile = "BOUNCY"
        StateMachine.Spring.Squish.value = 0.2
        StateMachine.Spring.Squish.vel = 1.2
        Haptic.Silent(Haptic.Types.TAP_MEDIUM)
    else
        MotionEngine.CurrentProfile = "SMOOTH"
        StateMachine.Spring.Squish.value = 0.0
        StateMachine.Spring.Squish.vel = 0.0
        if Haptic and Haptic.Trigger then
            Haptic.Trigger(Haptic.Types.TAP_LIGHT)
        end
    end

    tr.SqueezeUntil = nil
    if not toLarge and not fromLarge and not shared and prev ~= nextState and not MotionEngine.Reduce then
        tr.SqueezeW = math.max(70, StateMachine.Spring.W.value * 0.58)
        tr.SqueezeUntil = os.clock() + 0.12 * AnimScale()
        MotionEngine.CurrentProfile = "BOUNCY"
    end

    if nextState == StateMachine.States.GAME_PAUSED then
        HapticPlaySound("game_paused", 0.45)
    elseif StateMachine.PreviousState == StateMachine.States.GAME_PAUSED then
        HapticPlaySound("game_unpaused", 0.45)
    elseif nextState == StateMachine.States.MENU_MATCH_FOUND then
        if ToggleOn(UI and UI.Sounds and UI.Sounds.MatchFound) then HapticPlaySound("match_found", 0.60) end
    end
end

Impl.CleanHeroNameCache = {}
local function CleanHeroName(raw)
    if not raw or raw == "" then return L("di_ui_enemy_hero") end
    if Impl.CleanHeroNameCache[raw] then return Impl.CleanHeroNameCache[raw] end
    if Engine.GetDisplayNameByUnitName then
        local ok, dn = pcall(Engine.GetDisplayNameByUnitName, raw)
        if ok and dn and dn ~= "" then
            Impl.CleanHeroNameCache[raw] = dn
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
    Impl.CleanHeroNameCache[raw] = formatted
    return formatted
end

local function GetPlayerDisplayName(ent)
    if not ent then return L("di_ui_enemy_hero") end
    if Entity.IsHero and Entity.IsHero(ent) then
        local allPlayers = Players.GetAll()
        for _, pl in ipairs(allPlayers) do
            if Player.GetAssignedHero(pl) == ent then
                local pName = Player.GetName(pl)
                if pName and pName ~= "" then
                    return pName
                end
                break
            end
        end
    end
    return CleanHeroName(NPC.GetUnitName(ent))
end

Impl.TowerNameMap = {
    ["goodguys_tower1_mid"] = "di_towers_goodguys_tower1_mid",
    ["goodguys_tower2_mid"] = "di_towers_goodguys_tower2_mid",
    ["goodguys_tower3_mid"] = "di_towers_goodguys_tower3_mid",
    ["goodguys_tower1_top"] = "di_towers_goodguys_tower1_top",
    ["goodguys_tower2_top"] = "di_towers_goodguys_tower2_top",
    ["goodguys_tower3_top"] = "di_towers_goodguys_tower3_top",
    ["goodguys_tower1_bot"] = "di_towers_goodguys_tower1_bot",
    ["goodguys_tower2_bot"] = "di_towers_goodguys_tower2_bot",
    ["goodguys_tower3_bot"] = "di_towers_goodguys_tower3_bot",
    ["badguys_tower1_mid"] = "di_towers_badguys_tower1_mid",
    ["badguys_tower2_mid"] = "di_towers_badguys_tower2_mid",
    ["badguys_tower3_mid"] = "di_towers_badguys_tower3_mid",
    ["badguys_tower1_top"] = "di_towers_badguys_tower1_top",
    ["badguys_tower2_top"] = "di_towers_badguys_tower2_top",
    ["badguys_tower3_top"] = "di_towers_badguys_tower3_top",
    ["badguys_tower1_bot"] = "di_towers_badguys_tower1_bot",
    ["badguys_tower2_bot"] = "di_towers_badguys_tower2_bot",
    ["badguys_tower3_bot"] = "di_towers_badguys_tower3_bot"
}

function Impl.GetClosestLandmark(pos)
    if not pos then return L("di_ui_lane") end

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
                    for key, entry in pairs(Impl.TowerNameMap) do
                        if string.find(rawName, key) then
                            bestTowerDist = d
                            bestTowerName = L(entry)
                            break
                        end
                    end
                end
            end
        end
        if bestTowerName then return bestTowerName end
    end

    local closestName = L("di_ui_lane")
    local closestDist = 999999999
    for _, lm in ipairs(Impl.MapLandmarks) do
        local dx = pos.x - lm.pos.x
        local dy = pos.y - lm.pos.y
        local d = dx * dx + dy * dy
        if d < closestDist then
            closestDist = d
            closestName = L(lm.name)
        end
    end
    return closestName
end

Impl.CleanItemNameCache = {}
function Impl.CleanItemName(raw)
    if not raw or raw == "" then return "" end
    if Impl.CleanItemNameCache[raw] then return Impl.CleanItemNameCache[raw] end
    if KeyItemColors[raw] then
        Impl.CleanItemNameCache[raw] = KeyItemColors[raw].name
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
    Impl.CleanItemNameCache[raw] = result
    return result
end

function Impl.GetItemSignatureColor(rawItemName)
    if not rawItemName or rawItemName == "" then return Config.Colors.Blue end
    if KeyItemColors[rawItemName] then return KeyItemColors[rawItemName].col end
    return Config.Colors.Blue
end

function Impl.GetItemTexturePath(rawItemName)
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
    return string.format("%d:%02d", m, rem)
end

local function FormatTrackTime(seconds, neg)
    local s = math.max(0, math.floor(seconds or 0))
    local h, m, rem = s // 3600, (s % 3600) // 60, s % 60
    local out = h > 0 and string.format("%d:%02d:%02d", h, m, rem) or string.format("%d:%02d", m, rem)
    return neg and ("-" .. out) or out
end

local IsNotifDeferred

Impl.NotifPriorityKey = {
    stack = "Stack",
    roshan_kill = "RoshanKill",
    aegis = "Aegis",
    buyback = "Buyback",
    low_hp = "LowHp",
    roshan_attack = "RoshanAttack",
    tower = "Tower",
    invis = "Invis",
    teleport = "Teleport",
    kill = "Kill",
    courier = "Courier",
    enemy_item = "EnemyItem",
    tormentor = "Tormentor",
    fight_summary = "FightSummary",
    rune = "Rune",
    rune_world = "RuneWorld",
    rune_pickup = "RunePickup",
    power_rune_cycle = "PowerRuneCycle",
    lotus = "Lotus",
    neutral = "Neutral",
    level = "Level",
    spotify_like = "SpotifyLike",
    reminder = "Reminder"
}

local DEFAULT_NOTIF_PRIORITY = 3

Impl.NotifDurationKey = {
    stack = "Stack",
    roshan_kill = "Roshan",
    aegis = "Roshan",
    roshan_attack = "Roshan",
    buyback = "Buyback",
    low_hp = "LowHp",
    tower = "Tower",
    invis = "Invis",
    teleport = "Teleport",
    kill = "Kill",
    courier = "Courier",
    enemy_item = "EnemyItem",
    tormentor = "Tormentor",
    fight_summary = "FightSummary",
    rune = "Rune",
    power_rune_cycle = "Rune",
    rune_world = "RuneWorld",
    rune_pickup = "RunePickup",
    lotus = "Lotus",
    neutral = "Neutral",
    level = "Level",
    spotify_like = "SpotifyLike",
    reminder = "Reminder"
}

Impl.RuneKey = { rune_water = "WaterRunes", rune_wisdom = "WisdomRunes", bounty = "BountyRunes" }

function Impl.AlertKey(n, map)
    if n.Type == "rune" and Impl.RuneKey[n.FallbackSvg] then return Impl.RuneKey[n.FallbackSvg] end
    return n.Type and map[n.Type]
end

function Impl.GetNotifPriority(notif)
    if notif.PriorityOverride then
        return notif.PriorityOverride
    end
    local key = Impl.AlertKey(notif, Impl.NotifPriorityKey)
    local widget = key and UI and UI.Priority and UI.Priority[key]
    if widget then
        return widget:Get()
    end
    return DEFAULT_NOTIF_PRIORITY
end

function Impl.PopHighestPriorityNotif()
    local list = NotificationQueue.List
    if #list == 0 then return nil end
    local bestIdx, bestPriority = 1, list[1].Priority or DEFAULT_NOTIF_PRIORITY
    for i = 2, #list do
        local p = list[i].Priority or DEFAULT_NOTIF_PRIORITY
        if p > bestPriority then
            bestIdx, bestPriority = i, p
        end
    end
    local n = table.remove(list, bestIdx)
    Impl.NotifChime(n)
    return n
end

function Impl.SoundOn(n)
    if n.SdkApp then return Sdk.Sound[n.SdkApp] ~= false end
    local key = Impl.AlertKey(n, Impl.NotifDurationKey)
    local w = key and UI and UI.Sounds and UI.Sounds[key]
    return not w or w:Get() == true
end

function Impl.NotifChime(n)
    if not n or n.Chimed or n.Silent then return end
    n.Chimed = true
    if not Impl.SoundOn(n) then return end
    HapticPlaySound(n.Chime or "notification_toast", 0.45)
end

function DynamicIsland.PushNotification(notif)
    if not notif then return end
    if notif.Type == "neutral" and UI and UI.Runes and UI.Runes.Neutrals and not UI.Runes.Neutrals:Get() then return end
    if Dbg.On then Dbg.Log("notif", "push " .. tostring(notif.Type) .. " \"" .. tostring(notif.Tag) .. " / " .. tostring(notif.Title) .. "\"") end
    NotifCenter.Add(notif)
    local shared = (UI and UI.Timings and UI.Timings.ToastDuration) and UI.Timings.ToastDuration:Get() or 4
    local durKey = Impl.AlertKey(notif, Impl.NotifDurationKey)
    if durKey then
        local dw = UI and UI.Durations and UI.Durations[durKey]
        local own = dw and dw:Get() or 0
        notif.Duration = (own > 0) and own or shared
    elseif not notif.Duration then
        notif.Duration = shared
    end
    if notif.MaxDuration then
        notif.Duration = math.min(notif.Duration, notif.MaxDuration)
    end
    notif.Priority = Impl.GetNotifPriority(notif)
    if Focus.Blocks(notif) then
        Focus.Suppressed = Focus.Suppressed + 1
        if Dbg.On then Dbg.Log("notif", "held back by focus") end
        return
    end
    if NotificationQueue.Active and notif.Priority > (NotificationQueue.Active.Priority or DEFAULT_NOTIF_PRIORITY) and not Impl.HoldQueue() then
        table.insert(NotificationQueue.List, 1, NotificationQueue.Active)
        NotificationQueue.Active = notif
        NotificationQueue.StartTime = os.clock()
        Impl.NotifChime(notif)
        if not IsNotifDeferred(notif) then
            TriggerStateTransition(StateMachine.States.NOTIFICATION)
            StateMachine.Spring.Squish.value = 1.0
            StateMachine.Spring.Squish.vel = 5.0
            Haptic.Silent(Haptic.Types.SNAP_EXPAND)
        end
    else
        table.insert(NotificationQueue.List, notif)
    end
end

function Focus.Blocks(notif)
    if not Focus.Active or notif.FocusExempt then return false end
    if notif.SdkApp and Sdk.Focus[notif.SdkApp] then return false end
    local urgent = UI and UI.Focus and UI.Focus.Urgent and UI.Focus.Urgent:Get()
    if urgent and (notif.Priority or 0) >= 5 then return false end
    return true
end

function Focus.Set(on, delay)
    if on == Focus.Active then return end
    local now = os.clock()
    Focus.Active = on
    Focus.BannerOn = on
    Focus.BannerStart = now + (delay or 0)
    Focus.BannerUntil = Focus.BannerStart + 2.2
    if on then
        Focus.StartedAt = now
        Focus.Suppressed = 0
        Focus.Mode = (UI and UI.Focus and UI.Focus.Until) and UI.Focus.Until:Get() or 0
        local d = (Focus.Mode == 1 and 600) or (Focus.Mode == 2 and 1200) or nil
        Focus.Until = d and (now + d) or 0
        HapticPlaySound("island_expand", 0.4)
    else
        Focus.Until = 0
        HapticPlaySound("island_collapse", 0.4)
        if Focus.Suppressed > 0 then
            Focus.SummaryPending = Focus.Suppressed
            Focus.Suppressed = 0
        end
    end
end

function Focus.Tick(nowClk)
    local key = UI and UI.Focus and UI.Focus.Key
    if key and key:IsPressed() and not (Input.IsInputCaptured and Input.IsInputCaptured()) then
        Focus.Set(not Focus.Active)
    end
    if Focus.Active and Focus.Until > 0 and nowClk >= Focus.Until then
        Focus.Set(false)
    end
    if Focus.SummaryPending and nowClk >= Focus.BannerUntil then
        local n = Focus.SummaryPending
        Focus.SummaryPending = nil
        DynamicIsland.PushNotification({
            Type = "focus",
            FocusExempt = true,
            PriorityOverride = 3,
            Tag = L("di_focus_summary_tag"),
            Title = string.format(L("di_focus_summary"), n),
            Subtitle = L("di_focus_summary_sub"),
            AccentColor = Focus.Accent,
            IconType = "svg",
            FallbackSvg = "moon",
            Duration = 3.0
        })
    end
end

function Reminders.Tick()
    local R = UI and UI.Reminders
    if not R then return end
    local okS, gs = pcall(GameRules.GetGameState)
    if not okS or gs ~= 5 then return end
    local mt = GetActualMatchTime()
    if not mt or mt <= 0 then return end
    for i = 1, 4 do
        if R["On" .. i]:Get() then
            local t0 = R["Min" .. i]:Get() * 60 + R["Sec" .. i]:Get()
            local every = R["Every" .. i]:Get() * 60
            if mt >= t0 then
                local k = every > 0 and math.floor((mt - t0) / every) or 0
                local target = t0 + k * every
                if mt - target < 2 and Reminders.Fired[i] ~= target then
                    Reminders.Fired[i] = target
                    local txt = R["Text" .. i]:Get()
                    if type(txt) ~= "string" or txt == "" then txt = string.format(L("di_rem_default"), i) end
                    DynamicIsland.PushNotification({
                        Type = "reminder",
                        Tag = L("di_rem_tag"),
                        Title = txt,
                        Subtitle = FormatTime(target),
                        AccentColor = Color(255, 159, 10, 255),
                        IconType = "svg",
                        FallbackSvg = "bell",
                        Duration = 4.0,
                        Chime = "timer_chime"
                    })
                end
            end
        end
    end
end

local function SendMediaCommand(cmd, onResult)
    local base = string.match(cmd, "^(%a+)") or cmd
    if Sheet.BridgeOnline and not Sheet.BridgeOnline() then
        if Dbg.On then Dbg.Log("media", base .. " not sent, the bridge is offline") end
        if onResult then onResult(false) end
        if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.ERROR) end
        return
    end
    if Dbg.On then Dbg.MediaSent(base, cmd) end
    local sentAt = os.clock()
    local port = 45455
    local url = string.format("http://127.0.0.1:%d/media/%s", port, cmd)
    pcall(Impl.HttpRequest, "GET", url, {}, function(res)
        if Dbg.On then Dbg.MediaReply(base, res, sentAt) end
        if onResult then onResult(res ~= nil and res.response ~= nil and string.find(res.response, '"status"%s*:%s*"ok"') ~= nil, res) end
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

function Impl.OpenPlaylistPicker(retry)
    if PlaylistPicker.Loading or (PlaylistPicker.Open and not retry) then return end
    PlaylistPicker.Open = true
    PlaylistPicker.Loading = true
    PlaylistPicker.Error = nil
    if not retry then
        PlaylistPicker.Items = {}
        PlaylistPicker.Selected = {}
        PlaylistPicker.Offset = 0
        PlaylistPicker.Hits = {}
        PlaylistPicker.Track = MediaData.LastTrackKey
        PlaylistPicker.Retries = 0
        PlaylistPicker.RetryAt = 0
    end
    local ok, sent = pcall(Impl.HttpRequest, "GET", "http://127.0.0.1:45455/playlist/open", {}, function(res)
        if not PlaylistPicker.Open then return end
        PlaylistPicker.Loading = false
        local body = res and res.response or ""
        if string.match(body, '"status"%s*:%s*"ok"') then
            local items = string.match(body, '"items"%s*:%s*%[(.-)%]') or ""
            for encoded in string.gmatch(items, '"([^"]+)"') do
                local name = string.gsub(encoded, "%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
                PlaylistPicker.Items[#PlaylistPicker.Items + 1] = name
            end
            local selected = string.match(body, '"selected"%s*:%s*%[(.-)%]') or ""
            for flag in string.gmatch(selected, "%a+") do
                PlaylistPicker.Selected[#PlaylistPicker.Selected + 1] = flag == "true"
            end
            if #PlaylistPicker.Items == 0 then PlaylistPicker.Error = L("di_playlist_empty") end
        else
            local reason = string.match(body, '"status"%s*:%s*"([^"]+)"') or "no_answer"
            if Dbg.On then Dbg.Log("playlist", "open: " .. reason) end
            if reason == "no_list" and PlaylistPicker.Retries < 2 then
                PlaylistPicker.Retries = PlaylistPicker.Retries + 1
                PlaylistPicker.Loading = true
                PlaylistPicker.RetryAt = os.clock() + 1.2
                if Dbg.On then Dbg.Log("playlist", "retry no_list " .. tostring(PlaylistPicker.Retries)) end
            else
                PlaylistPicker.Error = reason .. ": " .. L("di_playlist_failed")
            end
        end
    end, "playlist_open")
    if not ok or sent == false then
        PlaylistPicker.Loading = false
        PlaylistPicker.Error = L("di_playlist_failed")
    end
end

function Impl.RemoveFromPlaylist(index)
    if PlaylistPicker.Busy or PlaylistPicker.Track ~= MediaData.LastTrackKey then
        PlaylistPicker.Error = L("di_playlist_add_failed")
        return
    end
    PlaylistPicker.Busy = true
    local ok, sent = pcall(Impl.HttpRequest, "GET", "http://127.0.0.1:45455/playlist/remove?index=" .. tostring(index - 1), {}, function(res)
        PlaylistPicker.Busy = false
        if not PlaylistPicker.Open then return end
        if res and res.response and string.match(res.response, '"status"%s*:%s*"ok"') then
            PlaylistPicker.Selected[index] = false
        else
            if Dbg.On then Dbg.Log("playlist", "remove failed: " .. tostring(res and res.response or "no answer")) end
            PlaylistPicker.Error = L("di_playlist_add_failed")
        end
    end, "playlist_remove")
    if not ok or sent == false then
        PlaylistPicker.Busy = false
        PlaylistPicker.Error = L("di_playlist_add_failed")
    end
end

function Impl.AddToPlaylist(index)
    if PlaylistPicker.Busy or PlaylistPicker.Track ~= MediaData.LastTrackKey then
        PlaylistPicker.Error = L("di_playlist_add_failed")
        return
    end
    PlaylistPicker.Busy = true
    local ok, sent = pcall(Impl.HttpRequest, "GET", "http://127.0.0.1:45455/playlist/add?index=" .. tostring(index - 1), {}, function(res)
        PlaylistPicker.Busy = false
        if not PlaylistPicker.Open then return end
        if res and res.response and string.match(res.response, '"status"%s*:%s*"ok"') then
            PlaylistPicker.Open = false
            PlaylistPicker.Items = {}
        else
            if Dbg.On then Dbg.Log("playlist", "add failed: " .. tostring(res and res.response or "no answer")) end
            PlaylistPicker.Error = L("di_playlist_add_failed")
        end
    end, "playlist_add")
    if not ok or sent == false then
        PlaylistPicker.Busy = false
        PlaylistPicker.Error = L("di_playlist_add_failed")
    end
end

function Impl.GetScriptRelPath()
    if Engine and Engine.GetCheatDirectory then
        local ok, cd = pcall(Engine.GetCheatDirectory)
        if ok and cd and cd ~= "" then
            local root = string.gsub(cd, "/", "\\")
            local clean = string.gsub((string.gsub(root, "^%a:\\", "")), "\\", "/")
            return "../../../../../../../../" .. clean .. "scripts/"
        end
    end
    return "../../../../../../../../Umbrella/scripts/"
end

function Impl.TryLoadAlbumImage(coverPath, coverJpg, coverBase64, curVer)
    if not curVer or curVer <= 0 then return nil end
    if coverBase64 and coverBase64 ~= "" then
        local vStr = tostring(curVer) .. "_" .. #coverBase64 .. "_" .. (string.byte(coverBase64, math.floor(#coverBase64 / 2)) or 0) .. (string.byte(coverBase64, #coverBase64 - 3) or 0)
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
        cheatDir .. "dynamic_island_covers/dynamic_island_cover_" .. vStr .. ".png",
        cheatDir .. "dynamic_island_covers/dynamic_island_cover_" .. vStr .. ".jpg",
        cheatDir .. "dynamic_island_cover_" .. vStr .. ".png",
        cheatDir .. "dynamic_island_cover.png"
    }
    for _, p in ipairs(paths) do
        if p and p ~= "" then
            local f = Impl.OpenFile(p, "rb")
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

function Impl.AdvancePosition(dt)
    local back = DragState.Back
    if back and not DragState.IsDragging then
        DragState.CustomX, back.vx = MotionEngine.Step(DragState.CustomX, back.vx, back.x, dt, "BOUNCY")
        DragState.CustomY, back.vy = MotionEngine.Step(DragState.CustomY, back.vy, back.y, dt, "BOUNCY")
        if math.abs(DragState.CustomX - back.x) + math.abs(DragState.CustomY - back.y) < 0.5 and math.abs(back.vx) + math.abs(back.vy) < 5 then
            DragState.CustomX, DragState.CustomY, DragState.Back = back.x, back.y, nil
            SaveAllConfig()
        end
    end
    SeekDrag.Grow, SeekDrag.GrowVel = MotionEngine.Step(SeekDrag.Grow, SeekDrag.GrowVel, SeekDrag.Active and 1 or 0, dt, "SNAPPY")
    if MediaData.IsPlaying then
        MediaData.PosSmooth = MediaData.PosSmooth + dt
        MediaData.PosTarget = MediaData.PosTarget + dt
    end
    MediaData.PosSmooth = MediaData.PosSmooth + (MediaData.PosTarget - MediaData.PosSmooth) * math.min(1, 3 * dt)
    if MediaData.Duration > 0 then
        MediaData.PosSmooth = math.max(0, math.min(MediaData.Duration, MediaData.PosSmooth))
    end
end

IsNotifDeferred = function(notif)
    if not notif then return false end
    if not (UI and UI.Priority and UI.Priority.Media) then return false end
    if not (UI.Media and UI.Media.SecondaryBubble and UI.Media.SecondaryBubble:Get()) then return false end
    if HUDCustomizer.IsOpen then return false end
    if not (Engine.IsInGame and Engine.IsInGame()) then return false end
    if Impl.Engaged() then return true end
    if FightTracker.Active then return false end
    if not IsMediaActive() or Impl.MainKind ~= "media" then return false end
    return (notif.Priority or DEFAULT_NOTIF_PRIORITY) <= UI.Priority.Media:Get()
end

Impl.MainKinds = { pause = true, fight = true, media = true, courier = true, sdk = true }
Impl.SatHidden = {}

function Impl.Plan(inCombat, mediaActive, now)
    local list, seen = {}, {}
    local function add(kind, act)
        if seen[kind] then return end
        seen[kind] = true
        list[#list + 1] = { kind = kind, act = act }
    end
    local media = mediaActive and not HUDCustomizer.IsOpen
    if PauseTracker.IsPaused and ToggleOn(UI and UI.Combat and UI.Combat.PauseAlert) then
        if media then add("media") end
        add("pause")
    end
    if inCombat then add("fight") end
    if media then add("media") end
    if CourierTracker.Delivering or CourierTracker.Delivered then add("courier") end
    if Rampage.Active or now - Rampage.SuccessAt < 1.5 then add("rampage") end
    local ros = GameTracker.Roshan
    if ros.AegisExpiryTime - GameRules.GetGameTime() > 0 and not ros.Dismissed then add("aegis") end
    if not HUDCustomizer.IsOpen then
        local cur = Sdk.Current()
        if cur then
            add("sdk", cur)
            local sec = Sdk.Second()
            if sec then add("sdk2", sec) end
        end
    end
    local pin = Impl.Pin
    if pin then
        local idx
        for i, it in ipairs(list) do
            if it.kind == pin.kind then
                idx = i
                break
            end
        end
        local newer = false
        if idx then
            for i = 1, idx - 1 do
                if not pin.seen[list[i].kind] then newer = true end
            end
        end
        if not idx or newer then
            Impl.Pin = nil
        elseif idx > 1 then
            table.insert(list, 1, table.remove(list, idx))
        end
    end
    for kind in pairs(Impl.SatHidden) do
        if not seen[kind] then Impl.SatHidden[kind] = nil end
    end
    return list
end

function Impl.SwapWithBubble()
    local R = Satellite.Right
    local kind = R.kind
    local seen = {}
    for _, it in ipairs(Impl.PlanList or {}) do seen[it.kind] = true end
    if kind == "search" or (kind == "media" and Impl.MenuSwap) then
        Impl.MenuSwap = kind == "search" or nil
    elseif kind == "notif" and NotificationQueue.Active then
        NotificationQueue.Active.Priority = 99
        NotificationQueue.StartTime = os.clock()
    elseif kind == "activity" and R.act then
        for i, a in ipairs(Sdk.Acts) do
            if a == R.act then
                table.remove(Sdk.Acts, i)
                break
            end
        end
        Sdk.Acts[#Sdk.Acts + 1] = R.act
        if Impl.MainKind ~= "sdk" then Impl.Pin = { kind = "sdk", seen = seen } end
    elseif kind and Impl.MainKinds[kind] then
        Impl.Pin = { kind = kind, seen = seen }
    else
        Haptic.Trigger(Haptic.Types.ERROR)
        return
    end
    if Dbg.On then Dbg.Log("notif", "side bubble " .. tostring(kind) .. " swapped into the island") end
    Haptic.Trigger(Haptic.Types.TAP_MEDIUM)
end

function Impl.RestState()
    if not (Engine.IsInGame and Engine.IsInGame()) then return nil end
    local S = StateMachine.States
    local k = Impl.MainKind
    if k == "pause" then return S.GAME_PAUSED end
    if k == "fight" then return S.COMPACT_FIGHT end
    if k == "courier" then return CourierTracker.Delivered and S.COURIER_DELIVERED or S.COURIER_DELIVERY end
    if k == "sdk" then return S.ACTIVITY end
    if k == "media" then return S.COMPACT_MEDIA end
    return S.COMPACT_IDLE
end

Impl.WaveWeights = { 0.62, 0.86, 1.0, 0.8, 0.58 }

function Impl.PollLevel()
    if not UI or not UI.Media.Enabled:Get() or Demo.Active then return end
    if not MediaData.IsPlaying or not Sheet.BridgeOnline() then return end
    local S = StateMachine.States
    local st = StateMachine.TargetState
    if st ~= S.COMPACT_MEDIA and st ~= S.LARGE_MEDIA and Satellite.Right.kind ~= "combat" and Satellite.Right.kind ~= "media" then return end
    local now = os.clock()
    if now - (MediaData.LevelPoll or 0) < 0.055 then return end
    if MediaData.LevelBusy and now - MediaData.LevelBusy < 1.5 then return end
    MediaData.LevelPoll = now
    MediaData.LevelBusy = now
    pcall(Impl.HttpRequest, "GET", "http://127.0.0.1:45455/level", {}, function(res)
        MediaData.LevelBusy = nil
        if not res or not res.response then return end
        local body = string.match(res.response, '"l"%s*:%s*%[([^%]]*)%]')
        if not body then return end
        local lv, i = MediaData.Level or {}, 1
        for num in string.gmatch(body, "[%d%.eE%-]+") do
            lv[i] = tonumber(num) or 0
            i = i + 1
            if i > 5 then break end
        end
        MediaData.Level = lv
        MediaData.LevelAt = os.clock()
    end, "di_level")
end

function Impl.PollMediaBridge()
    if not UI or not UI.Media.Enabled:Get() or Demo.Active then return end
    local clk = os.clock()
    if clk - MediaData.LastPollTime < MediaData.PollInterval then return end
    if MediaData.PollBusy and clk - MediaData.PollBusy < 2.0 then return end
    MediaData.LastPollTime = clk
    MediaData.PollBusy = clk
    MediaData.PendingSince = MediaData.PendingSince or clk

    local port = 45455
    if not Impl.MediaQuery then
        local dir = ""
        if Engine and Engine.GetCheatDirectory then
            local ok, cd = pcall(Engine.GetCheatDirectory)
            if ok and cd and cd ~= "" then dir = string.gsub((string.gsub(cd, "/", "\\")), "\\$", "") .. "\\scripts" end
        end
        Impl.MediaQuery = dir ~= "" and ("?dir=" .. string.gsub(dir, "[^%w%-%._~]", function(c) return string.format("%%%02X", string.byte(c)) end)) or ""
    end
    local likes = (UI.Media.SpotifyLike and UI.Media.SpotifyLike:Get()) and "1" or "0"
    local url = string.format("http://127.0.0.1:%d/media", port) .. Impl.MediaQuery .. (Impl.MediaQuery == "" and "?" or "&") .. "likes=" .. likes

    pcall(Impl.HttpRequest, "GET", url, {}, function(res)
        MediaData.PollBusy = nil
        MediaData.PendingSince = nil
        if not res or not res.response or res.response == "" then return end
        local body = res.response
        if string.find(body, '"is_playing"', 1, true) then Impl.BridgeAlive() end

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
            MediaData.CoverSig = nil
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

        local newPos = tonumber(posStr) or 0
        local acceptPos = not SeekDrag.Active
        if acceptPos and nowClk < SeekDrag.HoldUntil then
            local expected = SeekDrag.HoldPos + (MediaData.IsPlaying and (nowClk - SeekDrag.HoldStart) or 0)
            if math.abs(newPos - expected) > 2.5 then
                acceptPos = false
            else
                SeekDrag.HoldUntil = 0
            end
        end
        if acceptPos then
            MediaData.PosTarget = newPos
            if math.abs(newPos - MediaData.PosSmooth) > 1.0 then
                MediaData.PosSmooth = newPos
            end
        end
        MediaData.Duration = tonumber(durStr) or 0
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
        local sig = tostring(curVer) .. ":" .. #coverBase64 .. ":" .. (coverBase64 ~= "" and ((string.byte(coverBase64, math.floor(#coverBase64 / 2)) or 0) .. "." .. (string.byte(coverBase64, #coverBase64 - 3) or 0)) or coverPath)
        if sig ~= MediaData.CoverSig or curVer ~= MediaData.CoverVersion or not MediaData.CoverImageHandle then
            MediaData.CoverSig = sig
            MediaData.CoverVersion = curVer
            if hasCover and curVer > 0 then
                local img = Impl.TryLoadAlbumImage(coverPath, coverJpg, coverBase64, curVer)
                if img then
                    MediaData.CoverImageHandle = img
                    MediaData.CoverHandleSetAt = os.clock()
                end
            else
                MediaData.CoverImageHandle = nil
            end
        end
    end, "media_poll")
end

function Impl.BridgeAlive()
    BridgeStatus.LastOk = os.clock()
    if BridgeStatus.Down then
        BridgeStatus.Down = false
        if Dbg.On then Dbg.Log("bridge", "online again") end
    end
end

function Impl.BridgeLagging()
    local clk = os.clock()
    local m, b = MediaData.PendingSince, BridgeStatus.PendingSince
    return (m ~= nil and clk - m > 1.0) or (b ~= nil and clk - b > 1.0)
end

function Impl.BridgeRefused()
    return (BridgeStatus.FailAt or 0) > BridgeStatus.LastOk
end

function Impl.BridgeFail(what, res)
    BridgeStatus.FailAt = os.clock()
    if BridgeStatus.Down then return end
    local clk = os.clock()
    if BridgeStatus.LastOk > 0 and clk - BridgeStatus.LastOk < 10 then return end
    BridgeStatus.Down = true
    if Dbg.On then
        Dbg.Log("bridge", string.format("no answer on %s: code %s, error %s %s, body %d bytes", what, tostring(res and res.code), tostring(res and res.error_code), tostring(res and res.error_message), #(res and res.response or "")), true)
    end
end

function Impl.PollBridgeStatus()
    local clk = os.clock()
    local online = BridgeStatus.LastOk > 0 and clk - BridgeStatus.LastOk < 10
    if clk - BridgeStatus.LastPoll < (online and 3.0 or 1.0) then return end
    if BridgeStatus.Busy and clk - BridgeStatus.Busy < 4.0 then return end
    BridgeStatus.LastPoll = clk
    BridgeStatus.Busy = clk
    BridgeStatus.PendingSince = BridgeStatus.PendingSince or clk
    if BridgeStatus.FirstPoll == 0 then BridgeStatus.FirstPoll = clk end
    pcall(Impl.HttpRequest, "GET", "http://127.0.0.1:45455/status", {}, function(res)
        BridgeStatus.Busy = nil
        BridgeStatus.PendingSince = nil
        local body = res and res.response or ""
        if not string.find(body, '"status"', 1, true) then
            Impl.BridgeFail("/status", res)
            return
        end
        Impl.BridgeAlive()
        BridgeStatus.Version = string.match(body, '"version"%s*:%s*"([^"]*)"') or ""
        BridgeStatus.Latest = string.match(body, '"latest_version"%s*:%s*"([^"]*)"') or ""
        BridgeStatus.MediaSessions = string.match(body, '"media_sessions"%s*:%s*"([^"]*)"') or ""
        BridgeStatus.SpotifyDebug = string.match(body, '"spotify_debug"%s*:%s*"([^"]*)"') or ""
        BridgeStatus.YandexDebug = string.match(body, '"yandex_debug"%s*:%s*"([^"]*)"') or ""
        local fontsOk = string.match(body, '"fonts_ok"%s*:%s*(%a+)')
        if fontsOk then BridgeStatus.FontsOk = fontsOk == "true" end
    end, "bridge_status")
end

function Impl.SystemNotif(glyph, accent, tag, title)
    DynamicIsland.PushNotification({
        Type = "system",
        Tag = tag,
        Title = title,
        AccentColor = accent,
        IconType = "svg",
        FallbackSvg = glyph,
        Duration = 2.5,
        FocusExempt = true,
        Silent = true
    })
end

function Impl.PollSystem()
    local sys = UI and UI.System
    if not sys or not (ToggleOn(sys.Output) or ToggleOn(sys.Mute) or ToggleOn(sys.Battery)) then return end
    local clk = os.clock()
    if clk - SystemState.LastPoll < 0.6 then return end
    if SystemState.Busy and clk - SystemState.Busy < 3.0 then return end
    SystemState.LastPoll = clk
    SystemState.Busy = clk
    pcall(Impl.HttpRequest, "GET", "http://127.0.0.1:45455/system", {}, function(res)
        SystemState.Busy = nil
        if not res or not res.response or res.response == "" then return end
        local body = res.response
        local id = string.match(body, '"device_id"%s*:%s*"([^"]*)"')
        if not id then return end
        Impl.BridgeAlive()
        local cur = {
            id = id,
            name = string.match(body, '"device"%s*:%s*"(.-)"%s*,%s*"device_id"') or "",
            kind = string.match(body, '"device_kind"%s*:%s*"([^"]*)"') or "",
            muted = string.match(body, '"muted"%s*:%s*(%a+)') == "true",
            battery = tonumber(string.match(body, '"battery"%s*:%s*(%-?%d+)') or "-1") or -1,
            ac = string.match(body, '"on_ac"%s*:%s*(%a+)') == "true"
        }
        local prev = SystemState.Last
        SystemState.Last = cur
        if not prev then return end
        local C = Config.Colors
        if cur.id ~= prev.id and cur.id ~= "" and prev.id ~= "" and ToggleOn(sys.Output) then
            local glyph, tag = "volume", L("di_sys_speakers")
            if cur.kind == "headphones" then glyph, tag = "headphones", L("di_sys_headphones")
            elseif cur.kind == "display" then glyph, tag = "display", L("di_sys_display") end
            Impl.SystemNotif(glyph, C.Blue, tag, cur.name ~= "" and cur.name or tag)
        elseif cur.muted ~= prev.muted and cur.id == prev.id and ToggleOn(sys.Mute) then
            if cur.muted then
                Impl.SystemNotif("mute", C.Red, L("di_sys_sound"), L("di_sys_muted"))
            else
                Impl.SystemNotif("volume", C.Blue, L("di_sys_sound"), L("di_sys_unmuted"))
            end
        end
        if cur.battery >= 0 and prev.battery >= 0 and ToggleOn(sys.Battery) then
            if cur.ac and not prev.ac then
                Impl.SystemNotif("bolt", C.Green, L("di_sys_battery_tag"), string.format(L("di_sys_charging"), cur.battery))
            elseif not cur.ac and ((cur.battery <= 20 and prev.battery > 20) or (cur.battery <= 10 and prev.battery > 10)) then
                Impl.SystemNotif("battery_low", C.Red, L("di_sys_battery_tag"), string.format(L("di_sys_low"), cur.battery))
            end
        end
    end, "system_state")
end

function Impl.ParseVersion(s)
    if not s or s == "" then return nil end
    local a, b, c = string.match(s, "^[vV]?(%d+)%.(%d+)%.?(%d*)")
    if not a then return nil end
    return { tonumber(a), tonumber(b), tonumber(c) or 0 }
end

function Impl.VersionLess(x, y)
    for i = 1, 3 do
        if x[i] ~= y[i] then return x[i] < y[i] end
    end
    return false
end

function Impl.CollectStatusHints()
    local out = {}
    local clk = os.clock()
    local online = BridgeStatus.LastOk > 0 and (clk - BridgeStatus.LastOk) < 7.0
    local settled = BridgeStatus.FirstPoll > 0 and (clk - BridgeStatus.FirstPoll) > 6.0

    if UI and UI.Media and UI.Media.Enabled:Get() and settled and not online then
        table.insert(out, { text = L(Impl.BridgeRefused() and "di_ui_bridge_offline" or "di_ui_bridge_stalled"), dot = Color(255, 159, 10, 255) })
    elseif online and BridgeStatus.MediaSessions == "timeout" then
        table.insert(out, { text = L("di_ui_media_service_down"), dot = Color(255, 159, 10, 255) })
    end
    if online and BridgeStatus.SpotifyDebug == "closed" and UI and UI.Media and UI.Media.SpotifyLike:Get() then
        table.insert(out, { text = L("di_ui_spotify_no_port"), dot = Color(255, 159, 10, 255) })
    end
    if online and BridgeStatus.YandexDebug == "closed" and UI and UI.Media and UI.Media.SpotifyLike:Get() then
        table.insert(out, { text = L("di_ui_yandex_no_port"), dot = Color(255, 159, 10, 255) })
    end

    if next(Fuse.Off) then
        table.insert(out, { text = L("di_ui_module_off"), dot = Color(255, 69, 58, 255) })
    end
    local latest = Impl.ParseVersion(BridgeStatus.Latest)
    if latest then
        local mine = Impl.ParseVersion(SCRIPT_VERSION)
        local bridge = Impl.ParseVersion(BridgeStatus.Version)
        if (mine and Impl.VersionLess(mine, latest)) or (bridge and Impl.VersionLess(bridge, latest)) then
            table.insert(out, { text = L("di_ui_update_available") .. BridgeStatus.Latest, dot = Color(10, 132, 255, 255) })
        end
    end
    return out
end

function Impl.ProcessFightDetector()
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
        FightTracker.Landmark = Impl.GetClosestLandmark(bestCluster.center)

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
                local summaryTitle = L("di_ui_skirmish_concluded")
                local summarySub = L("di_ui_all_combatants_retreated")
                local summaryCol = Config.Colors.Yellow

                if ek > ak then
                    summaryTitle = L("di_ui_fight_won")
                    summarySub = string.format(L("di_ui_enemies_slain_n_losses_n"), ek, ak)
                    summaryCol = Config.Colors.Accent
                elseif ak > ek then
                    summaryTitle = L("di_ui_fight_lost")
                    summarySub = string.format(L("di_ui_team_losses_n_kills_n"), ak, ek)
                    summaryCol = Config.Colors.Red
                elseif ek > 0 and ek == ak then
                    summaryTitle = L("di_ui_even_trade")
                    summarySub = string.format(L("di_ui_traded_n_for_n"), ek, ak)
                    summaryCol = Config.Colors.Orange
                end

                DynamicIsland.PushNotification({
                    Type = "fight_summary",
                    Tag = L("di_ui_fight_outcome"),
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

function Impl.ProcessGameEvents()
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

        local okPing, latency = pcall(NetChannel.GetAvgLatency)
        if okPing and latency then
            local rawPing = math.floor(latency * 1000)
            local shownPing = PerformanceData.Ping
            if not PerformanceData.PingShown or math.abs(rawPing - shownPing) >= math.max(5, shownPing * 0.1) then
                PerformanceData.Ping = rawPing
                PerformanceData.PingShown = true
            end
        end
    end

    if UI.Combat.LevelUp:Get() then
        local curLevel = NPC.GetCurrentLevel(localHero)
        if HeroData.Level > 0 and curLevel > HeroData.Level then
            local heroRaw = NPC.GetUnitName(localHero)
            DynamicIsland.PushNotification({
                Type = "level",
                Tag = L("di_ui_level_up"),
                Title = string.format(L("di_ui_level_n_reached"), curLevel),
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
            local seen = HeroData.KillsSeen or -1
            HeroData.KillsSeen = curKills
            if seen >= 0 and curKills > seen then
                local delta = curKills - seen
                local nowGT = GameRules.GetGameTime()
                if nowGT - (HeroData.LastKillTime or -100) <= 18 then
                    HeroData.MultiKill = (HeroData.MultiKill or 0) + delta
                else
                    HeroData.MultiKill = delta
                end
                HeroData.LastKillTime = nowGT
                if HeroData.MultiKill >= 5 and Rampage.Count == 4 then
                    Rampage.SuccessAt = os.clock()
                end
                Rampage.Count = HeroData.MultiKill
                Rampage.LastKill = nowGT
                local multi = HeroData.MultiKill
                local streak = teamData.streak or 0
                local total = 0
                for _, pl in ipairs(Players.GetAll()) do
                    local okT, td = pcall(Player.GetTeamData, pl)
                    if okT and td then total = total + (td.kills or 0) end
                end
                local firstBlood = total > 0 and total - delta <= 0
                local streakTitle = L("di_ui_enemy_slain")
                if multi >= 5 then streakTitle = L("di_streak_rampage")
                elseif multi == 4 then streakTitle = L("di_streak_ultra_kill")
                elseif multi == 3 then streakTitle = L("di_streak_triple_kill")
                elseif multi == 2 then streakTitle = L("di_streak_double_kill")
                elseif firstBlood then streakTitle = L("di_streak_first_blood")
                elseif streak >= 10 then streakTitle = L("di_streak_beyond_godlike")
                elseif streak == 9 then streakTitle = L("di_streak_godlike")
                elseif streak == 8 then streakTitle = L("di_streak_monster_kill")
                elseif streak == 7 then streakTitle = L("di_streak_wicked_sick")
                elseif streak == 6 then streakTitle = L("di_streak_unstoppable")
                elseif streak == 5 then streakTitle = L("di_streak_mega_kill")
                elseif streak == 4 then streakTitle = L("di_streak_dominating")
                elseif streak == 3 then streakTitle = L("di_streak_killing_spree")
                end

                local killedHeroName = L("di_ui_enemy")
                local killedRaw = ""
                local deaths = HeroData.EnemyDeathTime or {}
                local victim, victimT = nil, -1
                for _, h in pairs(Heroes.GetAll()) do
                    if Entity.GetTeamNum(h) ~= Entity.GetTeamNum(localHero) and not Entity.IsAlive(h)
                        and not (NPC.IsIllusion and NPC.IsIllusion(h)) then
                        local hId = tostring(h)
                        local justDied = HeroData.EnemyHeroes[hId] == nil or HeroData.EnemyHeroes[hId] == true
                        local diedAt = justDied and nowGT or (deaths[hId] or -100)
                        if nowGT - diedAt <= 3 and diedAt > victimT then
                            victim, victimT = h, diedAt
                        end
                    end
                end
                if victim then
                    killedRaw = NPC.GetUnitName(victim) or ""
                    killedHeroName = CleanHeroName(killedRaw)
                    HeroData.LastKilled.Name = killedHeroName
                    HeroData.LastKilled.MaxHP = Entity.GetMaxHealth(victim)
                    HeroData.LastKilled.Level = NPC.GetCurrentLevel(victim)
                    HeroData.LastKilled.Items = {}
                    for idx = 0, 5 do
                        local it = NPC.GetItemByIndex(victim, idx)
                        if it then
                            local iname = Ability.GetName(it)
                            if iname and iname ~= "" then
                                table.insert(HeroData.LastKilled.Items, Impl.CleanItemName(iname))
                            end
                        end
                    end
                end

                local killerRaw = NPC.GetUnitName(localHero) or ""

                DynamicIsland.PushNotification({
                    Type = "kill",
                    Tag = L("di_ui_kill_streak"),
                    Title = streakTitle,
                    Subtitle = L("di_ui_eliminated") .. killedHeroName,
                    AccentColor = Config.Colors.Red,
                    IconType = "hero",
                    Icon = killerRaw ~= "" and ("panorama/images/heroes/icons/" .. killerRaw .. "_png.vtex_c") or nil,
                    Duration = 3.8
                })
            end
        end
    end

    if UI.Runes.Roshan:Get() then
        Impl.WatchRoshanHealth(now)
    end

    local allHeroesList = Heroes.GetAll()
    HeroData.EnemyDeathTime = HeroData.EnemyDeathTime or {}
    for _, h in pairs(allHeroesList) do
        if Entity.GetTeamNum(h) ~= Entity.GetTeamNum(localHero) then
            local hId = tostring(h)
            local aliveNow = Entity.IsAlive(h)
            if HeroData.EnemyHeroes[hId] == true and not aliveNow then
                HeroData.EnemyDeathTime[hId] = GameRules.GetGameTime()
            end
            HeroData.EnemyHeroes[hId] = aliveNow

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
                            local itemCol = Impl.GetItemSignatureColor(rawName)
                            DynamicIsland.PushNotification({
                                Type = "enemy_item",
                                Tag = L("di_ui_item_alert"),
                                Title = KeyItemColors[rawName].name,
                                Subtitle = hName .. L("di_ui_purchased_item"),
                                AccentColor = itemCol,
                                IconType = "item",
                                Icon = Impl.GetItemTexturePath(rawName),
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
                        local rInfo = RuneInfoList[rType] or { name = "di_rune_names_rune", col = Color(255, 214, 10, 255), path = "panorama/images/spellicons/rune_doubledamage_png.vtex_c", svg = "rune_dd" }
                        local locText = L("di_ui_spawned_in_river")
                        if rPos then
                            if rType == Enum.RuneType.DOTA_RUNE_XP then
                                locText = L("di_ui_spawned_at_shrine")
                            elseif rType ~= Enum.RuneType.DOTA_RUNE_BOUNTY then
                                locText = rPos.y > 0 and L("di_ui_spawned_top_river") or L("di_ui_spawned_bottom_river")
                            end
                        end
                        DynamicIsland.PushNotification({
                            Type = "rune_world",
                            Tag = L("di_ui_rune_spawned"),
                            Title = L(rInfo.name),
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
        local stackLead = UI.Timings.StackTime:Get()
        local stackUntil = UI.Timings.StackUntil:Get()

        if tf > 0 then
            local nm = math.floor(tf / 60) + 1
            local sl = nm * 60 - tf

            if UI.Runes.Stacks:Get() and nm >= 2 and (stackUntil == 0 or nm <= stackUntil) and sl == 7 + stackLead and not FightTracker.Active then
                local sKey = "stack_" .. nm
                if not GameTracker.Runes.WarnedMilestones[sKey] then
                    GameTracker.Runes.WarnedMilestones[sKey] = true
                    DynamicIsland.PushNotification({
                        Type = "stack",
                        Tag = L("di_ui_stack"),
                        Title = string.format(L("di_ui_stack_in_n_s"), stackLead),
                        Subtitle = string.format(L("di_ui_pull_the_camp_at_n_53"), nm - 1),
                        AccentColor = Color(48, 209, 88, 255),
                        IconType = "svg",
                        FallbackSvg = "stack",
                        MaxDuration = stackLead
                    })
                end
            end

            if UI.Runes.WisdomRunes:Get() and sl == wisdomLead and nm % 7 == 0 then
                local key = "w_" .. nm
                if not GameTracker.Runes.WarnedMilestones[key] then
                    GameTracker.Runes.WarnedMilestones[key] = true
                    DynamicIsland.PushNotification({
                        Type = "rune",
                        Tag = L("di_ui_wisdom_rune"),
                        Title = string.format(L("di_ui_wisdom_runes_in_n_s"), wisdomLead),
                        Subtitle = L("di_ui_side_lane_shrines"),
                        AccentColor = Color(191, 90, 242, 255),
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
                        Tag = L("di_ui_water_rune"),
                        Title = string.format(L("di_ui_water_runes_in_n_s"), waterLead),
                        Subtitle = L("di_ui_river_spawn_points"),
                        AccentColor = Color(100, 210, 255, 255),
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
                        Tag = L("di_ui_power_rune"),
                        Title = string.format(L("di_ui_power_runes_in_n_s"), powerLead),
                        Subtitle = L("di_ui_river_spawn_points"),
                        AccentColor = Color(10, 132, 255, 255),
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
                        Tag = L("di_ui_bounty_rune"),
                        Title = string.format(L("di_ui_bounty_runes_in_n_s"), bountyLead),
                        Subtitle = L("di_ui_bounty_spawn_spots"),
                        AccentColor = Color(255, 214, 10, 255),
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
                    Tag = L("di_ui_objective"),
                    Title = string.format(L("di_ui_tormentor_soon_s"), minStr),
                    Subtitle = L("di_ui_spawns_at_20_00"),
                    AccentColor = Color(64, 200, 224, 255),
                    IconType = "item",
                    Icon = "panorama/images/items/aghanims_shard_png.vtex_c",
                    Duration = 4.5
                })
            elseif tf >= (1200 - tLead2) and tf <= (1200 - tLead2 + 2) and UI.Runes.Tormentor:Get() and not GameTracker.Tormentor.Warned2 then
                GameTracker.Tormentor.Warned2 = true
                DynamicIsland.PushNotification({
                    Type = "tormentor",
                    Tag = L("di_ui_objective"),
                    Title = string.format(L("di_ui_tormentor_in_n_s"), tLead2),
                    Subtitle = L("di_ui_spawns_at_20_00_2"),
                    AccentColor = Color(64, 200, 224, 255),
                    IconType = "item",
                    Icon = "panorama/images/items/aghanims_shard_png.vtex_c",
                    Duration = 4.5
                })
            end
        elseif tf <= -bountyLead and tf >= -(bountyLead + 2) and UI.Runes.BountyRunes:Get() and not GameTracker.Runes.WarnedMilestones["start_bounty"] then
            GameTracker.Runes.WarnedMilestones["start_bounty"] = true
            DynamicIsland.PushNotification({
                Type = "rune",
                Tag = L("di_ui_bounty_rune"),
                Title = string.format(L("di_ui_bounty_runes_in_n_s"), bountyLead),
                Subtitle = L("di_ui_initial_bounty_spawns"),
                AccentColor = Color(255, 214, 10, 255),
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
            Tag = L("di_ui_neutrals_unlocked"),
            Title = L("di_ui_tier_1_neutrals_ready"),
            Subtitle = L("di_ui_n_7_00_match_time_reached"),
            AccentColor = Color(48, 209, 88, 255),
            Duration = 4.0
        })
    elseif sec >= 1020 and not GameTracker.Neutrals.Tier2 then
        GameTracker.Neutrals.Tier2 = true
        DynamicIsland.PushNotification({
            Type = "neutral",
            Tag = L("di_ui_neutrals_unlocked"),
            Title = L("di_ui_tier_2_neutrals_ready"),
            Subtitle = L("di_ui_n_17_00_match_time_reached"),
            AccentColor = Color(10, 132, 255, 255),
            Duration = 4.0
        })
    elseif sec >= 1620 and not GameTracker.Neutrals.Tier3 then
        GameTracker.Neutrals.Tier3 = true
        DynamicIsland.PushNotification({
            Type = "neutral",
            Tag = L("di_ui_neutrals_unlocked"),
            Title = L("di_ui_tier_3_neutrals_ready"),
            Subtitle = L("di_ui_n_27_00_match_time_reached"),
            AccentColor = Color(191, 90, 242, 255),
            Duration = 4.0
        })
    elseif sec >= 2220 and not GameTracker.Neutrals.Tier4 then
        GameTracker.Neutrals.Tier4 = true
        DynamicIsland.PushNotification({
            Type = "neutral",
            Tag = L("di_ui_neutrals_unlocked"),
            Title = L("di_ui_tier_4_neutrals_ready"),
            Subtitle = L("di_ui_n_37_00_match_time_reached"),
            AccentColor = Color(255, 159, 10, 255),
            Duration = 4.0
        })
    elseif sec >= 3600 and not GameTracker.Neutrals.Tier5 then
        GameTracker.Neutrals.Tier5 = true
        DynamicIsland.PushNotification({
            Type = "neutral",
            Tag = L("di_ui_neutrals_unlocked"),
            Title = L("di_ui_tier_5_neutrals_ready"),
            Subtitle = L("di_ui_n_60_00_match_time_reached"),
            AccentColor = Color(255, 69, 58, 255),
            Duration = 5.0
        })
    end

    if UI.Runes.Lotus:Get() and sec > 0 then
        local lotusLead = UI.Timings.LotusTime:Get()
        if (sec + lotusLead) % 180 <= 1 and (sec - GameTracker.Lotus.LastAlertTime > 60) then
            GameTracker.Lotus.LastAlertTime = sec
            DynamicIsland.PushNotification({
                Type = "lotus",
                Tag = L("di_ui_lotus_pool"),
                Title = string.format(L("di_ui_lotus_fruit_in_n_s"), lotusLead),
                Subtitle = L("di_ui_side_lane_pools"),
                AccentColor = Color(255, 55, 95, 255),
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
                        Tag = L("di_ui_courier_warning"),
                        Title = L("di_ui_courier_under_attack"),
                        Subtitle = string.format(L("di_ui_n_hp_remaining"), hp),
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
                            Tag = L("di_ui_tower_defense"),
                            Title = L("di_ui_ally_tower_attacked"),
                            Subtitle = string.format(L("di_ui_health_dropped_to_n_pct"), pct),
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
                            Tag = L("di_ui_kill_opportunity"),
                            Title = name .. " Low HP!",
                            Subtitle = string.format(L("di_ui_n_hp_remaining"), hp),
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
        local rType = Impl.RuneModifierMap[mn]
        if rType then
            local rInfo = RuneInfoList[rType] or { name = "di_rune_names_rune", col = Color(255, 214, 10, 255), path = "panorama/images/spellicons/rune_doubledamage_png.vtex_c", svg = "rune_dd" }
            local hName = GetPlayerDisplayName(ent)
            DynamicIsland.PushNotification({
                Type = "rune_pickup",
                Tag = L("di_ui_rune_pickup"),
                Title = hName,
                Subtitle = L("di_ui_picked_up") .. L(rInfo.name),
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
        local d = Impl.StrictInvisModifiers[mn]
        if d then
            local heroName = GetPlayerDisplayName(ent)
            DynamicIsland.PushNotification({
                Type = "invis",
                Tag = L("di_ui_invisibility_alert"),
                Title = heroName .. ", " .. d.name,
                Subtitle = L("di_ui_enemy_entered_stealth"),
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
        local landmark = Impl.GetClosestLandmark(targetPos)
        DynamicIsland.PushNotification({
            Type = "teleport",
            Tag = L("di_ui_teleport_warning"),
            Title = heroName .. L("di_ui_teleporting"),
            Subtitle = L("di_ui_teleporting_to") .. landmark,
            AccentColor = Color(100, 210, 255, 255),
            IconType = "item",
            Icon = "panorama/images/items/tpscroll_png.vtex_c",
            Duration = 3.8
        })
        return
    end

    if isHero and UI.Runes.Roshan:Get() and mn == "modifier_item_aegis" and not (NPC.IsIllusion and NPC.IsIllusion(ent)) then
        Impl.AegisClaimed(ent, isEnemy, "modifier")
        return
    end
end

function Impl.AegisClaimed(ent, isEnemy, source)
    local ros = GameTracker.Roshan
    local now = GameRules.GetGameTime()
    local known = ros.AegisClaimedAt ~= nil and now - ros.AegisClaimedAt < 300 and (ros.AegisClaimedBy == ent or ros.AegisClaimedBy == nil or ent == nil)
    if Dbg.On then
        Dbg.Log("roshan", string.format("aegis claimed via %s, holder %s, enemy %s, already known %s", source, ent and tostring(NPC.GetUnitName(ent)) or "unknown", tostring(isEnemy), tostring(known)))
    end
    if known then
        if ent then
            ros.AegisClaimedBy = ent
            ros.AegisHolder = ent
            if source == "modifier" and ros.AegisExpiryTime == 0 then
                ros.AegisExpiryTime = ros.AegisClaimedAt + 300
            end
        end
        return
    end
    ros.AegisClaimedAt = now
    ros.AegisClaimedBy = ent
    ros.AegisExpiryTime = now + 300
    ros.AegisHolder = ent
    ros.Dismissed = false
    local heroName = ent and CleanHeroName(NPC.GetUnitName(ent)) or L("di_ui_enemy_hero")
    DynamicIsland.PushNotification({
        Type = "aegis",
        Tag = L("di_ui_aegis_claimed"),
        Title = heroName .. L("di_ui_claimed_aegis"),
        Subtitle = isEnemy and L("di_ui_enemy_secured_immortal") or L("di_ui_ally_secured_immortal"),
        AccentColor = isEnemy and Config.Colors.Red or Config.Colors.Accent,
        IconType = "item",
        Icon = "panorama/images/items/aegis_png.vtex_c",
        Duration = 4.5
    })
end

function Impl.RoshanAttacked(now, subtitle, source)
    local ros = GameTracker.Roshan
    local fresh = now - ros.LastAttackAlert > 15.0
    ros.LastAttackAlert = now
    if not fresh then return end
    if Dbg.On then Dbg.Log("roshan", "under attack via " .. source .. ", " .. subtitle) end
    DynamicIsland.PushNotification({
        Type = "roshan_attack",
        Tag = L("di_ui_roshan_pit_alert"),
        Title = L("di_ui_roshan_under_attack"),
        Subtitle = subtitle,
        AccentColor = Config.Colors.Red,
        IconType = "item",
        Icon = "panorama/images/items/aegis_png.vtex_c",
        Duration = 4.5
    })
end

function Impl.WatchRoshanHealth(now)
    local ros = GameTracker.Roshan
    if ros.HpAt and now >= ros.HpAt and now - ros.HpAt < 1.0 then return end
    ros.HpAt = now
    local ok, hp = pcall(Entity.GetRoshanHealth)
    if not ok or type(hp) ~= "number" then
        if Dbg.On and not ros.HpLogged then
            ros.HpLogged = true
            Dbg.Log("roshan", "health is not readable: " .. tostring(hp))
        end
        return
    end
    local prev = ros.LastHP
    ros.LastHP = hp
    if Dbg.On and not ros.HpLogged then
        ros.HpLogged = true
        Dbg.Log("roshan", "health readable, now " .. tostring(hp))
    end
    if prev and prev > 0 and hp > 0 and hp < prev then
        Impl.RoshanAttacked(now, string.format(L("di_ui_roshan_health"), hp), "health " .. prev .. " -> " .. hp)
    end
end

function DynamicIsland.OnChatEvent(data)
    if not UI or not UI.Main.Enabled:Get() or not UI.Runes.Roshan:Get() or not data then return end
    local T = Enum.DotaChatMessage
    if data.type ~= T.CHAT_MESSAGE_AEGIS and data.type ~= T.CHAT_MESSAGE_AEGIS_STOLEN then return end
    local my = HeroData.Local or Heroes.GetLocal()
    if not my then return end
    local hero = nil
    for _, pl in ipairs(Players.GetAll()) do
        local okId, pid = pcall(Player.GetPlayerID, pl)
        if okId and pid == data.playerid_1 then
            hero = Player.GetAssignedHero(pl)
            break
        end
    end
    if Dbg.On then
        Dbg.Log("roshan", string.format("chat event %s, player %s, hero %s", tostring(data.type), tostring(data.playerid_1), hero and tostring(NPC.GetUnitName(hero)) or "not found"))
    end
    local isEnemy = true
    if hero then isEnemy = not Entity.IsSameTeam(my, hero) end
    Impl.AegisClaimed(hero, isEnemy, "chat")
end

function DynamicIsland.OnModifierDestroy(ent, mod)
    if GameTracker.Roshan.AegisExpiryTime == 0 or not mod or ent ~= GameTracker.Roshan.AegisHolder then return end
    local ok, mn = pcall(Modifier.GetName, mod)
    if ok and mn == "modifier_item_aegis" then
        if Entity.IsDormant(ent) then
            if Dbg.On then Dbg.Log("roshan", "aegis modifier dropped while the holder is in fog, timer kept") end
            return
        end
        GameTracker.Roshan.AegisExpiryTime = 0
        GameTracker.Roshan.AegisHolder = nil
    end
end

function DynamicIsland.OnStartSound(data)
    if not UI or not UI.Main.Enabled:Get() or not UI.Runes.Roshan:Get() or not data or not data.name then return end
    local snd = string.lower(data.name)
    if string.find(snd, "roshan") or string.find(snd, "rosh") then
        Impl.RoshanAttacked(GameRules.GetGameTime(), L("di_ui_combat_audio_detected_in_pit"), "sound " .. snd)
    end
end

function DynamicIsland.OnFireEventClient(data)
    if not UI or not UI.Main.Enabled:Get() or not data or not data.name then return end

    if data.name == "dota_buyback" and UI.Combat.Buybacks:Get() then
        local pid = Event.GetInt(data.event, "player_id")
        local pName = L("di_ui_player")
        local allPlayers = Players.GetAll()
        for _, pl in ipairs(allPlayers) do
            local pd = Player.GetPlayerData(pl)
            if pd and pd.PlayerID == pid then
                pName = Player.GetName(pl) or pd.PlayerName or L("di_ui_enemy")
                break
            end
        end
        DynamicIsland.PushNotification({
            Type = "buyback",
            Tag = L("di_ui_buyback_alert"),
            Title = pName .. L("di_ui_bought_back"),
            Subtitle = L("di_ui_hero_returned_to_match"),
            AccentColor = Color(255, 214, 10, 255),
            IconType = "svg",
            FallbackSvg = "buyback",
            Duration = 4.0
        })
        return
    end

    if data.name == "dota_roshan_kill" and UI.Runes.Roshan:Get() then
        GameTracker.Roshan.DeathTime = GameRules.GetGameTime()
        DynamicIsland.PushNotification({
            Type = "roshan_kill",
            Tag = L("di_ui_roshan_slain"),
            Title = L("di_ui_roshan_killed"),
            Subtitle = L("di_ui_aegis_dropped_in_pit"),
            AccentColor = Color(255, 69, 58, 255),
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
            Tag = L("di_ui_tormentor_spawn"),
            Title = L("di_ui_tormentor_spawned"),
            Subtitle = L("di_ui_objective_available"),
            AccentColor = Color(64, 200, 224, 255),
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
            Tag = L("di_ui_tormentor_defeated"),
            Title = L("di_ui_tormentor_defeated_2"),
            Subtitle = L("di_ui_shard_granted_to_team"),
            AccentColor = Color(48, 209, 88, 255),
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

    local freeDrag = preset == 1 and (DragState.IsDragging or DragState.Back ~= nil)
    if preset == 1 and ((DragState.CustomX >= 0 and DragState.CustomY >= 0) or freeDrag) then
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

    if not freeDrag then
        local margin = 4
        x = math.max(margin, math.min(x, scr.x - w - margin))
        y = math.max(margin, math.min(y, scr.y - h - margin))
    end

    local res = {
        x = x,
        y = y,
        w = w,
        h = h,
        r = r,
        scale = scale
    }
    res.x = res.x + math.floor(Swipe.IslandX + 0.5)
    if Haptic and Haptic.ApplyTransform then
        Haptic.ApplyTransform(res)
    end
    return res
end

local function PerfTint(kind, base)
    local st = PerformanceData.Warn[kind]
    local now = os.clock()
    if not st then
        st = { a = 0, clk = now, col = Config.Colors.Orange }
        PerformanceData.Warn[kind] = st
    end
    local lvl = PerformanceData.Level(kind)
    local dtw = math.min(0.1, math.max(0, now - st.clk))
    st.clk = now
    if lvl > 0 then st.col = (lvl == 2) and Config.Colors.Red or Config.Colors.Orange end
    st.a = st.a + ((lvl > 0 and 1 or 0) - st.a) * math.min(1, dtw * 6)
    if st.a < 0.01 then return base end
    local c = LerpColor(base, st.col, st.a)
    return Color(c.r, c.g, c.b, math.floor((base.a or 255) + (255 - (base.a or 255)) * st.a))
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

    local wg = Impl.Wg.ById[chipId]
    if wg then
        return { isClock = false, svgKey = (cfg.showIcon ~= false) and wg.glyph or nil, text = wg.text, font = font, color = col }
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
        local txt = Odometer.Group(HeroData.Gold)
        if cfg.format == 1 then txt = Odometer.Group(HeroData.Gold) .. " G"
        elseif cfg.format == 3 then txt = string.format("%.1fk G", HeroData.Gold / 1000.0) end
        return { isClock = false, svgKey = svgKey, text = txt, font = font, color = col }
    elseif chipId == "networth" then
        local txt = HeroData.NetWorth > 0 and string.format("%.1fk NW", HeroData.NetWorth / 1000.0) or string.format("%d NW", HeroData.Gold)
        if cfg.format == 2 then txt = HeroData.NetWorth > 0 and string.format("%.1fk", HeroData.NetWorth / 1000.0) or string.format("%d", HeroData.Gold)
        elseif cfg.format == 3 then txt = Odometer.Group(HeroData.NetWorth) .. " NW" end
        return { isClock = false, svgKey = svgKey, text = txt, font = font, color = col }
    elseif chipId == "lasthits" then
        local txt = string.format("%d LH", HeroData.LastHits)
        if cfg.format == 2 then txt = string.format("%d", HeroData.LastHits)
        elseif cfg.format == 3 then txt = string.format("%d/%d", HeroData.LastHits, HeroData.Denies) end
        return { isClock = false, svgKey = svgKey, text = txt, font = font, color = col }
    elseif chipId == "heroname" then
        local custom = (UI and UI.Main and UI.Main.CustomLabel) and UI.Main.CustomLabel:Get() or ""
        local nameStr = (custom and custom ~= "") and custom or CleanHeroName(HeroData.HeroName)
        if nameStr == "" then nameStr = L("di_ui_hero") end
        if cfg.format == 2 then
            nameStr = string.upper(string.sub(nameStr, 1, 3))
        end
        return { isClock = false, svgKey = svgKey, text = nameStr, font = font, color = col }
    elseif chipId == "fps" then
        local txt = string.format("%d FPS", PerformanceData.FPS)
        if cfg.format == 2 then txt = string.format("%d", PerformanceData.FPS) end
        return { isClock = false, svgKey = svgKey, text = txt, font = font, color = PerfTint("fps", col) }
    elseif chipId == "ping" then
        local txt = string.format("%d ms", PerformanceData.Ping)
        if cfg.format == 2 then txt = string.format("%d", PerformanceData.Ping) end
        return { isClock = false, svgKey = svgKey, text = txt, font = font, color = PerfTint("ping", col) }
    end
    return { isClock = false, svgKey = nil, text = "Chip", font = font, color = col }
end

function Impl.HasFindingMatchClass(panel)
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

function Impl.GetMatchSearchInfo()
    if not Panorama or not Panorama.GetPanelByName then
        return false, "0:00"
    end

    local isSearching = false
    local p = Panorama.GetPanelByName("SearchingTime", false)
    if p and p:IsValid() and Impl.HasFindingMatchClass(p) then
        isSearching = true
    end

    if not isSearching then
        local play = Panorama.GetPanelByName("DOTAPlay", true)
        if play and play:IsValid() and play:HasClass("FindingMatch") then
            isSearching = true
        end
    end

    if not isSearching then
        local btn = Panorama.GetPanelByName("PlayButton", false)
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

local Journey = { Accepted = false, AcceptedAt = nil, Hidden = false }

function Journey.Reset()
    Journey.Accepted = false
    Journey.AcceptedAt = nil
    Journey.FaceUsed = nil
end

function Journey.HiddenPhase()
    if Engine.GetUIState then
        local okU, ui = pcall(Engine.GetUIState)
        if okU and ui == 1 then return true end
    end
    if not GameRules or not GameRules.GetGameState then return false end
    local ok, gs = pcall(GameRules.GetGameState)
    return ok and (gs == 1 or gs == 2 or gs == 3 or gs == 8 or gs == 10) or false
end

function Journey.LineWidth(scale, label, right, hasIcon)
    local f, s = TF("Headline", scale)
    local w = Render.TextSize(f, s, label).x
    if hasIcon then w = w + 20 * scale end
    if right and right ~= "" then
        w = w + 24 * scale + Odometer.Width(f, s, right)
    end
    return w
end

function Journey.IdleTexts()
    return L("di_ui_main_menu"), GetChipContent("clock").text
end

function Journey.SearchTexts()
    local _, timeStr = Impl.GetMatchSearchInfo()
    return L("di_ui_finding_match"), (timeStr and timeStr ~= "") and timeStr or "0:00"
end

local function GetChipStandardWidth(chipId, scale)
    local cfg = HUDCustomizer.WidgetConfigs[chipId] or { showIcon = true }
    local iconW = (cfg.showIcon ~= false) and (20 * scale) or 0
    local c = GetChipContent(chipId)
    local _, s = TF("Headline", scale)
    return math.ceil(iconW + Odometer.Width(c.font, s, c.text))
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

function Impl.IsChipInActiveList(chipId)
    for _, id in ipairs(HUDCustomizer.ActiveChips) do
        if id == chipId then return true end
    end
    return false
end

function Impl.ToggleChipInActiveList(chipId)
    local foundIdx = nil
    for idx, id in ipairs(HUDCustomizer.ActiveChips) do
        if id == chipId then
            foundIdx = idx
            break
        end
    end
    Impl.Wg.Fallback = false
    if foundIdx then
        if #HUDCustomizer.ActiveChips > 1 then
            table.remove(HUDCustomizer.ActiveChips, foundIdx)
        end
    else
        table.insert(HUDCustomizer.ActiveChips, chipId)
    end
    SaveAllConfig()
end

function Impl.CloseEditor()
    HUDCustomizer.IsOpen = false
    HUDCustomizer.InspectedChip = nil
    HUDCustomizer.ColorPickerOpen = false
    HUDCustomizer.RowPress, HUDCustomizer.RowDrag = nil, nil
    SaveAllConfig()
    if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
end

function Impl.GetFountainPosition(hero, courier)
    if CourierTracker.BasePos then
        return CourierTracker.BasePos
    end
    if courier and Entity.IsAlive(courier) and NPC.HasModifier(courier, "modifier_fountain_aura_buff") and not NPC.IsRunning(courier) then
        local pos = Entity.GetAbsOrigin(courier)
        if pos then
            CourierTracker.BasePos = pos
            return pos
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

function Impl.GetLocalCourier()
    if Couriers and Couriers.GetLocal then
        local ok, c = pcall(Couriers.GetLocal)
        if ok and c then
            if not Entity.IsAlive(c) then return nil, true end
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
                local pid = c and Courier and Courier.GetPlayerID and Courier.GetPlayerID(c) or nil
                if myPlayerID and pid and pid == myPlayerID then
                    if not Entity.IsAlive(c) then return nil, true end
                    CourierTracker.CachedCourier = c
                    return c
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

function Impl.CourierQuiet()
    return not ToggleOn(UI and UI.Combat and UI.Combat.CourierSound)
end

function Impl.CourierIsMe(ent, hero)
    if not ent or not hero then return false end
    if ent == hero then return true end
    local a, b = Entity.GetIndex(ent), Entity.GetIndex(hero)
    return a ~= nil and a == b
end

function Impl.CourierHasItems(npc, first, last)
    for i = first, last do
        local it = NPC.GetItemByIndex(npc, i)
        if it then
            local n = Ability.GetName(it)
            if n and n ~= "" then return true end
        end
    end
    return false
end

function Impl.CourierDebug(c, what)
    if not Dbg.On then return end
    local mods = {}
    for _, m in ipairs(NPC.GetModifiers(c) or {}) do
        local ok, name = pcall(Modifier.GetName, m)
        mods[#mods + 1] = ok and tostring(name) or "?"
    end
    Dbg.Log("courier", string.format("%s | state %s, speed %.0f, base speed %s, zone r %s in %s out %s, modifiers: %s", what, tostring(Courier.GetCourierState(c)), NPC.GetMoveSpeed(c) or 0, tostring(NPC.GetBaseSpeed(c)), tostring(CourierTracker.Zone.R), tostring(CourierTracker.Zone.In), tostring(CourierTracker.Zone.Out), table.concat(mods, ", ")))
end

function Impl.CourierBegin(nowClk, viaStash, source)
    local T = CourierTracker
    if T.Delivering and T.Source == source and nowClk - T.DeliveryOrderedTime < 0.5 then return end
    T.Source = source
    T.DeliveryOrderedTime = nowClk
    T.Delivering = true
    T.Delivered = false
    T.Progress = 0.0
    T.ETA = 0
    T.StartDistance = 0
    T.ViaStash = viaStash
    T.IsGoingToStash = viaStash
    T.Carry = 0
    T.OffSince = nil
    T.NearSince = nil
    T.Block = false
    T.GraceUntil = nowClk + 1.0
    T.TowardAt = nowClk
    T.MoveAt = nil
    T.DirectHits = 0
    if Dbg.On then Dbg.Log("courier", "delivery started by " .. source .. (viaStash and ", through the stash" or "")) end
    if StateMachine.TargetState ~= StateMachine.States.COURIER_DELIVERY and StateMachine.TargetState ~= StateMachine.States.COURIER_LARGE then
        TriggerStateTransition(StateMachine.States.COURIER_DELIVERY)
    end
end

function Impl.CourierStop(reason)
    local T = CourierTracker
    if not T.Delivering then return end
    if Dbg.On then Dbg.Log("courier", "delivery dropped: " .. reason) end
    T.Delivering = false
    T.Delivered = false
    T.DeliveryOrderedTime = 0
    T.StartDistance = 0
    T.Progress = 0.0
    T.IsGoingToStash = false
    T.ViaStash = false
    T.Carry = 0
    T.OffSince = nil
    T.NearSince = nil
    T.Block = true
end

function Impl.CourierSegIn(a, b, center, r)
    local dx, dy = b.x - a.x, b.y - a.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 or r <= 0 then return 0, len end
    local ux, uy = dx / len, dy / len
    local mx, my = a.x - center.x, a.y - center.y
    local bq = mx * ux + my * uy
    local disc = bq * bq - (mx * mx + my * my - r * r)
    if disc <= 0 then return 0, len end
    local sq = math.sqrt(disc)
    local t1 = math.max(0, math.min(len, -bq - sq))
    local t2 = math.max(0, math.min(len, -bq + sq))
    return t2 - t1, len
end

function Impl.CourierTravel(cO, hO, basePos, viaBase, speed, inFountain)
    if not cO or not hO or not basePos then return 0, 0 end
    local Z = CourierTracker.Zone
    local r = Z.R or 0
    local inLen, total
    if viaBase then
        local i1, l1 = Impl.CourierSegIn(cO, basePos, basePos, r)
        local i2, l2 = Impl.CourierSegIn(basePos, hO, basePos, r)
        inLen, total = i1 + i2, l1 + l2
    else
        inLen, total = Impl.CourierSegIn(cO, hO, basePos, r)
    end
    local k = Z.Ratio or 1.5
    local inSpeed, outSpeed
    if inFountain then
        inSpeed = speed
        outSpeed = math.min(speed, Z.Out or speed / k)
    else
        outSpeed = speed
        inSpeed = math.max(speed, Z.In or speed * k)
    end
    return inLen / math.max(100, inSpeed) + (total - inLen) / math.max(100, outSpeed), total
end

function Impl.CourierLearnZone(c, distBase, speed, inFountain)
    local Z = CourierTracker.Zone
    local was = Z.WasIn
    Z.WasIn = inFountain
    if was ~= nil and was ~= inFountain and CourierTracker.BasePos and distBase >= 200 and distBase <= 4500 and NPC.IsRunning(c) then
        Z.R = (Z.Guess or not Z.R) and distBase or (Z.R + distBase) / 2
        Z.Guess = nil
        Impl.CourierDebug(c, string.format("fountain speed zone edge at %.0f from the base, zone is now %.0f", distBase, Z.R))
    end
    if inFountain then
        Z.In = speed
    else
        local burst = NPC.GetAbility(c, "courier_burst")
        local since = burst and Ability.SecondsSinceLastUse(burst) or -1
        if since < 0 or since >= 7 then Z.Out = speed end
    end
    if Z.In and Z.Out and Z.Out > 0 and Z.In > Z.Out then Z.Ratio = Z.In / Z.Out end
end

function Impl.ProcessPauseTracker()
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

Impl.CourierAbort = {
    courier_return_to_base = true,
    courier_go_to_secretshop = true,
    courier_go_to_enemy_secretshop = true,
    courier_go_to_sideshop = true,
    courier_go_to_sideshop2 = true,
    courier_take_stash_items = true,
    courier_return_stash_items = true,
    courier_transfer_items_to_other_player = true
}

Impl.CourierManual = {
    [Enum.UnitOrder.DOTA_UNIT_ORDER_STOP] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_DIRECTION] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_PATROL] = true
}

function DynamicIsland.OnPrepareUnitOrders(data)
    if HUDCustomizer.IsOpen and Menu.Opened and Menu.Opened() then
        return false
    end
    if data then
        if data.ability then
            local abName = Ability.GetName(data.ability)
            if abName == "courier_take_stash_and_transfer_items" or abName == "courier_transfer_items" then
                local c = Impl.GetLocalCourier()
                local myHero = HeroData.Local or (Heroes and Heroes.GetLocal and Heroes.GetLocal())
                if c and myHero then
                    local viaStash = abName ~= "courier_transfer_items" and Impl.CourierHasItems(myHero, 9, 14)
                    if viaStash or Impl.CourierHasItems(c, 0, 8) then
                        Impl.CourierBegin(os.clock(), viaStash and not NPC.HasModifier(c, "modifier_fountain_aura_buff"), "order " .. abName)
                    end
                end
            elseif abName and Impl.CourierAbort[abName] then
                Impl.CourierStop("order " .. abName)
            end
        elseif Impl.CourierManual[data.order] then
            local mine = Impl.GetLocalCourier()
            local hit = mine ~= nil and data.npc ~= nil and Impl.CourierIsMe(data.npc, mine)
            if mine and not hit and data.player then
                local ok, sel = pcall(Player.GetSelectedUnits, data.player)
                if ok and type(sel) == "table" then
                    for _, u in ipairs(sel) do
                        if Impl.CourierIsMe(u, mine) then
                            hit = true
                            break
                        end
                    end
                end
            end
            if hit then
                local myHero = HeroData.Local or (Heroes and Heroes.GetLocal and Heroes.GetLocal())
                if Dbg.On then Dbg.Log("courier", "manual order " .. tostring(data.order) .. " on the courier") end
                if data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET and data.target and myHero and Impl.CourierIsMe(data.target, myHero) then
                    Impl.CourierBegin(os.clock(), false, "order to follow the hero")
                else
                    Impl.CourierStop("manual order " .. tostring(data.order))
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

function Impl.ProcessCourierTracker()
    local T = CourierTracker
    if not ToggleOn(UI and UI.Combat and UI.Combat.CourierDelivery) then
        T.Delivering = false
        T.Delivered = false
        T.IsGoingToStash = false
        T.ViaStash = false
        return
    end

    local nowClk = os.clock()

    if T.Delivered and (nowClk - T.DeliveredStartTime) > T.DeliveredDuration then
        T.Delivered = false
        T.IsGoingToStash = false
    end

    local c, dead = Impl.GetLocalCourier()
    if not c or not Entity.IsAlive(c) then
        if dead and T.Delivering then
            if not Impl.CourierQuiet() then HapticPlaySound("courier_death_or_fail", 0.6) end
            Impl.CourierStop("courier died")
        end
        return
    end

    local CS = Enum.CourierState
    local cState = Courier.GetCourierState(c) or 0
    local cTarget = Courier.GetCourierStateEntity(c)
    local myHero = HeroData.Local or (Heroes and Heroes.GetLocal and Heroes.GetLocal())
    local isDeliveringState = cState == CS.COURIER_STATE_DELIVERING_ITEMS
    local isMovingState = cState == CS.COURIER_STATE_MOVING
    local inFountain = NPC.HasModifier(c, "modifier_fountain_aura_buff")

    local cOrigin = Entity.GetAbsOrigin(c)
    if inFountain and cOrigin and not NPC.IsRunning(c) then
        T.BasePos = cOrigin
    end
    local hOrigin = myHero and Entity.GetAbsOrigin(myHero)
    local basePos = Impl.GetFountainPosition(myHero, c)
    local distHero = (cOrigin and hOrigin) and (cOrigin - hOrigin):Length2D() or 0
    local distBase = (cOrigin and basePos) and (cOrigin - basePos):Length2D() or 0
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
                        icon = Impl.GetItemTexturePath(name)
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
                    icon = Impl.GetItemTexturePath(name)
                })
            end
        end
    end

    if itemCount > 0 then
        T.Inventory = items
    elseif hasStashItems and #stashItems > 0 then
        T.Inventory = stashItems
    else
        T.Inventory = items
    end

    T.Hp = Entity.GetHealth(c) or 0
    T.MaxHp = Entity.GetMaxHealth(c) or 1
    T.HpPercent = math.max(0, math.min(1.0, T.Hp / math.max(1, T.MaxHp)))
    T.Speed = speed
    T.CurrentDistance = distHero

    local targetMe = Impl.CourierIsMe(cTarget, myHero)
    local onRoute = itemCount > 0 and ((isDeliveringState and (cTarget == nil or targetMe)) or (isMovingState and targetMe))
    if not onRoute then T.Block = false end

    if Dbg.On and T.DbgState ~= cState then
        T.DbgState = cState
        Impl.CourierDebug(c, string.format("state changed, target %s, %.0f from the hero, %.0f from the base, %d items, %s", cTarget and (targetMe and "me" or "someone else") or "none", distHero, distBase, itemCount, inFountain and "in the fountain" or "outside"))
    end

    Impl.CourierLearnZone(c, distBase, speed, inFountain)

    local approaching = false
    if not T.Delivering and onRoute and cOrigin and hOrigin then
        if T.SeekAt and nowClk - T.SeekAt >= 0.25 and nowClk - T.SeekAt < 1.0 then
            local dx, dy = cOrigin.x - T.SeekX, cOrigin.y - T.SeekY
            local hx, hy = hOrigin.x - T.SeekX, hOrigin.y - T.SeekY
            local moved = math.sqrt(dx * dx + dy * dy)
            local hl = math.sqrt(hx * hx + hy * hy)
            approaching = moved > 20 and hl > 1 and (dx * hx + dy * hy) / (moved * hl) > 0.5
        end
        if not T.SeekAt or nowClk - T.SeekAt >= 0.25 then
            T.SeekAt, T.SeekX, T.SeekY = nowClk, cOrigin.x, cOrigin.y
        end
    else
        T.SeekAt = nil
    end

    if not T.Delivering and not T.Delivered and not T.Block and onRoute and approaching and distHero > 450 and myHero and Entity.IsAlive(myHero) then
        Impl.CourierBegin(nowClk, false, "state")
    end

    if not T.Delivering then return end
    if not cOrigin or not hOrigin then
        Impl.CourierStop("no hero")
        return
    end

    local ordered = nowClk - T.DeliveryOrderedTime
    if T.ViaStash and ordered > 0.3 and (inFountain or not hasStashItems) then
        T.ViaStash = false
        T.GraceUntil = math.max(T.GraceUntil, nowClk + 1.0)
        T.TowardAt = nowClk
        if Dbg.On then Dbg.Log("courier", "stash leg is over, heading to the hero") end
    end
    T.IsGoingToStash = T.ViaStash
    T.Carry = math.max(T.Carry, itemCount)

    if PauseTracker.IsPaused then
        T.TowardAt = nowClk
        T.MoveAt = nil
    elseif not T.MoveAt or nowClk - T.MoveAt >= 0.25 then
        if T.MoveAt and nowClk - T.MoveAt < 1.0 then
            local dx, dy = cOrigin.x - T.MoveX, cOrigin.y - T.MoveY
            local moved = math.sqrt(dx * dx + dy * dy)
            if moved > 20 then
                local hx, hy = hOrigin.x - T.MoveX, hOrigin.y - T.MoveY
                local hl = math.sqrt(hx * hx + hy * hy)
                local toHero = hl > 1 and (dx * hx + dy * hy) / (moved * hl) or 1
                local toBase = -1
                if T.ViaStash and basePos then
                    local bx, by = basePos.x - T.MoveX, basePos.y - T.MoveY
                    local bl = math.sqrt(bx * bx + by * by)
                    toBase = bl > 1 and (dx * bx + dy * by) / (moved * bl) or 1
                end
                if toHero > 0.3 or toBase > 0.3 then T.TowardAt = nowClk end
                if T.ViaStash then
                    T.DirectHits = (toHero > 0.6 and toBase < 0) and (T.DirectHits or 0) + 1 or 0
                    if T.DirectHits >= 6 then
                        T.ViaStash = false
                        T.IsGoingToStash = false
                        if Dbg.On then Dbg.Log("courier", "courier skips the base and flies straight to the hero") end
                    end
                end
            end
        end
        T.MoveAt, T.MoveX, T.MoveY = nowClk, cOrigin.x, cOrigin.y
    end

    local eta, remainingDist = Impl.CourierTravel(cOrigin, hOrigin, basePos, T.IsGoingToStash, speed, inFountain)
    if remainingDist > T.StartDistance then
        T.StartDistance = math.max(remainingDist, 500)
    end
    local prog = 1.0 - (remainingDist / math.max(1, T.StartDistance))
    T.Progress = math.max(T.Progress, math.max(0.0, math.min(1.0, prog)))
    T.ETA = math.ceil(eta)

    local atShop = cState == CS.COURIER_STATE_GOING_TO_SECRET_SHOP or cState == CS.COURIER_STATE_AT_SECRET_SHOP
    if not atShop and nowClk - (T.TowardAt or 0) < 1.5 then
        T.OffSince = nil
    else
        T.OffSince = T.OffSince or nowClk
    end
    if distHero <= 300 and not T.IsGoingToStash then
        T.NearSince = T.NearSince or nowClk
    else
        T.NearSince = nil
    end

    local arrived
    if T.Carry > 0 and itemCount < T.Carry and distHero <= 1200 then
        arrived = "items handed over"
    elseif T.Carry == 0 and T.OffSince and ordered > 1.0 and distHero <= 600 then
        arrived = "courier left the route next to the hero"
    elseif T.NearSince and nowClk - T.NearSince > 1.5 then
        arrived = "courier stays next to the hero"
    end

    if myHero and not Entity.IsAlive(myHero) then
        Impl.CourierStop("hero died")
    elseif arrived then
        if Dbg.On then Dbg.Log("courier", "delivered: " .. arrived) end
        T.Delivering = false
        T.DeliveryOrderedTime = 0
        T.StartDistance = 0
        T.Progress = 1.0
        T.Delivered = true
        T.DeliveredStartTime = nowClk
        T.IsGoingToStash = false
        T.ViaStash = false
        T.Carry = 0
        T.OffSince = nil
        T.NearSince = nil
        T.Block = true
        if ToggleOn(UI and UI.Combat and UI.Combat.CourierFaceID) and not FightTracker.Active and not PauseTracker.IsPaused and Impl.FaceStart("ok", 0.6) then
            Impl.Face.Quiet = Impl.CourierQuiet()
            T.FaceFor = nowClk
            Success.Fired["courier" .. nowClk] = true
            Success.Fired["sat_courier" .. nowClk] = true
        end
        if StateMachine.TargetState ~= StateMachine.States.COURIER_DELIVERED then
            TriggerStateTransition(StateMachine.States.COURIER_DELIVERED)
        end
    elseif T.OffSince and nowClk - T.OffSince > 0.5 and nowClk > T.GraceUntil then
        Impl.CourierStop(string.format("courier is not heading to the %s, state %s, %.0f from the hero", T.IsGoingToStash and "base" or "hero", tostring(cState), distHero))
    elseif ordered > 120.0 then
        Impl.CourierStop("took over two minutes")
    end
end

function Impl.OverIsland(cx, cy)
    if os.clock() - (MouseInput.LiveAt or 0) > 0.25 then return false end
    local l = GetIslandLayout()
    if l and l.w > 0 and l.h > 0 and cx >= l.x - 6 and cx <= l.x + l.w + 6 and cy >= l.y - 6 and cy <= l.y + l.h + 6 then return true end
    local sb = SatelliteBounds
    if sb and cx >= sb.x1 and cx <= sb.x2 and cy >= sb.y1 and cy <= sb.y2 then return true end
    return false
end

function Impl.SwallowClick(data)
    local k = data.key
    if k ~= Enum.ButtonCode.KEY_MOUSE1 and k ~= Enum.ButtonCode.KEY_MOUSE2 then return nil end
    if data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
        MouseInput.Swallow[k] = nil
        if Menu.Opened and Menu.Opened() and not HUDCustomizer.IsOpen then return nil end
        local cx, cy = Input.GetCursorPos()
        if not Impl.OverIsland(cx, cy) then return nil end
        MouseInput.Swallow[k] = true
        if Dbg.On then Dbg.Log("input", string.format("click swallowed %d,%d", cx, cy)) end
        return false
    elseif data.event == Enum.EKeyEvent.EKeyEvent_KEY_UP and MouseInput.Swallow[k] then
        MouseInput.Swallow[k] = nil
        return false
    end
    return nil
end

Impl.Cam = { Next = 0 }

function Impl.CameraMark(value)
    for _, path in ipairs({ "dynamic_island_cam.txt", "scripts/dynamic_island_cam.txt" }) do
        local f = Impl.OpenFile(path, value == nil and "r" or "w")
        if f then
            if value == nil then
                local v = tonumber(f:read("l") or "")
                f:close()
                return v
            end
            f:write(tostring(value))
            f:close()
            return nil
        end
    end
    return nil
end

function Impl.CameraFind(now)
    local H = Impl.Cam
    if H.Mode or now < H.Next then return end
    H.Next = now + 5
    H.Mode = Menu.Find("Info Screen", "Main", "Camera", "Main", "Camera Settings", "Zoom using Wheel")
    if not H.Mode then return end
    H.Plain, H.Keys = nil, nil
    local ok, list = pcall(H.Mode.List, H.Mode)
    if ok and type(list) == "table" then
        local ctrl
        for i, name in ipairs(list) do
            local up = string.upper(tostring(name))
            if string.find(up, "ALT", 1, true) then
                H.Keys = H.Keys or (i - 1)
            elseif string.find(up, "CTRL", 1, true) then
                ctrl = ctrl or (i - 1)
            elseif string.find(up, "WHEEL", 1, true) then
                H.Plain = H.Plain or (i - 1)
            end
        end
        H.Keys = H.Keys or ctrl
        if Dbg.On then Dbg.Log("camera", string.format("umbrella wheel zoom: selected %s, options %s", tostring(H.Mode:Get()), table.concat(list, " | "))) end
    end
    local left = Impl.CameraMark()
    if left and left > 0 then
        if H.Keys and H.Mode:Get() == H.Keys then H.Mode:Set(left - 1) end
        Impl.CameraMark(0)
    end
end

function Impl.CameraOverIsland()
    if not UI or not UI.Main.Enabled:Get() or Journey.Hidden then return false end
    if not (Engine.IsInGame and Engine.IsInGame()) then return false end
    local st = StateMachine.TargetState
    if not IsMediaActive() and st ~= StateMachine.States.LARGE_IDLE and st ~= StateMachine.States.NOTIF_CENTER then return false end
    local lay = GetIslandLayout()
    if not lay or lay.w <= 0 or lay.h <= 0 then return false end
    local mx, my = Input.GetCursorPos()
    return mx >= lay.x - 12 and mx <= lay.x + lay.w + 12 and my >= lay.y - 12 and my <= lay.y + lay.h + 12
end

function Impl.CameraTick()
    local H = Impl.Cam
    local now = os.clock()
    Impl.CameraFind(now)
    if not H.Mode or not H.Keys or not H.Plain then return end
    if Impl.CameraOverIsland() then H.OverAt = now end
    local over = H.OverAt ~= nil and now - H.OverAt < 0.25
    if over and not H.Orig and H.Mode:Get() == H.Plain then
        H.Orig = H.Plain
        H.Mode:Set(H.Keys)
        Impl.CameraMark(H.Orig + 1)
        if Dbg.On then Dbg.Log("camera", "cursor over the island, umbrella wheel zoom needs keys now") end
    elseif not over and H.Orig then
        if H.Mode:Get() == H.Keys then H.Mode:Set(H.Orig) end
        H.Orig = nil
        Impl.CameraMark(0)
        if Dbg.On then Dbg.Log("camera", "cursor left the island, umbrella wheel zoom is back") end
    end
end

function DynamicIsland.OnKeyEvent(data)
    if Hello.Phase then
        if Setup.Capture then return Setup.OnKey(data) end
        if Hello.Blocking() and (data.key == Enum.ButtonCode.KEY_MOUSE1 or data.key == Enum.ButtonCode.KEY_MOUSE2) then
            return false
        end
    end
    if HUDCustomizer.IsOpen and data.key == Enum.ButtonCode.KEY_ESCAPE and data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
        if HUDCustomizer.ColorPickerOpen then
            HUDCustomizer.ColorPickerOpen = false
        elseif HUDCustomizer.InspectedChip then
            HUDCustomizer.InspectedChip = nil
        else
            Impl.CloseEditor()
        end
        if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
        return false
    end
    if HUDCustomizer.IsOpen and Menu.Opened and Menu.Opened() then
        if data.key == Enum.ButtonCode.KEY_MOUSE1 or data.key == Enum.ButtonCode.KEY_MOUSE2 then
            return false
        end
    end
    if UI and UI.Main.Enabled:Get() and Impl.SwallowClick(data) == false then return false end

    local isUp = (data.key == Enum.ButtonCode.KEY_MWHEELUP or data.key == 124 or data.event == Enum.EKeyEvent.EKeyEvent_SCROLL_UP or data.event == 1)
    local isDown = (data.key == Enum.ButtonCode.KEY_MWHEELDOWN or data.key == 125 or data.event == Enum.EKeyEvent.EKeyEvent_SCROLL_DOWN or data.event == 0)

    if isUp or isDown then
        local st = StateMachine.TargetState
        if st == StateMachine.States.LARGE_IDLE or st == StateMachine.States.NOTIF_CENTER then
            local lay = GetIslandLayout()
            local mx, my = Input.GetCursorPos()
            if lay and mx >= lay.x - 12 and mx <= lay.x + lay.w + 12 and my >= lay.y - 12 and my <= lay.y + lay.h + 12 then
                if isDown and st == StateMachine.States.LARGE_IDLE then
                    TriggerStateTransition(StateMachine.States.NOTIF_CENTER)
                elseif isUp and st == StateMachine.States.NOTIF_CENTER then
                    TriggerStateTransition(StateMachine.States.LARGE_IDLE)
                end
                return false
            end
        end
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
                            SendMediaCommand("volup" .. Haptic.WheelQuery(true))
                            if Haptic and Haptic.Trigger then
                                Haptic.Trigger(Haptic.Types.BOUNDARY_BUMP, 1)
                            end
                        end
                    else
                        VolumeState.Target = math.min(100, VolumeState.Target + 4)
                        if (nowClk - (VolumeState.LastSoundTime or 0)) >= 0.038 then
                            VolumeState.LastSoundTime = nowClk
                            SendMediaCommand("volup" .. Haptic.WheelQuery(false))
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
                            SendMediaCommand("voldown" .. Haptic.WheelQuery(true))
                            if Haptic and Haptic.Trigger then
                                Haptic.Trigger(Haptic.Types.BOUNDARY_BUMP, -1)
                            end
                        end
                    else
                        VolumeState.Target = math.max(0, VolumeState.Target - 4)
                        if (nowClk - (VolumeState.LastSoundTime or 0)) >= 0.038 then
                            VolumeState.LastSoundTime = nowClk
                            SendMediaCommand("voldown" .. Haptic.WheelQuery(false))
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

function Impl.NotifHold(cx, cy)
    local S = StateMachine.States
    local st = StateMachine.TargetState
    if st == S.NOTIF_CENTER then return "nc" end
    if HUDCustomizer.IsOpen or Hello.Blocking() or SeekDrag.Active then return "hold" end
    if st == S.LARGE_IDLE or st == S.LARGE_MEDIA or st == S.LARGE_FIGHT or st == S.COURIER_LARGE or st == S.ACTIVITY_LARGE then
        local l = GetIslandLayout()
        if cx >= l.x - 12 and cx <= l.x + l.w + 12 and cy >= l.y - 12 and cy <= l.y + l.h + 12 then return "hold" end
    end
    return nil
end

function Impl.Engaged()
    if Demo.Active or Hello.Blocking() or HUDCustomizer.IsOpen then return false end
    local S = StateMachine.States
    local st = StateMachine.TargetState
    if st ~= S.LARGE_IDLE and st ~= S.LARGE_MEDIA and st ~= S.LARGE_FIGHT and st ~= S.COURIER_LARGE and st ~= S.ACTIVITY_LARGE then return false end
    if SeekDrag.Active then return true end
    local l = GetIslandLayout()
    local cx, cy = Input.GetCursorPos()
    return l ~= nil and cx >= l.x - 12 and cx <= l.x + l.w + 12 and cy >= l.y - 12 and cy <= l.y + l.h + 12
end

function Impl.BubbleAvail()
    return (Engine.IsInGame and Engine.IsInGame()) and UI and UI.Media and UI.Media.SecondaryBubble and UI.Media.SecondaryBubble:Get() and not HUDCustomizer.IsOpen or false
end

function Impl.MatchPrio()
    local w = UI and UI.Priority and UI.Priority.MatchFound
    return w and w:Get() or 4
end

function Impl.MatchAllowed(active)
    if not ToggleOn(UI and UI.Combat and UI.Combat.MatchFound) then return false end
    local p = Impl.MatchPrio()
    if active and (active.Priority or DEFAULT_NOTIF_PRIORITY) > p then return false end
    if StateMachine.TargetState == StateMachine.States.MENU_MATCH_FOUND then return true end
    if Focus.Active and Focus.Blocks({ Priority = p }) then return false end
    if p < 5 and Impl.Engaged() then return false end
    return true
end

function Impl.HoldQueue()
    if Impl.FaceLive() then return true end
    if StateMachine.TargetState == StateMachine.States.MENU_MATCH_FOUND then
        local p = Impl.MatchPrio()
        for _, n in ipairs(NotificationQueue.List) do
            if (n.Priority or DEFAULT_NOTIF_PRIORITY) > p then return false end
        end
        return true
    end
    return Impl.Engaged() and not Impl.BubbleAvail()
end

function Impl.HandleInteractions()
    if not UI or not UI.Main.Enabled:Get() then return end

    local nowClk = os.clock()
    local mediaActive = IsMediaActive()
    local inCombat = FightTracker.Active

    local isLMouseDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1)
    local isRMouseDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE2)
    local isLeftClicked = isLMouseDown and not MouseInput.LeftPressed
    local isRightClicked = isRMouseDown and not MouseInput.RightPressed
    local helloBlock = Hello.Blocking()
    if helloBlock then
        isLeftClicked, isRightClicked = false, false
    end

    MouseInput.LeftPressed = isLMouseDown
    MouseInput.RightPressed = isRMouseDown

    local cx, cy = Input.GetCursorPos()
    if helloBlock then
        cx, cy = -10000, -10000
        isLMouseDown, isRMouseDown = false, false
    end

    if PlaylistPicker.Open then
        if isRightClicked then
            PlaylistPicker.Open = false
        elseif isLeftClicked then
            local bounds = PlaylistPicker.Hits.Bounds
            local close = PlaylistPicker.Hits.Close
            if bounds and (cx < bounds.x1 or cx > bounds.x2 or cy < bounds.y1 or cy > bounds.y2) then
                PlaylistPicker.Open = false
            elseif close and cx >= close.x1 and cx <= close.x2 and cy >= close.y1 and cy <= close.y2 then
                PlaylistPicker.Open = false
            else
                for _, hit in ipairs(PlaylistPicker.Hits.Rows or {}) do
                    if cx >= hit.x1 and cx <= hit.x2 and cy >= hit.y1 and cy <= hit.y2 then
                        if PlaylistPicker.Selected[hit.index] then
                            Impl.RemoveFromPlaylist(hit.index)
                        else
                            Impl.AddToPlaylist(hit.index)
                        end
                        break
                    end
                end
            end
        end
        local wheelUp = Input.IsKeyDown(Enum.ButtonCode.KEY_MWHEELUP)
        local wheelDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MWHEELDOWN)
        if wheelUp and not MouseInput.WheelUp then PlaylistPicker.Offset = math.max(0, PlaylistPicker.Offset - 1) end
        if wheelDown and not MouseInput.WheelDown then PlaylistPicker.Offset = math.min(math.max(0, #PlaylistPicker.Items - 6), PlaylistPicker.Offset + 1) end
        MouseInput.WheelUp = wheelUp
        MouseInput.WheelDown = wheelDown
        return
    end

    if SeekDrag.Active then
        local hit = ButtonHits.MediaSeek
        if hit and hit.x2 > hit.x1 then
            SeekDrag.Frac = math.max(0.0, math.min(1.0, (cx - hit.x1) / (hit.x2 - hit.x1)))
        end
        if not isLMouseDown then
            SeekDrag.Active = false
            if StateMachine.TargetState == StateMachine.States.LARGE_MEDIA and MediaData.Duration > 0 then
                local target = SeekDrag.Frac * MediaData.Duration
                SendMediaCommand(string.format("seek?pos=%.2f", target))
                MediaData.PosTarget = target
                MediaData.PosSmooth = target
                SeekDrag.HoldPos = target
                SeekDrag.HoldStart = nowClk
                SeekDrag.HoldUntil = nowClk + 2.5
                if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
            end
        end
        return
    end

    local isWheelUp = Input.IsKeyDown(Enum.ButtonCode.KEY_MWHEELUP) or Input.IsKeyDown(124)
    local isWheelDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MWHEELDOWN) or Input.IsKeyDown(125)

    local notifHold = Impl.NotifHold(cx, cy)
    if Demo.Active then
    elseif notifHold == "nc" and not NotificationQueue.Active then
        while #NotificationQueue.List > 0 do
            Impl.PopHighestPriorityNotif()
        end
    elseif notifHold == "hold" and not NotificationQueue.Active and not (Impl.Engaged() and Impl.BubbleAvail()) then
    elseif NotificationQueue.Active then
        local elapsed = nowClk - NotificationQueue.StartTime
        if elapsed >= NotificationQueue.Active.Duration then
            if Dbg.On then Dbg.Log("notif", "timed out after " .. tostring(NotificationQueue.Active.Duration) .. "s") end
            NotificationQueue.LastDismissed = NotificationQueue.Active
            NotificationQueue.Active = nil
            if #NotificationQueue.List > 0 and not Impl.HoldQueue() then
                NotificationQueue.Active = Impl.PopHighestPriorityNotif()
                NotificationQueue.StartTime = nowClk
                if not IsNotifDeferred(NotificationQueue.Active) then
                    TriggerStateTransition(StateMachine.States.NOTIFICATION)
                end
            elseif StateMachine.TargetState == StateMachine.States.NOTIFICATION then
                local target = Impl.RestState() or (inCombat and StateMachine.States.COMPACT_FIGHT or (mediaActive and StateMachine.States.COMPACT_MEDIA or StateMachine.States.COMPACT_IDLE))
                TriggerStateTransition(target)
            end
        else
            if StateMachine.TargetState ~= StateMachine.States.NOTIFICATION and not IsNotifDeferred(NotificationQueue.Active) then
                TriggerStateTransition(StateMachine.States.NOTIFICATION)
            end
        end
    elseif #NotificationQueue.List > 0 and not Impl.HoldQueue() then
        NotificationQueue.Active = Impl.PopHighestPriorityNotif()
        NotificationQueue.StartTime = nowClk
        if not IsNotifDeferred(NotificationQueue.Active) then
            TriggerStateTransition(StateMachine.States.NOTIFICATION)
        end
    end

    local isMenuOpen = Menu.Opened and Menu.Opened()
    if not isMenuOpen and HUDCustomizer.IsOpen then
        HUDCustomizer.IsOpen = false
        HUDCustomizer.InspectedChip = nil
    end

    local isCtrlOnly = Input.IsKeyDown(Enum.ButtonCode.KEY_LCONTROL) or Input.IsKeyDown(Enum.ButtonCode.KEY_RCONTROL)
    local layout = GetIslandLayout()

    local playlistHit = ButtonHits.MediaPlaylist
    if isLeftClicked and not isCtrlOnly and not HUDCustomizer.IsOpen and not Demo.Active
        and StateMachine.TargetState == StateMachine.States.LARGE_MEDIA and mediaActive
        and playlistHit and cx >= playlistHit.x1 and cx <= playlistHit.x2
        and cy >= playlistHit.y1 and cy <= playlistHit.y2 then
        ButtonSprings.MediaPlaylist.scale = 0.65
        if Dbg.On then Dbg.Log("playlist", "plus clicked") end
        Impl.OpenPlaylistPicker()
        if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_MEDIUM) end
        return
    end

    local padHit = 6
    local isHover = (cx >= layout.x - padHit and cx <= layout.x + layout.w + padHit and cy >= layout.y - padHit and cy <= layout.y + layout.h + padHit)
    if Dbg.On and isLeftClicked and isHover then
        Dbg.Log("input", string.format("click on the island at %d%% of its width%s", math.floor((cx - layout.x) / math.max(1, layout.w) * 100), isCtrlOnly and " with ctrl" or ""))
    end
    if isLeftClicked and isHover and not isCtrlOnly and not MotionEngine.Reduce and ToggleOn(UI.Haptics.Enabled) and ToggleOn(UI.Haptics.VisualFeedback) then
        local rel = math.max(-1, math.min(1, (cx - (layout.x + layout.w / 2)) / math.max(1, layout.w / 2)))
        local intensity = UI.Haptics.Intensity and (UI.Haptics.Intensity:Get() / 100) or 1
        Haptic.State.VelX = Haptic.State.VelX + rel * 260 * layout.scale * intensity
    end

    if isHover and IsMediaActive() then
        if (nowClk - (MouseInput.LastKeyEventWheelTime or 0)) > 0.15 then
            if isWheelUp and not MouseInput.LastWheelUp then
                if VolumeState.Target >= 100 then
                    VolumeState.Overstretch = math.min(10, (VolumeState.Overstretch or 0) + 2.5)
                    if (nowClk - (VolumeState.LastBumpTime or 0)) >= 0.20 then
                        VolumeState.LastBumpTime = nowClk
                        SendMediaCommand("volup" .. Haptic.WheelQuery(true))
                        if Haptic and Haptic.Trigger then
                            Haptic.Trigger(Haptic.Types.BOUNDARY_BUMP, 1)
                        end
                    end
                else
                    VolumeState.Target = math.min(100, VolumeState.Target + 4)
                    if (nowClk - (VolumeState.LastSoundTime or 0)) >= 0.038 then
                        VolumeState.LastSoundTime = nowClk
                        SendMediaCommand("volup" .. Haptic.WheelQuery(false))
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
                        SendMediaCommand("voldown" .. Haptic.WheelQuery(true))
                        if Haptic and Haptic.Trigger then
                            Haptic.Trigger(Haptic.Types.BOUNDARY_BUMP, -1)
                        end
                    end
                else
                    VolumeState.Target = math.max(0, VolumeState.Target - 4)
                    if (nowClk - (VolumeState.LastSoundTime or 0)) >= 0.038 then
                        VolumeState.LastSoundTime = nowClk
                        SendMediaCommand("voldown" .. Haptic.WheelQuery(false))
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

    if isLeftClicked and not isCtrlOnly then
        local rb = Dbg.Bounds
        if rb and Dbg.On and cx >= rb.x1 and cx <= rb.x2 and cy >= rb.y1 and cy <= rb.y2 then
            Haptic.Trigger(Haptic.Types.TAP_LIGHT)
            Dbg.Reveal()
            return
        end
        local mb = Focus.Bounds
        if mb and cx >= mb.x1 and cx <= mb.x2 and cy >= mb.y1 and cy <= mb.y2 then
            if nowClk - Focus.ClickAt < 0.4 then
                Focus.ClickAt = -10
                Focus.Set(false)
            else
                Focus.ClickAt = nowClk
                Focus.BumpAt = nowClk
                if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
            end
            return
        end
        local fb = Focus.Button
        if fb and StateMachine.TargetState == StateMachine.States.LARGE_IDLE and (nowClk - Focus.ButtonAt) < 0.25
            and cx >= fb.x1 and cx <= fb.x2 and cy >= fb.y1 and cy <= fb.y2 then
            Focus.PressAt = nowClk
            Focus.Set(not Focus.Active, 0.45)
            if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_MEDIUM) end
            return
        end
    end

    local isHoverSatellite = false
    if SatelliteBounds and cx >= SatelliteBounds.x1 and cx <= SatelliteBounds.x2 and cy >= SatelliteBounds.y1 and cy <= SatelliteBounds.y2 then
        isHoverSatellite = true
    end
    FightTracker.SatelliteHover = isHoverSatellite

    if isMenuOpen and isCtrlOnly then
        if isHover and isLMouseDown and not DragState.IsDragging then
            DragState.IsDragging = true
            DragState.Back = nil
            DragState.OffsetX = cx - (layout.x + layout.w / 2)
            DragState.OffsetY = cy - layout.y
        end
    end

    if DragState.IsDragging then
        if not isLMouseDown or not isMenuOpen then
            DragState.IsDragging = false
            local bb = DragState.Bounds
            if bb then
                local tx = math.max(bb[1], math.min(bb[2], DragState.CustomX))
                local ty = math.max(bb[3], math.min(bb[4], DragState.CustomY))
                if tx ~= DragState.CustomX or ty ~= DragState.CustomY then
                    DragState.Back = { x = tx, y = ty, vx = 0, vy = 0 }
                end
            end
            SaveAllConfig()
        else
            local rawX = cx - DragState.OffsetX
            local rawY = cy - DragState.OffsetY
            local scrS = Render.ScreenSize()
            local mid = scrS.x / 2
            local lx1, lx2 = layout.w / 2 + 6, scrS.x - layout.w / 2 - 6
            local ly1, ly2 = 6, scrS.y - layout.h - 6
            local rb = 40 * layout.scale
            if rawX < lx1 then
                rawX = lx1 + Gesture.Rubber(rawX - lx1, rb)
            elseif rawX > lx2 then
                rawX = lx2 + Gesture.Rubber(rawX - lx2, rb)
            end
            if rawY < ly1 then
                rawY = ly1 + Gesture.Rubber(rawY - ly1, rb)
            elseif rawY > ly2 then
                rawY = ly2 + Gesture.Rubber(rawY - ly2, rb)
            end
            DragState.Bounds = { lx1, lx2, ly1, ly2 }
            local snap = math.abs(rawX - mid) <= 14 * layout.scale
            if snap and not DragState.SnapX then Haptic.Silent(Haptic.Types.RATCHET_NOTCH) end
            DragState.SnapX = snap
            DragState.CustomX = math.floor(snap and mid or rawX)
            DragState.CustomY = math.floor(rawY)
            if UI.Main.Preset:Get() ~= 1 then
                UI.Main.Preset:Set(1)
            end
            local st = StateMachine.TargetState
            local S = StateMachine.States
            if st == S.LARGE_IDLE or st == S.LARGE_MEDIA or st == S.LARGE_FIGHT or st == S.COURIER_LARGE or st == S.NOTIF_CENTER or st == S.ACTIVITY_LARGE then
                local target = inCombat and S.COMPACT_FIGHT or (mediaActive and S.COMPACT_MEDIA or S.COMPACT_IDLE)
                TriggerStateTransition(target)
            end
        end
    end

    if isLeftClicked and isHoverSatellite then
        if inCombat or Satellite.Right.kind == "media" then
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
        end
        return
    end

    if isLeftClicked and isHover and StateMachine.TargetState == StateMachine.States.NOTIFICATION and not isCtrlOnly then
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
                if b.id and cx >= b.x1 and cx <= b.x2 and cy >= b.y1 and cy <= b.y2 then
                    HUDCustomizer.InspectedChip = b.id
                    HUDCustomizer.ColorPickerOpen = false
                    clickedDrawerChip = true
                    if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
                    break
                end
            end
            if not clickedDrawerChip then
                Impl.CloseEditor()
            end
        end
    elseif isMenuOpen and HUDCustomizer.IsOpen and isLeftClicked then
        local clickedInspector = false
        for _, b in ipairs(HUDCustomizer.InspectorBounds) do
            if cx >= b.x1 and cx <= b.x2 and cy >= b.y1 and cy <= b.y2 then
                local id = HUDCustomizer.InspectedChip
                local cfg = HUDCustomizer.WidgetConfigs[id]
                if b.action == "done" then
                    Impl.CloseEditor()
                elseif b.action == "back" then
                    HUDCustomizer.InspectedChip = nil
                    HUDCustomizer.ColorPickerOpen = false
                    if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
                elseif cfg and b.action == "set_bold" then
                    cfg.bold = (b.val == 1)
                    SaveAllConfig()
                    if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_MEDIUM) end
                elseif cfg and b.action == "swatch" then
                    cfg.colorMode = b.mode
                    if b.mode == 3 then
                        cfg.customColor = Color(b.r, b.g, b.b, 255)
                        cfg.customHex = b.hex
                    end
                    HUDCustomizer.ColorPickerOpen = false
                    SaveAllConfig()
                    if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
                elseif cfg and b.action == "custom_color" then
                    if cfg.colorMode ~= 3 or not cfg.customColor then
                        local dCol, dHex = GetDefaultWidgetColor(id)
                        cfg.customColor = dCol
                        cfg.customHex = dHex
                    end
                    cfg.colorMode = 3
                    HUDCustomizer.ColorPickerOpen = not HUDCustomizer.ColorPickerOpen
                    SaveAllConfig()
                    if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
                elseif b.action == "toggle_active" then
                    if Impl.IsChipInActiveList(id) and #HUDCustomizer.ActiveChips <= 1 then
                        if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.ERROR) end
                    else
                        Impl.ToggleChipInActiveList(id)
                        if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_MEDIUM) end
                    end
                elseif b.action == "close_color_picker" then
                    HUDCustomizer.ColorPickerOpen = false
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
                end
                clickedInspector = true
                break
            end
        end

        if not clickedInspector then
            if HUDCustomizer.ColorPickerOpen then
                HUDCustomizer.ColorPickerOpen = false
            end
            local hitDrawer = false
            for _, b in ipairs(HUDCustomizer.DrawerBounds) do
                if cx >= b.x1 and cx <= b.x2 and cy >= b.y1 and cy <= b.y2 then
                    hitDrawer = true
                    if b.action == "done" then
                        Impl.CloseEditor()
                    elseif b.action == "remove" or b.action == "add" then
                        Impl.ToggleChipInActiveList(b.id)
                        if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_MEDIUM) end
                    elseif b.action == "row" then
                        HUDCustomizer.RowPress = { id = b.id, y = cy, off = cy - b.y1 }
                    end
                    break
                end
            end

            if not hitDrawer then
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
    end

    local press = HUDCustomizer.RowPress
    if press then
        local geo = HUDCustomizer.EditorGeo
        if not (isMenuOpen and HUDCustomizer.IsOpen) or not geo or HUDCustomizer.InspectedChip then
            HUDCustomizer.RowPress, HUDCustomizer.RowDrag = nil, nil
        elseif not isLMouseDown then
            if HUDCustomizer.RowDrag then
                SaveAllConfig()
            else
                HUDCustomizer.InspectedChip = press.id
                HUDCustomizer.ColorPickerOpen = false
                if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
            end
            HUDCustomizer.RowPress, HUDCustomizer.RowDrag = nil, nil
        else
            if not HUDCustomizer.RowDrag and math.abs(cy - press.y) > 4 * geo.s then
                HUDCustomizer.RowDrag = press.id
                if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
            end
            if HUDCustomizer.RowDrag then
                local relY = cy - press.off - geo.py
                HUDCustomizer.RowDragY = relY
                local list = HUDCustomizer.ActiveChips
                local idx = math.max(1, math.min(#list, math.floor((relY - geo.top) / geo.rowH + 0.5) + 1))
                for i, cid in ipairs(list) do
                    if cid == press.id then
                        if i ~= idx then
                            table.remove(list, i)
                            table.insert(list, idx, cid)
                            if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.RATCHET_NOTCH) end
                        end
                        break
                    end
                end
            end
        end
    end

    if isMenuOpen and HUDCustomizer.IsOpen and (HUDCustomizer.DraggingPopSV or HUDCustomizer.DraggingPopHue or HUDCustomizer.DraggingPopVal) then
        if not isLMouseDown then
            HUDCustomizer.DraggingPopSV = nil
            HUDCustomizer.DraggingPopHue = nil
            HUDCustomizer.DraggingPopVal = nil
            SaveAllConfig()
        else
            if HUDCustomizer.DraggingPopSV then
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
    Focus.Tick(nowClk)
    Journey.Hidden = Journey.HiddenPhase()

    if Demo.Active then
        Demo.Tick(nowClk)
    elseif Journey.Hidden then
        Journey.Reset()
    elseif Impl.FaceLive() then
        if StateMachine.TargetState ~= StateMachine.States.FACE_ID then TriggerStateTransition(StateMachine.States.FACE_ID) end
    elseif Focus.BannerStart <= nowClk and Focus.BannerUntil > nowClk and StateMachine.TargetState ~= StateMachine.States.MENU_MATCH_FOUND then
        if StateMachine.TargetState ~= StateMachine.States.FOCUS_BANNER then
            TriggerStateTransition(StateMachine.States.FOCUS_BANNER)
        end
    elseif not inGame then
        Impl.Pin = nil
        local canAccept = Engine.CanAcceptMatch and Engine.CanAcceptMatch()
        local wantMatch = canAccept or (Journey.AcceptedAt and nowClk - Journey.AcceptedAt < 1.2)
        if not canAccept then Journey.MatchHeld = nil end
        if wantMatch and not Impl.MatchAllowed(NotificationQueue.Active) then
            if canAccept and not Journey.MatchHeld then
                Journey.MatchHeld = true
                if Focus.Active and Focus.Blocks({ Priority = Impl.MatchPrio() }) then Focus.Suppressed = Focus.Suppressed + 1 end
                if Dbg.On then Dbg.Log("notif", "match found is waiting, priority " .. tostring(Impl.MatchPrio())) end
            end
            wantMatch = false
        end
        if not NotificationQueue.Active or wantMatch then
            local detected
            if wantMatch then
                detected = StateMachine.States.MENU_MATCH_FOUND
            else
                local isSearching, searchTime = Impl.GetMatchSearchInfo()
                detected = isSearching and StateMachine.States.MENU_SEARCHING or StateMachine.States.MENU_IDLE
                if isSearching then
                    Impl.MenuSearchAt = nowClk
                    Impl.MenuSearchTime = searchTime
                else
                    Impl.MenuSwap = nil
                    Impl.MenuSearchHidden = nil
                end
            end
            Sheet.MenuSince = Sheet.MenuSince or nowClk
            if detected == StateMachine.States.MENU_IDLE and not Hello.Blocking() and Sheet.Pick(nowClk) then
                detected = StateMachine.States.SHEET
            end
            if detected == StateMachine.States.MENU_IDLE and not Hello.Blocking() and not HUDCustomizer.IsOpen and Sdk.Current() then
                detected = StateMachine.TargetState == StateMachine.States.ACTIVITY_LARGE and StateMachine.States.ACTIVITY_LARGE or StateMachine.States.ACTIVITY
            end
            local overSearch = detected == StateMachine.States.MENU_SEARCHING and not Impl.MenuSwap and ToggleOn(UI and UI.Media and UI.Media.SecondaryBubble)
            if (detected == StateMachine.States.MENU_IDLE or overSearch) and not Hello.Blocking() and not HUDCustomizer.IsOpen and ToggleOn(UI and UI.Media and UI.Media.InMenu) and IsMediaActive() then
                local cur = StateMachine.TargetState
                detected = (cur == StateMachine.States.LARGE_MEDIA or cur == StateMachine.States.NOTIF_CENTER) and cur or StateMachine.States.COMPACT_MEDIA
            end
            if (HUDCustomizer.IsOpen or Hello.Blocking()) and detected ~= StateMachine.States.MENU_MATCH_FOUND then
                detected = StateMachine.States.COMPACT_IDLE
            end
            if detected ~= StateMachine.States.MENU_MATCH_FOUND and StateMachine.TargetState ~= StateMachine.States.MENU_MATCH_FOUND then
                Journey.Reset()
            end
            if detected ~= MenuStateCandidate.state then
                MenuStateCandidate.state = detected
                MenuStateCandidate.since = nowClk
            end

            local stable = detected == StateMachine.States.MENU_MATCH_FOUND or (nowClk - MenuStateCandidate.since) >= 0.3
            if stable and StateMachine.TargetState ~= detected then
                TriggerStateTransition(detected)
            end
        else
            if StateMachine.TargetState ~= StateMachine.States.NOTIFICATION then
                TriggerStateTransition(StateMachine.States.NOTIFICATION)
            end
        end
    else
        Sheet.MenuSince = nil
        if CourierTracker.Delivered and nowClk - CourierTracker.DeliveredStartTime > CourierTracker.DeliveredDuration then
            CourierTracker.Delivered = false
        end
        local plan = Impl.Plan(inCombat, mediaActive, nowClk)
        Impl.PlanList = plan
        local mainKind
        for _, it in ipairs(plan) do
            if Impl.MainKinds[it.kind] then
                mainKind = it.kind
                break
            end
        end
        if Impl.Engaged() then
            local SS, cur = StateMachine.States, StateMachine.TargetState
            local keep = (cur == SS.LARGE_MEDIA and "media") or (cur == SS.LARGE_FIGHT and "fight") or (cur == SS.COURIER_LARGE and "courier") or (cur == SS.ACTIVITY_LARGE and "sdk") or nil
            if keep then
                for _, it in ipairs(plan) do
                    if it.kind == keep then mainKind = keep break end
                end
            end
        end
        Impl.MainKind = mainKind
        local S = StateMachine.States
        local ts = StateMachine.TargetState
        local notif = NotificationQueue.Active
        local desired
        local engaged = Impl.Engaged()
        if not engaged and Sdk.AskInGame(inCombat, nowClk) then
            Sheet.Kind = "sdk_perm"
            desired = S.SHEET
        elseif notif and not IsNotifDeferred(notif) and not engaged then
            desired = S.NOTIFICATION
        elseif mainKind == "pause" then
            desired = S.GAME_PAUSED
        elseif mainKind == "fight" then
            desired = (ts == S.LARGE_FIGHT) and ts or S.COMPACT_FIGHT
        elseif mainKind == "courier" then
            if CourierTracker.Delivered then
                desired = S.COURIER_DELIVERED
            else
                desired = (ts == S.COURIER_LARGE) and ts or S.COURIER_DELIVERY
            end
        elseif mainKind == "sdk" then
            desired = (ts == S.ACTIVITY_LARGE) and ts or S.ACTIVITY
        elseif mainKind == "media" then
            if ts == S.NOTIF_CENTER then
                desired = ts
            elseif ts == S.LARGE_MEDIA or ts == S.LARGE_IDLE then
                desired = S.LARGE_MEDIA
            else
                desired = S.COMPACT_MEDIA
            end
        else
            if ts == S.NOTIF_CENTER then
                desired = ts
            elseif ts == S.LARGE_MEDIA or ts == S.LARGE_IDLE then
                desired = S.LARGE_IDLE
            else
                desired = S.COMPACT_IDLE
            end
        end
        if ts ~= desired then
            TriggerStateTransition(desired)
        end
    end

    if StateMachine.TargetState == StateMachine.States.COMPACT_IDLE then
        local contentW = CalculateIdleContentWidth(layout.scale)
        local targetUnscaled = (contentW / layout.scale) + 26
        Config.Dimensions.CompactTargetW = math.max(80, targetUnscaled)
        Config.Dimensions.CompactTargetH = Config.Dimensions.CompactH
        Config.Dimensions.CompactTargetR = Config.Dimensions.CompactRadius
    elseif StateMachine.TargetState == StateMachine.States.MENU_IDLE
        or StateMachine.TargetState == StateMachine.States.MENU_SEARCHING
        or StateMachine.TargetState == StateMachine.States.MENU_MATCH_FOUND then
        local label, right
        if StateMachine.TargetState == StateMachine.States.MENU_IDLE then
            label, right = Journey.IdleTexts()
        elseif StateMachine.TargetState == StateMachine.States.MENU_SEARCHING then
            label, right = Journey.SearchTexts()
        else
            label = Journey.Accepted and L("di_ui_accepted") or L("di_ui_match_found")
        end
        local contentW = Journey.LineWidth(layout.scale, label, right, true)

        local w = math.ceil(((contentW / layout.scale) + 32) / 4) * 4
        Config.Dimensions.CompactTargetW = math.max(150, w)
        Config.Dimensions.CompactTargetH = Config.Dimensions.CompactH
        Config.Dimensions.CompactTargetR = Config.Dimensions.CompactRadius
    elseif StateMachine.TargetState == StateMachine.States.FOCUS_BANNER then
        local right = Focus.BannerOn and L("di_focus_on") or L("di_focus_off")
        local contentW = Journey.LineWidth(layout.scale, L("di_focus_name"), right, true)
        Config.Dimensions.CompactTargetW = math.max(170, math.ceil(((contentW / layout.scale) + 32) / 4) * 4)
        Config.Dimensions.CompactTargetH = Config.Dimensions.CompactH
        Config.Dimensions.CompactTargetR = Config.Dimensions.CompactRadius
    elseif StateMachine.TargetState == StateMachine.States.FACE_ID then
        Config.Dimensions.CompactTargetW = 56
        Config.Dimensions.CompactTargetH = 56
        Config.Dimensions.CompactTargetR = 16
    elseif StateMachine.TargetState == StateMachine.States.COMPACT_MEDIA then
        Config.Dimensions.CompactTargetW = CompactMediaTitle() and Config.Dimensions.CompactMediaW or Config.Dimensions.CompactMediaBareW
        Config.Dimensions.CompactTargetH = Config.Dimensions.CompactMediaH
        Config.Dimensions.CompactTargetR = Config.Dimensions.CompactMediaRadius
    elseif StateMachine.TargetState == StateMachine.States.COMPACT_FIGHT then
        local fH, sH = TF("Headline", layout.scale)
        local lm = FightTracker.Landmark ~= "" and FightTracker.Landmark or L("di_ui_fight")
        local fw = Odometer.Width(fH, sH, string.format("%d vs %d \u{2022} %s", FightTracker.AllyCount, FightTracker.EnemyCount, lm)) / layout.scale
        Config.Dimensions.CompactTargetW = math.max(Config.Dimensions.CompactFightW, math.min(320, math.ceil((fw + 48) / 4) * 4))
        Config.Dimensions.CompactTargetH = Config.Dimensions.CompactFightH
        Config.Dimensions.CompactTargetR = Config.Dimensions.CompactFightRadius
    elseif StateMachine.TargetState == StateMachine.States.NOTIFICATION and Sdk.Expanded then
        Config.Dimensions.CompactTargetW = 360
        Config.Dimensions.CompactTargetH = Sdk.ExpandH(layout.scale)
        Config.Dimensions.CompactTargetR = 28
    elseif StateMachine.TargetState == StateMachine.States.NOTIFICATION then
        Config.Dimensions.CompactTargetW = Config.Dimensions.NotificationW
        Config.Dimensions.CompactTargetH = Config.Dimensions.NotificationH
        Config.Dimensions.CompactTargetR = Config.Dimensions.NotificationRadius
    elseif StateMachine.TargetState == StateMachine.States.LARGE_MEDIA then
        Config.Dimensions.CompactTargetW = Config.Dimensions.LargeMediaW
        Config.Dimensions.CompactTargetH = Config.Dimensions.LargeMediaH + (Impl.LyWant() and Impl.LyH or 0)
        Config.Dimensions.CompactTargetR = Config.Dimensions.LargeMediaRadius
    elseif StateMachine.TargetState == StateMachine.States.LARGE_FIGHT then
        Config.Dimensions.CompactTargetW = (UI and UI.Combat and UI.Combat.FightLargeW) and UI.Combat.FightLargeW:Get() or Config.Dimensions.LargeFightW
        Config.Dimensions.CompactTargetH = (UI and UI.Combat and UI.Combat.FightLargeH) and UI.Combat.FightLargeH:Get() or Config.Dimensions.LargeFightH
        Config.Dimensions.CompactTargetR = Config.Dimensions.LargeFightRadius
    elseif StateMachine.TargetState == StateMachine.States.SHEET then
        local sw, sh = Sheet.Size()
        Config.Dimensions.CompactTargetW = sw
        Config.Dimensions.CompactTargetH = sh
        Config.Dimensions.CompactTargetR = 28
    elseif StateMachine.TargetState == StateMachine.States.NOTIF_CENTER then
        Config.Dimensions.CompactTargetW = Config.Dimensions.LargeW
        Config.Dimensions.CompactTargetH = NotifCenter.Height()
        Config.Dimensions.CompactTargetR = 28
    elseif StateMachine.TargetState == StateMachine.States.LARGE_IDLE then
        Config.Dimensions.CompactTargetW = Config.Dimensions.LargeW
        Config.Dimensions.CompactTargetH = Config.Dimensions.LargeH
        Config.Dimensions.CompactTargetR = Config.Dimensions.LargeRadius
    elseif StateMachine.TargetState == StateMachine.States.GAME_PAUSED then
        local fB, sB = TF("Body", layout.scale)
        local fH, sH = TF("Headline", layout.scale)
        local elapsed = PauseTracker.PauseStartTime > 0 and math.floor(os.clock() - PauseTracker.PauseStartTime) or 0
        local pText = L("di_island_paused")
        local timeText = string.format("%d:%02d", math.floor(elapsed / 60), elapsed % 60)
        local w1 = Render.TextSize(fB, sB, pText).x
        local wDot = Render.TextSize(fB, sB, " \u{2022} ").x
        local w2 = Odometer.Width(fH, sH, timeText)
        local totalContentW = 12 * layout.scale + 16 * layout.scale + 8 * layout.scale + w1 + wDot + w2 + 16 * layout.scale
        Config.Dimensions.CompactTargetW = math.max(120, math.floor(totalContentW / layout.scale))
        Config.Dimensions.CompactTargetH = Config.Dimensions.GamePausedH
        Config.Dimensions.CompactTargetR = Config.Dimensions.GamePausedRadius
    elseif StateMachine.TargetState == StateMachine.States.COURIER_DELIVERY then
        Config.Dimensions.CompactTargetW = Config.Dimensions.CourierDeliveryW
        Config.Dimensions.CompactTargetH = Config.Dimensions.CourierDeliveryH
        Config.Dimensions.CompactTargetR = Config.Dimensions.CourierDeliveryRadius
    elseif StateMachine.TargetState == StateMachine.States.COURIER_DELIVERED then
        local fH, sH = TF("Headline", layout.scale)
        local txt = L("di_courier_delivered")
        local tSize = Render.TextSize(fH, sH, txt)
        Config.Dimensions.CompactTargetW = math.max(160, (tSize.x / layout.scale) + 60)
        Config.Dimensions.CompactTargetH = Config.Dimensions.CourierDeliveredH
        Config.Dimensions.CompactTargetR = Config.Dimensions.CourierDeliveredRadius
    elseif StateMachine.TargetState == StateMachine.States.ACTIVITY then
        Config.Dimensions.CompactTargetW = Sdk.CompactW(layout.scale)
        Config.Dimensions.CompactTargetH = Config.Dimensions.CourierDeliveryH
        Config.Dimensions.CompactTargetR = Config.Dimensions.CourierDeliveryRadius
    elseif StateMachine.TargetState == StateMachine.States.ACTIVITY_LARGE then
        Config.Dimensions.CompactTargetW = 340
        Config.Dimensions.CompactTargetH = Sdk.LargeH()
        Config.Dimensions.CompactTargetR = 28
    elseif StateMachine.TargetState == StateMachine.States.COURIER_LARGE then
        Config.Dimensions.CompactTargetW = Config.Dimensions.CourierLargeW
        Config.Dimensions.CompactTargetH = Config.Dimensions.CourierLargeH
        Config.Dimensions.CompactTargetR = Config.Dimensions.CourierLargeRadius
    end

    if isLeftClicked and not isCtrlOnly and not Demo.Active then
        local hits = (StateMachine.TargetState == StateMachine.States.SHEET and Sheet.Hits) or (StateMachine.TargetState == StateMachine.States.NOTIF_CENTER and NotifCenter.Hits) or nil
        if hits then
            for _, h in ipairs(hits) do
                if cx >= h.x1 and cx <= h.x2 and cy >= h.y1 and cy <= h.y2 then
                    Sheet.Action(h.action, nowClk)
                    Haptic.Trigger(Haptic.Types.TAP_MEDIUM)
                    return
                end
            end
        elseif isHover and StateMachine.TargetState == StateMachine.States.MENU_IDLE and Sheet.BadgeOn() then
            Sheet.Dismissed = false
            Sheet.MenuSince = nowClk - 2
            Haptic.Trigger(Haptic.Types.TAP_MEDIUM)
            return
        end
    end

    if HUDCustomizer.IsOpen or Demo.Active or DragState.IsDragging then return end

    local holdMode = UI.Main.ExpandMode and UI.Main.ExpandMode:Get() == 1
    local openOnHover = not holdMode
    local hoverDelaySec = 0.10
    local expandable = StateMachine.TargetState == StateMachine.States.COMPACT_FIGHT or StateMachine.TargetState == StateMachine.States.COURIER_DELIVERY
        or StateMachine.TargetState == StateMachine.States.COMPACT_IDLE or StateMachine.TargetState == StateMachine.States.COMPACT_MEDIA
        or StateMachine.TargetState == StateMachine.States.ACTIVITY
        or (StateMachine.TargetState == StateMachine.States.NOTIFICATION and Sdk.CanExpand() and not Sdk.Expanded)

    if holdMode then
        if isLeftClicked and isHover and not isCtrlOnly and expandable then
            StateMachine.PressAt = nowClk
            StateMachine.Spring.Squish.value = -0.12
            StateMachine.Spring.Squish.vel = -0.8
            Haptic.Silent(Haptic.Types.TAP_LIGHT)
        end
        if StateMachine.PressAt and (not isLMouseDown or not isHover or not expandable) then
            StateMachine.PressAt = nil
        end
        if StateMachine.PressAt and nowClk - StateMachine.PressAt >= 0.35 then
            StateMachine.PressAt = nil
            openOnHover = true
            hoverDelaySec = 0
            StateMachine.HoverStartTime = nowClk
        end
    end

    if isHover and not isCtrlOnly then
        if not StateMachine.IsHovered then
            StateMachine.IsHovered = true
            StateMachine.HoverStartTime = nowClk
            if not holdMode and Haptic and Haptic.Trigger then
                Haptic.Trigger(Haptic.Types.TAP_LIGHT)
            end
        end
        StateMachine.UnhoverStartTime = 0

        if openOnHover and not StateMachine.NoExpand then
            if StateMachine.TargetState == StateMachine.States.COMPACT_FIGHT then
                if (nowClk - StateMachine.HoverStartTime) >= hoverDelaySec then
                    TriggerStateTransition(StateMachine.States.LARGE_FIGHT)
                end
            elseif StateMachine.TargetState == StateMachine.States.COURIER_DELIVERY then
                if (nowClk - StateMachine.HoverStartTime) >= hoverDelaySec then
                    TriggerStateTransition(StateMachine.States.COURIER_LARGE)
                end
            elseif StateMachine.TargetState == StateMachine.States.NOTIFICATION then
                if not Sdk.Expanded and Sdk.CanExpand() and (nowClk - StateMachine.HoverStartTime) >= hoverDelaySec then
                    Sdk.Expand(nowClk)
                end
            elseif StateMachine.TargetState == StateMachine.States.ACTIVITY then
                if (nowClk - StateMachine.HoverStartTime) >= hoverDelaySec then
                    TriggerStateTransition(StateMachine.States.ACTIVITY_LARGE)
                    Sdk.ExpandedAt = nowClk
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
        StateMachine.NoExpand = nil

        if Sdk.Expanded and StateMachine.UnhoverStartTime > 0 and (nowClk - StateMachine.UnhoverStartTime) >= 0.22 then
            Sdk.Expanded = false
        end

        do
            if StateMachine.TargetState == StateMachine.States.LARGE_FIGHT then
                if StateMachine.UnhoverStartTime > 0 and (nowClk - StateMachine.UnhoverStartTime) >= 0.22 then
                    TriggerStateTransition(StateMachine.States.COMPACT_FIGHT)
                end
            elseif StateMachine.TargetState == StateMachine.States.COURIER_LARGE then
                if StateMachine.UnhoverStartTime > 0 and (nowClk - StateMachine.UnhoverStartTime) >= 0.22 then
                    TriggerStateTransition(StateMachine.States.COURIER_DELIVERY)
                end
            elseif StateMachine.TargetState == StateMachine.States.ACTIVITY_LARGE then
                if StateMachine.UnhoverStartTime > 0 and (nowClk - StateMachine.UnhoverStartTime) >= 0.22 then
                    TriggerStateTransition(StateMachine.States.ACTIVITY)
                end
            elseif StateMachine.TargetState == StateMachine.States.LARGE_MEDIA or StateMachine.TargetState == StateMachine.States.LARGE_IDLE or StateMachine.TargetState == StateMachine.States.NOTIF_CENTER then
                if StateMachine.UnhoverStartTime > 0 and (nowClk - StateMachine.UnhoverStartTime) >= 0.22 then
                    local nextC = mediaActive and StateMachine.States.COMPACT_MEDIA or StateMachine.States.COMPACT_IDLE
                    TriggerStateTransition(nextC)
                end
            end
        end
    end

    if isLeftClicked and isHover and not isCtrlOnly and StateMachine.TargetState == StateMachine.States.MENU_MATCH_FOUND then
        if Engine.AcceptMatch and not Journey.Accepted then
            local ok = pcall(Engine.AcceptMatch, 1)
            if ok then
                Journey.Accepted = true
                Journey.AcceptedAt = os.clock()
                if ToggleOn(UI and UI.Combat and UI.Combat.MatchFaceID) and Impl.FaceStart("ok", 0.9) then Journey.FaceUsed = true end
            elseif Haptic and Haptic.Trigger then
                Haptic.Trigger(Haptic.Types.ERROR)
            end
        end
    end

    if isLeftClicked and isHover and not isCtrlOnly and mediaActive
        and StateMachine.TargetState == StateMachine.States.LARGE_MEDIA and (not StateMachine.Transition.Active or StateMachine.Transition.Progress > 0.9) then
        local h = ButtonHits.MediaSeek
        if h and cx >= h.x1 - 4 and cx <= h.x2 + 4 and cy >= h.y1 and cy <= h.y2 then
            SeekDrag.Active = true
            SeekDrag.Frac = math.max(0.0, math.min(1.0, (cx - h.x1) / math.max(1, h.x2 - h.x1)))
            return
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
            elseif StateMachine.TargetState == StateMachine.States.LARGE_MEDIA and Impl.Ly.Btn > 0.5 and ButtonHits.MediaLyrics and cx >= ButtonHits.MediaLyrics.x1 and cx <= ButtonHits.MediaLyrics.x2 and cy >= ButtonHits.MediaLyrics.y1 and cy <= ButtonHits.MediaLyrics.y2 then
                ButtonSprings.MediaLyrics.scale = 0.75
                Impl.Ly.Open = not Impl.Ly.Open
                if Dbg.On then Dbg.Log("media", "lyrics " .. (Impl.Ly.Open and "opened" or "closed")) end
                SaveAllConfig()
                clickedButton = true
            elseif StateMachine.TargetState == StateMachine.States.LARGE_MEDIA and Impl.LyHitAt(cx, cy) then
                local t = Impl.LyHitAt(cx, cy)
                SendMediaCommand(string.format("seek?pos=%.2f", t))
                MediaData.PosTarget = t
                MediaData.PosSmooth = t
                SeekDrag.HoldPos = t
                SeekDrag.HoldStart = nowClk
                SeekDrag.HoldUntil = nowClk + 2.5
                if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
                clickedButton = true
            elseif ButtonHits.MediaLike and cx >= ButtonHits.MediaLike.x1 and cx <= ButtonHits.MediaLike.x2 and cy >= ButtonHits.MediaLike.y1 and cy <= ButtonHits.MediaLike.y2 then
                ButtonSprings.MediaLike.scale = 0.65
                local likeApp = string.lower(MediaData.App or "")
                local inYandex = string.find(likeApp, "yandex", 1, true) ~= nil and string.find(likeApp, "music", 1, true) ~= nil
                local inSpotify = string.find(likeApp, "spotify", 1, true) ~= nil
                if (BridgeStatus.SpotifyDebug == "closed" and inSpotify) or (BridgeStatus.YandexDebug == "closed" and inYandex) then
                    DynamicIsland.PushNotification({
                        Type = "spotify_like",
                        Tag = inYandex and L("di_ui_yandex_music") or "Spotify",
                        Title = L("di_ui_likes_unavailable"),
                        Subtitle = inYandex and L("di_ui_restart_yandex") or L("di_ui_restart_spotify"),
                        AccentColor = Color(255, 159, 10, 255),
                        IconType = "svg",
                        FallbackSvg = "heart_outline"
                    })
                    return
                end
                local trackKey = MediaData.LastTrackKey
                SendMediaCommand("like", function(ok, res)
                    if not ok then
                        DynamicIsland.PushNotification({
                            Type = "spotify_like",
                            Tag = inYandex and L("di_ui_yandex_music") or "Spotify",
                            Title = L("di_ui_likes_unavailable"),
                            Subtitle = L("di_ui_like_failed"),
                            AccentColor = Color(255, 159, 10, 255),
                            IconType = "svg",
                            FallbackSvg = "heart_outline"
                        })
                        return
                    end
                    local isNowLiked = string.find(res.response, '"is_liked"%s*:%s*true') ~= nil
                    if trackKey == MediaData.LastTrackKey then
                        MediaData.IsLiked = isNowLiked
                        MediaData.LikedTracks[trackKey] = isNowLiked
                    end
                    DynamicIsland.PushNotification({
                        Type = "spotify_like",
                        Tag = inYandex and L("di_ui_yandex_music") or "Spotify",
                        Title = isNowLiked and L("di_ui_liked_songs") or L("di_ui_removed_from_favorites"),
                        Subtitle = isNowLiked and L("di_ui_saved_to_library") or (inYandex and L("di_ui_removed_from_yandex") or L("di_ui_removed_from_spotify")),
                        AccentColor = Color(255, 55, 95, 255),
                        IconType = "svg",
                        FallbackSvg = isNowLiked and "heart_fill" or "heart_outline",
                        Duration = 2.5
                    })
                end)
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
    local baseCol = customColor or MediaTint()
    local baseFreqs = { 3.2, 4.8, 6.1, 4.9, 7.4 }
    local phaseOffsets = { 0.41, 1.93, 3.52, 5.18, 1.15 }
    local harmonicMults = { 1.618, 1.414, 1.732, 1.528, 1.667 }
    local beat = (math.sin(now * 4.2) * 0.28 + 0.72)
    local volMul = math.max(0.45, math.min(1.0, ((MediaData.Volume or 100) / 100.0)))
    local live = isPlaying and MediaData.Level and MediaData.LevelAt and (now - MediaData.LevelAt) < 0.5

    for i = 1, count do
        local bx = math.floor(x + (i - 1) * (barW + barGap))
        local targetH = 2.0 * scale

        if live then
            local lv = math.max(0, math.min(1, MediaData.Level[i] or 0))
            local wgt = Impl.WaveWeights[i] or 0.8
            targetH = (2.2 + (0.16 + 0.84 * lv) * wgt * (maxH - 3.2)) * scale
        elseif isPlaying then
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

        local col = FadeColor(Color(baseCol.r, baseCol.g, baseCol.b, 255), aMul)
        local cornerR = math.max(1, math.floor(barW / 2))

        Render.FilledRect(Vec2(bx, by), Vec2(bx + barW, by + intH), col, cornerR)
    end
end

local function Glyph(name, cx, cy, sz, col)
    local g = GetVectorIcon(name)
    if g and sz > 0 then Impl.DrawIcon(g, cx - sz / 2, cy - sz / 2, sz, sz, col) end
end

local function SoftShadow(p1, p2, r, col, thick, off)
    local w, h = p2.x - p1.x, p2.y - p1.y
    if w <= 0 or h <= 0 then return end
    local flags = Enum.DrawFlags.ShadowCutOutShapeBackground
    off = off or Vec2(0, 0)
    r = math.max(0, math.min(r or 0, w / 2, h / 2))
    if r < 1 or not Render.ShadowConvexPoly then
        Render.Shadow(p1, p2, col, thick, r, flags, off)
        return
    end
    if math.abs(w - h) < 1 and r >= w / 2 - 0.5 then
        Render.ShadowCircle(Vec2(p1.x + w / 2, p1.y + h / 2), r, col, thick, 32, flags, off)
        return
    end
    local pts = {}
    local corners = { { p2.x - r, p1.y + r, -90 }, { p2.x - r, p2.y - r, 0 }, { p1.x + r, p2.y - r, 90 }, { p1.x + r, p1.y + r, 180 } }
    for _, c in ipairs(corners) do
        for i = 0, 8 do
            local ang = math.rad(c[3] + 90 * i / 8)
            local px, py = c[1] + math.cos(ang) * r, c[2] + math.sin(ang) * r
            local last = pts[#pts]
            if not last or math.abs(last.x - px) + math.abs(last.y - py) > 0.05 then
                pts[#pts + 1] = Vec2(px, py)
            end
        end
    end
    local first, last = pts[1], pts[#pts]
    if math.abs(first.x - last.x) + math.abs(first.y - last.y) <= 0.05 then pts[#pts] = nil end
    Render.ShadowConvexPoly(pts, col, thick, flags, off)
end

local TruncateCache = {}
local function TruncateToWidth(font, size, text, maxW)
    local key = tostring(font) .. "|" .. text .. "|" .. math.floor(size * 10) .. "|" .. math.floor(maxW)
    local hit = TruncateCache[key]
    if hit then return hit end
    local result = text
    if Render.TextSize(font, size, text).x > maxW then
        local chars = {}
        for ch in string.gmatch(text, "[\0-\x7F\xC2-\xF4][\x80-\xBF]*") do
            chars[#chars + 1] = ch
        end
        result = "…"
        for n = #chars - 1, 1, -1 do
            local candidate = (string.gsub(table.concat(chars, "", 1, n), "%s+$", "")) .. "…"
            if Render.TextSize(font, size, candidate).x <= maxW then
                result = candidate
                break
            end
        end
    end
    TruncateCache[key] = result
    return result
end

local Marquee = { Runs = {}, Glyphs = {}, GlyphCount = 0 }

function Marquee.Layout(font, size, text)
    local key = font .. ":" .. size .. ":" .. text
    local g = Marquee.Glyphs[key]
    if g then return g end
    if Marquee.GlyphCount > 48 then
        Marquee.Glyphs = {}
        Marquee.GlyphCount = 0
    end
    g = {}
    local prefix = ""
    for ch in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do
        local x0 = #prefix > 0 and Render.TextSize(font, size, prefix).x or 0
        prefix = prefix .. ch
        g[#g + 1] = { ch = ch, x0 = x0, x1 = Render.TextSize(font, size, prefix).x }
    end
    Marquee.Glyphs[key] = g
    Marquee.GlyphCount = Marquee.GlyphCount + 1
    return g
end

local function RenderMarqueeText(font, size, text, boxX, boxY, boxW, color, scale, holdArg, once, key)
    local fullSize = Render.TextSize(font, size, text)
    local ix = math.floor(boxX)
    local iy = math.floor(boxY)
    local iw = math.floor(boxW)

    if fullSize.x <= iw then
        Render.Text(font, size, text, Vec2(ix, iy), color)
        return
    end

    local now = os.clock()
    local runKey = key or text
    local run = Marquee.Runs[runKey]
    if not run or now - run.seen > 0.5 then
        run = { t0 = now }
        Marquee.Runs[runKey] = run
    end
    run.seen = now

    local speed = (UI and UI.Media and UI.Media.MarqueeSpeed) and UI.Media.MarqueeSpeed:Get() or 45
    local gap = math.floor(math.max(28 * scale, iw * 0.2))
    local totalCycle = fullSize.x + gap
    local hold = holdArg or 2.2
    local offset, atEnd
    if once then
        local travel = math.ceil(fullSize.x - iw)
        offset = math.floor(math.max(0, math.min(travel, (now - run.t0 - hold) * speed)))
        atEnd = offset >= travel
    else
        local phase = (now - run.t0) % (hold + totalCycle / speed)
        offset = phase < hold and 0 or math.floor((phase - hold) * speed)
    end

    local fadeW = math.floor(14 * scale)
    local leftFade = math.min(1, offset / math.max(1, fadeW))
    if not once and offset > totalCycle - fadeW then leftFade = math.max(0, (totalCycle - offset) / math.max(1, fadeW)) end
    local glyphs = Marquee.Layout(font, size, text)
    local baseA = color.a or 255
    local right = ix + iw

    Render.PushClip(Vec2(ix, iy - 2), Vec2(right, iy + fullSize.y + 4))
    for copy = 0, once and 0 or 1 do
        local ox = ix - offset + copy * totalCycle
        if ox < right and ox + fullSize.x > ix then
            for _, gl in ipairs(glyphs) do
                local gx0, gx1 = ox + gl.x0, ox + gl.x1
                if gx1 > ix and gx0 < right then
                    local mid = (gx0 + gx1) / 2
                    local a = 1
                    if once then
                        local gw = math.max(1, gx1 - gx0)
                        if gx0 < ix then a = math.max(0, (gx1 - ix) / gw) end
                        if gx1 > right then a = math.min(a, math.max(0, (right - gx0) / gw)) end
                    else
                        if mid > right - fadeW then a = math.max(0, (right - mid) / fadeW) end
                        if mid < ix + fadeW then a = math.min(a, 1 - leftFade * (1 - math.max(0, (mid - ix) / fadeW))) end
                    end
                    if a > 0.01 then
                        Render.Text(font, size, gl.ch, Vec2(math.floor(gx0), iy), Color(color.r, color.g, color.b, math.floor(baseA * a)))
                    end
                end
            end
        end
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

    local function Placeholder(a)
        if a <= 0.01 then return end
        Render.FilledRect(Vec2(ix, iy), Vec2(ix + isz, iy + isz), FadeColor(Config.Colors.Placeholder, a), ir)
        Glyph("music", ix + isz / 2, iy + isz / 2, math.floor(isz * 0.5), FadeColor(Color(142, 142, 147, 255), a))
    end

    local imgH = customHandle or MediaData.CoverImageHandle
    if imgH and imgH > 0 then
        local fadeIn = 1.0
        if not customHandle then
            local since = os.clock() - (MediaData.CoverHandleSetAt or 0)
            fadeIn = math.max(0.0, math.min(1.0, since / 0.25))
        end
        if fadeIn < 1.0 then Placeholder(aMul * (1.0 - fadeIn)) end
        Impl.Img(imgH, Vec2(ix, iy), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), aMul * fadeIn), ir)
    else
        Placeholder(aMul)
    end
end

function Journey.DrawLine(layout, aMul, yOff, drawIcon, label, labelCol, right, rightCol, rightId)
    local scale = layout.scale
    local f, s = TF("Headline", scale)
    local padX = math.floor(16 * scale)
    local midY = math.floor(layout.y + layout.h / 2 + yOff)
    local iconSz = math.floor(14 * scale)
    local x = math.floor(layout.x + padX)
    drawIcon(x, midY, iconSz)
    x = x + iconSz + math.floor(6 * scale)
    local sL = Render.TextSize(f, s, label)
    local ty = math.floor(midY - sL.y / 2 + MenuTextOffsetY * scale)
    Render.Text(f, s, label, Vec2(x, ty), FadeColor(labelCol, aMul))
    if right and right ~= "" then
        local rw = Odometer.Width(f, s, right)
        Odometer.Text(rightId, f, s, right, Vec2(math.floor(layout.x + layout.w - padX - rw), ty), FadeColor(rightCol, aMul))
    end
end

function Journey.Spinner(cx, cy, r, col, aMul)
    local n = 8
    local step = math.floor(os.clock() * 10) % n
    local w = math.max(1.5, r * 0.28)
    for i = 0, n - 1 do
        local ang = math.rad(i * 360 / n - 90)
        local age = (step - i) % n
        local a = 1 - age / n * 0.75
        local c, s = math.cos(ang), math.sin(ang)
        local p1 = Vec2(cx + c * r * 0.42, cy + s * r * 0.42)
        local p2 = Vec2(cx + c * (r - w / 2), cy + s * (r - w / 2))
        local colA = FadeColor(col, aMul * a)
        Render.Line(p1, p2, colA, w)
        Render.FilledCircle(p1, w / 2, colA, 0, 1.0, 8)
        Render.FilledCircle(p2, w / 2, colA, 0, 1.0, 8)
    end
end

function Journey.RenderIdle(layout, alphaMul, yOffset)
    local aMul = alphaMul or 1.0
    local label, right = Journey.IdleTexts()
    Journey.DrawLine(layout, aMul, yOffset or 0, function(x, midY, sz)
        local h = GetVectorIcon("home")
        if h then
            Impl.Img(h, Vec2(x, math.floor(midY - sz / 2 + MenuIconOffsetY * layout.scale)), Vec2(sz, sz), FadeColor(Config.Colors.TextSecondary, aMul), 0)
        end
    end, label, Config.Colors.TextSecondary, right, Config.Colors.TextPrimary, "journey_clock")
end

function Journey.RenderSearching(layout, alphaMul, yOffset)
    local aMul = alphaMul or 1.0
    local label, right = Journey.SearchTexts()
    Journey.DrawLine(layout, aMul, yOffset or 0, function(x, midY, sz)
        Journey.Spinner(x + sz / 2, midY, sz * 0.5, Config.Colors.TextPrimary, aMul)
    end, label, Config.Colors.TextPrimary, right, Config.Colors.Blue, "journey_search")
end

function Journey.RenderMatchFound(layout, alphaMul, yOffset)
    local aMul = alphaMul or 1.0
    local scale = layout.scale
    local sucT = Journey.AcceptedAt and (os.clock() - Journey.AcceptedAt) or 99
    local label = Journey.Accepted and L("di_ui_accepted") or L("di_ui_match_found")
    Journey.DrawLine(layout, aMul, yOffset or 0, function(x, midY, sz)
        local c = Vec2(x + sz / 2, midY)
        local r = sz / 2 + 1 * scale
        if sucT < 1.2 and not Journey.FaceUsed then
            Success.Draw("accept" .. tostring(Journey.AcceptedAt), c, r, sucT, aMul, scale)
            return
        end
        Render.FilledCircle(c, r, FadeColor(Config.Colors.Green, aMul), 0, 1.0, 32)
        local h = GetVectorIcon("check")
        local isz = math.floor(r * 1.3)
        if h then
            Impl.Img(h, Vec2(math.floor(c.x - isz / 2), math.floor(c.y - isz / 2)), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), aMul), 0)
        end
    end, label, Config.Colors.TextPrimary)
end

local function RenderModularIdlePill(layout, alphaMul, yOffset)
    local aMul = alphaMul or 1.0
    local yOff = yOffset or 0
    local scale = layout.scale
    local _, s = TF("Headline", scale)
    local renderedChips = {}

    for idx, id in ipairs(HUDCustomizer.ActiveChips) do
        local c = GetChipContent(id)
        local chipW = GetChipStandardWidth(id, scale)
        table.insert(renderedChips, { id = id, isClock = c.isClock, svgKey = c.svgKey, text = c.text, font = c.font, color = FadeColor(c.color, aMul), width = chipW })
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

        local refSize = Render.TextSize(chip.font, s, "0123456789")
        local ty = math.floor(midY - refSize.y / 2 + MenuTextOffsetY * scale)
        local odoId = "chip_" .. chip.id
        local soft = chip.id == "fps" or chip.id == "ping"
        if chip.svgKey then
            local iconHandle = GetVectorIcon(chip.svgKey)
            local iconSz = math.floor(14 * scale)
            local iconY = math.floor(midY - iconSz / 2 + MenuIconOffsetY * scale)
            if iconHandle then
                Impl.Img(iconHandle, Vec2(drawX, iconY), Vec2(iconSz, iconSz), chip.color, 0)
            end
            Odometer.Text(odoId, chip.font, s, chip.text, Vec2(drawX + math.floor(20 * scale), ty), chip.color, soft)
        else
            Odometer.Text(odoId, chip.font, s, chip.text, Vec2(drawX, ty), chip.color, soft)
        end
        curX = curX + chip.width

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
    local a = math.max(0.0, math.min(1.0, aMul or 1.0))
    if (IsPureGlass() or UI.Media.Blur:Get()) and a > 0.01 then
        Render.Blur(p1, p2, 1.0, a, radius, Enum.DrawFlags.None)
    end
    if not IsPureGlass() then
        local bg = UI.Main.IslandBgColor:Get()
        local opacity = UI.Main.BgOpacity:Get() / 100
        Render.FilledRect(p1, p2, Color(bg.r, bg.g, bg.b, math.floor((bg.a or 255) * opacity * a)), radius)
    end
    local curBorder = borderCol
    if StateMachine.TargetState == StateMachine.States.MENU_MATCH_FOUND then
        local g = Config.Colors.Green
        curBorder = Color(g.r, g.g, g.b, 150)
    end
    Render.Rect(p1, p2, FadeColor(curBorder, a), radius, Enum.DrawFlags.None, thickness or 1.0)
end

local function DrawerSurface(p1, p2, radius, aMul)
    if IsPureGlass() then
        if aMul > 0.01 then
            Render.Blur(p1, p2, 1.0, aMul, radius, Enum.DrawFlags.None)
        end
    else
        local bg = UI.Main.IslandBgColor:Get()
        Render.FilledRect(p1, p2, FadeColor(Color(bg.r, bg.g, bg.b, 255), aMul), radius)
    end
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

function Odometer.Natural(font, size, str)
    local key = str .. "|" .. size .. "|" .. tostring(font)
    local w = Odometer.Widths[key]
    if not w then
        if Odometer.WidthCount > 3000 then
            Odometer.Widths, Odometer.WidthCount = {}, 0
        end
        w = Render.TextSize(font, size, str).x
        Odometer.Widths[key] = w
        Odometer.WidthCount = Odometer.WidthCount + 1
    end
    return w
end

function Odometer.DigitW(font, size)
    local key = size .. "|" .. tostring(font)
    local w = Odometer.Digit[key]
    if not w then
        w = 0
        for d = 0, 9 do
            w = math.max(w, Render.TextSize(font, size, tostring(d)).x)
        end
        Odometer.Digit[key] = w
    end
    return w
end

function Odometer.Chars(str)
    local t = {}
    for ch in string.gmatch(str, "[\0-\x7F\xC2-\xF4][\x80-\xBF]*") do
        t[#t + 1] = ch
    end
    return t
end

function Odometer.Layout(font, size, text)
    local key = text .. "|" .. size .. "|" .. tostring(font)
    local lay = Odometer.Layouts[key]
    if lay then return lay end
    if Odometer.LayoutCount > 2000 then
        Odometer.Layouts, Odometer.LayoutCount = {}, 0
    end
    local cells, runs = {}, {}
    local x, runStart, run = 0, 0, ""
    local dw = Odometer.DigitW(font, size)
    local tab = Odometer.Tabular(text)
    local function flush()
        if run ~= "" then
            runs[#runs + 1] = { text = run, x = runStart }
            x = runStart + Odometer.Natural(font, size, run)
            run = ""
        end
    end
    for _, ch in ipairs(Odometer.Chars(text)) do
        if tab and string.match(ch, "^%d$") then
            flush()
            local off = (dw - Odometer.Natural(font, size, ch)) / 2
            cells[#cells + 1] = { ch = ch, x = x, off = off }
            runs[#runs + 1] = { text = ch, x = x + off }
            x = x + dw
        else
            if run == "" then runStart = x end
            cells[#cells + 1] = { ch = ch, x = runStart + Odometer.Natural(font, size, run), off = 0 }
            run = run .. ch
        end
    end
    flush()
    lay = { cells = cells, runs = runs, w = x }
    Odometer.Layouts[key] = lay
    Odometer.LayoutCount = Odometer.LayoutCount + 1
    return lay
end

function Odometer.Group(n)
    local s = tostring(math.floor(math.abs(n or 0)))
    local sep = L("di_num_sep")
    local out, len = "", #s
    for i = 1, len do
        out = out .. string.sub(s, i, i)
        local left = len - i
        if left > 0 and left % 3 == 0 then out = out .. sep end
    end
    return ((n or 0) < 0 and "-" or "") .. out
end

function Odometer.Tabular(text)
    return string.find(text, "%d") ~= nil and string.find(text, "/") == nil
end

function Odometer.Width(font, size, text)
    if not Odometer.Tabular(text) then return Odometer.Natural(font, size, text) end
    return Odometer.Layout(font, size, text).w
end

function Odometer.Draw(font, size, text, pos, col)
    if not Odometer.Tabular(text) then
        Render.Text(font, size, text, pos, col)
        return
    end
    for _, r in ipairs(Odometer.Layout(font, size, text).runs) do
        Render.Text(font, size, r.text, Vec2(math.floor(pos.x + r.x + 0.5), pos.y), col)
    end
end

function Odometer.Text(id, font, size, text, pos, col, soft)
    if not id then
        Odometer.Draw(font, size, text, pos, col)
        return
    end
    local now = os.clock()
    local st = Odometer.States[id]
    if not st then
        st = { cur = text, prev = nil, t0 = 0, dir = 1, seen = now }
        Odometer.States[id] = st
    elseif now - (st.seen or now) > 0.15 then
        st.cur, st.prev = text, nil
    elseif st.cur ~= text then
        local a = tonumber((string.gsub(st.cur, "%D", "")))
        local b = tonumber((string.gsub(text, "%D", "")))
        st.dir = (a and b and b < a) and -1 or 1
        st.prev, st.cur, st.t0 = st.cur, text, now
    end
    st.seen = now
    soft = soft or MotionEngine.Reduce
    local p = (now - st.t0) / (soft and 0.2 or 0.42)
    if not st.prev or p >= 1 then
        st.prev = nil
        Odometer.Draw(font, size, text, pos, col)
        return
    end
    local e = EaseOutCubic(p)
    local lh = Render.TextSize(font, size, "0").y
    local shift = soft and 0 or lh * 0.95
    local alpha = col.a or 255
    local oldCol = Color(col.r, col.g, col.b, math.floor(alpha * (1 - e)))
    local newCol = Color(col.r, col.g, col.b, math.floor(alpha * e))
    local newL, oldL = Odometer.Layout(font, size, text), Odometer.Layout(font, size, st.prev)
    local wMax = math.max(newL.w, oldL.w)
    Render.PushClip(Vec2(pos.x - 2, pos.y), Vec2(pos.x + wMax + 2, pos.y + lh), true)
    if #newL.cells == #oldL.cells then
        for i, cN in ipairs(newL.cells) do
            local cO = oldL.cells[i]
            if cN.ch == cO.ch then
                Render.Text(font, size, cN.ch, Vec2(math.floor(pos.x + cN.x + cN.off + 0.5), pos.y), col)
            else
                Render.Text(font, size, cO.ch, Vec2(math.floor(pos.x + cO.x + cO.off + 0.5), pos.y - st.dir * shift * e), oldCol)
                Render.Text(font, size, cN.ch, Vec2(math.floor(pos.x + cN.x + cN.off + 0.5), pos.y + st.dir * shift * (1 - e)), newCol)
            end
        end
    else
        Odometer.Draw(font, size, st.prev, Vec2(pos.x, pos.y - st.dir * shift * e), oldCol)
        Odometer.Draw(font, size, text, Vec2(pos.x, pos.y + st.dir * shift * (1 - e)), newCol)
    end
    Render.PopClip()
end

function Success.Draw(id, c, r, t, a, scale)
    local green = Config.Colors.Green
    local thick = math.max(1.5, 2 * scale)
    if t < 0.35 then
        local k = t / 0.35
        local e = (k < 0.5) and (4 * k * k * k) or (1 - ((-2 * k + 2) ^ 3) / 2)
        Render.Circle(c, r, FadeColor(Config.Colors.FillTertiary, a), thick, 0, 1.0, false, 48)
        if e > 0.002 then
            Render.Circle(c, r, FadeColor(green, a), thick, 270, e, true, 48)
        end
        return
    end
    if t > 0.72 then
        local bk = math.min(1, (t - 0.72) / 0.4)
        if bk < 1 then
            Render.FilledCircle(c, r * (1 + 0.7 * bk), FadeColor(Color(green.r, green.g, green.b, math.floor(90 * (1 - bk))), a), 0, 1.0, 48)
        end
    end
    local fk = math.min(1, (t - 0.35) / 0.18)
    Render.FilledCircle(c, math.max(0, r * EaseOutBack(fk)), FadeColor(green, a), 0, 1.0, 48)
    local ck = math.max(0, math.min(1, (t - 0.40) / 0.35))
    if ck > 0 then
        local p0 = Vec2(c.x - 0.40 * r, c.y + 0.02 * r)
        local p1 = Vec2(c.x - 0.12 * r, c.y + 0.30 * r)
        local p2 = Vec2(c.x + 0.42 * r, c.y - 0.28 * r)
        local lw = math.max(1.5, r * 0.19)
        local white = FadeColor(Color(255, 255, 255, 255), a)
        local f1 = math.min(1, ck / 0.4)
        local e1 = Vec2(p0.x + (p1.x - p0.x) * f1, p0.y + (p1.y - p0.y) * f1)
        Render.Line(p0, e1, white, lw)
        Render.FilledCircle(p0, lw / 2, white, 0, 1.0, 12)
        Render.FilledCircle(e1, lw / 2, white, 0, 1.0, 12)
        if ck > 0.4 then
            local k2 = (ck - 0.4) / 0.6
            local f2 = 1 - (1 - k2) ^ 3
            local e2 = Vec2(p1.x + (p2.x - p1.x) * f2, p1.y + (p2.y - p1.y) * f2)
            Render.Line(p1, e2, white, lw)
            Render.FilledCircle(e2, lw / 2, white, 0, 1.0, 12)
        end
    end
    if t >= 0.75 and not Success.Fired[id] then
        Success.Fired[id] = true
        local quiet = string.find(id, "courier", 1, true) ~= nil and Impl.CourierQuiet()
        if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.SUCCESS_APPLE_PAY, quiet) end
    end
end

Impl.Face = { At = nil, Result = "ok", Scan = 1, Total = 0, Fired = false }

function Impl.FaceLive()
    local F = Impl.Face
    return F.At ~= nil and (os.clock() - F.At) * 1.5 / AnimScale() < F.Total
end

function Impl.FaceT()
    local F = Impl.Face
    return F.At and (os.clock() - F.At) * 1.5 / AnimScale() or nil
end

function Impl.FaceStart(result, scan)
    local F = Impl.Face
    if Impl.FaceLive() then return false end
    F.At = os.clock()
    F.Result = result == "fail" and "fail" or "ok"
    F.Scan = math.max(0.4, math.min(3, scan or 1))
    F.Total = 0.4 + F.Scan + (F.Result == "ok" and 1.0 or 0.9)
    F.Fired = false
    F.Quiet = false
    return true
end

function Impl.FacePoly(pts, col, th)
    for i = 1, #pts - 1 do Render.Line(pts[i], pts[i + 1], col, th) end
    local joints = (col.a or 255) >= 250
    if joints then
        for i = 1, #pts do Render.FilledCircle(pts[i], th / 2, col, 0, 1.0, 10) end
    end
end

function Impl.RenderFaceID(layout, alphaMul, yOffset)
    local F = Impl.Face
    local t = Impl.FaceT() or 0
    local am = alphaMul or 1
    local C = Config.Colors
    local S = math.min(layout.w, layout.h)
    local cx, cy = layout.x + layout.w / 2, layout.y + layout.h / 2 + (yOffset or 0)
    local ok = F.Result == "ok"
    local reduce = MotionEngine.Reduce
    local tRes = 0.4 + F.Scan
    local function cl(v) return math.max(0, math.min(1, v)) end
    local rk = cl((t - tRes) / 0.25)
    local white = Color(255, 255, 255, 255)
    local tint = ok and C.Green or C.Red
    local col = FadeColor(LerpColor(white, tint, rk), am)
    local oxF, oxB, sc = 0, 0, 1
    if t >= 0.4 and t < tRes and not reduce then
        oxF = math.sin((t - 0.4) * 6.5) * 0.012 * S
    end
    if t >= tRes then
        local dt = t - tRes
        if not reduce then
            if ok then
                sc = 1 + 0.08 * math.sin(math.pi * cl(dt / 0.4))
            elseif dt < 0.5 then
                local sh = math.sin(dt * 46) * 0.07 * S * (1 - dt / 0.5)
                oxF, oxB = sh, sh
            end
        end
        if not F.Fired then
            F.Fired = true
            if Haptic and Haptic.Trigger then Haptic.Trigger(ok and Haptic.Types.SUCCESS_APPLE_PAY or Haptic.Types.ERROR, ok and F.Quiet == true) end
        end
    end
    local function P(px, py, ox) return Vec2(cx + (ox or 0) + px * S * sc, cy + py * S * sc) end
    local th = math.max(1.6, S * 0.042 * sc)
    local intro = 1 - (1 - cl((t - 0.12) / 0.35)) ^ 3
    local bracketFade = ok and (1 - cl((t - tRes) / 0.2)) or 1
    local bs = (1.2 - 0.2 * intro) * (ok and (1 - 0.14 * cl((t - tRes) / 0.2)) or 1)
    local bA = am * intro * bracketFade
    if bA > 0.01 then
        local bcol = FadeColor(LerpColor(white, tint, ok and 0 or rk), bA)
        local hs, rr, L = 0.235 * bs, 0.075 * bs, 0.075 * bs
        local function corner(ccx, ccy, a0, a1)
            local pts = {}
            local r0, r1 = math.rad(a0), math.rad(a1)
            pts[1] = P(ccx + rr * math.cos(r0) + L * math.sin(r0), ccy + rr * math.sin(r0) - L * math.cos(r0), oxB)
            for i = 0, 8 do
                local a = r0 + (r1 - r0) * i / 8
                pts[#pts + 1] = P(ccx + rr * math.cos(a), ccy + rr * math.sin(a), oxB)
            end
            pts[#pts + 1] = P(ccx + rr * math.cos(r1) - L * math.sin(r1), ccy + rr * math.sin(r1) + L * math.cos(r1), oxB)
            Impl.FacePoly(pts, bcol, th)
        end
        corner(-hs + rr, -hs + rr, 180, 270)
        corner(hs - rr, -hs + rr, 270, 360)
        corner(hs - rr, hs - rr, 0, 90)
        corner(-hs + rr, hs - rr, 90, 180)
    end
    if ok and t >= tRes then
        local rk2 = 1 - (1 - cl((t - tRes) / 0.4)) ^ 3
        if rk2 > 0.01 then
            Render.Circle(P(0, 0.005, 0), 0.245 * S * sc, col, th, 270, rk2, true, 56)
        end
    end
    local k2, k3, k4 = cl((t - 0.30) / 0.2), cl((t - 0.42) / 0.24), cl((t - 0.52) / 0.32)
    if k2 > 0 then
        local half = 0.03 * (1 - (1 - k2) ^ 3)
        for _, ex in ipairs({ -0.105, 0.105 }) do
            Impl.FacePoly({ P(ex, -0.05 - half, oxF), P(ex, -0.05 + half, oxF) }, col, th)
        end
    end
    if k3 > 0 then
        local pts = { P(0.022, -0.075, oxF) }
        local endY = -0.075 + (0.02 + 0.075) * math.min(1, k3 / 0.6)
        pts[2] = P(0.022, endY, oxF)
        local hk = math.max(0, (k3 - 0.6) / 0.4)
        if hk > 0 then
            for i = 1, 6 do
                local a = math.rad(i * 15 * hk)
                pts[#pts + 1] = P(-0.013 + 0.035 * math.cos(a), 0.02 + 0.035 * math.sin(a), oxF)
            end
        end
        Impl.FacePoly(pts, col, th)
    end
    if k4 > 0 then
        local grow = ok and rk or 0
        local sweep = (104 + 14 * grow) * (1 - (1 - k4) ^ 3)
        Render.Circle(P(0, 0.03, oxF), 0.105 * S * sc, col, th, 38 - 7 * grow, sweep / 360, true, 24)
    end
end

function Rampage.Tick()
    local on = UI and UI.Combat and UI.Combat.RampageTimer and UI.Combat.RampageTimer:Get()
    local left = 18 - (GameRules.GetGameTime() - Rampage.LastKill)
    Rampage.Left = left
    if left <= 0 then Rampage.Count = 0 end
    local me = HeroData.Local
    if not on or Rampage.Count ~= 4 or left <= 0 or not me then
        Rampage.Active = false
        return
    end
    local myPos = Entity.GetAbsOrigin(me)
    local best, bestD = nil, nil
    for _, h in pairs(Heroes.GetAll()) do
        if h and not Entity.IsSameTeam(me, h) and Entity.IsAlive(h) and not (NPC.IsIllusion and NPC.IsIllusion(h)) then
            local p = Entity.GetAbsOrigin(h)
            local d = (p.x - myPos.x) ^ 2 + (p.y - myPos.y) ^ 2
            if not bestD or d < bestD then best, bestD = h, d end
        end
    end
    Rampage.Active = best ~= nil
    if best then
        local raw = NPC.GetUnitName(best)
        if raw and raw ~= "" then Rampage.Target = raw end
    end
end

function Satellite.Step(id, want, wide)
    local now = os.clock()
    local st = Satellite.S[id]
    if not st then
        st = { p = 0, pv = 0, w = 0, wv = 0, clk = now }
        Satellite.S[id] = st
    end
    local dt = math.min(0.05, math.max(0.001, now - st.clk)) / AnimScale()
    st.clk = now
    local keep = want or st.w > 0.2
    st.p, st.pv = SolveDampedSpring(st.p, st.pv, keep and 1 or 0, dt, 11.0, 0.64)
    local wideT = (want and wide and st.p > 0.55) and 1 or 0
    st.w, st.wv = SolveDampedSpring(st.w, st.wv, wideT, dt, 8.0, 0.74)
    return st
end

function Satellite.Draw(layout, st, side, fullW, content, shift)
    local p = st.p
    if p < 0.01 then return nil end
    local scale = layout.scale
    local rm = MotionEngine.Reduce
    local pg = rm and 1 or p
    local rowY, bh = Focus.SatRow(layout)
    local cy = rowY + bh / 2
    local d = bh * (0.34 + 0.66 * math.min(pg, 1.12))
    local w = d + math.max(0, fullW - bh) * math.max(0, math.min(1.08, st.w))
    local gap = 8 * scale
    local edge = (side > 0) and (layout.x + layout.w) or layout.x
    local travel = (gap + d / 2) * pg - d / 2
    local x1 = (side > 0) and (edge + travel) or (edge - travel - w)
    if side > 0 then x1 = x1 + Swipe.SatX end
    if shift then x1 = x1 + side * shift end
    x1 = math.floor(x1 + 0.5)
    local y1 = math.floor(cy - d / 2 + 0.5)
    local x2 = x1 + math.floor(w + 0.5)
    local y2 = y1 + math.floor(d + 0.5)
    local a = rm and math.min(1, p) or math.min(1, p * 3)
    if p < 0.6 and not rm and not IsPureGlass() then
        local k = 1 - p / 0.6
        local nh = bh * 0.46 * k * k
        if nh > 1 then
            local nx1 = (side > 0) and (edge - 2 * scale) or (x2 - d / 2)
            local nx2 = (side > 0) and (x1 + d / 2) or (edge + 2 * scale)
            local bg = UI.Main.IslandBgColor:Get()
            Render.FilledRect(Vec2(math.floor(nx1), math.floor(cy - nh / 2)), Vec2(math.floor(nx2), math.floor(cy + nh / 2)), FadeColor(Color(bg.r, bg.g, bg.b, bg.a or 255), a), math.floor(nh / 2))
        end
    end
    local p1, p2 = Vec2(x1, y1), Vec2(x2, y2)
    local r = math.floor((y2 - y1) / 2)
    if UI.Media.Shadow:Get() then
        SoftShadow(p1, p2, r, FadeColor(Config.Colors.Shadow, a), 12, Vec2(0, 3))
    end
    IslandSurface(p1, p2, r, Config.Colors.Border, nil, a)
    local ca = math.max(0, math.min(1, (p - 0.45) / 0.35)) * a
    local ta = math.max(0, math.min(1, (st.w - 0.55) / 0.35)) * a
    Render.PushClip(p1, p2, true)
    content(x1, y1, x2, y2, y2 - y1, ca, ta)
    Render.PopClip()
    return { x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
end

function Focus.SatRow(layout)
    local scale = layout.scale
    local compactH = math.floor(Config.Dimensions.CompactH * scale + 0.5)
    local targetH = math.floor((Config.Dimensions.CompactTargetH or Config.Dimensions.CompactH) * scale + 0.5)
    local refH, parityH = compactH, compactH
    if targetH <= compactH * 1.4 then
        refH, parityH = layout.h, targetH
    end
    local bh = math.floor(compactH * 0.88)
    if (parityH - bh) % 2 == 1 then bh = bh - 1 end
    return math.floor(layout.y + refH / 2 - bh / 2 + 0.5), bh
end

function Focus.MoonColor()
    local now = os.clock()
    local dtm = math.min(0.1, math.max(0, now - (Focus.TintClk or now)))
    Focus.TintClk = now
    local want = Focus.Accent
    if UI and UI.Focus and UI.Focus.MoonTint and UI.Focus.MoonTint:Get() and IsMediaActive() and MediaData.IsPlaying then
        want = MediaTint()
    end
    Focus.TintCol = Focus.TintCol and LerpColor(Focus.TintCol, want, math.min(1, dtm * 5)) or want
    return Focus.TintCol
end

function Focus.RenderBubble(layout)
    local ts = StateMachine.TargetState
    local want = Focus.Active and not HUDCustomizer.IsOpen and ts ~= StateMachine.States.FOCUS_BANNER and ts ~= StateMachine.States.MENU_MATCH_FOUND
    local sat = Satellite.Step("moon", want, false)
    local _, bh = Focus.SatRow(layout)
    local scale = layout.scale
    Focus.Bounds = Satellite.Draw(layout, sat, -1, bh, function(x1, y1, x2, y2, d, ca)
        if ca <= 0.01 then return end
        local now = os.clock()
        local c = Vec2((x1 + x2) / 2, (y1 + y2) / 2)
        local bt = now - Focus.BumpAt
        local bump = 1 - 0.14 * math.exp(-bt * 9) * math.cos(bt * 22)
        local accent = Focus.MoonColor()
        Render.FilledCircle(c, d * 0.30, FadeColor(Color(accent.r, accent.g, accent.b, 38), ca), 0, 1.0, 32)
        local isz = math.floor(d * 0.52 * bump)
        local h = GetVectorIcon("moon")
        if h then
            Impl.Img(h, Vec2(math.floor(c.x - isz / 2), math.floor(c.y - isz / 2)), Vec2(isz, isz), FadeColor(accent, ca), 0)
        end
        if Focus.Until > Focus.StartedAt then
            local frac = math.max(0, math.min(1, (Focus.Until - now) / (Focus.Until - Focus.StartedAt)))
            local rr = d / 2 - 2.5 * scale
            local rt = math.max(1.2, 1.5 * scale)
            Render.Circle(c, rr, FadeColor(Config.Colors.FillTertiary, ca), rt, 0, 1.0, false, 48)
            if frac > 0.002 then
                Render.Circle(c, rr, FadeColor(accent, ca), rt, 270, frac, true, 48)
            end
        end
    end)
end

function Focus.RenderBanner(layout, alphaMul, yOffset)
    local aMul = alphaMul or 1.0
    local on = Focus.BannerOn
    Journey.DrawLine(layout, aMul, yOffset or 0, function(x, midY, sz)
        local h = GetVectorIcon("moon")
        if h then
            local t = math.max(0, os.clock() - Focus.BannerStart)
            local e = EaseOutBack(math.min(1, t / 0.5))
            local a = math.min(1, t / 0.25)
            local s2 = math.floor(sz * (0.55 + 0.45 * e))
            local dy = math.floor((1 - e) * 5 * layout.scale)
            Impl.Img(h, Vec2(math.floor(x + (sz - s2) / 2), math.floor(midY - s2 / 2 + dy)), Vec2(s2, s2), FadeColor(on and Focus.Accent or Config.Colors.TextSecondary, aMul * a), 0)
        end
    end, L("di_focus_name"), Config.Colors.TextPrimary, on and L("di_focus_on") or L("di_focus_off"), on and Focus.Accent or Config.Colors.TextMuted)
end

function Focus.RenderTile(layout, x1, x2, y1, aMul)
    local scale = layout.scale
    local now = os.clock()
    local on = Focus.Active
    local dtl = math.min(0.05, math.max(0, now - (Focus.TileClk or now)))
    Focus.TileClk = now
    Focus.TileVis = (Focus.TileVis or 0) + ((on and 1 or 0) - (Focus.TileVis or 0)) * math.min(1, dtl * 11)
    local tv = math.min(1, math.max(0, Focus.TileVis))
    local tileH = math.floor(26 * scale)
    local pt = now - Focus.PressAt
    local press = 1 - 0.07 * math.exp(-pt * 11) * math.cos(pt * 24)
    local cxT = (x1 + x2) / 2
    local cyT = y1 + tileH / 2
    local w = (x2 - x1) * press
    local hh = tileH * press
    local q1 = Vec2(math.floor(cxT - w / 2), math.floor(cyT - hh / 2))
    local q2 = Vec2(math.floor(cxT + w / 2), math.floor(cyT + hh / 2))
    Render.FilledRect(q1, q2, FadeColor(LerpColor(Config.Colors.FillSecondary, Config.Colors.TextPrimary, tv), aMul), math.floor(hh / 2))
    local cr = math.floor(hh / 2 - 3 * scale)
    local cc = Vec2(math.floor(q1.x + hh / 2), math.floor(cyT))
    Render.FilledCircle(cc, cr, FadeColor(LerpColor(Config.Colors.Fill, Focus.Accent, tv), aMul), 0, 1.0, 24)
    local isz = math.floor(cr * 1.15)
    local moon = GetVectorIcon("moon")
    if moon then
        Impl.Img(moon, Vec2(math.floor(cc.x - isz / 2), math.floor(cc.y - isz / 2)), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), aMul), 0)
    end
    local f, s = TF("FootnoteEm", scale)
    local label = L("di_focus_name")
    local ls = Render.TextSize(f, s, label)
    local textCol = LerpColor(Config.Colors.TextPrimary, Config.Colors.TextInverse, tv)
    Render.Text(f, s, label, Vec2(math.floor(cc.x + cr + 7 * scale), math.floor(cyT - ls.y / 2)), FadeColor(textCol, aMul))
    if on then
        local right = Focus.Until > 0 and FormatTime(math.max(0, Focus.Until - now)) or L("di_focus_on")
        local rw = Odometer.Width(f, s, right)
        Odometer.Text("focus_tile", f, s, right, Vec2(math.floor(q2.x - 10 * scale - rw), math.floor(cyT - ls.y / 2)), FadeColor(Focus.Accent, aMul * tv))
    end
    Focus.Button = { x1 = x1, y1 = y1, x2 = x2, y2 = y1 + tileH }
    Focus.ButtonAt = now
end

function Impl.RenderSegmented(x, y, w, h, items, sel, spring, dt, scale, aMul, action)
    local n = #items
    spring.v, spring.vel = MotionEngine.Step(spring.v, spring.vel, sel - 1, dt, "SNAPPY")
    local rT = math.floor(h * 0.3)
    local rK = math.floor((h - 4) * 0.28)
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), FadeColor(Config.Colors.SegTrack, aMul), rT)
    local segW = w / n
    local tx = x + 2 + spring.v * segW
    SoftShadow(Vec2(tx, y + 2), Vec2(tx + segW - 4, y + h - 2), rK, Color(0, 0, 0, math.floor(60 * aMul)), 5, Vec2(0, 1))
    Render.FilledRect(Vec2(tx, y + 2), Vec2(tx + segW - 4, y + h - 2), FadeColor(Config.Colors.SegThumb, aMul), rK)
    for i, it in ipairs(items) do
        local act = (i == sel)
        local f, s = TF("Caption", scale)
        if act then f = Config.Fonts.Semibold end
        local ts = Render.TextSize(f, s, L(it.label))
        Render.Text(f, s, L(it.label), Vec2(math.floor(x + (i - 1) * segW + (segW - ts.x) / 2), math.floor(y + (h - ts.y) / 2)), FadeColor(act and Config.Colors.TextPrimary or Config.Colors.TextSecondary, aMul))
        if aMul > 0.6 then
            table.insert(HUDCustomizer.InspectorBounds, { x1 = x + (i - 1) * segW, y1 = y, x2 = x + i * segW, y2 = y + h, action = action, val = it.val })
        end
    end
end

function Impl.RenderSwitch(x, y, w, h, on, spring, dt, aMul)
    spring.v, spring.vel = MotionEngine.Step(spring.v, spring.vel, on and 1 or 0, dt, "SNAPPY")
    local t = math.min(1, math.max(0, spring.v))
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), FadeColor(LerpColor(Config.Colors.Fill, Config.Colors.Green, t), aMul), h / 2)
    local kr = h / 2 - 2
    local kc = Vec2(x + 2 + kr + (w - 4 - kr * 2) * t, y + h / 2)
    SoftShadow(Vec2(kc.x - kr, kc.y - kr), Vec2(kc.x + kr, kc.y + kr), kr, Color(0, 0, 0, math.floor(70 * aMul)), 5, Vec2(0, 1.5))
    Render.FilledCircle(Vec2(x + 2 + kr + (w - 4 - kr * 2) * t, y + h / 2), kr, FadeColor(Color(255, 255, 255, 255), aMul), 0, 1.0, 24)
end

Impl.SEG_WEIGHT = { { label = "di_drawer_bold", val = 1 }, { label = "di_drawer_regular", val = 2 } }
Impl.SEG_FORMAT = { { label = "di_drawer_standard", val = 1 }, { label = "di_drawer_minimal", val = 2 }, { label = "di_drawer_detailed", val = 3 } }

Impl.CHIP_TINT = { clock = "Orange", kda = "Red", gold = "Yellow", networth = "Blue", lasthits = "Gray", heroname = "Indigo", fps = "Green", ping = "Teal" }
Impl.SWATCHES = {
    { mode = 1 },
    { mode = 2 },
    { mode = 3, r = 255, g = 69, b = 58, hex = "FF453A" },
    { mode = 3, r = 255, g = 159, b = 10, hex = "FF9F0A" },
    { mode = 3, r = 255, g = 214, b = 10, hex = "FFD60A" },
    { mode = 3, r = 48, g = 209, b = 88, hex = "30D158" },
    { mode = 3, r = 10, g = 132, b = 255, hex = "0A84FF" },
    { mode = 3, r = 191, g = 90, b = 242, hex = "BF5AF2" }
}

function Impl.ChipLabel(id)
    local wg = Impl.Wg.ById[id]
    if wg then return wg.title end
    for _, c in ipairs(HUDCustomizer.AvailableChips) do
        if c.id == id then return L(c.label) end
    end
    return id
end

function Impl.EdPos(id)
    local P = HUDCustomizer.Anim.Pos[id]
    if not P then
        P = { x = 0, y = 0, s = 0, a = 0, vx = 0, vy = 0, vs = 0, va = 0, fresh = true }
        HUDCustomizer.Anim.Pos[id] = P
    end
    return P
end

function Impl.EdMove(P, x, y, s, a, dt)
    if P.fresh then
        P.x, P.y, P.s, P.a, P.fresh = x, y, s, a, false
        return
    end
    P.x, P.vx = MotionEngine.Step(P.x, P.vx, x, dt, "SMOOTH")
    P.y, P.vy = MotionEngine.Step(P.y, P.vy, y, dt, "SMOOTH")
    P.s, P.vs = MotionEngine.Step(P.s, P.vs, s, dt, "SMOOTH")
    P.a, P.va = MotionEngine.Step(P.a, P.va, a, dt, "SMOOTH")
end

function Impl.EdIcon(id, x, y, sz, a)
    local wg = Impl.Wg.ById[id]
    local tint = wg and wg.tint or Config.Colors[Impl.CHIP_TINT[id] or "Gray"] or Config.Colors.Gray
    Render.FilledRect(Vec2(x, y), Vec2(x + sz, y + sz), FadeColor(tint, a), sz * 0.24)
    local gc = id == "gold" and Color(0, 0, 0, 215) or Color(255, 255, 255, 255)
    Glyph(wg and wg.glyph or id, x + sz / 2, y + sz / 2, math.floor(sz * 0.6), FadeColor(gc, a))
end

function Impl.EdDone(x0, py, cardW, s, a, bounds)
    local f, sz = TF("Headline", s)
    local t = L("di_ui_done")
    local ts = Render.TextSize(f, sz, t)
    local tx = math.floor(x0 + cardW - 14 * s - ts.x)
    local my = py + 30 * s
    local _, pk = Pointer.Button(bounds == HUDCustomizer.DrawerBounds and "ed_done_l" or "ed_done_d", tx - 6 * s, my - 14 * s, x0 + cardW - 6 * s, my + 14 * s)
    Render.Text(f, sz, t, Vec2(tx, math.floor(my - ts.y / 2)), FadeColor(Config.Colors.Blue, a * (1 - 0.45 * pk)))
    if bounds then
        table.insert(bounds, { x1 = tx - 6 * s, y1 = my - 14 * s, x2 = x0 + cardW - 6 * s, y2 = my + 14 * s, action = "done" })
    end
end

function Impl.EdHeader(x, y, text, s, a)
    local f, sz = TF("Footnote", s)
    Render.Text(f, sz, text, Vec2(math.floor(x), math.floor(y)), FadeColor(Config.Colors.TextSecondary, a))
end

function Impl.EditorListH(s)
    local n = #HUDCustomizer.ActiveChips
    local m = #HUDCustomizer.AvailableChips - n
    local h = 68 * s + n * 36 * s
    if m <= 0 then return h + 12 * s end
    local rows = math.ceil(m / (m > 5 and 4 or 5))
    return h + 32 * s + (22 + rows * 56 + (rows - 1) * 10) * s + 12 * s
end

function Impl.EdRow(id, P, x0, py, cardW, s, a, first, isDrag, hl)
    local C = Config.Colors
    local rowH = 36 * s
    local gl, gr = x0 + 12 * s, x0 + cardW - 12 * s
    local top = py + P.ry
    local my = top + rowH / 2
    if hl > 0.01 then
        Render.FilledRect(Vec2(gl + 4 * s, top + 3 * s), Vec2(gr - 4 * s, top + rowH - 3 * s), FadeColor(C.FillQuaternary, a * hl), 7 * s)
    end
    if not first and not isDrag then
        Render.Line(Vec2(gl + 74 * s, math.floor(top) + 0.5), Vec2(gr, math.floor(top) + 0.5), FadeColor(C.Separator, a), 1.0)
    end
    local canRemove = #HUDCustomizer.ActiveChips > 1
    local ma = a * (canRemove and 1 or 0.35)
    local mx = gl + 18 * s
    Render.FilledCircle(Vec2(mx, my), 9 * s, FadeColor(C.Red, ma), 0, 1.0, 24)
    Render.FilledRect(Vec2(mx - 4.5 * s, my - 1 * s), Vec2(mx + 4.5 * s, my + 1 * s), FadeColor(Color(255, 255, 255, 255), ma), 1 * s)

    local f, sz = TF("Body", s)
    local label = Impl.ChipLabel(id)
    local ls = Render.TextSize(f, sz, label)
    local lx = math.floor(gl + 74 * s)
    Render.Text(f, sz, label, Vec2(lx, math.floor(my - ls.y / 2)), FadeColor(C.TextPrimary, a))

    local gx2 = gr - 12 * s
    local gx1 = gx2 - 14 * s
    for k = -1, 1 do
        local yy = math.floor(my + k * 4 * s) + 0.5
        Render.Line(Vec2(gx1, yy), Vec2(gx2, yy), FadeColor(C.TextMuted, a), 1.5 * s)
    end
    local chx = gx1 - 14 * s
    Glyph("chevron", chx, my, math.floor(12 * s), FadeColor(C.TextMuted, a))

    local c = GetChipContent(id)
    local right = chx - 14 * s
    local maxW = right - (lx + ls.x + 12 * s)
    if maxW > 8 * s then
        local txt = c.text
        local vw = Odometer.Width(f, sz, txt)
        if vw > maxW then
            txt = TruncateToWidth(f, sz, txt, maxW)
            local ts = Render.TextSize(f, sz, txt)
            Render.Text(f, sz, txt, Vec2(math.floor(right - ts.x), math.floor(my - ts.y / 2)), FadeColor(C.TextSecondary, a))
        else
            Odometer.Text("ed_" .. id, f, sz, txt, Vec2(math.floor(right - vw), math.floor(my - ls.y / 2)), FadeColor(C.TextSecondary, a), id == "fps" or id == "ping")
        end
    end
    return gl, gr, top, canRemove
end

function Impl.RenderEditorList(cx, py, cardW, s, a, dt, offX, live)
    local C = Config.Colors
    local anim = HUDCustomizer.Anim
    local pad = 12 * s
    local rowH = 36 * s
    local x0 = cx + offX
    local gl, gr = x0 + pad, x0 + cardW - pad
    local bounds = live and HUDCustomizer.DrawerBounds or nil
    local mx, my = Input.GetCursorPos()

    local fT, sT = TF("Headline", s)
    local title = L("di_ui_widgets")
    local tsz = Render.TextSize(fT, sT, title)
    Render.Text(fT, sT, title, Vec2(math.floor(gl + 2 * s), math.floor(py + 30 * s - tsz.y / 2)), FadeColor(C.TextPrimary, a))
    Impl.EdDone(x0, py, cardW, s, a, bounds)

    local act = HUDCustomizer.ActiveChips
    local n = #act
    local g1Top = 68 * s
    HUDCustomizer.EditorGeo = { py = py, top = g1Top, rowH = rowH, s = s }

    local shelf = {}
    for _, c in ipairs(HUDCustomizer.AvailableChips) do
        if not Impl.IsChipInActiveList(c.id) then shelf[#shelf + 1] = c.id end
    end
    local m = #shelf
    local cols = m > 5 and 4 or 5
    local rows = math.max(1, math.ceil(m / cols))
    local shelfH = m > 0 and (22 + rows * 56 + (rows - 1) * 10) * s or 0

    if not anim.G1 then
        anim.G1, anim.G1v, anim.G2, anim.G2v = n * rowH, 0, shelfH, 0
    end
    anim.G1, anim.G1v = MotionEngine.Step(anim.G1, anim.G1v, n * rowH, dt, "SMOOTH")
    anim.G2, anim.G2v = MotionEngine.Step(anim.G2, anim.G2v, shelfH, dt, "SMOOTH")
    local g1H = math.max(0, anim.G1)
    local g2H = math.max(0, anim.G2)
    local g2Top = g1Top + g1H + 32 * s

    Impl.EdHeader(gl + 6 * s, py + 50 * s, L("di_ui_on_island_hdr"), s, a)
    Render.FilledRect(Vec2(gl, py + g1Top), Vec2(gr, py + g1Top + g1H), FadeColor(C.Group, a), 10 * s)
    if g2H > 1 then
        local ha = a * math.min(1, g2H / (40 * s))
        Impl.EdHeader(gl + 6 * s, py + g2Top - 18 * s, L("di_ui_add_hdr"), s, ha)
        Render.FilledRect(Vec2(gl, py + g2Top), Vec2(gr, py + g2Top + g2H), FadeColor(C.Group, ha), 10 * s)
    end

    local drag = HUDCustomizer.RowDrag
    local press = HUDCustomizer.RowPress
    local isz = 26 * s
    for i, id in ipairs(act) do
        local P = Impl.EdPos(id)
        local ry = g1Top + (i - 1) * rowH
        if drag == id then
            ry = math.max(g1Top, math.min(g1Top + (n - 1) * rowH, HUDCustomizer.RowDragY or ry))
        end
        if not P.ry or P.a < 0.05 or drag == id then
            P.ry, P.vry = ry, 0
        else
            P.ry, P.vry = MotionEngine.Step(P.ry, P.vry, ry, dt, "SMOOTH")
        end
        Impl.EdMove(P, pad + 38 * s, ry + (rowH - isz) / 2, isz, 1, dt)
        if drag == id then
            P.x, P.y, P.s, P.vx, P.vy, P.vs = pad + 38 * s, P.ry + (rowH - isz) / 2, isz, 0, 0, 0
        end
    end
    local cellW = (gr - gl) / cols
    local ssz = 38 * s
    for j, id in ipairs(shelf) do
        local P = Impl.EdPos(id)
        local col = (j - 1) % cols
        local row = math.floor((j - 1) / cols)
        Impl.EdMove(P, pad + (col + 0.5) * cellW - ssz / 2, g2Top + 12 * s + row * 66 * s, ssz, 0, dt)
    end

    for i, id in ipairs(act) do
        if id ~= drag then
            local P = Impl.EdPos(id)
            local top = py + P.ry
            local over = not drag and mx >= gl and mx <= gr and my >= top and my <= top + rowH
            local hl = (press and press.id == id) and 1.6 or (over and 1 or 0)
            local ra = a * math.max(0, math.min(1, P.a))
            local _, _, _, canRemove = Impl.EdRow(id, P, x0, py, cardW, s, ra, i == 1, false, hl)
            if bounds and not drag and P.a > 0.9 then
                if canRemove then
                    table.insert(bounds, { x1 = gl, y1 = top, x2 = gl + 30 * s, y2 = top + rowH, action = "remove", id = id })
                end
                table.insert(bounds, { x1 = gl + 30 * s, y1 = top, x2 = gr, y2 = top + rowH, action = "row", id = id })
            end
        end
    end

    local fC, sC = TF("Caption", s)
    for j, id in ipairs(shelf) do
        local P = Impl.EdPos(id)
        local sa = a * math.max(0, math.min(1, 1 - P.a))
        if sa > 0.01 then
            local ccx = x0 + P.x + P.s / 2
            local lbl = TruncateToWidth(fC, sC, Impl.ChipLabel(id), math.floor(cellW - 6 * s))
            local lsz = Render.TextSize(fC, sC, lbl)
            Render.Text(fC, sC, lbl, Vec2(math.floor(ccx - lsz.x / 2), math.floor(py + P.y + P.s + 5 * s)), FadeColor(C.TextSecondary, sa))
        end
        if bounds and P.a < 0.1 then
            local col = (j - 1) % cols
            table.insert(bounds, { x1 = gl + col * cellW, y1 = py + P.y - 6 * s, x2 = gl + (col + 1) * cellW, y2 = py + P.y + P.s + 20 * s, action = "add", id = id })
        end
    end

    for _, c in ipairs(HUDCustomizer.AvailableChips) do
        local id = c.id
        if id ~= drag then
            local P = Impl.EdPos(id)
            if not P.fresh then
                Impl.EdIcon(id, x0 + P.x, py + P.y, P.s, a)
                local ba = a * math.max(0, math.min(1, 1 - P.a * 1.6))
                if ba > 0.01 then
                    local bc = Vec2(x0 + P.x + P.s - 3 * s, py + P.y + 3 * s)
                    local br = 8.5 * s
                    SoftShadow(Vec2(bc.x - br, bc.y - br), Vec2(bc.x + br, bc.y + br), br, Color(0, 0, 0, math.floor(90 * ba)), 5, Vec2(0, 1))
                    Render.FilledCircle(bc, br, FadeColor(C.SegThumb, ba), 0, 1.0, 20)
                    Glyph("plus", bc.x, bc.y, math.floor(11 * s), FadeColor(C.TextPrimary, ba))
                end
            end
        end
    end

    if drag then
        local P = Impl.EdPos(drag)
        local top = py + P.ry
        local bg = IsPureGlass() and Color(28, 28, 30, 225) or UI.Main.IslandBgColor:Get()
        SoftShadow(Vec2(gl, top), Vec2(gr, top + rowH), 10 * s, Color(0, 0, 0, math.floor(140 * a)), 18, Vec2(0, 5))
        Render.FilledRect(Vec2(gl, top), Vec2(gr, top + rowH), FadeColor(Color(bg.r, bg.g, bg.b, IsPureGlass() and bg.a or 255), a), 10 * s)
        Render.FilledRect(Vec2(gl, top), Vec2(gr, top + rowH), FadeColor(C.Group, a), 10 * s)
        Impl.EdRow(drag, P, x0, py, cardW, s, a, true, true, 0)
        Impl.EdIcon(drag, x0 + P.x, py + P.y, P.s, a)
    end
end

function Impl.EditorDetailH(s)
    return (Impl.Wg.ById[HUDCustomizer.InspectedChip or ""] and 268 or 304) * s
end

function Impl.RenderEditorDetail(cx, py, cardW, s, a, dt, offX, id, live, pb)
    local cfg = HUDCustomizer.WidgetConfigs[id]
    if not cfg then return end
    local C = Config.Colors
    local anim = HUDCustomizer.Anim
    local rowH = 36 * s
    local x0 = cx + offX
    if offX > 0.5 and not IsPureGlass() then
        if pb.x2 - x0 < pb.r * 2 then return end
        local c = UI.Main.IslandBgColor:Get()
        Render.FilledRect(Vec2(x0, py), Vec2(pb.x2, pb.y2), FadeColor(Color(c.r, c.g, c.b, 255), a), pb.r)
    end
    local gl, gr = x0 + 12 * s, x0 + cardW - 12 * s
    local bounds = live and HUDCustomizer.InspectorBounds or nil
    local my = py + 30 * s

    local fB, sB = TF("Body", s)
    local back = L("di_ui_widgets")
    local bs = Render.TextSize(fB, sB, back)
    Glyph("chevron_back", gl + 5 * s, my, math.floor(17 * s), FadeColor(C.Blue, a))
    Render.Text(fB, sB, back, Vec2(math.floor(gl + 14 * s), math.floor(my - bs.y / 2)), FadeColor(C.Blue, a))
    if bounds then
        table.insert(bounds, { x1 = gl - 6 * s, y1 = my - 14 * s, x2 = gl + 18 * s + bs.x, y2 = my + 14 * s, action = "back" })
    end
    local fT, sT = TF("Headline", s)
    local title = Impl.ChipLabel(id)
    local ts = Render.TextSize(fT, sT, title)
    Render.Text(fT, sT, title, Vec2(math.floor(x0 + (cardW - ts.x) / 2), math.floor(my - ts.y / 2)), FadeColor(C.TextPrimary, a))
    Impl.EdDone(x0, py, cardW, s, a, bounds)

    local function Group(top, rows, h)
        local y1 = py + top
        Render.FilledRect(Vec2(gl, y1), Vec2(gr, y1 + (h or rows * rowH)), FadeColor(C.Group, a), 10 * s)
        for k = 1, rows - 1 do
            local yy = math.floor(y1 + k * rowH) + 0.5
            Render.Line(Vec2(gl + 14 * s, yy), Vec2(gr, yy), FadeColor(C.Separator, a), 1.0)
        end
    end
    local function Label(text, top, ca)
        local ls = Render.TextSize(fB, sB, text)
        Render.Text(fB, sB, text, Vec2(math.floor(gl + 14 * s), math.floor(py + top + (rowH - ls.y) / 2)), FadeColor(C.TextPrimary, ca or a))
    end
    local swW, swH = 42 * s, 25 * s
    local function Switch(top, on, spring, action, sa)
        local sx = gr - 12 * s - swW
        local sy = py + top + (rowH - swH) / 2
        Impl.RenderSwitch(sx, sy, swW, swH, on, spring, dt, sa or a)
        if bounds then
            table.insert(bounds, { x1 = gl, y1 = py + top, x2 = gr, y2 = py + top + rowH, action = action })
        end
    end

    local onIsland = Impl.IsChipInActiveList(id)
    local locked = onIsland and #HUDCustomizer.ActiveChips <= 1
    Group(50 * s, 2)
    Label(L("di_ui_show_on_island"), 50 * s)
    Switch(50 * s, onIsland, anim.KnobOn, "toggle_active", a * (locked and 0.5 or 1))
    Label(L("di_ui_icon"), 50 * s + rowH)
    Switch(50 * s + rowH, cfg.showIcon ~= false, anim.Knob, "toggle_icon")

    local segH = 26 * s
    local top2 = 136 * s
    local isSdk = Impl.Wg.ById[id] ~= nil
    Group(top2, isSdk and 1 or 2)
    Label(L("di_ui_weight"), top2)
    local segW1 = 150 * s
    local segY1 = py + top2 + (rowH - segH) / 2
    Impl.RenderSegmented(gr - 8 * s - segW1, segY1, segW1, segH, Impl.SEG_WEIGHT, cfg.bold and 1 or 2, anim.SegWeight, dt, s, a, "set_bold")
    if not isSdk then
        Label(L("di_ui_format"), top2 + rowH)
        local segW2 = 176 * s
        local segY2 = py + top2 + rowH + (rowH - segH) / 2
        Impl.RenderSegmented(gr - 8 * s - segW2, segY2, segW2, segH, Impl.SEG_FORMAT, cfg.format or 1, anim.SegFormat, dt, s, a, "set_format")
    end
    if not bounds then
        local B = HUDCustomizer.InspectorBounds
        for k = #B, 1, -1 do
            if B[k].action == "set_bold" or B[k].action == "set_format" then table.remove(B, k) end
        end
    end

    local top3 = (isSdk and 186 or 222) * s
    Group(top3, 1, 70 * s)
    local hy = py + top3 + 16 * s
    local cl = L("di_ui_color")
    local cs = Render.TextSize(fB, sB, cl)
    Render.Text(fB, sB, cl, Vec2(math.floor(gl + 14 * s), math.floor(hy - cs.y / 2)), FadeColor(C.TextPrimary, a))
    local mode = cfg.colorMode or 1
    local vk = mode == 1 and "di_drawer_white" or (mode == 2 and "di_drawer_dim" or "di_drawer_custom")
    local vt = L(vk)
    local vs = Render.TextSize(fB, sB, vt)
    Render.Text(fB, sB, vt, Vec2(math.floor(gr - 14 * s - vs.x), math.floor(hy - vs.y / 2)), FadeColor(C.TextSecondary, a))

    local d = 22 * s
    local count = #Impl.SWATCHES + 1
    local span = (gr - gl) - 28 * s
    local gap = (span - count * d) / (count - 1)
    local scy = py + top3 + 48 * s
    local hex = string.upper(cfg.customHex or "")
    local matched = false
    for k, q in ipairs(Impl.SWATCHES) do
        local qx = gl + 14 * s + d / 2 + (k - 1) * (d + gap)
        local col
        if q.mode == 1 then col = C.TextPrimary
        elseif q.mode == 2 then col = C.Gray
        else col = Color(q.r, q.g, q.b, 255) end
        local sel = (q.mode == mode) and (mode ~= 3 or q.hex == hex)
        if sel then matched = true end
        local r = sel and (d / 2 - 3.5 * s) or d / 2
        Render.FilledCircle(Vec2(qx, scy), r, FadeColor(col, a), 0, 1.0, 28)
        if q.mode == 1 and not sel then
            Render.Circle(Vec2(qx, scy), d / 2, FadeColor(C.Separator, a), 1.0, 0, 1.0, false, 32)
        end
        if sel then
            Render.Circle(Vec2(qx, scy), d / 2 - 1 * s, FadeColor(col, a), 2 * s, 0, 1.0, false, 32)
        end
        if bounds then
            table.insert(bounds, { x1 = qx - d / 2 - gap / 2, y1 = scy - d / 2 - 4 * s, x2 = qx + d / 2 + gap / 2, y2 = scy + d / 2 + 4 * s, action = "swatch", mode = q.mode, r = q.r, g = q.g, b = q.b, hex = q.hex })
        end
    end
    local rx = gl + 14 * s + d / 2 + (count - 1) * (d + gap)
    local rc = Vec2(rx, scy)
    local custom = mode == 3 and not matched
    local rr = d / 2 - 1.5 * s
    for q = 0, 11 do
        local cr, cg, cb = HSVtoRGB(q * 30, 0.85, 1.0)
        Render.Circle(rc, rr, FadeColor(Color(cr, cg, cb, 255), a), 3 * s, (q * 30 + 270) % 360, 1 / 12 + 0.004, false, 6)
    end
    if custom then
        Render.FilledCircle(rc, d / 2 - 5 * s, FadeColor(cfg.customColor or C.TextPrimary, a), 0, 1.0, 24)
    else
        Glyph("plus", rx, scy, math.floor(10 * s), FadeColor(C.TextPrimary, a))
    end
    if HUDCustomizer.ColorPickerOpen then
        Render.Circle(rc, d / 2 + 2.5 * s, FadeColor(C.Blue, a), 1.5 * s, 0, 1.0, false, 32)
    end
    if bounds then
        table.insert(bounds, { x1 = rx - d / 2 - gap / 2, y1 = scy - d / 2 - 4 * s, x2 = rx + d / 2 + gap / 2, y2 = scy + d / 2 + 4 * s, action = "custom_color" })
    end
end

Impl.PickerTabs = { { label = "di_cp_grid", val = 1 }, { label = "di_cp_spectrum", val = 2 }, { label = "di_cp_sliders", val = 3 } }

function Impl.GridColor(col, row)
    if row == 0 then
        local g = math.floor(255 * (1 - col / 11) + 0.5)
        return g, g, g
    end
    local t = (row - 1) / 8
    local sat, val
    if t < 0.5 then
        sat, val = 1, 0.32 + t / 0.5 * 0.68
    else
        sat, val = 1 - (t - 0.5) / 0.5 * 0.7, 1
    end
    return HSVtoRGB(col / 12 * 360, sat, val)
end

function Impl.ApplyPicked(cfg, r, g, b)
    r, g, b = math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5)
    cfg.colorMode = 3
    cfg.customColor = Color(r, g, b, 255)
    cfg.customHex = string.format("%02X%02X%02X", r, g, b)
    HUDCustomizer.PickDirty = true
end

function Impl.PickIn(x1, y1, x2, y2)
    return Pointer.down and Pointer.px >= x1 and Pointer.px <= x2 and Pointer.py >= y1 and Pointer.py <= y2
end

function Impl.RenderColorPickerPopover(cx, cy, cardW, scale, dt)
    local anim = HUDCustomizer.Anim
    anim.ColorPickerT = anim.ColorPickerT or 0
    anim.ColorPickerT = math.min(1, math.max(0, anim.ColorPickerT + dt / 0.18 * (HUDCustomizer.ColorPickerOpen and 1 or -1.8)))
    if HUDCustomizer.PickDirty and not Pointer.down then
        HUDCustomizer.PickDirty = false
        SaveAllConfig()
    end
    if anim.ColorPickerT <= 0 then return end

    local id = HUDCustomizer.InspectedChip
    local cfg = id and HUDCustomizer.WidgetConfigs[id]
    if not cfg then return end

    local s = scale
    local C = Config.Colors
    local curCol = cfg.customColor or GetDefaultWidgetColor(id)
    local cr, cg, cb = curCol.r, curCol.g, curCol.b
    local curHex = string.format("%02X%02X%02X", cr, cg, cb)

    local pad = 14 * s
    local popW = math.floor(296 * s)
    local innerW = popW - pad * 2
    local cell = innerW / 12
    local contentH = cell * 10
    local popH = math.floor(46 * s + 28 * s + 12 * s + contentH + 14 * s + 50 * s + pad)

    local scr = Render.ScreenSize()
    local popX = cx + cardW + 10 * s
    local popY = cy
    if popX + popW > scr.x - 10 then popX = cx - popW - 10 * s end
    if popX < 10 then
        popX = math.floor(cx + (cardW - popW) / 2)
        popY = cy + 180 * s
    end
    if popY + popH > scr.y - 10 then popY = scr.y - popH - 10 end
    if popY < 10 then popY = 10 end
    popX, popY = math.floor(popX), math.floor(popY)

    local a = anim.ColorPickerT
    local live = a > 0.9
    local p1, p2 = Vec2(popX, popY), Vec2(popX + popW, popY + popH)
    local rad = 18 * s
    SoftShadow(p1, p2, rad, Color(0, 0, 0, math.floor(220 * a)), 28, Vec2(0, 8))
    DrawerSurface(p1, p2, rad, a)
    if live then
        table.insert(HUDCustomizer.InspectorBounds, { x1 = popX, y1 = popY, x2 = popX + popW, y2 = popY + popH, action = "pop_noop" })
    end

    local fH, sH = TF("Headline", s)
    local title = L("di_ui_color_picker")
    local ts = Render.TextSize(fH, sH, title)
    local hy = popY + 23 * s
    Render.Text(fH, sH, title, Vec2(math.floor(popX + (popW - ts.x) / 2), math.floor(hy - ts.y / 2)), FadeColor(C.TextPrimary, a))
    local closeR = 12 * s
    local closeX = popX + popW - pad - closeR
    local _, cpk = Pointer.Button("cp_close", closeX - closeR, hy - closeR, closeX + closeR, hy + closeR)
    Render.FilledCircle(Vec2(closeX, hy), closeR, FadeColor(C.SegTrack, a * (1 + 0.6 * cpk)), 0, 1.0, 24)
    Glyph("close", closeX, hy, math.floor(closeR * 0.95), FadeColor(C.TextSecondary, a))
    if live then
        table.insert(HUDCustomizer.InspectorBounds, 1, { x1 = closeX - closeR - 4, y1 = hy - closeR - 4, x2 = closeX + closeR + 4, y2 = hy + closeR + 4, action = "close_color_picker" })
    end

    local tab = HUDCustomizer.PickerTab or 1
    anim.PickerSeg = anim.PickerSeg or { v = tab - 1, vel = 0 }
    local segY = popY + 46 * s
    local keep = HUDCustomizer.InspectorBounds
    HUDCustomizer.InspectorBounds = {}
    Impl.RenderSegmented(popX + pad, segY, innerW, 28 * s, Impl.PickerTabs, tab, anim.PickerSeg, dt, s, a, "pick_tab")
    local segHits = HUDCustomizer.InspectorBounds
    HUDCustomizer.InspectorBounds = keep
    if live and Pointer.pressed then
        for _, b in ipairs(segHits) do
            if Pointer.x >= b.x1 and Pointer.x <= b.x2 and Pointer.y >= b.y1 and Pointer.y <= b.y2 and b.val ~= tab then
                HUDCustomizer.PickerTab = b.val
                if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
            end
        end
    end

    local ax, ay = popX + pad, segY + 28 * s + 12 * s
    local aw, ah = innerW, contentH
    local hit = live and Impl.PickIn(ax, ay, ax + aw, ay + ah)
    local mx = math.max(ax, math.min(ax + aw - 0.01, Pointer.x))
    local my = math.max(ay, math.min(ay + ah - 0.01, Pointer.y))
    local rr = 10 * s

    if tab == 1 then
        local selX, selY
        for row = 0, 9 do
            for col = 0, 11 do
                local r, g, b = Impl.GridColor(col, row)
                local x1, y1 = ax + col * cell, ay + row * cell
                local flags, rnd = Enum.DrawFlags.None, 0
                if row == 0 and col == 0 then flags, rnd = Enum.DrawFlags.RoundCornersTopLeft, rr
                elseif row == 0 and col == 11 then flags, rnd = Enum.DrawFlags.RoundCornersTopRight, rr
                elseif row == 9 and col == 0 then flags, rnd = Enum.DrawFlags.RoundCornersBottomLeft, rr
                elseif row == 9 and col == 11 then flags, rnd = Enum.DrawFlags.RoundCornersBottomRight, rr end
                Render.FilledRect(Vec2(x1, y1), Vec2(x1 + cell + 0.6, y1 + cell + 0.6), FadeColor(Color(r, g, b, 255), a), rnd, flags)
                if string.format("%02X%02X%02X", r, g, b) == curHex then selX, selY = x1, y1 end
            end
        end
        if selX then
            local lum = cr * 0.299 + cg * 0.587 + cb * 0.114
            Render.Rect(Vec2(selX - 1, selY - 1), Vec2(selX + cell + 1, selY + cell + 1), FadeColor(lum > 150 and Color(0, 0, 0, 255) or Color(255, 255, 255, 255), a), 3 * s, Enum.DrawFlags.None, 2.5 * s)
        end
        if hit then
            local col = math.min(11, math.floor((mx - ax) / cell))
            local row = math.min(9, math.floor((my - ay) / cell))
            local r, g, b = Impl.GridColor(col, row)
            if string.format("%02X%02X%02X", r, g, b) ~= curHex then
                Impl.ApplyPicked(cfg, r, g, b)
                if Haptic and Haptic.Silent then Haptic.Silent(Haptic.Types.RATCHET_NOTCH) end
            end
        end
    elseif tab == 2 then
        local seg = aw / 6
        for i = 0, 5 do
            local r1, g1, b1 = HSVtoRGB(i * 60, 1, 1)
            local r2, g2, b2 = HSVtoRGB((i + 1) * 60, 1, 1)
            local c1, c2 = FadeColor(Color(r1, g1, b1, 255), a), FadeColor(Color(r2, g2, b2, 255), a)
            local flags, rnd = Enum.DrawFlags.None, 0
            if i == 0 then flags, rnd = Enum.DrawFlags.RoundCornersLeft, rr elseif i == 5 then flags, rnd = Enum.DrawFlags.RoundCornersRight, rr end
            Render.Gradient(Vec2(ax + i * seg, ay), Vec2(ax + (i + 1) * seg + (i < 5 and 0.6 or 0), ay + ah), c1, c2, c1, c2, rnd, flags)
        end
        local w0, w1 = FadeColor(Color(255, 255, 255, 255), a), Color(255, 255, 255, 0)
        local k0, k1 = Color(0, 0, 0, 0), FadeColor(Color(0, 0, 0, 255), a)
        Render.Gradient(Vec2(ax, ay), Vec2(ax + aw, ay + ah / 2), w0, w0, w1, w1, rr, Enum.DrawFlags.RoundCornersTop)
        Render.Gradient(Vec2(ax, ay + ah / 2), Vec2(ax + aw, ay + ah), k0, k0, k1, k1, rr, Enum.DrawFlags.RoundCornersBottom)
        local h, sv, v = RGBtoHSV(cr, cg, cb)
        local fy = v >= 0.995 and sv * 0.5 or (0.5 + (1 - v) * 0.5)
        local kx, ky = ax + (h / 360) * aw, ay + fy * ah
        local kr = 11 * s
        SoftShadow(Vec2(kx - kr, ky - kr), Vec2(kx + kr, ky + kr), kr, Color(0, 0, 0, math.floor(120 * a)), 6, Vec2(0, 1))
        Render.FilledCircle(Vec2(kx, ky), kr, FadeColor(Color(255, 255, 255, 255), a), 0, 1.0, 28)
        Render.FilledCircle(Vec2(kx, ky), kr - 3 * s, FadeColor(curCol, a), 0, 1.0, 24)
        if hit then
            local fx = (mx - ax) / aw
            local fy2 = (my - ay) / ah
            local nh = fx * 360
            local ns, nv
            if fy2 < 0.5 then ns, nv = fy2 / 0.5, 1 else ns, nv = 1, 1 - (fy2 - 0.5) / 0.5 end
            local r, g, b = HSVtoRGB(nh, ns, nv)
            Impl.ApplyPicked(cfg, r, g, b)
        end
    else
        local names = { "di_cp_red", "di_cp_green", "di_cp_blue" }
        local vals = { cr, cg, cb }
        local fL, sL = TF("Caption", s)
        local fV, sV = TF("Body", s)
        local boxW = 52 * s
        local trackW = aw - boxW - 10 * s
        local th2 = 26 * s
        for i = 1, 3 do
            local ry = ay + (i - 1) * 60 * s
            Render.Text(fL, sL, L(names[i]), Vec2(math.floor(ax + 2 * s), math.floor(ry)), FadeColor(C.TextSecondary, a))
            local ty = ry + 18 * s
            local lo = { cr, cg, cb }
            local hi = { cr, cg, cb }
            lo[i], hi[i] = 0, 255
            local c1 = FadeColor(Color(lo[1], lo[2], lo[3], 255), a)
            local c2 = FadeColor(Color(hi[1], hi[2], hi[3], 255), a)
            Render.Gradient(Vec2(ax, ty), Vec2(ax + trackW, ty + th2), c1, c2, c1, c2, th2 / 2)
            local kx = ax + th2 / 2 + (trackW - th2) * (vals[i] / 255)
            local kc = Vec2(kx, ty + th2 / 2)
            SoftShadow(Vec2(kx - th2 / 2, ty), Vec2(kx + th2 / 2, ty + th2), th2 / 2, Color(0, 0, 0, math.floor(110 * a)), 6, Vec2(0, 1))
            Render.FilledCircle(kc, th2 / 2 - 1 * s, FadeColor(Color(255, 255, 255, 255), a), 0, 1.0, 28)
            local bx = ax + trackW + 10 * s
            Render.FilledRect(Vec2(bx, ty), Vec2(bx + boxW, ty + th2), FadeColor(C.Group, a), 7 * s)
            local vt = tostring(vals[i])
            local vs = Render.TextSize(fV, sV, vt)
            Render.Text(fV, sV, vt, Vec2(math.floor(bx + (boxW - vs.x) / 2), math.floor(ty + (th2 - vs.y) / 2)), FadeColor(C.TextPrimary, a))
            if live and Impl.PickIn(ax - 6 * s, ty - 6 * s, ax + trackW + 6 * s, ty + th2 + 6 * s) then
                local f = math.max(0, math.min(1, (Pointer.x - ax - th2 / 2) / (trackW - th2)))
                local nv = { cr, cg, cb }
                nv[i] = f * 255
                Impl.ApplyPicked(cfg, nv[1], nv[2], nv[3])
            end
        end
        local hy2 = ay + 3 * 60 * s + 2 * s
        local hl = L("di_cp_hex")
        Render.Text(fL, sL, hl, Vec2(math.floor(ax + 2 * s), math.floor(hy2 + 3 * s)), FadeColor(C.TextSecondary, a))
        local hexT = "#" .. curHex
        local hs = Render.TextSize(fV, sV, hexT)
        Odometer.Draw(fV, sV, hexT, Vec2(math.floor(ax + aw - hs.x - 2 * s), math.floor(hy2)), FadeColor(C.TextPrimary, a))
    end

    local sepY = ay + ah + 14 * s
    Render.Line(Vec2(popX + pad, math.floor(sepY) + 0.5), Vec2(popX + popW - pad, math.floor(sepY) + 0.5), FadeColor(C.Separator, a), 1.0)
    local by = sepY + 12 * s
    local big = 38 * s
    Render.FilledRect(Vec2(ax, by), Vec2(ax + big, by + big), FadeColor(curCol, a), 9 * s)
    Render.Rect(Vec2(ax, by), Vec2(ax + big, by + big), FadeColor(C.Border, a), 9 * s, Enum.DrawFlags.None, 1.0)
    local saved = HUDCustomizer.Saved or {}
    local d = 26 * s
    local gap = 8 * s
    local sx = ax + big + 16 * s
    local scy = by + big / 2
    local slots = math.floor((ax + aw - sx + gap) / (d + gap))
    local shown = math.min(#saved, slots - 1)
    for i = 1, shown do
        local hx = saved[i]
        local r, g, b = tonumber(string.sub(hx, 1, 2), 16) or 0, tonumber(string.sub(hx, 3, 4), 16) or 0, tonumber(string.sub(hx, 5, 6), 16) or 0
        local ccx = sx + (i - 1) * (d + gap) + d / 2
        local _, pk = Pointer.Button("cp_saved" .. i, ccx - d / 2, scy - d / 2, ccx + d / 2, scy + d / 2)
        local rad2 = d / 2 * (1 - 0.1 * pk)
        Render.FilledCircle(Vec2(ccx, scy), rad2, FadeColor(Color(r, g, b, 255), a), 0, 1.0, 28)
        if hx == curHex then
            Render.Circle(Vec2(ccx, scy), d / 2 + 3 * s, FadeColor(Color(r, g, b, 255), a), 2 * s, 0, 1.0, false, 32)
        end
        if live and Pointer.pressed and Pointer.x >= ccx - d / 2 and Pointer.x <= ccx + d / 2 and Pointer.y >= scy - d / 2 and Pointer.y <= scy + d / 2 then
            Impl.ApplyPicked(cfg, r, g, b)
            if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
        end
    end
    local pcx = sx + shown * (d + gap) + d / 2
    local _, ppk = Pointer.Button("cp_add", pcx - d / 2, scy - d / 2, pcx + d / 2, scy + d / 2)
    Render.FilledCircle(Vec2(pcx, scy), d / 2 * (1 - 0.1 * ppk), FadeColor(C.SegTrack, a), 0, 1.0, 28)
    Glyph("plus", pcx, scy, math.floor(12 * s), FadeColor(C.TextSecondary, a))
    if live and Pointer.pressed and Pointer.x >= pcx - d / 2 and Pointer.x <= pcx + d / 2 and Pointer.y >= scy - d / 2 and Pointer.y <= scy + d / 2 then
        local list = { curHex }
        for _, hx in ipairs(saved) do
            if hx ~= curHex and #list < 12 then list[#list + 1] = hx end
        end
        HUDCustomizer.Saved = list
        SaveAllConfig()
        if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_MEDIUM) end
    end
end

function Impl.RenderHUDDrawer(layout, dt)
    local anim = HUDCustomizer.Anim
    if not HUDCustomizer.IsOpen and anim.t <= 0 then
        anim.h, anim.hVel = 0, 0
        anim.Pos, anim.G1, anim.G2 = {}, nil, nil
        anim.Page.v, anim.Page.vel, anim.PageId = 0, 0, nil
        HUDCustomizer.DrawerBounds = {}
        HUDCustomizer.InspectorBounds = {}
        HUDCustomizer.RowPress, HUDCustomizer.RowDrag = nil, nil
        return
    end

    local scale = layout.scale
    anim.t = math.min(1, math.max(0, anim.t + dt / 0.42 * (HUDCustomizer.IsOpen and 1 or -1.4)))

    local emerge = EaseOutCubic(anim.t / 0.55)
    local widen = EaseOutBack((anim.t - 0.28) / 0.72)
    local contentA = math.min(1, math.max(0, (anim.t - 0.58) / 0.42))

    local cardW = math.floor(300 * scale)
    local id = HUDCustomizer.InspectedChip
    if id then anim.PageId = id end

    if anim.LastId ~= id then
        anim.LastId = id
        local cfg = HUDCustomizer.WidgetConfigs[id]
        if cfg then
            anim.SegWeight.v, anim.SegWeight.vel = cfg.bold and 0 or 1, 0
            anim.SegFormat.v, anim.SegFormat.vel = (cfg.format or 1) - 1, 0
            anim.Knob.v, anim.Knob.vel = cfg.showIcon ~= false and 1 or 0, 0
            anim.KnobOn.v, anim.KnobOn.vel = Impl.IsChipInActiveList(id) and 1 or 0, 0
        end
    end

    local want = id and 1 or 0
    local hL, hD = Impl.EditorListH(scale), Impl.EditorDetailH(scale)
    local hMax = math.max(hL, hD)
    local moving = anim.Page.v > 0.002 and anim.Page.v < 0.998
    if moving or math.abs(anim.Page.v - want) < 0.002 or anim.h >= hMax - 1.5 then
        anim.Page.v, anim.Page.vel = MotionEngine.Step(anim.Page.v, anim.Page.vel, want, dt, "SMOOTH")
    end
    local pg = math.min(1, math.max(0, anim.Page.v))
    local settled = math.abs(pg - want) < 0.002
    local targetH = settled and (id and hD or hL) or hMax

    if anim.h <= 0 then
        anim.h, anim.hVel = targetH, 0
    else
        anim.h, anim.hVel = MotionEngine.Step(anim.h, anim.hVel, targetH, dt, settled and "SMOOTH" or "SNAPPY")
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

    SoftShadow(p1, p2, rad, Color(0, 0, 0, math.floor(200 * emerge)), 26, Vec2(0, 6))
    DrawerSurface(p1, p2, rad, emerge)

    HUDCustomizer.DrawerBounds = {}
    HUDCustomizer.InspectorBounds = {}

    Render.PushClip(Vec2(px + math.ceil(3 * scale), py), Vec2(px + panelW - math.ceil(3 * scale), py + panelH))

    local cx = math.floor(layout.x + (layout.w - cardW) / 2)

    local live = contentA > 0.6
    local glass = IsPureGlass()
    if pg < 0.99 then
        Impl.RenderEditorList(cx, py, cardW, scale, contentA * (glass and math.max(0, 1 - pg * 2) or (1 - 0.8 * pg)), dt, math.floor(-pg * cardW * 0.3), live and pg < 0.05)
    end
    if pg > 0.01 and anim.PageId then
        Impl.RenderEditorDetail(cx, py, cardW, scale, contentA * (glass and math.max(0, pg * 2 - 1) or 1), dt, math.floor((1 - pg) * cardW), anim.PageId, live and pg > 0.95, { x2 = p2.x, y2 = p2.y, r = rad })
    end

    local grabW = 34 * scale
    Render.FilledRect(Vec2(cx + (cardW - grabW) / 2, py + 8 * scale), Vec2(cx + (cardW + grabW) / 2, py + 12 * scale), FadeColor(Config.Colors.Grabber, contentA), 2 * scale)

    Render.PopClip()
    if pg > 0.01 and pg < 0.99 then
        Render.Rect(p1, p2, FadeColor(Config.Colors.Border, emerge), rad, Enum.DrawFlags.None, 1.0)
    end

    if HUDCustomizer.IsOpen and HUDCustomizer.InspectedChip then
        Impl.RenderColorPickerPopover(px, py, cardW, scale, dt)
    end
end

function Impl.RenderSecondarySatelliteBubble(layout)
    local R = Satellite.Right
    local scale = layout.scale
    local fontBold, headSize = TF("Headline", scale)
    local now = os.clock()
    local ts = StateMachine.TargetState
    local active = NotificationQueue.Active
    local desired, notif = nil, nil
    local rampageSuccess = now - Rampage.SuccessAt < 1.5
    local S = StateMachine.States
    if ts == S.FACE_ID then
    elseif Engine.IsInGame and Engine.IsInGame() then
        if not HUDCustomizer.IsOpen then
            local bubbleOn = UI.Media.SecondaryBubble:Get()
            if bubbleOn and active and ts ~= S.NOTIFICATION and IsNotifDeferred(active) then
                local left = (active.Duration or 3) - (now - (NotificationQueue.StartTime or now))
                if left > 0.45 then
                    desired, notif = "notif", active
                end
            end
            if not desired then
                local mainKind = (ts == S.NOTIFICATION or ts == S.SHEET) and "" or Impl.MainKind
                for _, it in ipairs(Impl.PlanList or {}) do
                    local k = (it.kind == "sdk" or it.kind == "sdk2") and "activity" or it.kind
                    if it.kind ~= mainKind and not Impl.SatHidden[k] and (bubbleOn or k == "rampage") then
                        desired = k
                        if k == "activity" then R.act = it.act end
                        break
                    end
                end
            end
        end
    elseif not HUDCustomizer.IsOpen and (Rampage.Active or rampageSuccess) then
        desired = "rampage"
    elseif UI.Media.SecondaryBubble:Get() and not HUDCustomizer.IsOpen then
        if active and IsNotifDeferred(active) and (ts == StateMachine.States.COMPACT_MEDIA or ts == StateMachine.States.LARGE_MEDIA) then
            local left = (active.Duration or 3) - (now - (NotificationQueue.StartTime or now))
            if left > 0.45 then
                desired, notif = "notif", active
            end
        elseif (ts == S.COMPACT_MEDIA or ts == S.LARGE_MEDIA) and now - (Impl.MenuSearchAt or 0) < 0.5 and not Impl.MenuSearchHidden then
            desired = "search"
        elseif ts == S.MENU_SEARCHING and Impl.MenuSwap and ToggleOn(UI.Media.InMenu) and IsMediaActive() then
            desired = "media"
        elseif FightTracker.Active and not active and Sdk.Current() then
            desired, R.act = "activity", Sdk.Current()
        elseif FightTracker.Active and (active or IsMediaActive()) then
            desired = "combat"
        elseif (ts == StateMachine.States.ACTIVITY or ts == StateMachine.States.ACTIVITY_LARGE) and IsMediaActive() then
            desired = "media"
        elseif (ts == StateMachine.States.ACTIVITY or ts == StateMachine.States.ACTIVITY_LARGE) and Sdk.Second() then
            desired, R.act = "activity", Sdk.Second()
        else
            local ros = GameTracker.Roshan
            if ros.AegisExpiryTime - GameRules.GetGameTime() > 0 and not ros.Dismissed and ts ~= StateMachine.States.NOTIFICATION then
                desired = "aegis"
            end
        end
    end
    if notif then R.notif = notif end
    local cur = Satellite.S.right
    if R.kind ~= desired and (not cur or cur.p < 0.04) then
        R.kind = desired
        if cur then cur.w, cur.wv = 0, 0 end
    end
    local kind = R.kind
    local combatMedia = kind == "combat" and not active and IsMediaActive()
    local wide = kind == "notif" or kind == "aegis" or kind == "search" or (combatMedia and FightTracker.SatelliteHover) or (kind == "rampage" and not rampageSuccess)
        or ((kind == "media" or kind == "activity" or kind == "pause" or kind == "courier" or kind == "fight") and FightTracker.SatelliteHover)
    local sat = Satellite.Step("right", kind ~= nil and kind == desired, wide)
    ButtonHits.SatellitePrev = nil
    ButtonHits.SatellitePlay = nil
    ButtonHits.SatelliteNext = nil
    if not kind then
        SatelliteBounds = nil
        return
    end

    local _, bh = Focus.SatRow(layout)
    local fullW = bh
    local content

    if kind == "notif" and R.notif then
        local n = R.notif
        local titleSize = headSize
        local title = TruncateToWidth(fontBold, titleSize, n.Title or n.Tag or "", math.floor(170 * scale))
        local tsz = Render.TextSize(fontBold, titleSize, title)
        fullW = bh + math.floor(5 * scale) + tsz.x + math.floor(bh * 0.38)
        local remain = 0
        if n == NotificationQueue.Active then
            remain = math.max(0, 1 - (now - (NotificationQueue.StartTime or now)) / math.max(0.5, n.Duration or 3))
        end
        content = function(x1, y1, x2, y2, d, ca, ta)
            local c = Vec2(x1 + d / 2, (y1 + y2) / 2)
            local ringR = d / 2 - 4 * scale
            local isz = math.floor(ringR * 1.25)
            local accent = n.AccentColor or Config.Colors.Accent
            local rt = math.max(1.2, 1.5 * scale)
            Render.Circle(c, ringR, FadeColor(Config.Colors.FillTertiary, ca), rt, 0, 1.0, false, 48)
            if remain > 0.01 then
                Render.Circle(c, ringR, FadeColor(accent, ca), rt, 270, remain, true, 48)
            end
            local fb = n.FallbackSvg
            local realImg = n.Icon and GetCachedImage(n.Icon) or nil
            local hIcon = realImg or ((fb and not NotifGlyphs[fb]) and GetCachedImage(nil, fb) or nil)
            if hIcon then
                Impl.Img(hIcon, Vec2(math.floor(c.x - isz / 2), math.floor(c.y - isz / 2)), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), ca), math.floor(isz / 2))
            else
                Render.FilledCircle(c, isz / 2, FadeColor(accent, ca), 0, 1.0, 24)
                Glyph(fb or "bell", c.x, c.y, math.floor(isz * 0.58), FadeColor(Color(255, 255, 255, 255), ca))
            end
            if ta > 0.01 then
                Render.Text(fontBold, titleSize, title, Vec2(math.floor(x1 + d + 5 * scale), math.floor(c.y - tsz.y / 2)), FadeColor(Config.Colors.TextPrimary, ta))
            end
        end
    elseif kind == "rampage" then
        local left = math.max(0, Rampage.Left or 0)
        local secs = tostring(math.ceil(left))
        local fontSize = headSize
        local tsz = Render.TextSize(fontBold, fontSize, "0")
        tsz = Vec2(Odometer.Width(fontBold, fontSize, secs), tsz.y)
        fullW = bh + math.floor(5 * scale) + tsz.x + math.floor(bh * 0.38)
        local sucT = now - Rampage.SuccessAt
        content = function(x1, y1, x2, y2, d, ca, ta)
            local c = Vec2(x1 + d / 2, (y1 + y2) / 2)
            local ringR = d / 2 - 4 * scale
            if sucT < 1.5 then
                Success.Draw("rampage" .. Rampage.SuccessAt, c, ringR, sucT, ca, scale)
                return
            end
            local urgent = left <= 5
            local col = urgent and Config.Colors.Red or Config.Colors.Orange
            local pulse = urgent and (0.7 + 0.3 * math.sin(now * 10)) or 1
            local rt = math.max(1.4, 1.8 * scale)
            Render.Circle(c, ringR, FadeColor(Config.Colors.FillTertiary, ca), rt, 0, 1.0, false, 48)
            local frac = math.max(0, math.min(1, left / 18))
            if frac > 0.002 then
                Render.Circle(c, ringR, FadeColor(col, ca * pulse), rt, 270, frac, true, 48)
            end
            if Rampage.Target then
                local isz = math.floor(ringR * 1.3)
                local hImg = GetCachedImage("panorama/images/heroes/icons/" .. Rampage.Target .. "_png.vtex_c")
                if hImg then
                    Impl.Img(hImg, Vec2(math.floor(c.x - isz / 2), math.floor(c.y - isz / 2)), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), ca), math.floor(isz / 2))
                end
            end
            if ta > 0.01 then
                Odometer.Text("rampage_time", fontBold, fontSize, secs, Vec2(math.floor(x1 + d + 5 * scale), math.floor(c.y - tsz.y / 2)), FadeColor(urgent and col or Config.Colors.TextPrimary, ta))
            end
        end
    elseif kind == "aegis" then
        local rem = math.max(0, GameTracker.Roshan.AegisExpiryTime - GameRules.GetGameTime())
        local timeStr = FormatTime(rem)
        local fontSize = headSize
        local tsz = Render.TextSize(fontBold, fontSize, "0")
        tsz = Vec2(Odometer.Width(fontBold, fontSize, timeStr), tsz.y)
        fullW = bh + math.floor(5 * scale) + tsz.x + math.floor(bh * 0.38)
        content = function(x1, y1, x2, y2, d, ca, ta)
            local c = Vec2(x1 + d / 2, (y1 + y2) / 2)
            local ringR = d / 2 - 4 * scale
            local isz = math.floor(ringR * 1.25)
            local rt = math.max(1.2, 1.5 * scale)
            Render.Circle(c, ringR, FadeColor(Config.Colors.FillTertiary, ca), rt, 0, 1.0, false, 48)
            local frac = math.max(0, math.min(1, rem / 300))
            if frac > 0.002 then
                Render.Circle(c, ringR, FadeColor(Config.Colors.Yellow, ca), rt, 270, frac, true, 48)
            end
            local aegisH = GetCachedImage("panorama/images/items/aegis_png.vtex_c")
            if aegisH then
                Impl.Img(aegisH, Vec2(math.floor(c.x - isz / 2), math.floor(c.y - isz / 2)), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), ca), math.floor(isz / 2))
            end
            if ta > 0.01 then
                Odometer.Text("aegis_time", fontBold, fontSize, timeStr, Vec2(math.floor(x1 + d + 5 * scale), math.floor(c.y - tsz.y / 2)), FadeColor(Config.Colors.TextPrimary, ta))
            end
        end
    elseif kind == "pause" then
        local elapsed = PauseTracker.PauseStartTime > 0 and math.floor(now - PauseTracker.PauseStartTime) or 0
        local timeStr = string.format("%d:%02d", math.floor(elapsed / 60), elapsed % 60)
        local tw = Odometer.Width(fontBold, headSize, timeStr)
        local th = Render.TextSize(fontBold, headSize, "0").y
        fullW = bh + math.floor(5 * scale) + tw + math.floor(bh * 0.38)
        content = function(x1, y1, x2, y2, d, ca, ta)
            local c = Vec2(x1 + d / 2, (y1 + y2) / 2)
            local isz = math.floor(d * 0.46)
            local h = GetVectorIcon("pause")
            if h then
                Impl.Img(h, Vec2(math.floor(c.x - isz / 2), math.floor(c.y - isz / 2)), Vec2(isz, isz), FadeColor(Config.Colors.Orange, ca), 0)
            end
            if ta > 0.01 then
                Odometer.Text("sat_pause", fontBold, headSize, timeStr, Vec2(math.floor(x1 + d + 5 * scale), math.floor(c.y - th / 2)), FadeColor(Config.Colors.TextPrimary, ta))
            end
        end
    elseif kind == "courier" then
        local delivered = CourierTracker.Delivered
        local txt = delivered and L("di_courier_delivered") or ((CourierTracker.ETA > 0) and FormatTime(CourierTracker.ETA) or L("di_ui_courier_delivering_short"))
        local tw = delivered and Render.TextSize(fontBold, headSize, txt).x or Odometer.Width(fontBold, headSize, txt)
        local th = Render.TextSize(fontBold, headSize, "0").y
        fullW = bh + math.floor(5 * scale) + tw + math.floor(bh * 0.38)
        content = function(x1, y1, x2, y2, d, ca, ta)
            local c = Vec2(x1 + d / 2, (y1 + y2) / 2)
            local ringR = d / 2 - 4 * scale
            if delivered then
                Success.Draw("sat_courier" .. CourierTracker.DeliveredStartTime, c, ringR, CourierTracker.FaceFor == CourierTracker.DeliveredStartTime and 99 or now - CourierTracker.DeliveredStartTime, ca, scale)
            else
                local rt = math.max(1.2, 1.5 * scale)
                Render.Circle(c, ringR, FadeColor(Config.Colors.FillTertiary, ca), rt, 0, 1.0, false, 48)
                local frac = math.max(0, math.min(1, CourierTracker.Progress or 0))
                if frac > 0.002 then
                    Render.Circle(c, ringR, FadeColor(Config.Colors.Green, ca), rt, 270, frac, true, 48)
                end
                local isz = math.floor(ringR * 1.1)
                local h = GetVectorIcon("courier")
                if h then
                    Impl.Img(h, Vec2(math.floor(c.x - isz / 2), math.floor(c.y - isz / 2)), Vec2(isz, isz), FadeColor(Config.Colors.Yellow, ca), 0)
                end
            end
            if ta > 0.01 then
                local pos = Vec2(math.floor(x1 + d + 5 * scale), math.floor(c.y - th / 2))
                if delivered then
                    Render.Text(fontBold, headSize, txt, pos, FadeColor(Config.Colors.TextPrimary, ta))
                else
                    Odometer.Text("sat_courier", fontBold, headSize, txt, pos, FadeColor(Config.Colors.TextPrimary, ta))
                end
            end
        end
    elseif kind == "search" then
        local txt = Impl.MenuSearchTime or "0:00"
        local tw = Odometer.Width(fontBold, headSize, txt)
        local th = Render.TextSize(fontBold, headSize, "0").y
        fullW = bh + math.floor(5 * scale) + tw + math.floor(bh * 0.38)
        content = function(x1, y1, x2, y2, d, ca, ta)
            local c = Vec2(x1 + d / 2, (y1 + y2) / 2)
            Journey.Spinner(c.x, c.y, d * 0.25, Config.Colors.TextPrimary, ca)
            if ta > 0.01 then
                Odometer.Text("sat_search", fontBold, headSize, txt, Vec2(math.floor(x1 + d + 5 * scale), math.floor(c.y - th / 2)), FadeColor(Config.Colors.Blue, ta))
            end
        end
    elseif kind == "fight" then
        local txt = string.format("%d vs %d", FightTracker.AllyCount or 0, FightTracker.EnemyCount or 0)
        local tw = Odometer.Width(fontBold, headSize, txt)
        local th = Render.TextSize(fontBold, headSize, "0").y
        fullW = bh + math.floor(5 * scale) + tw + math.floor(bh * 0.38)
        content = function(x1, y1, x2, y2, d, ca, ta)
            local c = Vec2(x1 + d / 2, (y1 + y2) / 2)
            local isz = math.floor(d * 0.5)
            local h = GetVectorIcon("swords")
            if h then
                Impl.Img(h, Vec2(math.floor(c.x - isz / 2), math.floor(c.y - isz / 2)), Vec2(isz, isz), FadeColor(Config.Colors.Red, ca), 0)
            end
            if ta > 0.01 then
                Odometer.Text("sat_fight", fontBold, headSize, txt, Vec2(math.floor(x1 + d + 5 * scale), math.floor(c.y - th / 2)), FadeColor(Config.Colors.TextPrimary, ta))
            end
        end
    elseif kind == "activity" and R.act then
        local a = R.act
        local txt = Sdk.Trailing(a)
        local tw = txt and Odometer.Width(fontBold, headSize, txt) or 0
        local th = Render.TextSize(fontBold, headSize, "0").y
        fullW = txt and (bh + math.floor(5 * scale) + tw + math.floor(bh * 0.38)) or bh
        content = function(x1, y1, x2, y2, d, ca, ta)
            local c = Vec2(x1 + d / 2, (y1 + y2) / 2)
            local ringR = d / 2 - 4 * scale
            local tint = Impl.OnLight(a.tint or Config.Colors.Blue)
            local frac = Sdk.Frac(a)
            if frac then
                local rt = math.max(1.2, 1.5 * scale)
                Render.Circle(c, ringR, FadeColor(Config.Colors.FillTertiary, ca), rt, 0, 1.0, false, 48)
                if frac > 0.002 then
                    Render.Circle(c, ringR, FadeColor(tint, ca), rt, 270, frac, true, 48)
                end
            end
            local isz = math.floor(ringR * (frac and 1.05 or 1.35))
            local img = a.image and GetCachedImage(a.image) or nil
            if img then
                Impl.Img(img, Vec2(math.floor(c.x - isz / 2), math.floor(c.y - isz / 2)), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), ca), math.floor(isz / 2))
            else
                Glyph(a.glyph or "bell", c.x, c.y, isz, FadeColor(tint, ca))
            end
            if ta > 0.01 and txt then
                Odometer.Text("sat_activity", fontBold, headSize, txt, Vec2(math.floor(x1 + d + 5 * scale), math.floor(c.y - th / 2)), FadeColor(tint, ta))
            end
        end
    else
        local step = math.floor(26 * scale)
        fullW = bh + step * 3 + math.floor(6 * scale)
        content = function(x1, y1, x2, y2, d, ca, ta)
            local c = Vec2(x1 + d / 2, (y1 + y2) / 2)
            if active and kind ~= "media" then
                local isz = math.floor(d * 0.52)
                local hIcon = GetCachedImage(active.Icon, active.FallbackSvg)
                if hIcon then
                    Impl.Img(hIcon, Vec2(math.floor(c.x - isz / 2), math.floor(c.y - isz / 2)), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), ca), math.floor(isz / 2))
                end
                return
            end
            local thumb = math.floor(d * 0.62)
            DrawAlbumThumbnail(math.floor(c.x - thumb / 2), math.floor(c.y - thumb / 2), thumb, thumb / 2, ca)
            if ta <= 0.01 then return end
            local bx0 = x1 + d + math.floor(step / 2)
            local items = {
                { key = "SatellitePrev", icon = "media_prev", size = 12 },
                { key = "SatellitePlay", icon = MediaData.IsPlaying and "media_pause" or "media_play", size = 14 },
                { key = "SatelliteNext", icon = "media_next", size = 12 }
            }
            for i, it in ipairs(items) do
                local bxc = math.floor(bx0 + (i - 1) * step)
                ButtonHits[it.key] = { x1 = bxc - step / 2, y1 = y1, x2 = bxc + step / 2, y2 = y2 }
                local sz = math.floor(it.size * scale * ButtonSprings[it.key].scale)
                local h = GetVectorIcon(it.icon)
                if h then
                    Impl.Img(h, Vec2(math.floor(bxc - sz / 2), math.floor(c.y - sz / 2)), Vec2(sz, sz), FadeColor(Config.Colors.TextPrimary, ta), 0)
                end
            end
        end
    end

    SatelliteBounds = Satellite.Draw(layout, sat, 1, fullW, content)
end

function Impl.RenderMenuClosedHint(layout)
    if not Menu.Opened or not Menu.Opened() then return end
    if HUDCustomizer.IsOpen then return end
    if DragState.IsDragging then return end

    local lines = Impl.CollectStatusHints()
    if UI.Media.Hints:Get() then
        table.insert(lines, { text = L("di_ui_controls_hint") })
    end
    if #lines == 0 then return end

    local scale = layout.scale
    local f, s = TF("Footnote", scale)
    local boxH = math.floor(22 * scale)
    local y = math.floor(layout.y + layout.h + 8 * scale)
    for _, line in ipairs(lines) do
        local ts = Render.TextSize(f, s, line.text)
        local dotW = line.dot and math.floor(12 * scale) or 0
        local boxW = math.floor(ts.x + 22 * scale + dotW)
        local x = math.floor(layout.x + (layout.w - boxW) / 2)
        Render.FilledRect(Vec2(x, y), Vec2(x + boxW, y + boxH), Config.Colors.HintBg, boxH / 2)
        Render.Rect(Vec2(x, y), Vec2(x + boxW, y + boxH), Config.Colors.HintBorder, boxH / 2, Enum.DrawFlags.None, 1.0)
        local tx = x + 11 * scale
        if line.dot then
            Render.FilledCircle(Vec2(tx + 3 * scale, y + boxH / 2), 3 * scale, line.dot, 0, 1.0, 12)
            tx = tx + dotW
        end
        Render.Text(f, s, line.text, Vec2(math.floor(tx), math.floor(y + (boxH - ts.y) / 2)), Config.Colors.TextSecondary)
        y = y + boxH + math.floor(6 * scale)
    end
end

function Impl.CompactTitleX(layout, textStartX, textAvailW, font, size, title)
    if not UI.Media.CenterShortTitle:Get() then return textStartX end
    local titleW = Render.TextSize(font, size, title).x
    if titleW >= textAvailW then return textStartX end
    local centerX = layout.x + (layout.w - titleW) / 2
    return math.floor(math.max(textStartX, math.min(centerX, textStartX + textAvailW - titleW)))
end

local function RenderCompactMedia(layout, alphaMul, yOffset)
    local aMul = alphaMul or 1.0
    local yOff = yOffset or 0
    local scale = layout.scale
    local fontBold, headSize = TF("Headline", scale)
    local textCol = FadeColor(Config.Colors.TextPrimary, aMul)
    local waveCol = MediaTint()

    local thumbSize = math.floor(20 * scale)
    local thumbX = math.floor(layout.x + (layout.h - thumbSize) / 2)
    local thumbY = math.floor(layout.y + (layout.h - thumbSize) / 2 + yOff)

    local waveCount = 5
    local waveW = math.floor(waveCount * (2.4 * scale) + (waveCount - 1) * (1.8 * scale))
    local waveX = math.floor(layout.x + layout.w - waveW - 10 * scale)
    local waveY = math.floor(layout.y + (layout.h - 18 * scale) / 2 + yOff)

    local textStartX = math.floor(thumbX + thumbSize + 8 * scale)
    local textAvailW = math.max(10, math.floor((waveX - 4 * scale) - textStartX))

    local displayStr = MediaData.Title ~= "" and MediaData.Title or L("di_ui_music")
    if UI.Media.ShowArtist:Get() and MediaData.Artist ~= "" and MediaData.Title ~= "" then
        displayStr = MediaData.Title .. " • " .. MediaData.Artist
    end

    local tH = Render.TextSize(fontBold, headSize, "Ag").y
    local textY = math.floor(layout.y + (layout.h - tH) / 2 + yOff)

    local nowClk = os.clock()
    if TrackTransition.Active then
        local t = math.min(1.0, (nowClk - TrackTransition.StartTime) / (TrackTransition.Duration * AnimScale()))
        local dir = TrackTransition.Direction
        local e = EaseOutCubic(t)
        local outOffset = -dir * (e * 6 * scale)
        local outAlpha = (1.0 - t) * aMul
        local inOffset = dir * ((1.0 - e) * 6 * scale)
        local inAlpha = t * aMul

        local showTitle = CompactMediaTitle()
        if outAlpha > 0.02 and TrackTransition.OldTitle ~= "" then
            local oldStr = TrackTransition.OldTitle .. (UI.Media.ShowArtist:Get() and TrackTransition.OldArtist ~= "" and (" • " .. TrackTransition.OldArtist) or "")
            if showTitle then RenderMarqueeText(fontBold, headSize, oldStr, Impl.CompactTitleX(layout, textStartX, textAvailW, fontBold, headSize, oldStr) + outOffset, textY, textAvailW, FadeColor(Config.Colors.TextPrimary, outAlpha), scale) end
            DrawAlbumThumbnail(thumbX, thumbY, thumbSize, 5 * scale, outAlpha, 1.0 - t * 0.15, TrackTransition.OldCoverHandle, TrackTransition.OldCoverColor)
        end
        if inAlpha > 0.02 then
            if showTitle then RenderMarqueeText(fontBold, headSize, displayStr, Impl.CompactTitleX(layout, textStartX, textAvailW, fontBold, headSize, displayStr) + inOffset, textY, textAvailW, FadeColor(Config.Colors.TextPrimary, inAlpha), scale) end
            DrawAlbumThumbnail(thumbX, thumbY, thumbSize, 5 * scale, inAlpha, 0.85 + t * 0.15)
        end
        if t >= 1.0 then
            TrackTransition.Active = false
        end
    else
        if CompactMediaTitle() and not (Impl.LyCompactOn() and Impl.LyCompactDraw(textStartX, textY, textAvailW, fontBold, headSize, aMul, scale, displayStr)) then
            RenderMarqueeText(fontBold, headSize, displayStr, Impl.CompactTitleX(layout, textStartX, textAvailW, fontBold, headSize, displayStr), textY, textAvailW, textCol, scale)
        end
        DrawAlbumThumbnail(thumbX, thumbY, thumbSize, 5 * scale, aMul)
    end

    DrawAppleWaveform(waveX, waveY, 18, waveCount, MediaData.IsPlaying, scale, waveCol, aMul)
end

function Impl.RenderFightCompact(layout, alphaMul, yOffset)
    local aMul = alphaMul or 1.0
    local yOff = yOffset or 0
    local scale = layout.scale
    local f, s = TF("Headline", scale)

    local iconSz = math.floor(16 * scale)
    local iconX = math.floor(layout.x + 12 * scale)
    local iconY = math.floor(layout.y + (layout.h - iconSz) / 2 + yOff)

    local swordsSvg = GetVectorIcon("swords")
    if swordsSvg then
        Impl.Img(swordsSvg, Vec2(iconX, iconY), Vec2(iconSz, iconSz), FadeColor(Config.Colors.Red, aMul), 0)
    else
        Render.FilledCircle(Vec2(iconX + iconSz / 2, iconY + iconSz / 2), iconSz / 2, FadeColor(Config.Colors.Red, aMul), 0, 1.0, 18)
    end

    local scoreStr = string.format("%d vs %d", FightTracker.AllyCount, FightTracker.EnemyCount)
    local lmarkStr = FightTracker.Landmark ~= "" and FightTracker.Landmark or L("di_ui_fight")
    local fullText = scoreStr .. " \u{2022} " .. lmarkStr

    local textStartX = math.floor(iconX + iconSz + 8 * scale)
    local textAvailW = math.max(10, math.floor(layout.x + layout.w - textStartX - 12 * scale))
    local tH = Render.TextSize(f, s, "Ag").y
    local textY = math.floor(layout.y + (layout.h - tH) / 2 + yOff)

    RenderMarqueeText(f, s, fullText, textStartX, textY, textAvailW, FadeColor(Config.Colors.TextPrimary, aMul), scale)
end

local CachedDotaMapHandle = nil
local DotaMapFailed = false
local DotaMapNextRetry = 0
local LastMapWarmCheck = 0
function Impl.GetDotaMapTexture()
    if CachedDotaMapHandle ~= nil then return CachedDotaMapHandle end
    if DotaMapFailed and os.clock() < DotaMapNextRetry then return nil end
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
        if ImageCache[mp] == false then ImageCache[mp] = nil end
        local h = GetCachedImage(mp)
        if h and h > 0 then
            CachedDotaMapHandle = h
            DotaMapFailed = false
            return h
        end
    end

    DotaMapFailed = true
    DotaMapNextRetry = os.clock() + 30.0
    return nil
end

function Impl.RenderFightLarge(layout, alphaMul, yOffset)
    local aMul = alphaMul or 1.0
    local yOff = yOffset or 0
    local scale = layout.scale
    local fTitle, sTitle = TF("Title", scale)
    local fSub, sSub = TF("Subhead", scale)
    local fName, sName = TF("Headline", scale)
    local textCol = FadeColor(Config.Colors.TextPrimary, aMul)
    local subCol = FadeColor(Config.Colors.TextSecondary, aMul)

    local padX = math.floor(16 * scale)
    local padY = math.floor(14 * scale)

    local inset = math.floor(12 * scale)
    local radarAvail = math.min(124 * scale, layout.h - inset * 2)
    local radarSz = math.max(math.floor(34 * scale), math.floor(radarAvail))
    local radarR = math.max(6 * scale, math.min(radarSz / 2, layout.r - inset))
    local radarX = math.floor(layout.x + layout.w - inset - radarSz)
    local radarY = math.floor(layout.y + (layout.h - radarSz) / 2 + yOff)

    local headerScore = string.format("%d vs %d", FightTracker.AllyCount, FightTracker.EnemyCount)
    local lmark = FightTracker.Landmark ~= "" and FightTracker.Landmark or L("di_ui_map")

    local hdrSize = Render.TextSize(fTitle, sTitle, headerScore)
    local hdrY = math.floor(layout.y + padY + yOff - 2 * scale)
    local swords = GetVectorIcon("swords")
    local swSz = math.floor(15 * scale)
    local hdrX = layout.x + padX
    if swords then
        Impl.Img(swords, Vec2(hdrX, math.floor(hdrY + hdrSize.y / 2 - swSz / 2)), Vec2(swSz, swSz), FadeColor(Config.Colors.Red, aMul), 0)
        hdrX = hdrX + swSz + math.floor(7 * scale)
    end
    Odometer.Draw(fTitle, sTitle, headerScore, Vec2(hdrX, hdrY), textCol)
    local fightW = Odometer.Width(fTitle, sTitle, headerScore)
    Render.Text(fSub, sSub, L("di_ui_fight"), Vec2(math.floor(hdrX + fightW + 6 * scale), math.floor(hdrY + hdrSize.y - Render.TextSize(fSub, sSub, "Ag").y - 1 * scale)), subCol)
    Render.Text(fSub, sSub, TruncateToWidth(fSub, sSub, lmark, math.floor(radarX - 12 * scale - layout.x - padX)), Vec2(layout.x + padX, math.floor(hdrY + hdrSize.y + 1 * scale)), subCol)

    local function PickPriorityCombatant(list)
        local best, bestPct = nil, nil
        for _, h in ipairs(list) do
            local hp = Entity.GetHealth(h)
            local maxHp = math.max(1, Entity.GetMaxHealth(h))
            local pct = hp / maxHp
            if not best or pct < bestPct then
                best, bestPct = h, pct
            end
        end
        return best
    end

    local combatants = {}
    local priorityAlly = PickPriorityCombatant(FightTracker.Allies)
    local priorityEnemy = PickPriorityCombatant(FightTracker.Enemies)
    if priorityAlly then table.insert(combatants, { hero = priorityAlly, isAlly = true }) end
    if priorityEnemy then table.insert(combatants, { hero = priorityEnemy, isAlly = false }) end

    local rowY = math.floor(layout.y + padY + 42 * scale + yOff)
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
            Render.Line(Vec2(layout.x + padX + 2 * scale, divY), Vec2(radarX - 10 * scale, divY), FadeColor(Config.Colors.Separator, aMul), 1.0)
        end

        local heroIconPath = "panorama/images/heroes/icons/" .. rawName .. "_png.vtex_c"
        local hHandle = GetCachedImage(heroIconPath)
        if hHandle then
            Impl.Img(hHandle, Vec2(ax, ay), Vec2(avatarSz, avatarSz), FadeColor(Color(255, 255, 255, 255), aMul), avatarSz / 2)
        else
            local dotCol = c.isAlly and Config.Colors.Green or Config.Colors.Red
            Render.FilledCircle(Vec2(ax + avatarSz / 2, ay + avatarSz / 2), avatarSz / 2, FadeColor(dotCol, aMul), 0, 1.0, 18)
        end

        local nameX = math.floor(ax + avatarSz + 10 * scale)
        local barW = math.floor(radarX - 14 * scale - nameX)

        Render.Text(fName, sName, TruncateToWidth(fName, sName, hName, math.floor(radarX - 10 * scale - nameX)), Vec2(nameX, math.floor(ay - 2 * scale)), textCol)

        local barY = math.floor(ay + 18 * scale)
        local barH = math.max(3, math.floor(4 * scale))
        local barR = barH / 2
        local gapB = math.floor(4 * scale)
        local hpW = math.floor((barW - gapB) * 0.62)
        local manaW = barW - gapB - hpW
        local manaX = nameX + hpW + gapB

        Render.FilledRect(Vec2(nameX, barY), Vec2(nameX + hpW, barY + barH), FadeColor(Config.Colors.FillTertiary, aMul), barR)
        if hpPct > 0 then
            local hpCol = c.isAlly and Config.Colors.Green or Config.Colors.Red
            Render.FilledRect(Vec2(nameX, barY), Vec2(nameX + math.max(barH, hpW * hpPct), barY + barH), FadeColor(hpCol, aMul), barR)
        end

        Render.FilledRect(Vec2(manaX, barY), Vec2(manaX + manaW, barY + barH), FadeColor(Config.Colors.FillTertiary, aMul), barR)
        if manaPct > 0 then
            Render.FilledRect(Vec2(manaX, barY), Vec2(manaX + math.max(barH, manaW * manaPct), barY + barH), FadeColor(Config.Colors.Blue, aMul), barR)
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

    local mapH = Impl.GetDotaMapTexture()

    Render.FilledRect(rP1, rP2, FadeColor(Config.Colors.FillQuaternary, aMul), radarR)

    Render.PushClip(rP1, rP2)

    if mapH and mapH > 0 then
        Impl.Img(mapH, rP1, Vec2(radarSz, radarSz), FadeColor(Color(255, 255, 255, 255), aMul), radarR, Enum.DrawFlags.None, uvMin, uvMax)
        Render.FilledRect(rP1, rP2, FadeColor(Color(0, 0, 0, 70), aMul), radarR)
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

            local tSz = math.floor(18 * scale)
            local edge = tSz / 2 + 3 * scale
            hX = math.max(radarX + edge, math.min(radarX + radarSz - edge, hX))
            hY = math.max(radarY + edge, math.min(radarY + radarSz - edge, hY))
            local rawName = NPC.GetUnitName(h)
            local hIcon = GetCachedImage("panorama/images/heroes/icons/" .. rawName .. "_png.vtex_c")
            local isAlly = c.isAlly
            local arrowCol = isAlly and Config.Colors.Green or Config.Colors.Red

            if Entity.GetRotationPYR then
                local _, yaw, _ = Entity.GetRotationPYR(h)
                if yaw then
                    local rad = math.rad(-yaw)
                    local dirX = math.cos(rad)
                    local dirY = math.sin(rad)

                    local base = tSz / 2 + 1 * scale
                    local tip = Vec2(hX + dirX * (base + 5 * scale), hY + dirY * (base + 5 * scale))
                    local s1 = Vec2(hX + dirX * base - dirY * 4 * scale, hY + dirY * base + dirX * 4 * scale)
                    local s2 = Vec2(hX + dirX * base + dirY * 4 * scale, hY + dirY * base - dirX * 4 * scale)

                    Render.FilledTriangle({ tip, s1, s2 }, FadeColor(arrowCol, aMul))
                end
            end

            Render.FilledCircle(Vec2(hX, hY), tSz / 2 + 2 * scale, FadeColor(arrowCol, aMul), 0, 1.0, 24)
            if hIcon then
                Impl.Img(hIcon, Vec2(math.floor(hX - tSz / 2), math.floor(hY - tSz / 2)), Vec2(tSz, tSz), FadeColor(Color(255, 255, 255, 255), aMul), tSz / 2)
            else
                Render.FilledCircle(Vec2(hX, hY), tSz / 2, FadeColor(Config.Colors.TextPrimary, aMul), 0, 1.0, 16)
            end
        end
    end

    Render.PopClip()

    Render.Rect(rP1, rP2, FadeColor(Config.Colors.Border, aMul), radarR, Enum.DrawFlags.None, 1.0)
end

function Impl.RenderNotificationState(layout, alphaMul, yOffset)
    local notif = NotificationQueue.Active or NotificationQueue.LastDismissed
    if not notif then
        if IsMediaActive() then
            RenderCompactMedia(layout, alphaMul, yOffset)
        else
            RenderModularIdlePill(layout, alphaMul, yOffset)
        end
        return
    end

    if notif.SdkApp and Sdk.ExpandK > 0.01 and notif == NotificationQueue.Active then
        local k = math.max(0, math.min(1, Sdk.ExpandK))
        Sdk.RenderExpanded(layout, (alphaMul or 1) * math.max(0, (k - 0.35) / 0.65), yOffset, notif)
        alphaMul = (alphaMul or 1) * math.max(0, 1 - k * 2.2)
        if alphaMul <= 0.01 then return end
    end

    local aMul = alphaMul or 1.0
    local yOff = yOffset or 0
    local scale = layout.scale
    local fTag, sTag = TF("Caption", scale)
    local fTitle, sTitle = TF("Headline", scale)
    local textCol = FadeColor(Config.Colors.TextPrimary, aMul)
    local now = os.clock()

    local function TwoLines(textX, maxW, tagStr, tagCol, titleStr)
        local tagSize = Render.TextSize(fTag, sTag, tagStr)
        local titleSize = Render.TextSize(fTitle, sTitle, "Ag")
        local totalH = tagSize.y + titleSize.y
        local startY = math.floor(layout.y + (layout.h - totalH) / 2 + yOff)
        Render.Text(fTag, sTag, TruncateToWidth(fTag, sTag, tagStr, maxW), Vec2(textX, startY), FadeColor(Impl.OnLight(tagCol), aMul))
        Render.Text(fTitle, sTitle, TruncateToWidth(fTitle, sTitle, titleStr or "", maxW), Vec2(textX, math.floor(startY + tagSize.y)), textCol)
    end

    local function QueueBadge()
        local n = (notif == NotificationQueue.Active) and #NotificationQueue.List or 0
        if n <= 0 then return 0 end
        local fB, sB = TF("Caption", scale)
        fB = Config.Fonts.Semibold
        local txt = "+" .. n
        local tw = Odometer.Width(fB, sB, txt)
        local th = Render.TextSize(fB, sB, txt).y
        local h = math.floor(18 * scale)
        local w = math.floor(math.max(h, tw + 12 * scale))
        local bx = math.floor(layout.x + layout.w - 14 * scale - w)
        local by = math.floor(layout.y + (layout.h - h) / 2 + yOff)
        Render.FilledRect(Vec2(bx, by), Vec2(bx + w, by + h), FadeColor(Config.Colors.Fill, aMul), h / 2)
        Odometer.Draw(fB, sB, txt, Vec2(math.floor(bx + (w - tw) / 2), math.floor(by + (h - th) / 2)), FadeColor(Config.Colors.TextSecondary, aMul))
        return math.floor(w + 8 * scale)
    end

    local accent = notif.AccentColor or GetPrimaryThemeColor()
    local iconH = math.floor(24 * scale)
    local iconW = math.floor(24 * scale)
    local iconRadius = math.floor(math.max(5 * scale, layout.r - (layout.h - iconH) / 2))
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

        local iconX = math.floor(layout.x + 12 * scale)
        local iconY = math.floor(layout.y + (layout.h - iconH) / 2 + yOff)

        Render.PushClip(Vec2(iconX - 2, iconY - 2), Vec2(iconX + iconW + 2, iconY + iconH + 2))

        local hA = GetCachedImage(PowerRunesCycleList[idxA].path, PowerRunesCycleList[idxA].svg)
        local hB = GetCachedImage(PowerRunesCycleList[idxB].path, PowerRunesCycleList[idxB].svg)
        local offA = -smoothFrac * 16 * scale
        local offB = (1.0 - smoothFrac) * 16 * scale

        if hA then Impl.Img(hA, Vec2(iconX, iconY + offA), Vec2(iconW, iconH), FadeColor(Color(255, 255, 255, 255), (1.0 - smoothFrac) * aMul), math.floor(iconW / 2)) end
        if hB then Impl.Img(hB, Vec2(iconX, iconY + offB), Vec2(iconW, iconH), FadeColor(Color(255, 255, 255, 255), smoothFrac * aMul), math.floor(iconW / 2)) end

        Render.PopClip()
    else
        if notif.IconType == "rune" or notif.FallbackSvg == "bounty" or notif.FallbackSvg == "rune_wisdom" or notif.FallbackSvg == "rune_water" or notif.FallbackSvg == "lotus" then
            iconRadius = math.floor(iconW / 2)
            iconHandle = GetCachedImage(notif.Icon, notif.FallbackSvg)
        elseif notif.IconType == "item" then
            iconW = math.floor(30 * scale)
            iconH = math.floor(22 * scale)
            iconRadius = math.floor(5 * scale)
            iconHandle = GetCachedImage(notif.Icon, notif.FallbackSvg)
        elseif notif.IconType == "hero" then
            iconW = math.floor(26 * scale)
            iconH = math.floor(26 * scale)
            iconRadius = math.floor(13 * scale)
            iconHandle = GetCachedImage(notif.Icon, notif.FallbackSvg)
        else
            iconHandle = GetCachedImage(notif.Icon, notif.FallbackSvg)
        end

        local iconX = math.floor(layout.x + 12 * scale)
        local iconY = math.floor(layout.y + (layout.h - iconH) / 2 + yOff)

        local fb = notif.FallbackSvg
        local mono = fb and (NotifGlyphs[fb] or notif.Mono)
        local realImg = notif.Icon and GetCachedImage(notif.Icon) or nil
        if realImg or (iconHandle and not mono) then
            Impl.Img(realImg or iconHandle, Vec2(iconX, iconY), Vec2(iconW, iconH), FadeColor(Color(255, 255, 255, 255), aMul), iconRadius)
        else
            local cx, cy = iconX + iconW / 2, iconY + iconH / 2
            Render.FilledCircle(Vec2(cx, cy), iconH / 2, FadeColor(accent, aMul), 0, 1.0, 24)
            Glyph(fb or "bell", cx, cy, math.floor(iconH * 0.58), FadeColor(Color(255, 255, 255, 255), aMul))
        end
    end

    local textX = math.floor(layout.x + 12 * scale + iconW + 10 * scale)
    local qW = QueueBadge()
    if notif.Trailing then
        qW = qW + Sdk.DrawPill(layout, notif, qW, yOff, aMul)
    end
    TwoLines(textX, math.floor(layout.x + layout.w - textX - 16 * scale - qW), notif.Tag or L("di_ui_notification"), accent, notif.Title)
end

Impl.Ly = { Key = nil, Status = "idle", Lines = {}, Open = false, Btn = 0, Scroll = 0, ScrollV = 0, Target = 0, ChangedAt = 0, RetryAt = 0, Idx = 0, Hits = {}, WrapW = 0, WrapS = 0 }
Impl.LyH = 92

function Impl.LyOn()
    return UI and UI.Media and UI.Media.Lyrics and UI.Media.Lyrics:Get() or false
end

function Impl.LyWant()
    local Ly = Impl.Ly
    return Ly.Open and Ly.Status == "ok" and #Ly.Lines > 0 and Impl.LyOn() or false
end

function Impl.LyReply(key, res)
    local Ly = Impl.Ly
    if Ly.Key ~= key then return end
    local body = res and res.response or ""
    local head = string.match(body, "^([^\n]*)") or ""
    if head == "ok" then
        local lines = {}
        for ms, raw in string.gmatch(body, "\n(%d+)\t([^\n]*)") do
            local text = string.match(raw, "^([^\t]*)")
            local s = string.match(text or "", "^%s*(.-)%s*$") or ""
            local gap = s == "" or s == "\u{266A}" or s == "\u{266B}" or s == "\u{2026}" or s == "..."
            local prev = lines[#lines]
            if not (gap and prev and prev.gap) then
                lines[#lines + 1] = { t = tonumber(ms) / 1000, x = gap and "" or s, gap = gap, a = 0, h = 0 }
            end
        end
        if #lines > 0 and not lines[1].gap and lines[1].t > 3 then table.insert(lines, 1, { t = 0, x = "", gap = true, a = 0, h = 0 }) end
        while #lines > 0 and lines[#lines].gap do lines[#lines] = nil end
        Ly.Lines = lines
        Ly.Status = #lines > 0 and "ok" or "none"
        Ly.WrapW = 0
    elseif head == "pending" then
        Ly.Status = "wait"
        Ly.ChangedAt = os.clock() + 0.4
        return
    elseif head == "none" or head == "instrumental" then
        Ly.Status = head
    else
        Ly.Status = "error"
        Ly.RetryAt = os.clock() + 20
    end
    if Dbg.On then
        local name = string.gsub(key, "\n", " - ")
        Dbg.Log("media", "lyrics for \"" .. name .. "\": " .. Ly.Status .. (Ly.Status == "ok" and (", " .. #Ly.Lines .. " lines") or (head ~= Ly.Status and (" (" .. string.sub(head, 1, 60) .. ")") or "")))
    end
end

function Impl.LyTick(dt)
    local Ly = Impl.Ly
    local on = Impl.LyOn()
    local target = (on and Ly.Status == "ok" and #Ly.Lines > 0) and 1 or 0
    Ly.Btn = Ly.Btn + (target - Ly.Btn) * math.min(1, dt * 12)
    Ly.Scroll, Ly.ScrollV = MotionEngine.Step(Ly.Scroll, Ly.ScrollV, Ly.Target, dt, "SMOOTH")
    local pos = (MediaData.PosSmooth or 0) + 0.25
    local idx = 0
    for i, ln in ipairs(Ly.Lines) do
        if ln.t <= pos then idx = i else break end
    end
    Ly.Idx = idx
    local k = math.min(1, dt * 9)
    for i, ln in ipairs(Ly.Lines) do
        ln.a = ln.a + ((i == idx and 1 or 0) - ln.a) * k
        if ln.gap then
            local nxt = Ly.Lines[i + 1]
            local open = (i == idx and (not nxt or nxt.t - pos > 1.0)) and 1 or 0
            ln.h = ln.h + (open - ln.h) * k
        end
    end
    if not on or not MediaData.HasReceivedData or (MediaData.Title or "") == "" then return end
    local key = (MediaData.Artist or "") .. "\n" .. MediaData.Title
    local now = os.clock()
    if key ~= Ly.Key then
        Ly.Key, Ly.Status, Ly.Lines, Ly.ChangedAt, Ly.Idx, Ly.WrapW = key, "wait", {}, now, 0, 0
        Ly.Scroll, Ly.ScrollV, Ly.Target = 0, 0, 0
        return
    end
    if Ly.Status == "loading" and now - (Ly.LoadAt or now) > 12 then
        Ly.Status = "error"
        Ly.RetryAt = now + 5
    end
    if (Ly.Status == "wait" and now - Ly.ChangedAt > 0.6) or (Ly.Status == "error" and now > Ly.RetryAt) then
        if not Sheet.BridgeOnline() then return end
        Ly.Status = "loading"
        Ly.LoadAt = now
        local q = "artist=" .. Sheet.UrlEncode(MediaData.Artist or "") .. "&title=" .. Sheet.UrlEncode(MediaData.Title) .. "&album=" .. Sheet.UrlEncode(MediaData.Album or "") .. string.format("&dur=%d", math.floor((MediaData.Duration or 0) + 0.5))
        local ok = pcall(Impl.HttpRequest, "GET", "http://127.0.0.1:45455/lyrics?" .. q, {}, function(res) Impl.LyReply(key, res) end, "di_lyrics")
        if not ok then
            Ly.Status = "error"
            Ly.RetryAt = now + 20
        end
    end
end

function Impl.LyCompactOn()
    local Ly = Impl.Ly
    return Impl.LyOn() and UI.Media.LyricsCompact and UI.Media.LyricsCompact:Get() and Ly.Status == "ok" and #Ly.Lines > 0 or false
end

function Impl.LyCompactLine(key, title, x, y, w, font, size, aMul, scale, done)
    if aMul <= 0.01 then return end
    local col = Config.Colors.TextPrimary
    if key == 0 then
        RenderMarqueeText(font, size, title, x, y, w, FadeColor(col, aMul), scale)
        return
    end
    local ln = Impl.Ly.Lines[key]
    if not ln then return end
    local text = ln.x
    if Render.TextSize(font, size, text).x > w then
        RenderMarqueeText(font, size, text, x, y, w, FadeColor(col, aMul), scale, 0.3, true, "ly" .. key)
        return
    end
    Render.Text(font, size, text, Vec2(math.floor(x + 0.5), math.floor(y + 0.5)), FadeColor(col, aMul))
end

function Impl.LyCompactKey()
    local Ly = Impl.Ly
    local ln = Ly.Lines[Ly.Idx]
    if not ln or ln.gap then return 0 end
    return Ly.Idx
end

function Impl.LyCompactDraw(x, y, w, font, size, aMul, scale, title)
    local Ly = Impl.Ly
    local cur = Impl.LyCompactKey()
    local now = os.clock()
    if cur ~= Ly.CCur then
        Ly.CPrev, Ly.CCur, Ly.CAt = Ly.CCur, cur, now
    end
    local t = math.min(1, (now - (Ly.CAt or 0)) / (0.32 * AnimScale()))
    if cur == 0 and (t >= 1 or not Ly.CPrev or Ly.CPrev == 0) then return false end
    local e = EaseOutCubic(t)
    local lift = size * 0.9
    Render.PushClip(Vec2(x - 2, y - 4 * scale), Vec2(x + w + 2, y + size * 1.4 + 4 * scale), true)
    if t < 1 and Ly.CPrev then
        Impl.LyCompactLine(Ly.CPrev, title, x, math.floor(y - e * lift + 0.5), w, font, size, aMul * (1 - e), scale, true)
    end
    Impl.LyCompactLine(cur, title, x, math.floor(y + (1 - e) * lift + 0.5), w, font, size, aMul * (t < 1 and e or 1), scale, false)
    Render.PopClip()
    return true
end

function Impl.LyWrap(font, size, text, maxW)
    local rows, cur = {}, ""
    for word in string.gmatch(text, "%S+") do
        local try = cur == "" and word or (cur .. " " .. word)
        if cur ~= "" and Render.TextSize(font, size, try).x > maxW then
            rows[#rows + 1] = cur
            cur = word
        else
            cur = try
        end
    end
    if cur ~= "" then rows[#rows + 1] = cur end
    return rows
end

function Impl.LyHitAt(cx, cy)
    for _, h in ipairs(Impl.Ly.Hits) do
        if cx >= h.x1 and cx <= h.x2 and cy >= h.y1 and cy <= h.y2 then return h.t end
    end
    return nil
end

function Impl.LyDraw(x, y, w, h, scale, aMul)
    local Ly = Impl.Ly
    local font = Config.Fonts.Lyric or Config.Fonts.Semibold
    local size = 17 * scale
    local rowH = math.floor(Render.TextSize(font, size, "Ag").y + 1 * scale)
    local dotsH = 16 * scale
    local space = 7 * scale
    if Ly.WrapW ~= w or Ly.WrapS ~= size or Ly.WrapF ~= font then
        for _, ln in ipairs(Ly.Lines) do ln.rows = ln.gap and {} or Impl.LyWrap(font, size, ln.x, w) end
        Ly.WrapW, Ly.WrapS, Ly.WrapF = w, size, font
    end
    local tops, acc = {}, 0
    for i, ln in ipairs(Ly.Lines) do
        tops[i] = acc
        if ln.gap then
            acc = acc + (dotsH + space) * ln.h
        else
            acc = acc + #ln.rows * rowH + space
        end
    end
    local inset = math.floor(2 * scale)
    Ly.Target = Ly.Idx > 0 and tops[Ly.Idx] or 0
    Ly.Hits = {}
    local fade = rowH * 0.9
    local now = os.clock()
    Render.PushClip(Vec2(x - 4 * scale, y), Vec2(x + w + 4 * scale, y + h), true)
    for i, ln in ipairs(Ly.Lines) do
        local ty = y + inset + tops[i] - Ly.Scroll
        if ty > y + h then break end
        local lh = ln.gap and dotsH * ln.h or #ln.rows * rowH
        if ty + lh >= y then
            local edge = math.max(0, math.min(1, (ty + lh - y - rowH * 0.3) / fade, (y + h - ty - rowH * 0.3) / fade))
            edge = edge * edge * (3 - 2 * edge)
            local base = i < Ly.Idx and 0.26 or 0.36
            local al = (base + (1 - base) * ln.a) * edge * aMul
            if ln.gap then
                if ln.h > 0.02 then
                    for d = 0, 2 do
                        local ph = 0.5 + 0.5 * math.sin(now * 3.2 - d * 0.7)
                        local r = (2.4 + 0.9 * ph) * scale * ln.h
                        Render.FilledCircle(Vec2(x + (4 + d * 11) * scale, ty + dotsH * ln.h / 2), r, FadeColor(Config.Colors.TextPrimary, al * ln.h * (0.45 + 0.55 * ph)))
                    end
                end
            else
                local col = FadeColor(Config.Colors.TextPrimary, al)
                for r, row in ipairs(ln.rows) do
                    Render.Text(font, size, row, Vec2(x, math.floor(ty + (r - 1) * rowH)), col)
                end
                Ly.Hits[#Ly.Hits + 1] = { x1 = x, y1 = math.max(y, ty), x2 = x + w, y2 = math.min(y + h, ty + lh), t = ln.t }
            end
        end
    end
    Render.PopClip()
end

function Impl.RenderLargeMedia(layout, alphaMul, yOffset)
    local aMul = alphaMul or 1.0
    local yOff = yOffset or 0
    local scale = layout.scale
    local fontBold, titleSz = TF("Title", scale)
    local fontMain, artistSz = TF("Body", scale)
    local fTime, sTime = TF("Footnote", scale)
    local fontTiny, tinySz = TF("Caption2", scale)
    local textCol = FadeColor(Config.Colors.TextPrimary, aMul)
    local subCol = FadeColor(Config.Colors.TextSecondary, aMul)
    local waveCol = MediaTint()

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
    local infoY = math.floor(artY + 4 * scale)
    local maxInfoW = math.max(10, math.floor(waveX - infoX - 8 * scale))

    local titleStr = MediaData.Title ~= "" and MediaData.Title or L("di_ui_track")
    local artistStr = MediaData.Artist ~= "" and MediaData.Artist or ""

    local nowClk = os.clock()
    if TrackTransition.Active then
        local t = math.min(1.0, (nowClk - TrackTransition.StartTime) / (TrackTransition.Duration * AnimScale()))
        local dir = TrackTransition.Direction
        local e = EaseOutCubic(t)
        local outOffset = -dir * (e * 8 * scale)
        local outAlpha = (1.0 - t) * aMul
        local inOffset = dir * ((1.0 - e) * 8 * scale)
        local inAlpha = t * aMul

        if outAlpha > 0.02 and TrackTransition.OldTitle ~= "" then
            Render.Text(fontBold, titleSz, TrackTransition.OldTitle, Vec2(infoX + outOffset, infoY), FadeColor(Config.Colors.TextPrimary, outAlpha))
            Render.Text(fontMain, artistSz, TrackTransition.OldArtist, Vec2(infoX + outOffset, infoY + 22 * scale), FadeColor(Config.Colors.TextSecondary, outAlpha))
            DrawAlbumThumbnail(artX, artY, artSize, math.floor(12 * scale), outAlpha, 1.0 - t * 0.15, TrackTransition.OldCoverHandle, TrackTransition.OldCoverColor)
        end
        if inAlpha > 0.02 then
            Render.Text(fontBold, titleSz, titleStr, Vec2(infoX + inOffset, infoY), FadeColor(Config.Colors.TextPrimary, inAlpha))
            if artistStr ~= "" then Render.Text(fontMain, artistSz, artistStr, Vec2(infoX + inOffset, infoY + 22 * scale), FadeColor(Config.Colors.TextSecondary, inAlpha)) end
            DrawAlbumThumbnail(artX, artY, artSize, math.floor(12 * scale), inAlpha, (0.85 + t * 0.15) * (MediaData.ArtK or 1))
        end
    else
        local titleSize = Render.TextSize(fontBold, titleSz, titleStr)
        if titleSize.x > maxInfoW then
            RenderMarqueeText(fontBold, titleSz, titleStr, infoX, infoY, maxInfoW, textCol, scale)
        else
            Render.Text(fontBold, titleSz, titleStr, Vec2(infoX, infoY), textCol)
        end

        if artistStr ~= "" then
            local artSizeText = Render.TextSize(fontMain, artistSz, artistStr)
            local artYPos = math.floor(infoY + titleSize.y + 2 * scale)
            local artistW = UI.Media.SpotifyLike:Get() and math.max(10, math.floor(layout.x + layout.w - pad - 16 * scale - 10 * scale - infoX - (Impl.Ly.Btn > 0.01 and 28 * scale or 0))) or maxInfoW
            if artSizeText.x > artistW then
                RenderMarqueeText(fontMain, artistSz, artistStr, infoX, artYPos, artistW, subCol, scale)
            else
                Render.Text(fontMain, artistSz, artistStr, Vec2(infoX, artYPos), subCol)
            end
        end

        local ak = MediaData.ArtK or 1
        local sh = math.max(0, math.min(1, (ak - 0.84) / 0.16))
        if sh > 0.02 then
            local isz = artSize * ak
            local ix, iy = artX + (artSize - isz) / 2, artY + (artSize - isz) / 2
            SoftShadow(Vec2(ix, iy), Vec2(ix + isz, iy + isz), 12 * scale * ak, Color(0, 0, 0, math.floor(120 * sh * aMul)), 12, Vec2(0, 3))
        end
        DrawAlbumThumbnail(artX, artY, artSize, math.floor(12 * scale), aMul, ak)
    end

    local progressY = math.floor(artY + artSize + 14 * scale)
    local lyK = math.max(0, math.min(1, (StateMachine.Spring.H.value - Config.Dimensions.LargeMediaH) / Impl.LyH))
    local lyExtra = math.floor(lyK * Impl.LyH * scale)
    if lyExtra > 1 and #Impl.Ly.Lines > 0 then
        Impl.LyDraw(layout.x + pad, math.floor(artY + artSize + 12 * scale), layout.w - pad * 2, math.max(0, lyExtra - 8 * scale), scale, aMul * math.min(1, lyK * 1.3))
    else
        Impl.Ly.Hits = {}
    end
    progressY = progressY + lyExtra
    local progressW = math.floor(layout.w - pad * 2)
    local progressH = math.floor(4.5 * scale)

    local duration = math.max(1, MediaData.Duration)
    local curPos = MediaData.PosSmooth
    local barX1 = layout.x + pad
    local barX2 = layout.x + pad + progressW
    if SeekDrag.Active then
        local mx = Input.GetCursorPos()
        SeekDrag.Frac = math.max(0.0, math.min(1.0, (mx - barX1) / math.max(1, progressW)))
        curPos = SeekDrag.Frac * duration
    end
    local progressPct = math.min(1.0, math.max(0.0, curPos / duration))

    local barH = progressH + 3.5 * scale * SeekDrag.Grow
    local barY = progressY + progressH / 2 - barH / 2
    local barR = barH / 2
    Render.FilledRect(Vec2(barX1, barY), Vec2(barX2, barY + barH), FadeColor(Config.Colors.TrackProgressBg, aMul), barR)
    if progressPct > 0 then
        Render.FilledRect(Vec2(barX1, barY), Vec2(barX1 + progressW * progressPct, barY + barH), FadeColor(Config.Colors.TextPrimary, aMul), barR)
    end
    ButtonHits.MediaSeek = { x1 = barX1, y1 = progressY - 8 * scale, x2 = barX2, y2 = progressY + progressH + 8 * scale }

    local posText = FormatTrackTime(curPos)
    local remSec = math.max(0, duration - curPos)
    local remText = FormatTrackTime(remSec, true)

    local timeY = math.floor(progressY + 8 * scale)
    Odometer.Draw(fTime, sTime, posText, Vec2(layout.x + pad, timeY), subCol)
    local remW = Odometer.Width(fTime, sTime, remText)
    Odometer.Draw(fTime, sTime, remText, Vec2(math.floor(layout.x + layout.w - pad - remW), timeY), subCol)

    local ctrlY = math.floor(timeY + 16 * scale)
    local midX = math.floor(layout.x + layout.w / 2)

    local playX = midX
    local playY = math.floor(ctrlY + 16 * scale)
    local ctrlCol = FadeColor(Config.Colors.TextPrimary, aMul)
    local prevX = math.floor(playX - 54 * scale)
    local nextX = math.floor(playX + 54 * scale)
    local shufX = math.floor(layout.x + pad + 12 * scale)
    local repX = math.floor(layout.x + layout.w - pad - 12 * scale)
    local hb = 20 * scale
    local sb2 = 14 * scale
    ButtonHits.MediaPlay = { x1 = playX - 22 * scale, y1 = playY - 22 * scale, x2 = playX + 22 * scale, y2 = playY + 22 * scale }
    ButtonHits.MediaPrev = { x1 = prevX - hb, y1 = playY - hb, x2 = prevX + hb, y2 = playY + hb }
    ButtonHits.MediaNext = { x1 = nextX - hb, y1 = playY - hb, x2 = nextX + hb, y2 = playY + hb }
    ButtonHits.MediaShuffle = { x1 = shufX - sb2, y1 = playY - sb2, x2 = shufX + sb2, y2 = playY + sb2 }
    ButtonHits.MediaRepeat = { x1 = repX - sb2, y1 = playY - sb2, x2 = repX + sb2, y2 = playY + sb2 }

    local k, d = Impl.PointerBlob("m_play", playX, playY, 22 * scale, ButtonHits.MediaPlay, aMul)
    Glyph(MediaData.IsPlaying and "media_pause" or "media_play", playX, playY, math.floor(26 * scale * ButtonSprings.MediaPlay.scale * k), FadeColor(ctrlCol, d))
    k, d = Impl.PointerBlob("m_prev", prevX, playY, 19 * scale, ButtonHits.MediaPrev, aMul)
    Glyph("media_prev", prevX, playY, math.floor(24 * scale * ButtonSprings.MediaPrev.scale * k), FadeColor(ctrlCol, d))
    k, d = Impl.PointerBlob("m_next", nextX, playY, 19 * scale, ButtonHits.MediaNext, aMul)
    Glyph("media_next", nextX, playY, math.floor(24 * scale * ButtonSprings.MediaNext.scale * k), FadeColor(ctrlCol, d))

    local shufH = GetVectorIcon("shuffle")
    k, d = Impl.PointerBlob("m_shuf", shufX, playY, 15 * scale, ButtonHits.MediaShuffle, aMul)
    if shufH then
        local shufCol = MediaData.Shuffle and Config.Colors.TextPrimary or Config.Colors.TextSecondary
        local sSz = 14 * scale * ButtonSprings.MediaShuffle.scale * k
        Impl.Img(shufH, Vec2(shufX - sSz / 2, playY - sSz / 2), Vec2(sSz, sSz), FadeColor(shufCol, aMul * d), 0)
    end

    local repH = GetVectorIcon("repeat")
    k, d = Impl.PointerBlob("m_rep", repX, playY, 15 * scale, ButtonHits.MediaRepeat, aMul)
    if repH then
        local repCol = (MediaData.RepeatMode > 0) and Config.Colors.TextPrimary or Config.Colors.TextSecondary
        local rSz = 14 * scale * ButtonSprings.MediaRepeat.scale * k
        Impl.Img(repH, Vec2(repX - rSz / 2, playY - rSz / 2), Vec2(rSz, rSz), FadeColor(repCol, aMul * d), 0)
        if MediaData.RepeatMode == 2 then
            Render.Text(fontTiny, tinySz, "1", Vec2(repX + 5 * scale, playY - 8 * scale), FadeColor(Config.Colors.TextPrimary, aMul * d))
        end
    end

    local playlistActive = UI.Media.Playlist:Get() and string.find(string.lower(MediaData.App or ""), "yandex", 1, true) ~= nil
        and string.find(string.lower(MediaData.App or ""), "music", 1, true) ~= nil
    local playlistX = math.floor(layout.x + layout.w - pad - 8 * scale - (UI.Media.SpotifyLike:Get() and 28 * scale or 0))
    local playlistY = math.floor(artY + artSize - 10 * scale)
    if playlistActive then
        ButtonHits.MediaPlaylist = { x1 = playlistX - 14 * scale, y1 = playlistY - 14 * scale, x2 = playlistX + 14 * scale, y2 = playlistY + 14 * scale }
        local pk, pd = Impl.PointerBlob("m_playlist", playlistX, playlistY, 14 * scale, ButtonHits.MediaPlaylist, aMul)
        local plusH = GetVectorIcon("plus")
        if plusH then
            local sz = 16 * scale * ButtonSprings.MediaPlaylist.scale * pk
            Impl.Img(plusH, Vec2(playlistX - sz / 2, playlistY - sz / 2), Vec2(sz, sz), FadeColor(Config.Colors.TextSecondary, aMul * pd), 0)
        end
    else
        ButtonHits.MediaPlaylist = nil
    end

    local lyB = Impl.Ly.Btn
    if lyB > 0.01 then
        local lyX = math.floor(layout.x + layout.w - pad - 8 * scale - (UI.Media.SpotifyLike:Get() and 28 * scale or 0) - (playlistActive and 28 * scale or 0))
        local lyY = math.floor(artY + artSize - 10 * scale)
        ButtonHits.MediaLyrics = { x1 = lyX - 14 * scale, y1 = lyY - 14 * scale, x2 = lyX + 14 * scale, y2 = lyY + 14 * scale }
        local lk, ld = Impl.PointerBlob("m_lyr", lyX, lyY, 14 * scale, ButtonHits.MediaLyrics, aMul)
        local icon = GetVectorIcon("lyrics")
        if icon then
            local sz = 16 * scale * lk * ButtonSprings.MediaLyrics.scale
            local col = Impl.Ly.Open and Config.Colors.TextPrimary or Config.Colors.TextSecondary
            Impl.Img(icon, Vec2(lyX - sz / 2, lyY - sz / 2), Vec2(sz, sz), FadeColor(col, aMul * ld * lyB), 0)
        end
    else
        ButtonHits.MediaLyrics = nil
    end

    if UI.Media.SpotifyLike:Get() then
        local likeScale = ButtonSprings.MediaLike.scale
        local isLiked = (MediaData.IsLiked == true)
        local likeX = math.floor(layout.x + layout.w - pad - 8 * scale)
        local likeY = math.floor(artY + artSize - 10 * scale)
        local heartH = GetVectorIcon(isLiked and "heart_fill" or "heart_outline")
        ButtonHits.MediaLike = {
            x1 = likeX - 14 * scale,
            y1 = likeY - 14 * scale,
            x2 = likeX + 14 * scale,
            y2 = likeY + 14 * scale
        }
        local lk, ld = Impl.PointerBlob("m_like", likeX, likeY, 14 * scale, ButtonHits.MediaLike, aMul)
        if heartH then
            local heartCol = isLiked and Config.Colors.Red or Config.Colors.TextSecondary
            local lSz = 16 * scale * likeScale * lk
            Impl.Img(heartH, Vec2(likeX - lSz / 2, likeY - lSz / 2), Vec2(lSz, lSz), FadeColor(heartCol, aMul * ld), 0)
        end
    else
        ButtonHits.MediaLike = nil
    end
end

local function IdleGeo(layout, yOff)
    local scale = layout.scale
    local oy = yOff or 0
    local g = {}
    g.pad = math.floor(16 * scale)
    g.leftX = math.floor(layout.x + g.pad)
    local fN, sN = TF("LargeNum", scale)
    local fF, sF = TF("Footnote", scale)
    local block = Render.TextSize(fN, sN, "0").y + 2 * scale + Render.TextSize(fF, sF, "Ag").y
    g.leftY = math.floor(layout.y + (Config.Dimensions.LargeH * scale - block) / 2 + oy)
    g.divX = math.floor(layout.x + 140 * scale)
    g.rightX = math.floor(g.divX + 14 * scale)
    g.col2X = math.floor(g.rightX + 92 * scale)
    g.row1Y = math.floor(layout.y + 16 * scale + oy)
    g.row2Y = math.floor(layout.y + 42 * scale + oy)
    g.icon = math.floor(13 * scale)
    g.textDX = math.floor(18 * scale)
    return g
end

local function RenderLargeIdle(layout, alphaMul, yOffset)
    local aMul = alphaMul or 1.0
    local yOff = yOffset or 0
    local scale = layout.scale
    local g = IdleGeo(layout, yOff)
    local fNum, sNum = TF("LargeNum", scale)
    local fSec, sSec = TF("Subhead", scale)
    local fFoot, sFoot = TF("Footnote", scale)
    local fHead, sHead = TF("Headline", scale)
    local textCol = FadeColor(Config.Colors.TextPrimary, aMul)
    local subCol = FadeColor(Config.Colors.TextSecondary, aMul)

    local clockCfg = HUDCustomizer.WidgetConfigs.clock
    local clockFormat = clockCfg and clockCfg.format or 1
    local timeHM = os.date(clockFormat == 2 and "%I:%M" or "%H:%M")
    local timeSec = os.date(":%S")
    local hmH = Render.TextSize(fNum, sNum, "0").y
    local hmW = Odometer.Width(fNum, sNum, timeHM)
    Odometer.Text("large_hm", fNum, sNum, timeHM, Vec2(g.leftX, g.leftY), textCol)
    local secH = Render.TextSize(fSec, sSec, "0").y
    if clockFormat ~= 2 then
        Odometer.Text("large_sec", fSec, sSec, timeSec, Vec2(math.floor(g.leftX + hmW + 2 * scale), math.floor(g.leftY + (hmH - secH) * 0.8)), subCol)
    end

    local matchTime = GetActualMatchTime()
    local subInfo = (matchTime and matchTime > 0) and (L("di_ui_match") .. FormatTime(matchTime)) or L("di_ui_main_menu")
    Odometer.Draw(fFoot, sFoot, subInfo, Vec2(g.leftX, math.floor(g.leftY + hmH + 2 * scale)), subCol)

    Render.Line(Vec2(g.divX, layout.y + 14 * scale + yOff), Vec2(g.divX, layout.y + layout.h - 14 * scale + yOff), FadeColor(Config.Colors.Separator, aMul), 1.0)

    local function Row(id, svg, txt, x, y, f, s, col, soft)
        local h = GetVectorIcon(svg)
        if h then Impl.Img(h, Vec2(x, y), Vec2(g.icon, g.icon), subCol, 0) end
        local th = Render.TextSize(f, s, "0").y
        Odometer.Text(id, f, s, txt, Vec2(x + g.textDX, math.floor(y + g.icon / 2 - th / 2)), col, soft)
    end
    Row("large_kda", "kda", string.format("%d/%d/%d", HeroData.Kills, HeroData.Deaths, HeroData.Assists), g.rightX, g.row1Y, fHead, sHead, textCol)
    Row("large_gold", "gold", Odometer.Group(HeroData.Gold), g.col2X, g.row1Y, fHead, sHead, textCol)
    Row("large_fps", "fps", string.format("%d FPS", PerformanceData.FPS), g.rightX, g.row2Y, fSec, sSec, FadeColor(PerfTint("fps", Config.Colors.TextSecondary), aMul), true)
    Row("large_ping", "ping", string.format("%d ms", PerformanceData.Ping), g.col2X, g.row2Y, fSec, sSec, FadeColor(PerfTint("ping", Config.Colors.TextSecondary), aMul), true)

    Focus.RenderTile(layout, g.rightX, math.floor(layout.x + layout.w - 14 * scale), math.floor(layout.y + layout.h - 12 * scale - 26 * scale + yOff), aMul)
end

function Impl.RenderGamePausedPill(layout, alphaMul, yOffset)
    local scale = layout.scale
    local yOff = (yOffset or 0) * scale
    local centerY = math.floor(layout.y + layout.h / 2 + yOff)
    local fB, sB = TF("Body", scale)
    local fH, sH = TF("Headline", scale)
    local elapsed = PauseTracker.PauseStartTime > 0 and math.floor(os.clock() - PauseTracker.PauseStartTime) or 0
    local pText = L("di_island_paused")
    local timeText = string.format("%d:%02d", math.floor(elapsed / 60), elapsed % 60)
    local dotStr = " \u{2022} "

    local badgeSize = math.floor(16 * scale)
    local badgeX = math.floor(layout.x + 12 * scale)
    local badgeY = math.floor(centerY - badgeSize / 2)

    local pauseSvg = GetVectorIcon("pause")
    if pauseSvg then
        Impl.Img(pauseSvg, Vec2(badgeX, badgeY), Vec2(badgeSize, badgeSize), FadeColor(Config.Colors.Orange, alphaMul), 0)
    end

    local w1 = Render.TextSize(fB, sB, pText).x
    local wDot = Render.TextSize(fB, sB, dotStr).x
    local hB = Render.TextSize(fB, sB, "Ag").y
    local hH = Render.TextSize(fH, sH, "Ag").y

    local textStartX = math.floor(badgeX + badgeSize + 8 * scale)
    local textY1 = math.floor(centerY - hB / 2)
    local textY2 = math.floor(centerY - hH / 2)

    Render.Text(fB, sB, pText, Vec2(textStartX, textY1), FadeColor(Config.Colors.TextSecondary, alphaMul))
    Render.Text(fB, sB, dotStr, Vec2(textStartX + w1, textY1), FadeColor(Config.Colors.TextMuted, alphaMul))
    Odometer.Text("pause_time", fH, sH, timeText, Vec2(textStartX + w1 + wDot, textY2), FadeColor(Config.Colors.TextPrimary, alphaMul))
end

function Impl.RenderCourierDeliveryPill(layout, alphaMul, yOffset)
    local scale = layout.scale
    local yOff = (yOffset or 0) * scale
    local centerY = math.floor(layout.y + layout.h / 2 + yOff)
    local fH, sH = TF("Headline", scale)

    local courierSvg = GetVectorIcon("courier")
    local iconSize = math.floor(16 * scale)
    local leftX = math.floor(layout.x + 12 * scale)
    if courierSvg then
        Impl.Img(courierSvg, Vec2(leftX, centerY - math.floor(iconSize / 2)), Vec2(iconSize, iconSize), FadeColor(Config.Colors.Yellow, alphaMul), 0)
    end

    local etaStr = (CourierTracker.ETA > 0) and (L("di_courier_eta") .. " " .. FormatTime(CourierTracker.ETA)) or L("di_ui_courier_delivering_short")
    local etaW = Odometer.Width(fH, sH, etaStr)
    local etaH = Render.TextSize(fH, sH, "Ag").y
    local rightX = math.floor(layout.x + layout.w - 14 * scale - etaW)
    Odometer.Text("courier_eta", fH, sH, etaStr, Vec2(rightX, math.floor(centerY - etaH / 2)), FadeColor(Config.Colors.TextPrimary, alphaMul))

    local trackStartX = math.floor(leftX + iconSize + 10 * scale)
    local trackEndX = math.floor(rightX - 10 * scale)
    local trackW = trackEndX - trackStartX
    if trackW > 20 * scale then
        local trackH = math.max(3, math.floor(4 * scale))
        local trackY = math.floor(centerY - trackH / 2)
        local trackR = math.floor(trackH / 2)
        Render.FilledRect(Vec2(trackStartX, trackY), Vec2(trackEndX, trackY + trackH), FadeColor(Config.Colors.Fill, alphaMul), trackR)

        local fillW = math.floor(trackW * math.max(0, math.min(1.0, CourierTracker.Progress)))
        if fillW > 0 then
            Render.FilledRect(Vec2(trackStartX, trackY), Vec2(trackStartX + fillW, trackY + trackH), FadeColor(Config.Colors.Green, alphaMul), trackR)
        end
    end
end

function Impl.RenderCourierDeliveredPill(layout, alphaMul, yOffset)
    local scale = layout.scale
    local yOff = (yOffset or 0) * scale
    local centerY = math.floor(layout.y + layout.h / 2 + yOff)
    local fH, sH = TF("Headline", scale)

    local nowClk = os.clock()
    local elapsed = math.max(0, nowClk - CourierTracker.DeliveredStartTime)
    if CourierTracker.FaceFor == CourierTracker.DeliveredStartTime then elapsed = 99 end
    local iconSize = math.floor(18 * scale)
    local delivText = L("di_courier_delivered")
    local tSize = Render.TextSize(fH, sH, delivText)
    local gap = 8 * scale
    local totalW = iconSize + gap + tSize.x
    local startX = math.floor(layout.x + (layout.w - totalW) / 2)

    Success.Draw("courier" .. CourierTracker.DeliveredStartTime, Vec2(startX + iconSize / 2, centerY), iconSize / 2, elapsed, alphaMul, scale)
    Render.Text(fH, sH, delivText, Vec2(math.floor(startX + iconSize + gap), math.floor(centerY - tSize.y / 2)), FadeColor(Config.Colors.TextPrimary, alphaMul))
end

function Impl.RenderCourierLarge(layout, alphaMul, yOffset)
    local scale = layout.scale
    local yOff = (yOffset or 0) * scale
    local fH, sH = TF("Headline", scale)
    local fF, sF = TF("Footnote", scale)

    local leftX = math.floor(layout.x + 18 * scale)
    local row1Y = math.floor(layout.y + 14 * scale + yOff)
    local iconSz = math.floor(16 * scale)

    local courierSvg = GetVectorIcon("courier")
    if courierSvg then
        Impl.Img(courierSvg, Vec2(leftX, row1Y), Vec2(iconSz, iconSz), FadeColor(Config.Colors.Yellow, alphaMul), 0)
    end
    local titleTxt = L("di_courier_delivering")
    local hH = Render.TextSize(fH, sH, "Ag").y
    Render.Text(fH, sH, titleTxt, Vec2(leftX + 22 * scale, math.floor(row1Y + iconSz / 2 - hH / 2)), FadeColor(Config.Colors.TextPrimary, alphaMul))

    local infoTxt = string.format("%s %d  \u{2022}  %s %d%%", L("di_courier_speed"), math.floor(CourierTracker.Speed), L("di_courier_hp"), math.floor(CourierTracker.HpPercent * 100))
    local infoW = Odometer.Width(fF, sF, infoTxt)
    local fH2 = Render.TextSize(fF, sF, "Ag").y
    local rightX = math.floor(layout.x + layout.w - 18 * scale - infoW)
    Odometer.Draw(fF, sF, infoTxt, Vec2(rightX, math.floor(row1Y + iconSz / 2 - fH2 / 2)), FadeColor(Config.Colors.TextSecondary, alphaMul))

    local trackStartX = math.floor(layout.x + 18 * scale)
    local trackEndX = math.floor(layout.x + layout.w - 18 * scale)
    local trackW = trackEndX - trackStartX
    local trackY = math.floor(layout.y + 40 * scale + yOff)
    local trackH = math.max(3, math.floor(4 * scale))
    Render.FilledRect(Vec2(trackStartX, trackY), Vec2(trackEndX, trackY + trackH), FadeColor(Config.Colors.Fill, alphaMul), math.floor(trackH / 2))
    local fillW = math.floor(trackW * math.max(0, math.min(1.0, CourierTracker.Progress)))
    if fillW > 0 then
        Render.FilledRect(Vec2(trackStartX, trackY), Vec2(trackStartX + fillW, trackY + trackH), FadeColor(Config.Colors.Green, alphaMul), math.floor(trackH / 2))
    end

    local slotW = math.floor(40 * scale)
    local slotH = math.floor(28 * scale)
    local slotGap = math.floor(8 * scale)
    local totalSlotsW = 6 * slotW + 5 * slotGap
    local slotsStartX = math.floor(layout.x + (layout.w - totalSlotsW) / 2)
    local slotsY = math.floor(layout.y + 56 * scale + yOff)

    for i = 1, 6 do
        local sx = math.floor(slotsStartX + (i - 1) * (slotW + slotGap))
        local sy = slotsY
        local it = CourierTracker.Inventory[i]
        if it and it.icon then
            Render.FilledRect(Vec2(sx, sy), Vec2(sx + slotW, sy + slotH), FadeColor(Config.Colors.FillTertiary, alphaMul), 6 * scale)
            local itHandle = GetCachedImage(it.icon)
            if itHandle and itHandle > 0 then
                Impl.Img(itHandle, Vec2(sx + 2 * scale, sy + 2 * scale), Vec2(slotW - 4 * scale, slotH - 4 * scale), FadeColor(Color(255, 255, 255, 255), alphaMul), 4 * scale)
            end
        else
            Render.FilledRect(Vec2(sx, sy), Vec2(sx + slotW, sy + slotH), FadeColor(Config.Colors.FillQuaternary, alphaMul), 6 * scale)
        end
    end
end

function Impl.RenderVolumeOverlay(layout, alphaMul)
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

    local ibg = UI.Main.IslandBgColor:Get()
    local hudBg = IsPureGlass() and Color(0, 0, 0, 235) or Color(ibg.r, ibg.g, ibg.b, 255)
    Render.FilledRect(Vec2(hudX, hudY), Vec2(hudX + hudW, hudY + hudH), FadeColor(hudBg, aMul), hudR)
    Render.Rect(Vec2(hudX, hudY), Vec2(hudX + hudW, hudY + hudH), FadeColor(Config.Colors.Border, aMul), hudR, Enum.DrawFlags.None, 1.0)

    local centerY = math.floor(hudY + hudH * 0.5)
    local leftPad = math.floor(12 * scale)
    local rightPad = math.floor(14 * scale)

    local vol = VolumeState.Current
    local iconSize = math.floor(15 * scale)
    local iconX = hudX + leftPad
    local iconY = centerY - math.floor(iconSize * 0.5)

    local volSvg = (vol <= 0.5) and GetVectorIcon("mute") or GetVectorIcon("volume")
    if volSvg then
        Impl.Img(volSvg, Vec2(iconX, iconY), Vec2(iconSize, iconSize), FadeColor(Config.Colors.TextPrimary, aMul), 0)
    end

    local trackStartX = math.floor(iconX + iconSize + 10 * scale)
    local trackEndX = math.floor(hudX + hudW - rightPad)
    local trackW = trackEndX - trackStartX
    if trackW > 20 * scale then
        local trackH = math.floor(math.max(6, 7.5 * scale))
        local trackY = math.floor(centerY - trackH * 0.5)
        local trackR = math.floor(trackH * 0.5)

        Render.FilledRect(Vec2(trackStartX, trackY), Vec2(trackEndX, trackY + trackH), FadeColor(Config.Colors.Fill, aMul), trackR)

        local overstretch = VolumeState.Overstretch or 0.0
        local pct = math.max(0.0, math.min(1.0, vol / 100.0))
        local fillW = math.floor(trackW * pct + overstretch * scale + 0.5)
        fillW = math.max(0, math.min(trackW + math.floor(6 * scale), fillW))

        if fillW > 0 then
            local fillEnd = math.min(trackEndX + math.floor(math.max(0, overstretch * scale)), trackStartX + fillW)
            Render.FilledRect(Vec2(trackStartX, trackY), Vec2(fillEnd, trackY + trackH), FadeColor(Config.Colors.TextPrimary, aMul), trackR)
        end
    end
end

function Impl.RenderMediaSharedTransition(fromState, toState, layout, progress)
    local scale = layout.scale
    local fontBold, titleSz = TF("Title", scale)
    local fontMain, artistSz = TF("Body", scale)
    local fontHead, headSz = TF("Headline", scale)
    local fTime, sTime = TF("Footnote", scale)
    local fontTiny, tinySz = TF("Caption2", scale)
    local waveCol = MediaTint()

    local artT = math.max(0.0, math.min(1.0, progress or 0.0))
    local D = Config.Dimensions
    local cL = StateMachine.FrameFor(layout, CompactMediaTitle() and D.CompactMediaW or D.CompactMediaBareW, D.CompactMediaH, D.CompactMediaRadius)
    local lyOpen = Impl.LyWant() and Impl.LyH or 0
    local lL = StateMachine.FrameFor(layout, D.LargeMediaW, D.LargeMediaH + lyOpen, D.LargeMediaRadius)
    local secAlpha = artT * artT

    local cThumbSize = math.floor(20 * scale)
    local cThumbX = math.floor(cL.x + (Config.Dimensions.CompactMediaH * scale - cThumbSize) * 0.5)
    local cThumbY = math.floor(cL.y + (cL.h - cThumbSize) * 0.5)
    local cThumbR = math.floor(5 * scale)

    local pad = math.floor(16 * scale)
    local lThumbSize = math.floor(48 * scale)
    local lThumbX = math.floor(lL.x + pad)
    local lThumbY = math.floor(lL.y + pad)
    local lThumbR = math.floor(12 * scale)

    local curThumbX = math.floor(cThumbX + (lThumbX - cThumbX) * artT + 0.5)
    local curThumbY = math.floor(cThumbY + (lThumbY - cThumbY) * artT + 0.5)
    local curThumbSize = math.floor(cThumbSize + (lThumbSize - cThumbSize) * artT + 0.5)
    local curThumbR = math.floor(cThumbR + (lThumbR - cThumbR) * artT + 0.5)

    DrawAlbumThumbnail(curThumbX, curThumbY, curThumbSize, curThumbR, 1.0)

    local waveCount = 5
    local waveW = math.floor(waveCount * (2.4 * scale) + (waveCount - 1) * (1.8 * scale))
    local cWaveX = math.floor(cL.x + cL.w - waveW - 10 * scale)
    local cWaveY = math.floor(cL.y + (cL.h - 18 * scale) * 0.5)

    local lWaveX = math.floor(lL.x + lL.w - pad - waveW)
    local lWaveY = math.floor(lThumbY + 4 * scale)

    local curWaveX = math.floor(cWaveX + (lWaveX - cWaveX) * artT + 0.5)
    local curWaveY = math.floor(cWaveY + (lWaveY - cWaveY) * artT + 0.5)

    DrawAppleWaveform(curWaveX, curWaveY, 18 + 2 * artT, waveCount, MediaData.IsPlaying, scale, waveCol, 1.0)

    local titleStr = MediaData.Title ~= "" and MediaData.Title or L("di_ui_music")
    local artistStr = MediaData.Artist ~= "" and MediaData.Artist or ""

    local curInfoX = math.floor(curThumbX + curThumbSize + math.floor((8 + 5 * artT) * scale))
    local cTextStartX = curInfoX
    local cTextY = math.floor(cL.y + (Config.Dimensions.CompactMediaH * scale - Render.TextSize(fontHead, headSz, "Ag").y) * 0.5)
    local cTextAvailW = math.max(10, math.floor((curWaveX - 4 * scale) - cTextStartX))

    local lInfoX = curInfoX
    local lInfoY = math.floor(curThumbY + 4 * scale)
    local lMaxInfoW = math.max(10, math.floor(curWaveX - lInfoX - 8 * scale))

    local compactAlpha = math.max(0.0, 1.0 - artT * 2.5)
    if compactAlpha > 0.01 and CompactMediaTitle() then
        local compStr = (UI.Media.ShowArtist:Get() and artistStr ~= "" and titleStr ~= "") and (titleStr .. " \u{2022} " .. artistStr) or titleStr
        if not (Impl.LyCompactOn() and Impl.LyCompactDraw(cTextStartX, cTextY, cTextAvailW, fontHead, headSz, compactAlpha, scale, compStr)) then
            RenderMarqueeText(fontHead, headSz, compStr, Impl.CompactTitleX(cL, cTextStartX, cTextAvailW, fontHead, headSz, compStr), cTextY, cTextAvailW, FadeColor(Config.Colors.TextPrimary, compactAlpha), scale)
        end
    end

    local largeAlpha = math.max(0.0, (artT - 0.25) / 0.75)^1.5
    if largeAlpha > 0.01 then
        local slideY = math.floor((1.0 - (artT - 0.25) / 0.75) * 5 * scale)
        local curLY = lInfoY + slideY
        local lTitleSize = Render.TextSize(fontBold, titleSz, titleStr)
        RenderMarqueeText(fontBold, titleSz, titleStr, lInfoX, curLY, lMaxInfoW, FadeColor(Config.Colors.TextPrimary, largeAlpha), scale)
        if artistStr ~= "" then
            local artY = curLY + lTitleSize.y + 2 * scale
            local artistW = UI.Media.SpotifyLike:Get() and math.max(10, math.floor(lL.x + lL.w - pad - 16 * scale - 10 * scale - lInfoX)) or lMaxInfoW
            RenderMarqueeText(fontMain, artistSz, artistStr, lInfoX, artY, artistW, FadeColor(Config.Colors.TextSecondary, largeAlpha), scale)
        end
    end

    if lyOpen > 0 and #Impl.Ly.Lines > 0 and artT > 0.5 then
        local slide = math.floor((1.0 - artT) * 10 * scale)
        local lyA = math.max(0, math.min(1, (artT - 0.5) / 0.5))
        Impl.LyDraw(lL.x + pad, math.floor(lThumbY + lThumbSize + 12 * scale) + slide, lL.w - pad * 2, math.floor(lyOpen * scale - 8 * scale), scale, lyA * lyA)
    end

    if secAlpha > 0.01 then
        local progressY = math.floor(lThumbY + lThumbSize + 14 * scale + lyOpen * scale)
        local progressW = math.floor(lL.w - pad * 2)
        local progressH = math.floor(4.5 * scale)

        local curPos = MediaData.PosSmooth
        local duration = math.max(1, MediaData.Duration)
        local progressPct = math.min(1.0, math.max(0.0, curPos / duration))

        Render.FilledRect(Vec2(lL.x + pad, progressY), Vec2(lL.x + pad + progressW, progressY + progressH), FadeColor(Config.Colors.TrackProgressBg, secAlpha), 2.5 * scale)
        if progressPct > 0 then
            Render.FilledRect(Vec2(lL.x + pad, progressY), Vec2(lL.x + pad + progressW * progressPct, progressY + progressH), FadeColor(Config.Colors.TextPrimary, secAlpha), 2.5 * scale)
        end

        local posText = FormatTrackTime(curPos)
        local remSec = math.max(0, duration - curPos)
        local remText = FormatTrackTime(remSec, true)
        local timeY = math.floor(progressY + 8 * scale)
        Odometer.Draw(fTime, sTime, posText, Vec2(lL.x + pad, timeY), FadeColor(Config.Colors.TextSecondary, secAlpha))
        local remW = Odometer.Width(fTime, sTime, remText)
        Odometer.Draw(fTime, sTime, remText, Vec2(math.floor(lL.x + lL.w - pad - remW), timeY), FadeColor(Config.Colors.TextSecondary, secAlpha))

        local ctrlY = math.floor(timeY + 16 * scale)
        local midX = math.floor(lL.x + lL.w / 2)
        local playY = math.floor(ctrlY + 16 * scale)

        local bloomT = artT * artT * (3.0 - 2.0 * artT)
        local elemScale = 0.80 + 0.20 * bloomT

        local playScale = ButtonSprings.MediaPlay.scale * elemScale
        local playX = midX
        local ctrlCol = FadeColor(Config.Colors.TextPrimary, secAlpha)
        Glyph(MediaData.IsPlaying and "media_pause" or "media_play", playX, playY, math.floor(26 * scale * playScale), ctrlCol)

        local prevTargetX = math.floor(playX - 54 * scale)
        local curPrevX = math.floor(midX + (prevTargetX - midX) * bloomT)
        Glyph("media_prev", curPrevX, playY, math.floor(24 * scale * ButtonSprings.MediaPrev.scale * elemScale), ctrlCol)

        local nextTargetX = math.floor(playX + 54 * scale)
        local curNextX = math.floor(midX + (nextTargetX - midX) * bloomT)
        Glyph("media_next", curNextX, playY, math.floor(24 * scale * ButtonSprings.MediaNext.scale * elemScale), ctrlCol)

        local shufTargetX = math.floor(lL.x + pad + 12 * scale)
        local shufScale = ButtonSprings.MediaShuffle.scale * elemScale
        local curShufX = math.floor(midX + (shufTargetX - midX) * bloomT)
        local shufH = GetVectorIcon("shuffle")
        if shufH then
            local shufCol = MediaData.Shuffle and Config.Colors.TextPrimary or Config.Colors.TextSecondary
            local sSz = 14 * scale * shufScale
            Impl.Img(shufH, Vec2(curShufX - sSz / 2, playY - sSz / 2), Vec2(sSz, sSz), FadeColor(shufCol, secAlpha), 0)
        end

        local repTargetX = math.floor(lL.x + lL.w - pad - 12 * scale)
        local repScale = ButtonSprings.MediaRepeat.scale * elemScale
        local curRepX = math.floor(midX + (repTargetX - midX) * bloomT)
        local repH = GetVectorIcon("repeat")
        if repH then
            local repCol = (MediaData.RepeatMode > 0) and Config.Colors.TextPrimary or Config.Colors.TextSecondary
            local rSz = 14 * scale * repScale
            Impl.Img(repH, Vec2(curRepX - rSz / 2, playY - rSz / 2), Vec2(rSz, rSz), FadeColor(repCol, secAlpha), 0)
            if MediaData.RepeatMode == 2 then
                Render.Text(fontTiny, tinySz * elemScale, "1", Vec2(curRepX + 5 * scale, playY - 8 * scale), FadeColor(Config.Colors.TextPrimary, secAlpha))
            end
        end

        local likeTargetX = math.floor(lL.x + lL.w - pad - 8 * scale)
        local likeY = math.floor(curThumbY + curThumbSize - 10 * scale)
        local playlistActive = UI.Media.Playlist:Get() and string.find(string.lower(MediaData.App or ""), "yandex", 1, true) ~= nil
            and string.find(string.lower(MediaData.App or ""), "music", 1, true) ~= nil
        if playlistActive then
            local icon = GetVectorIcon("plus")
            if icon then
                local px = likeTargetX - (UI.Media.SpotifyLike:Get() and 28 * scale or 0)
                local sz = 16 * scale * ButtonSprings.MediaPlaylist.scale * elemScale
                Impl.Img(icon, Vec2(px - sz / 2, likeY - sz / 2), Vec2(sz, sz), FadeColor(Config.Colors.TextSecondary, secAlpha), 0)
            end
        end
        local lyB = Impl.Ly.Btn
        if lyB > 0.01 then
            local icon = GetVectorIcon("lyrics")
            if icon then
                local lyX = math.floor(likeTargetX - (UI.Media.SpotifyLike:Get() and 28 * scale or 0) - (playlistActive and 28 * scale or 0))
                local sz = 16 * scale * elemScale
                local col = Impl.Ly.Open and Config.Colors.TextPrimary or Config.Colors.TextSecondary
                Impl.Img(icon, Vec2(lyX - sz / 2, likeY - sz / 2), Vec2(sz, sz), FadeColor(col, secAlpha * lyB), 0)
            end
        end
        local likeScale = ButtonSprings.MediaLike.scale * elemScale
        local curLikeX = likeTargetX
        local isLiked = (MediaData.IsLiked == true)
        local likeSvg = GetVectorIcon(isLiked and "heart_fill" or "heart_outline")
        if likeSvg and UI.Media.SpotifyLike:Get() then
            local lSz = 16 * scale * likeScale
            local lCol = isLiked and Config.Colors.Red or Config.Colors.TextSecondary
            Impl.Img(likeSvg, Vec2(curLikeX - lSz / 2, likeY - lSz / 2), Vec2(lSz, lSz), FadeColor(lCol, secAlpha), 0)
        end
    end
end

function Impl.RenderIdleSharedTransition(fromState, toState, layout, progress)
    local scale = layout.scale
    local elemT = math.max(0.0, math.min(1.0, progress or 0.0))
    local D = Config.Dimensions
    local cL = StateMachine.FrameFor(layout, math.max(80, CalculateIdleContentWidth(scale) / scale + 26), D.CompactH, D.CompactRadius)
    local lL = StateMachine.FrameFor(layout, D.LargeW, D.LargeH, D.LargeRadius)
    local g = IdleGeo(lL, 0)
    local _, sChip = TF("Headline", scale)
    local fNum, sNum = TF("LargeNum", scale)
    local fSec, sSec = TF("Subhead", scale)
    local fFoot, sFoot = TF("Footnote", scale)
    local fHead, sHead = TF("Headline", scale)
    local function Q(v) return math.floor(v * 2 + 0.5) / 2 end

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

    local compactStartX = math.floor(cL.x + (cL.w - totalCompactW) / 2)
    local midY = math.floor(cL.y + cL.h / 2)

    for _, chip in ipairs(renderedChips) do
        compactMap[chip.id] = { startX = compactStartX + chip.offset, chip = chip }
    end

    local clockChip = compactMap["clock"]
    local cFont = clockChip and clockChip.chip.font or fHead
    local cClockX = clockChip and (clockChip.startX + (clockChip.chip.svgKey and (20 * scale) or 0)) or math.floor(cL.x + cL.w * 0.5 - 20 * scale)
    local cClockY = math.floor(midY - Render.TextSize(cFont, sChip, "0").y / 2 + MenuTextOffsetY * scale)
    local curClockX = math.floor(cClockX + (g.leftX - cClockX) * elemT + 0.5)
    local curClockY = math.floor(cClockY + (g.leftY - cClockY) * elemT + 0.5)
    local curSize = Q(sChip + (sNum - sChip) * elemT)
    local fontMix = math.max(0, math.min(1, (elemT - 0.25) / 0.5))
    local curFont = fontMix > 0.5 and fNum or cFont
    local clockCfg = HUDCustomizer.WidgetConfigs.clock
    local clockFormat = clockCfg and clockCfg.format or 1
    local timeHM = os.date(clockFormat == 2 and "%I:%M" or "%H:%M")
    local clockCol = clockChip and LerpColor(clockChip.chip.color, Config.Colors.TextPrimary, elemT) or Config.Colors.TextPrimary
    if fontMix < 1 then
        local txt = clockChip and clockChip.chip.text or timeHM
        Odometer.Draw(cFont, curSize, txt, Vec2(curClockX, curClockY), FadeColor(clockCol, 1 - fontMix))
    end
    if fontMix > 0 then
        Odometer.Draw(fNum, curSize, timeHM, Vec2(curClockX, curClockY), FadeColor(clockCol, fontMix))
    end
    if clockChip and clockChip.chip.svgKey then
        local ca = math.max(0, 1 - elemT * 2.5)
        local iconHandle = GetVectorIcon("clock")
        if iconHandle and ca > 0.01 then
            local iconSz = math.floor(14 * scale)
            Impl.Img(iconHandle, Vec2(math.floor(clockChip.startX + (curClockX - cClockX)), math.floor(midY - iconSz / 2 + MenuIconOffsetY * scale + (curClockY - cClockY))), Vec2(iconSz, iconSz), FadeColor(clockChip.chip.color, ca), 0)
        end
    end

    local compactAlpha = math.max(0.0, 1.0 - elemT * 1.5)
    if compactAlpha > 0.01 then
        local curX = compactStartX
        for idx, chip in ipairs(renderedChips) do
            if chip.id ~= "clock" and chip.id ~= "fps" and chip.id ~= "ping" and chip.id ~= "gold" and chip.id ~= "kda" then
                local refSize = Render.TextSize(chip.font, sChip, "0123456789")
                local ty = math.floor(midY - refSize.y / 2 + MenuTextOffsetY * scale)
                local tx = curX
                if chip.svgKey then
                    local iconHandle = GetVectorIcon(chip.svgKey)
                    local iconSz = math.floor(14 * scale)
                    local iconY = math.floor(midY - iconSz / 2 + MenuIconOffsetY * scale)
                    if iconHandle then
                        Impl.Img(iconHandle, Vec2(curX, iconY), Vec2(iconSz, iconSz), FadeColor(chip.color, compactAlpha), 0)
                    end
                    tx = curX + math.floor(20 * scale)
                end
                Odometer.Draw(chip.font, sChip, chip.text, Vec2(tx, ty), FadeColor(chip.color, compactAlpha))
            end
            curX = curX + chip.width
            if idx < #renderedChips then
                local dotX = curX + 6 * scale
                Render.FilledCircle(Vec2(dotX, midY), 1.6 * scale, FadeColor(Config.Colors.TextMuted, compactAlpha), 0, 1.0, 12)
                curX = dotX + 6 * scale
            end
        end
    end

    if elemT > 0.01 then
        local divStartY = math.floor(lL.y + 14 * scale)
        local divTotalH = math.max(10, math.floor(lL.h - 28 * scale))
        Render.Line(Vec2(g.divX, divStartY), Vec2(g.divX, divStartY + math.floor(divTotalH * elemT)), FadeColor(Config.Colors.Separator, elemT), 1.0)
    end

    local lateAlpha = math.max(0.0, (elemT - 0.20) / 0.80) ^ 1.5
    if lateAlpha > 0.01 then
        local hmH = Render.TextSize(fNum, sNum, "0").y
        local hmW = Odometer.Width(curFont, curSize, timeHM)
        local secH = Render.TextSize(fSec, sSec, "0").y
        if clockFormat ~= 2 then
            Odometer.Draw(fSec, sSec, os.date(":%S"), Vec2(math.floor(curClockX + hmW + 2 * scale), math.floor(curClockY + (hmH - secH) * 0.8)), FadeColor(Config.Colors.TextSecondary, lateAlpha))
        end
        local matchTime = GetActualMatchTime()
        local subInfo = (matchTime and matchTime > 0) and (L("di_ui_match") .. FormatTime(matchTime)) or L("di_ui_main_menu")
        Odometer.Draw(fFoot, sFoot, subInfo, Vec2(g.leftX, math.floor(curClockY + hmH + 2 * scale)), FadeColor(Config.Colors.TextSecondary, lateAlpha))
    end

    local unfoldShiftX = math.floor((1.0 - elemT) * -16 * scale)
    local function Row(id, svg, txt, tx, ty, bigFont, bigSize, bigCol)
        local cm = compactMap[id]
        local iconCol = Config.Colors.TextSecondary
        if cm then
            local sx = cm.startX
            local iconSz = math.floor(14 * scale + (g.icon - 14 * scale) * elemT + 0.5)
            local sy = math.floor(midY - 7 * scale + MenuIconOffsetY * scale)
            local ix = math.floor(sx + (tx - sx) * elemT + 0.5)
            local iy = math.floor(sy + (ty - sy) * elemT + 0.5)
            local h = GetVectorIcon(svg)
            local iconA = cm.chip.svgKey and 1 or elemT
            if h and iconA > 0.01 then Impl.Img(h, Vec2(ix, iy), Vec2(iconSz, iconSz), FadeColor(LerpColor(cm.chip.color, iconCol, elemT), iconA), 0) end
            local sz = Q(sChip + (bigSize - sChip) * elemT)
            local dx0 = cm.chip.svgKey and 20 * scale or 0
            local dx = math.floor(dx0 + (g.textDX - dx0) * elemT + 0.5)
            local col = LerpColor(cm.chip.color, bigCol, elemT)
            local mix = (bigFont == cm.chip.font and txt == cm.chip.text) and 1 or math.max(0, math.min(1, (elemT - 0.25) / 0.5))
            local midT = iy + iconSz / 2
            if mix < 1 then
                local th = Render.TextSize(cm.chip.font, sz, "0").y
                Odometer.Draw(cm.chip.font, sz, (elemT < 0.5) and cm.chip.text or txt, Vec2(ix + dx, math.floor(midT - th / 2)), FadeColor(col, 1 - mix))
            end
            if mix > 0 then
                local th = Render.TextSize(bigFont, sz, "0").y
                Odometer.Draw(bigFont, sz, txt, Vec2(ix + dx, math.floor(midT - th / 2)), FadeColor(col, mix))
            end
        elseif lateAlpha > 0.01 then
            local ux = tx + unfoldShiftX
            local h = GetVectorIcon(svg)
            if h then Impl.Img(h, Vec2(ux, ty), Vec2(g.icon, g.icon), FadeColor(iconCol, lateAlpha), 0) end
            local th = Render.TextSize(bigFont, bigSize, "0").y
            Odometer.Draw(bigFont, bigSize, txt, Vec2(ux + g.textDX, math.floor(ty + g.icon / 2 - th / 2)), FadeColor(bigCol, lateAlpha))
        end
    end
    Row("kda", "kda", string.format("%d/%d/%d", HeroData.Kills, HeroData.Deaths, HeroData.Assists), g.rightX, g.row1Y, fHead, sHead, Config.Colors.TextPrimary)
    Row("gold", "gold", Odometer.Group(HeroData.Gold), g.col2X, g.row1Y, fHead, sHead, Config.Colors.TextPrimary)
    Row("fps", "fps", string.format("%d FPS", PerformanceData.FPS), g.rightX, g.row2Y, fSec, sSec, PerfTint("fps", Config.Colors.TextSecondary))
    Row("ping", "ping", string.format("%d ms", PerformanceData.Ping), g.col2X, g.row2Y, fSec, sSec, PerfTint("ping", Config.Colors.TextSecondary))

    local tileA = math.max(0, (elemT - 0.5) / 0.5) ^ 1.5
    if tileA > 0.01 then
        Focus.RenderTile(lL, g.rightX, math.floor(lL.x + lL.w - 14 * scale), math.floor(lL.y + lL.h - 12 * scale - 26 * scale), tileA)
    end
end

function Sheet.BridgeOnline()
    return BridgeStatus.LastOk > 0 and (os.clock() - BridgeStatus.LastOk) < 10
end

function Sheet.BridgeMissing(now)
    return BridgeStatus.FirstPoll > 0 and (now - BridgeStatus.FirstPoll) > 6 and not Sheet.BridgeOnline() and Impl.BridgeRefused()
end

function Sheet.UpdateInfo()
    if not Sheet.BridgeOnline() then return nil end
    local mine = Impl.ParseVersion(SCRIPT_VERSION)
    local bridge = Impl.ParseVersion(BridgeStatus.Version)
    local latest = Impl.ParseVersion(BridgeStatus.Latest)
    local canSelf = bridge and not Impl.VersionLess(bridge, { 2, 2, 0 })
    if latest and ((mine and Impl.VersionLess(mine, latest)) or (bridge and Impl.VersionLess(bridge, latest))) then
        return { title = "Dynamic Island " .. string.gsub(BridgeStatus.Latest, "^[vV]", ""), sub = canSelf and L("di_upd_available") or L("di_upd_manual"), canSelf = canSelf }
    end
    if bridge and mine and Impl.VersionLess(bridge, mine) then
        return { title = L("di_upd_bridge_title"), sub = canSelf and L("di_upd_bridge_sub") or L("di_upd_manual"), canSelf = canSelf }
    end
    return nil
end

function Sheet.BadgeOn()
    return Sheet.Dismissed and Sheet.Upd.State == "idle" and Sheet.UpdateInfo() ~= nil
end

function Sheet.Pick(now)
    if Sheet.Forced then
        Sheet.Kind = Sheet.Forced
        return true
    end
    if not Sheet.MenuSince or now - Sheet.MenuSince < 1.5 then return false end
    local kind
    if Sheet.Upd.State ~= "idle" then
        kind = "update"
    elseif Sheet.Fonts.State ~= "idle" then
        kind = "fonts"
    elseif #Sdk.Asks > 0 then
        kind = "sdk_perm"
        Sdk.Prompt = Sdk.Asks[1]
    elseif Sheet.ConfigLoaded and string.match(Sheet.SeenVer or "", "^%d+%.%d+") ~= string.match(SCRIPT_VERSION, "^%d+%.%d+") then
        kind = "whatsnew"
    elseif not Sheet.BridgeHintSeen and Sheet.BridgeMissing(now) then
        kind = "bridge"
    elseif not Sheet.FontsDismissed and Sheet.BridgeOnline() and BridgeStatus.FontsOk == false then
        kind = "fonts"
    elseif not Sheet.Dismissed and Sheet.UpdateInfo() then
        kind = "update"
    end
    Sheet.Kind = kind or Sheet.Kind
    return kind ~= nil
end

Sheet.News = {
    { glyph = "stack", color = "Orange", t = "di_wn_1_t", d = "di_wn_1_d" },
    { glyph = "lyrics", color = "Pink", t = "di_wn_2_t", d = "di_wn_2_d" },
    { glyph = "appearance", color = "Blue", t = "di_wn_3_t", d = "di_wn_3_d" },
    { glyph = "plus", color = "Purple", t = "di_wn_4_t", d = "di_wn_4_d" }
}

function Sheet.Desc()
    local C = Config.Colors
    local kind = Sheet.Kind
    if kind == "sdk_perm" then
        local app = Sdk.Prompt or Sdk.LastPrompt or ""
        return { icon = "square", color = Sdk.AppTint(app), glyph = "bell", title = "\u{201C}" .. app .. "\u{201D}", sub = L("di_sdk_perm_sub"), buttons = { { L("di_sdk_deny"), false, "sdk_deny" }, { L("di_sdk_allow"), true, "sdk_allow" } } }
    end
    if kind == "bridge" then
        return { icon = "square", color = C.Orange, glyph = "music", title = L("di_br_title"), sub = L("di_br_sub"), buttons = { { L("di_upd_ok"), true, "bridge_seen" } } }
    end
    if kind == "fonts" then
        local st = Sheet.Fonts.State
        if st == "installing" then
            return { icon = "spin", title = L("di_fonts_installing"), sub = "SF Pro" }
        elseif st == "done" then
            return { icon = "ok", title = L("di_fonts_done"), sub = L("di_upd_ready_sub"), buttons = { { L("di_upd_restart"), true, "reload" } } }
        elseif st == "error" then
            return { icon = "fail", title = L("di_fonts_failed"), sub = L("di_fonts_failed_sub"), buttons = { { L("di_upd_later"), false, "fonts_later" }, { L("di_upd_retry"), true, "fonts_install" } } }
        end
        return { icon = "text", color = C.Blue, text = "Aa", title = L("di_fonts_title"), sub = L("di_fonts_sub"), buttons = { { L("di_upd_later"), false, "fonts_later" }, { L("di_fonts_install"), true, "fonts_install" } } }
    end
    local u = Sheet.Upd
    local info = Sheet.UpdateInfo() or { title = "Dynamic Island", sub = "", canSelf = true }
    if u.State == "downloading" or u.State == "installing" or u.State == "restarting" then
        local p = u.State == "downloading" and math.max(0.02, math.min(1, u.Progress)) or 1
        return { icon = "ring", progress = p, title = u.State == "downloading" and L("di_upd_downloading") or L("di_upd_installing"), sub = info.title }
    elseif u.State == "ready" then
        return { icon = "ok", title = L("di_upd_ready"), sub = L("di_upd_ready_sub"), buttons = { { L("di_upd_restart"), true, "restart" } } }
    elseif u.State == "error" then
        return { icon = "fail", title = L("di_upd_failed"), sub = L("di_upd_failed_sub"), buttons = { { L("di_upd_later"), false, "later" }, { L("di_upd_retry"), true, "install" } } }
    end
    local buttons = info.canSelf and { { L("di_upd_later"), false, "later" }, { L("di_upd_install"), true, "install" } } or { { L("di_upd_ok"), true, "later" } }
    return { icon = "square", color = C.Blue, glyph = "arrow_down", title = info.title, sub = info.sub, buttons = buttons }
end

function Sheet.Size()
    if Sheet.Kind == "whatsnew" then
        return 360, 18 + 30 + #Sheet.News * 46 + 6 + 36 + 18
    end
    return 340, Sheet.Desc().buttons and 126 or 80
end

function Sheet.UrlEncode(s)
    return (string.gsub(s, "[^%w%-%._~]", function(c) return string.format("%%%02X", string.byte(c)) end))
end

function Sheet.StartUpdate(now)
    local dir = "C:\\Umbrella\\scripts"
    if Engine and Engine.GetCheatDirectory then
        local ok, cd = pcall(Engine.GetCheatDirectory)
        if ok and cd and cd ~= "" then dir = string.gsub((string.gsub(cd, "/", "\\")), "\\$", "") .. "\\scripts" end
    end
    local _, probe = pcall(function() error("di_self") end)
    local self = string.match(tostring(probe), "^(.-%.lua):%d+: di_self")
    Sheet.Upd.State = "downloading"
    Sheet.Upd.Progress = 0
    Sheet.Upd.Error = ""
    Sheet.Upd.LastOk = now
    local q = "dir=" .. Sheet.UrlEncode(dir) .. (self and ("&path=" .. Sheet.UrlEncode(self)) or "")
    pcall(Impl.HttpRequest, "GET", "http://127.0.0.1:45455/update/start?" .. q, {}, function() end, "di_update_start")
end

function Sheet.PollFonts(now)
    local f = Sheet.Fonts
    if f.State ~= "installing" then return end
    if now - f.LastOk > 60 then
        f.State = "error"
        return
    end
    if now - f.LastPoll < 0.4 then return end
    f.LastPoll = now
    pcall(Impl.HttpRequest, "GET", "http://127.0.0.1:45455/fonts", {}, function(res)
        if not res or not res.response or res.response == "" then return end
        local st = string.match(res.response, '"state"%s*:%s*"([^"]*)"')
        if not st then return end
        f.LastOk = os.clock()
        if st == "done" or st == "error" then f.State = st end
    end, "di_fonts_status")
end

function Sheet.PollUpdate()
    local u = Sheet.Upd
    local now = os.clock()
    if Sheet.ReloadAt and now >= Sheet.ReloadAt then
        Sheet.ReloadAt = nil
        if Engine and Engine.ReloadScriptSystem then pcall(Engine.ReloadScriptSystem) end
        return
    end
    Sheet.PollFonts(now)
    if u.State ~= "downloading" and u.State ~= "installing" then return end
    if now - u.LastOk > 20 then
        u.State = "error"
        u.Error = "offline"
        return
    end
    if now - u.LastPoll < 0.25 then return end
    u.LastPoll = now
    pcall(Impl.HttpRequest, "GET", "http://127.0.0.1:45455/update/status", {}, function(res)
        if not res or not res.response or res.response == "" then return end
        local body = res.response
        local st = string.match(body, '"state"%s*:%s*"([^"]*)"')
        if not st then return end
        u.LastOk = os.clock()
        u.Progress = tonumber(string.match(body, '"progress"%s*:%s*([%d%.eE%-]+)') or "0") or 0
        u.Error = string.match(body, '"error"%s*:%s*"([^"]*)"') or ""
        if st == "downloading" or st == "installing" or st == "ready" or st == "error" then
            u.State = st
        end
    end, "di_update_status")
end

function Sheet.Action(action, now)
    if action == "later" then
        Sheet.Dismissed = true
        Sheet.Upd.State = "idle"
    elseif action == "install" then
        Sheet.StartUpdate(now)
    elseif action == "restart" then
        Sheet.Upd.State = "restarting"
        Sheet.ReloadAt = now + 1.2
        pcall(Impl.HttpRequest, "GET", "http://127.0.0.1:45455/update/restart", {}, function() end, "di_update_restart")
    elseif action == "reload" then
        Sheet.ReloadAt = now + 0.2
    elseif action == "fonts_install" then
        Sheet.Fonts.State = "installing"
        Sheet.Fonts.LastOk = now
        pcall(Impl.HttpRequest, "GET", "http://127.0.0.1:45455/fonts/install", {}, function() end, "di_fonts_install")
    elseif action == "fonts_later" then
        Sheet.FontsDismissed = true
        Sheet.Fonts.State = "idle"
    elseif action == "bridge_seen" then
        Sheet.BridgeHintSeen = true
        SaveAllConfig()
    elseif action == "seen" then
        Sheet.SeenVer = SCRIPT_VERSION
        Sheet.Forced = nil
        SaveAllConfig()
    elseif action == "nc_clear" then
        if Dbg.On then Dbg.Log("notif", "notification center cleared") end
        NotifCenter.Items = {}
    elseif action == "sdk_allow" then
        Sdk.Answer(true)
    elseif action == "sdk_deny" then
        Sdk.Answer(false)
    end
end

function Sheet.Button(x, y, w, h, label, primary, action, aMul, s)
    local C = Config.Colors
    local _, pk = Pointer.Button("sb_" .. tostring(action or label), x, y, x + w, y + h)
    local kx, ky = w * 0.0175 * pk, h * 0.0175 * pk
    local dim = aMul * (1 - 0.22 * pk)
    Render.FilledRect(Vec2(x + kx, y + ky), Vec2(x + w - kx, y + h - ky), FadeColor(primary and C.Blue or C.FillSecondary, dim), (h - ky * 2) / 2)
    local f, sz = TF("Headline", s)
    local ts = Render.TextSize(f, sz, label)
    Render.Text(f, sz, label, Vec2(math.floor(x + (w - ts.x) / 2), math.floor(y + (h - ts.y) / 2)), FadeColor(primary and Color(255, 255, 255, 255) or C.TextPrimary, dim))
    if aMul > 0.9 and action then
        table.insert(Sheet.Hits, { x1 = x, y1 = y, x2 = x + w, y2 = y + h, action = action })
    end
end

function Sheet.Buttons(layout, y, aMul, s, a, b)
    local pad = math.floor(16 * s)
    local h = math.floor(34 * s)
    local x0 = layout.x + pad
    local w = layout.w - pad * 2
    if b then
        local gap = math.floor(10 * s)
        local bw = math.floor((w - gap) / 2)
        Sheet.Button(x0, y, bw, h, a[1], a[2], a[3], aMul, s)
        Sheet.Button(x0 + bw + gap, y, w - bw - gap, h, b[1], b[2], b[3], aMul, s)
    else
        Sheet.Button(x0, y, w, h, a[1], a[2], a[3], aMul, s)
    end
end

function Sheet.Render(layout, alphaMul, yOffset)
    if Sheet.Kind == "whatsnew" then
        Sheet.RenderNews(layout, alphaMul, yOffset)
    else
        Sheet.RenderCard(layout, alphaMul, yOffset, Sheet.Desc())
    end
end

function Sheet.RenderCard(layout, alphaMul, yOffset, d)
    local a = alphaMul or 1
    local s = layout.scale
    local C = Config.Colors
    local pad = math.floor(16 * s)
    local isz = math.floor(44 * s)
    local ix = layout.x + pad
    local iy = math.floor(layout.y + pad + (yOffset or 0))
    local icx, icy = ix + isz / 2, iy + isz / 2
    local white = FadeColor(Color(255, 255, 255, 255), a)

    if d.icon == "ring" or d.icon == "spin" then
        local r = math.floor(18 * s)
        Render.Circle(Vec2(icx, icy), r, FadeColor(C.Fill, a), 3 * s, 0, 1.0, false, 48)
        if d.icon == "spin" then
            Render.Circle(Vec2(icx, icy), r, FadeColor(C.Blue, a), 3 * s, (os.clock() * 360) % 360, 0.28, true, 48)
        else
            Render.Circle(Vec2(icx, icy), r, FadeColor(C.Blue, a), 3 * s, 270, d.progress, true, 48)
            local fP, sP = TF("Caption2", s)
            local pct = string.format("%d", math.floor(d.progress * 100 + 0.5))
            local pw = Odometer.Width(fP, sP, pct)
            local ph = Render.TextSize(fP, sP, pct).y
            Odometer.Draw(fP, sP, pct, Vec2(math.floor(icx - pw / 2), math.floor(icy - ph / 2)), FadeColor(C.TextPrimary, a))
        end
    elseif d.icon == "ok" or d.icon == "fail" then
        Render.FilledCircle(Vec2(icx, icy), isz / 2, FadeColor(d.icon == "ok" and C.Green or C.Red, a), 0, 1.0, 32)
        Glyph(d.icon == "ok" and "check" or "close", icx, icy, math.floor(isz * (d.icon == "ok" and 0.5 or 0.46)), white)
    else
        Render.FilledRect(Vec2(ix, iy), Vec2(ix + isz, iy + isz), FadeColor(d.color or C.Blue, a), math.floor(11 * s))
        if d.text then
            local fA, sA = TF("Title", s * 1.15)
            local ts = Render.TextSize(fA, sA, d.text)
            Render.Text(fA, sA, d.text, Vec2(math.floor(icx - ts.x / 2), math.floor(icy - ts.y / 2)), white)
        else
            Glyph(d.glyph, icx, icy, math.floor(isz * 0.52), white)
        end
    end

    local tx = ix + isz + math.floor(12 * s)
    local maxW = layout.x + layout.w - pad - tx
    local fT, sT = TF("Title", s)
    local fS, sS = TF("Subhead", s)
    local th = Render.TextSize(fT, sT, "Ag").y
    local sh = Render.TextSize(fS, sS, "Ag").y
    local ty = math.floor(icy - (th + sh + 2 * s) / 2)
    Render.Text(fT, sT, TruncateToWidth(fT, sT, d.title, maxW), Vec2(tx, ty), FadeColor(C.TextPrimary, a))
    Render.Text(fS, sS, TruncateToWidth(fS, sS, d.sub or "", maxW), Vec2(tx, math.floor(ty + th + 2 * s)), FadeColor(C.TextSecondary, a))

    if d.buttons then
        Sheet.Buttons(layout, iy + isz + math.floor(16 * s), a, s, d.buttons[1], d.buttons[2])
    end
end

function Sheet.RenderNews(layout, alphaMul, yOffset)
    local a = alphaMul or 1
    local s = layout.scale
    local C = Config.Colors
    local pad = math.floor(18 * s)
    local y = math.floor(layout.y + pad + (yOffset or 0))
    local fT, sT = TF("Title", s)
    Render.Text(fT, sT, L("di_wn_title"), Vec2(layout.x + pad, y), FadeColor(C.TextPrimary, a))
    local fV, sV = TF("Footnote", s)
    local ver = SCRIPT_VERSION
    local vw = Odometer.Width(fV, sV, ver)
    local vy = math.floor(y + (Render.TextSize(fT, sT, "Ag").y - Render.TextSize(fV, sV, "Ag").y) / 2)
    Odometer.Draw(fV, sV, ver, Vec2(math.floor(layout.x + layout.w - pad - vw), vy), FadeColor(C.TextSecondary, a))

    local fH, sH = TF("Headline", s)
    local fD, sD = TF("Footnote", s)
    local isz = math.floor(30 * s)
    local rowY = y + math.floor(30 * s)
    for i, n in ipairs(Sheet.News) do
        local ry = rowY + (i - 1) * math.floor(46 * s)
        local cx, cy = layout.x + pad + isz / 2, ry + isz / 2 + math.floor(2 * s)
        Render.FilledCircle(Vec2(cx, cy), isz / 2, FadeColor(C[n.color] or C.Blue, a), 0, 1.0, 28)
        Glyph(n.glyph, cx, cy, math.floor(isz * 0.56), FadeColor(Color(255, 255, 255, 255), a))
        local tx = layout.x + pad + isz + math.floor(12 * s)
        local maxW = layout.x + layout.w - pad - tx
        local hh = Render.TextSize(fH, sH, "Ag").y
        Render.Text(fH, sH, TruncateToWidth(fH, sH, L(n.t), maxW), Vec2(tx, ry), FadeColor(C.TextPrimary, a))
        Render.Text(fD, sD, TruncateToWidth(fD, sD, L(n.d), maxW), Vec2(tx, math.floor(ry + hh + 1 * s)), FadeColor(C.TextSecondary, a))
    end
    local by = rowY + #Sheet.News * math.floor(46 * s) + math.floor(6 * s)
    Sheet.Buttons(layout, by, a, s, { L("di_wn_continue"), true, "seen" })
end

function Sheet.RenderBadge(layout)
    if StateMachine.TargetState ~= StateMachine.States.MENU_IDLE or not Sheet.BadgeOn() then return end
    local s = layout.scale
    local r = math.floor(5 * s)
    local c = Vec2(math.floor(layout.x + layout.w - layout.r * 0.3), math.floor(layout.y + layout.r * 0.3))
    Render.FilledCircle(c, r + math.floor(2 * s), Color(0, 0, 0, 200), 0, 1.0, 20)
    Render.FilledCircle(c, r, Config.Colors.Red, 0, 1.0, 20)
end

function NotifCenter.Add(n)
    table.insert(NotifCenter.Items, 1, { tag = n.Tag or "", title = n.Title or "", accent = n.AccentColor, fb = n.FallbackSvg, icon = n.Icon, mono = n.Mono, app = n.SdkApp, onTap = n.OnTap, t = os.clock() })
    while #NotifCenter.Items > 24 do table.remove(NotifCenter.Items) end
end

NotifCenter.Open = {}
NotifCenter.RowHits = {}
NotifCenter.RowH = 44
NotifCenter.StackH = 8

function NotifCenter.Rows()
    local groups, order = {}, {}
    for _, it in ipairs(NotifCenter.Items) do
        local g = groups[it.tag]
        if not g then
            g = { key = it.tag, items = {} }
            groups[it.tag] = g
            order[#order + 1] = g
        end
        g.items[#g.items + 1] = it
    end
    local rows = {}
    for i = 1, math.min(5, #order) do
        local g = order[i]
        if #g.items > 1 and NotifCenter.Open[g.key] then
            for j = 1, math.min(5, #g.items) do
                rows[#rows + 1] = { item = g.items[j], group = g, count = 1, open = true }
            end
        else
            rows[#rows + 1] = { item = g.items[1], group = g, count = #g.items }
        end
    end
    return rows
end

function NotifCenter.Height()
    local rows = NotifCenter.Rows()
    if #rows == 0 then return 96 end
    local h = 46
    for _, r in ipairs(rows) do
        h = h + NotifCenter.RowH + (r.count > 1 and NotifCenter.StackH or 0)
    end
    return h + 6
end

function NotifCenter.Ago(t)
    local d = math.max(0, os.clock() - t)
    if d < 60 then return L("di_nc_now") end
    if d < 3600 then return string.format(L("di_nc_min"), math.floor(d / 60)) end
    return string.format(L("di_nc_hour"), math.floor(d / 3600))
end

function NotifCenter.Remove(row)
    local list = NotifCenter.Items
    for i = #list, 1, -1 do
        local it = list[i]
        if it == row.item or (row.count > 1 and it.tag == row.group.key) then
            table.remove(list, i)
        end
    end
    local left = 0
    for _, it in ipairs(list) do
        if it.tag == row.group.key then left = left + 1 end
    end
    if left < 2 then NotifCenter.Open[row.group.key] = nil end
end

function NotifCenter.Toggle(row)
    if row.count > 1 then
        NotifCenter.Open[row.group.key] = true
    elseif row.open then
        NotifCenter.Open[row.group.key] = nil
    else
        return
    end
    if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
end

function NotifCenter.Render(layout, alphaMul, yOffset)
    local a = alphaMul or 1
    local s = layout.scale
    local C = Config.Colors
    local pad = math.floor(16 * s)
    local yOff = yOffset or 0
    local fH, sH = TF("FootnoteEm", s)
    local hy = math.floor(layout.y + 16 * s + yOff)
    Render.Text(fH, sH, L("di_nc_title"), Vec2(layout.x + pad, hy), FadeColor(C.TextSecondary, a))
    NotifCenter.RowHits = {}

    local rows = NotifCenter.Rows()
    if #rows == 0 then
        local fE, sE = TF("Subhead", s)
        local msg = L("di_nc_empty")
        local ts = Render.TextSize(fE, sE, msg)
        Render.Text(fE, sE, msg, Vec2(math.floor(layout.x + (layout.w - ts.x) / 2), math.floor(layout.y + 50 * s + yOff)), FadeColor(C.TextMuted, a))
        return
    end

    local clr = L("di_nc_clear")
    local cs = Render.TextSize(fH, sH, clr)
    local ccx = math.floor(layout.x + layout.w - pad - cs.x)
    local _, cpk = Pointer.Button("nc_clear", ccx - 6, hy - 6, ccx + cs.x + 6, hy + cs.y + 6)
    Render.Text(fH, sH, clr, Vec2(ccx, hy), FadeColor(C.Blue, a * (1 - 0.4 * cpk)))
    if a > 0.9 then
        table.insert(NotifCenter.Hits, { x1 = ccx - 6, y1 = hy - 6, x2 = ccx + cs.x + 6, y2 = hy + cs.y + 6, action = "nc_clear" })
    end

    local dt = Pointer.dt
    local fT, sT = TF("Caption", s)
    local fB, sB = TF("Subhead", s)
    local isz = math.floor(26 * s)
    local gl, gr = layout.x + 10 * s, layout.x + layout.w - 10 * s
    local w = gr - gl
    local cardH = (NotifCenter.RowH - 6) * s
    local dragItem = Swipe.Target == "nc" and Swipe.Row and Swipe.Row.item or nil
    local y = 42 * s
    local th = Render.TextSize(fT, sT, "Ag").y
    for _, r in ipairs(rows) do
        local it = r.item
        if not it._y then it._y, it._yv = y, 0 end
        it._y, it._yv = MotionEngine.Step(it._y, it._yv, y, dt, "SMOOTH")
        local xo = it._x or 0
        if dragItem ~= it then
            local tx = it._gone and -(w + 40 * s) or 0
            it._x, it._xv = MotionEngine.Step(xo, it._xv or 0, tx, dt, it._gone and "SNAPPY" or "BOUNCY")
            xo = it._x
        end
        local top = math.floor(layout.y + it._y + yOff)

        if xo < -4 * s and not it._gone then
            local rw = math.min(-xo - 6 * s, w)
            if rw > 6 * s then
                Render.FilledRect(Vec2(gr - rw, top), Vec2(gr, top + cardH), FadeColor(C.Red, a), math.min(12 * s, rw / 2))
                local ls = Render.TextSize(fT, sT, clr)
                if rw > ls.x + 16 * s then
                    Render.Text(fT, sT, clr, Vec2(math.floor(gr - rw / 2 - ls.x / 2), math.floor(top + (cardH - ls.y) / 2)), FadeColor(Color(255, 255, 255, 255), a))
                end
            end
        end

        if r.count > 1 then
            Render.FilledRect(Vec2(gl + 16 * s + xo, top + cardH), Vec2(gr - 16 * s + xo, top + cardH + 7 * s), FadeColor(C.Group, a * 0.45), 8 * s, Enum.DrawFlags.RoundCornersBottom)
            Render.FilledRect(Vec2(gl + 8 * s + xo, top + cardH), Vec2(gr - 8 * s + xo, top + cardH + 3.5 * s), FadeColor(C.Group, a * 0.8), 8 * s, Enum.DrawFlags.RoundCornersBottom)
        end
        Render.FilledRect(Vec2(gl + xo, top), Vec2(gr + xo, top + cardH), FadeColor(C.Group, a), 12 * s)

        local icx, icy = gl + xo + 8 * s + isz / 2, top + cardH / 2
        local accent = it.accent or C.Blue
        local img = it.icon and GetCachedImage(it.icon) or nil
        if not img and it.fb and not NotifGlyphs[it.fb] and not it.mono then img = GetCachedImage(nil, it.fb) end
        if img then
            Impl.Img(img, Vec2(math.floor(icx - isz / 2), math.floor(icy - isz / 2)), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), a), math.floor(isz / 2))
        else
            Render.FilledCircle(Vec2(icx, icy), isz / 2, FadeColor(accent, a), 0, 1.0, 24)
            Glyph(it.fb or "bell", icx, icy, math.floor(isz * 0.56), FadeColor(Color(255, 255, 255, 255), a))
        end
        local tx = math.floor(gl + xo + 8 * s + isz + 9 * s)
        local right = gr + xo - 10 * s
        local ago = NotifCenter.Ago(it.t)
        local aw = Render.TextSize(fT, sT, ago).x
        local ly = math.floor(top + cardH / 2 - th - 1 * s)
        Render.Text(fT, sT, TruncateToWidth(fT, sT, it.tag, right - tx - aw - 8 * s), Vec2(tx, ly), FadeColor(Impl.OnLight(accent), a))
        Render.Text(fT, sT, ago, Vec2(math.floor(right - aw), ly), FadeColor(C.TextMuted, a))
        local titleMax = right - tx
        if r.count > 1 then
            local badge = "+" .. tostring(r.count - 1)
            local bw = Render.TextSize(fT, sT, badge).x + 10 * s
            local bh = th + 2 * s
            local by = math.floor(top + cardH / 2 + 1 * s)
            Render.FilledRect(Vec2(right - bw, by), Vec2(right, by + bh), FadeColor(C.FillSecondary, a), bh / 2)
            Render.Text(fT, sT, badge, Vec2(math.floor(right - bw + 5 * s), math.floor(by + 1 * s)), FadeColor(C.TextPrimary, a))
            titleMax = titleMax - bw - 6 * s
        end
        Render.Text(fB, sB, TruncateToWidth(fB, sB, it.title, titleMax), Vec2(tx, math.floor(top + cardH / 2)), FadeColor(C.TextPrimary, a))

        if a > 0.9 and not it._gone then
            NotifCenter.RowHits[#NotifCenter.RowHits + 1] = { x1 = gl, y1 = top, x2 = gr, y2 = top + cardH, row = r }
        end
        if it._gone and xo < -w then
            NotifCenter.Remove(r)
        end
        y = y + NotifCenter.RowH * s + (r.count > 1 and NotifCenter.StackH * s or 0)
    end
end

Sdk.API = 2
Sdk.Apps = {}
Sdk.Asks = {}
Sdk.AskAt = {}
Sdk.AskHidden = {}
Sdk.Pending = {}
Sdk.Strikes = {}
Sdk.StrikeAt = {}
Sdk.Muted = {}
Sdk.Errors = {}
Sdk.Early = {}
Sdk.Warned = {}
Sdk.Acts = {}
Sdk.Bucket = {}
Sdk.Hits = {}
Sdk.Expanded = false
Sdk.ExpandK, Sdk.ExpandV = 0, 0
Sdk.LastT = 0
Sdk.Focus = {}
Sdk.Sound = {}
Sdk.Slots = {}
Sdk.MenuDirty = true
Sdk.MenuAt = 0
Sdk.SoundWin = { t = 0, n = 0 }
Sdk.Seq = 0
Sdk.Seen = {}
Sdk.SeenCount = 0
Sdk.LogBudget = 40
Sdk.Images = {}
Sdk.ImageCount = 0
Sdk.Hook = debug and debug.sethook and debug.gethook and { set = debug.sethook, get = debug.gethook } or nil
Sdk.Features = { notify = true, activity = true, queue = true, levels = true, sounds = true, body = true, actions = true, trailing = true, onEnd = true, staleAfter = true, endAfter = true, playSound = true, focus = true, widgets = true, faceId = true }
Sdk.SoundFiles = { notification_toast = true, timer_chime = true, courier_delivered = true, courier_death_or_fail = true, button_press = true, button_dismiss = true, wheel_notch = true, wheel_boundary_bump = true, island_expand = true, island_collapse = true, island_hover = true, toast_dismiss = true }
Sdk.Levels = { passive = 1, active = 3, ["time-sensitive"] = 5 }
Sdk.Sounds = { default = "notification_toast", chime = "timer_chime", success = "courier_delivered", failure = "courier_death_or_fail" }
Sdk.Tints = { "red", "orange", "yellow", "green", "mint", "teal", "cyan", "blue", "indigo", "purple", "pink", "brown", "gray" }
Sdk.Palette = { "Blue", "Orange", "Green", "Purple", "Pink", "Teal", "Indigo", "Red" }

function Sdk.S(v)
    local ok, s = pcall(tostring, v)
    if ok and type(s) == "string" then return string.sub(s, 1, 300) end
    return "?"
end

function Sdk.Log(app, msg)
    if Dbg.On then Dbg.Log("sdk", (app and (app .. ": ") or "") .. msg) end
    if Sdk.LogBudget <= 0 then return end
    Sdk.LogBudget = Sdk.LogBudget - 1
    pcall(Log.Write, "[Dynamic Island] " .. (app and (app .. ": ") or "") .. msg)
end

function Sdk.Num(v, lo, hi)
    local n = tonumber(v)
    if not n or n ~= n then return nil end
    return math.max(lo, math.min(hi, n))
end

function Sdk.Byte(v)
    if type(v) ~= "number" or v ~= v then return 0 end
    return math.floor(math.max(0, math.min(255, v)))
end

function Sdk.Known(app)
    if Sdk.Seen[app] or Sdk.Apps[app] ~= nil then return true end
    if Sdk.SeenCount >= 24 then
        Sdk.Warn(nil, "too many different app names, ignoring new ones until reload")
        return false
    end
    Sdk.Seen[app] = true
    Sdk.SeenCount = Sdk.SeenCount + 1
    return true
end

function Sdk.Warn(app, msg)
    local key = tostring(app) .. "\0" .. msg
    if Sdk.Warned[key] then return end
    Sdk.Warned[key] = true
    Sdk.Log(app, msg)
end

function Sdk.Str(v, max)
    if v == nil then return nil end
    v = tostring(v)
    if type(v) ~= "string" then return nil end
    if #v > max * 4 + 16 then
        v = string.gsub(string.sub(v, 1, max * 4 + 16), "[\192-\255][\128-\191]*$", "")
    end
    v = string.gsub(v, "%c", " ")
    local ok, n = pcall(utf8.len, v)
    if not (ok and n) then
        v = string.gsub(v, "[\128-\255]", "?")
        n = #v
    end
    if n > max then v = string.sub(v, 1, utf8.offset(v, max + 1) - 1) end
    return v
end

function Sdk.Text(v, max)
    if v == false or v == "" then return nil end
    return Sdk.Str(v, max)
end

function Sdk.AppName(v)
    if type(v) ~= "string" then return nil end
    v = Sdk.Str(string.gsub(v, "[|:=]", ""), 24)
    v = v and string.match(v, "^%s*(.-)%s*$")
    if not v or v == "" then return nil end
    return v
end

function Sdk.AppTint(app)
    local h = 0
    for i = 1, #(app or "") do h = (h * 31 + string.byte(app, i)) % 997 end
    return Config.Colors[Sdk.Palette[h % #Sdk.Palette + 1]] or Config.Colors.Blue
end

function Sdk.Tint(t, app)
    if type(t) == "string" then
        local hex = string.match(t, "^#?(%x%x%x%x%x%x)$")
        if hex then
            return Color(tonumber(string.sub(hex, 1, 2), 16), tonumber(string.sub(hex, 3, 4), 16), tonumber(string.sub(hex, 5, 6), 16), 255)
        end
        local low = string.lower(t)
        for _, name in ipairs(Sdk.Tints) do
            if name == low then
                return Config.Colors[string.upper(string.sub(low, 1, 1)) .. string.sub(low, 2)]
            end
        end
    elseif t ~= nil then
        local ok, r, g, b = pcall(function() return t.r, t.g, t.b end)
        if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return Color(Sdk.Byte(r), Sdk.Byte(g), Sdk.Byte(b), 255)
        end
    end
    return app and Sdk.AppTint(app) or nil
end

function Sdk.Icon(icon)
    if type(icon) == "string" and icon ~= "" then
        if VectorIcons[icon] then return icon, nil end
        if #icon <= 160 and string.match(icon, "^[%w_%-][%w_%-/%.]*%.[%a_]+$") and not string.find(icon, "%.%.") then
            if not Sdk.Images[icon] then
                if Sdk.ImageCount >= 32 then return "bell", nil end
                Sdk.Images[icon] = true
                Sdk.ImageCount = Sdk.ImageCount + 1
            end
            return "bell", icon
        end
    end
    return "bell", nil
end

function Sdk.Guard(fn, ...)
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    Sdk.Log(nil, "rejected a call with bad arguments: " .. Sdk.S(a))
    return nil, "bad arguments"
end

function Sdk.Run(fn, ...)
    local H = Sdk.Hook
    if not H then return pcall(fn, ...) end
    local okGet, prev = pcall(H.get)
    if not okGet or prev then return pcall(fn, ...) end
    H.set(function()
        H.set()
        error("callback took too long", 2)
    end, "", 1000000)
    local ok, err = pcall(fn, ...)
    H.set()
    return ok, err
end

function Sdk.Call(app, fn, ...)
    if type(fn) ~= "function" or (Sdk.Errors[app] or 0) >= 3 then return end
    local ok, err = Sdk.Run(fn, ...)
    if ok then return end
    Sdk.Errors[app] = (Sdk.Errors[app] or 0) + 1
    Sdk.Log(app, "callback error: " .. Sdk.S(err))
    if Sdk.Errors[app] >= 3 then
        Sdk.Log(app, "callbacks turned off after repeated errors")
    end
end

function Sdk.Build(app, title, o)
    local lvl = Sdk.Levels[o.level] and o.level or "active"
    local glyph, image = Sdk.Icon(o.icon)
    local n = {
        Type = "sdk",
        Tag = app,
        Title = title,
        SdkApp = app,
        SdkLevel = lvl,
        PriorityOverride = Sdk.Levels[lvl],
        FallbackSvg = glyph,
        Icon = image,
        Mono = true,
        AccentColor = Sdk.Tint(o.tint, app)
    }
    n.Duration = Sdk.Num(o.duration, 1.5, 8)
    if o.sound == false or lvl == "passive" then
        n.Silent = true
    else
        n.Chime = Sdk.Sounds[o.sound] or (lvl == "time-sensitive" and "timer_chime" or "notification_toast")
    end
    if type(o.onTap) == "function" then n.OnTap = o.onTap end
    n.Trailing = Sdk.Text(o.trailing, 12)
    n.Body = Sdk.Text(o.body, 160)
    if type(o.actions) == "table" then
        local list = {}
        for i = 1, 2 do
            local ac = o.actions[i]
            if type(ac) == "table" then
                local t = Sdk.Text(ac.title, 20)
                if t then list[#list + 1] = { title = t, fn = type(ac.fn) == "function" and ac.fn or nil, destructive = ac.destructive == true } end
            end
        end
        if #list > 0 then n.Actions = list end
    end
    return n
end

function Sdk.Strike(app, now)
    local s = math.max(0, (Sdk.Strikes[app] or 0) - (now - (Sdk.StrikeAt[app] or now)))
    Sdk.StrikeAt[app] = now
    return s
end

function Sdk.Take(app, now)
    local b = Sdk.Bucket[app]
    if not b then
        b = { n = 3, t = now }
        Sdk.Bucket[app] = b
    end
    b.n = math.min(3, b.n + (now - b.t) / 2)
    b.t = now
    if b.n < 1 then return false end
    b.n = b.n - 1
    return true
end

function Sdk.Deliver(n)
    if n.SdkLevel == "passive" then
        NotifCenter.Add(n)
        return
    end
    local cur = NotificationQueue.Active
    n.Priority = Impl.GetNotifPriority(n)
    if cur and cur.SdkApp == n.SdkApp and not Focus.Blocks(n) then
        NotifCenter.Add(n)
        n.Duration = n.Duration or cur.Duration
        NotificationQueue.Active = n
        NotificationQueue.StartTime = os.clock()
        Impl.NotifChime(n)
        if Sdk.Expanded then
            Sdk.ExpandedFor = n
            Sdk.Expanded = n.Body ~= nil or n.Actions ~= nil
        end
        return
    end
    DynamicIsland.PushNotification(n)
end

function Sdk.Post(o, bulk)
    local app = Sdk.AppName(o.app)
    if not app then
        Sdk.Warn(nil, "Notify needs an app name")
        return nil, "app required"
    end
    local title = Sdk.Str(o.title, 80)
    if not title or title == "" then
        Sdk.Warn(app, "Notify needs a title")
        return nil, "title required"
    end
    if Sdk.Muted[app] then return nil, "muted" end
    if Sdk.Apps[app] == false then return nil, "not allowed" end
    if not Sdk.Known(app) then return nil, "too many apps" end
    if Sdk.Apps[app] == nil and not Sdk.Ask(app) then return nil, "busy" end
    if o.level ~= "passive" and Sdk.QueueFull(app) then return nil, "busy" end
    local now = os.clock()
    if bulk then
        if not Sdk.Take(app, now) then return nil, "rate limited" end
    elseif not Sdk.Take(app, now) then
        Sdk.Strikes[app] = Sdk.Strike(app, now) + 1
        if Sdk.Strikes[app] >= 15 then
            Sdk.Muted[app] = true
            Sdk.EndApp(app, "muted")
            Sdk.Unask(app)
            Sdk.Log(app, "muted until reload for sending too many notifications")
        else
            Sdk.Warn(app, "notifications are limited to 3 in a row, then one every 2 seconds")
        end
        return nil, "rate limited"
    end
    Sdk.Strikes[app] = Sdk.Strike(app, now)
    Sdk.Seq = Sdk.Seq + 1
    local n = Sdk.Build(app, title, o)
    n.SdkId = Sdk.Seq
    if Dbg.On then Dbg.Log("sdk", app .. " notify " .. n.SdkLevel .. " \"" .. title .. "\"" .. (Sdk.Apps[app] == nil and " (waiting for permission)" or "")) end
    if Sdk.Apps[app] == nil then
        local p = Sdk.Pending[app] or {}
        if #p < 3 then p[#p + 1] = n end
        Sdk.Pending[app] = p
        return Sdk.Seq
    end
    Sdk.Deliver(n)
    return Sdk.Seq
end

function Sdk.Notify(o, a2, a3, a4)
    if type(o) == "string" then
        o = { app = o, title = a2, icon = a3, duration = a4 }
    end
    if type(o) ~= "table" then return nil, "Notify expects a table" end
    if not Sdk.Ready then
        if #Sdk.Early < 20 then Sdk.Early[#Sdk.Early + 1] = o end
        return 0
    end
    return Sdk.Post(o, false)
end

function Sdk.Unask(app)
    for i = #Sdk.Asks, 1, -1 do
        if Sdk.Asks[i] == app then table.remove(Sdk.Asks, i) end
    end
    Sdk.Pending[app] = nil
end

function Sdk.Ask(app)
    if Sdk.Muted[app] then return false end
    for _, a in ipairs(Sdk.Asks) do
        if a == app then return true end
    end
    if #Sdk.Asks >= 6 then return false end
    Sdk.Asks[#Sdk.Asks + 1] = app
    return true
end

function Sdk.QueueFull(app)
    local cur = NotificationQueue.Active
    if cur and cur.SdkApp == app then return false end
    local n = 0
    for _, it in ipairs(NotificationQueue.List) do
        if it.SdkApp then n = n + 1 end
    end
    return n >= 6
end

function Sdk.Answer(allow)
    local app = Sdk.Prompt
    if not app then return end
    Sdk.Prompt, Sdk.LastPrompt = nil, app
    local p = Sdk.Pending[app]
    Sdk.Unask(app)
    Sdk.Apps[app] = allow
    if Dbg.On then Dbg.Log("sdk", app .. " permission " .. (allow and "allowed" or "denied")) end
    Sdk.MenuDirty = true
    SaveAllConfig()
    if allow then
        for _, n in ipairs(p or {}) do Sdk.Deliver(n) end
    else
        Sdk.EndApp(app, "denied")
    end
end

function Sdk.AskInGame(inCombat, now)
    if #Sdk.Asks == 0 or inCombat or HUDCustomizer.IsOpen then return false end
    if NotificationQueue.Active and not IsNotifDeferred(NotificationQueue.Active) then return false end
    if StateMachine.TargetState == StateMachine.States.SHEET and Sheet.Kind == "sdk_perm" and Sdk.Prompt and not Sdk.AskHidden[Sdk.Prompt] then
        if now - (Sdk.AskAt[Sdk.Prompt] or now) > 12 then
            Sdk.AskHidden[Sdk.Prompt] = true
            return false
        end
        return true
    end
    for _, app in ipairs(Sdk.Asks) do
        if not Sdk.AskHidden[app] then
            Sdk.Prompt = app
            Sdk.AskAt[app] = now
            return true
        end
    end
    return false
end

function Sdk.Reset()
    Sdk.MenuDirty = true
    Sdk.Focus = {}
    Sdk.Sound = {}
    Sdk.Apps = {}
    Sdk.Muted = {}
    Sdk.Strikes = {}
    Sdk.AskHidden = {}
    SaveAllConfig()
end

function Sdk.SaveLine()
    local parts = {}
    for app, v in pairs(Sdk.Apps) do
        parts[#parts + 1] = app .. ":" .. (v and "1" or "0")
    end
    if #parts == 0 then return nil end
    table.sort(parts)
    return table.concat(parts, "|")
end

function Sdk.FocusLine()
    local parts = {}
    for app, v in pairs(Sdk.Focus) do
        if v then parts[#parts + 1] = app end
    end
    if #parts == 0 then return nil end
    table.sort(parts)
    return table.concat(parts, "|")
end

function Sdk.LoadLine(s)
    for pair in string.gmatch(s .. "|", "([^|]*)|") do
        local app, v = string.match(pair, "^(.+):([01])$")
        if app then Sdk.Apps[app] = v == "1" end
    end
    Sdk.MenuDirty = true
end

function Sdk.SoundLine()
    local parts = {}
    for app, v in pairs(Sdk.Sound) do
        if v == false then parts[#parts + 1] = app end
    end
    if #parts == 0 then return nil end
    table.sort(parts)
    return table.concat(parts, "|")
end

function Sdk.LoadSound(s)
    for app in string.gmatch(s .. "|", "([^|]*)|") do
        if app ~= "" then Sdk.Sound[app] = false end
    end
end

function Sdk.LoadFocus(s)
    for app in string.gmatch(s .. "|", "([^|]*)|") do
        if app ~= "" then Sdk.Focus[app] = true end
    end
end

function Sdk.InitMenu(page)
    local g = page:Create("di_group_sdk", Enum.GroupSide.Right)
    Sdk.NoneLabel = g:Label("di_sdk_none", "\u{f121}")
    for i = 1, 12 do
        local slot = {}
        slot.sw = g:Switch("sdk_slot_" .. i, false, "\u{f121}")
        slot.gear = slot.sw:Gear("sdk_gear_" .. i)
        slot.focus = slot.gear:Switch("sdk_focus_" .. i, false, "\u{f186}")
        slot.sound = slot.gear:Switch("sdk_sound_" .. i, true, "\u{f028}")
        slot.sw:ToolTip("di_sdk_slot_tip")
        slot.focus:ToolTip("di_sdk_focus_tip")
        slot.sound:ToolTip("di_alert_sound_tip")
        slot.sound:SetCallback(function(w)
            if Sdk.Syncing or not slot.app then return end
            if w:Get() == true then
                Sdk.Sound[slot.app] = nil
            else
                Sdk.Sound[slot.app] = false
            end
            SaveAllConfig()
        end)
        slot.sw:SetCallback(function(w)
            if Sdk.Syncing or not slot.app then return end
            local on = w:Get() == true
            Sdk.Apps[slot.app] = on
            if not on then Sdk.EndApp(slot.app, "denied") end
            Sdk.Unask(slot.app)
            SaveAllConfig()
        end)
        slot.focus:SetCallback(function(w)
            if Sdk.Syncing or not slot.app then return end
            Sdk.Focus[slot.app] = w:Get() == true or nil
            SaveAllConfig()
        end)
        pcall(slot.sw.Visible, slot.sw, false)
        Sdk.Slots[i] = slot
    end
    Sdk.MenuDirty = true
end

function Sdk.MenuSync(now)
    if #Sdk.Slots == 0 then return end
    local open = Menu.Opened and Menu.Opened()
    if not Sdk.MenuDirty and not (open and now - Sdk.MenuAt > 1) then return end
    Sdk.MenuDirty = false
    Sdk.MenuAt = now
    local apps = {}
    for app in pairs(Sdk.Apps) do apps[#apps + 1] = app end
    table.sort(apps, function(a, b) return string.lower(a) < string.lower(b) end)
    Sdk.Syncing = true
    for i, slot in ipairs(Sdk.Slots) do
        local app = apps[i]
        slot.app = app
        if app then
            local label = string.gsub(app, "%.", " ")
            pcall(slot.sw.ForceLocalization, slot.sw, label)
            pcall(slot.gear.ForceLocalization, slot.gear, label)
            pcall(slot.focus.ForceLocalization, slot.focus, L("di_sdk_focus"))
            pcall(slot.sound.ForceLocalization, slot.sound, L("di_alert_sound"))
            if slot.sound:Get() ~= (Sdk.Sound[app] ~= false) then slot.sound:Set(Sdk.Sound[app] ~= false) end
            if slot.sw:Get() ~= (Sdk.Apps[app] == true) then slot.sw:Set(Sdk.Apps[app] == true) end
            if slot.focus:Get() ~= (Sdk.Focus[app] == true) then slot.focus:Set(Sdk.Focus[app] == true) end
        end
        pcall(slot.sw.Visible, slot.sw, app ~= nil)
    end
    if Sdk.NoneLabel then pcall(Sdk.NoneLabel.Visible, Sdk.NoneLabel, #apps == 0) end
    Sdk.Syncing = false
end

function Sdk.FaceID(o)
    o = type(o) == "table" and o or {}
    local now = os.clock()
    if now - (Sdk.FaceAt or -10) < 3 then return false end
    if not (UI and UI.Main.Enabled:Get()) or HUDCustomizer.IsOpen or Hello.Blocking() then return false end
    if Impl.FaceStart(o.result, Sdk.Num(o.scan, 0.4, 3)) then
        Sdk.FaceAt = now
        return true
    end
    return false
end

function Sdk.PlaySound(name, vol)
    if type(name) ~= "string" then return false end
    name = Sdk.Sounds[name] or name
    if not Sdk.SoundFiles[name] then return false end
    local now = os.clock()
    local w = Sdk.SoundWin
    if now - w.t > 1 then
        w.t, w.n = now, 0
    end
    w.n = w.n + 1
    if w.n > 25 then return false end
    HapticPlaySound(name, Sdk.Num(vol, 0.05, 1) or 0.5)
    return true
end

function Sdk.ActApply(a, o)
    if o.title ~= nil then a.title = Sdk.Text(o.title, 60) end
    if o.subtitle ~= nil then a.subtitle = Sdk.Text(o.subtitle, 80) end
    if o.trailing ~= nil then
        a.trailing = Sdk.Text(o.trailing, 12)
        if o.timer == nil then a.ends, a.timerLen = nil, nil end
    end
    if o.progress ~= nil then a.progress = Sdk.Num(o.progress, 0, 1) end
    if o.timer ~= nil then
        local t = Sdk.Num(o.timer, 0, 86400)
        a.ends = t and (os.clock() + t) or nil
        a.timerLen = t and math.max(1, t) or nil
    end
    if o.icon ~= nil then a.glyph, a.image = Sdk.Icon(o.icon) end
    if o.tint ~= nil then a.tint = Sdk.Tint(o.tint, a.app) end
    if o.onTap ~= nil then a.onTap = type(o.onTap) == "function" and o.onTap or nil end
    if o.onEnd ~= nil then a.onEnd = type(o.onEnd) == "function" and o.onEnd or nil end
    if o.staleAfter ~= nil then
        a.staleAfter = Sdk.Num(o.staleAfter, 5, 86400)
    end
    a.touched = os.clock()
end

function Sdk.Handle(a)
    local h = { id = a.id }
    h.Update = function(p1, p2)
        local o = p1 == h and p2 or p1
        if a.ended or a.endAt or type(o) ~= "table" then return false end
        Sdk.Guard(Sdk.ActApply, a, o)
        return true
    end
    h.End = function(p1, p2)
        local o = p1 == h and p2 or p1
        if a.ended then return end
        if type(o) == "table" then
            Sdk.Guard(Sdk.ActApply, a, o)
            local after = Sdk.Num(o.after, 0, 10)
            if after and after > 0 then
                a.endAt = os.clock() + after
                return
            end
        end
        Sdk.ActEnd(a)
    end
    h.IsActive = function()
        return not a.ended and not a.endAt
    end
    return h
end

function Sdk.ActStart(o)
    if type(o) ~= "table" then return nil, "Activity.Start expects a table" end
    local app = Sdk.AppName(o.app)
    if not app then
        Sdk.Warn(nil, "Activity.Start needs an app name")
        return nil, "app required"
    end
    if Sdk.Muted[app] then return nil, "muted" end
    if Sdk.Apps[app] == false then return nil, "not allowed" end
    if not Sdk.Known(app) then return nil, "too many apps" end
    for i = #Sdk.Acts, 1, -1 do
        if Sdk.Acts[i].app == app then Sdk.ActEnd(Sdk.Acts[i]) end
    end
    if #Sdk.Acts >= 3 then
        for _, other in ipairs(Sdk.Acts) do
            if Sdk.Apps[other.app] ~= true then
                Sdk.ActEnd(other)
                break
            end
        end
    end
    if #Sdk.Acts >= 3 then
        Sdk.Warn(app, "only 3 live activities can run at once")
        return nil, "too many activities"
    end
    Sdk.Seq = Sdk.Seq + 1
    local a = { id = Sdk.Seq, app = app, glyph = "bell", started = os.clock() }
    a.tint = Sdk.AppTint(app)
    Sdk.ActApply(a, o)
    Sdk.Acts[#Sdk.Acts + 1] = a
    if Dbg.On then Dbg.Log("sdk", app .. " activity started \"" .. tostring(a.title) .. "\"") end
    return Sdk.Handle(a)
end

function Sdk.ActEnd(a, reason)
    if not a or a.ended then return end
    a.ended = true
    if Dbg.On then Dbg.Log("sdk", a.app .. " activity ended (" .. tostring(reason or "by the script") .. ")") end
    for i = #Sdk.Acts, 1, -1 do
        if Sdk.Acts[i] == a then table.remove(Sdk.Acts, i) end
    end
    if reason and a.onEnd then Sdk.Call(a.app, a.onEnd, reason) end
end

function Sdk.EndApp(app, reason)
    local list = {}
    for _, a in ipairs(Sdk.Acts) do
        if a.app == app then list[#list + 1] = a end
    end
    for _, a in ipairs(list) do Sdk.ActEnd(a, reason) end
end

function Sdk.Dismiss(a)
    if not a or a.ended then return end
    HapticPlaySound("toast_dismiss", 0.45)
    Sdk.ActEnd(a, "dismissed")
end

function Sdk.Second()
    local first = Sdk.Current()
    for i = #Sdk.Acts, 1, -1 do
        local a = Sdk.Acts[i]
        if a ~= first and Sdk.Apps[a.app] == true and not Sdk.Muted[a.app] then return a end
    end
    return nil
end

function Sdk.Frac(a)
    if a.progress then return a.progress end
    if a.ends and a.timerLen then return math.max(0, math.min(1, (a.ends - os.clock()) / a.timerLen)) end
    return nil
end

function Sdk.Current()
    for i = #Sdk.Acts, 1, -1 do
        local a = Sdk.Acts[i]
        if Sdk.Apps[a.app] == true and not Sdk.Muted[a.app] then return a end
    end
    return nil
end

function Sdk.ShowActivity(inCombat)
    if inCombat or HUDCustomizer.IsOpen or not Sdk.Current() then return false end
    if NotificationQueue.Active then return false end
    return true
end

function Sdk.TapNotif(now)
    local n = NotificationQueue.Active
    if not n then return end
    if Sdk.ExpandedAt and Sdk.PressAt and Sdk.ExpandedAt >= Sdk.PressAt then return end
    local fn, app = n.OnTap, n.SdkApp
    if Sdk.Expanded and Sdk.ExpandK > 0.9 then
        for _, h in ipairs(Sdk.Hits) do
            if Pointer.x >= h.x1 and Pointer.x <= h.x2 and Pointer.y >= h.y1 and Pointer.y <= h.y2 then
                fn = h.fn
                if not fn then
                    Impl.DismissNotif(now)
                    return
                end
                break
            end
        end
    end
    if not fn then return end
    Haptic.Trigger(Haptic.Types.TAP_MEDIUM)
    Impl.DismissNotif(now)
    Sdk.Call(app, fn)
end

function Sdk.TapActivity(a)
    a = a or Sdk.Current()
    if a and a.onTap then
        Haptic.Trigger(Haptic.Types.TAP_MEDIUM)
        Sdk.Call(a.app, a.onTap)
    end
end

function Sdk.CanExpand()
    local n = NotificationQueue.Active
    return n ~= nil and n.SdkApp ~= nil and (n.Body ~= nil or n.Actions ~= nil) and StateMachine.TargetState == StateMachine.States.NOTIFICATION and not IsNotifDeferred(n)
end

function Sdk.Expand(now)
    Sdk.Expanded = true
    Sdk.ExpandedAt = now
    Sdk.ExpandedFor = NotificationQueue.Active
    Haptic.Silent(Haptic.Types.SNAP_EXPAND)
end

function Sdk.TickExpand(now)
    local dt = math.min(0.05, math.max(0.001, now - (Sdk.LastT > 0 and Sdk.LastT or now - 0.016)))
    Sdk.LastT = now
    local n = NotificationQueue.Active
    if Sdk.Expanded and (n ~= Sdk.ExpandedFor or StateMachine.TargetState ~= StateMachine.States.NOTIFICATION) then
        Sdk.Expanded = false
    end
    if Sdk.Expanded and n then
        NotificationQueue.StartTime = math.max(NotificationQueue.StartTime or now, now - math.max(0, (n.Duration or 4) - 1.5))
    end
    if not Sdk.Expanded then Sdk.Hits = {} end
    Sdk.ExpandK, Sdk.ExpandV = MotionEngine.Step(Sdk.ExpandK, Sdk.ExpandV, Sdk.Expanded and 1 or 0, dt / AnimScale(), "SNAPPY")
end

function Sdk.BodyLines(n, scale)
    n._lines = n._lines or {}
    local key = math.floor(scale * 100)
    if not n._lines[key] then
        local lines = {}
        if n.Body then
            local f, sz = TF("Subhead", scale)
            local maxW = (360 - 32) * scale
            lines = Impl.Wrap(f, sz, n.Body, maxW)
            if #lines > 3 then
                lines = { lines[1], lines[2], table.concat(lines, " ", 3) }
            end
            for i, ln in ipairs(lines) do lines[i] = TruncateToWidth(f, sz, ln, maxW) end
        end
        n._lines[key] = lines
    end
    return n._lines[key]
end

function Sdk.ExpandH(scale)
    local n = NotificationQueue.Active
    if not n then return Config.Dimensions.NotificationH end
    local h = 14 + 38 + 16
    local lines = Sdk.BodyLines(n, scale or 1)
    if #lines > 0 then h = h + 6 + #lines * 19 end
    if n.Actions then h = h + 12 + 34 end
    return h
end

function Sdk.RenderExpanded(layout, am, yOffset, n)
    Sdk.Hits = {}
    if am <= 0.01 then return end
    local s = layout.scale
    local C = Config.Colors
    local pad = math.floor(16 * s)
    local yOff = yOffset or 0
    local tint = n.AccentColor or C.Blue
    local isz = math.floor(38 * s)
    local ix = layout.x + pad
    local iy = math.floor(layout.y + 14 * s + yOff)
    local icx, icy = ix + isz / 2, iy + isz / 2
    local img = n.Icon and GetCachedImage(n.Icon) or nil
    if img then
        Impl.Img(img, Vec2(ix, iy), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), am), math.floor(isz / 2))
    else
        Render.FilledCircle(Vec2(icx, icy), isz / 2, FadeColor(tint, am), 0, 1.0, 32)
        Glyph(n.FallbackSvg or "bell", icx, icy, math.floor(isz * 0.54), FadeColor(Color(255, 255, 255, 255), am))
    end
    local fC, sC = TF("Caption", s)
    local fH, sH = TF("Headline", s)
    local ch = Render.TextSize(fC, sC, "Ag").y
    local hh = Render.TextSize(fH, sH, "Ag").y
    local tx = math.floor(ix + isz + 12 * s)
    local maxW = layout.x + layout.w - pad - tx
    local ty = math.floor(icy - (ch + hh) / 2)
    Render.Text(fC, sC, TruncateToWidth(fC, sC, n.Tag or "", maxW), Vec2(tx, ty), FadeColor(Impl.OnLight(tint), am))
    Render.Text(fH, sH, TruncateToWidth(fH, sH, n.Title or "", maxW), Vec2(tx, math.floor(ty + ch)), FadeColor(C.TextPrimary, am))
    local y = iy + isz + math.floor(6 * s)
    local lines = Sdk.BodyLines(n, s)
    if #lines > 0 then
        local fS, sS = TF("Subhead", s)
        local lh = math.floor(19 * s)
        y = y + math.floor(6 * s)
        for _, ln in ipairs(lines) do
            Render.Text(fS, sS, ln, Vec2(layout.x + pad, y), FadeColor(C.TextSecondary, am))
            y = y + lh
        end
    end
    if n.Actions then
        local bh = math.floor(34 * s)
        local by = math.floor(layout.y + layout.h - 16 * s - bh + yOff)
        local gap = math.floor(10 * s)
        local cnt = #n.Actions
        local bw = math.floor((layout.w - pad * 2 - gap * (cnt - 1)) / cnt)
        for i, ac in ipairs(n.Actions) do
            local bx = math.floor(layout.x + pad + (i - 1) * (bw + gap))
            local _, pk = Pointer.Button("sdk_ac_" .. i, bx, by, bx + bw, by + bh)
            local kx, ky = bw * 0.0175 * pk, bh * 0.0175 * pk
            local dim = am * (1 - 0.22 * pk)
            Render.FilledRect(Vec2(bx + kx, by + ky), Vec2(bx + bw - kx, by + bh - ky), FadeColor(C.FillSecondary, dim), (bh - ky * 2) / 2)
            local ts = Render.TextSize(fH, sH, ac.title)
            local label = TruncateToWidth(fH, sH, ac.title, bw - 16 * s)
            local lw = Render.TextSize(fH, sH, label).x
            Render.Text(fH, sH, label, Vec2(math.floor(bx + (bw - lw) / 2), math.floor(by + (bh - ts.y) / 2)), FadeColor(ac.destructive and C.Red or C.TextPrimary, dim))
            if am > 0.9 then
                Sdk.Hits[#Sdk.Hits + 1] = { x1 = bx, y1 = by, x2 = bx + bw, y2 = by + bh, fn = ac.fn }
            end
        end
    end
end

function Sdk.Drain()
    local q = DynamicIslandQueue
    if q == nil then return end
    if type(q) ~= "table" then error("queue is not a table") end
    local n = #q
    if type(n) ~= "number" or n <= 0 then
        if n ~= 0 then error("bad queue length") end
        return
    end
    DynamicIslandQueue = {}
    for i = 1, math.min(n, 20) do
        local it = q[i]
        if type(it) == "table" then Sdk.Guard(Sdk.Post, it, true) end
    end
end

Impl.Wg = { List = {}, ById = {}, Vis = {}, Hold = {}, Sig = nil, Fallback = false }

function Impl.WgCid(app, key)
    local function clean(v, n)
        v = string.gsub(string.lower(v), "[^%w]", "")
        return string.sub(v, 1, n)
    end
    local base = "sdk_" .. clean(app, 14) .. "_" .. clean(key, 14)
    return base
end

function Impl.WgActiveList()
    local W = Impl.Wg
    local out = {}
    for _, id in ipairs(HUDCustomizer.ActiveChips) do
        if not (W.Fallback and id == "clock") then out[#out + 1] = id end
    end
    for _, h in ipairs(W.Hold) do
        table.insert(out, math.min(h.at, #out + 1), h.id)
    end
    if #out == 0 then out[1] = "clock" end
    return out
end

function Impl.WgSync()
    local W = Impl.Wg
    local vis, sig = {}, {}
    for _, e in ipairs(W.List) do
        if Sdk.Apps[e.app] ~= false and not Sdk.Muted[e.app] then
            vis[e.cid] = e
            sig[#sig + 1] = e.cid
        end
    end
    W.Vis = vis
    local s = table.concat(sig, ",")
    if s ~= W.Sig then
        W.Sig = s
        local av = HUDCustomizer.AvailableChips
        for i = #av, 1, -1 do
            if av[i].sdk then table.remove(av, i) end
        end
        for _, e in ipairs(W.List) do
            if vis[e.cid] then av[#av + 1] = { id = e.cid, sdk = e } end
        end
        if HUDCustomizer.InspectedChip and string.sub(HUDCustomizer.InspectedChip, 1, 4) == "sdk_" and not vis[HUDCustomizer.InspectedChip] then
            HUDCustomizer.InspectedChip = nil
        end
    end
    local act = HUDCustomizer.ActiveChips
    for i = #act, 1, -1 do
        local id = act[i]
        if string.sub(id, 1, 4) == "sdk_" and not vis[id] then
            table.remove(act, i)
            table.insert(W.Hold, { id = id, at = i })
        end
    end
    if #W.Hold > 0 then
        table.sort(W.Hold, function(a, b) return a.at < b.at end)
        for k = #W.Hold, 1, -1 do
            local h = W.Hold[k]
            if vis[h.id] then
                table.remove(W.Hold, k)
                if W.Fallback then
                    for i = #act, 1, -1 do
                        if act[i] == "clock" then table.remove(act, i) end
                    end
                    W.Fallback = false
                end
                table.insert(act, math.min(h.at, #act + 1), h.id)
            end
        end
    end
    if #act == 0 then
        act[1] = "clock"
        W.Fallback = true
    end
end

function Impl.WgApply(e, o)
    if o.text ~= nil then e.text = Sdk.Str(o.text, 16) or "" end
    if o.title ~= nil then e.title = Sdk.Text(o.title, 24) or e.title end
    if o.icon ~= nil then e.glyph = (Sdk.Icon(o.icon)) end
    if o.tint ~= nil then e.tint = Sdk.Tint(o.tint, e.app) end
end

function Impl.WgRemove(e)
    local W = Impl.Wg
    if e.removed then return end
    e.removed = true
    for i = #W.List, 1, -1 do
        if W.List[i] == e then table.remove(W.List, i) end
    end
    if W.ById[e.cid] == e then W.ById[e.cid] = nil end
    if Dbg.On then Dbg.Log("sdk", e.app .. " widget removed \"" .. e.title .. "\"") end
end

function Impl.WgRegister(o)
    if type(o) ~= "table" then return nil, "Widget.Register expects a table" end
    local app = Sdk.AppName(o.app)
    if not app then
        Sdk.Warn(nil, "Widget.Register needs an app name")
        return nil, "app required"
    end
    if Sdk.Muted[app] then return nil, "muted" end
    if Sdk.Apps[app] == false then return nil, "not allowed" end
    if not Sdk.Known(app) then return nil, "too many apps" end
    local key = type(o.id) == "string" and o.id or (type(o.title) == "string" and o.title or nil)
    if not key or string.gsub(key, "[^%w]", "") == "" then
        Sdk.Warn(app, "Widget.Register needs an id")
        return nil, "id required"
    end
    local W = Impl.Wg
    local cid = Impl.WgCid(app, key)
    local old = W.ById[cid]
    if old then Impl.WgRemove(old) end
    local mine = 0
    for _, e in ipairs(W.List) do
        if e.app == app then mine = mine + 1 end
    end
    if mine >= 4 then
        Sdk.Warn(app, "only 4 widgets per script")
        return nil, "too many widgets"
    end
    if #W.List >= 12 then
        Sdk.Warn(app, "only 12 widgets from scripts at once")
        return nil, "too many widgets"
    end
    local e = { cid = cid, app = app, title = Sdk.Text(o.title, 24) or app, text = "", glyph = "bell", tint = Sdk.AppTint(app) }
    Impl.WgApply(e, o)
    W.List[#W.List + 1] = e
    W.ById[cid] = e
    if not HUDCustomizer.WidgetConfigs[cid] then
        HUDCustomizer.WidgetConfigs[cid] = { bold = false, colorMode = 1, format = 1, showIcon = true }
    end
    if Dbg.On then Dbg.Log("sdk", app .. " widget registered \"" .. e.title .. "\"") end
    local h = {}
    h.Set = function(p1, p2)
        local v = p1 == h and p2 or p1
        if e.removed then return false end
        e.text = Sdk.Str(v, 16) or ""
        return true
    end
    h.Update = function(p1, p2)
        local v = p1 == h and p2 or p1
        if e.removed or type(v) ~= "table" then return false end
        Sdk.Guard(Impl.WgApply, e, v)
        return true
    end
    h.Remove = function()
        Impl.WgRemove(e)
    end
    h.IsOnIsland = function()
        return not e.removed and Impl.IsChipInActiveList(cid)
    end
    return h
end

function Sdk.Tick(now)
    Impl.WgSync()
    Sdk.TickExpand(now)
    if not Sdk.Ready then return end
    if #Sdk.Early > 0 then
        local early = Sdk.Early
        Sdk.Early = {}
        for _, o in ipairs(early) do Sdk.Guard(Sdk.Post, o, true) end
    end
    if not pcall(Sdk.Drain) then
        DynamicIslandQueue = {}
        Sdk.Warn(nil, "DynamicIslandQueue was broken by another script, reset it")
    end
    if ReadIsland() ~= Sdk.Facade then
        PublishIsland(Sdk.Facade)
        Sdk.Warn(nil, "another script replaced DynamicIsland, restored it")
    end
    local acts = {}
    for i, a in ipairs(Sdk.Acts) do acts[i] = a end
    for _, a in ipairs(acts) do
        if not a.ended then
            if Sdk.Apps[a.app] == nil then Sdk.Ask(a.app) end
            if a.endAt and now >= a.endAt then
                Sdk.ActEnd(a)
            elseif a.staleAfter and now - (a.touched or now) > a.staleAfter then
                Sdk.ActEnd(a, "stale")
            elseif now - a.started > 14400 then
                Sdk.ActEnd(a, "expired")
            end
        end
    end
    Sdk.MenuSync(now)
end

function Sdk.DrawPill(layout, notif, used, yOff, aMul)
    local s = layout.scale
    local fB, sB = TF("Caption", s)
    fB = Config.Fonts.Semibold
    local txt = notif.Trailing
    local ts = Render.TextSize(fB, sB, txt)
    local h = math.floor(20 * s)
    local w = math.floor(math.max(40 * s, ts.x + 16 * s))
    local x2 = math.floor(layout.x + layout.w - 14 * s - used)
    local y = math.floor(layout.y + (layout.h - h) / 2 + yOff)
    Render.FilledRect(Vec2(x2 - w, y), Vec2(x2, y + h), FadeColor(notif.AccentColor or Config.Colors.Blue, aMul), h / 2)
    Render.Text(fB, sB, txt, Vec2(math.floor(x2 - w + (w - ts.x) / 2), math.floor(y + (h - ts.y) / 2)), FadeColor(Color(255, 255, 255, 255), aMul))
    return w + math.floor(8 * s)
end

function Sdk.Trailing(a)
    if a.ends then return FormatTime(math.ceil(math.max(0, a.ends - os.clock()))) end
    return a.trailing
end

function Sdk.Shown()
    local a = Sdk.Current()
    if a then Sdk.LastShown = a end
    return a or Sdk.LastShown
end

function Sdk.CompactW(scale)
    local a = Sdk.Shown()
    if not a then return 150 end
    if a.progress then return 230 end
    local txt = Sdk.Trailing(a)
    local tw = 0
    if txt then
        local fH, sH = TF("Headline", scale)
        tw = Odometer.Width(fH, sH, txt) / scale
    elseif a.title then
        local fS, sS = TF("Subhead", scale)
        tw = math.min(180, Render.TextSize(fS, sS, a.title).x / scale) - 18
    end
    return math.max(150, math.ceil((12 + 18 + 28 + tw + 14) / 4) * 4)
end

function Sdk.LargeH()
    local a = Sdk.Shown()
    if not a then return 64 end
    return 60 + (a.subtitle and 22 or 0) + (a.progress and 16 or 0)
end

function Sdk.Track(x1, x2, y, s, frac, col, am)
    local h = math.max(3, math.floor(4 * s))
    local r = math.floor(h / 2)
    Render.FilledRect(Vec2(x1, y), Vec2(x2, y + h), FadeColor(Config.Colors.Fill, am), r)
    local fw = math.floor((x2 - x1) * math.max(0, math.min(1, frac)))
    if fw > 0 then
        Render.FilledRect(Vec2(x1, y), Vec2(x1 + fw, y + h), FadeColor(col, am), r)
    end
end

function Sdk.RenderCompact(layout, alphaMul, yOffset)
    local a = Sdk.Shown()
    if not a then
        RenderModularIdlePill(layout, alphaMul, yOffset)
        return
    end
    local s = layout.scale
    local am = alphaMul or 1
    local cy = math.floor(layout.y + layout.h / 2 + (yOffset or 0) * s)
    local tint = Impl.OnLight(a.tint or Config.Colors.Blue)
    local isz = math.floor(18 * s)
    local ix = math.floor(layout.x + 12 * s)
    local img = a.image and GetCachedImage(a.image) or nil
    if img then
        Impl.Img(img, Vec2(ix, cy - math.floor(isz / 2)), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), am), math.floor(isz / 2))
    else
        Glyph(a.glyph or "bell", ix + isz / 2, cy, isz, FadeColor(tint, am))
    end
    local rightX = math.floor(layout.x + layout.w - 14 * s)
    local txt = Sdk.Trailing(a)
    if txt then
        local fH, sH = TF("Headline", s)
        local tw = Odometer.Width(fH, sH, txt)
        local th = Render.TextSize(fH, sH, "Ag").y
        rightX = math.floor(rightX - tw)
        Odometer.Text("sdk_trail", fH, sH, txt, Vec2(rightX, math.floor(cy - th / 2)), FadeColor(tint, am))
    elseif a.title and not a.progress then
        local fS, sS = TF("Subhead", s)
        local tx = math.floor(ix + isz + 10 * s)
        local th = Render.TextSize(fS, sS, "Ag").y
        Render.Text(fS, sS, TruncateToWidth(fS, sS, a.title, rightX - tx), Vec2(tx, math.floor(cy - th / 2)), FadeColor(Config.Colors.TextPrimary, am))
    end
    if a.progress then
        local x1 = math.floor(ix + isz + 10 * s)
        local x2 = math.floor(rightX - 10 * s)
        if x2 - x1 > 20 * s then
            Sdk.Track(x1, x2, math.floor(cy - math.max(3, math.floor(4 * s)) / 2), s, a.progress, tint, am)
        end
    end
end

function Sdk.RenderLarge(layout, alphaMul, yOffset)
    local a = Sdk.Shown()
    if not a then
        RenderLargeIdle(layout, alphaMul, yOffset)
        return
    end
    local s = layout.scale
    local am = alphaMul or 1
    local C = Config.Colors
    local tint = a.tint or C.Blue
    local pad = math.floor(16 * s)
    local isz = math.floor(30 * s)
    local ix = layout.x + pad
    local iy = math.floor(layout.y + 14 * s + (yOffset or 0) * s)
    local icx, icy = ix + isz / 2, iy + isz / 2
    local img = a.image and GetCachedImage(a.image) or nil
    if img then
        Impl.Img(img, Vec2(ix, iy), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), am), math.floor(isz / 2))
    else
        Render.FilledCircle(Vec2(icx, icy), isz / 2, FadeColor(tint, am), 0, 1.0, 28)
        Glyph(a.glyph or "bell", icx, icy, math.floor(isz * 0.56), FadeColor(Color(255, 255, 255, 255), am))
    end
    local right = layout.x + layout.w - pad
    local trail = Sdk.Trailing(a)
    if trail then
        local fT, sT = TF("Title", s)
        local tw = Odometer.Width(fT, sT, trail)
        local th = Render.TextSize(fT, sT, "Ag").y
        Odometer.Draw(fT, sT, trail, Vec2(math.floor(right - tw), math.floor(icy - th / 2)), FadeColor(Impl.OnLight(tint), am))
        right = right - tw - 10 * s
    end
    local fC, sC = TF("Caption", s)
    local fH, sH = TF("Headline", s)
    local ch = Render.TextSize(fC, sC, "Ag").y
    local hh = Render.TextSize(fH, sH, "Ag").y
    local tx = math.floor(ix + isz + 10 * s)
    local ty = math.floor(icy - (ch + hh) / 2)
    Render.Text(fC, sC, TruncateToWidth(fC, sC, a.app, right - tx), Vec2(tx, ty), FadeColor(C.TextSecondary, am))
    Render.Text(fH, sH, TruncateToWidth(fH, sH, a.title or a.app, right - tx), Vec2(tx, math.floor(ty + ch)), FadeColor(C.TextPrimary, am))
    local y = math.floor(iy + isz + 10 * s)
    if a.subtitle then
        local fS, sS = TF("Subhead", s)
        Render.Text(fS, sS, TruncateToWidth(fS, sS, a.subtitle, layout.w - pad * 2), Vec2(layout.x + pad, y), FadeColor(C.TextSecondary, am))
        y = y + math.floor(22 * s)
    end
    if a.progress then
        Sdk.Track(layout.x + pad, layout.x + layout.w - pad, y + math.floor(2 * s), s, a.progress, Impl.OnLight(tint), am)
    end
end

do
    local function ReadOnly()
        error("DynamicIsland is read-only", 2)
    end
    local activity = setmetatable({}, {
        __index = {
            Start = function(o) return Sdk.Guard(Sdk.ActStart, o) end
        },
        __newindex = ReadOnly,
        __metatable = false
    })
    local widget = setmetatable({}, {
        __index = {
            Register = function(o) return Sdk.Guard(Impl.WgRegister, o) end
        },
        __newindex = ReadOnly,
        __metatable = false
    })
    Sdk.Facade = setmetatable({}, {
        __index = {
            api = Sdk.API,
            version = SCRIPT_VERSION,
            Notify = function(...) return Sdk.Guard(Sdk.Notify, ...) end,
            PlaySound = function(name, vol) return Sdk.Guard(Sdk.PlaySound, name, vol) end,
            FaceID = function(o) return Sdk.Guard(Sdk.FaceID, o) end,
            Has = function(feature) return Sdk.Features[feature] == true end,
            Activity = activity,
            Widget = widget,
            IsAllowed = function(app)
                local name = Sdk.AppName(app)
                return name ~= nil and Sdk.Apps[name] == true
            end,
            Glyphs = function()
                local list = {}
                for name in pairs(VectorIcons) do list[#list + 1] = name end
                table.sort(list)
                return list
            end
        },
        __newindex = ReadOnly,
        __metatable = false
    })
end

Dbg.File = "dynamic_island_debug.log"
Dbg.OldFile = "dynamic_island_debug.old.log"
Dbg.Buf = {}
Dbg.Bytes = 0
Dbg.Cap = 3 * 1024 * 1024
Dbg.Last = {}
Dbg.SettingsLast = nil
Dbg.SettingsAt = 0
Dbg.FlushAt = 0
Dbg.PerfAt = 0
Dbg.SpikeAt = 0
Dbg.SpikeMs = 4
Dbg.Samples = { OnFrame = {}, OnUpdateEx = {} }
Dbg.Errors = {}

function Dbg.Dir()
    local dir = "C:/Umbrella/"
    if Engine and Engine.GetCheatDirectory then
        local ok, cd = pcall(Engine.GetCheatDirectory)
        if ok and type(cd) == "string" and cd ~= "" then dir = cd end
    end
    if not string.find(dir, "[/\\]$") then dir = dir .. "/" end
    return dir .. "scripts/"
end

function Dbg.StateName()
    if not Dbg.Names then
        Dbg.Names = {}
        for k, v in pairs(StateMachine.States) do Dbg.Names[v] = k end
    end
    return Dbg.Names[StateMachine.TargetState] or tostring(StateMachine.TargetState)
end

function Dbg.GameClock()
    if not (Engine.IsInGame and Engine.IsInGame()) then return "menu" end
    local ok, t = pcall(GameRules.GetDOTATime, true, true)
    if not ok or type(t) ~= "number" or t ~= t then return "game" end
    local s = math.floor(math.abs(t))
    return string.format("%s%d:%02d", t < 0 and "-" or "", math.floor(s / 60), s % 60)
end

function Dbg.Stamp()
    local c = os.clock()
    return string.format("%s +%.3f | %s | %s", os.date("%H:%M:%S"), c - (Dbg.T0 or c), Dbg.GameClock(), Dbg.StateName())
end

function Dbg.Log(cat, msg, urgent)
    if not Dbg.On then return end
    if Dbg.Bytes > Dbg.Cap and cat ~= "error" then
        if not Dbg.CapHit then
            Dbg.CapHit = true
            Dbg.Buf[#Dbg.Buf + 1] = Dbg.Stamp() .. " | debug: log is over 3 MB, only errors from now on"
        end
        return
    end
    local ok, line = pcall(function() return Dbg.Stamp() .. " | " .. cat .. ": " .. tostring(msg) end)
    if not ok then return end
    Dbg.Buf[#Dbg.Buf + 1] = line
    Dbg.Bytes = Dbg.Bytes + #line + 1
    if urgent then Dbg.Flush() end
end

function Dbg.Flush()
    if #Dbg.Buf == 0 or not Dbg.Path then return end
    local text = table.concat(Dbg.Buf, "\n") .. "\n"
    Dbg.Buf = {}
    local f = Impl.OpenFile(Dbg.Path, "a")
    if not f then return end
    f:write(text)
    f:close()
end

function Dbg.Val(v)
    local t = type(v)
    if t == "number" then
        if v ~= v then return "nan" end
        if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%d", v) end
        return string.format("%.3f", v)
    end
    if t == "boolean" then return tostring(v) end
    if t == "string" then return '"' .. string.gsub(v, "[%c]", " ") .. '"' end
    if t == "nil" then return "nil" end
    local ok, r, g, b, a = pcall(function() return v.r, v.g, v.b, v.a end)
    if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
        return string.format("#%02X%02X%02X%02X", math.floor(r), math.floor(g), math.floor(b), math.floor(tonumber(a) or 255))
    end
    if t == "table" then
        local parts = {}
        for k, x in pairs(v) do
            if #parts >= 12 then
                parts[#parts + 1] = "..."
                break
            end
            local tx = type(x)
            if tx ~= "function" and tx ~= "table" and tx ~= "userdata" then parts[#parts + 1] = tostring(k) .. "=" .. tostring(x) end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return t
end

function Dbg.Settings()
    local out, order = {}, {}
    local function walk(t, path, depth)
        if depth > 3 then return end
        local keys = {}
        for k in pairs(t) do
            if type(k) == "string" then keys[#keys + 1] = k end
        end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local v = t[k]
            local p = path == "" and k or (path .. "." .. k)
            local okGet, getter = pcall(function() return v.Get end)
            if okGet and type(getter) == "function" then
                local ok, val = pcall(getter, v)
                if ok and val ~= nil and type(val) ~= "function" then
                    out[p] = Dbg.Val(val)
                    order[#order + 1] = p
                end
            elseif type(v) == "table" then
                walk(v, p, depth + 1)
            end
        end
    end
    if UI then walk(UI, "", 0) end
    return out, order
end

function Dbg.ReadConfig()
    for _, path in ipairs(Impl.ConfigSavePaths) do
        local f = Impl.OpenFile(path, "r")
        if f then
            local text = f:read("a") or ""
            f:close()
            local lines = {}
            for line in string.gmatch(text, "[^\r\n]+") do lines[#lines + 1] = line end
            return table.concat(lines, " ; ")
        end
    end
    return "not found"
end

Dbg.Watches = {
    { "state", function() return Dbg.StateName() end },
    { "in game", function() return Engine.IsInGame and Engine.IsInGame() or false end },
    { "umbrella menu open", function() return Menu.Opened and Menu.Opened() or false end },
    { "widget editor", function() return HUDCustomizer.IsOpen end },
    { "game paused", function() return PauseTracker.IsPaused end },
    { "fight", function() return FightTracker.Active end },
    { "focus", function() return Focus.Active end },
    { "bridge", function() return Sheet.BridgeOnline() and ("online v" .. tostring(BridgeStatus.Version)) or (Impl.BridgeRefused() and "offline" or "answers held back by umbrella") end },
    { "bridge media sessions", function() return BridgeStatus.MediaSessions end },
    { "media", function() return IsMediaActive() and (MediaData.IsPlaying and "playing" or "paused") or "none" end },
    { "track", function() return MediaData.HasReceivedData and (MediaData.Artist .. " - " .. MediaData.Title .. " [" .. tostring(MediaData.App) .. "]") or "none" end },
    { "notification", function()
        local n = NotificationQueue.Active
        return n and (tostring(n.Type) .. " \"" .. tostring(n.Tag) .. " / " .. tostring(n.Title) .. "\" prio " .. tostring(n.Priority) .. " for " .. tostring(n.Duration) .. "s") or "none"
    end },
    { "queued notifications", function() return #NotificationQueue.List end },
    { "side bubble", function() return Satellite.Right.kind or "none" end },
    { "sheet", function() return StateMachine.TargetState == StateMachine.States.SHEET and tostring(Sheet.Kind) or "none" end },
    { "update", function() return Sheet.Upd.State end },
    { "fonts install", function() return Sheet.Fonts.State end },
    { "hello", function() return Hello.Phase or "none" end },
    { "setup step", function() return Setup.Visible() and tostring(Setup.Step) or "closed" end },
    { "drag", function() return DragState.IsDragging end },
    { "position", function() return DragState.IsDragging and "dragging" or (tostring(math.floor(DragState.CustomX or -1)) .. "," .. tostring(math.floor(DragState.CustomY or -1))) end },
    { "expanded notification", function() return Sdk.Expanded end },
    { "activity", function()
        local a = Sdk.Current()
        return a and (a.app .. " \"" .. tostring(a.title) .. "\"") or "none"
    end },
    { "permission prompt", function() return Sdk.Prompt or "none" end },
    { "hero", function() return HeroData.HeroName or "none" end },
    { "disabled modules", function()
        local list = {}
        for k in pairs(Fuse.Off) do list[#list + 1] = k end
        table.sort(list)
        return #list > 0 and table.concat(list, ",") or "none"
    end }
}

function Dbg.Check(report)
    local initial = {}
    for _, w in ipairs(Dbg.Watches) do
        local ok, v = pcall(w[2])
        v = ok and Dbg.Val(v) or "error"
        local old = Dbg.Last[w[1]]
        if report then
            initial[#initial + 1] = w[1] .. "=" .. v
        elseif old ~= v then
            Dbg.Log("change", w[1] .. ": " .. tostring(old) .. " -> " .. v)
        end
        Dbg.Last[w[1]] = v
    end
    return initial
end

function Dbg.Passport(reason)
    local scr = Render.ScreenSize()
    Dbg.Log("session", string.format("Dynamic Island %s, logging started (%s)", SCRIPT_VERSION, reason))
    Dbg.Log("session", string.format("screen %dx%d, scale %s, language sample \"%s\", glass %s", scr.x, scr.y, Dbg.Val(UI and UI.Main.Scale:Get()), L("di_nc_clear"), tostring(IsPureGlass())))
    Dbg.Log("session", string.format("bridge %s, version %s, latest %s, fonts ok %s, sessions %s", Sheet.BridgeOnline() and "online" or "offline", tostring(BridgeStatus.Version), tostring(BridgeStatus.Latest), tostring(BridgeStatus.FontsOk), tostring(BridgeStatus.MediaSessions)))
    Dbg.Log("session", "fonts: regular " .. tostring(Config.Fonts.Regular) .. ", semibold " .. tostring(Config.Fonts.Semibold) .. ", display " .. tostring(Config.Fonts.Display))
    Dbg.Log("session", "debug.traceback " .. (Dbg.TB and "available" or "missing") .. ", chronos " .. (Perf.Now ~= os.clock and "available" or "missing"))
    Dbg.Log("session", "config: " .. Dbg.ReadConfig())
    local set, order = Dbg.Settings()
    Dbg.SettingsLast = set
    local line = {}
    for _, p in ipairs(order) do
        line[#line + 1] = p .. "=" .. set[p]
        if #line == 10 then
            Dbg.Log("settings", table.concat(line, "  "))
            line = {}
        end
    end
    if #line > 0 then Dbg.Log("settings", table.concat(line, "  ")) end
    local apps = {}
    for app, v in pairs(Sdk.Apps) do apps[#apps + 1] = app .. (v and ":allowed" or ":denied") .. (Sdk.Focus[app] and "+focus" or "") .. (Sdk.Sound[app] == false and "-sound" or "") end
    table.sort(apps)
    Dbg.Log("session", "sdk scripts: " .. (#apps > 0 and table.concat(apps, ", ") or "none") .. ", activities " .. #Sdk.Acts)
    Dbg.Log("session", "now: " .. table.concat(Dbg.Check(true), "  "))
    if Sheet.BridgeOnline() then Dbg.AudioDiag("session start") end
end

function Dbg.Start(reason)
    if Dbg.On then return end
    local dir = Dbg.Dir()
    Dbg.Path = dir .. Dbg.File
    Dbg.T0 = Dbg.T0 or os.clock()
    local stamp = Hello.Stamp()
    local same, size = false, 0
    local f = Impl.OpenFile(Dbg.Path, "r")
    if f then
        local first = f:read("l") or ""
        local prev = tonumber(string.match(first, "session (%-?%d+)"))
        same = prev ~= nil and math.abs(prev - stamp) <= 8
        if same then
            size = f:seek("end") or 0
        else
            f:seek("set")
            local all = f:read("a") or ""
            local o = Impl.OpenFile(dir .. Dbg.OldFile, "w")
            if o then
                o:write(all)
                o:close()
            end
        end
        f:close()
    end
    if not same then
        local w = Impl.OpenFile(Dbg.Path, "w")
        if w then
            w:write("Dynamic Island debug log, session " .. tostring(stamp) .. "\n")
            w:close()
        end
    end
    Dbg.On = true
    Dbg.Bytes = size
    Dbg.CapHit = false
    Dbg.Samples = { OnFrame = {}, OnUpdateEx = {} }
    Dbg.PerfAt = os.clock()
    if same then Dbg.Log("session", "---- script reloaded ----") end
    local ok, err = pcall(Dbg.Passport, reason)
    if not ok then Dbg.Log("error", "passport failed: " .. tostring(err)) end
    Dbg.Flush()
end

function Dbg.Stop()
    if not Dbg.On then return end
    Dbg.Log("session", "logging stopped")
    Dbg.Flush()
    Dbg.On = false
end

function Dbg.Trace(e)
    local msg = Sdk.S(e)
    if Dbg.TB then
        local ok, tb = pcall(Dbg.TB, msg, 3)
        if ok and type(tb) == "string" then return tb end
    end
    return msg
end

function Dbg.Error(name, err)
    local c = (Dbg.Errors[name] or 0) + 1
    Dbg.Errors[name] = c
    if c > 5 then return end
    local text = string.gsub(Sdk.S(err), "\n", "\n    ")
    Dbg.Log("error", name .. (c == 5 and " (further errors from this part are not logged)" or "") .. ": " .. text)
    if c == 1 then
        Dbg.Log("error", "context: " .. table.concat(Dbg.Check(true), "  "))
    end
    Dbg.Flush()
end

function Dbg.PerfAdd(name, dt)
    local list = Dbg.Samples[name]
    if not list then return end
    if #list < 5000 then list[#list + 1] = dt end
    local ms = dt * 1000
    local now = os.clock()
    if ms > Dbg.SpikeMs and now - Dbg.SpikeAt > 1 then
        Dbg.SpikeAt = now
        Dbg.Log("perf", string.format("slow %s: %.2f ms", name, ms))
    end
end

function Dbg.PerfSummary()
    local parts = {}
    for _, name in ipairs({ "OnFrame", "OnUpdateEx" }) do
        local list = Dbg.Samples[name]
        if #list > 0 then
            local sorted = {}
            local sum = 0
            for i, v in ipairs(list) do
                sorted[i] = v
                sum = sum + v
            end
            table.sort(sorted)
            local p95 = sorted[math.max(1, math.floor(#sorted * 0.95))]
            parts[#parts + 1] = string.format("%s avg %.3f ms, p95 %.3f, max %.3f, %d calls", name, sum / #list * 1000, p95 * 1000, sorted[#sorted] * 1000, #list)
        end
    end
    Dbg.Samples = { OnFrame = {}, OnUpdateEx = {} }
    if #parts > 0 then Dbg.Log("perf", table.concat(parts, " | ")) end
end

function Dbg.Tick()
    if not Dbg.On then return end
    local now = os.clock()
    Dbg.Check(false)
    if now - Dbg.SettingsAt > 1 then
        Dbg.SettingsAt = now
        local set = Dbg.Settings()
        local last = Dbg.SettingsLast or {}
        for p, v in pairs(set) do
            if last[p] ~= nil and last[p] ~= v then Dbg.Log("setting", p .. ": " .. last[p] .. " -> " .. v) end
        end
        Dbg.SettingsLast = set
    end
    if now - Dbg.PerfAt > 30 then
        Dbg.PerfAt = now
        Dbg.PerfSummary()
    end
    if Dbg.Vol and now - Dbg.Vol.at > 0.8 then Dbg.VolumeDone() end
    if now - Dbg.FlushAt > 1 then
        Dbg.FlushAt = now
        Dbg.Flush()
    end
end

function Dbg.MediaSent(base, cmd)
    if base ~= "volup" and base ~= "voldown" then
        Dbg.Log("media", "sent " .. cmd)
        return
    end
    local v = Dbg.Vol
    if not v then
        local bump = string.find(cmd, "bump=1", 1, true) ~= nil
        v = { up = 0, down = 0, limit = 0, replies = 0, failed = 0, from = bump and VolumeState.Target or math.max(0, math.min(100, VolumeState.Target + (base == "volup" and -4 or 4))) }
        Dbg.Vol = v
    end
    if base == "volup" then v.up = v.up + 1 else v.down = v.down + 1 end
    if string.find(cmd, "bump=1", 1, true) then v.limit = v.limit + 1 end
    v.at = os.clock()
end

function Dbg.MediaReply(base, res, sentAt)
    local body = res and res.response or ""
    local ms = math.floor((os.clock() - sentAt) * 1000)
    local vol = tonumber(string.match(body, '"volume"%s*:%s*(%-?%d+)'))
    local target = string.match(body, '"target"%s*:%s*"([^"]*)"')
    if base == "volup" or base == "voldown" then
        local v = Dbg.Vol
        if not v then return end
        if body == "" then
            v.failed = v.failed + 1
            v.err = tostring(res and res.error_code) .. " " .. tostring(res and res.error_message)
            return
        end
        v.replies = v.replies + 1
        if vol then
            v.first = v.first or vol
            v.last = vol
        end
        v.target = target or v.target
        return
    end
    if body == "" then
        Dbg.Log("media", string.format("%s got no answer after %d ms (code %s, %s)", base, ms, tostring(res and res.code), tostring(res and res.error_message)))
    else
        Dbg.Log("media", string.format("%s answered in %d ms: %s", base, ms, string.sub(string.gsub(body, "[%c]", " "), 1, 160)))
    end
end

function Dbg.VolumeDone()
    local v = Dbg.Vol
    Dbg.Vol = nil
    local function pct(n) return n and (n < 0 and "unknown" or (tostring(n) .. "%")) or "no answer" end
    Dbg.Log("media", string.format("volume wheel: %d up, %d down%s, island %s -> %s, player %s -> %s, %d answers%s, changed %s",
        v.up, v.down, v.limit > 0 and (", " .. v.limit .. " at the limit") or "",
        pct(math.floor(v.from + 0.5)), pct(math.floor(VolumeState.Target + 0.5)), pct(v.first), pct(v.last),
        v.replies, v.failed > 0 and (", " .. v.failed .. " failed (" .. tostring(v.err) .. ")") or "",
        v.target or "nothing (this bridge does not report it)"))
    if (v.last == nil or v.last < 0 or (v.target and string.find(v.target, "^no audio"))) and not Dbg.AudioDiagDone then
        Dbg.AudioDiagDone = true
        Dbg.AudioDiag("the volume did not reach the player")
    end
end

function Dbg.AudioDiag(why)
    pcall(Impl.HttpRequest, "GET", "http://127.0.0.1:45455/diag/audio", {}, function(res)
        local body = res and res.response or ""
        if body == "" or not string.find(body, '"sessions"', 1, true) then
            Dbg.Log("media", "audio sessions (" .. why .. "): this bridge can not list them, update it")
            return
        end
        local app = string.match(body, '"app"%s*:%s*"([^"]*)"') or "?"
        local fam = string.match(body, '"family"%s*:%s*"([^"]*)"') or "?"
        local list = string.match(body, '"sessions"%s*:%s*"([^"]*)"') or "?"
        Dbg.Log("media", "audio sessions (" .. why .. "): player " .. app .. " looks like \"" .. fam .. "\", windows mixer has: " .. list)
    end, "di_diag_audio")
end

function Dbg.Dump(name, t, depth)
    if type(t) ~= "table" then
        Dbg.Log("snapshot", name .. " = " .. Dbg.Val(t))
        return
    end
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local scalars, nested = {}, {}
    for _, k in ipairs(keys) do
        local v = t[k]
        local tv = type(v)
        if tv == "table" and (depth or 0) > 0 then
            local okc = pcall(function() return v.r end)
            if okc and v.r and v.g then
                scalars[#scalars + 1] = tostring(k) .. "=" .. Dbg.Val(v)
            else
                nested[#nested + 1] = k
            end
        elseif tv ~= "function" then
            scalars[#scalars + 1] = tostring(k) .. "=" .. Dbg.Val(v)
        end
        if #scalars >= 80 then break end
    end
    Dbg.Log("snapshot", name .. ": " .. table.concat(scalars, "  "))
    for _, k in ipairs(nested) do Dbg.Dump(name .. "." .. tostring(k), t[k], (depth or 0) - 1) end
end

function Dbg.Snapshot()
    if not Dbg.On then
        if UI and UI.Main.Debug then UI.Main.Debug:Set(true) end
        Dbg.Start("snapshot button")
    end
    Dbg.Log("snapshot", "-------- snapshot --------")
    local l = GetIslandLayout()
    Dbg.Log("snapshot", string.format("layout x %d y %d w %d h %d r %.1f scale %.2f", l.x, l.y, l.w, l.h, l.r or 0, l.scale))
    Dbg.Dump("state", { Current = Dbg.Names and Dbg.Names[StateMachine.Current], Target = Dbg.StateName(), Previous = Dbg.Names and Dbg.Names[StateMachine.PreviousState], Transition = StateMachine.Transition.Active, Progress = StateMachine.Transition.Progress, Ghosts = #StateMachine.Ghosts })
    Dbg.Dump("target size", { W = Config.Dimensions.CompactTargetW, H = Config.Dimensions.CompactTargetH, R = Config.Dimensions.CompactTargetR })
    Dbg.Dump("notification", NotificationQueue.Active or { Active = "none" })
    for i, n in ipairs(NotificationQueue.List) do Dbg.Log("snapshot", "queued " .. i .. ": " .. tostring(n.Type) .. " \"" .. tostring(n.Title) .. "\" prio " .. tostring(n.Priority)) end
    Dbg.Log("snapshot", "notification center items " .. #NotifCenter.Items)
    Dbg.Dump("media", { Playing = MediaData.IsPlaying, Title = MediaData.Title, Artist = MediaData.Artist, App = MediaData.App, Pos = MediaData.PosSmooth, Duration = MediaData.Duration, HasCover = MediaData.HasCover, Liked = MediaData.IsLiked, Received = MediaData.HasReceivedData, Level = MediaData.Level })
    Dbg.Dump("bridge", BridgeStatus)
    Dbg.Dump("focus", { Active = Focus.Active, Until = Focus.Until, Suppressed = Focus.Suppressed, Mode = Focus.Mode })
    Dbg.Dump("drag", DragState)
    Dbg.Dump("editor", { Open = HUDCustomizer.IsOpen, Chips = HUDCustomizer.ActiveChips, Inspected = HUDCustomizer.InspectedChip })
    Dbg.Dump("fight", { Active = FightTracker.Active, Allies = FightTracker.AllyCount, Enemies = FightTracker.EnemyCount, Landmark = FightTracker.Landmark })
    Dbg.Dump("courier", { Delivering = CourierTracker.Delivering, Delivered = CourierTracker.Delivered, Progress = CourierTracker.Progress, ETA = CourierTracker.ETA })
    Dbg.Dump("pause", { Paused = PauseTracker.IsPaused })
    Dbg.Dump("hello", { Phase = tostring(Hello.Phase), SetupDone = Hello.SetupDone == true, SetupStep = tostring(Setup.Step) })
    Dbg.Dump("sheet", { Kind = Sheet.Kind, Update = Sheet.Upd.State, Fonts = Sheet.Fonts.State, Dismissed = Sheet.Dismissed })
    Dbg.Dump("side bubble", { Kind = tostring(Satellite.Right.kind) })
    Dbg.Dump("sdk apps", Sdk.Apps)
    for i, a in ipairs(Sdk.Acts) do
        Dbg.Log("snapshot", string.format("activity %d: %s \"%s\" trailing %s progress %s ends in %s", i, a.app, tostring(a.title), tostring(a.trailing), tostring(a.progress), a.ends and string.format("%.1f", a.ends - os.clock()) or "-"))
    end
    Dbg.Dump("sdk", { Asks = table.concat(Sdk.Asks, ","), Prompt = Sdk.Prompt, Muted = Sdk.Muted, Errors = Sdk.Errors, Expanded = Sdk.Expanded })
    Dbg.Dump("fuse errors", Fuse.Count)
    Dbg.Log("snapshot", "now: " .. table.concat(Dbg.Check(true), "  "))
    Dbg.PerfSummary()
    Dbg.Log("snapshot", "-------- end of snapshot --------", true)
end

function Dbg.Reveal()
    Dbg.Flush()
    if not Dbg.Path then Dbg.Path = Dbg.Dir() .. Dbg.File end
    pcall(Impl.HttpRequest, "GET", "http://127.0.0.1:45455/reveal", {}, function() end, "di_reveal")
    Log.Write("[Dynamic Island] debug log: " .. Dbg.Path)
end

function Dbg.RenderBubble(layout)
    local want = Dbg.On and not HUDCustomizer.IsOpen and not Hello.Blocking()
    local sat = Satellite.Step("rec", want, false)
    local _, bh = Focus.SatRow(layout)
    local moon = Satellite.S.moon
    local shift = moon and (bh + 8 * layout.scale) * math.max(0, math.min(1, moon.p)) or 0
    Dbg.Bounds = Satellite.Draw(layout, sat, -1, bh, function(x1, y1, x2, y2, d, ca)
        if ca <= 0.01 then return end
        Render.FilledCircle(Vec2((x1 + x2) / 2, (y1 + y2) / 2), d * 0.2, FadeColor(Config.Colors.Red, ca), 0, 1.0, 24)
    end, shift)
end

Demo.Steps = {
    { s = "COMPACT_IDLE", d = 1.6 },
    { s = "LARGE_IDLE", d = 2.4 },
    { s = "NOTIF_CENTER", d = 2.6 },
    { s = "COMPACT_MEDIA", d = 1.8, media = true },
    { s = "LARGE_MEDIA", d = 2.8, media = true },
    { s = "NOTIFICATION", d = 2.4, notif = true },
    { s = "COURIER_DELIVERY", d = 2.4, courier = true },
    { s = "COURIER_DELIVERED", d = 2.2, delivered = true },
    { s = "GAME_PAUSED", d = 2.0, pause = true },
    { s = "FACE_ID", d = 3.2, face = true },
    { s = "FOCUS_BANNER", d = 2.2, banner = true },
    { s = "SHEET", d = 3.4, sheet = "whatsnew" }
}

Demo.MediaKeys = { "HasReceivedData", "Title", "Artist", "LastTrackKey", "IsPlaying", "Duration", "Position", "PosSmooth", "PosTarget", "LastPauseTime" }

function Demo.Start()
    if Demo.Active then return end
    local now = os.clock()
    HUDCustomizer.IsOpen = false
    local media = {}
    for _, k in ipairs(Demo.MediaKeys) do media[k] = MediaData[k] end
    Demo.Saved = {
        media = media,
        realMedia = IsMediaActive(),
        notif = NotificationQueue.Active,
        notifStart = NotificationQueue.StartTime,
        eta = CourierTracker.ETA,
        progress = CourierTracker.Progress,
        delivered = CourierTracker.DeliveredStartTime,
        pause = PauseTracker.PauseStartTime,
        banner = { Focus.BannerOn, Focus.BannerStart, Focus.BannerUntil },
        kind = Sheet.Kind
    }
    NotificationQueue.Active = nil
    Demo.Notif = {
        Type = "stack",
        Tag = L("di_ui_stack"),
        Title = string.format(L("di_ui_stack_in_n_s"), 10),
        AccentColor = Color(48, 209, 88, 255),
        IconType = "svg",
        FallbackSvg = "stack",
        Duration = 99,
        Priority = 1,
        Chimed = true
    }
    Demo.Active = true
    Demo.Step = 0
    Demo.Next(now)
end

function Demo.Next(now)
    Demo.Step = Demo.Step + 1
    local st = Demo.Steps[Demo.Step]
    if not st then
        Demo.Stop()
        return
    end
    if st.media and not (UI and UI.Media and UI.Media.Enabled:Get()) then
        return Demo.Next(now)
    end
    Demo.At = now
    if st.media and not Demo.Saved.realMedia then
        MediaData.HasReceivedData = true
        MediaData.Title = "Blinding Lights"
        MediaData.Artist = "The Weeknd"
        MediaData.LastTrackKey = "demo"
        MediaData.IsPlaying = true
        MediaData.Duration = 200
        MediaData.Position = 63
        MediaData.PosSmooth = 63
        MediaData.PosTarget = 63
    end
    NotificationQueue.Active = st.notif and Demo.Notif or nil
    NotificationQueue.StartTime = now
    if st.courier then
        CourierTracker.ETA = 14
        CourierTracker.Progress = 0.55
    end
    if st.delivered then CourierTracker.DeliveredStartTime = now end
    if st.face then Impl.Face.At = nil Impl.FaceStart("ok", 0.9) end
    if st.pause then PauseTracker.PauseStartTime = now - 83 end
    if st.banner then
        Focus.BannerOn = true
        Focus.BannerStart = now
        Focus.BannerUntil = now + st.d
    end
    Sheet.Forced = st.sheet
    if st.sheet then Sheet.Kind = st.sheet end
    TriggerStateTransition(StateMachine.States[st.s])
end

function Demo.Tick(now)
    local st = Demo.Steps[Demo.Step]
    if not st then
        Demo.Stop()
        return
    end
    if now - Demo.At >= st.d then
        Demo.Next(now)
        return
    end
    local target = StateMachine.States[st.s]
    if StateMachine.TargetState ~= target then TriggerStateTransition(target) end
end

function Demo.Stop()
    local sv = Demo.Saved
    Demo.Active = false
    Sheet.Forced = nil
    if not sv then return end
    for _, k in ipairs(Demo.MediaKeys) do MediaData[k] = sv.media[k] end
    NotificationQueue.Active = sv.notif
    NotificationQueue.StartTime = sv.notifStart or os.clock()
    CourierTracker.ETA = sv.eta
    CourierTracker.Progress = sv.progress
    CourierTracker.DeliveredStartTime = sv.delivered
    PauseTracker.PauseStartTime = sv.pause
    Focus.BannerOn, Focus.BannerStart, Focus.BannerUntil = sv.banner[1], sv.banner[2], sv.banner[3]
    Sheet.Kind = sv.kind
    Demo.Saved = nil
end

local function RenderStateLayerRaw(state, layout, alphaMul, yOffset)
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
            Impl.RenderFightCompact(layout, alphaMul, yOffset)
        else
            if IsMediaActive() then
                RenderCompactMedia(layout, alphaMul, yOffset)
            else
                RenderModularIdlePill(layout, alphaMul, yOffset)
            end
        end
    elseif state == StateMachine.States.NOTIFICATION then
        Impl.RenderNotificationState(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.GAME_PAUSED then
        Impl.RenderGamePausedPill(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.COURIER_DELIVERY then
        Impl.RenderCourierDeliveryPill(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.COURIER_DELIVERED then
        Impl.RenderCourierDeliveredPill(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.COURIER_LARGE then
        Impl.RenderCourierLarge(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.LARGE_MEDIA then
        if IsMediaActive() then
            Impl.RenderLargeMedia(layout, alphaMul, yOffset)
        else
            RenderLargeIdle(layout, alphaMul, yOffset)
        end
    elseif state == StateMachine.States.LARGE_FIGHT then
        if FightTracker.Active then
            Impl.RenderFightLarge(layout, alphaMul, yOffset)
        else
            RenderLargeIdle(layout, alphaMul, yOffset)
        end
    elseif state == StateMachine.States.LARGE_IDLE then
        RenderLargeIdle(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.MENU_IDLE then
        Journey.RenderIdle(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.MENU_SEARCHING then
        Journey.RenderSearching(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.MENU_MATCH_FOUND then
        Journey.RenderMatchFound(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.FACE_ID then
        Impl.RenderFaceID(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.FOCUS_BANNER then
        Focus.RenderBanner(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.SHEET then
        Sheet.Render(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.NOTIF_CENTER then
        NotifCenter.Render(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.ACTIVITY then
        Sdk.RenderCompact(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.ACTIVITY_LARGE then
        Sdk.RenderLarge(layout, alphaMul, yOffset)
    end
end

local function RenderStateLayer(state, layout, alphaMul, yOffset)
    Fuse.Guard("state_" .. tostring(state), RenderStateLayerRaw, state, layout, alphaMul, yOffset)
end

local ContentFx = { k = 1, alpha = 1, cx = 0, cy = 0, top = 0, h = 1, stagger = 0, reveal = nil, Installed = false }
local FxBase = getmetatable(Render).__index

function ContentFx.TextOut(font, size, text, pos, col, ...)
    if ContentFx.Glass and col and (col.a or 255) > 8 then
        FxBase.Text(font, size, text, Vec2(pos.x, pos.y + 1), Color(0, 0, 0, math.floor((col.a or 255) * 0.45)))
    end
    return FxBase.Text(font, size, text, pos, col, ...)
end

function ContentFx.Alpha(col, y)
    if not col then return col end
    local a = ContentFx.alpha
    if ContentFx.reveal then
        local rel = math.max(0, math.min(1, (y - ContentFx.top) / math.max(1, ContentFx.h)))
        local e = math.max(0, math.min(1, (ContentFx.reveal - ContentFx.stagger * rel) / (1 - ContentFx.stagger)))
        a = a * (1 - (1 - e) * (1 - e))
    end
    if a >= 0.999 then return col end
    return Color(col.r, col.g, col.b, math.floor((col.a or 255) * a))
end

function ContentFx.P(v)
    local k = ContentFx.k
    return Vec2(ContentFx.cx + (v.x - ContentFx.cx) * k, ContentFx.cy + (v.y - ContentFx.cy) * k)
end

ContentFx.Wrap = {
    Text = function(a)
        a[2] = a[2] * ContentFx.k
        a[5] = ContentFx.Alpha(a[5], a[4].y)
        a[4] = ContentFx.P(a[4])
    end,
    Image = function(a)
        local p, s = a[2], a[3]
        a[4] = ContentFx.Alpha(a[4], p.y + s.y / 2)
        a[2] = ContentFx.P(p)
        a[3] = Vec2(s.x * ContentFx.k, s.y * ContentFx.k)
        if a.n >= 5 and a[5] then a[5] = a[5] * ContentFx.k end
    end,
    FilledRect = function(a)
        a[3] = ContentFx.Alpha(a[3], (a[1].y + a[2].y) / 2)
        a[1], a[2] = ContentFx.P(a[1]), ContentFx.P(a[2])
        if a.n >= 4 and a[4] then a[4] = a[4] * ContentFx.k end
    end,
    FilledCircle = function(a)
        a[3] = ContentFx.Alpha(a[3], a[1].y)
        a[1] = ContentFx.P(a[1])
        a[2] = a[2] * ContentFx.k
    end,
    Line = function(a)
        a[3] = ContentFx.Alpha(a[3], (a[1].y + a[2].y) / 2)
        a[1], a[2] = ContentFx.P(a[1]), ContentFx.P(a[2])
    end,
    FilledTriangle = function(a)
        local pts = {}
        for i, pt in ipairs(a[1]) do pts[i] = ContentFx.P(pt) end
        a[2] = ContentFx.Alpha(a[2], a[1][1].y)
        a[1] = pts
    end,
    PushClip = function(a)
        a[1], a[2] = ContentFx.P(a[1]), ContentFx.P(a[2])
    end
}
ContentFx.Wrap.Rect = ContentFx.Wrap.FilledRect
ContentFx.Wrap.Circle = ContentFx.Wrap.FilledCircle
ContentFx.Wrap.Shadow = ContentFx.Wrap.FilledRect
ContentFx.Fns = {}
for name, fn in pairs(ContentFx.Wrap) do
    ContentFx.Fns[name] = function(...)
        local a = table.pack(...)
        fn(a)
        if name == "Text" then return ContentFx.TextOut(table.unpack(a, 1, a.n)) end
        return FxBase[name](table.unpack(a, 1, a.n))
    end
end

function ContentFx.Begin(layout, alpha, k, reveal, stagger)
    ContentFx.alpha = alpha
    ContentFx.k = k or 1
    ContentFx.reveal = reveal
    ContentFx.stagger = stagger or 0
    ContentFx.cx = layout.x + layout.w / 2
    ContentFx.cy = layout.y + layout.h / 2
    ContentFx.top = layout.y
    ContentFx.h = layout.h
    if ContentFx.k == 1 and alpha >= 0.999 and (not reveal or reveal >= 1) then
        ContentFx.End()
        return
    end
    if not ContentFx.Installed then
        for name, f in pairs(ContentFx.Fns) do Render[name] = f end
        ContentFx.Installed = true
    end
end

function ContentFx.End()
    if ContentFx.Installed then
        for name in pairs(ContentFx.Fns) do Render[name] = nil end
        if ContentFx.Glass then Render.Text = ContentFx.TextOut end
        ContentFx.Installed = false
    end
end

function Impl.RenderShared(kind, layout, m)
    local S = StateMachine.States
    if kind == "media" then
        Impl.RenderMediaSharedTransition(S.COMPACT_MEDIA, S.LARGE_MEDIA, layout, m)
    else
        Impl.RenderIdleSharedTransition(S.COMPACT_IDLE, S.LARGE_IDLE, layout, m)
    end
end

function Impl.RenderContent(layout, dt)
    local tr = StateMachine.Transition
    local ghosts = StateMachine.Ghosts
    for i = #ghosts, 1, -1 do
        local g = ghosts[i]
        g.a = g.a - dt / 0.16
        if g.a <= 0.01 then
            table.remove(ghosts, i)
            if g.state == StateMachine.States.NOTIFICATION and not tr.Active and StateMachine.TargetState ~= StateMachine.States.NOTIFICATION then
                NotificationQueue.LastDismissed = nil
            end
        end
    end
    for _, g in ipairs(ghosts) do
        local ok, err = pcall(function()
            ContentFx.Begin(layout, g.a ^ 1.5, 1 - 0.06 * (1 - g.a))
            if g.shared then
                Fuse.Guard("shared", Impl.RenderShared, g.shared, layout, g.m)
            else
                RenderStateLayer(g.state, g.w and StateMachine.FrameFor(layout, g.w, g.h, g.r) or layout, 1.0, 0)
            end
        end)
        ContentFx.End()
        if not ok then error(err, 0) end
    end
    if tr.Active and tr.SharedPair then
        tr.Reveal = 1
        Fuse.Guard("shared", Impl.RenderShared, tr.SharedPair, layout, StateMachine.SharedM(tr.SharedPair))
    elseif tr.Active then
        local r = tr.Shrink and math.min(1, tr.Progress / 0.5) or math.max(0, math.min(1, (tr.Progress - 0.05) / 0.70))
        r = math.max(r, tr.Reveal or 0)
        tr.Reveal = r
        if r > 0.001 then
            local ok, err = pcall(function()
                local D = Config.Dimensions
                local fl = StateMachine.FrameFor(layout, D.CompactTargetW or D.CompactW, D.CompactTargetH or D.CompactH, D.CompactTargetR or D.CompactRadius)
                ContentFx.Begin(fl, 1, 0.92 + 0.08 * EaseOutCubic(r), r, 0.25)
                RenderStateLayer(StateMachine.TargetState, fl, 1.0, 0)
            end)
            ContentFx.End()
            if not ok then error(err, 0) end
        end
    else
        RenderStateLayer(StateMachine.Current, layout, 1.0, 0.0)
    end
end

function Impl.RenderDragGuides(layout)
    local target = (DragState.IsDragging and DragState.SnapX) and 1 or 0
    local a = DragState.GuideA or 0
    a = a + (target - a) * 0.22
    if a < 0.01 then a = 0 end
    DragState.GuideA = a
    if a <= 0 then return end
    local scr = Render.ScreenSize()
    local gx = math.floor(scr.x / 2)
    local gap = math.floor(8 * layout.scale)
    local col = Color(255, 255, 255, math.floor(200 * a))
    Render.Line(Vec2(gx, 0), Vec2(gx, layout.y - gap), col, 1.0)
    Render.Line(Vec2(gx, layout.y + layout.h + gap), Vec2(gx, scr.y), col, 1.0)
end

Hello.Order = { "en", "ru", "uk", "es", "fr", "de", "it", "pt", "tr", "pl", "cs", "sv", "ro", "bg", "kk", "el" }
Hello.Raw = {
    en = { { -109, -96, 30, 2, -158, 103, -237, 218, -372, 30, 296, -464, 338, -570, 340, -642, 29, 341, -696, 315, -737, 266, -737, 30, 212, -737, 178, -696, 157, -602, 30, 134, -499, 117, -380, 74, 0, 30 }, { 78, -37, 30, 100, -231, 184, -372, 291, -372, 28, 355, -372, 396, -321, 384, -248, 30, 378, -205, 370, -161, 361, -110, 30, 351, -46, 380, 4, 469, 4, 30, 598, 4, 739, -68, 811, -179, 30, 836, -217, 846, -251, 847, -284, 30, 848, -344, 814, -389, 754, -389, 30, 678, -389, 620, -303, 620, -193, 30, 620, -75, 684, 8, 820, 8, 30, 1005, 8, 1209, -214, 1303, -461, 30, 1330, -531, 1340, -596, 1340, -642, 30, 1340, -695, 1323, -737, 1275, -737, 30, 1228, -737, 1197, -700, 1169, -643, 30, 1136, -576, 1112, -479, 1102, -370, 30, 1077, -97, 1133, 4, 1266, 4, 30, 1428, 4, 1607, -221, 1699, -462, 30, 1725, -531, 1735, -596, 1735, -642, 30, 1735, -695, 1718, -737, 1670, -737, 30, 1623, -737, 1592, -700, 1564, -643, 30, 1531, -576, 1507, -479, 1497, -370, 30, 1472, -97, 1528, 4, 1647, 4, 30, 1766, 4, 1830, -99, 1869, -209, 30, 1907, -318, 1954, -385, 2052, -385, 30, 2133, -385, 2197, -325, 2197, -212, 30, 2197, -87, 2116, 7, 2013, 8, 30, 1923, 9, 1864, -64, 1870, -174, 30, 1877, -296, 1951, -385, 2048, -385, 30, 2104, -385, 2151, -360, 2188, -333, 30, 2288, -260, 2365, -305, 2395, -377, 30 } },
    ru = { { -12, -241, 30, 2, -307, 43, -382, 117, -382, 30, 191, -382, 212, -316, 193, -228, 30, 180, -165, 170, -100, 149, -1, 30 }, { 169, -104, 30, 202, -278, 281, -388, 377, -388, 30, 442, -388, 476, -340, 470, -272, 30, 465, -221, 448, -162, 444, -112, 30, 439, -44, 461, 4, 531, 4, 30, 647, 4, 741, -127, 771, -290, 30, 777, -319, 783, -350, 788, -380, 30 }, { 788, -380, 30, 755, -170, 729, 41, 707, 251, 30 }, { 745, -80, 30, 771, -277, 859, -388, 959, -388, 30, 1038, -387, 1082, -323, 1074, -216, 30, 1065, -100, 978, 8, 873, 8, 28, 805, 7, 764, -28, 745, -75, 29 }, { 849, 6, 28, 1070, 39, 1311, -86, 1349, -287, 30, 1355, -319, 1362, -349, 1369, -379, 30 }, { 1369, -379, 30, 1352, -306, 1341, -247, 1334, -203, 30, 1329, -171, 1326, -149, 1325, -122, 29, 1323, -51, 1363, 0, 1440, 0, 29, 1552, 0, 1608, -100, 1641, -263, 29, 1649, -302, 1658, -339, 1665, -379, 30 }, { 1665, -379, 30, 1640, -241, 1620, -158, 1620, -112, 30, 1620, -43, 1647, 4, 1726, 4, 30, 1862, 4, 2038, -255, 2144, -475, 30, 2177, -542, 2189, -603, 2191, -649, 30, 2194, -708, 2170, -750, 2123, -750, 30, 2078, -750, 2048, -717, 2015, -649, 30, 1976, -566, 1953, -468, 1941, -370, 30, 1910, -97, 1975, 4, 2084, 4, 30, 2174, 4, 2231, -77, 2238, -184, 30, 2242, -274, 2204, -344, 2136, -377, 30 }, { 2196, -330, 30, 2290, -213, 2373, -120, 2496, -134, 30, 2602, -146, 2666, -212, 2669, -278, 30, 2672, -342, 2637, -389, 2567, -389, 30, 2484, -389, 2423, -302, 2423, -199, 30, 2423, -69, 2494, 8, 2614, 8, 30, 2775, 8, 2893, -115, 2925, -289, 30, 2931, -319, 2937, -350, 2942, -380, 30 }, { 2942, -380, 30, 2923, -253, 2906, -128, 2887, -1, 30 }, { 2903, -111, 30, 2928, -285, 3003, -388, 3092, -388, 30, 3164, -388, 3193, -331, 3189, -254, 30, 3185, -202, 3167, -100, 3151, -1, 30 }, { 3168, -107, 30, 3196, -281, 3264, -388, 3362, -388, 30, 3429, -388, 3462, -332, 3455, -264, 30, 3450, -216, 3434, -159, 3431, -112, 30, 3426, -43, 3460, 4, 3516, 4, 30, 3587, 4, 3630, -46, 3650, -101, 30 } },
    uk = { { -12, -241, 30, 2, -307, 43, -382, 117, -382, 30, 191, -382, 212, -316, 193, -228, 30, 180, -165, 170, -100, 149, -1, 30 }, { 169, -104, 30, 202, -278, 281, -388, 377, -388, 30, 442, -388, 476, -340, 470, -272, 30, 465, -221, 448, -162, 444, -112, 30, 439, -44, 461, 4, 531, 4, 30, 647, 4, 741, -127, 771, -290, 30, 776, -319, 783, -350, 788, -380, 30 }, { 788, -380, 30, 755, -170, 728, 41, 706, 251, 30 }, { 745, -80, 30, 770, -277, 859, -388, 959, -388, 30, 1037, -388, 1081, -323, 1073, -216, 30, 1065, -100, 978, 8, 872, 8, 28, 804, 8, 764, -28, 745, -75, 29 }, { 848, 6, 28, 1069, 37, 1311, -86, 1348, -287, 30, 1354, -319, 1362, -349, 1369, -379, 30 }, { 1369, -379, 30, 1352, -306, 1340, -247, 1334, -203, 30, 1329, -171, 1326, -149, 1324, -122, 29, 1323, -51, 1363, 0, 1440, 0, 29, 1552, 0, 1607, -100, 1641, -263, 29, 1649, -302, 1658, -339, 1665, -379, 30 }, { 1665, -379, 30, 1640, -241, 1620, -158, 1620, -112, 30, 1620, -43, 1647, 4, 1726, 4, 30, 1864, 4, 2036, -263, 2145, -491, 30, 2174, -552, 2185, -609, 2188, -653, 30, 2191, -709, 2168, -750, 2123, -750, 30, 2078, -750, 2048, -717, 2015, -649, 30, 1976, -566, 1953, -468, 1941, -370, 30, 1910, -97, 1975, 4, 2084, 4, 30, 2174, 4, 2231, -77, 2238, -184, 30, 2242, -274, 2204, -344, 2136, -377, 30 }, { 2195, -330, 30, 2301, -198, 2452, -299, 2512, -380, 30 }, { 2512, -380, 30, 2500, -312, 2490, -256, 2483, -206, 30, 2479, -173, 2478, -145, 2478, -117, 30, 2478, -45, 2507, 4, 2579, 4, 30, 2686, 4, 2794, -127, 2825, -290, 30, 2830, -319, 2837, -350, 2842, -380, 30 }, { 2842, -380, 30, 2822, -253, 2806, -128, 2787, -1, 30 }, { 2803, -111, 30, 2828, -285, 2903, -388, 2991, -388, 30, 3063, -388, 3092, -331, 3088, -254, 30, 3085, -202, 3066, -100, 3051, -1, 30 }, { 3068, -107, 30, 3096, -281, 3163, -388, 3261, -388, 30, 3328, -388, 3362, -332, 3354, -264, 30, 3349, -216, 3333, -159, 3330, -112, 30, 3325, -43, 3360, 4, 3416, 4, 30, 3486, 4, 3530, -46, 3549, -101, 30 }, { 2551, -589, 47, 2551, -589, 2551, -589, 2551, -589, 47 } },
    es = { { -87, -84, 30, 23, -150, 119, -232, 226, -376, 30, 301, -478, 338, -569, 340, -642, 29, 341, -696, 315, -737, 266, -737, 30, 212, -737, 178, -696, 157, -602, 30, 134, -499, 117, -380, 74, 0, 30 }, { 78, -37, 30, 99, -224, 184, -372, 291, -372, 28, 355, -372, 396, -321, 384, -248, 30, 378, -205, 366, -155, 359, -106, 30, 351, -44, 374, 4, 446, 4, 30, 548, 4, 612, -95, 640, -212, 30 }, { 823, -387, 30, 723, -379, 648, -294, 634, -178, 30, 621, -72, 680, 8, 774, 8, 30, 888, 8, 962, -90, 967, -212, 30, 971, -329, 915, -388, 839, -388, 30, 779, -388, 747, -343, 749, -288, 30, 751, -213, 807, -128, 926, -118, 30, 1090, -103, 1314, -224, 1405, -463, 30, 1431, -531, 1441, -596, 1441, -642, 30, 1441, -695, 1424, -737, 1376, -737, 30, 1329, -737, 1298, -700, 1270, -643, 30, 1237, -576, 1213, -479, 1203, -370, 30, 1178, -97, 1234, 4, 1354, 4, 30, 1475, 4, 1556, -101, 1590, -223, 29 }, { 1906, -312, 29, 1886, -358, 1844, -388, 1778, -388, 29, 1668, -388, 1585, -278, 1580, -160, 29, 1575, -52, 1625, 9, 1696, 8, 29, 1797, 7, 1871, -92, 1904, -301, 30, 1908, -327, 1912, -354, 1916, -380, 30 }, { 1916, -380, 30, 1912, -354, 1908, -328, 1904, -301, 30, 1886, -187, 1877, -142, 1878, -112, 30, 1880, -43, 1905, 4, 1967, 4, 30, 2045, 4, 2089, -49, 2110, -107, 30 } },
    fr = { { -92, -75, 30, 71, -132, 183, -247, 299, -489, 30, 328, -552, 339, -609, 342, -653, 30, 345, -709, 322, -750, 277, -750, 30, 232, -750, 202, -717, 169, -649, 30, 130, -566, 107, -468, 95, -370, 30, 64, -97, 129, 4, 238, 4, 30, 328, 4, 385, -77, 392, -184, 30, 396, -274, 358, -344, 290, -377, 30 }, { 350, -330, 30, 450, -205, 614, -295, 690, -351, 30, 723, -376, 752, -385, 788, -385, 30, 867, -385, 929, -325, 929, -212, 30, 929, -87, 850, 7, 750, 8, 30, 662, 9, 604, -64, 610, -174, 30, 617, -296, 689, -385, 784, -385, 30, 838, -385, 876, -366, 920, -333, 30, 1044, -241, 1168, -285, 1198, -380, 30 }, { 1198, -380, 30, 1179, -253, 1163, -128, 1143, -1, 30 }, { 1157, -91, 30, 1184, -279, 1268, -388, 1368, -388, 30, 1438, -388, 1474, -340, 1468, -272, 30, 1463, -221, 1446, -162, 1442, -112, 30, 1437, -43, 1469, 4, 1539, 4, 30, 1643, 4, 1747, -128, 1777, -290, 30, 1783, -319, 1790, -351, 1794, -381, 30 }, { 1794, -381, 30, 1775, -223, 1757, -64, 1738, 94, 30, 1719, 251, 1673, 314, 1603, 314, 30, 1556, 314, 1522, 284, 1522, 236, 30, 1522, 172, 1571, 126, 1679, 92, 30, 1866, 34, 2003, -76, 2048, -203, 30, 2088, -318, 2135, -385, 2233, -385, 30, 2314, -385, 2378, -325, 2378, -212, 30, 2378, -87, 2297, 7, 2194, 8, 30, 2104, 9, 2045, -64, 2051, -174, 30, 2058, -296, 2132, -385, 2229, -385, 30, 2285, -385, 2324, -366, 2369, -333, 30, 2506, -233, 2620, -280, 2660, -379, 30 }, { 2660, -379, 30, 2643, -306, 2632, -247, 2625, -203, 30, 2620, -171, 2617, -149, 2616, -122, 29, 2614, -51, 2654, 0, 2731, 0, 29, 2843, 0, 2899, -100, 2932, -263, 29, 2940, -302, 2949, -339, 2956, -379, 30 }, { 2956, -379, 30, 2931, -241, 2911, -158, 2911, -112, 30, 2911, -43, 2938, 4, 3012, 4, 30, 3130, 4, 3232, -164, 3283, -393, 30 }, { 3275, -359, 28, 3399, -353, 3454, -328, 3454, -269, 30, 3454, -228, 3434, -165, 3428, -119, 30, 3417, -39, 3447, 5, 3510, 5, 30, 3587, 5, 3641, -46, 3661, -98, 30 }, { 1815, -589, 47, 1815, -589, 1815, -589, 1815, -589, 47 } },
    de = { { -87, -84, 30, 23, -150, 119, -232, 226, -376, 30, 301, -478, 338, -569, 340, -642, 29, 341, -696, 315, -737, 266, -737, 30, 212, -737, 178, -696, 157, -602, 30, 134, -499, 117, -380, 74, 0, 30 }, { 78, -37, 30, 99, -224, 184, -372, 291, -372, 28, 355, -372, 396, -321, 384, -248, 30, 378, -205, 366, -155, 359, -106, 30, 351, -44, 374, 4, 447, 4, 30, 549, 4, 610, -107, 643, -223, 29 }, { 959, -312, 29, 939, -358, 897, -388, 831, -388, 29, 721, -388, 638, -278, 633, -160, 29, 628, -52, 678, 9, 749, 8, 29, 850, 7, 924, -92, 957, -301, 30, 961, -327, 965, -354, 969, -380, 30 }, { 969, -380, 30, 965, -354, 961, -328, 957, -301, 30, 939, -187, 930, -142, 931, -112, 30, 933, -43, 958, 4, 1037, 4, 30, 1173, 4, 1361, -225, 1451, -463, 30, 1477, -531, 1487, -596, 1487, -642, 30, 1487, -695, 1470, -737, 1422, -737, 30, 1375, -737, 1344, -700, 1316, -643, 30, 1283, -576, 1259, -479, 1249, -370, 30, 1224, -97, 1280, 4, 1413, 4, 30, 1575, 4, 1754, -221, 1846, -462, 30, 1872, -531, 1882, -596, 1882, -642, 30, 1882, -695, 1865, -737, 1817, -737, 30, 1770, -737, 1739, -700, 1711, -643, 30, 1678, -576, 1654, -479, 1644, -370, 30, 1619, -97, 1675, 4, 1794, 4, 30, 1913, 4, 1977, -99, 2016, -209, 30, 2054, -318, 2101, -385, 2199, -385, 30, 2280, -385, 2344, -325, 2344, -212, 30, 2344, -87, 2263, 7, 2160, 8, 30, 2070, 9, 2011, -64, 2017, -174, 30, 2024, -296, 2098, -385, 2195, -385, 30, 2251, -385, 2298, -360, 2335, -333, 30, 2435, -260, 2512, -305, 2542, -377, 30 } },
    it = { { 375, -325, 30, 355, -363, 313, -391, 250, -391, 30, 130, -391, 71, -287, 71, -185, 30, 71, -74, 144, 8, 267, 8, 30, 427, 8, 570, -113, 603, -289, 30, 608, -319, 616, -350, 621, -380, 30 }, { 621, -380, 30, 609, -312, 599, -256, 592, -206, 30, 588, -173, 587, -145, 587, -117, 30, 587, -45, 616, 4, 685, 4, 30, 782, 4, 877, -104, 911, -223, 29 }, { 1226, -312, 29, 1207, -358, 1165, -388, 1099, -388, 29, 989, -388, 906, -278, 901, -160, 29, 896, -52, 946, 9, 1017, 8, 29, 1118, 7, 1192, -92, 1225, -301, 30, 1229, -327, 1233, -354, 1237, -380, 30 }, { 1237, -380, 30, 1233, -354, 1229, -328, 1225, -301, 30, 1207, -187, 1198, -142, 1199, -112, 30, 1201, -43, 1226, 4, 1292, 4, 30, 1382, 4, 1456, -104, 1494, -210, 30, 1532, -318, 1579, -385, 1677, -385, 30, 1758, -385, 1822, -325, 1822, -212, 30, 1822, -87, 1741, 7, 1638, 8, 30, 1548, 9, 1489, -64, 1495, -174, 30, 1502, -296, 1576, -385, 1673, -385, 30, 1729, -385, 1776, -360, 1813, -333, 30, 1913, -260, 1990, -305, 2020, -377, 30 }, { 660, -589, 47, 660, -589, 660, -589, 660, -589, 47 } },
    pt = { { 266, -387, 30, 166, -379, 91, -294, 77, -178, 30, 64, -72, 123, 8, 217, 8, 30, 331, 8, 405, -90, 410, -212, 30, 414, -329, 358, -388, 282, -388, 30, 222, -388, 190, -343, 192, -288, 30, 194, -213, 250, -128, 369, -118, 30, 533, -103, 757, -224, 848, -463, 30, 874, -531, 884, -596, 884, -642, 30, 884, -695, 867, -737, 819, -737, 30, 772, -737, 741, -700, 713, -643, 30, 680, -576, 656, -479, 646, -370, 30, 621, -97, 677, 4, 797, 4, 30, 918, 4, 999, -101, 1033, -223, 29 }, { 1349, -312, 29, 1329, -358, 1287, -388, 1221, -388, 29, 1111, -388, 1028, -278, 1023, -160, 29, 1018, -52, 1068, 9, 1139, 8, 29, 1240, 7, 1314, -92, 1347, -301, 30, 1351, -327, 1355, -354, 1359, -380, 30 }, { 1359, -380, 30, 1355, -354, 1351, -328, 1347, -301, 30, 1329, -187, 1320, -142, 1321, -112, 30, 1323, -43, 1348, 4, 1410, 4, 30, 1488, 4, 1532, -49, 1553, -107, 30 }, { 1378, -690, 30, 1332, -638, 1285, -590, 1235, -544, 30 } },
    tr = { { -20, -241, 30, -10, -311, 33, -382, 104, -382, 30, 175, -382, 195, -316, 177, -228, 30, 164, -165, 155, -100, 135, -1, 30 }, { 154, -104, 30, 186, -277, 258, -388, 347, -388, 30, 419, -388, 448, -331, 444, -254, 30, 440, -202, 422, -100, 406, -1, 30 }, { 423, -107, 30, 451, -281, 519, -388, 616, -388, 30, 682, -388, 715, -332, 708, -264, 30, 703, -216, 691, -159, 688, -112, 30, 684, -44, 707, 4, 790, 4, 30, 902, 4, 1063, -68, 1135, -179, 30, 1159, -217, 1169, -251, 1170, -284, 30, 1171, -344, 1137, -389, 1077, -389, 30, 1001, -389, 943, -303, 943, -193, 30, 943, -75, 1007, 8, 1138, 8, 30, 1306, 8, 1424, -153, 1477, -393, 30 }, { 1469, -359, 28, 1593, -353, 1648, -328, 1648, -269, 30, 1648, -228, 1628, -165, 1622, -119, 30, 1611, -39, 1634, 5, 1716, 5, 30, 1841, 5, 1966, -229, 2074, -376, 30, 2150, -478, 2186, -569, 2188, -642, 29, 2189, -696, 2163, -737, 2114, -737, 30, 2060, -737, 2026, -696, 2005, -602, 30, 1982, -499, 1965, -380, 1922, 0, 30 }, { 1927, -37, 30, 1948, -224, 2032, -372, 2139, -372, 28, 2203, -372, 2244, -321, 2232, -248, 30, 2226, -205, 2214, -155, 2208, -106, 30, 2199, -44, 2223, 4, 2295, 4, 30, 2397, 4, 2458, -107, 2492, -223, 29 }, { 2807, -312, 29, 2787, -358, 2746, -388, 2679, -388, 29, 2569, -388, 2487, -278, 2481, -160, 29, 2477, -52, 2526, 9, 2597, 8, 29, 2698, 7, 2772, -92, 2805, -301, 30, 2809, -327, 2814, -354, 2818, -380, 30 }, { 2818, -380, 30, 2813, -354, 2809, -328, 2805, -301, 30, 2787, -187, 2779, -142, 2780, -112, 30, 2782, -43, 2807, 4, 2886, 4, 30, 3024, 4, 3194, -264, 3303, -491, 30, 3332, -552, 3342, -609, 3345, -653, 30, 3348, -709, 3325, -750, 3280, -750, 30, 3235, -750, 3205, -717, 3172, -649, 30, 3133, -566, 3110, -468, 3098, -370, 30, 3067, -97, 3132, 4, 3241, 4, 30, 3331, 4, 3388, -77, 3395, -184, 30, 3399, -274, 3361, -344, 3293, -377, 30 }, { 3353, -330, 30, 3462, -195, 3614, -244, 3681, -322, 29 }, { 3944, -312, 29, 3924, -358, 3883, -388, 3816, -388, 29, 3706, -388, 3624, -278, 3618, -160, 29, 3614, -52, 3663, 9, 3734, 8, 29, 3835, 7, 3909, -92, 3942, -301, 30, 3946, -327, 3951, -354, 3955, -380, 30 }, { 3955, -380, 30, 3950, -354, 3946, -328, 3942, -301, 30, 3924, -187, 3916, -142, 3917, -112, 30, 3919, -43, 3944, 4, 4006, 4, 30, 4084, 4, 4127, -49, 4148, -107, 30 } },
    pl = { { 375, -325, 30, 355, -363, 313, -391, 250, -391, 30, 130, -391, 71, -287, 71, -185, 30, 71, -74, 144, 8, 270, 8, 30, 439, 8, 533, -134, 628, -376, 30 }, { 629, -376, 30, 701, -343, 852, -338, 972, -375, 30 }, { 972, -375, 30, 914, -126, 825, 12, 705, 12, 30, 638, 12, 610, -16, 612, -52, 30, 615, -94, 670, -129, 765, -106, 30, 887, -75, 921, 2, 1057, 2, 30, 1180, 2, 1290, -73, 1359, -180, 30, 1383, -217, 1393, -251, 1394, -284, 30, 1395, -344, 1361, -389, 1301, -389, 30, 1225, -389, 1167, -303, 1167, -193, 30, 1167, -75, 1231, 8, 1363, 8, 30, 1534, 8, 1654, -156, 1728, -409, 30 }, { 1718, -377, 26, 1837, -308, 1896, -232, 1896, -139, 30, 1896, -62, 1833, 2, 1737, 2, 28, 1663, 2, 1610, -43, 1589, -84, 28 }, { 1702, -2, 28, 1912, 42, 2097, -66, 2127, -230, 30 }, { 2422, -325, 30, 2404, -363, 2363, -391, 2302, -391, 30, 2182, -391, 2123, -284, 2123, -179, 30, 2123, -76, 2194, 8, 2297, 8, 30, 2387, 8, 2444, -51, 2464, -105, 30 }, { 1900, -690, 30, 1854, -638, 1807, -590, 1757, -544, 30 }, { 2432, -690, 30, 2386, -638, 2339, -590, 2289, -544, 30 } },
    cs = { { 402, -312, 29, 382, -358, 340, -388, 274, -388, 29, 164, -388, 81, -278, 76, -160, 29, 71, -52, 121, 9, 192, 8, 29, 293, 7, 367, -92, 400, -301, 30, 404, -327, 408, -354, 412, -380, 30 }, { 412, -380, 30, 408, -354, 404, -328, 400, -301, 30, 382, -187, 373, -142, 374, -112, 30, 376, -43, 401, 4, 475, 4, 30, 594, 4, 716, -230, 824, -376, 30, 899, -478, 936, -569, 938, -642, 29, 939, -696, 913, -737, 864, -737, 30, 810, -737, 776, -696, 755, -602, 30, 732, -499, 715, -380, 672, 0, 30 }, { 676, -37, 30, 697, -224, 782, -372, 889, -372, 28, 953, -372, 994, -321, 982, -248, 30, 976, -205, 964, -155, 957, -106, 30, 949, -44, 972, 4, 1044, 4, 30, 1143, 4, 1189, -104, 1226, -211, 30, 1264, -318, 1311, -385, 1409, -385, 30, 1490, -385, 1554, -325, 1554, -212, 30, 1554, -87, 1473, 7, 1370, 8, 30, 1280, 9, 1221, -64, 1227, -174, 30, 1234, -296, 1308, -385, 1405, -385, 30, 1461, -385, 1500, -366, 1545, -333, 30, 1684, -231, 1800, -281, 1841, -381, 30 }, { 1841, -381, 30, 1822, -223, 1804, -64, 1785, 94, 30, 1766, 251, 1720, 314, 1650, 314, 30, 1603, 314, 1569, 284, 1569, 236, 30, 1569, 172, 1618, 126, 1730, 91, 30, 1935, 28, 2021, -45, 2074, -182, 30 }, { 1862, -589, 47, 1862, -589, 1862, -589, 1862, -589, 47 } },
    sv = { { -109, -96, 30, 2, -158, 103, -237, 218, -372, 30, 296, -464, 338, -570, 340, -642, 29, 341, -696, 315, -737, 266, -737, 30, 212, -737, 178, -696, 157, -602, 30, 134, -499, 117, -380, 74, 0, 30 }, { 78, -37, 30, 100, -231, 184, -372, 291, -372, 28, 355, -372, 396, -321, 384, -248, 30, 378, -205, 370, -161, 361, -110, 30, 351, -46, 380, 4, 469, 4, 30, 598, 4, 739, -68, 811, -179, 30, 836, -217, 846, -251, 847, -284, 30, 848, -344, 814, -389, 754, -389, 30, 678, -389, 620, -303, 620, -193, 30, 620, -75, 684, 8, 811, 8, 30, 965, 8, 1093, -115, 1125, -289, 30, 1131, -319, 1138, -351, 1142, -381, 30 }, { 1142, -381, 30, 1123, -223, 1105, -64, 1086, 94, 30, 1067, 251, 1021, 314, 951, 314, 30, 904, 314, 870, 284, 870, 236, 30, 870, 172, 919, 126, 1031, 91, 30, 1236, 28, 1322, -45, 1375, -182, 30 }, { 1163, -589, 47, 1163, -589, 1163, -589, 1163, -589, 47 } },
    ro = { { -143, -14, 30, 11, -37, 86, -109, 173, -409, 30 }, { 163, -377, 26, 282, -308, 341, -232, 341, -139, 30, 341, -62, 278, 2, 182, 2, 28, 108, 2, 55, -43, 34, -84, 28 }, { 147, -2, 28, 357, 41, 540, -68, 584, -223, 29 }, { 900, -312, 29, 880, -358, 838, -388, 772, -388, 29, 662, -388, 579, -278, 574, -160, 29, 569, -52, 619, 9, 690, 8, 29, 791, 7, 865, -92, 898, -301, 30, 902, -327, 906, -354, 910, -380, 30 }, { 910, -380, 30, 906, -354, 902, -328, 898, -301, 30, 880, -187, 871, -142, 872, -112, 30, 874, -43, 899, 4, 978, 4, 30, 1114, 4, 1302, -225, 1392, -463, 30, 1418, -531, 1428, -596, 1428, -642, 30, 1428, -695, 1411, -737, 1363, -737, 30, 1316, -737, 1285, -700, 1257, -643, 30, 1224, -576, 1200, -479, 1190, -370, 30, 1165, -97, 1221, 4, 1344, 4, 30, 1475, 4, 1569, -124, 1600, -290, 30, 1606, -319, 1613, -349, 1620, -379, 30 }, { 1620, -379, 30, 1603, -306, 1592, -247, 1585, -203, 30, 1580, -171, 1577, -149, 1576, -122, 29, 1574, -51, 1614, 0, 1691, 0, 29, 1803, 0, 1859, -100, 1892, -263, 29, 1900, -302, 1909, -339, 1916, -379, 30 }, { 1916, -379, 30, 1891, -241, 1871, -158, 1871, -112, 30, 1871, -43, 1898, 4, 1968, 4, 30, 2076, 4, 2201, -106, 2233, -280, 30 }, { 2293, -540, 30, 2248, -366, 2221, -238, 2217, -155, 30, 2212, -62, 2251, 4, 2323, 4, 30, 2403, 4, 2453, -56, 2467, -121, 30 }, { 2137, -381, 29, 2228, -381, 2319, -381, 2410, -381, 29 } },
    bg = { { 60, -258, 30, 78, -335, 138, -382, 218, -382, 30, 289, -382, 346, -335, 346, -254, 30, 346, -183, 303, -130, 198, -84, 28 }, { 198, -84, 28, 266, -53, 308, 20, 302, 113, 29, 294, 228, 240, 298, 173, 298, 30, 125, 298, 93, 263, 94, 211, 30, 95, 146, 143, 92, 268, 55, 30, 435, 7, 532, -83, 558, -217, 30 }, { 858, -320, 29, 842, -356, 803, -389, 735, -389, 30, 635, -389, 551, -291, 553, -157, 30, 553, -81, 602, -28, 661, -28, 30, 766, -28, 835, -133, 855, -299, 30 }, { 865, -380, 30, 846, -226, 828, -71, 809, 83, 30, 790, 237, 744, 298, 674, 298, 30, 626, 298, 595, 263, 597, 211, 30, 600, 146, 649, 92, 779, 55, 30, 962, 2, 1107, -108, 1141, -289, 30, 1147, -319, 1153, -350, 1158, -380, 30 }, { 1158, -380, 30, 1125, -170, 1099, 41, 1077, 251, 30 }, { 1115, -80, 30, 1141, -277, 1229, -388, 1329, -388, 30, 1408, -387, 1452, -323, 1444, -216, 30, 1435, -100, 1348, 8, 1243, 8, 28, 1175, 7, 1134, -28, 1115, -75, 29 }, { 1219, 6, 28, 1426, 37, 1651, -65, 1696, -223, 29 }, { 2012, -312, 29, 1992, -358, 1950, -388, 1884, -388, 29, 1774, -388, 1691, -278, 1686, -160, 29, 1681, -52, 1731, 9, 1802, 8, 29, 1903, 7, 1977, -92, 2010, -301, 30, 2014, -327, 2018, -354, 2022, -380, 30 }, { 2022, -380, 30, 2018, -354, 2014, -328, 2010, -301, 30, 1992, -187, 1983, -142, 1984, -112, 30, 1986, -43, 2011, 4, 2090, 4, 30, 2226, 4, 2400, -255, 2506, -475, 30, 2539, -542, 2551, -603, 2553, -649, 30, 2556, -708, 2532, -750, 2485, -750, 30, 2440, -750, 2410, -717, 2377, -649, 30, 2338, -566, 2315, -468, 2303, -370, 30, 2272, -97, 2337, 4, 2446, 4, 30, 2536, 4, 2593, -77, 2600, -184, 30, 2604, -274, 2566, -344, 2498, -377, 30 }, { 2558, -330, 30, 2652, -213, 2735, -120, 2858, -134, 30, 2964, -146, 3028, -212, 3031, -278, 30, 3034, -342, 2999, -389, 2929, -389, 30, 2846, -389, 2785, -302, 2785, -199, 30, 2785, -69, 2856, 8, 2976, 8, 30, 3137, 8, 3255, -115, 3287, -289, 30, 3293, -319, 3300, -349, 3307, -379, 30 }, { 3307, -379, 30, 3290, -306, 3279, -247, 3272, -203, 30, 3267, -171, 3264, -149, 3263, -122, 29, 3261, -51, 3301, 0, 3378, 0, 29, 3490, 0, 3546, -100, 3579, -263, 29, 3587, -302, 3596, -339, 3603, -379, 30 }, { 3603, -379, 30, 3578, -241, 3558, -158, 3558, -112, 30, 3558, -43, 3585, 4, 3647, 4, 30, 3725, 4, 3771, -49, 3792, -107, 30 }, { 3378, -592, 28, 3378, -549, 3408, -511, 3466, -511, 28, 3526, -511, 3574, -554, 3587, -628, 28 } },
    kk = { { 363, -320, 30, 342, -360, 302, -391, 238, -391, 30, 138, -391, 71, -289, 71, -185, 30, 71, -77, 137, 8, 252, 8, 30, 387, 8, 439, -73, 508, -199, 30, 579, -330, 639, -380, 729, -380, 30, 829, -380, 887, -281, 875, -159, 30, 864, -48, 798, 10, 721, 10, 30, 661, 10, 627, -31, 628, -81, 30, 629, -152, 691, -199, 807, -205, 30, 891, -209, 963, -205, 1028, -192, 30 }, { 1028, -192, 30, 994, -70, 1037, 5, 1106, 5, 30, 1190, 5, 1247, -70, 1359, -380, 30 }, { 1359, -380, 30, 1354, -303, 1354, -218, 1359, -139, 30, 1365, -47, 1402, 5, 1481, 5, 30, 1592, 5, 1758, -67, 1830, -179, 30, 1855, -217, 1865, -251, 1866, -284, 30, 1867, -344, 1833, -389, 1773, -389, 30, 1697, -389, 1639, -303, 1639, -193, 30, 1639, -75, 1703, 8, 1823, 8, 30, 1954, 8, 2023, -51, 2068, -145, 30 }, { 2068, -145, 30, 2062, -67, 2099, 5, 2170, 5, 30, 2246, 5, 2311, -66, 2415, -393, 30 }, { 2415, -393, 30, 2390, -116, 2415, 0, 2506, 0, 28, 2588, 0, 2651, -98, 2724, -392, 26 }, { 2724, -392, 26, 2712, -113, 2728, 4, 2817, 4, 30, 2891, 4, 2937, -68, 2954, -156, 30 } },
    el = { { 32, -271, 30, 54, -330, 104, -374, 165, -374, 30, 236, -374, 264, -324, 274, -202, 30, 280, -126, 287, -51, 293, 25, 30, 306, 178, 339, 240, 413, 240, 30, 487, 240, 543, 181, 560, 112, 30 }, { 494, -379, 30, 366, -177, 224, 27, 65, 233, 30 }, { 1033, -379, 30, 959, -149, 869, 8, 742, 8, 29, 669, 8, 626, -51, 630, -157, 29, 635, -290, 703, -386, 789, -386, 28, 862, -386, 898, -338, 915, -224, 28, 918, -205, 920, -186, 923, -167, 28, 941, -49, 964, 4, 1046, 4, 29, 1157, 4, 1298, -218, 1340, -380, 30 }, { 1340, -380, 30, 1304, -240, 1288, -166, 1288, -107, 30, 1288, -45, 1319, 4, 1395, 4, 30, 1485, 4, 1589, -76, 1630, -198, 26 }, { 1630, -198, 26, 1626, -90, 1682, -1, 1777, -1, 30, 1900, -1, 1955, -96, 1959, -201, 30, 1963, -315, 1898, -381, 1812, -381, 30, 1708, -381, 1642, -300, 1622, -154, 30, 1589, 83, 1674, 224, 1812, 224, 30, 1847, 224, 1878, 215, 1902, 200, 30 }, { 1475, -690, 30, 1440, -638, 1404, -590, 1364, -544, 30 }, { 2408, -340, 30, 2383, -365, 2341, -386, 2277, -386, 30, 2195, -386, 2140, -345, 2141, -286, 30, 2142, -220, 2204, -188, 2277, -188, 26, 2316, -188, 2332, -194, 2331, -207, 26, 2328, -225, 2282, -233, 2228, -224, 27, 2148, -211, 2104, -168, 2103, -108, 30, 2102, -48, 2157, 3, 2261, 3, 30, 2363, 3, 2425, -48, 2453, -105, 30 }, { 2532, -388, 30, 2606, -355, 2716, -343, 2818, -358, 28, 2870, -366, 2893, -376, 2892, -385, 26, 2891, -393, 2859, -397, 2805, -384, 27, 2684, -356, 2608, -242, 2608, -141, 30, 2608, -53, 2666, 4, 2747, 4, 30, 2804, 4, 2851, -17, 2886, -53, 30 }, { 3338, -340, 30, 3313, -365, 3271, -386, 3207, -386, 30, 3125, -386, 3070, -345, 3071, -286, 30, 3072, -220, 3134, -188, 3207, -188, 26, 3246, -188, 3262, -194, 3261, -207, 26, 3258, -225, 3212, -233, 3158, -224, 27, 3078, -211, 3034, -168, 3033, -108, 30, 3032, -48, 3087, 3, 3191, 3, 30, 3293, 3, 3355, -48, 3383, -105, 30 } }
}

function Gesture.New()
    return { active = false, wasDown = false, x0 = 0, y0 = 0, x = 0, y = 0, vx = 0, vy = 0, t = 0, moved = false, event = nil }
end

function Gesture.Step(g, down, x, y, now, canStart)
    g.event = nil
    if down and not g.active then
        if not g.wasDown and (not canStart or canStart(x, y)) then
            g.active, g.moved = true, false
            g.x0, g.y0, g.x, g.y, g.vx, g.vy, g.t = x, y, x, y, 0, 0, now
            g.event = "begin"
        end
    elseif down and g.active then
        local dt = math.max(0.001, now - g.t)
        local k = math.min(1, dt / 0.05)
        g.vx = g.vx + ((x - g.x) / dt - g.vx) * k
        g.vy = g.vy + ((y - g.y) / dt - g.vy) * k
        g.x, g.y, g.t = x, y, now
        if math.abs(x - g.x0) + math.abs(y - g.y0) > 4 then g.moved = true end
        g.event = "move"
    elseif not down and g.active then
        g.active = false
        if now - g.t > 0.08 then g.vx, g.vy = 0, 0 end
        g.event = "end"
    end
    g.wasDown = down
    return g.event
end

function Gesture.Rubber(off, dim)
    local a = math.abs(off)
    local r = (1 - 1 / (a * 0.55 / dim + 1)) * dim
    return off < 0 and -r or r
end

function Impl.Bezier(x1, y1, x2, y2, t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    local u = t
    for _ = 1, 8 do
        local iu = 1 - u
        local x = 3 * iu * iu * u * x1 + 3 * iu * u * u * x2 + u * u * u - t
        if math.abs(x) < 1e-5 then break end
        local dx = 3 * iu * iu * x1 + 6 * iu * u * (x2 - x1) + 3 * u * u * (1 - x2)
        if math.abs(dx) < 1e-6 then break end
        u = math.min(1, math.max(0, u - x / dx))
    end
    local iu = 1 - u
    return 3 * iu * iu * u * y1 + 3 * iu * u * u * y2 + u * u * u
end

function Impl.Wrap(font, size, text, maxW)
    local lines, cur = {}, ""
    for word in string.gmatch(text, "%S+") do
        local try = cur == "" and word or (cur .. " " .. word)
        if cur ~= "" and Render.TextSize(font, size, try).x > maxW then
            lines[#lines + 1] = cur
            cur = word
        else
            cur = try
        end
    end
    if cur ~= "" then lines[#lines + 1] = cur end
    return lines
end

function Impl.TextBlock(font, size, text, cx, y, maxW, col, lh)
    local lines = Impl.Wrap(font, size, text, maxW)
    for i, ln in ipairs(lines) do
        local ts = Render.TextSize(font, size, ln)
        Render.Text(font, size, ln, Vec2(math.floor(cx - ts.x / 2), math.floor(y + (i - 1) * lh)), col)
    end
    return #lines * lh
end

Hello.Cache = {}
Hello.Gest = Gesture.New()
Hello.Idx = 1
Hello.T0 = 0
Hello.Off, Hello.OffV = 0, 0
Hello.Back, Hello.BackV = 0, 0
Hello.Hint = 0

function Hello.Build(id)
    local c = Hello.Cache[id]
    if c then return c end
    local raw = Hello.Raw[id]
    if not raw then return nil end
    local X, Y, W, D, B = {}, {}, {}, {}, {}
    local n, len = 0, 0
    local x1, x2 = math.huge, -math.huge
    local dots = {}
    for _, st in ipairs(raw) do
        local px, py, pw = st[1], st[2], st[3]
        local startLen, startN = len, n
        n = n + 1
        X[n], Y[n], W[n], D[n], B[n] = px, py, pw, len, true
        x1, x2 = math.min(x1, px), math.max(x2, px)
        local i = 4
        while i + 6 <= #st do
            local ax, ay, bx, by, ex, ey, ew = st[i], st[i + 1], st[i + 2], st[i + 3], st[i + 4], st[i + 5], st[i + 6]
            local poly = math.sqrt((ax - px) ^ 2 + (ay - py) ^ 2) + math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) + math.sqrt((ex - bx) ^ 2 + (ey - by) ^ 2)
            local steps = math.max(2, math.ceil(poly / 18))
            local lx, ly = px, py
            for k = 1, steps do
                local t = k / steps
                local u = 1 - t
                local qx = u * u * u * px + 3 * u * u * t * ax + 3 * u * t * t * bx + t * t * t * ex
                local qy = u * u * u * py + 3 * u * u * t * ay + 3 * u * t * t * by + t * t * t * ey
                len = len + math.sqrt((qx - lx) ^ 2 + (qy - ly) ^ 2)
                n = n + 1
                X[n], Y[n], W[n], D[n], B[n] = qx, qy, pw + (ew - pw) * t, len, false
                x1, x2 = math.min(x1, qx), math.max(x2, qx)
                lx, ly = qx, qy
            end
            px, py, pw = ex, ey, ew
            i = i + 7
        end
        if len - startLen < 1 then
            for k = n, startN + 1, -1 do
                X[k], Y[k], W[k], D[k], B[k] = nil, nil, nil, nil, nil
            end
            n = startN
            dots[#dots + 1] = { x = st[1], y = st[2], w = st[3] }
        end
    end
    for _, d in ipairs(dots) do
        d.at = len
        for i = 1, n do
            if X[i] >= d.x + 12 then
                d.at = D[i]
                break
            end
        end
    end
    local J = {}
    for i = 1, n do
        local first = B[i]
        local last = i == n or B[i + 1]
        if first or last then
            J[i] = true
        else
            local ax, ay = X[i] - X[i - 1], Y[i] - Y[i - 1]
            local bx, by = X[i + 1] - X[i], Y[i + 1] - Y[i]
            local la, lb = math.sqrt(ax * ax + ay * ay), math.sqrt(bx * bx + by * by)
            J[i] = la < 1e-6 or lb < 1e-6 or (ax * bx + ay * by) / (la * lb) < 0.985
        end
    end
    c = { X = X, Y = Y, W = W, D = D, B = B, J = J, n = n, len = len, mid = (x1 + x2) / 2, dots = dots }
    Hello.Cache[id] = c
    return c
end

function Hello.Trim(t)
    local s, e, k = 0, 0, 1
    if t > 0.208 then e = Impl.Bezier(0.302, 0.14, 0.665, 1, math.min(1, (t - 0.208) / 2.292)) end
    if t > 4.158 then s = Impl.Bezier(0.477, 0, 0.729, 1, math.min(1, (t - 4.158) / 1.592)) end
    if t > 0.208 and t < 0.608 then
        k = 1 + Impl.Bezier(0.681, 0, 0.788, 1, (t - 0.208) / 0.4) / 9
    elseif t >= 0.608 and t < 2.5 then
        k = 1 + (1 - Impl.Bezier(0.059, 0, 0.118, 1, (t - 0.608) / 1.892)) / 9
    end
    return s, e, k
end

function Hello.Draw(c, cx, cy, sc, s0, e0, a, thick)
    if not c or e0 <= s0 or a <= 0.01 then return end
    local L0, L1 = s0 * c.len, e0 * c.len
    local X, Y, W, D, B, J = c.X, c.Y, c.W, c.D, c.B, c.J
    local ox = cx - c.mid * sc
    local oy = cy + 335 * sc
    local core = Color(255, 255, 255, math.floor(245 * a))
    local segs = math.max(16, math.min(32, math.floor(W[1] * sc * thick * 3)))
    local lastQ, lastI = nil, -1
    for i = 2, c.n do
        if not B[i] then
            local da, db = D[i - 1], D[i]
            if db > L0 and da < L1 and db > da then
                local ta = da < L0 and (L0 - da) / (db - da) or 0
                local tb = db > L1 and (L1 - da) / (db - da) or 1
                local ax, ay = X[i - 1], Y[i - 1]
                local r = (W[i - 1] + (W[i] - W[i - 1]) * tb) * sc * thick
                local p
                if ta == 0 and lastI == i - 1 then
                    p = lastQ
                else
                    p = Vec2(ox + (ax + (X[i] - ax) * ta) * sc, oy + (ay + (Y[i] - ay) * ta) * sc)
                end
                local q = Vec2(ox + (ax + (X[i] - ax) * tb) * sc, oy + (ay + (Y[i] - ay) * tb) * sc)
                local ddx, ddy = q.x - p.x, q.y - p.y
                local dl = math.sqrt(ddx * ddx + ddy * ddy)
                if dl > 0.01 then
                    local e = math.min(r * 0.45, 2.5) / dl
                    Render.Line(Vec2(p.x - ddx * e, p.y - ddy * e), Vec2(q.x + ddx * e, q.y + ddy * e), core, r * 2)
                end
                if ta > 0 or J[i - 1] then
                    Render.FilledCircle(p, r, core, 0, 1.0, segs)
                end
                if tb < 1 or J[i] then
                    Render.FilledCircle(q, r, core, 0, 1.0, segs)
                end
                lastQ, lastI = q, i
            end
        end
    end
    for _, d in ipairs(c.dots) do
        if L1 >= d.at and L0 < d.at then
            local k = EaseOutBack(math.min(1, (L1 - d.at) / 90))
            if k > 0.01 then
                Render.FilledCircle(Vec2(ox + d.x * sc, oy + d.y * sc), d.w * sc * thick * k, core, 0, 1.0, math.max(16, segs))
            end
        end
    end
end

function Hello.Backdrop(scr, back)
    if Hello.RT == nil then
        local ok, h = pcall(Render.FindOrCreateRT, "di_hello_back")
        Hello.RT = (ok and h) or false
        local ok2, h2 = pcall(Render.FindOrCreateRT, "di_hello_grain", 256, 256)
        Hello.Grain = (ok2 and h2) or false
        Hello.RTDirty = true
        Hello.GrainDirty = true
    end
    if Hello.RT then
        if Hello.RTDirty then
            pcall(Render.MarkDirtyRT, Hello.RT)
            Hello.RTDirty = false
        end
        local ok = pcall(Render.RenderRT, function()
            Render.Blur(Vec2(0, 0), scr, 2.6, 1.0, 0, Enum.DrawFlags.None)
            Render.Blur(Vec2(0, 0), scr, 2.6, 1.0, 0, Enum.DrawFlags.None)
            Render.FilledRect(Vec2(0, 0), scr, Color(18, 18, 22, 118), 0)
            return false
        end, Hello.RT, Vec2(0, 0), Color(255, 255, 255, math.floor(255 * back)))
        if not ok then Hello.RT = false end
    end
    if not Hello.RT then
        Render.Blur(Vec2(0, 0), scr, 1.0, back, 0, Enum.DrawFlags.None)
        Render.FilledRect(Vec2(0, 0), scr, Color(18, 18, 22, math.floor(118 * back)), 0)
    end
    if Hello.Grain then
        if Hello.GrainDirty then
            pcall(Render.MarkDirtyRT, Hello.Grain)
            Hello.GrainDirty = false
        end
        local tint = Color(255, 255, 255, math.floor(255 * back))
        for gy = 0, math.ceil(scr.y / 256) - 1 do
            for gx = 0, math.ceil(scr.x / 256) - 1 do
                local ok = pcall(Render.RenderRT, Hello.BakeGrain, Hello.Grain, Vec2(gx * 256, gy * 256), tint)
                if not ok then
                    Hello.Grain = false
                    return
                end
            end
        end
    end
end

function Hello.BakeGrain()
    local seed = 1337
    local function rnd()
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed / 2147483648
    end
    for _ = 1, 2600 do
        local px, py = math.floor(rnd() * 256), math.floor(rnd() * 256)
        local light = rnd() > 0.5
        local al = math.floor(10 + rnd() * 16)
        Render.FilledRect(Vec2(px, py), Vec2(px + 1, py + 1), light and Color(255, 255, 255, al) or Color(0, 0, 0, al + 6), 0)
    end
    return false
end

function Hello.ChatWidget()
    if Hello.ChatW == nil then
        local ok, w = pcall(Menu.Find, "Changer", "Main", "Better UI", "Main Menu", "Main Menu", "Chat", "Settings", "Hide")
        Hello.ChatW = (ok and w) or false
    end
    return Hello.ChatW or nil
end

function Hello.HideChat()
    local w = Hello.ChatWidget()
    if not w then return end
    if Hello.ChatPrev == nil then
        local ok, v = pcall(w.Get, w)
        if not ok then return end
        Hello.ChatPrev = v == true
        SaveAllConfig()
    end
    pcall(w.Set, w, true)
    Hello.ChatHidden = true
end

function Hello.RestoreChat()
    if Hello.ChatPrev == nil then return end
    local w = Hello.ChatWidget()
    if w then pcall(w.Set, w, Hello.ChatPrev) end
    Hello.ChatPrev = nil
    Hello.ChatHidden = false
    SaveAllConfig()
end

Impl.KeyVK = nil

function Impl.ButtonVK(code)
    if not Impl.KeyVK then
        local B = Enum.ButtonCode
        local t = {}
        local named = {
            KEY_INSERT = 0x2D, KEY_DELETE = 0x2E, KEY_HOME = 0x24, KEY_END = 0x23, KEY_PAGEUP = 0x21, KEY_PAGEDOWN = 0x22,
            KEY_BACKQUOTE = 0xC0, KEY_SCROLLLOCK = 0x91, KEY_BREAK = 0x13, KEY_APP = 0x5D
        }
        for name, vk in pairs(named) do
            if B[name] then t[B[name]] = vk end
        end
        local letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        for i = 1, 26 do
            local ch = string.sub(letters, i, i)
            if B["KEY_" .. ch] then t[B["KEY_" .. ch]] = 0x40 + i end
        end
        for d = 0, 9 do
            if B["KEY_" .. d] then t[B["KEY_" .. d]] = 0x30 + d end
            if B["KEY_PAD_" .. d] then t[B["KEY_PAD_" .. d]] = 0x60 + d end
        end
        for f = 1, 24 do
            if B["KEY_F" .. f] then t[B["KEY_F" .. f]] = 0x6F + f end
        end
        Impl.KeyVK = t
    end
    return code and Impl.KeyVK[code] or nil
end

function Hello.CloseMenu()
    if not (Menu.Opened and Menu.Opened()) then return end
    local ok, bind = pcall(Menu.Find, "SettingsHidden", "", "", "", "Main", "Menu Bind")
    if not ok or not bind then return end
    local ok2, code = pcall(bind.Get, bind)
    if not ok2 then return end
    local vk = Impl.ButtonVK(code)
    if not vk then return end
    pcall(Impl.HttpRequest, "GET", "http://127.0.0.1:45455/key?vk=" .. tostring(vk), {}, function() end, "di_key")
end

function Hello.Stamp()
    return math.floor(os.time() - os.clock())
end

function Hello.Blocking()
    return Hello.Phase ~= nil and Hello.Phase ~= "out" and os.clock() - (Hello.Seen or -10) < 0.5
end

function Hello.Start(forceSetup)
    Hello.Phase = "hello"
    Hello.Idx = 1
    Hello.T0 = os.clock()
    Hello.Off, Hello.OffV = 0, 0
    Hello.Hint = 0
    Hello.Gest = Gesture.New()
    Hello.Gest.wasDown = true
    Hello.Seen = os.clock()
    Hello.RTDirty = true
    Hello.WantSetup = forceSetup or not Hello.SetupDone
    Hello.StampValue = Hello.Stamp()
    Hello.ChatHidden = false
    Hello.MenuWatchUntil = os.clock() + 3
    Hello.MenuDone = false
    Hello.ChatTry = 0
    SaveAllConfig()
end

function Hello.Init()
    if Hello.ChatPending ~= nil then
        Hello.ChatPrev = Hello.ChatPending
        Hello.ChatPending = nil
    end
    local inGame = Engine.IsInGame and Engine.IsInGame()
    if inGame or UI.Main.OnlyInGame:Get() or Journey.HiddenPhase() then return end
    local same = Hello.SavedStamp and math.abs(Hello.SavedStamp - Hello.Stamp()) <= 8
    if UI.Main.Hello:Get() and not Setup.Resume and not same then
        Hello.Start(false)
    elseif not Hello.SetupDone then
        Hello.WantSetup = true
        Setup.Open()
    end
    if Hello.Phase ~= "hello" then Hello.RestoreChat() end
end

function Hello.Finish()
    Hello.Phase = "out"
end

function Hello.Commit(now)
    Hello.Phase = "fly"
    Hello.FlyAt = now
    Hello.FlyFrom = Hello.Off
    Hello.Squished = false
    HapticPlaySound("toast_dismiss", 0.5)
end

function Hello.Tick(layout, now, dt)
    if Hello.ChatPrev ~= nil and Hello.Phase ~= "hello" then Hello.RestoreChat() end
    if Hello.Phase == "hello" then
        if not Hello.MenuDone and now < (Hello.MenuWatchUntil or 0) and Menu.Opened and Menu.Opened() then
            Hello.MenuDone = true
            Hello.CloseMenu()
        end
        if not Hello.ChatHidden and now - (Hello.ChatTry or 0) > 0.25 then
            Hello.ChatTry = now
            if not Hello.ChatW then Hello.ChatW = nil end
            Hello.HideChat()
        end
    end
    local inGame = Engine.IsInGame and Engine.IsInGame()
    local accept = Engine.CanAcceptMatch and Engine.CanAcceptMatch()
    if (inGame or accept) and Hello.Phase ~= "out" then
        Hello.Phase = "out"
        Setup.Active = false
    end
    local mx, my = Input.GetCursorPos()
    local down = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1)
    local H = Render.ScreenSize().y
    if Hello.Phase == "hello" then
        local ev = Gesture.Step(Hello.Gest, down, mx, my, now)
        local g = Hello.Gest
        if g.active then
            local dy = g.y - g.y0
            Hello.Off = dy < 0 and dy or Gesture.Rubber(dy, H * 0.08)
            Hello.OffV = 0
        elseif ev == "end" then
            local p = -Hello.Off / (H * 0.28)
            if (p > 0.35 or g.vy < -700) and g.y - g.y0 < -6 then
                Hello.Commit(now)
            end
        else
            Hello.Off, Hello.OffV = MotionEngine.Step(Hello.Off, Hello.OffV, 0, dt, "BOUNCY")
        end
    elseif Hello.Phase == "fly" then
        local f = (now - Hello.FlyAt) / 0.55
        if f > 0.62 and not Hello.Squished then
            Hello.Squished = true
            if StateMachine.Spring and StateMachine.Spring.Squish then
                StateMachine.Spring.Squish.value = -0.32
                StateMachine.Spring.Squish.vel = -2.2
            end
            if Haptic and Haptic.Silent then Haptic.Silent(Haptic.Types.TAP_MEDIUM) end
        end
        if f >= 1 then
            if Hello.WantSetup then
                Setup.Open()
            else
                Hello.Phase = "out"
            end
        end
    elseif Hello.Phase == "setup" then
        Setup.Tick(layout, now, dt, mx, my, down)
    end
    local target = 0
    if Hello.Phase == "hello" then
        target = 1 - math.min(0.6, math.max(0, -Hello.Off / (H * 0.5)))
    elseif Hello.Phase == "fly" then
        target = Hello.WantSetup and 0.85 or 0
    elseif Hello.Phase == "setup" then
        target = Setup.Active and 0.85 or 0
    end
    Hello.Back, Hello.BackV = MotionEngine.Step(Hello.Back, Hello.BackV, target, dt, "SMOOTH")
    if Hello.Phase == "out" and Hello.Back < 0.01 and (not Setup.Anim or Setup.Anim <= 0) then
        Hello.Phase = nil
        Hello.Back, Hello.BackV = 0, 0
    end
end

function Hello.RenderBack(layout, dt)
    if not Hello.Phase then return end
    local now = os.clock()
    Hello.Seen = now
    Hello.Tick(layout, now, dt)
    if not Hello.Phase then return end
    local scr = Render.ScreenSize()
    local back = math.max(0, math.min(1, Hello.Back))
    if back > 0.01 then
        Hello.Backdrop(scr, back)
    end
    if Hello.Phase ~= "hello" and Hello.Phase ~= "fly" then return end

    local sc = scr.x * 0.33 / 2504
    local cx, cy = scr.x / 2, scr.y * 0.46
    local t = now - Hello.T0
    local cycle = 6.0
    local idx = math.floor(t / cycle)
    local wt = t - idx * cycle
    local order = Hello.Order
    local id = order[(idx % #order) + 1]
    local s0, e0, k = Hello.Trim(wt)
    local a, scale, wx, wy = 1, 1, cx, cy + Hello.Off
    if Hello.Phase == "hello" then
        local p = math.max(0, math.min(1, -Hello.Off / (scr.y * 0.28)))
        scale = 1 - 0.16 * p
        a = 1 - 0.25 * p
        Hello.Frozen = { id = id, s = s0, e = e0, k = k }
    else
        local fr = Hello.Frozen or { id = id, s = s0, e = e0, k = k }
        id, s0, e0, k = fr.id, fr.s, fr.e, fr.k
        local f = math.min(1, (now - Hello.FlyAt) / 0.55)
        local ef = EaseOutCubic(f)
        local tx, ty = layout.x + layout.w / 2, layout.y + layout.h / 2
        local sy = cy + Hello.FlyFrom
        wx = cx + (tx - cx) * ef
        wy = sy + (ty - sy) * ef
        scale = (1 - 0.16 * math.min(1, -Hello.FlyFrom / (scr.y * 0.28))) * (1 - 0.93 * ef)
        a = 1 - f * f
    end
    Hello.Draw(Hello.Build(id), wx, wy, sc * scale, s0, e0, a, k)

    local hintT = math.min(1, math.max(0, (t - 1.4) / 0.6))
    local hp = math.max(0, math.min(1, -Hello.Off / (scr.y * 0.12)))
    local ha = hintT * (1 - hp) * (Hello.Phase == "hello" and 1 or 0)
    Hello.Hint = Hello.Hint + (ha - Hello.Hint) * math.min(1, dt * 10)
    if Hello.Hint > 0.01 then
        local s = layout.scale
        local pulse = 0.62 + 0.38 * (0.5 + 0.5 * math.sin(now * 2.4))
        local bob = math.max(0, math.sin(now * 2.4)) * 3 * s
        local barW, barH = math.floor(140 * s), math.max(3, math.floor(5 * s))
        local by = scr.y - 34 * s - bob + Hello.Off * 0.35
        Render.FilledRect(Vec2(math.floor(cx - barW / 2), math.floor(by)), Vec2(math.floor(cx + barW / 2), math.floor(by + barH)), Color(255, 255, 255, math.floor(235 * Hello.Hint)), barH / 2)
        local f, sz = TF("Subhead", s)
        local txt = L("di_hello_swipe")
        local ts = Render.TextSize(f, sz, txt)
        Render.Text(f, sz, txt, Vec2(math.floor(cx - ts.x / 2), math.floor(by - 14 * s - ts.y)), Color(255, 255, 255, math.floor(200 * Hello.Hint * pulse)))
    end
end

Setup.Steps = { "bridge", "fonts", "position", "look", "alerts", "likes", "focus", "done" }
Setup.Hits = {}
Setup.Anim = 0
Setup.PT, Setup.PTV = 1, 0
Setup.Active = false
Setup.Glyph = { bridge = "bolt", position = "display", look = "appearance", alerts = "bell", likes = "heart_fill", focus = "moon" }
Setup.Tint = { bridge = "Orange", fonts = "Blue", position = "Blue", look = "Indigo", alerts = "Red", likes = "Pink", focus = "Indigo", done = "Green" }

function Setup.Visible(id)
    if id == "fonts" then
        return Sheet.BridgeOnline() and BridgeStatus.FontsOk == false or Sheet.Fonts.State ~= "idle"
    end
    return true
end

function Setup.IndexOf(id)
    for i, v in ipairs(Setup.Steps) do
        if v == id then return i end
    end
    return 1
end

function Setup.Open()
    Hello.Phase = "setup"
    Setup.Active = true
    Setup.Anim = Setup.Anim or 0
    local start = 1
    if Setup.Resume then
        start = math.max(1, math.min(#Setup.Steps, Setup.Resume))
        Setup.Resume = nil
        SaveAllConfig()
    end
    Setup.Step = start
    Setup.Prev = nil
    Setup.PT, Setup.PTV = 1, 0
    Setup.BridgeOkAt = nil
    Setup.Capture = false
    Setup.Slider = nil
    Hello.Seen = os.clock()
end

function Setup.Go(dir)
    local i = Setup.Step
    repeat
        i = i + dir
    until i < 1 or i > #Setup.Steps or Setup.Visible(Setup.Steps[i])
    if i < 1 or i > #Setup.Steps then return end
    Setup.Prev = Setup.Step
    Setup.Dir = dir
    Setup.Step = i
    Setup.PT, Setup.PTV = 0, 0
    Setup.Capture = false
    Setup.BridgeOkAt = nil
end

function Setup.Finish(demo)
    Sheet.BridgeHintSeen = true
    Sheet.SeenVer = SCRIPT_VERSION
    Setup.Active = false
    Setup.Capture = false
    Hello.SetupDone = true
    Hello.WantSetup = false
    SaveAllConfig()
    Hello.Phase = "out"
    if demo then Demo.Start() end
end

function Setup.Action(h, now)
    local a = h.action
    if a == "next" then
        Setup.Go(1)
    elseif a == "later" then
        Setup.Finish(false)
    elseif a == "done" then
        Setup.Finish(false)
    elseif a == "demo" then
        Setup.Finish(true)
    elseif a == "fonts_install" then
        Sheet.Action("fonts_install", now)
    elseif a == "fonts_reload" then
        Setup.Resume = Setup.IndexOf("position")
        SaveAllConfig()
        Sheet.ReloadAt = now + 0.2
    elseif a == "preset" then
        UI.Main.Preset:Set(h.val)
        SaveAllConfig()
    elseif a == "slider" then
        Setup.Slider = h
    elseif a == "look" then
        if h.val == 3 then
            UI.Main.PureGlass:Set(true)
        else
            UI.Main.PureGlass:Set(false)
            UI.Main.IslandBgColor:Set(h.val == 2 and Color(242, 242, 247, 245) or Color(0, 0, 0, 245))
        end
        SaveAllConfig()
    elseif a == "alerts" then
        Setup.ApplyAlerts(h.val)
        Setup.AlertPick = h.val
        SaveAllConfig()
    elseif a == "like" then
        UI.Media.SpotifyLike:Set(not UI.Media.SpotifyLike:Get())
        SaveAllConfig()
    elseif a == "like_guide" then
        pcall(Impl.HttpRequest, "GET", "http://127.0.0.1:45455/open?url=" .. Sheet.UrlEncode("https://github.com/qhols/DynamicIsland-Dota/blob/main/docs/spotify-likes.md"), {}, function() end, "di_open_docs")
    elseif a == "capture" then
        Setup.Capture = not Setup.Capture
    end
    if Haptic and Haptic.Trigger and a ~= "slider" then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
end

Setup.AlertSets = {
    {
        on = { "Kills", "Buybacks", "LowHP", "CourierDelivery", "PauseAlert", "ActiveRunes", "WisdomRunes", "Lotus", "Tormentor", "Mute" }
    },
    {
        off = { "Stacks" }
    },
    {
        off = {}
    }
}

function Setup.AlertWidgets()
    local C, R, S = UI.Combat, UI.Runes, UI.System
    return {
        Kills = C and C.Kills, Invis = C and C.Invis, Teleports = C and C.Teleports, KeyEnemyItems = C and C.KeyEnemyItems,
        Towers = C and C.Towers, Couriers = C and C.Couriers, Buybacks = C and C.Buybacks, LowHP = C and C.LowHP,
        LevelUp = C and C.LevelUp, CourierDelivery = C and C.CourierDelivery, PauseAlert = C and C.PauseAlert,
        ActiveRunes = R and R.ActiveRunes, WaterRunes = R and R.WaterRunes, BountyRunes = R and R.BountyRunes,
        WisdomRunes = R and R.WisdomRunes, RunePickups = R and R.RunePickups, RuneWorldSpawn = R and R.RuneWorldSpawn,
        Stacks = R and R.Stacks, Lotus = R and R.Lotus, Neutrals = R and R.Neutrals, Tormentor = R and R.Tormentor,
        Output = S and S.Output, Mute = S and S.Mute, Battery = S and S.Battery
    }
end

function Setup.ApplyAlerts(idx)
    local set = Setup.AlertSets[idx]
    if not set then return end
    local list = {}
    if set.on then
        for _, k in ipairs(set.on) do list[k] = true end
    end
    for k, w in pairs(Setup.AlertWidgets()) do
        local v
        if set.on then
            v = list[k] == true
        else
            v = true
            for _, o in ipairs(set.off) do
                if o == k then v = false end
            end
        end
        if w and w.Set then pcall(w.Set, w, v) end
    end
end

function Setup.KeyName(code)
    if not code or code <= 0 then return L("di_su_focus_none") end
    if not Setup.Names then
        Setup.Names = {}
        pcall(function()
            for k, v in pairs(Enum.ButtonCode) do
                if type(v) == "number" and type(k) == "string" and string.sub(k, 1, 4) == "KEY_" and not Setup.Names[v] then
                    Setup.Names[v] = string.gsub(string.sub(k, 5), "_", " ")
                end
            end
        end)
    end
    return Setup.Names[code] or ("#" .. tostring(code))
end

function Setup.OnKey(data)
    if not Setup.Capture then return true end
    local key = data.key
    if key == Enum.ButtonCode.KEY_MOUSE1 or key == Enum.ButtonCode.KEY_MOUSE2 or key == Enum.ButtonCode.KEY_MWHEELUP or key == Enum.ButtonCode.KEY_MWHEELDOWN then
        return true
    end
    if data.event ~= Enum.EKeyEvent.EKeyEvent_KEY_DOWN then return false end
    if key == Enum.ButtonCode.KEY_ESCAPE then
        Setup.Capture = false
    elseif key == Enum.ButtonCode.KEY_BACKSPACE or key == Enum.ButtonCode.KEY_DELETE then
        pcall(UI.Focus.Key.Set, UI.Focus.Key, Enum.ButtonCode.KEY_NONE)
        Setup.Capture = false
        SaveAllConfig()
    else
        pcall(UI.Focus.Key.Set, UI.Focus.Key, key)
        Setup.Capture = false
        SaveAllConfig()
        if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_MEDIUM) end
    end
    return false
end

function Setup.Geometry(layout)
    local s = layout.scale
    local scr = Render.ScreenSize()
    local w, h = math.floor(344 * s), math.floor(452 * s)
    local x = math.floor(layout.x + layout.w / 2 - w / 2)
    x = math.max(10, math.min(scr.x - w - 10, x))
    local y = math.floor(layout.y + layout.h + 12 * s)
    if y + h > scr.y - 10 then y = math.max(10, scr.y - h - 10) end
    return x, y, w, h, s
end

function Setup.Tick(layout, now, dt, mx, my, down)
    local pressed = down and not Setup.WasDown
    Setup.WasDown = down
    if Setup.Slider then
        local h = Setup.Slider
        if not down then
            Setup.Slider = nil
            SaveAllConfig()
        else
            local f = math.max(0, math.min(1, (mx - h.val[1]) / (h.val[2] - h.val[1])))
            local v = math.floor((60 + f * 120) / 5 + 0.5) * 5
            if v ~= UI.Main.Scale:Get() then
                UI.Main.Scale:Set(v)
                if Haptic and Haptic.Silent then Haptic.Silent(Haptic.Types.RATCHET_NOTCH) end
            end
        end
    elseif pressed and Setup.Anim > 0.9 and Setup.PT > 0.9 then
        for _, h in ipairs(Setup.Hits) do
            if mx >= h.x1 and mx <= h.x2 and my >= h.y1 and my <= h.y2 then
                Setup.Action(h, now)
                break
            end
        end
    end
    local id = Setup.Steps[Setup.Step]
    if id == "bridge" and Sheet.BridgeOnline() then
        Setup.BridgeOkAt = Setup.BridgeOkAt or now
        if Setup.BridgeWasOff and now - Setup.BridgeOkAt > 1.3 then
            Setup.BridgeWasOff = false
            Setup.Go(1)
        end
    elseif id == "bridge" then
        Setup.BridgeWasOff = BridgeStatus.FirstPoll > 0 and now - BridgeStatus.FirstPoll > 3
    elseif id == "fonts" and not Setup.Visible("fonts") then
        Setup.Go(1)
    end
end

function Setup.Hit(x1, y1, x2, y2, action, val)
    if not Setup.HitsOn then return end
    Setup.Hits[#Setup.Hits + 1] = { x1 = x1, y1 = y1, x2 = x2, y2 = y2, action = action, val = val }
end

function Setup.Primary(x, y, w, h, label, action, a, s, busy, tint)
    local C = Config.Colors
    local _, pk = Pointer.Button("su_primary", x, y, x + w, y + h)
    local kx, ky = w * 0.0175 * pk, h * 0.0175 * pk
    a = a * (1 - 0.22 * pk)
    Render.FilledRect(Vec2(x + kx, y + ky), Vec2(x + w - kx, y + h - ky), FadeColor(tint or C.Blue, a), (h - ky * 2) / 2)
    local f, sz = TF("Headline", s)
    if busy then
        Journey.Spinner(x + w / 2, y + h / 2, h * 0.22, Color(255, 255, 255, 255), a)
    else
        local ts = Render.TextSize(f, sz, label)
        Render.Text(f, sz, label, Vec2(math.floor(x + (w - ts.x) / 2), math.floor(y + (h - ts.y) / 2)), FadeColor(Color(255, 255, 255, 255), a))
    end
    if action then Setup.Hit(x, y, x + w, y + h, action) end
end

function Setup.Link(cx, y, label, action, a, s)
    local f, sz = TF("Body", s)
    local ts = Render.TextSize(f, sz, label)
    local _, pk = Pointer.Button("su_link", cx - ts.x / 2 - 10 * s, y - 14 * s, cx + ts.x / 2 + 10 * s, y + 14 * s)
    a = a * (1 - 0.45 * pk)
    Render.Text(f, sz, label, Vec2(math.floor(cx - ts.x / 2), math.floor(y - ts.y / 2)), FadeColor(Config.Colors.Blue, a))
    if action then Setup.Hit(cx - ts.x / 2 - 10 * s, y - 14 * s, cx + ts.x / 2 + 10 * s, y + 14 * s, action) end
end

function Setup.Group(x, y, w, h, a, s)
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), FadeColor(Config.Colors.Group, a), 12 * s)
end

function Setup.Page(id, x, y, w, h, a, s, live, now)
    Setup.HitsOn = live
    local C = Config.Colors
    local pad = 20 * s
    local cx = x + w / 2
    local tint = C[Setup.Tint[id] or "Blue"] or C.Blue
    local iy = y + 50 * s
    if id == "done" then
        Setup.DoneAt = Setup.DoneAt or now
        Success.Draw("setup_done" .. tostring(Setup.DoneAt), Vec2(cx, iy), 26 * s, now - Setup.DoneAt, a, s)
    elseif id == "fonts" then
        local f = Config.Fonts.Semibold
        local ts = Render.TextSize(f, math.floor(40 * s), "Aa")
        Render.Text(f, math.floor(40 * s), "Aa", Vec2(math.floor(cx - ts.x / 2), math.floor(iy - ts.y / 2)), FadeColor(tint, a))
    else
        Glyph(Setup.Glyph[id] or "check", cx, iy, math.floor(46 * s), FadeColor(tint, a))
    end
    if id ~= "done" then Setup.DoneAt = nil end

    local tf = Config.Fonts.Semibold
    local tsz = math.floor(21 * s)
    local ty = y + 92 * s
    local th = Impl.TextBlock(tf, tsz, L("di_su_" .. id .. "_t"), cx, ty, w - pad * 2, FadeColor(C.TextPrimary, a), math.floor(25 * s))
    local bf, bsz = TF("Subhead", s)
    local by = ty + th + 8 * s
    local bh = Impl.TextBlock(bf, bsz, L("di_su_" .. id .. "_d"), cx, by, w - pad * 2, FadeColor(C.TextSecondary, a), math.floor(17 * s))
    local top = by + bh + 16 * s
    local gx, gw = x + pad, w - pad * 2
    local rowH = 44 * s
    local lf, lsz = TF("Body", s)
    local function Label(text, yy, col, lx)
        local ls = Render.TextSize(lf, lsz, text)
        Render.Text(lf, lsz, text, Vec2(math.floor(lx or (gx + 14 * s)), math.floor(yy - ls.y / 2)), FadeColor(col or C.TextPrimary, a))
        return ls.x
    end

    local primary, pAction, busy, ptint = L("di_su_continue"), "next", false, nil
    local link, lAction = L("di_su_later"), "later"

    if id == "bridge" then
        local online = Sheet.BridgeOnline()
        local checking = not online and (BridgeStatus.FirstPoll == 0 or now - BridgeStatus.FirstPoll < 3)
        Setup.Group(gx, top, gw, rowH, a, s)
        local my = top + rowH / 2
        if online then
            Setup.BridgeSeen = Setup.BridgeSeen or now
            Success.Draw("setup_bridge", Vec2(gx + 24 * s, my), 10 * s, now - Setup.BridgeSeen, a, s)
            Label(L("di_su_bridge_on"), my, C.TextPrimary, gx + 44 * s)
        elseif checking then
            Journey.Spinner(gx + 24 * s, my, 8 * s, C.TextSecondary, a)
            Label(L("di_su_bridge_check"), my, C.TextSecondary, gx + 44 * s)
        else
            Render.FilledCircle(Vec2(gx + 24 * s, my), 10 * s, FadeColor(C.Orange, a), 0, 1.0, 24)
            local ef, esz = TF("FootnoteEm", s)
            local es = Render.TextSize(ef, esz, "!")
            Render.Text(ef, esz, "!", Vec2(math.floor(gx + 24 * s - es.x / 2), math.floor(my - es.y / 2)), FadeColor(Color(255, 255, 255, 255), a))
            Label(L("di_su_bridge_off"), my, C.TextPrimary, gx + 44 * s)
            local cy2 = top + rowH + 12 * s
            local hf, hsz = TF("Footnote", s)
            local hh = Impl.TextBlock(hf, hsz, L("di_su_bridge_how"), x + w / 2, cy2, gw, FadeColor(C.TextSecondary, a), math.floor(15 * s))
            local boxY = cy2 + hh + 6 * s
            Setup.Group(gx, boxY, gw, 30 * s, a, s)
            local code = "\"...\\media_bridge.exe\" %command%"
            local cs = Render.TextSize(hf, hsz, code)
            Render.Text(hf, hsz, code, Vec2(math.floor(x + w / 2 - cs.x / 2), math.floor(boxY + 15 * s - cs.y / 2)), FadeColor(C.TextPrimary, a))
            primary = L("di_su_bridge_skip")
            ptint = C.FillSecondary
        end
    elseif id == "fonts" then
        local st = Sheet.Fonts.State
        if st == "installing" then
            busy, pAction = true, nil
        elseif st == "done" then
            primary, pAction = L("di_su_continue"), "fonts_reload"
        elseif st == "error" then
            primary, pAction = L("di_upd_retry"), "fonts_install"
        else
            primary, pAction = L("di_fonts_install"), "fonts_install"
        end
        link, lAction = L("di_su_skip"), "next"
        if st == "done" then
            Setup.FontsAt = Setup.FontsAt or now
            Success.Draw("setup_fonts", Vec2(cx, top + 26 * s), 18 * s, now - Setup.FontsAt, a, s)
        end
    elseif id == "position" then
        local items = { { label = "di_su_pos_top", val = 0 }, { label = "di_su_pos_left", val = 2 }, { label = "di_su_pos_right", val = 3 } }
        local cur = UI.Main.Preset:Get()
        local sel = 0
        for i, it in ipairs(items) do
            if it.val == cur then sel = i end
        end
        Setup.PosSeg = Setup.PosSeg or { v = math.max(0, sel - 1), vel = 0 }
        local keep = HUDCustomizer.InspectorBounds
        HUDCustomizer.InspectorBounds = {}
        Impl.RenderSegmented(gx, top, gw, 30 * s, items, sel > 0 and sel or 1, Setup.PosSeg, Setup.DT or 0.016, s, sel > 0 and a or a * 0.6, "preset")
        if live then
            for _, b in ipairs(HUDCustomizer.InspectorBounds) do
                Setup.Hit(b.x1, b.y1, b.x2, b.y2, "preset", b.val)
            end
        end
        HUDCustomizer.InspectorBounds = keep
        local sy = top + 46 * s
        Setup.Group(gx, sy, gw, 56 * s, a, s)
        local v = UI.Main.Scale:Get()
        Label(L("di_su_size"), sy + 16 * s)
        local vf, vsz = TF("Body", s)
        local vt = tostring(v) .. "%"
        local vs = Render.TextSize(vf, vsz, vt)
        Render.Text(vf, vsz, vt, Vec2(math.floor(gx + gw - 14 * s - vs.x), math.floor(sy + 16 * s - vs.y / 2)), FadeColor(C.TextSecondary, a))
        local tx1, tx2 = gx + 14 * s, gx + gw - 14 * s
        local tyy = sy + 38 * s
        local f = (v - 60) / 120
        Render.FilledRect(Vec2(tx1, tyy - 2 * s), Vec2(tx2, tyy + 2 * s), FadeColor(C.Fill, a), 2 * s)
        Render.FilledRect(Vec2(tx1, tyy - 2 * s), Vec2(tx1 + (tx2 - tx1) * f, tyy + 2 * s), FadeColor(C.Blue, a), 2 * s)
        local kx = tx1 + (tx2 - tx1) * f
        SoftShadow(Vec2(kx - 11 * s, tyy - 11 * s), Vec2(kx + 11 * s, tyy + 11 * s), 11 * s, Color(0, 0, 0, math.floor(90 * a)), 6, Vec2(0, 2))
        Render.FilledCircle(Vec2(kx, tyy), 11 * s, FadeColor(Color(255, 255, 255, 255), a), 0, 1.0, 28)
        Setup.Hit(tx1 - 8 * s, tyy - 14 * s, tx2 + 8 * s, tyy + 14 * s, "slider", { tx1, tx2 })
        local hf, hsz = TF("Footnote", s)
        Impl.TextBlock(hf, hsz, L("di_su_pos_hint"), cx, sy + 66 * s, gw, FadeColor(C.TextSecondary, a), math.floor(15 * s))
    elseif id == "look" then
        local cur = IsPureGlass() and 3 or ((UI.Main.IslandBgColor:Get().r or 0) > 150 and 2 or 1)
        local gap = 10 * s
        local tw = (gw - gap * 2) / 3
        local names = { "di_su_look_dark", "di_su_look_light", "di_su_look_glass" }
        for i = 1, 3 do
            local tx = gx + (i - 1) * (tw + gap)
            local th2 = 74 * s
            local ga = a
            Setup.Group(tx, top, tw, th2, ga, s)
            local pw, ph = tw * 0.72, 22 * s
            local px1, py1 = tx + (tw - pw) / 2, top + (th2 - ph) / 2
            local pill = i == 1 and Color(0, 0, 0, 255) or (i == 2 and Color(242, 242, 247, 255) or Color(255, 255, 255, 40))
            Render.FilledRect(Vec2(px1, py1), Vec2(px1 + pw, py1 + ph), FadeColor(pill, a), ph / 2)
            Render.Rect(Vec2(px1, py1), Vec2(px1 + pw, py1 + ph), FadeColor(i == 3 and Color(255, 255, 255, 90) or Color(255, 255, 255, 28), a), ph / 2, Enum.DrawFlags.None, 1.0)
            local cf, csz = TF("FootnoteEm", s)
            local ctxt = os.date("%H:%M")
            local cts = Render.TextSize(cf, csz, ctxt)
            Render.Text(cf, csz, ctxt, Vec2(math.floor(px1 + (pw - cts.x) / 2), math.floor(py1 + (ph - cts.y) / 2)), FadeColor(i == 2 and Color(0, 0, 0, 255) or Color(255, 255, 255, 255), a))
            local nf, nsz = TF("Footnote", s)
            local nt = L(names[i])
            local ns = Render.TextSize(nf, nsz, nt)
            Render.Text(nf, nsz, nt, Vec2(math.floor(tx + (tw - ns.x) / 2), math.floor(top + th2 + 8 * s)), FadeColor(C.TextPrimary, a))
            local rc = Vec2(tx + tw / 2, top + th2 + 36 * s)
            if cur == i then
                Render.FilledCircle(rc, 10 * s, FadeColor(C.Blue, a), 0, 1.0, 24)
                Glyph("check", rc.x, rc.y, math.floor(13 * s), FadeColor(Color(255, 255, 255, 255), a))
            else
                Render.Circle(rc, 10 * s, FadeColor(C.TextMuted, a), 1.5 * s, 0, 1.0, false, 32)
            end
            Setup.Hit(tx, top, tx + tw, top + th2 + 48 * s, "look", i)
        end
    elseif id == "alerts" then
        local names = { "di_su_al_min", "di_su_al_mid", "di_su_al_all" }
        local rh = 50 * s
        Setup.Group(gx, top, gw, rh * 3, a, s)
        local tf2, tsz2 = TF("Body", s)
        local sf2, ssz2 = TF("Footnote", s)
        for i = 1, 3 do
            local ry = top + (i - 1) * rh
            if i > 1 then
                Render.Line(Vec2(gx + 14 * s, math.floor(ry) + 0.5), Vec2(gx + gw, math.floor(ry) + 0.5), FadeColor(C.Separator, a), 1.0)
            end
            local t1 = L(names[i] .. "_t")
            local t1s = Render.TextSize(tf2, tsz2, t1)
            Render.Text(tf2, tsz2, t1, Vec2(math.floor(gx + 14 * s), math.floor(ry + 9 * s)), FadeColor(C.TextPrimary, a))
            Render.Text(sf2, ssz2, L(names[i] .. "_d"), Vec2(math.floor(gx + 14 * s), math.floor(ry + 11 * s + t1s.y)), FadeColor(C.TextSecondary, a))
            if Setup.AlertPick == i then
                Glyph("check", gx + gw - 22 * s, ry + rh / 2, math.floor(16 * s), FadeColor(C.Blue, a))
            end
            Setup.Hit(gx, ry, gx + gw, ry + rh, "alerts", i)
        end
    elseif id == "likes" then
        Setup.Group(gx, top, gw, rowH * 2, a, s)
        Label(L("di_media_spotify_like"), top + rowH / 2)
        Setup.LikeKnob = Setup.LikeKnob or { v = UI.Media.SpotifyLike:Get() and 1 or 0, vel = 0 }
        Impl.RenderSwitch(gx + gw - 12 * s - 42 * s, top + (rowH - 25 * s) / 2, 42 * s, 25 * s, UI.Media.SpotifyLike:Get(), Setup.LikeKnob, Setup.DT or 0.016, a)
        Setup.Hit(gx, top, gx + gw, top + rowH, "like")
        Render.Line(Vec2(gx + 14 * s, math.floor(top + rowH) + 0.5), Vec2(gx + gw, math.floor(top + rowH) + 0.5), FadeColor(C.Separator, a), 1.0)
        Label(L("di_su_likes_guide"), top + rowH * 1.5, C.Blue)
        Glyph("chevron", gx + gw - 18 * s, top + rowH * 1.5, math.floor(12 * s), FadeColor(C.TextMuted, a))
        Setup.Hit(gx, top + rowH, gx + gw, top + rowH * 2, "like_guide")
    elseif id == "focus" then
        Setup.Group(gx, top, gw, rowH, a, s)
        Label(L("di_su_focus_key"), top + rowH / 2)
        local val = Setup.Capture and L("di_su_focus_press") or Setup.KeyName(UI.Focus.Key:Get())
        local vf, vsz = TF("Body", s)
        local vs = Render.TextSize(vf, vsz, val)
        Render.Text(vf, vsz, val, Vec2(math.floor(gx + gw - 14 * s - vs.x), math.floor(top + rowH / 2 - vs.y / 2)), FadeColor(Setup.Capture and C.Blue or C.TextSecondary, a))
        Setup.Hit(gx, top, gx + gw, top + rowH, "capture")
        local hf, hsz = TF("Footnote", s)
        Impl.TextBlock(hf, hsz, L("di_su_focus_hint"), cx, top + rowH + 10 * s, gw, FadeColor(C.TextSecondary, a), math.floor(15 * s))
    elseif id == "done" then
        primary, pAction = L("di_su_finish"), "done"
        link, lAction = L("di_main_demo"), "demo"
    end

    local total, cur = 0, 0
    for i, sid in ipairs(Setup.Steps) do
        if Setup.Visible(sid) or i == Setup.Step then
            total = total + 1
            if sid == id then cur = total end
        end
    end
    local dy = y + h - 108 * s
    local dgap = 14 * s
    local dx = cx - (total - 1) * dgap / 2
    for i = 1, total do
        Render.FilledCircle(Vec2(dx + (i - 1) * dgap, dy), 3.5 * s, FadeColor(i == cur and C.TextPrimary or C.TextMuted, a), 0, 1.0, 16)
    end
    local bh2 = 48 * s
    Setup.Primary(gx, y + h - 88 * s, gw, bh2, primary, pAction, a, s, busy, ptint)
    Setup.Link(cx, y + h - 22 * s, link, lAction, a, s)
    Setup.HitsOn = false
end

function Setup.Render(layout, dt)
    if Hello.Phase ~= "setup" and Hello.Phase ~= "out" then return end
    if not Setup.Step then return end
    Setup.Anim = math.min(1, math.max(0, Setup.Anim + dt / 0.46 * ((Hello.Phase == "setup" and Setup.Active) and 1 or -1.5)))
    if Setup.Anim <= 0 then return end
    local x, y, w, h, s = Setup.Geometry(layout)
    local emerge = EaseOutCubic(Setup.Anim / 0.55)
    local widen = EaseOutBack((Setup.Anim - 0.25) / 0.75)
    local contentA = math.min(1, math.max(0, (Setup.Anim - 0.55) / 0.45))
    local pw = layout.w + (w - layout.w) * math.max(0, widen)
    local ph = h * emerge
    local px = math.floor(layout.x + layout.w / 2 - pw / 2)
    px = math.max(math.min(px, x), math.min(x + w - pw, px))
    local py = math.floor(layout.y + layout.h + 12 * s * emerge)
    local rad = math.min(30 * s, ph / 2)
    local p1, p2 = Vec2(px, py), Vec2(px + pw, py + ph)
    SoftShadow(p1, p2, rad, Color(0, 0, 0, math.floor(200 * emerge)), 30, Vec2(0, 8))
    DrawerSurface(p1, p2, rad, emerge)
    Setup.Hits = {}
    Setup.DT = dt
    if contentA <= 0.01 then return end
    Setup.PT, Setup.PTV = MotionEngine.Step(Setup.PT, Setup.PTV, 1, dt, "SMOOTH")
    local pt = math.min(1, math.max(0, Setup.PT))
    local now = os.clock()
    Render.PushClip(Vec2(px + 3 * s, py), Vec2(px + pw - 3 * s, py + ph))
    local dir = Setup.Dir or 1
    local shift = w * 0.28
    if Setup.Prev and pt < 0.995 then
        local oa = contentA * math.max(0, 1 - pt * 1.6)
        if oa > 0.01 then
            Setup.Page(Setup.Steps[Setup.Prev], x - dir * shift * pt, y, w, h, oa, s, false, now)
        end
    end
    local na = contentA * math.min(1, math.max(0, (pt - 0.25) / 0.75))
    if Setup.Prev == nil or pt >= 0.995 then na = contentA end
    Setup.Page(Setup.Steps[Setup.Step], x + dir * shift * (1 - pt), y, w, h, na, s, pt > 0.9 and contentA > 0.9, now)
    Render.PopClip()
end

Pointer.S = {}
Pointer.x, Pointer.y, Pointer.px, Pointer.py = -10000, -10000, -10000, -10000
Pointer.down, Pointer.pressed, Pointer.off = false, false, false
Pointer.dt, Pointer.Frame = 0.016, 0

function Pointer.Update(dt)
    local mx, my = Input.GetCursorPos()
    local down = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1)
    Pointer.pressed = down and not Pointer.down
    if Pointer.pressed then Pointer.px, Pointer.py = mx, my end
    Pointer.x, Pointer.y, Pointer.down = mx, my, down
    Pointer.dt = dt
    Pointer.Frame = Pointer.Frame + 1
    Pointer.off = Hello.Blocking() or DragState.IsDragging
end

function Pointer.Button(key, x1, y1, x2, y2)
    local st = Pointer.S[key]
    if not st then
        st = { h = 0, hv = 0, p = 0, pv = 0, f = -1 }
        Pointer.S[key] = st
    end
    if st.f ~= Pointer.Frame then
        st.f = Pointer.Frame
        local over = not Pointer.off and Pointer.x >= x1 and Pointer.x <= x2 and Pointer.y >= y1 and Pointer.y <= y2
        local press = over and Pointer.down and Pointer.px >= x1 and Pointer.px <= x2 and Pointer.py >= y1 and Pointer.py <= y2
        st.h, st.hv = MotionEngine.Step(st.h, st.hv, over and 1 or 0, Pointer.dt, "SMOOTH")
        st.p, st.pv = MotionEngine.Step(st.p, st.pv, press and 1 or 0, Pointer.dt, "SNAPPY")
    end
    return math.max(0, math.min(1, st.h)), math.max(0, math.min(1, st.p))
end

function Impl.PointerBlob(key, cx, cy, r, hit, aMul)
    local hk, pk = Pointer.Button(key, hit.x1, hit.y1, hit.x2, hit.y2)
    if hk > 0.01 then
        Render.FilledCircle(Vec2(cx, cy), r * (0.8 + 0.2 * hk), FadeColor(Config.Colors.FillTertiary, aMul * hk * (1 + 0.6 * pk)), 0, 1.0, 32)
    end
    return 1 + 0.06 * hk - 0.12 * pk, 1 - 0.35 * pk
end

function Impl.TickArt(dt)
    local want = MediaData.IsPlaying and 1 or 0.84
    MediaData.ArtK = MediaData.ArtK or want
    MediaData.ArtKV = MediaData.ArtKV or 0
    MediaData.ArtK, MediaData.ArtKV = MotionEngine.Step(MediaData.ArtK, MediaData.ArtKV, want, dt, want > MediaData.ArtK and "BOUNCY" or "SMOOTH")
end

function Impl.DismissNotif(nowClk)
    if Dbg.On then Dbg.Log("notif", "dismissed by the user") end
    local inCombat = FightTracker.Active
    local mediaActive = IsMediaActive()
    NotificationQueue.LastDismissed = NotificationQueue.Active
    NotificationQueue.Active = nil
    HapticPlaySound("toast_dismiss", 0.45)
    if StateMachine.Spring and StateMachine.Spring.Squish then
        StateMachine.Spring.Squish.value = -0.32
        StateMachine.Spring.Squish.vel = -2.2
    end
    if #NotificationQueue.List > 0 then
        NotificationQueue.Active = Impl.PopHighestPriorityNotif()
        NotificationQueue.StartTime = nowClk
    end
    if NotificationQueue.Active and not IsNotifDeferred(NotificationQueue.Active) then
        TriggerStateTransition(StateMachine.States.NOTIFICATION)
    else
        local target = Impl.RestState() or (inCombat and StateMachine.States.COMPACT_FIGHT or (mediaActive and StateMachine.States.COMPACT_MEDIA or StateMachine.States.COMPACT_IDLE))
        TriggerStateTransition(target)
    end
end

function Impl.DismissSatellite(kind, nowClk)
    if Dbg.On then Dbg.Log("notif", "side bubble " .. tostring(kind) .. " swiped away") end
    if kind == "notif" then
        NotificationQueue.LastDismissed = NotificationQueue.Active
        NotificationQueue.Active = nil
        if #NotificationQueue.List > 0 then
            NotificationQueue.Active = Impl.PopHighestPriorityNotif()
            NotificationQueue.StartTime = nowClk
        end
    elseif kind == "activity" then
        Sdk.ActEnd(Satellite.Right.act, "dismissed")
    elseif kind == "aegis" then
        GameTracker.Roshan.Dismissed = true
    elseif kind == "search" then
        Impl.MenuSearchHidden = true
    elseif kind then
        Impl.SatHidden[kind] = true
    end
    HapticPlaySound("toast_dismiss", 0.45)
end

Swipe.G = Gesture.New()
Swipe.IslandX, Swipe.IslandV = 0, 0
Swipe.SatX, Swipe.SatV = 0, 0

function Swipe.Start(x, y)
    local S = StateMachine.States
    local ctrl = Input.IsKeyDown(Enum.ButtonCode.KEY_LCONTROL) or Input.IsKeyDown(Enum.ButtonCode.KEY_RCONTROL)
    if ctrl or Hello.Blocking() or DragState.IsDragging or Demo.Active or HUDCustomizer.IsOpen then return false end
    local l = Swipe.Layout
    local inside = l and x >= l.x and x <= l.x + l.w and y >= l.y and y <= l.y + l.h
    if StateMachine.TargetState == S.NOTIFICATION and NotificationQueue.Active and inside then
        Swipe.Target = "island"
        Swipe.IslandKind = "notif"
        Sdk.PressAt = os.clock()
        return true
    end
    if (StateMachine.TargetState == S.ACTIVITY or StateMachine.TargetState == S.ACTIVITY_LARGE) and Sdk.Current() and inside then
        Swipe.Target = "island"
        Swipe.IslandKind = "activity"
        Sdk.PressAt = os.clock()
        return true
    end
    local sb = SatelliteBounds
    local kind = Satellite.Right.kind
    if sb and kind and x >= sb.x1 and x <= sb.x2 and y >= sb.y1 and y <= sb.y2 then
        for _, key in ipairs({ "SatellitePrev", "SatellitePlay", "SatelliteNext" }) do
            local h = ButtonHits[key]
            if h and x >= h.x1 and x <= h.x2 and y >= h.y1 and y <= h.y2 then return false end
        end
        Swipe.Target = "sat"
        Swipe.SatKind = kind
        Swipe.SatPressAt = os.clock()
        Swipe.SatHeld = false
        return true
    end
    if StateMachine.TargetState == S.NOTIF_CENTER then
        for _, r in ipairs(NotifCenter.RowHits) do
            if x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2 then
                Swipe.Target = "nc"
                Swipe.Row = r.row
                return true
            end
        end
    end
    return false
end

function Swipe.Tick(layout, now, dt)
    Swipe.Layout = layout
    local g = Swipe.G
    local ev = Gesture.Step(g, Pointer.down, Pointer.x, Pointer.y, now, Swipe.Start)
    local s = layout.scale
    local t = Swipe.Target
    if g.active then
        local dx, dy = g.x - g.x0, g.y - g.y0
        if t == "island" then
            Swipe.IslandX, Swipe.IslandV = dx * 0.85, 0
        elseif t == "sat" then
            Swipe.SatX, Swipe.SatV = dx * 0.85, 0
            if not g.moved and not Swipe.SatHeld and now - (Swipe.SatPressAt or now) >= 0.35 * AnimScale() then
                Swipe.SatHeld = true
                Impl.SwapWithBubble()
            end
        elseif t == "nc" and Swipe.Row then
            local it = Swipe.Row.item
            it._x, it._xv = dx < 0 and dx or Gesture.Rubber(dx, 14 * s), 0
        end
    elseif ev == "end" then
        local dx, dy = g.x - g.x0, g.y - g.y0
        if Dbg.On and t then
            local what = t == "island" and ("island " .. tostring(Swipe.IslandKind)) or t == "sat" and ("side bubble " .. tostring(Swipe.SatKind)) or "notification center row"
            local how = Swipe.SatHeld and "hold" or g.moved and string.format("swipe %+d px, %d px/s", math.floor(dx), math.floor(g.vx or 0)) or "tap"
            Dbg.Log("input", how .. " on the " .. what)
        end
        if t == "island" then
            local far = g.moved and math.abs(dx) > 6 and (math.abs(dx) > 28 * s or math.abs(g.vx) > 600)
            if far then StateMachine.NoExpand = true end
            if Swipe.IslandKind == "activity" then
                if far then
                    Sdk.Dismiss(Sdk.Current())
                elseif not g.moved and StateMachine.TargetState == StateMachine.States.ACTIVITY_LARGE and not (Sdk.ExpandedAt and Sdk.ExpandedAt >= (Sdk.PressAt or 0)) then
                    Sdk.TapActivity()
                end
            elseif far then
                Impl.DismissNotif(now)
            elseif not g.moved then
                Sdk.TapNotif(now)
            end
        elseif t == "sat" then
            if Swipe.SatHeld then
                Swipe.SatHeld = false
            elseif g.moved and math.abs(dx) > 6 and (math.abs(dx) > 24 * s or math.abs(g.vx) > 600) then
                Impl.DismissSatellite(Swipe.SatKind, now)
            elseif not g.moved and Swipe.SatKind == "activity" then
                Sdk.TapActivity(Satellite.Right.act)
            end
        elseif t == "nc" and Swipe.Row then
            local it = Swipe.Row.item
            if g.moved and dx < -6 and (dx < -layout.w * 0.33 or g.vx < -700) then
                it._gone = true
                HapticPlaySound("toast_dismiss", 0.45)
            elseif not g.moved then
                if it.onTap and Swipe.Row.count == 1 then
                    Haptic.Trigger(Haptic.Types.TAP_MEDIUM)
                    it._gone = true
                    Sdk.Call(it.app, it.onTap)
                else
                    NotifCenter.Toggle(Swipe.Row)
                end
            end
        end
        Swipe.Target = nil
        Swipe.Row = nil
    end
    if not (g.active and t == "island") then
        Swipe.IslandX, Swipe.IslandV = MotionEngine.Step(Swipe.IslandX, Swipe.IslandV, 0, dt, "BOUNCY")
    end
    if not (g.active and t == "sat") then
        Swipe.SatX, Swipe.SatV = MotionEngine.Step(Swipe.SatX, Swipe.SatV, 0, dt, "BOUNCY")
    end
end


local LastMenuOpenState = false

function Impl.RenderPlaylistPicker(layout)
    if not PlaylistPicker.Open then return end
    local screen = Render.ScreenSize()
    local scale = layout.scale
    local width = math.min(360 * scale, screen.x - 24)
    local count = math.min(6, #PlaylistPicker.Items)
    local height = (PlaylistPicker.Loading or PlaylistPicker.Error) and 82 * scale or (53 + count * 34) * scale
    local x = math.max(12, math.min(screen.x - width - 12, layout.x + layout.w / 2 - width / 2))
    local y = layout.y + layout.h + 10 * scale
    if y + height > screen.y - 12 then y = math.max(12, layout.y - height - 10 * scale) end
    if UI.Media.Shadow:Get() then
        SoftShadow(Vec2(x, y), Vec2(x + width, y + height), 14 * scale, Config.Colors.Shadow, 16, Vec2(0, 3))
    end
    IslandSurface(Vec2(x, y), Vec2(x + width, y + height), 14 * scale, Config.Colors.Border, UI.Main.BorderThickness:Get())
    local font, size = TF("FootnoteEm", scale)
    local normal, small = TF("Footnote", scale)
    Render.Text(font, size, L("di_playlist_title"), Vec2(x + 16 * scale, y + 12 * scale), Config.Colors.TextPrimary)
    Render.Text(font, size, "×", Vec2(x + width - 28 * scale, y + 12 * scale), Config.Colors.TextSecondary)
    PlaylistPicker.Hits = { Bounds = { x1 = x, x2 = x + width, y1 = y, y2 = y + height }, Close = { x1 = x + width - 42 * scale, x2 = x + width, y1 = y, y2 = y + 40 * scale }, Rows = {} }
    if PlaylistPicker.Loading or PlaylistPicker.Error then
        Render.PushClip(Vec2(x + 12 * scale, y + 42 * scale), Vec2(x + width - 12 * scale, y + height))
        Render.Text(normal, small, PlaylistPicker.Loading and L("di_playlist_loading") or PlaylistPicker.Error, Vec2(x + 16 * scale, y + 47 * scale), Config.Colors.TextSecondary)
        Render.PopClip()
        return
    end
    local cx, cy = Input.GetCursorPos()
    for row = 1, count do
        local index = PlaylistPicker.Offset + row
        local rowY = y + (44 + (row - 1) * 34) * scale
        local hit = { x1 = x + 8 * scale, x2 = x + width - 8 * scale, y1 = rowY, y2 = rowY + 32 * scale, index = index }
        PlaylistPicker.Hits.Rows[#PlaylistPicker.Hits.Rows + 1] = hit
        if cx >= hit.x1 and cx <= hit.x2 and cy >= hit.y1 and cy <= hit.y2 then
            Render.FilledRect(Vec2(hit.x1, hit.y1), Vec2(hit.x2, hit.y2), Config.Colors.FillSecondary, 7 * scale)
        end
        Render.PushClip(Vec2(hit.x1 + 8 * scale, hit.y1), Vec2(hit.x2 - 30 * scale, hit.y2))
        Render.Text(normal, small, PlaylistPicker.Items[index], Vec2(hit.x1 + 8 * scale, rowY + 7 * scale), Config.Colors.TextPrimary)
        Render.PopClip()
        if PlaylistPicker.Selected[index] then
            local check = GetVectorIcon("check")
            if check then
                local sz = 14 * scale
                Impl.Img(check, Vec2(hit.x2 - 24 * scale, rowY + (32 * scale - sz) / 2), Vec2(sz, sz), Config.Colors.Green, 0)
            end
        end
    end
end

function DynamicIsland.OnFrame()
    if not UI or not UI.Main.Enabled:Get() then return end
    ContentFx.Glass = IsPureGlass()
    Render.Text = ContentFx.Glass and ContentFx.TextOut or nil
    local inGame = Engine.IsInGame and Engine.IsInGame()
    if UI.Main.OnlyInGame:Get() and not inGame then return end
    if Journey.Hidden then return end

    if Menu.Opened then
        local isOpened = Menu.Opened()
        if LastMenuOpenState and not isOpened then
            SaveAllConfig()
        end
        LastMenuOpenState = isOpened
        if isOpened then Impl.AutoSave(os.clock()) end
    end

    local curClock = os.clock()
    local dt = 0.016
    if StateMachine.LastDrawTime > 0 then
        dt = math.min(0.04, math.max(0.001, curClock - StateMachine.LastDrawTime))
    end
    StateMachine.LastDrawTime = curClock
    Impl.AdvancePosition(dt)
    dt = dt / AnimScale()
    Pointer.Update(dt)
    Impl.TickArt(dt)
    Fuse.Guard("lyrics", Impl.LyTick, dt)
    Fuse.Guard("sdk", Sdk.Tick, curClock)

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
        local nC, nVC = MotionEngine.Step(VolumeState.Current or 50.0, VolumeState.CurrentVel or 0.0, VolumeState.Target or 50.0, dt, "SNAPPY", 0.1)
        VolumeState.Current = nC
        VolumeState.CurrentVel = nVC
        local nO, nVO = MotionEngine.Step(VolumeState.Overstretch or 0.0, VolumeState.OverstretchVel or 0.0, 0.0, dt, "SNAPPY", 0.15)
        VolumeState.Overstretch = nO
        VolumeState.OverstretchVel = nVO
    end

    Impl.A11yTick()
    local isPureGlass = IsPureGlass()
    local currentBg = UI.Main.IslandBgColor:Get()
    local targetFactor = ThemeSpring.target
    if not isPureGlass and currentBg then
        local lum = (currentBg.r * 0.299 + currentBg.g * 0.587 + currentBg.b * 0.114)

        if targetFactor > 0.5 then
            if lum < 120 then targetFactor = 0.0 end
        else
            if lum > 150 then targetFactor = 1.0 end
        end
    else
        targetFactor = 0.0
    end
    ThemeSpring.target = targetFactor

    local nF, nV = MotionEngine.Step(ThemeSpring.factor, ThemeSpring.vel, targetFactor, dt, "SMOOTH")
    ThemeSpring.factor = nF
    ThemeSpring.vel = nV

    local f = math.min(1.0, math.max(0.0, ThemeSpring.factor))
    local hc = Impl.HighContrast and true or false
    if f ~= ThemeSpring.LastF or hc ~= ThemeSpring.LastHC then
        ThemeSpring.LastF = f
        ThemeSpring.LastHC = hc
        local C = Config.Colors
        local function D(r1, g1, b1, a1, r2, g2, b2, a2)
            return LerpColor(Color(r1, g1, b1, a1), Color(r2, g2, b2, a2), f)
        end
        C.TextPrimary = D(255, 255, 255, 255, 0, 0, 0, 255)
        C.TextSecondary = hc and D(235, 235, 245, 210, 40, 40, 45, 210) or D(235, 235, 245, 153, 60, 60, 67, 153)
        C.TextMuted = hc and D(235, 235, 245, 150, 40, 40, 45, 150) or D(235, 235, 245, 77, 60, 60, 67, 77)
        C.TextQuaternary = hc and D(235, 235, 245, 110, 40, 40, 45, 110) or D(235, 235, 245, 46, 60, 60, 67, 46)
        C.TextInverse = D(0, 0, 0, 255, 255, 255, 255, 255)
        C.Separator = hc and D(120, 120, 128, 220, 40, 40, 45, 150) or D(84, 84, 88, 153, 60, 60, 67, 74)
        C.Fill = hc and D(140, 140, 150, 130, 100, 100, 110, 90) or D(120, 120, 128, 92, 120, 120, 128, 51)
        C.FillSecondary = hc and D(140, 140, 150, 115, 100, 100, 110, 75) or D(120, 120, 128, 82, 120, 120, 128, 41)
        C.FillTertiary = hc and D(135, 135, 148, 95, 100, 100, 110, 60) or D(118, 118, 128, 61, 118, 118, 128, 31)
        C.FillQuaternary = hc and D(130, 130, 145, 75, 100, 100, 110, 45) or D(118, 118, 128, 46, 116, 116, 128, 20)
        C.Border = hc and D(255, 255, 255, 90, 0, 0, 0, 110) or D(255, 255, 255, 28, 0, 0, 0, 35)
        C.SegThumb = D(99, 99, 102, 255, 255, 255, 255, 255)
        C.ChipActiveBorder = D(255, 255, 255, 255, 0, 0, 0, 255)
        C.Red = hc and D(255, 105, 97, 255, 215, 0, 21, 255) or D(255, 69, 58, 255, 255, 59, 48, 255)
        C.Orange = hc and D(255, 179, 64, 255, 201, 52, 0, 255) or D(255, 159, 10, 255, 255, 149, 0, 255)
        C.Yellow = hc and D(255, 212, 38, 255, 178, 80, 0, 255) or D(255, 214, 10, 255, 255, 204, 0, 255)
        C.Green = hc and D(48, 219, 91, 255, 36, 138, 61, 255) or D(48, 209, 88, 255, 52, 199, 89, 255)
        C.Mint = hc and D(102, 212, 207, 255, 12, 129, 123, 255) or D(99, 230, 226, 255, 0, 199, 190, 255)
        C.Teal = hc and D(93, 230, 255, 255, 0, 130, 153, 255) or D(64, 200, 224, 255, 48, 176, 199, 255)
        C.Cyan = hc and D(112, 215, 255, 255, 0, 113, 164, 255) or D(100, 210, 255, 255, 50, 173, 230, 255)
        C.Blue = hc and D(64, 156, 255, 255, 0, 64, 221, 255) or D(10, 132, 255, 255, 0, 122, 255, 255)
        C.Indigo = hc and D(125, 122, 255, 255, 54, 52, 163, 255) or D(94, 92, 230, 255, 88, 86, 214, 255)
        C.Purple = hc and D(218, 143, 255, 255, 137, 68, 171, 255) or D(191, 90, 242, 255, 175, 82, 222, 255)
        C.Pink = hc and D(255, 100, 130, 255, 211, 15, 69, 255) or D(255, 55, 95, 255, 255, 45, 85, 255)
        C.Brown = hc and D(181, 148, 105, 255, 127, 101, 69, 255) or D(172, 142, 104, 255, 162, 132, 94, 255)
        C.TrackProgressBg = C.Fill
        C.ChipInactive = C.FillTertiary
        C.SegTrack = C.FillTertiary
        C.Group = D(118, 118, 128, 61, 255, 255, 255, 255)
        C.Grabber = C.TextMuted
        C.Placeholder = D(58, 58, 60, 255, 229, 229, 234, 255)
    end

    if inGame and CachedDotaMapHandle == nil and os.clock() - LastMapWarmCheck > 10.0 then
        LastMapWarmCheck = os.clock()
        Impl.GetDotaMapTexture()
    end

    PerformanceData.FrameCount = PerformanceData.FrameCount + 1
    if curClock - PerformanceData.LastFPSUpdate >= 0.5 then
        local elapsed = curClock - PerformanceData.LastFPSUpdate
        local raw = PerformanceData.FrameCount / elapsed
        PerformanceData.FrameCount = 0
        PerformanceData.LastFPSUpdate = curClock
        local ema = PerformanceData.FpsEma or raw
        local k = (math.abs(raw - ema) / math.max(1, ema) > 0.15) and 0.75 or 0.35
        ema = ema + (raw - ema) * k
        PerformanceData.FpsEma = ema
        local shown = PerformanceData.FPS
        if not PerformanceData.FpsShown or math.abs(ema - shown) >= math.max(3, shown * 0.03) then
            PerformanceData.FPS = math.floor(ema + 0.5)
            PerformanceData.FpsShown = true
        end
    end

    local scale = (UI and UI.Main and UI.Main.Scale) and (UI.Main.Scale:Get() / 100.0) or 1.0

    local targetW = Config.Dimensions.CompactTargetW or Config.Dimensions.CompactW
    local targetH = Config.Dimensions.CompactTargetH or Config.Dimensions.CompactH
    local targetR = Config.Dimensions.CompactTargetR or Config.Dimensions.CompactRadius
    local trq = StateMachine.Transition
    if trq.SqueezeUntil and curClock >= trq.SqueezeUntil then trq.SqueezeUntil = nil end
    if trq.SqueezeUntil then
        targetW = math.min(targetW, trq.SqueezeW)
        targetH = math.min(targetH, Config.Dimensions.CompactH)
        targetR = math.min(targetR, targetH / 2)
    end

    local prof = MotionEngine.GetProfile(trq.SqueezeUntil and "SNAPPY" or MotionEngine.CurrentProfile)
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

    local squishProf = MotionEngine.GetProfile("SNAPPY")
    local newSq, newVelSq = MotionEngine.SolveSpring(StateMachine.Spring.Squish.value, StateMachine.Spring.Squish.vel, 0, smoothDt, squishProf.omega, squishProf.zeta)
    StateMachine.Spring.Squish.value = newSq
    StateMachine.Spring.Squish.vel = newVelSq

    local btnProf = MotionEngine.GetProfile("SNAPPY")
    for btnName, btnData in pairs(ButtonSprings) do
        local nS, nV = MotionEngine.SolveSpring(btnData.scale, btnData.vel, 1.0, smoothDt, btnProf.omega, btnProf.zeta)
        btnData.scale = nS
        btnData.vel = nV
    end

    local tr = StateMachine.Transition
    if tr.Active then
        local tW = Config.Dimensions.CompactTargetW or Config.Dimensions.CompactW
        local tH = Config.Dimensions.CompactTargetH or Config.Dimensions.CompactH
        local d = math.abs(StateMachine.Spring.W.value - tW) + math.abs(StateMachine.Spring.H.value - tH)
        if not tr.Dist0 or d > tr.Dist0 then
            tr.Dist0 = d
            tr.Shrink = tW * tH < StateMachine.Spring.W.value * StateMachine.Spring.H.value
        end
        local elapsed = curClock - tr.StartTime
        local p
        if tr.Dist0 > 3 then
            p = 1 - d / tr.Dist0
        else
            p = elapsed / (0.25 * AnimScale())
        end
        p = math.max(p, elapsed / (1.6 * AnimScale()))
        p = math.max(tr.Progress or 0, math.min(1, math.max(0, p)))
        tr.Progress = p
        local settled = true
        if tr.SharedPair then
            local m = StateMachine.SharedM(tr.SharedPair)
            settled = (m <= 0 or m >= 1) or elapsed > 2.5 * AnimScale()
        end
        if p >= 0.999 and settled then
            tr.Active = false
            tr.SharedPair = nil
            tr.Reveal = 1
            StateMachine.Current = StateMachine.TargetState
        end
    else
        StateMachine.Current = StateMachine.TargetState
    end
    if not tr.Active and NotificationQueue.LastDismissed and StateMachine.TargetState ~= StateMachine.States.NOTIFICATION then
        local held = false
        for _, g in ipairs(StateMachine.Ghosts) do
            if g.state == StateMachine.States.NOTIFICATION then held = true end
        end
        if not held then NotificationQueue.LastDismissed = nil end
    end

    if Haptic and Haptic.Update then
        Haptic.Update(dt)
    end

    local layout = GetIslandLayout()
    if layout.w <= 0 or layout.h <= 0 then return end

    Fuse.Guard("swipe", Swipe.Tick, layout, os.clock(), dt)
    Fuse.Guard("hello", Hello.RenderBack, layout, dt)
    Impl.RenderDragGuides(layout)

    local p1 = Vec2(layout.x, layout.y)
    local p2 = Vec2(layout.x + layout.w, layout.y + layout.h)

    if UI.Media.Shadow:Get() then
        SoftShadow(p1, p2, layout.r, Config.Colors.Shadow, 16, Vec2(0, 3))
    end

    local borderW = (UI and UI.Main and UI.Main.BorderThickness) and UI.Main.BorderThickness:Get() or 1.0
    IslandSurface(p1, p2, layout.r, HUDCustomizer.IsOpen and Config.Colors.PMenuIslandBorder or Config.Colors.Border, HUDCustomizer.IsOpen and math.max(1.2, borderW) or borderW)

    if Haptic and Haptic.State and Haptic.State.GlowAlpha > 1.0 then
        local gAlpha = math.min(255, math.floor(Haptic.State.GlowAlpha))
        local gCol = Haptic.State.GlowColor or Color(255, 255, 255, 255)
        local tactileBorderCol = Color(gCol.r, gCol.g, gCol.b, math.floor(gCol.a * (gAlpha / 255)))
        Render.Rect(p1, p2, tactileBorderCol, layout.r, Enum.DrawFlags.None, 1.8)
    end

    Render.PushClip(p1, p2)

    Sheet.Hits = {}
    NotifCenter.Hits = {}
    Impl.RenderContent(layout, dt)

    if VolumeState.Visible and VolumeState.Alpha > 0.01 then
        Impl.RenderVolumeOverlay(layout, VolumeState.Alpha)
    end

    Render.PopClip()

    Fuse.Guard("badge", Sheet.RenderBadge, layout)
    Fuse.Guard("satellite", Impl.RenderSecondarySatelliteBubble, layout)
    Fuse.Guard("focus_bubble", Focus.RenderBubble, layout)
    Fuse.Guard("rec_bubble", Dbg.RenderBubble, layout)
    Fuse.Guard("hints", Impl.RenderMenuClosedHint, layout)
    Fuse.Guard("drawer", Impl.RenderHUDDrawer, layout, dt)
    Fuse.Guard("setup", Setup.Render, layout, dt)
    Fuse.Guard("playlist", Impl.RenderPlaylistPicker, layout)
end

function DynamicIsland.OnUpdateEx()
    if PlaylistPicker.Open and PlaylistPicker.Loading and PlaylistPicker.RetryAt > 0 and os.clock() >= PlaylistPicker.RetryAt then
        PlaylistPicker.RetryAt = 0
        PlaylistPicker.Loading = false
        Impl.OpenPlaylistPicker(true)
    end
    local inGame = Engine.IsInGame and Engine.IsInGame()
    if inGame then
        WasInGame = true
        HeroData.Local = (Heroes and Heroes.GetLocal) and Heroes.GetLocal() or nil
        if HeroData.Local and HeroData.HeroName == "" then
            HeroData.HeroName = NPC.GetUnitName(HeroData.Local)
        end
        if HeroData.Local and not Demo.Active then
            Fuse.Guard("fight", Impl.ProcessFightDetector)
        end
        Fuse.Guard("events", Impl.ProcessGameEvents)
        Fuse.Guard("reminders", Reminders.Tick)
        Fuse.Guard("rampage", Rampage.Tick)
        if not Demo.Active then
            Fuse.Guard("pause", Impl.ProcessPauseTracker)
            Fuse.Guard("courier", Impl.ProcessCourierTracker)
        end
    else
        if WasInGame then
            WasInGame = false
            HeroData.KillsSeen = -1
            HeroData.LastKillTime = -100
            HeroData.MultiKill = 0
            HeroData.EnemyDeathTime = {}
            Rampage.Count = 0
            Rampage.Active = false
            Reminders.Fired = {}
            if Focus.Active and Focus.Mode == 3 then
                Focus.Set(false)
            end
            GameTracker.Towers.LastHP = {}
            GameTracker.Towers.LastAlert = {}
            GameTracker.Couriers.LastHP = {}
            HeroData.LowHPCache = {}
            HeroData.EnemyInventoryCache = {}
            HeroData.EnemyHeroes = {}
            FightTracker.HeroHPMap = {}
            FightTracker.LastDamageTimes = {}

            GameTracker.Runes.WarnedMilestones = {}
            GameTracker.Runes.KnownWorldRunes = {}
            GameTracker.Neutrals.Tier1 = false
            GameTracker.Neutrals.Tier2 = false
            GameTracker.Neutrals.Tier3 = false
            GameTracker.Neutrals.Tier4 = false
            GameTracker.Neutrals.Tier5 = false
            GameTracker.Tormentor.Warned1 = false
            GameTracker.Tormentor.Warned2 = false
            GameTracker.Lotus.LastAlertTime = 0
            GameTracker.Buybacks = {}
            GameTracker.Roshan.IsAlive = true
            GameTracker.Roshan.DeathTime = 0
            GameTracker.Roshan.AegisExpiryTime = 0
            GameTracker.Roshan.AegisHolder = nil
            GameTracker.Roshan.HasAegis = false
            GameTracker.Roshan.LastAttackAlert = 0
            GameTracker.Roshan.LastHP = nil
            GameTracker.Roshan.HpAt = nil
            GameTracker.Roshan.HpLogged = nil
            GameTracker.Roshan.AegisClaimedAt = nil
            GameTracker.Roshan.AegisClaimedBy = nil
            GameTracker.Roshan.Dismissed = false
        end
        HeroData.Local = nil
        PauseTracker.IsPaused = false
        PauseTracker.PauseStartTime = 0
        CourierTracker.Delivering = false
        CourierTracker.Delivered = false
        CourierTracker.IsGoingToStash = false
        CourierTracker.Progress = 0.0
        CourierTracker.StartDistance = 0
        CourierTracker.ViaStash = false
        CourierTracker.Carry = 0
        CourierTracker.Block = false
        CourierTracker.Zone.In = nil
        CourierTracker.Zone.Out = nil
        CourierTracker.Zone.PrevAt = nil
        CourierTracker.BasePos = nil
        CourierTracker.CachedCourier = nil
    end
    MouseInput.LiveAt = os.clock()
    Fuse.Guard("camera", Impl.CameraTick)
    Fuse.Guard("input", Impl.HandleInteractions)
    Fuse.Guard("media", Impl.PollMediaBridge)
    Fuse.Guard("level", Impl.PollLevel)
    Fuse.Guard("bridge", Impl.PollBridgeStatus)
    Fuse.Guard("system", Impl.PollSystem)
    Fuse.Guard("updater", Sheet.PollUpdate)
end

function DynamicIsland.OnScriptsLoaded()
    Impl.LoadScriptFonts()
    Impl.InitMenu()
    Impl.LoadAllConfig()
    UI.Main.Enabled:Set(true)
    Sheet.ConfigLoaded = true
    Sdk.Ready = true
    if not Impl.HadConfig and UI.Main.Scale:Get() == 100 then
        local scr = Render.ScreenSize()
        local auto = math.floor(math.max(80, math.min(180, scr.y / 1080 * 100)) / 5 + 0.5) * 5
        if auto ~= 100 then UI.Main.Scale:Set(auto) end
    end

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

    Impl.PollMediaBridge()
    Hello.Init()
    if UI.Main.Debug:Get() then Dbg.Start("script loaded") end
end

do
    local function Finish(name, ok, ...)
        if ok then return ... end
        ContentFx.End()
        Fuse.Unwind(0)
        Fuse.Fail(name, (...))
    end
    local function Timed(name, t0, ok, ...)
        Perf.Add(name, Perf.Now() - t0)
        return Finish(name, ok, ...)
    end
    for name, fn in pairs(DynamicIsland) do
        if type(fn) == "function" and string.sub(name, 1, 2) == "On" then
            DynamicIsland[name] = function(...)
                if Dbg.On then
                    if name == "OnFrame" then pcall(Dbg.Tick) end
                    if Dbg.TB then return Timed(name, Perf.Now(), xpcall(fn, Dbg.Trace, ...)) end
                    return Timed(name, Perf.Now(), pcall(fn, ...))
                end
                return Finish(name, pcall(fn, ...))
            end
        end
    end
end

PublishIsland(Sdk.Facade)

return DynamicIsland
