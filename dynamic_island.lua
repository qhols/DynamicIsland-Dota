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
				for key in path:gmatch("[^.]+") do
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
			local code = name:match("%a+")

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
local Render = setmetatable({}, { __index = Render })

local DynamicIsland = {}

local localization = qLocalization.new({
    en = {
        di_ui_spotify_no_port = "Spotify is running without the debug port, likes won't work. Restart it",
        di_ui_likes_unavailable = "Likes unavailable",
        di_ui_restart_spotify = "Restart Spotify from the taskbar or Start",
        di_rampage_timer = "Rampage timer",
        di_rampage_timer_tip = "After an Ultra Kill, shows how long you have left to get the fifth",
        di_streak_mega_kill = "Mega Kill!",
        di_streak_unstoppable = "Unstoppable!",
        di_streak_wicked_sick = "Wicked Sick!",
        di_streak_godlike = "Godlike!",
        di_group_live = "Live Activities",
        di_group_alerts_all = "All Alerts",
        di_toast_duration_tip = "Used by every alert that has no duration of its own",
        di_alert_duration = "Duration",
        di_alert_duration_tip = "0 uses the shared duration from the top of the page",
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
        di_alert_priority_tip = "When alerts collide, the higher one shows first",
        di_media_priority_tip = "Alerts at or below this priority won't cover the player",
        di_runes_neutrals = "Neutral Item Tiers",
        di_tab_focus = "Focus",
        di_tab_focus_group = "Do Not Disturb",
        di_tab_reminders_group = "Reminders",
        di_focus_key = "Toggle key",
        di_focus_key_tip = "Or tap the Do Not Disturb tile in the expanded island",
        di_focus_until = "Turn off",
        di_focus_until_off = "When I turn it off",
        di_focus_until_10 = "In 10 minutes",
        di_focus_until_20 = "In 20 minutes",
        di_focus_until_match = "When the match ends",
        di_focus_urgent = "Let urgent alerts through",
        di_focus_urgent_tip = "Alerts with priority 5 still show up",
        di_focus_moon_tint = "Moon in artwork color",
        di_focus_moon_tint_tip = "While music plays, the Do Not Disturb moon takes the color of the cover",
        di_focus_name = "Do Not Disturb",
        di_focus_on = "On",
        di_focus_off = "Off",
        di_focus_summary_tag = "Do Not Disturb",
        di_focus_summary = "Alerts hidden: %d",
        di_focus_summary_sub = "Notifications are back on",
        di_rem_tag = "REMINDER",
        di_rem_default = "Reminder %d",
        di_rem_text_tip = "What the island shows",
        di_rem_every_tip = "0 means once",
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
        di_ui_weight = "Weight",
        di_ui_color = "Color",
        di_ui_palette = "Palette",
        di_ui_format = "Format",
        di_ui_icon = "Icon",
        di_ui_color_picker = "Color Picker",
        di_ui_reset = "Reset",
        di_ui_widgets = "Widgets",
        di_ui_drawer_hint = "RMB: settings  \u{2022}  LMB: toggle  \u{2022}  drag: reorder",
        di_ui_controls_hint = "Ctrl + LMB: move  \u{2022}  RMB: widgets",
        di_ui_music = "Music",
        di_ui_fight = "Fight",
        di_main_demo = "Show all screens",
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
        di_wn_1_t = "System alerts",
        di_wn_1_d = "Headphones, sound and battery in the island",
        di_wn_2_t = "Notification Center",
        di_wn_2_d = "Expand the island and scroll down",
        di_wn_3_t = "Press and hold",
        di_wn_3_d = "Opens the island like on iPhone, see settings",
        di_wn_4_t = "One-click updates",
        di_wn_4_d = "New versions install right from the island",
        di_nc_title = "Notifications",
        di_nc_clear = "Clear",
        di_nc_empty = "No notifications",
        di_nc_now = "now",
        di_nc_min = "%dm",
        di_nc_hour = "%dh",
        di_main_expand = "Expand island",
        di_main_expand_hover = "On hover",
        di_main_expand_hold = "Press and hold",
        di_main_expand_tip = "Press and hold works like on iPhone: hold the island for a moment to open it",
        di_group_system = "System",
        di_sys_output = "Audio output",
        di_sys_output_tip = "Shows the device when Windows switches sound output, like when headphones connect. Needs MediaBridge",
        di_sys_mute = "Sound on and off",
        di_sys_mute_tip = "Shows when Windows sound gets muted or unmuted. Needs MediaBridge",
        di_sys_battery = "Battery",
        di_sys_battery_tip = "Laptops only: charging and low battery. Needs MediaBridge",
        di_sys_headphones = "Headphones",
        di_sys_speakers = "Speakers",
        di_sys_display = "Display",
        di_sys_sound = "Sound",
        di_sys_muted = "Muted",
        di_sys_unmuted = "On",
        di_sys_battery_tag = "Battery",
        di_sys_charging = "Charging, %d%%",
        di_sys_low = "Low Battery, %d%%",
        di_ui_tap = "Tap",
        di_num_sep = ",",
        di_ui_map = "Map",
        di_ui_success = "Done",
        di_ui_notification = "Notification",
        di_ui_track = "Track",
        di_ui_match = "Match ",
        di_tab_general = "General",
        di_tab_alerts = "Alerts",
        di_tab_media = "Media",
        di_tab_haptics = "Haptic Engine",
        di_main_enabled = "Enable Island",
        di_main_only_in_game = "Only In-Game",
        di_main_preset = "Position Preset",
        di_main_offset_y = "Vertical Offset (Y)",
        di_main_offset_x = "Horizontal Offset (X)",
        di_main_scale = "Island Scale",
        di_main_custom_label = "Hero Tag",
        di_main_bg_color = "Island Background Color",
        di_main_pure_glass = "Glass Mode",
        di_main_border_thickness = "Border Thickness",
        di_main_widget_editor = "Widget Editor (RMB)",
        di_main_reset_pos = "Reset Position",
        di_preset_top_center = "Top Center",
        di_preset_custom = "Custom (Draggable)",
        di_preset_top_left = "Top Left",
        di_preset_top_right = "Top Right",
        di_preset_screen_center = "Screen Center",
        di_preset_bottom_center = "Bottom Center",
        di_combat_fight_hud = "Live Combat Radar",
        di_combat_fight_scope = "Fight Scope",
        di_combat_scope_local = "Local Hero Only",
        di_combat_scope_any = "Any Fight on Map",
        di_combat_min_heroes = "Min Heroes in Fight",
        di_combat_fight_radius = "Fight Detection Radius",
        di_combat_radar_zoom = "Radar Zoom Range",
        di_combat_fight_timeout = "Fight Completion Timeout",
        di_combat_fight_large_w = "Fight Card Width",
        di_combat_fight_large_h = "Fight Card Height",
        di_combat_kills = "Kill Streaks",
        di_combat_invis = "Enemy Invis & Smoke",
        di_combat_teleports = "Enemy Teleports",
        di_combat_key_enemy_items = "Key Enemy Items",
        di_combat_couriers = "Courier Under Attack",
        di_combat_towers = "Tower Under Attack",
        di_combat_buybacks = "Player Buybacks",
        di_combat_low_hp = "Low HP Kill Opportunities",
        di_combat_level_up = "Hero Level Up",
        di_combat_courier_delivery = "Courier Delivery Activity",
        di_combat_pause_alert = "Pause Notification Pill",
        di_runes_active_runes = "Active Power Runes",
        di_runes_water_runes = "Water Runes",
        di_runes_bounty_runes = "Bounty Runes",
        di_runes_wisdom_runes = "Wisdom Runes",
        di_runes_rune_pickups = "Rune Pickups",
        di_runes_rune_world_spawn = "Rune World Spawns",
        di_runes_lotus = "Lotus Pools",
        di_runes_tormentor = "Tormentor Objective",
        di_runes_roshan = "Roshan & Aegis",
        di_runes_stacks = "Camp Stack Reminder",
        di_timings_toast_duration = "Alert Duration",
        di_timings_stack_time = "Stack Reminder Lead (pull at :53)",
        di_timings_power_rune_time = "Power Runes Lead Time",
        di_timings_water_rune_time = "Water Runes Lead Time",
        di_timings_bounty_rune_time = "Bounty Runes Lead Time",
        di_timings_wisdom_rune_time = "Wisdom Runes Lead Time",
        di_timings_lotus_time = "Lotus Fruit Lead Time",
        di_timings_tormentor1_time = "Tormentor 1st Warning",
        di_timings_tormentor2_time = "Tormentor 2nd Warning",
        di_media_enabled = "Media Sync",
        di_media_spotify_like = "Spotify Like Button",
        di_media_volume_wheel = "Scroll Wheel Volume Control",
        di_media_marquee_speed = "Marquee Speed",
        di_media_compact_title = "Track Title in Compact View",
        di_media_artwork_tint = "Wave Color From Artwork",
        di_media_secondary_bubble = "Satellite Bubble",
        di_media_shadow = "Soft Shadows",
        di_media_blur = "Backdrop Glass Blur",
        di_media_hints = "Control Hints",
        di_media_accent_color = "Primary Theme Color",
        di_media_export_cfg = "Export All Settings to File",
        di_media_import_cfg = "Import All Settings from File",
        di_courier_delivering = "Delivering Items",
        di_courier_delivered = "Delivered",
        di_courier_eta = "ETA",
        di_courier_speed = "Speed",
        di_courier_hp = "HP",
        di_island_clock = "Clock",
        di_island_kda = "KDA",
        di_island_gold = "Gold",
        di_island_networth = "NW",
        di_island_lasthits = "CS",
        di_island_hero = "Hero",
        di_island_fps = "FPS",
        di_island_ping = "Ping",
        di_island_paused = "Paused",
        di_haptics_enabled = "Enable Haptic Engine",
        di_haptics_visual = "Visual Haptics (Squish & Bounce)",
        di_haptics_audio = "Acoustic Taptic Clicks",
        di_haptics_volume = "Taptic Click Volume",
        di_haptics_intensity = "Kinetic Intensity",
        di_haptics_combat_filter = "Combat Anti-Spam Filter",
        di_haptics_audio_ducking = "Audio Auto-Ducking",
        di_haptics_ducking_amount = "Ducking Strength",
        di_haptics_ducking_alerts = "Ducking: Critical Alerts",
        di_haptics_ducking_courier = "Ducking: Courier",
        di_haptics_ducking_notifs = "Ducking: Notifications",
        di_haptics_ducking_motion = "Ducking: Island Motion",
        di_haptics_ducking_taptics = "Ducking: Clicks & Taptics",
        di_haptics_test_ducking = "Audition Ducking",
        di_priority_roshan_kill = "Roshan Killed",
        di_priority_aegis = "Aegis Picked Up",
        di_priority_roshan_attack = "Roshan Under Attack",
        di_priority_fight_summary = "Fight Summary",
        di_priority_rune = "Rune Spawn Reminder",
        di_priority_power_rune_cycle = "Power Rune Cycle"
    },
    ru = {
        di_ui_spotify_no_port = "Спотифай запущен без порта, лайки не работают. Перезапусти его",
        di_ui_likes_unavailable = "Лайки недоступны",
        di_ui_restart_spotify = "Перезапусти Спотифай с панели задач или из Пуска",
        di_rampage_timer = "Таймер рампаги",
        di_rampage_timer_tip = "После Ультра-убийства показывает, сколько осталось до Рампаги",
        di_streak_mega_kill = "Мега-убийство!",
        di_streak_unstoppable = "Неудержимый!",
        di_streak_wicked_sick = "Нечто!",
        di_streak_godlike = "Божественно!",
        di_group_live = "Живые активности",
        di_group_alerts_all = "Все оповещения",
        di_toast_duration_tip = "Для всех оповещений, у которых не задана своя длительность",
        di_alert_duration = "Длительность",
        di_alert_duration_tip = "0 значит общая длительность сверху страницы",
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
        di_alert_priority_tip = "Если оповещения совпали, первым покажется более важное",
        di_media_priority_tip = "Оповещения с таким приоритетом или ниже не перекрывают плеер",
        di_runes_neutrals = "Тиры нейтральных предметов",
        di_tab_focus = "Фокус",
        di_tab_focus_group = "Не беспокоить",
        di_tab_reminders_group = "Напоминания",
        di_focus_key = "Клавиша",
        di_focus_key_tip = "Или плитка «Не беспокоить» в развёрнутом островке",
        di_focus_until = "Выключить",
        di_focus_until_off = "Когда выключу сам",
        di_focus_until_10 = "Через 10 минут",
        di_focus_until_20 = "Через 20 минут",
        di_focus_until_match = "После матча",
        di_focus_urgent = "Пропускать срочные",
        di_focus_urgent_tip = "Оповещения с приоритетом 5 всё равно покажутся",
        di_focus_moon_tint = "Луна в цвет обложки",
        di_focus_moon_tint_tip = "Пока играет музыка, луна «Не беспокоить» красится в цвет обложки",
        di_focus_name = "Не беспокоить",
        di_focus_on = "Вкл",
        di_focus_off = "Выкл",
        di_focus_summary_tag = "Не беспокоить",
        di_focus_summary = "Скрыто уведомлений: %d",
        di_focus_summary_sub = "Уведомления снова включены",
        di_rem_tag = "НАПОМИНАНИЕ",
        di_rem_default = "Напоминание %d",
        di_rem_text_tip = "Что покажет островок",
        di_rem_every_tip = "0 значит один раз",
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
        di_ui_weight = "Начертание",
        di_ui_color = "Цвет",
        di_ui_palette = "Палитра",
        di_ui_format = "Формат",
        di_ui_icon = "Иконка",
        di_ui_color_picker = "Выбор цвета",
        di_ui_reset = "Сброс",
        di_ui_widgets = "Виджеты",
        di_ui_drawer_hint = "ПКМ: опции  \u{2022}  ЛКМ: вкл/выкл  \u{2022}  тяни: порядок",
        di_ui_controls_hint = "Ctrl + ЛКМ: двигать  \u{2022}  ПКМ: виджеты",
        di_ui_music = "Музыка",
        di_ui_fight = "Бой",
        di_main_demo = "Показать все экраны",
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
        di_wn_1_t = "Системные уведомления",
        di_wn_1_d = "Наушники, звук и батарея прямо в островке",
        di_wn_2_t = "Центр уведомлений",
        di_wn_2_d = "Раскрой островок и прокрути вниз",
        di_wn_3_t = "Раскрытие удержанием",
        di_wn_3_d = "Как на айфоне, включается в настройках",
        di_wn_4_t = "Обновления в один клик",
        di_wn_4_d = "Новая версия ставится прямо из островка",
        di_nc_title = "Уведомления",
        di_nc_clear = "Очистить",
        di_nc_empty = "Нет уведомлений",
        di_nc_now = "сейчас",
        di_nc_min = "%d мин",
        di_nc_hour = "%d ч",
        di_main_expand = "Раскрытие",
        di_main_expand_hover = "При наведении",
        di_main_expand_hold = "Удержанием",
        di_main_expand_tip = "Удержанием как на айфоне: зажми островок на секунду, и он раскроется",
        di_group_system = "Система",
        di_sys_output = "Вывод звука",
        di_sys_output_tip = "Показывает устройство, когда Windows переключает вывод звука, например при подключении наушников. Нужен MediaBridge",
        di_sys_mute = "Звук вкл/выкл",
        di_sys_mute_tip = "Показывает, когда звук Windows выключают или включают. Нужен MediaBridge",
        di_sys_battery = "Батарея",
        di_sys_battery_tip = "Только для ноутбуков: зарядка и низкий заряд. Нужен MediaBridge",
        di_sys_headphones = "Наушники",
        di_sys_speakers = "Динамики",
        di_sys_display = "Монитор",
        di_sys_sound = "Звук",
        di_sys_muted = "Выключен",
        di_sys_unmuted = "Включён",
        di_sys_battery_tag = "Батарея",
        di_sys_charging = "Заряжается, %d%%",
        di_sys_low = "Низкий заряд, %d%%",
        di_ui_tap = "Тап",
        di_num_sep = "\u{00A0}",
        di_ui_map = "Карта",
        di_ui_success = "Готово",
        di_ui_notification = "Уведомление",
        di_ui_track = "Трек",
        di_ui_match = "Матч ",
        di_tab_general = "Главная",
        di_tab_alerts = "Оповещения",
        di_tab_media = "Медиа",
        di_tab_haptics = "Тактильный отклик",
        di_main_enabled = "Включить Island",
        di_main_only_in_game = "Только в игре",
        di_main_preset = "Пресет позиции",
        di_main_offset_y = "Смещение (Y)",
        di_main_offset_x = "Смещение (X)",
        di_main_scale = "Масштаб",
        di_main_custom_label = "Тег героя",
        di_main_bg_color = "Цвет фона островка",
        di_main_pure_glass = "Режим стекла",
        di_main_border_thickness = "Толщина обводки",
        di_main_widget_editor = "Редактор виджетов (ПКМ)",
        di_main_reset_pos = "Сбросить позицию",
        di_preset_top_center = "Сверху по центру",
        di_preset_custom = "Своя (Ctrl + ЛКМ)",
        di_preset_top_left = "Сверху слева",
        di_preset_top_right = "Сверху справа",
        di_preset_screen_center = "По центру экрана",
        di_preset_bottom_center = "Снизу по центру",
        di_combat_fight_hud = "Радар боя (Fight HUD)",
        di_combat_fight_scope = "Область боя",
        di_combat_scope_local = "Только вокруг своего героя",
        di_combat_scope_any = "Любой бой на карте",
        di_combat_min_heroes = "Мин. героев для драки",
        di_combat_fight_radius = "Радиус захвата драки",
        di_combat_radar_zoom = "Масштаб радара",
        di_combat_fight_timeout = "Задержка закрытия после драки",
        di_combat_fight_large_w = "Ширина карточки боя",
        di_combat_fight_large_h = "Высота карточки боя",
        di_combat_kills = "Серии убийств",
        di_combat_invis = "Невидимость и Smoke врага",
        di_combat_teleports = "Телепорты врагов",
        di_combat_key_enemy_items = "Важные предметы врага",
        di_combat_couriers = "Атака курьера",
        di_combat_towers = "Атака вышек",
        di_combat_buybacks = "Выкупы игроков",
        di_combat_low_hp = "Добивание Low HP",
        di_combat_level_up = "Повышение уровня",
        di_combat_courier_delivery = "Активность доставки курьера",
        di_combat_pause_alert = "Оповещение паузы игры",
        di_runes_active_runes = "Активные руны (Power)",
        di_runes_water_runes = "Водные руны",
        di_runes_bounty_runes = "Руны богатства (Bounty)",
        di_runes_wisdom_runes = "Руны мудрости (Wisdom)",
        di_runes_rune_pickups = "Подбор рун союзником",
        di_runes_rune_world_spawn = "Появление рун на карте",
        di_runes_lotus = "Пруды лотосов",
        di_runes_tormentor = "Терзатель",
        di_runes_roshan = "Рошан и Эгида",
        di_runes_stacks = "Напоминание о стаке кемпов",
        di_timings_toast_duration = "Длительность уведомлений",
        di_timings_stack_time = "Пре-таймер стака (агр на :53)",
        di_timings_power_rune_time = "Пре-таймер: Power руны",
        di_timings_water_rune_time = "Пре-таймер: Водные руны",
        di_timings_bounty_rune_time = "Пре-таймер: Bounty руны",
        di_timings_wisdom_rune_time = "Пре-таймер: Wisdom руны",
        di_timings_lotus_time = "Пре-таймер: Лотосы",
        di_timings_tormentor1_time = "1-е опов. Терзателя",
        di_timings_tormentor2_time = "2-е опов. Терзателя",
        di_media_enabled = "Медиа плеер",
        di_media_spotify_like = "Лайк трека Spotify",
        di_media_volume_wheel = "Громкость колесиком мыши",
        di_media_marquee_speed = "Скорость бегущей строки",
        di_media_compact_title = "Название трека в маленьком островке",
        di_media_artwork_tint = "Цвет волны из обложки",
        di_media_secondary_bubble = "Второй островок/баббл",
        di_media_shadow = "Мягкие тени",
        di_media_blur = "Размытие фона (Blur)",
        di_media_hints = "Подсказки управления",
        di_media_accent_color = "Основной цвет темы",
        di_media_export_cfg = "Экспорт всех настроек в файл",
        di_media_import_cfg = "Импорт всех настроек из файла",
        di_courier_delivering = "Доставка вещей",
        di_courier_delivered = "Доставлено",
        di_courier_eta = "Через",
        di_courier_speed = "Скор.",
        di_courier_hp = "ХП",
        di_island_clock = "Часы",
        di_island_kda = "КДА",
        di_island_gold = "Золото",
        di_island_networth = "NW",
        di_island_lasthits = "CS",
        di_island_hero = "Герой",
        di_island_fps = "ФПС",
        di_island_ping = "Пинг",
        di_island_paused = "Пауза",
        di_haptics_enabled = "Включить тактильный движок",
        di_haptics_visual = "Визуальная тактильность (Сквиш)",
        di_haptics_audio = "Акустические микро-клики",
        di_haptics_volume = "Громкость щелчков",
        di_haptics_intensity = "Сила кинетического импульса",
        di_haptics_combat_filter = "Умный фильтр в драках",
        di_haptics_audio_ducking = "Затихание остальных звуков",
        di_haptics_ducking_amount = "Сила затихания",
        di_haptics_ducking_alerts = "Затихание: Важные алерты",
        di_haptics_ducking_courier = "Затихание: Курьер",
        di_haptics_ducking_notifs = "Затихание: Уведомления",
        di_haptics_ducking_motion = "Затихание: Движение острова",
        di_haptics_ducking_taptics = "Затихание: Клики и кнопки",
        di_haptics_test_ducking = "Проверить звук",
        di_priority_roshan_kill = "Убийство Рошана",
        di_priority_aegis = "Подбор Эгиды",
        di_priority_roshan_attack = "Атака на Рошана",
        di_priority_fight_summary = "Итог боя",
        di_priority_rune = "Напоминание о руне",
        di_priority_power_rune_cycle = "Цикл Power рун"
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
        NOTIF_CENTER = 19
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

local SCRIPT_VERSION = "2.2.0"

local BridgeStatus = { FirstPoll = 0, LastPoll = 0, LastOk = 0, Version = "", Latest = "", MediaSessions = "" }
local SystemState = { LastPoll = 0, Seen = false }
local Sheet = { Kind = nil, Hits = {}, Dismissed = false, SeenVer = nil, ConfigLoaded = false, MenuSince = nil, Forced = nil, Upd = { State = "idle", Progress = 0, Error = "", Version = "", LastPoll = 0, LastOk = 0 } }
local NotifCenter = { Items = {}, Hits = {} }
local Demo = { Active = false, Step = 0, At = 0 }
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
    ["buyback"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M19 12a7 7 0 1 1-2.05-4.95" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M19.5 3.8v4.2h-4.2" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["swords"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M4.5 4.5 14 14" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M11.5 16.5l5-5" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M15.5 15.5l4 4" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M19.5 4.5 10 14" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M12.5 16.5l-5-5" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M8.5 15.5l-4 4" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["flame"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path fill="#FFFFFF" d="M12 2C9.5 5.5 8 8.5 8 11.5c0 1.2.3 2.3.8 3.3-.5-.4-.9-.9-1.2-1.5-.4-.9-.6-1.9-.6-2.9C5.3 12.2 4 14.5 4 17c0 4.4 3.6 8 8 8s8-3.6 8-8c0-4.5-3.5-8.5-8-15zm1 18.5c-2.5 0-4.5-2-4.5-4.5 0-1.5.8-2.9 2-3.7.3.8.8 1.5 1.5 2 .7.5 1.5.8 2.4.8.4 0 .7-.1 1.1-.2-.4 3.2-2.3 5.6-2.5 5.6z"/></svg>',
    ["media_prev"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M11.5 7.3v9.4c0 .8-.9 1.3-1.6.9L2.8 13c-.7-.4-.7-1.5 0-1.9l7.1-4.6c.7-.5 1.6 0 1.6.8z" fill="#FFF"/><path d="M21.5 7.3v9.4c0 .8-.9 1.3-1.6.9L12.8 13c-.7-.4-.7-1.5 0-1.9l7.1-4.6c.7-.5 1.6 0 1.6.8z" fill="#FFF"/></svg>',
    ["media_next"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M12.5 7.3v9.4c0 .8.9 1.3 1.6.9l7.1-4.6c.7-.4.7-1.5 0-1.9l-7.1-4.6c-.7-.5-1.6 0-1.6.8z" fill="#FFF"/><path d="M2.5 7.3v9.4c0 .8.9 1.3 1.6.9l7.1-4.6c.7-.4.7-1.5 0-1.9L4.1 6.5c-.7-.5-1.6 0-1.6.8z" fill="#FFF"/></svg>',
    ["media_play"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M7 4.9c0-1 1.1-1.6 2-1.1l11.4 7.1c.8.5.8 1.7 0 2.2L9 20.2c-.9.5-2-.1-2-1.1z" fill="#FFF"/></svg>',
    ["media_pause"] = '<svg viewBox="0 0 24 24" width="24" height="24"><rect x="5.5" y="4" width="4.6" height="16" rx="1.4" fill="#FFF"/><rect x="13.9" y="4" width="4.6" height="16" rx="1.4" fill="#FFF"/></svg>',

    ["heart_outline"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M12 20.3 10.7 19.1C6 14.9 3 12.2 3 8.9 3 6.2 5.1 4.2 7.7 4.2c1.6 0 3.2.8 4.3 2 1.1-1.2 2.7-2 4.3-2 2.6 0 4.7 2 4.7 4.7 0 3.3-3 6-7.7 10.2z" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linejoin="round"/></svg>',
    ["heart_fill"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M12 20.3 10.7 19.1C6 14.9 3 12.2 3 8.9 3 6.2 5.1 4.2 7.7 4.2c1.6 0 3.2.8 4.3 2 1.1-1.2 2.7-2 4.3-2 2.6 0 4.7 2 4.7 4.7 0 3.3-3 6-7.7 10.2z" fill="#FFF"/></svg>',
    ["shuffle"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M3 17h2.4c1.9 0 3.1-.8 4.1-2.4l4.8-7.2C15.3 5.8 16.5 5 18.4 5H21" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M18.5 2.5 21 5l-2.5 2.5" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M3 7h2.4c1.5 0 2.6.5 3.5 1.5" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M15.1 15.5c.9 1 2 1.5 3.3 1.5H21" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M18.5 14.5 21 17l-2.5 2.5" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["repeat"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M4 11.5V10a4 4 0 0 1 4-4h12" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M17 3l3 3-3 3" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M20 12.5V14a4 4 0 0 1-4 4H4" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M7 21l-3-3 3-3" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',

    ["clock"] = '<svg viewBox="0 0 24 24" width="24" height="24"><circle cx="12" cy="12" r="9" fill="none" stroke="#FFF" stroke-width="2.2"/><path d="M12 7v5l3.5 2" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["kda"] = '<svg viewBox="0 0 24 24" width="24" height="24"><circle cx="12" cy="12" r="7.5" fill="none" stroke="#FFF" stroke-width="2.2"/><path d="M12 2v4M12 18v4M2 12h4M18 12h4" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><circle cx="12" cy="12" r="2" fill="#FFF"/></svg>',
    ["gold"] = '<svg viewBox="0 0 24 24" width="24" height="24"><circle cx="12" cy="12" r="9" fill="none" stroke="#FFF" stroke-width="2.2"/><path d="M12 6.5v11M14.6 9.3a2.3 2.3 0 0 0-2.3-2H11.2a2.1 2.1 0 0 0 0 4.2h1.6a2.1 2.1 0 0 1 0 4.2h-1.4a2.3 2.3 0 0 1-2.3-2" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["networth"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M3.5 4v14.5a1.5 1.5 0 0 0 1.5 1.5h15" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M7.5 14.5l3.5-4 3 3 5-6M15.5 7.5H19v3.5" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["lasthits"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M14.5 4.5l5 5L10 19l-5.5 1 1-5.5z" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M12.5 6.5l5 5" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["heroname"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M4 18.5h16M4.5 15.5 3.5 7.5l4.8 3.6L12 5l3.7 6.1 4.8-3.6-1 8z" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["fps"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M5.6 18.4A9 9 0 1 1 18.4 18.4" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M12 13l4-4.5" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><circle cx="12" cy="13" r="1.9" fill="#FFF"/></svg>',
    ["ping"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M2.45 9.45a13.5 13.5 0 0 1 19.1 0" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M5.64 12.64a9 9 0 0 1 12.72 0" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M8.82 15.82a4.5 4.5 0 0 1 6.36 0" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><circle cx="12" cy="19.2" r="1.7" fill="#FFF"/></svg>',
    ["home"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M3.5 10.8 12 3.5l8.5 7.3V19a1.5 1.5 0 0 1-1.5 1.5h-4v-6h-6v6H5A1.5 1.5 0 0 1 3.5 19z" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["search"] = '<svg viewBox="0 0 24 24" width="24" height="24"><circle cx="10.5" cy="10.5" r="6.5" fill="none" stroke="#FFF" stroke-width="2.2"/><path d="M15.5 15.5 21 21" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["check"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M5 12.5l4.5 4.5L19 7.5" fill="none" stroke="#FFF" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["close"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M6.5 6.5l11 11M17.5 6.5l-11 11" fill="none" stroke="#FFF" stroke-width="2.6" stroke-linecap="round"/></svg>',
    ["bolt"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M13.6 2.2 4.8 13.1a.8.8 0 0 0 .6 1.3h5.4l-1.2 7.1c-.1.7.8 1.1 1.2.5l8.7-10.9a.8.8 0 0 0-.6-1.3h-5.4l1.2-7.1c.1-.7-.8-1.1-1.1-.5z" fill="#FFF"/></svg>',
    ["music"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M18.5 3.6v11.2a3.1 3.1 0 1 1-1.8-2.8V7.9l-7.4 1.9v7.3a3.1 3.1 0 1 1-1.8-2.8V6.3c0-.6.4-1.1 1-1.3l8.9-2.3c.6-.1 1.1.3 1.1.9z" fill="#FFF"/></svg>',
    ["headphones"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M4.4 15.4V12a7.6 7.6 0 0 1 15.2 0v3.4" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" fill="none"/><rect x="3.2" y="13.2" width="4.8" height="7.6" rx="2" fill="#FFF"/><rect x="16" y="13.2" width="4.8" height="7.6" rx="2" fill="#FFF"/></svg>',
    ["display"] = '<svg viewBox="0 0 24 24" width="24" height="24"><rect x="3" y="4.4" width="18" height="12.2" rx="2.2" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" fill="none"/><path d="M8.6 20.2h6.8M12 16.8v3.2" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" fill="none"/></svg>',
    ["battery_low"] = '<svg viewBox="0 0 24 24" width="24" height="24"><rect x="2.4" y="7.2" width="17" height="9.6" rx="2.8" fill="none" stroke="#FFF" stroke-width="1.8"/><rect x="20.4" y="10.2" width="1.8" height="3.6" rx=".9" fill="#FFF"/><rect x="4.6" y="9.4" width="3.6" height="5.2" rx="1.2" fill="#FFF"/></svg>',
    ["arrow_down"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M12 4.2v14.6M5.8 12.6l6.2 6.2 6.2-6.2" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" fill="none"/></svg>',
    ["hold"] = '<svg viewBox="0 0 24 24" width="24" height="24"><circle cx="12" cy="12" r="3.6" fill="#FFF"/><circle cx="12" cy="12" r="8" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" fill="none"/></svg>',
    ["moon"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M12 3A6.364 6.364 0 0 0 21 12A9 9 0 1 1 12 3Z" fill="#FFFFFF"/></svg>',
    ["bell"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M12 3a6 6 0 0 0-6 6v4.3L4.4 16v1.2h15.2V16L18 13.3V9a6 6 0 0 0-6-6z" fill="#FFFFFF"/><path d="M9.7 18.6a2.4 2.4 0 0 0 4.6 0z" fill="#FFFFFF"/></svg>',
    ["courier"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path fill="#FFD60A" d="M19.38 6.81l-6.5-3.61a1.76 1.76 0 0 0-1.76 0l-6.5 3.61A1.76 1.76 0 0 0 3.75 8.35v7.3a1.76 1.76 0 0 0 .87 1.54l6.5 3.61a1.76 1.76 0 0 0 1.76 0l6.5-3.61a1.76 1.76 0 0 0 .87-1.54v-7.3a1.76 1.76 0 0 0-.87-1.54zm-7.38-2.1l6.12 3.4-2.6 1.45-6.13-3.41 2.61-1.44zm-7 4.19l6.13 3.41v6.86L5 15.76V8.9zm8 10.27v-6.86l6.13-3.41v6.86l-6.13 3.41z"/></svg>',
    ["pause"] = '<svg viewBox="0 0 24 24" width="24" height="24"><rect x="5.5" y="4" width="4.6" height="16" rx="1.4" fill="#FFF"/><rect x="13.9" y="4" width="4.6" height="16" rx="1.4" fill="#FFF"/></svg>',
    ["volume"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M3.5 9.8A1.3 1.3 0 0 1 4.8 8.5h2.6l4.3-3.7c.7-.6 1.8-.1 1.8.8v12.8c0 .9-1.1 1.4-1.8.8l-4.3-3.7H4.8a1.3 1.3 0 0 1-1.3-1.3z" fill="#FFF"/><path d="M16.3 9.2a4 4 0 0 1 0 5.6" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M19 6.5a7.8 7.8 0 0 1 0 11" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["mute"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M3.5 9.8A1.3 1.3 0 0 1 4.8 8.5h2.6l4.3-3.7c.7-.6 1.8-.1 1.8.8v12.8c0 .9-1.1 1.4-1.8.8l-4.3-3.7H4.8a1.3 1.3 0 0 1-1.3-1.3z" fill="#FFF"/><path d="M16.5 9.5l5 5M21.5 9.5l-5 5" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    ["apple_check"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path fill="#34C759" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1.2 15.2l-4.5-4.5 1.41-1.41 3.09 3.08 7.09-7.09 1.41 1.41-8.5 8.51z"/></svg>',
    ["stack"] = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M12 3.8l7.2 3.6L12 11 4.8 7.4z" fill="#FFF"/><path d="M4.8 11.6 12 15.2l7.2-3.6" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M4.8 15.6 12 19.2l7.2-3.6" fill="none" stroke="#FFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>'
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

Impl.ConfigSavePaths = { "dynamic_island_config.json", "C:/Umbrella/scripts/dynamic_island_config.json", "scripts/dynamic_island_config.json" }

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
        local f = io.open(path, "w")
        if f then
            local activeStr = table.concat(HUDCustomizer.ActiveChips, ",")
            f:write("active=" .. activeStr .. "\n")
            f:write(string.format("drag_center=%d,%d\n", math.floor(DragState.CustomX or -1), math.floor(DragState.CustomY or -1)))
            if Sheet.SeenVer then f:write("seen_ver=" .. Sheet.SeenVer .. "\n") end

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

                for secName, sec in pairs(UI) do
                    if type(sec) == "table" then
                        for name, w in pairs(sec) do
                            local ok, v = pcall(function() return w:Get() end)
                            if ok and type(v) == "boolean" then
                                f:write(string.format("w_%s.%s=%s\n", secName, name, v and "b1" or "b0"))
                            elseif ok and type(v) == "number" then
                                f:write(string.format("w_%s.%s=%s\n", secName, name, tostring(v)))
                            elseif ok and type(v) == "string" and not v:find("[\r\n]") then
                                f:write(string.format("w_%s.%s=s:%s\n", secName, name, v))
                            end
                        end
                    end
                end
            end
            f:close()
        end
    end
end

function Impl.LoadAllConfig()
    local paths = Impl.ConfigSavePaths
    local f = nil
    for _, path in ipairs(paths) do
        f = io.open(path, "r")
        if f then break end
    end
    if not f then return end

    for line in f:lines() do
        local activeMatch = string.match(line, "^active=([%w_,]+)")
        local dragMatchX, dragMatchY = string.match(line, "^drag_center=([%-]?%d+),([%-]?%d+)")
        local seenMatch = string.match(line, "^seen_ver=([%w%.]+)")
        if seenMatch then
            Sheet.SeenVer = seenMatch
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
                        if wVal:sub(1, 2) == "s:" then
                            val = wVal:sub(3)
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
    if not name or not VectorIcons[name] then return nil end
    local cacheKey = "svg_apple_v39_" .. name
    local h = ImageCache[cacheKey]
    if h ~= nil then return h or nil end
    local ok, handle = pcall(Render.LoadSvgString, VectorIcons[name], Vec2(48, 48), "vec_sym_apple_v39_" .. name)
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

function Impl.LoadScriptFonts()
    local aa = Enum.FontCreate.FONTFLAG_ANTIALIAS
    Config.Fonts.Regular = Render.LoadFont("SF Pro Text", aa, 400)
    Config.Fonts.Medium = Render.LoadFont("SF Pro Text", aa, 500)
    Config.Fonts.Semibold = Render.LoadFont("SF Pro Text", aa, 600)
    Config.Fonts.Display = Render.LoadFont("SF Pro Display", aa, 500)
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
        HEARTBEAT = 8
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

local function HapticPlaySound(appleSoundName, arg2, arg3)
    if Haptic.Quiet then return end
    if not ToggleOn(UI and UI.Haptics and UI.Haptics.Enabled) then return end
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
            pcall(HTTP.Request, "GET", "http://127.0.0.1:45455/sound?name=" .. appleSoundName .. "&vol=" .. string.format("%.2f", finalVol) .. forceParam .. duckParam, {}, function() end)
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
        end
    elseif hType == Haptic.Types.SUCCESS_APPLE_PAY then
        if visualOn then
            Haptic.State.VelScaleX = Haptic.State.VelScaleX + 1.4 * intensity
            Haptic.State.VelScaleY = Haptic.State.VelScaleY + 1.4 * intensity
            Haptic.State.GlowAlpha = 140 * intensity
            Haptic.State.GlowColor = Color(48, 209, 88, 255)
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
            Haptic.State.GlowColor = Color(255, 55, 95, 255)
        end
        if p1 then
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
    local pMedia = tab:Create(L("di_tab_media"))
    local gMedia = pMedia:Create("di_group_media", Enum.GroupSide.Left)

    local pFocus = extra:Create(L("di_tab_focus"))
    local gFocus = pFocus:Create("di_tab_focus_group", Enum.GroupSide.Left)
    local gRem = pFocus:Create("di_tab_reminders_group", Enum.GroupSide.Right)
    local pHaptics = extra:Create(L("di_tab_haptics"))
    local gHaptics = pHaptics:Create("di_group_haptics", Enum.GroupSide.Left)
    local gDuck = pHaptics:Create("di_group_ducking", Enum.GroupSide.Right)

    UI = { Main = {}, Media = {}, Combat = {}, Runes = {}, Timings = {}, Haptics = {}, Priority = {}, Durations = {}, Focus = {}, Reminders = {}, System = {} }
    local M, Md, C, R, T, H, P, D = UI.Main, UI.Media, UI.Combat, UI.Runes, UI.Timings, UI.Haptics, UI.Priority, UI.Durations

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
    local function lead(gear, key, lo, hi, def)
        local w = gear:Slider(key, lo, hi, def, "%d s")
        w:Icon("\u{f017}")
        return w
    end

    M.Enabled = gIsland:Switch("di_main_enabled", true, "\u{f0eb}")
    local gMore = M.Enabled:Gear("di_gear_more")
    M.OnlyInGame = gMore:Switch("di_main_only_in_game", false, "\u{f108}")
    M.ExpandMode = gMore:Combo("di_main_expand", { "di_main_expand_hover", "di_main_expand_hold" }, 0)
    M.ExpandMode:Icon("\u{f065}")
    M.ExpandMode:ToolTip("di_main_expand_tip")
    M.Demo = gMore:Button("di_main_demo", function() Demo.Start() end)
    T.ToastDuration = gAll:Slider("di_timings_toast_duration", 1, 10, 4, "%d s")
    T.ToastDuration:Icon("\u{f254}")
    T.ToastDuration:ToolTip("di_toast_duration_tip")
    M.CustomLabel = gMore:Input("di_main_custom_label", "", "\u{f02b}")
    M.ResetPos = gMore:Button("di_main_reset_pos", function()
        DragState.CustomX = -1
        DragState.CustomY = -1
        UI.Main.Preset:Set(0)
        UI.Main.OffsetY:Set(20)
        UI.Main.OffsetX:Set(0)
        SaveAllConfig()
    end)
    M.ExportCfg = gMore:Button("di_media_export_cfg", function()
        SaveAllConfig()
    end)
    M.ImportCfg = gMore:Button("di_media_import_cfg", function()
        Impl.LoadAllConfig()
    end)

    M.Preset = gIsland:Combo("di_main_preset", { "di_preset_top_center", "di_preset_custom", "di_preset_top_left", "di_preset_top_right", "di_preset_screen_center", "di_preset_bottom_center" }, 0)
    M.Preset:Icon("\u{f3c5}")
    local gPos = M.Preset:Gear("di_gear_position")
    M.OffsetY = gPos:Slider("di_main_offset_y", 0, 1000, 20, "%d px")
    M.OffsetY:Icon("\u{f338}")
    M.OffsetX = gPos:Slider("di_main_offset_x", -960, 960, 0, "%d px")
    M.OffsetX:Icon("\u{f337}")
    M.Scale = gPos:Slider("di_main_scale", 60, 180, 100, "%d%%")
    M.Scale:Icon("\u{f065}")

    M.ToggleHUDMode = gLook:Button("di_main_widget_editor", function()
        HUDCustomizer.IsOpen = not HUDCustomizer.IsOpen
        HUDCustomizer.InspectedChip = nil
    end)

    M.PureGlass = gLookGear:Switch("di_main_pure_glass", false, "\u{f06e}")
    Md.Blur = gLookGear:Switch("di_media_blur", true, "\u{f042}")
    Md.Shadow = gLookGear:Switch("di_media_shadow", true, "\u{f0c8}")
    M.IslandBgColor = gLookGear:ColorPicker("di_main_bg_color", Color(0, 0, 0, 245), "\u{f53f}")
    Md.AccentColor = gLookGear:ColorPicker("di_media_accent_color", Config.Colors.Accent, "\u{f53f}")
    Md.ArtworkTint = gLookGear:Switch("di_media_artwork_tint", true, "\u{f1fc}")
    M.BorderThickness = gLookGear:Slider("di_main_border_thickness", 0.0, 3.0, 1.0, "%.1f px")
    M.BorderThickness:Icon("\u{f065}")

    C.FightHUD = gLive:Switch("di_combat_fight_hud", true, "\u{f140}")
    local gRadar = C.FightHUD:Gear("di_gear_radar")
    C.FightScope = gRadar:Combo("di_combat_fight_scope", { "di_combat_scope_local", "di_combat_scope_any" }, 0)
    C.FightScope:Icon("\u{f05b}")
    C.MinHeroes = gRadar:Slider("di_combat_min_heroes", 1, 10, 2, "%d")
    C.MinHeroes:Icon("\u{f0c0}")
    C.FightRadius = gRadar:Slider("di_combat_fight_radius", 1000, 3000, 1600, "%d px")
    C.FightRadius:Icon("\u{f1ce}")
    C.RadarZoom = gRadar:Slider("di_combat_radar_zoom", 1000, 3500, 2000, "%d px")
    C.RadarZoom:Icon("\u{f00e}")
    C.FightTimeout = gRadar:Slider("di_combat_fight_timeout", 2, 10, 4, "%d s")
    C.FightTimeout:Icon("\u{f017}")
    C.FightLargeW = gRadar:Slider("di_combat_fight_large_w", 300, 520, 365, "%d px")
    C.FightLargeW:Icon("\u{f337}")
    C.FightLargeH = gRadar:Slider("di_combat_fight_large_h", 110, 220, 148, "%d px")
    C.FightLargeH:Icon("\u{f338}")
    P.FightSummary = prio(gRadar, "di_priority_fight_summary", 3)
    D.FightSummary = dur(gRadar)

    C.Kills = gCombat:Switch("di_combat_kills", true, "\u{f0e7}")
    local gKill = C.Kills:Gear("di_gear_alert")
    P.Kill = prio(gKill, "di_alert_priority", 3)
    D.Kill = dur(gKill)
    C.RampageTimer = gKill:Switch("di_rampage_timer", true, "\u{f2f2}")
    C.RampageTimer:ToolTip("di_rampage_timer_tip")
    C.Invis = gCombat:Switch("di_combat_invis", true, "\u{f070}")
    local gInvis = C.Invis:Gear("di_gear_alert")
    P.Invis = prio(gInvis, "di_alert_priority", 4)
    D.Invis = dur(gInvis)
    C.Teleports = gCombat:Switch("di_combat_teleports", true, "\u{f3c5}")
    local gTeleport = C.Teleports:Gear("di_gear_alert")
    P.Teleport = prio(gTeleport, "di_alert_priority", 4)
    D.Teleport = dur(gTeleport)
    C.KeyEnemyItems = gCombat:Switch("di_combat_key_enemy_items", true, "\u{f290}")
    local gEnemyItem = C.KeyEnemyItems:Gear("di_gear_alert")
    P.EnemyItem = prio(gEnemyItem, "di_alert_priority", 3)
    D.EnemyItem = dur(gEnemyItem)
    C.Towers = gCombat:Switch("di_combat_towers", true, "\u{f447}")
    local gTower = C.Towers:Gear("di_gear_alert")
    P.Tower = prio(gTower, "di_alert_priority", 4)
    D.Tower = dur(gTower)
    C.Couriers = gCombat:Switch("di_combat_couriers", true, "\u{f48b}")
    local gCourier = C.Couriers:Gear("di_gear_alert")
    P.Courier = prio(gCourier, "di_alert_priority", 3)
    D.Courier = dur(gCourier)
    C.Buybacks = gCombat:Switch("di_combat_buybacks", true, "\u{f2f9}")
    local gBuyback = C.Buybacks:Gear("di_gear_alert")
    P.Buyback = prio(gBuyback, "di_alert_priority", 5)
    D.Buyback = dur(gBuyback)
    C.LowHP = gCombat:Switch("di_combat_low_hp", true, "\u{f004}")
    local gLowHp = C.LowHP:Gear("di_gear_alert")
    P.LowHp = prio(gLowHp, "di_alert_priority", 5)
    D.LowHp = dur(gLowHp)
    C.LevelUp = gCombat:Switch("di_combat_level_up", true, "\u{f201}")
    local gLevel = C.LevelUp:Gear("di_gear_alert")
    P.Level = prio(gLevel, "di_alert_priority", 1)
    D.Level = dur(gLevel)
    C.CourierDelivery = gLive:Switch("di_combat_courier_delivery", true, "\u{f48b}")
    C.PauseAlert = gLive:Switch("di_combat_pause_alert", true, "\u{f04c}")
    UI.System.Output = gSystem:Switch("di_sys_output", true, "\u{f025}")
    UI.System.Output:ToolTip("di_sys_output_tip")
    UI.System.Mute = gSystem:Switch("di_sys_mute", true, "\u{f6a9}")
    UI.System.Mute:ToolTip("di_sys_mute_tip")
    UI.System.Battery = gSystem:Switch("di_sys_battery", true, "\u{f240}")
    UI.System.Battery:ToolTip("di_sys_battery_tip")

    R.ActiveRunes = gMap:Switch("di_runes_active_runes", true, "\u{f0e7}")
    local gPower = R.ActiveRunes:Gear("di_gear_alert")
    T.PowerRuneTime = lead(gPower, "di_timings_power_rune_time", 5, 60, 20)
    P.Rune = prio(gPower, "di_priority_rune", 2)
    P.PowerRuneCycle = prio(gPower, "di_priority_power_rune_cycle", 2)
    D.Rune = dur(gPower)
    R.WaterRunes = gMap:Switch("di_runes_water_runes", true, "\u{f043}")
    T.WaterRuneTime = lead(R.WaterRunes:Gear("di_gear_alert"), "di_timings_water_rune_time", 5, 60, 20)
    R.BountyRunes = gMap:Switch("di_runes_bounty_runes", true, "\u{f155}")
    T.BountyRuneTime = lead(R.BountyRunes:Gear("di_gear_alert"), "di_timings_bounty_rune_time", 5, 45, 10)
    R.WisdomRunes = gMap:Switch("di_runes_wisdom_runes", true, "\u{f19d}")
    T.WisdomRuneTime = lead(R.WisdomRunes:Gear("di_gear_alert"), "di_timings_wisdom_rune_time", 5, 60, 20)
    R.RunePickups = gMap:Switch("di_runes_rune_pickups", true, "\u{f21b}")
    local gRunePickup = R.RunePickups:Gear("di_gear_alert")
    P.RunePickup = prio(gRunePickup, "di_alert_priority", 2)
    D.RunePickup = dur(gRunePickup)
    R.RuneWorldSpawn = gMap:Switch("di_runes_rune_world_spawn", true, "\u{f279}")
    local gRuneWorld = R.RuneWorldSpawn:Gear("di_gear_alert")
    P.RuneWorld = prio(gRuneWorld, "di_alert_priority", 2)
    D.RuneWorld = dur(gRuneWorld)
    R.Stacks = gMap:Switch("di_runes_stacks", false, "\u{f5fd}")
    local gStack = R.Stacks:Gear("di_gear_alert")
    T.StackTime = lead(gStack, "di_timings_stack_time", 3, 20, 8)
    P.Stack = prio(gStack, "di_alert_priority", 2)
    D.Stack = dur(gStack)
    R.Lotus = gMap:Switch("di_runes_lotus", true, "\u{f06c}")
    local gLotus = R.Lotus:Gear("di_gear_alert")
    T.LotusTime = lead(gLotus, "di_timings_lotus_time", 5, 60, 20)
    P.Lotus = prio(gLotus, "di_alert_priority", 2)
    D.Lotus = dur(gLotus)
    R.Neutrals = gMap:Switch("di_runes_neutrals", true, "\u{f466}")
    local gNeutral = R.Neutrals:Gear("di_gear_alert")
    P.Neutral = prio(gNeutral, "di_alert_priority", 2)
    D.Neutral = dur(gNeutral)
    R.Tormentor = gMap:Switch("di_runes_tormentor", true, "\u{f005}")
    local gTorm = R.Tormentor:Gear("di_gear_alert")
    T.Tormentor1Time = lead(gTorm, "di_timings_tormentor1_time", 30, 180, 120)
    T.Tormentor2Time = lead(gTorm, "di_timings_tormentor2_time", 5, 60, 20)
    P.Tormentor = prio(gTorm, "di_alert_priority", 3)
    D.Tormentor = dur(gTorm)
    R.Roshan = gMap:Switch("di_runes_roshan", true, "\u{f6e3}")
    local gRosh = R.Roshan:Gear("di_gear_alert")
    P.RoshanKill = prio(gRosh, "di_priority_roshan_kill", 5)
    P.Aegis = prio(gRosh, "di_priority_aegis", 5)
    P.RoshanAttack = prio(gRosh, "di_priority_roshan_attack", 4)
    D.Roshan = dur(gRosh)

    Md.Enabled = gMedia:Switch("di_media_enabled", true, "\u{f001}")
    local gPlayer = Md.Enabled:Gear("di_gear_media")
    P.Media = gPlayer:Slider("di_alert_priority", 1, 5, 5, "%d")
    P.Media:Icon("\u{f160}")
    P.Media:ToolTip("di_media_priority_tip")
    Md.CompactTitle = gPlayer:Switch("di_media_compact_title", true, "\u{f031}")
    Md.MarqueeSpeed = gPlayer:Slider("di_media_marquee_speed", 20, 100, 45, "%d px/s")
    Md.MarqueeSpeed:Icon("\u{f337}")
    Md.SpotifyLike = gMedia:Switch("di_media_spotify_like", true, "\u{f004}")
    local gSpotifyLike = Md.SpotifyLike:Gear("di_gear_alert")
    P.SpotifyLike = prio(gSpotifyLike, "di_alert_priority", 1)
    D.SpotifyLike = dur(gSpotifyLike)
    Md.VolumeWheel = gMedia:Switch("di_media_volume_wheel", true, "\u{f028}")
    Md.SecondaryBubble = gMedia:Switch("di_media_secondary_bubble", true, "\u{f111}")
    Md.Hints = gMedia:Switch("di_media_hints", true, "\u{f05a}")

    H.Enabled = gHaptics:Switch("di_haptics_enabled", true, "\u{f011}")
    H.VisualFeedback = gHaptics:Switch("di_haptics_visual", true, "\u{f06e}")
    H.Intensity = H.VisualFeedback:Gear("di_gear_visual"):Slider("di_haptics_intensity", 50, 150, 100, "%d%%")
    H.Intensity:Icon("\u{f065}")
    H.AudioFeedback = gHaptics:Switch("di_haptics_audio", true, "\u{f028}")
    H.Volume = H.AudioFeedback:Gear("di_gear_audio"):Slider("di_haptics_volume", 0, 100, 50, "%d%%")
    H.Volume:Icon("\u{f028}")
    H.CombatFilter = gHaptics:Switch("di_haptics_combat_filter", true, "\u{f0e7}")
    H.AudioDucking = gDuck:Switch("di_haptics_audio_ducking", true, "\u{f026}")
    local gDuckGear = H.AudioDucking:Gear("di_gear_ducking")
    H.DuckingAmount = gDuckGear:Slider("di_haptics_ducking_amount", 0, 100, 50, "%d%%")
    H.DuckingAmount:Icon("\u{f027}")
    H.DuckingAlerts = gDuckGear:Switch("di_haptics_ducking_alerts", true, "\u{f0f3}")
    H.DuckingCourier = gDuckGear:Switch("di_haptics_ducking_courier", true, "\u{f48b}")
    H.DuckingNotifs = gDuckGear:Switch("di_haptics_ducking_notifs", true, "\u{f05a}")
    H.DuckingMotion = gDuckGear:Switch("di_haptics_ducking_motion", false, "\u{f065}")
    H.DuckingTaptics = gDuckGear:Switch("di_haptics_ducking_taptics", false, "\u{f0a7}")
    H.TestDucking = gDuckGear:Button("di_haptics_test_ducking", function()
        if HTTP and HTTP.Request then
            local userVol = (UI and UI.Haptics and UI.Haptics.Volume) and (UI.Haptics.Volume:Get() / 100.0) or 0.5
            local baseDuckPct = (UI and UI.Haptics and UI.Haptics.DuckingAmount and UI.Haptics.DuckingAmount:Get() or 50) / 100.0
            local finalDuck = string.format("%.2f", baseDuckPct)
            pcall(HTTP.Request, "GET", "http://127.0.0.1:45455/sound?name=courier_delivered&vol=" .. string.format("%.2f", userVol) .. "&force=1&duck=" .. finalDuck, {}, function() end)
        end
    end)

    UI.Focus.Key = gFocus:Bind("di_focus_key", Enum.ButtonCode.KEY_NONE, "\u{f186}")
    UI.Focus.Key:ToolTip("di_focus_key_tip")
    UI.Focus.Key:Properties(L("di_focus_name"))
    UI.Focus.Until = gFocus:Combo("di_focus_until", { "di_focus_until_off", "di_focus_until_10", "di_focus_until_20", "di_focus_until_match" }, 0)
    UI.Focus.Until:Icon("\u{f017}")
    UI.Focus.Urgent = gFocus:Switch("di_focus_urgent", true, "\u{f0f3}")
    UI.Focus.Urgent:ToolTip("di_focus_urgent_tip")
    UI.Focus.MoonTint = gFocus:Switch("di_focus_moon_tint", true, "\u{f53f}")
    UI.Focus.MoonTint:ToolTip("di_focus_moon_tint_tip")

    local RM = UI.Reminders
    for i, key in ipairs({ "di_rem_1", "di_rem_2", "di_rem_3", "di_rem_4" }) do
        local sw = gRem:Switch(key, false, "\u{f0f3}")
        local g = sw:Gear(({ "di_rem_gear_1", "di_rem_gear_2", "di_rem_gear_3", "di_rem_gear_4" })[i])
        RM["On" .. i] = sw
        RM["Text" .. i] = g:Input(({ "di_rem1_text", "di_rem2_text", "di_rem3_text", "di_rem4_text" })[i], "", "\u{f036}")
        RM["Text" .. i]:ToolTip("di_rem_text_tip")
        RM["Min" .. i] = g:Slider(({ "di_rem1_min", "di_rem2_min", "di_rem3_min", "di_rem4_min" })[i], 0, 90, 10 * i, "%d")
        RM["Min" .. i]:Icon("\u{f017}")
        RM["Sec" .. i] = g:Slider(({ "di_rem1_sec", "di_rem2_sec", "di_rem3_sec", "di_rem4_sec" })[i], 0, 59, 0, "%d")
        RM["Sec" .. i]:Icon("\u{f017}")
        RM["Every" .. i] = g:Slider(({ "di_rem1_every", "di_rem2_every", "di_rem3_every", "di_rem4_every" })[i], 0, 30, 0, "%d")
        RM["Every" .. i]:Icon("\u{f01e}")
        RM["Every" .. i]:ToolTip("di_rem_every_tip")
    end
    P.Reminder = prio(gRem, "di_priority_reminder", 4)
    D.Reminder = dur(gRem, "di_reminder_duration")

    local function refreshDisabled()
        local hOn = H.Enabled:Get()
        H.VisualFeedback:Disabled(not hOn)
        H.AudioFeedback:Disabled(not hOn)
        H.CombatFilter:Disabled(not hOn)
        H.AudioDucking:Disabled(not hOn)
        local mOn = Md.Enabled:Get()
        Md.SpotifyLike:Disabled(not mOn)
        Md.VolumeWheel:Disabled(not mOn)
        Md.SecondaryBubble:Disabled(not mOn)
    end
    H.Enabled:SetCallback(refreshDisabled, true)
    Md.Enabled:SetCallback(refreshDisabled)

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
    if kind == "media" then lo, hi = D.CompactMediaH, D.LargeMediaH end
    local m = (StateMachine.Spring.H.value - lo) / math.max(1, hi - lo)
    if m < 0.004 then return 0 end
    if m > 0.996 then return 1 end
    return m
end

local function TriggerStateTransition(nextState)
    if StateMachine.TargetState == nextState then return end

    local fromLarge = (StateMachine.TargetState == StateMachine.States.LARGE_IDLE or StateMachine.TargetState == StateMachine.States.LARGE_MEDIA or StateMachine.TargetState == StateMachine.States.LARGE_FIGHT or StateMachine.TargetState == StateMachine.States.COURIER_LARGE or StateMachine.TargetState == StateMachine.States.SHEET or StateMachine.TargetState == StateMachine.States.NOTIF_CENTER)
    local toLarge = (nextState == StateMachine.States.LARGE_IDLE or nextState == StateMachine.States.LARGE_MEDIA or nextState == StateMachine.States.LARGE_FIGHT or nextState == StateMachine.States.COURIER_LARGE or nextState == StateMachine.States.SHEET or nextState == StateMachine.States.NOTIF_CENTER)

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

    if nextState == StateMachine.States.GAME_PAUSED then
        HapticPlaySound("game_paused", 0.45)
    elseif StateMachine.PreviousState == StateMachine.States.GAME_PAUSED then
        HapticPlaySound("game_unpaused", 0.45)
    elseif nextState == StateMachine.States.MENU_MATCH_FOUND then
        HapticPlaySound("match_found", 0.60)
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

function Impl.GetNotifPriority(notif)
    if notif.PriorityOverride then
        return notif.PriorityOverride
    end
    local key = notif.Type and Impl.NotifPriorityKey[notif.Type]
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

function Impl.NotifChime(n)
    if not n or n.Chimed or n.Silent then return end
    n.Chimed = true
    HapticPlaySound(n.Chime or "notification_toast", 0.45)
end

function DynamicIsland.PushNotification(notif)
    if not notif then return end
    if notif.Type == "neutral" and UI and UI.Runes and UI.Runes.Neutrals and not UI.Runes.Neutrals:Get() then return end
    NotifCenter.Add(notif)
    local shared = (UI and UI.Timings and UI.Timings.ToastDuration) and UI.Timings.ToastDuration:Get() or 4
    local durKey = notif.Type and Impl.NotifDurationKey[notif.Type]
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
        return
    end
    if NotificationQueue.Active and notif.Priority > (NotificationQueue.Active.Priority or DEFAULT_NOTIF_PRIORITY) then
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

function Impl.GetScriptRelPath()
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

function Impl.TryLoadAlbumImage(coverPath, coverJpg, coverBase64, curVer)
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
        cheatDir .. "dynamic_island_covers/dynamic_island_cover_" .. vStr .. ".png",
        cheatDir .. "dynamic_island_covers/dynamic_island_cover_" .. vStr .. ".jpg",
        cheatDir .. "dynamic_island_cover_" .. vStr .. ".png",
        cheatDir .. "dynamic_island_cover.png"
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

function Impl.AdvancePosition(dt)
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
    if HUDCustomizer.IsOpen or FightTracker.Active then return false end
    if not (Engine.IsInGame and Engine.IsInGame()) then return false end
    if not IsMediaActive() then return false end
    return (notif.Priority or DEFAULT_NOTIF_PRIORITY) <= UI.Priority.Media:Get()
end

function Impl.PollMediaBridge()
    if not UI or not UI.Media.Enabled:Get() or Demo.Active then return end
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
        if curVer ~= MediaData.CoverVersion or not MediaData.CoverImageHandle then
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

function Impl.PollBridgeStatus()
    local clk = os.clock()
    if clk - BridgeStatus.LastPoll < 3.0 then return end
    BridgeStatus.LastPoll = clk
    if BridgeStatus.FirstPoll == 0 then BridgeStatus.FirstPoll = clk end
    pcall(HTTP.Request, "GET", "http://127.0.0.1:45455/status", {}, function(res)
        if not res or not res.response or res.response == "" then return end
        local body = res.response
        if not string.find(body, '"status"', 1, true) then return end
        BridgeStatus.LastOk = os.clock()
        BridgeStatus.Version = string.match(body, '"version"%s*:%s*"([^"]*)"') or ""
        BridgeStatus.Latest = string.match(body, '"latest_version"%s*:%s*"([^"]*)"') or ""
        BridgeStatus.MediaSessions = string.match(body, '"media_sessions"%s*:%s*"([^"]*)"') or ""
        BridgeStatus.SpotifyDebug = string.match(body, '"spotify_debug"%s*:%s*"([^"]*)"') or ""
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
    if clk - SystemState.LastPoll < 0.5 then return end
    SystemState.LastPoll = clk
    pcall(HTTP.Request, "GET", "http://127.0.0.1:45455/system", {}, function(res)
        if not res or not res.response or res.response == "" then return end
        local body = res.response
        local id = string.match(body, '"device_id"%s*:%s*"([^"]*)"')
        if not id then return end
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
        table.insert(out, { text = L("di_ui_bridge_offline"), dot = Color(255, 159, 10, 255) })
    elseif online and BridgeStatus.MediaSessions == "timeout" then
        table.insert(out, { text = L("di_ui_media_service_down"), dot = Color(255, 159, 10, 255) })
    end
    if online and BridgeStatus.SpotifyDebug == "closed" and UI and UI.Media and UI.Media.SpotifyLike:Get() then
        table.insert(out, { text = L("di_ui_spotify_no_port"), dot = Color(255, 159, 10, 255) })
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

                DynamicIsland.PushNotification({
                    Type = "kill",
                    Tag = L("di_ui_kill_streak"),
                    Title = streakTitle,
                    Subtitle = L("di_ui_eliminated") .. killedHeroName,
                    AccentColor = Config.Colors.Red,
                    IconType = "hero",
                    Icon = killedRaw ~= "" and ("panorama/images/heroes/icons/" .. killedRaw .. "_png.vtex_c") or nil,
                    Duration = 3.8
                })
            end
        end
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

        if tf > 0 then
            local nm = math.floor(tf / 60) + 1
            local sl = nm * 60 - tf

            if UI.Runes.Stacks:Get() and nm >= 2 and sl == 7 + stackLead and not FightTracker.Active then
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
        GameTracker.Roshan.AegisExpiryTime = GameRules.GetGameTime() + 300
        GameTracker.Roshan.AegisHolder = ent
        GameTracker.Roshan.Dismissed = false
        local heroName = GetPlayerDisplayName(ent)
        local accent = isEnemy and Config.Colors.Red or Config.Colors.Accent
        DynamicIsland.PushNotification({
            Type = "aegis",
            Tag = L("di_ui_aegis_claimed"),
            Title = heroName .. L("di_ui_claimed_aegis"),
            Subtitle = isEnemy and L("di_ui_enemy_secured_immortal") or L("di_ui_ally_secured_immortal"),
            AccentColor = accent,
            IconType = "item",
            Icon = "panorama/images/items/aegis_png.vtex_c",
            Duration = 4.5
        })
        return
    end
end

function DynamicIsland.OnModifierDestroy(ent, mod)
    if GameTracker.Roshan.AegisExpiryTime == 0 or not mod or ent ~= GameTracker.Roshan.AegisHolder then return end
    local ok, mn = pcall(Modifier.GetName, mod)
    if ok and mn == "modifier_item_aegis" then
        GameTracker.Roshan.AegisExpiryTime = 0
        GameTracker.Roshan.AegisHolder = nil
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
                Tag = L("di_ui_roshan_pit_alert"),
                Title = L("di_ui_roshan_under_attack"),
                Subtitle = L("di_ui_combat_audio_detected_in_pit"),
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

    local margin = 4
    x = math.max(margin, math.min(x, scr.x - w - margin))
    y = math.max(margin, math.min(y, scr.y - h - margin))

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
            nameStr = string.sub(nameStr, 1, 3):upper()
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
    return L("di_ui_main_menu"), os.date("%H:%M")
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

function Impl.ChipAnim(chipId)
    local a = HUDCustomizer.Anim.Chips[chipId]
    if not a then
        a = { fill = Impl.IsChipInActiveList(chipId) and 1 or 0, fillVel = 0, scale = 1, scaleVel = 0 }
        HUDCustomizer.Anim.Chips[chipId] = a
    end
    return a
end

function Impl.ToggleChipInActiveList(chipId)
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
    local a = Impl.ChipAnim(chipId)
    a.scale, a.scaleVel = 0.86, -2.2
    SaveAllConfig()
end

function Impl.GetFountainPosition(hero, courier)
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

function Impl.GetLocalCourier()
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
                local c = Impl.GetLocalCourier()
                local myHero = HeroData.Local or (Heroes and Heroes.GetLocal and Heroes.GetLocal())
                local dist = 1000
                if c and myHero then
                    local cO = Entity.GetAbsOrigin(c)
                    local hO = Entity.GetAbsOrigin(myHero)
                    local basePos = Impl.GetFountainPosition(myHero, c)
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

function Impl.ProcessCourierTracker()
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

    local c = Impl.GetLocalCourier()
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
    local basePos = Impl.GetFountainPosition(myHero, c)
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
            if isDead then HapticPlaySound("courier_death_or_fail", 0.6) end
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
        if data.key == Enum.ButtonCode.KEY_MOUSE1 or data.key == Enum.ButtonCode.KEY_MOUSE2 then
            return false
        end
    end

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

function Impl.HandleInteractions()
    if not UI or not UI.Main.Enabled:Get() then return end

    local nowClk = os.clock()
    local mediaActive = IsMediaActive()
    local inCombat = FightTracker.Active

    local isLMouseDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1)
    local isRMouseDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE2)
    local isLeftClicked = isLMouseDown and not MouseInput.LeftPressed
    local isRightClicked = isRMouseDown and not MouseInput.RightPressed

    MouseInput.LeftPressed = isLMouseDown
    MouseInput.RightPressed = isRMouseDown

    local cx, cy = Input.GetCursorPos()

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

    if Demo.Active then
    elseif NotificationQueue.Active then
        local elapsed = nowClk - NotificationQueue.StartTime
        if elapsed >= NotificationQueue.Active.Duration then
            NotificationQueue.LastDismissed = NotificationQueue.Active
            NotificationQueue.Active = nil
            if #NotificationQueue.List > 0 then
                NotificationQueue.Active = Impl.PopHighestPriorityNotif()
                NotificationQueue.StartTime = nowClk
                if not IsNotifDeferred(NotificationQueue.Active) then
                    TriggerStateTransition(StateMachine.States.NOTIFICATION)
                end
            elseif StateMachine.TargetState == StateMachine.States.NOTIFICATION then
                local target = inCombat and StateMachine.States.COMPACT_FIGHT or (mediaActive and StateMachine.States.COMPACT_MEDIA or StateMachine.States.COMPACT_IDLE)
                TriggerStateTransition(target)
            end
        else
            if StateMachine.TargetState ~= StateMachine.States.NOTIFICATION and not IsNotifDeferred(NotificationQueue.Active) then
                TriggerStateTransition(StateMachine.States.NOTIFICATION)
            end
        end
    elseif #NotificationQueue.List > 0 then
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

    local padHit = 6
    local isHover = (cx >= layout.x - padHit and cx <= layout.x + layout.w + padHit and cy >= layout.y - padHit and cy <= layout.y + layout.h + padHit)

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
            local kind = (NotificationQueue.Active and IsNotifDeferred(NotificationQueue.Active)) and "notif" or "aegis"
            if MouseInput.SatClickKind == kind and nowClk - (MouseInput.SatClickAt or -10) < 0.4 then
                MouseInput.SatClickAt = -10
                if kind == "notif" then
                    NotificationQueue.LastDismissed = NotificationQueue.Active
                    NotificationQueue.Active = nil
                    if #NotificationQueue.List > 0 then
                        NotificationQueue.Active = Impl.PopHighestPriorityNotif()
                        NotificationQueue.StartTime = nowClk
                    end
                else
                    GameTracker.Roshan.Dismissed = true
                end
                HapticPlaySound("toast_dismiss", 0.45)
            else
                MouseInput.SatClickAt = nowClk
                MouseInput.SatClickKind = kind
                if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.TAP_LIGHT) end
            end
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
            NotificationQueue.Active = Impl.PopHighestPriorityNotif()
            NotificationQueue.StartTime = nowClk
        end
        if NotificationQueue.Active and not IsNotifDeferred(NotificationQueue.Active) then
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
                        Impl.ToggleChipInActiveList(b.id)
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
    Focus.Tick(nowClk)
    Journey.Hidden = Journey.HiddenPhase()

    if Demo.Active then
        Demo.Tick(nowClk)
    elseif Journey.Hidden then
        Journey.Reset()
    elseif Focus.BannerStart <= nowClk and Focus.BannerUntil > nowClk and StateMachine.TargetState ~= StateMachine.States.MENU_MATCH_FOUND then
        if StateMachine.TargetState ~= StateMachine.States.FOCUS_BANNER then
            TriggerStateTransition(StateMachine.States.FOCUS_BANNER)
        end
    elseif not inGame then
        if not NotificationQueue.Active then
            local detected
            local canAccept = Engine.CanAcceptMatch and Engine.CanAcceptMatch()
            if canAccept or (Journey.AcceptedAt and nowClk - Journey.AcceptedAt < 1.2) then
                detected = StateMachine.States.MENU_MATCH_FOUND
            else
                local isSearching = Impl.GetMatchSearchInfo()
                detected = isSearching and StateMachine.States.MENU_SEARCHING or StateMachine.States.MENU_IDLE
            end
            Sheet.MenuSince = Sheet.MenuSince or nowClk
            if detected == StateMachine.States.MENU_IDLE and Sheet.Pick(nowClk) then
                detected = StateMachine.States.SHEET
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
        local pauseEnabled = ToggleOn(UI and UI.Combat and UI.Combat.PauseAlert)
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
        elseif not NotificationQueue.Active or IsNotifDeferred(NotificationQueue.Active) then
            if inCombat then
                if StateMachine.TargetState ~= StateMachine.States.COMPACT_FIGHT and StateMachine.TargetState ~= StateMachine.States.LARGE_FIGHT then
                    TriggerStateTransition(StateMachine.States.COMPACT_FIGHT)
                end
            elseif StateMachine.TargetState == StateMachine.States.NOTIFICATION or StateMachine.TargetState == StateMachine.States.MENU_IDLE or StateMachine.TargetState == StateMachine.States.MENU_SEARCHING or StateMachine.TargetState == StateMachine.States.MENU_MATCH_FOUND or StateMachine.TargetState == StateMachine.States.FOCUS_BANNER or StateMachine.TargetState == StateMachine.States.GAME_PAUSED or StateMachine.TargetState == StateMachine.States.COURIER_DELIVERED or StateMachine.TargetState == StateMachine.States.COURIER_DELIVERY or StateMachine.TargetState == StateMachine.States.COURIER_LARGE or StateMachine.TargetState == StateMachine.States.SHEET then
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
    elseif StateMachine.TargetState == StateMachine.States.NOTIFICATION then
        Config.Dimensions.CompactTargetW = Config.Dimensions.NotificationW
        Config.Dimensions.CompactTargetH = Config.Dimensions.NotificationH
        Config.Dimensions.CompactTargetR = Config.Dimensions.NotificationRadius
    elseif StateMachine.TargetState == StateMachine.States.LARGE_MEDIA then
        Config.Dimensions.CompactTargetW = Config.Dimensions.LargeMediaW
        Config.Dimensions.CompactTargetH = Config.Dimensions.LargeMediaH
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

    if HUDCustomizer.IsOpen or Demo.Active then return end

    local holdMode = UI.Main.ExpandMode and UI.Main.ExpandMode:Get() == 1
    local openOnHover = not holdMode
    local hoverDelaySec = 0.10
    local expandable = StateMachine.TargetState == StateMachine.States.COMPACT_FIGHT or StateMachine.TargetState == StateMachine.States.COURIER_DELIVERY
        or StateMachine.TargetState == StateMachine.States.COMPACT_IDLE or StateMachine.TargetState == StateMachine.States.COMPACT_MEDIA

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

        do
            if StateMachine.TargetState == StateMachine.States.LARGE_FIGHT then
                if StateMachine.UnhoverStartTime > 0 and (nowClk - StateMachine.UnhoverStartTime) >= 0.22 then
                    TriggerStateTransition(StateMachine.States.COMPACT_FIGHT)
                end
            elseif StateMachine.TargetState == StateMachine.States.COURIER_LARGE then
                if StateMachine.UnhoverStartTime > 0 and (nowClk - StateMachine.UnhoverStartTime) >= 0.22 then
                    TriggerStateTransition(StateMachine.States.COURIER_DELIVERY)
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
            elseif ButtonHits.MediaLike and cx >= ButtonHits.MediaLike.x1 and cx <= ButtonHits.MediaLike.x2 and cy >= ButtonHits.MediaLike.y1 and cy <= ButtonHits.MediaLike.y2 then
                ButtonSprings.MediaLike.scale = 0.65
                if BridgeStatus.SpotifyDebug == "closed" and string.find(string.lower(MediaData.App or ""), "spotify", 1, true) then
                    DynamicIsland.PushNotification({
                        Type = "spotify_like",
                        Tag = "Spotify",
                        Title = L("di_ui_likes_unavailable"),
                        Subtitle = L("di_ui_restart_spotify"),
                        AccentColor = Color(255, 159, 10, 255),
                        IconType = "svg",
                        FallbackSvg = "heart_outline"
                    })
                    return
                end
                local isNowLiked = not MediaData.IsLiked
                MediaData.IsLiked = isNowLiked
                if MediaData.LastTrackKey ~= "" then
                    MediaData.LikedTracks[MediaData.LastTrackKey] = isNowLiked
                end

                SendMediaCommand("like")
                DynamicIsland.PushNotification({
                    Type = "spotify_like",
                    Tag = "Spotify",
                    Title = isNowLiked and L("di_ui_liked_songs") or L("di_ui_removed_from_favorites"),
                    Subtitle = isNowLiked and L("di_ui_saved_to_library") or L("di_ui_removed_from_spotify"),
                    AccentColor = Color(255, 55, 95, 255),
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
    local baseCol = customColor or MediaTint()
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

        local col = FadeColor(Color(baseCol.r, baseCol.g, baseCol.b, 255), aMul)
        local cornerR = math.max(1, math.floor(barW / 2))

        Render.FilledRect(Vec2(bx, by), Vec2(bx + barW, by + intH), col, cornerR)
    end
end

local function Glyph(name, cx, cy, sz, col)
    local h = GetVectorIcon(name)
    if h and sz > 0 then
        Render.Image(h, Vec2(math.floor(cx - sz / 2 + 0.5), math.floor(cy - sz / 2 + 0.5)), Vec2(sz, sz), col, 0)
    end
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
            local candidate = (table.concat(chars, "", 1, n):gsub("%s+$", "")) .. "…"
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
    for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        local x0 = #prefix > 0 and Render.TextSize(font, size, prefix).x or 0
        prefix = prefix .. ch
        g[#g + 1] = { ch = ch, x0 = x0, x1 = Render.TextSize(font, size, prefix).x }
    end
    Marquee.Glyphs[key] = g
    Marquee.GlyphCount = Marquee.GlyphCount + 1
    return g
end

local function RenderMarqueeText(font, size, text, boxX, boxY, boxW, color, scale)
    local fullSize = Render.TextSize(font, size, text)
    local ix = math.floor(boxX)
    local iy = math.floor(boxY)
    local iw = math.floor(boxW)

    if fullSize.x <= iw then
        Render.Text(font, size, text, Vec2(ix, iy), color)
        return
    end

    local now = os.clock()
    local run = Marquee.Runs[text]
    if not run or now - run.seen > 0.5 then
        run = { t0 = now }
        Marquee.Runs[text] = run
    end
    run.seen = now

    local speed = (UI and UI.Media and UI.Media.MarqueeSpeed) and UI.Media.MarqueeSpeed:Get() or 45
    local gap = math.floor(math.max(28 * scale, iw * 0.2))
    local totalCycle = fullSize.x + gap
    local hold = 2.2
    local phase = (now - run.t0) % (hold + totalCycle / speed)
    local offset = phase < hold and 0 or math.floor((phase - hold) * speed)

    local fadeW = math.floor(14 * scale)
    local leftFade = math.min(1, offset / math.max(1, fadeW))
    if offset > totalCycle - fadeW then leftFade = math.max(0, (totalCycle - offset) / math.max(1, fadeW)) end
    local glyphs = Marquee.Layout(font, size, text)
    local baseA = color.a or 255
    local right = ix + iw

    Render.PushClip(Vec2(ix, iy - 2), Vec2(right, iy + fullSize.y + 4))
    for copy = 0, 1 do
        local ox = ix - offset + copy * totalCycle
        if ox < right and ox + fullSize.x > ix then
            for _, gl in ipairs(glyphs) do
                local gx0, gx1 = ox + gl.x0, ox + gl.x1
                if gx1 > ix and gx0 < right then
                    local mid = (gx0 + gx1) / 2
                    local a = 1
                    if mid > right - fadeW then a = math.max(0, (right - mid) / fadeW) end
                    if mid < ix + fadeW then a = math.min(a, 1 - leftFade * (1 - math.max(0, (mid - ix) / fadeW))) end
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
        Render.Image(imgH, Vec2(ix, iy), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), aMul * fadeIn), ir)
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
            Render.Image(h, Vec2(x, math.floor(midY - sz / 2 + MenuIconOffsetY * layout.scale)), Vec2(sz, sz), FadeColor(Config.Colors.TextSecondary, aMul), 0)
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
        if sucT < 1.2 then
            Success.Draw("accept" .. tostring(Journey.AcceptedAt), c, r, sucT, aMul, scale)
            return
        end
        Render.FilledCircle(c, r, FadeColor(Config.Colors.Green, aMul), 0, 1.0, 32)
        local h = GetVectorIcon("check")
        local isz = math.floor(r * 1.3)
        if h then
            Render.Image(h, Vec2(math.floor(c.x - isz / 2), math.floor(c.y - isz / 2)), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), aMul), 0)
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
                Render.Image(iconHandle, Vec2(drawX, iconY), Vec2(iconSz, iconSz), chip.color, 0)
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
        Render.FilledRect(p1, p2, FadeColor(UI.Main.IslandBgColor:Get(), a), radius)
    end
    local curBorder = borderCol
    if StateMachine.TargetState == StateMachine.States.MENU_MATCH_FOUND then
        local g = Config.Colors.Green
        curBorder = Color(g.r, g.g, g.b, 150)
    end
    Render.Rect(p1, p2, FadeColor(curBorder, a), radius, Enum.DrawFlags.None, thickness or 1.0)
end

local function DrawerSurface(p1, p2, radius, aMul)
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
        if tab and ch:match("^%d$") then
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
        out = out .. s:sub(i, i)
        local left = len - i
        if left > 0 and left % 3 == 0 then out = out .. sep end
    end
    return ((n or 0) < 0 and "-" or "") .. out
end

function Odometer.Tabular(text)
    return text:find("%d") ~= nil and text:find("/") == nil
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
        local a = tonumber((st.cur:gsub("%D", "")))
        local b = tonumber((text:gsub("%D", "")))
        st.dir = (a and b and b < a) and -1 or 1
        st.prev, st.cur, st.t0 = st.cur, text, now
    end
    st.seen = now
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
        if Haptic and Haptic.Trigger then Haptic.Trigger(Haptic.Types.SUCCESS_APPLE_PAY) end
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
    st.p, st.pv = SolveDampedSpring(st.p, st.pv, keep and 1 or 0, dt, 7.0, 0.62)
    local wideT = (want and wide and st.p > 0.55) and 1 or 0
    st.w, st.wv = SolveDampedSpring(st.w, st.wv, wideT, dt, 8.0, 0.74)
    return st
end

function Satellite.Draw(layout, st, side, fullW, content)
    local p = st.p
    if p < 0.01 then return nil end
    local scale = layout.scale
    local rowY, bh = Focus.SatRow(layout)
    local cy = rowY + bh / 2
    local d = bh * (0.34 + 0.66 * math.min(p, 1.12))
    local w = d + math.max(0, fullW - bh) * math.max(0, math.min(1.08, st.w))
    local gap = 8 * scale
    local edge = (side > 0) and (layout.x + layout.w) or layout.x
    local travel = (gap + d / 2) * p - d / 2
    local x1 = (side > 0) and (edge + travel) or (edge - travel - w)
    x1 = math.floor(x1 + 0.5)
    local y1 = math.floor(cy - d / 2 + 0.5)
    local x2 = x1 + math.floor(w + 0.5)
    local y2 = y1 + math.floor(d + 0.5)
    local a = math.min(1, p * 3)
    if p < 0.6 and not IsPureGlass() then
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
            Render.Image(h, Vec2(math.floor(c.x - isz / 2), math.floor(c.y - isz / 2)), Vec2(isz, isz), FadeColor(accent, ca), 0)
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
            Render.Image(h, Vec2(math.floor(x + (sz - s2) / 2), math.floor(midY - s2 / 2 + dy)), Vec2(s2, s2), FadeColor(on and Focus.Accent or Config.Colors.TextSecondary, aMul * a), 0)
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
        Render.Image(moon, Vec2(math.floor(cc.x - isz / 2), math.floor(cc.y - isz / 2)), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), aMul), 0)
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
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), FadeColor(Config.Colors.SegTrack, aMul), h / 2)
    local segW = w / n
    local tx = x + 2 + spring.v * segW
    SoftShadow(Vec2(tx, y + 2), Vec2(tx + segW - 4, y + h - 2), (h - 4) / 2, Color(0, 0, 0, math.floor(60 * aMul)), 5, Vec2(0, 1))
    Render.FilledRect(Vec2(tx, y + 2), Vec2(tx + segW - 4, y + h - 2), FadeColor(Config.Colors.SegThumb, aMul), (h - 4) / 2)
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
Impl.SEG_COLOR = { { label = "di_drawer_white", val = 1 }, { label = "di_drawer_dim", val = 2 }, { label = "di_drawer_custom", val = 3 } }
Impl.SEG_FORMAT = { { label = "di_drawer_standard", val = 1 }, { label = "di_drawer_minimal", val = 2 }, { label = "di_drawer_detailed", val = 3 } }

function Impl.RenderSettingsLabel(x, y, rowH, label, scale, aMul)
    local f, s = TF("Footnote", scale)
    local ts = Render.TextSize(f, s, label)
    Render.Text(f, s, label, Vec2(x, math.floor(y + (rowH - ts.y) / 2)), FadeColor(Config.Colors.TextPrimary, aMul))
end

function Impl.RenderWidgetSettings(cx, cw, cy, scale, aMul, dt)
    local id = HUDCustomizer.InspectedChip
    local cfg = HUDCustomizer.WidgetConfigs[id]
    if not cfg then return end

    local anim = HUDCustomizer.Anim
    local padX = 14 * scale

    local label = id
    for _, c in ipairs(HUDCustomizer.AvailableChips) do
        if c.id == id then label = L(c.label) end
    end

    local hdrY = cy + 11 * scale
    local fH, sH = TF("FootnoteEm", scale)
    Render.Text(fH, sH, label, Vec2(cx + padX, hdrY), FadeColor(Config.Colors.TextPrimary, aMul))

    local closeR = 9 * scale
    local closeX = cx + cw - padX - closeR
    local closeY = hdrY + 5 * scale
    Render.FilledCircle(Vec2(closeX, closeY), closeR, FadeColor(Config.Colors.SegTrack, aMul), 0, 1.0, 20)
    Glyph("close", closeX, closeY, math.floor(closeR * 1.05), FadeColor(Config.Colors.TextSecondary, aMul))
    if aMul > 0.6 then
        table.insert(HUDCustomizer.InspectorBounds, { x1 = closeX - closeR, y1 = closeY - closeR, x2 = closeX + closeR, y2 = closeY + closeR, action = "close_inspector" })
    end

    local rowH = 30 * scale
    local segW = 172 * scale
    local segH = 24 * scale
    local segX = cx + cw - padX - segW
    local rowY = cy + 30 * scale

    Impl.RenderSettingsLabel(cx + padX, rowY, rowH, L("di_ui_weight"), scale, aMul)
    Impl.RenderSegmented(segX, rowY + (rowH - segH) / 2, segW, segH, Impl.SEG_WEIGHT, cfg.bold and 1 or 2, anim.SegWeight, dt, scale, aMul, "set_bold")

    rowY = rowY + rowH
    Impl.RenderSettingsLabel(cx + padX, rowY, rowH, L("di_ui_color"), scale, aMul)
    Impl.RenderSegmented(segX, rowY + (rowH - segH) / 2, segW, segH, Impl.SEG_COLOR, cfg.colorMode or 1, anim.SegColor, dt, scale, aMul, "set_color")

    if cfg.colorMode == 3 then
        rowY = rowY + rowH
        local curCol = cfg.customColor or GetDefaultWidgetColor(id)
        local curHex = cfg.customHex or select(2, GetDefaultWidgetColor(id))

        Impl.RenderSettingsLabel(cx + padX, rowY, rowH, L("di_ui_palette"), scale, aMul)
        local fL, sL = TF("Footnote", scale)
        local lblSize = Render.TextSize(fL, sL, L("di_ui_palette"))

        local prevR = 8 * scale
        local prevX = cx + padX + lblSize.x + 14 * scale
        local prevY = rowY + rowH / 2
        SoftShadow(Vec2(prevX - prevR, prevY - prevR), Vec2(prevX + prevR, prevY + prevR), prevR, Color(0, 0, 0, math.floor(110 * aMul)), 6, Vec2(0, 1))
        Render.FilledCircle(Vec2(prevX, prevY), prevR, FadeColor(curCol, aMul), 0, 1.0, 22)
        local ringCol = HUDCustomizer.ColorPickerOpen and Config.Colors.Blue or Config.Colors.TextSecondary
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
        local segSteps = 6
        local midW = segW - barR * 2

        local c0r, c0g, c0b = HSVtoRGB(0, 0.90, 1.0)
        Render.FilledCircle(Vec2(segX + barR, barY + barR), barR, FadeColor(Color(c0r, c0g, c0b, 255), aMul), 0, 1.0, 16)
        local c1r, c1g, c1b = HSVtoRGB(360, 0.90, 1.0)
        Render.FilledCircle(Vec2(segX + segW - barR, barY + barR), barR, FadeColor(Color(c1r, c1g, c1b, 255), aMul), 0, 1.0, 16)

        for i = 0, segSteps - 1 do
            local ar, ag, ab = HSVtoRGB(i / segSteps * 360, 0.90, 1.0)
            local br, bg, bb = HSVtoRGB((i + 1) / segSteps * 360, 0.90, 1.0)
            local x1 = segX + barR + (i / segSteps) * midW
            local x2 = segX + barR + ((i + 1) / segSteps) * midW + (i < segSteps - 1 and 0.6 or 0)
            local ca, cb = FadeColor(Color(ar, ag, ab, 255), aMul), FadeColor(Color(br, bg, bb, 255), aMul)
            Render.Gradient(Vec2(x1, barY), Vec2(x2, barY + barH), ca, cb, ca, cb, 0)
        end
        Render.Rect(Vec2(segX, barY), Vec2(segX + segW, barY + barH), FadeColor(Color(255, 255, 255, 55), aMul), barR, Enum.DrawFlags.None, 1.0)

        local curHue = RGBtoHue(curCol.r, curCol.g, curCol.b)
        local knobX = segX + (curHue / 360) * segW
        local knobY = barY + barH / 2
        local knobR = 6.5 * scale

        SoftShadow(Vec2(knobX - knobR, knobY - knobR), Vec2(knobX + knobR, knobY + knobR), knobR, Color(0, 0, 0, math.floor(120 * aMul)), 6, Vec2(0, 1.5))
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
    Impl.RenderSettingsLabel(cx + padX, rowY, rowH, L("di_ui_format"), scale, aMul)
    Impl.RenderSegmented(segX, rowY + (rowH - segH) / 2, segW, segH, Impl.SEG_FORMAT, cfg.format or 1, anim.SegFormat, dt, scale, aMul, "set_format")

    rowY = rowY + rowH
    Impl.RenderSettingsLabel(cx + padX, rowY, rowH, L("di_ui_icon"), scale, aMul)
    local swW, swH = 42 * scale, 25 * scale
    local swX = cx + cw - padX - swW
    local swY = rowY + (rowH - swH) / 2
    Impl.RenderSwitch(swX, swY, swW, swH, cfg.showIcon ~= false, anim.Knob, dt, aMul)
    if aMul > 0.6 then
        table.insert(HUDCustomizer.InspectorBounds, { x1 = swX, y1 = swY, x2 = swX + swW, y2 = swY + swH, action = "toggle_icon" })
    end
end

function Impl.RenderColorPickerPopover(cx, cy, cardW, scale, dt)
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

    local SWATCHES = {
        { 255, 69, 58, "FF453A" }, { 255, 159, 10, "FF9F0A" }, { 255, 214, 10, "FFD60A" }, { 48, 209, 88, "30D158" },
        { 99, 230, 226, "63E6E2" }, { 64, 200, 224, "40C8E0" }, { 100, 210, 255, "64D2FF" }, { 10, 132, 255, "0A84FF" },
        { 94, 92, 230, "5E5CE6" }, { 191, 90, 242, "BF5AF2" }, { 255, 55, 95, "FF375F" }, { 172, 142, 104, "AC8E68" },
        { 142, 142, 147, "8E8E93" }, { 255, 255, 255, "FFFFFF" }
    }

    local pad = 12 * scale
    local popW = 216 * scale
    local gap = 6 * scale
    local cols = 7
    local sw = (popW - pad * 2 - gap * (cols - 1)) / cols
    local gridTop = 34 * scale
    local gridH = sw * 2 + gap
    local canvasTop = gridTop + gridH + 12 * scale
    local canvasH = 70 * scale
    local previewR = 8 * scale
    local popH = canvasTop + canvasH + 9 * scale + 8 * scale + 6 * scale + 8 * scale + 12 * scale + previewR * 2 + pad

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
    local popRad = 16 * scale

    SoftShadow(p1, p2, popRad, Color(0, 0, 0, math.floor(220 * popA)), 28, Vec2(0, 8))
    DrawerSurface(p1, p2, popRad, popA)

    local hdrY = math.floor(popY + 11 * scale)
    local fH, sH = TF("FootnoteEm", scale)
    Render.Text(fH, sH, L("di_ui_color_picker"), Vec2(popX + pad, hdrY), FadeColor(Config.Colors.TextPrimary, popA))

    local closeR = 9 * scale
    local closeX = popX + popW - pad - closeR
    local closeY = hdrY + Render.TextSize(fH, sH, "Ag").y / 2
    Render.FilledCircle(Vec2(closeX, closeY), closeR, FadeColor(Config.Colors.SegTrack, popA), 0, 1.0, 18)
    Glyph("close", closeX, closeY, math.floor(closeR * 1.05), FadeColor(Config.Colors.TextSecondary, popA))

    if popA > 0.6 then
        table.insert(HUDCustomizer.InspectorBounds, {
            x1 = closeX - closeR - 4, y1 = closeY - closeR - 4,
            x2 = closeX + closeR + 4, y2 = closeY + closeR + 4,
            action = "close_color_picker"
        })
    end

    for i, q in ipairs(SWATCHES) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local qx = popX + pad + col * (sw + gap) + sw / 2
        local qy = popY + gridTop + row * (sw + gap) + sw / 2
        local r = sw / 2
        local selected = string.upper(curHex) == q[4]
        local rr = selected and (r - 3.5 * scale) or r
        Render.FilledCircle(Vec2(qx, qy), rr, FadeColor(Color(q[1], q[2], q[3], 255), popA), 0, 1.0, 24)
        if q[4] == "FFFFFF" then
            Render.Circle(Vec2(qx, qy), rr, FadeColor(Config.Colors.Separator, popA), 1.0, 0, 1.0, false, 32)
        end
        if selected then
            Render.Circle(Vec2(qx, qy), r - 1, FadeColor(Color(q[1], q[2], q[3], 255), popA), 2 * scale, 0, 1.0, false, 32)
        end
        if popA > 0.6 then
            table.insert(HUDCustomizer.InspectorBounds, {
                x1 = qx - r, y1 = qy - r, x2 = qx + r, y2 = qy + r,
                action = "pop_pick_quick",
                r = q[1], g = q[2], b = q[3], hex = q[4], id = id
            })
        end
    end

    local canvasX = popX + pad
    local canvasY = popY + canvasTop
    local canvasW = popW - pad * 2

    Render.Line(Vec2(popX + pad, canvasY - 6 * scale), Vec2(popX + popW - pad, canvasY - 6 * scale), FadeColor(Config.Colors.Separator, popA), 1.0)

    local pr, pg, pb = HSVtoRGB(curHue, 1, 1)
    local cA, cB = Vec2(canvasX, canvasY), Vec2(canvasX + canvasW, canvasY + canvasH)
    local white, pure = FadeColor(Color(255, 255, 255, 255), popA), FadeColor(Color(pr, pg, pb, 255), popA)
    local clear, black = Color(0, 0, 0, 0), FadeColor(Color(0, 0, 0, 255), popA)
    Render.Gradient(cA, cB, white, pure, white, pure, 4 * scale)
    Render.Gradient(cA, cB, clear, clear, black, black, 4 * scale)
    Render.Rect(Vec2(canvasX, canvasY), Vec2(canvasX + canvasW, canvasY + canvasH), FadeColor(Config.Colors.Border, popA), 4 * scale, Enum.DrawFlags.None, 1.0)

    local reticleX = canvasX + curSat * canvasW
    local reticleY = canvasY + (1.0 - curVal) * canvasH
    local retR = 6 * scale
    SoftShadow(Vec2(reticleX - retR, reticleY - retR), Vec2(reticleX + retR, reticleY + retR), retR, Color(0, 0, 0, math.floor(110 * popA)), 4, Vec2(0, 1))
    Render.FilledCircle(Vec2(reticleX, reticleY), retR, FadeColor(Color(255, 255, 255, 255), popA), 0, 1.0, 18)
    Render.FilledCircle(Vec2(reticleX, reticleY), retR - 2 * scale, FadeColor(curCol, popA), 0, 1.0, 16)

    if popA > 0.6 then
        table.insert(HUDCustomizer.InspectorBounds, {
            x1 = canvasX - 2, y1 = canvasY - 2,
            x2 = canvasX + canvasW + 2, y2 = canvasY + canvasH + 2,
            action = "drag_pop_sv",
            x = canvasX, y = canvasY, w = canvasW, h = canvasH, id = id
        })
    end

    local function Bar(barY, steps, colorAt, knobT, knobCol, action)
        local barH = 8 * scale
        local barR = barH / 2
        local midW = canvasW - barR * 2
        local c0 = colorAt(0)
        local c1 = colorAt(1)
        Render.FilledCircle(Vec2(canvasX + barR, barY + barR), barR, FadeColor(c0, popA), 0, 1.0, 16)
        Render.FilledCircle(Vec2(canvasX + canvasW - barR, barY + barR), barR, FadeColor(c1, popA), 0, 1.0, 16)
        for i = 0, steps - 1 do
            local x1 = canvasX + barR + (i / steps) * midW
            local x2 = canvasX + barR + ((i + 1) / steps) * midW + (i < steps - 1 and 0.6 or 0)
            local ca, cb = FadeColor(colorAt(i / steps), popA), FadeColor(colorAt((i + 1) / steps), popA)
            Render.Gradient(Vec2(x1, barY), Vec2(x2, barY + barH), ca, cb, ca, cb, 0)
        end
        local kx = canvasX + knobT * canvasW
        local ky = barY + barH / 2
        local kr = 6 * scale
        SoftShadow(Vec2(kx - kr, ky - kr), Vec2(kx + kr, ky + kr), kr, Color(0, 0, 0, math.floor(110 * popA)), 4, Vec2(0, 1))
        Render.FilledCircle(Vec2(kx, ky), kr, FadeColor(Color(255, 255, 255, 255), popA), 0, 1.0, 18)
        Render.FilledCircle(Vec2(kx, ky), kr - 2 * scale, FadeColor(knobCol, popA), 0, 1.0, 16)
        if popA > 0.6 then
            table.insert(HUDCustomizer.InspectorBounds, {
                x1 = canvasX - 2, y1 = barY - 4,
                x2 = canvasX + canvasW + 2, y2 = barY + barH + 4,
                action = action,
                x = canvasX, w = canvasW, id = id
            })
        end
        return barY + barH
    end

    local hr0, hg0, hb0 = HSVtoRGB(curHue, 0.90, 1.0)
    local hEnd = Bar(canvasY + canvasH + 9 * scale, 6, function(t)
        local r, g, b = HSVtoRGB(t * 360, 0.90, 1.0)
        return Color(r, g, b, 255)
    end, curHue / 360, Color(hr0, hg0, hb0, 255), "drag_pop_hue")
    local vEnd = Bar(hEnd + 6 * scale, 1, function(t)
        local r, g, b = HSVtoRGB(curHue, curSat, t)
        return Color(r, g, b, 255)
    end, curVal, curCol, "drag_pop_val")

    local btmY = vEnd + 12 * scale
    local fC, sC = TF("Caption", scale)
    Render.FilledCircle(Vec2(canvasX + previewR, btmY + previewR), previewR, FadeColor(curCol, popA), 0, 1.0, 20)
    Render.Circle(Vec2(canvasX + previewR, btmY + previewR), previewR, FadeColor(Config.Colors.Border, popA), 1.0, 0, 1.0, false, 24)
    local hexLabel = "#" .. string.upper(curHex)
    local hexSz = Render.TextSize(fC, sC, hexLabel)
    Odometer.Draw(fC, sC, hexLabel, Vec2(math.floor(canvasX + previewR * 2 + 8 * scale), math.floor(btmY + previewR - hexSz.y / 2)), FadeColor(Config.Colors.TextSecondary, popA))

    local rstText = L("di_ui_reset")
    local rstS = Render.TextSize(fC, sC, rstText)
    local rstW = rstS.x + 16 * scale
    local rstH = 20 * scale
    local rstX = popX + popW - pad - rstW
    local rstY = btmY + previewR - rstH / 2
    Render.FilledRect(Vec2(rstX, rstY), Vec2(rstX + rstW, rstY + rstH), FadeColor(Config.Colors.SegTrack, popA), rstH / 2)
    Render.Text(fC, sC, rstText, Vec2(math.floor(rstX + (rstW - rstS.x) / 2), math.floor(rstY + (rstH - rstS.y) / 2)), FadeColor(Config.Colors.TextPrimary, popA))

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

function Impl.RenderHUDDrawer(layout, dt)
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
        anim.h, anim.hVel = MotionEngine.Step(anim.h, anim.hVel, targetH, dt, "SMOOTH")
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

    Render.PushClip(p1, p2)

    local cx = math.floor(layout.x + (layout.w - cardW) / 2)
    local grabW = 34 * scale
    Render.FilledRect(Vec2(cx + (cardW - grabW) / 2, py + 8 * scale), Vec2(cx + (cardW + grabW) / 2, py + 12 * scale), FadeColor(Config.Colors.Grabber, contentA), 2 * scale)
    local fW, sW = TF("Footnote", scale)
    Render.Text(fW, sW, L("di_ui_widgets"), Vec2(cx + padX, py + 18 * scale), FadeColor(Config.Colors.TextSecondary, contentA))

    local chipY = py + chipsTop
    for i, chip in ipairs(HUDCustomizer.AvailableChips) do
        local bx = math.floor(cx + padX + ((i - 1) % 4) * (chipW + gap))
        local by = math.floor(chipY + math.floor((i - 1) / 4) * (chipH + gap))
        local active = Impl.IsChipInActiveList(chip.id)

        local ca = Impl.ChipAnim(chip.id)
        ca.fill, ca.fillVel = MotionEngine.Step(ca.fill, ca.fillVel, active and 1 or 0, dt, "SMOOTH")
        ca.scale, ca.scaleVel = MotionEngine.Step(ca.scale, ca.scaleVel, 1.0, dt, "SNAPPY")
        local insetX = chipW * (1 - ca.scale) / 2
        local insetY = chipH * (1 - ca.scale) / 2
        local q1 = Vec2(bx + insetX, by + insetY)
        local q2 = Vec2(bx + chipW - insetX, by + chipH - insetY)
        local qr = (chipH - insetY * 2) / 2

        Render.FilledRect(q1, q2, FadeColor(LerpColor(Config.Colors.ChipInactive, Config.Colors.ChipActiveBorder, ca.fill), contentA), qr)
        Render.Rect(q1, q2, FadeColor(Config.Colors.ChipInactiveBorder, contentA * (1 - ca.fill)), qr, Enum.DrawFlags.None, 1.0)
        if HUDCustomizer.InspectedChip == chip.id then
            Render.Rect(Vec2(q1.x - 2 * scale, q1.y - 2 * scale), Vec2(q2.x + 2 * scale, q2.y + 2 * scale), FadeColor(Config.Colors.Blue, contentA), qr + 2 * scale, Enum.DrawFlags.None, 1.5)
        end

        local f, s = TF("Footnote", scale)
        if ca.fill > 0.5 then f = Config.Fonts.Semibold end
        local ls = Render.TextSize(f, s, L(chip.label))
        Render.Text(f, s, L(chip.label), Vec2(math.floor(bx + (chipW - ls.x) / 2), math.floor(by + (chipH - ls.y) / 2)), FadeColor(LerpColor(Config.Colors.TextPrimary, Config.Colors.TextInverse, ca.fill), contentA))

        if contentA > 0.6 then
            table.insert(HUDCustomizer.DrawerBounds, { x1 = bx, y1 = by, x2 = bx + chipW, y2 = by + chipH, id = chip.id, action = "toggle" })
        end
    end

    if HUDCustomizer.InspectedChip then
        Impl.RenderWidgetSettings(cx, cardW, py + baseH - 12 * scale, scale, contentA, dt)
    end

    if hintsOn then
        local fh, sh = TF("Caption", scale)
        local hint = TruncateToWidth(fh, sh, L("di_ui_drawer_hint"), math.floor(cardW - 24 * scale))
        local hs = Render.TextSize(fh, sh, hint)
        Render.Text(fh, sh, hint, Vec2(math.floor(cx + (cardW - hs.x) / 2), math.floor(py + anim.h - 18 * scale)), FadeColor(Config.Colors.TextSecondary, contentA))
    end

    Render.PopClip()

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
    if not HUDCustomizer.IsOpen and (Rampage.Active or rampageSuccess) then
        desired = "rampage"
    elseif UI.Media.SecondaryBubble:Get() and not HUDCustomizer.IsOpen then
        if active and IsNotifDeferred(active) and (ts == StateMachine.States.COMPACT_MEDIA or ts == StateMachine.States.LARGE_MEDIA) then
            local left = (active.Duration or 3) - (now - (NotificationQueue.StartTime or now))
            if left > 0.45 then
                desired, notif = "notif", active
            end
        elseif FightTracker.Active and (active or IsMediaActive()) then
            desired = "combat"
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
    local wide = kind == "notif" or kind == "aegis" or (combatMedia and FightTracker.SatelliteHover) or (kind == "rampage" and not rampageSuccess)
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
                Render.Image(hIcon, Vec2(math.floor(c.x - isz / 2), math.floor(c.y - isz / 2)), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), ca), math.floor(isz / 2))
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
                    Render.Image(hImg, Vec2(math.floor(c.x - isz / 2), math.floor(c.y - isz / 2)), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), ca), math.floor(isz / 2))
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
                Render.Image(aegisH, Vec2(math.floor(c.x - isz / 2), math.floor(c.y - isz / 2)), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), ca), math.floor(isz / 2))
            end
            if ta > 0.01 then
                Odometer.Text("aegis_time", fontBold, fontSize, timeStr, Vec2(math.floor(x1 + d + 5 * scale), math.floor(c.y - tsz.y / 2)), FadeColor(Config.Colors.TextPrimary, ta))
            end
        end
    else
        local step = math.floor(26 * scale)
        fullW = bh + step * 3 + math.floor(6 * scale)
        content = function(x1, y1, x2, y2, d, ca, ta)
            local c = Vec2(x1 + d / 2, (y1 + y2) / 2)
            if active then
                local isz = math.floor(d * 0.52)
                local hIcon = GetCachedImage(active.Icon, active.FallbackSvg)
                if hIcon then
                    Render.Image(hIcon, Vec2(math.floor(c.x - isz / 2), math.floor(c.y - isz / 2)), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), ca), math.floor(isz / 2))
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
                    Render.Image(h, Vec2(math.floor(bxc - sz / 2), math.floor(c.y - sz / 2)), Vec2(sz, sz), FadeColor(Config.Colors.TextPrimary, ta), 0)
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
    if MediaData.Artist ~= "" and MediaData.Title ~= "" then
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
            local oldStr = TrackTransition.OldTitle .. (TrackTransition.OldArtist ~= "" and (" • " .. TrackTransition.OldArtist) or "")
            if showTitle then RenderMarqueeText(fontBold, headSize, oldStr, textStartX + outOffset, textY, textAvailW, FadeColor(Config.Colors.TextPrimary, outAlpha), scale) end
            DrawAlbumThumbnail(thumbX, thumbY, thumbSize, 5 * scale, outAlpha, 1.0 - t * 0.15, TrackTransition.OldCoverHandle, TrackTransition.OldCoverColor)
        end
        if inAlpha > 0.02 then
            if showTitle then RenderMarqueeText(fontBold, headSize, displayStr, textStartX + inOffset, textY, textAvailW, FadeColor(Config.Colors.TextPrimary, inAlpha), scale) end
            DrawAlbumThumbnail(thumbX, thumbY, thumbSize, 5 * scale, inAlpha, 0.85 + t * 0.15)
        end
        if t >= 1.0 then
            TrackTransition.Active = false
        end
    else
        if CompactMediaTitle() then RenderMarqueeText(fontBold, headSize, displayStr, textStartX, textY, textAvailW, textCol, scale) end
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
        Render.Image(swordsSvg, Vec2(iconX, iconY), Vec2(iconSz, iconSz), FadeColor(Config.Colors.Red, aMul), 0)
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
        Render.Image(swords, Vec2(hdrX, math.floor(hdrY + hdrSize.y / 2 - swSz / 2)), Vec2(swSz, swSz), FadeColor(Config.Colors.Red, aMul), 0)
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
            Render.Image(hHandle, Vec2(ax, ay), Vec2(avatarSz, avatarSz), FadeColor(Color(255, 255, 255, 255), aMul), avatarSz / 2)
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
        Render.Image(mapH, rP1, Vec2(radarSz, radarSz), FadeColor(Color(255, 255, 255, 255), aMul), radarR, Enum.DrawFlags.None, uvMin, uvMax)
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
                Render.Image(hIcon, Vec2(math.floor(hX - tSz / 2), math.floor(hY - tSz / 2)), Vec2(tSz, tSz), FadeColor(Color(255, 255, 255, 255), aMul), tSz / 2)
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

    if notif.Type == "apple_pay" then
        local green = Config.Colors.Green
        local elapsed = now - (NotificationQueue.StartTime or now)
        local pulseT = math.min(1.0, elapsed * 5.0)
        local checkScale = EaseOutBack(pulseT)

        local iconSz = math.floor(24 * scale)
        local iconX = math.floor(layout.x + 12 * scale)
        local iconY = math.floor(layout.y + (layout.h - iconSz) / 2 + yOff)

        Render.FilledCircle(Vec2(iconX + iconSz / 2, iconY + iconSz / 2), math.floor(iconSz / 2 * checkScale), FadeColor(green, aMul), 0, 1.0, 28)

        Glyph("check", iconX + iconSz / 2, iconY + iconSz / 2, math.floor(iconSz * 0.62 * checkScale), FadeColor(Color(255, 255, 255, 255), aMul))

        local textX = math.floor(iconX + iconSz + 10 * scale)
        local qW = QueueBadge()
        TwoLines(textX, math.floor(layout.x + layout.w - textX - 14 * scale - qW), notif.Tag or L("di_ui_notification"), green, notif.Title or L("di_ui_success"))
        return
    end

    if notif.Type == "apple_action_dial" then
        local accent = notif.AccentColor or Config.Colors.Green
        local isEnabled = (notif.Subtitle == "ENABLED")
        local isTap = (notif.Subtitle == "TRIGGERED")

        local iconSz = math.floor(24 * scale)
        local iconX = math.floor(layout.x + 12 * scale)
        local iconY = math.floor(layout.y + (layout.h - iconSz) / 2 + yOff)

        Render.FilledCircle(Vec2(iconX + iconSz / 2, iconY + iconSz / 2), math.floor(iconSz / 2), FadeColor(accent, aMul * 0.22), 0, 1.0, 24)
        Render.Circle(Vec2(iconX + iconSz / 2, iconY + iconSz / 2), math.floor(iconSz / 2), FadeColor(accent, aMul * 0.85), 1.2 * scale)

        Glyph(isTap and "bolt" or (isEnabled and "check" or "close"), iconX + iconSz / 2, iconY + iconSz / 2, math.floor(iconSz * 0.55), FadeColor(accent, aMul))

        local badgeTxt = isTap and L("di_ui_tap") or (isEnabled and L("di_focus_on") or L("di_focus_off"))
        local fB, sB = TF("Caption", scale)
        fB = Config.Fonts.Semibold
        local badgeSz = Render.TextSize(fB, sB, badgeTxt)
        local badgeH = math.floor(20 * scale)
        local badgeW = math.floor(math.max(40 * scale, badgeSz.x + 16 * scale))
        local badgeX = math.floor(layout.x + layout.w - 14 * scale - badgeW)
        local badgeY = math.floor(layout.y + (layout.h - badgeH) / 2 + yOff)
        local badgeR = math.floor(badgeH / 2)

        local badgeBg = isTap and Config.Colors.Blue or (isEnabled and Config.Colors.Green or Config.Colors.Fill)
        Render.FilledRect(Vec2(badgeX, badgeY), Vec2(badgeX + badgeW, badgeY + badgeH), FadeColor(badgeBg, aMul), badgeR)
        Render.Text(fB, sB, badgeTxt, Vec2(math.floor(badgeX + (badgeW - badgeSz.x) / 2), math.floor(badgeY + (badgeH - badgeSz.y) / 2)), FadeColor(Color(255, 255, 255, 255), aMul))

        local textX = math.floor(iconX + iconSz + 10 * scale)
        TwoLines(textX, math.floor(badgeX - textX - 8 * scale), notif.Tag or L("di_ui_notification"), Config.Colors.TextSecondary, notif.Title)
        return
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

        if hA then Render.Image(hA, Vec2(iconX, iconY + offA), Vec2(iconW, iconH), FadeColor(Color(255, 255, 255, 255), (1.0 - smoothFrac) * aMul), math.floor(iconW / 2)) end
        if hB then Render.Image(hB, Vec2(iconX, iconY + offB), Vec2(iconW, iconH), FadeColor(Color(255, 255, 255, 255), smoothFrac * aMul), math.floor(iconW / 2)) end

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
        local mono = fb and NotifGlyphs[fb]
        local realImg = notif.Icon and GetCachedImage(notif.Icon) or nil
        if realImg or (iconHandle and not mono) then
            Render.Image(realImg or iconHandle, Vec2(iconX, iconY), Vec2(iconW, iconH), FadeColor(Color(255, 255, 255, 255), aMul), iconRadius)
        else
            local cx, cy = iconX + iconW / 2, iconY + iconH / 2
            Render.FilledCircle(Vec2(cx, cy), iconH / 2, FadeColor(accent, aMul), 0, 1.0, 24)
            Glyph(fb or "bell", cx, cy, math.floor(iconH * 0.58), FadeColor(Color(255, 255, 255, 255), aMul))
        end
    end

    local textX = math.floor(layout.x + 12 * scale + iconW + 10 * scale)
    local qW = QueueBadge()
    TwoLines(textX, math.floor(layout.x + layout.w - textX - 16 * scale - qW), notif.Tag or L("di_ui_notification"), accent, notif.Title)
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
            Render.Text(fontMain, artistSz, artistStr, Vec2(infoX + inOffset, infoY + 22 * scale), FadeColor(Config.Colors.TextSecondary, inAlpha))
            DrawAlbumThumbnail(artX, artY, artSize, math.floor(12 * scale), inAlpha, 0.85 + t * 0.15)
        end
    else
        local titleSize = Render.TextSize(fontBold, titleSz, titleStr)
        if titleSize.x > maxInfoW then
            RenderMarqueeText(fontBold, titleSz, titleStr, infoX, infoY, maxInfoW, textCol, scale)
        else
            Render.Text(fontBold, titleSz, titleStr, Vec2(infoX, infoY), textCol)
        end

        local artSizeText = Render.TextSize(fontMain, artistSz, artistStr)
        local artYPos = math.floor(infoY + titleSize.y + 2 * scale)
        local artistW = UI.Media.SpotifyLike:Get() and math.max(10, math.floor(layout.x + layout.w - pad - 16 * scale - 10 * scale - infoX)) or maxInfoW
        if artSizeText.x > artistW then
            RenderMarqueeText(fontMain, artistSz, artistStr, infoX, artYPos, artistW, subCol, scale)
        else
            Render.Text(fontMain, artistSz, artistStr, Vec2(infoX, artYPos), subCol)
        end

        DrawAlbumThumbnail(artX, artY, artSize, math.floor(12 * scale), aMul)
    end

    local progressY = math.floor(artY + artSize + 14 * scale)
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

    local playScale = ButtonSprings.MediaPlay.scale
    local playX = midX
    local playY = math.floor(ctrlY + 16 * scale)
    local ctrlCol = FadeColor(Config.Colors.TextPrimary, aMul)
    Glyph(MediaData.IsPlaying and "media_pause" or "media_play", playX, playY, math.floor(26 * scale * playScale), ctrlCol)

    ButtonHits.MediaPlay = {
        x1 = playX - 22,
        y1 = playY - 22,
        x2 = playX + 22,
        y2 = playY + 22
    }

    local prevScale = ButtonSprings.MediaPrev.scale
    local prevX = math.floor(playX - 54 * scale)
    local prevY = playY
    Glyph("media_prev", prevX, prevY, math.floor(24 * scale * prevScale), ctrlCol)

    ButtonHits.MediaPrev = {
        x1 = prevX - 18,
        y1 = prevY - 18,
        x2 = prevX + 18,
        y2 = prevY + 18
    }

    local nextScale = ButtonSprings.MediaNext.scale
    local nextX = math.floor(playX + 54 * scale)
    local nextY = playY
    Glyph("media_next", nextX, nextY, math.floor(24 * scale * nextScale), ctrlCol)

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
        local shufCol = MediaData.Shuffle and Config.Colors.TextPrimary or Config.Colors.TextSecondary
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
    local repX = math.floor(layout.x + layout.w - pad - 12 * scale)
    local repY = playY
    local repH = GetVectorIcon("repeat")
    if repH then
        local repCol = (MediaData.RepeatMode > 0) and Config.Colors.TextPrimary or Config.Colors.TextSecondary
        local rSz = 14 * scale * repScale
        Render.Image(repH, Vec2(repX - rSz / 2, repY - rSz / 2), Vec2(rSz, rSz), FadeColor(repCol, aMul), 0)
        if MediaData.RepeatMode == 2 then
            Render.Text(fontTiny, tinySz, "1", Vec2(repX + 5 * scale, repY - 8 * scale), FadeColor(Config.Colors.TextPrimary, aMul))
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
        local likeX = math.floor(layout.x + layout.w - pad - 8 * scale)
        local likeY = math.floor(artY + artSize - 10 * scale)
        local heartH = GetVectorIcon(isLiked and "heart_fill" or "heart_outline")
        if heartH then
            local heartCol = isLiked and Config.Colors.Red or Config.Colors.TextSecondary
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

    local timeHM = os.date("%H:%M")
    local timeSec = os.date(":%S")
    local hmH = Render.TextSize(fNum, sNum, "0").y
    local hmW = Odometer.Width(fNum, sNum, timeHM)
    Odometer.Text("large_hm", fNum, sNum, timeHM, Vec2(g.leftX, g.leftY), textCol)
    local secH = Render.TextSize(fSec, sSec, "0").y
    Odometer.Text("large_sec", fSec, sSec, timeSec, Vec2(math.floor(g.leftX + hmW + 2 * scale), math.floor(g.leftY + (hmH - secH) * 0.8)), subCol)

    local matchTime = GetActualMatchTime()
    local subInfo = (matchTime and matchTime > 0) and (L("di_ui_match") .. FormatTime(matchTime)) or L("di_ui_main_menu")
    Odometer.Draw(fFoot, sFoot, subInfo, Vec2(g.leftX, math.floor(g.leftY + hmH + 2 * scale)), subCol)

    Render.Line(Vec2(g.divX, layout.y + 14 * scale + yOff), Vec2(g.divX, layout.y + layout.h - 14 * scale + yOff), FadeColor(Config.Colors.Separator, aMul), 1.0)

    local function Row(id, svg, txt, x, y, f, s, col, soft)
        local h = GetVectorIcon(svg)
        if h then Render.Image(h, Vec2(x, y), Vec2(g.icon, g.icon), subCol, 0) end
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
        Render.Image(pauseSvg, Vec2(badgeX, badgeY), Vec2(badgeSize, badgeSize), FadeColor(Config.Colors.Orange, alphaMul), 0)
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
        Render.Image(courierSvg, Vec2(leftX, centerY - math.floor(iconSize / 2)), Vec2(iconSize, iconSize), FadeColor(Config.Colors.Yellow, alphaMul), 0)
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
        Render.Image(courierSvg, Vec2(leftX, row1Y), Vec2(iconSz, iconSz), FadeColor(Config.Colors.Yellow, alphaMul), 0)
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
                Render.Image(itHandle, Vec2(sx + 2 * scale, sy + 2 * scale), Vec2(slotW - 4 * scale, slotH - 4 * scale), FadeColor(Color(255, 255, 255, 255), alphaMul), 4 * scale)
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
        Render.Image(volSvg, Vec2(iconX, iconY), Vec2(iconSize, iconSize), FadeColor(Config.Colors.TextPrimary, aMul), 0)
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
    local lL = StateMachine.FrameFor(layout, D.LargeMediaW, D.LargeMediaH, D.LargeMediaRadius)
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
        local compStr = (artistStr ~= "" and titleStr ~= "") and (titleStr .. " \u{2022} " .. artistStr) or titleStr
        RenderMarqueeText(fontHead, headSz, compStr, cTextStartX, cTextY, cTextAvailW, FadeColor(Config.Colors.TextPrimary, compactAlpha), scale)
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

    if secAlpha > 0.01 then
        local progressY = math.floor(lThumbY + lThumbSize + 14 * scale)
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
            Render.Image(shufH, Vec2(curShufX - sSz / 2, playY - sSz / 2), Vec2(sSz, sSz), FadeColor(shufCol, secAlpha), 0)
        end

        local repTargetX = math.floor(lL.x + lL.w - pad - 12 * scale)
        local repScale = ButtonSprings.MediaRepeat.scale * elemScale
        local curRepX = math.floor(midX + (repTargetX - midX) * bloomT)
        local repH = GetVectorIcon("repeat")
        if repH then
            local repCol = (MediaData.RepeatMode > 0) and Config.Colors.TextPrimary or Config.Colors.TextSecondary
            local rSz = 14 * scale * repScale
            Render.Image(repH, Vec2(curRepX - rSz / 2, playY - rSz / 2), Vec2(rSz, rSz), FadeColor(repCol, secAlpha), 0)
            if MediaData.RepeatMode == 2 then
                Render.Text(fontTiny, tinySz * elemScale, "1", Vec2(curRepX + 5 * scale, playY - 8 * scale), FadeColor(Config.Colors.TextPrimary, secAlpha))
            end
        end

        local likeTargetX = math.floor(lL.x + lL.w - pad - 8 * scale)
        local likeY = math.floor(curThumbY + curThumbSize - 10 * scale)
        local likeScale = ButtonSprings.MediaLike.scale * elemScale
        local curLikeX = likeTargetX
        local isLiked = (MediaData.IsLiked == true) or (MediaData.LikedTracks[MediaData.LastTrackKey] == true)
        local likeSvg = GetVectorIcon(isLiked and "heart_fill" or "heart_outline")
        if likeSvg and UI.Media.SpotifyLike:Get() then
            local lSz = 16 * scale * likeScale
            local lCol = isLiked and Config.Colors.Red or Config.Colors.TextSecondary
            Render.Image(likeSvg, Vec2(curLikeX - lSz / 2, likeY - lSz / 2), Vec2(lSz, lSz), FadeColor(lCol, secAlpha), 0)
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
    local timeHM = os.date("%H:%M")
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
            Render.Image(iconHandle, Vec2(math.floor(clockChip.startX + (curClockX - cClockX)), math.floor(midY - iconSz / 2 + MenuIconOffsetY * scale + (curClockY - cClockY))), Vec2(iconSz, iconSz), FadeColor(clockChip.chip.color, ca), 0)
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
                        Render.Image(iconHandle, Vec2(curX, iconY), Vec2(iconSz, iconSz), FadeColor(chip.color, compactAlpha), 0)
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
        Odometer.Draw(fSec, sSec, os.date(":%S"), Vec2(math.floor(curClockX + hmW + 2 * scale), math.floor(curClockY + (hmH - secH) * 0.8)), FadeColor(Config.Colors.TextSecondary, lateAlpha))
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
            if h and iconA > 0.01 then Render.Image(h, Vec2(ix, iy), Vec2(iconSz, iconSz), FadeColor(LerpColor(cm.chip.color, iconCol, elemT), iconA), 0) end
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
            if h then Render.Image(h, Vec2(ux, ty), Vec2(g.icon, g.icon), FadeColor(iconCol, lateAlpha), 0) end
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

function Sheet.UpdateInfo()
    if not Sheet.BridgeOnline() then return nil end
    local mine = Impl.ParseVersion(SCRIPT_VERSION)
    local bridge = Impl.ParseVersion(BridgeStatus.Version)
    local latest = Impl.ParseVersion(BridgeStatus.Latest)
    local canSelf = bridge and not Impl.VersionLess(bridge, { 2, 2, 0 })
    if latest and ((mine and Impl.VersionLess(mine, latest)) or (bridge and Impl.VersionLess(bridge, latest))) then
        return { title = "Dynamic Island " .. BridgeStatus.Latest:gsub("^[vV]", ""), sub = canSelf and L("di_upd_available") or L("di_upd_manual"), canSelf = canSelf }
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
    if Sheet.Upd.State ~= "idle" then
        Sheet.Kind = "update"
        return true
    end
    if Sheet.ConfigLoaded and Sheet.SeenVer ~= SCRIPT_VERSION then
        Sheet.Kind = "whatsnew"
        return true
    end
    if not Sheet.Dismissed and Sheet.UpdateInfo() then
        Sheet.Kind = "update"
        return true
    end
    return false
end

Sheet.News = {
    { glyph = "headphones", color = "Blue", t = "di_wn_1_t", d = "di_wn_1_d" },
    { glyph = "bell", color = "Orange", t = "di_wn_2_t", d = "di_wn_2_d" },
    { glyph = "hold", color = "Purple", t = "di_wn_3_t", d = "di_wn_3_d" },
    { glyph = "arrow_down", color = "Green", t = "di_wn_4_t", d = "di_wn_4_d" }
}

function Sheet.Size()
    if Sheet.Kind == "whatsnew" then
        return 360, 18 + 30 + #Sheet.News * 46 + 6 + 36 + 18
    end
    local st = Sheet.Upd.State
    if st == "downloading" or st == "installing" or st == "restarting" then
        return 340, 80
    end
    return 340, 126
end

function Sheet.UrlEncode(s)
    return (s:gsub("[^%w%-%._~]", function(c) return string.format("%%%02X", string.byte(c)) end))
end

function Sheet.StartUpdate(now)
    local dir = "C:\\Umbrella\\scripts"
    if Engine and Engine.GetCheatDirectory then
        local ok, cd = pcall(Engine.GetCheatDirectory)
        if ok and cd and cd ~= "" then dir = cd:gsub("/", "\\"):gsub("\\$", "") .. "\\scripts" end
    end
    Sheet.Upd.State = "downloading"
    Sheet.Upd.Progress = 0
    Sheet.Upd.Error = ""
    Sheet.Upd.LastOk = now
    pcall(HTTP.Request, "GET", "http://127.0.0.1:45455/update/start?dir=" .. Sheet.UrlEncode(dir), {}, function() end, "di_update_start")
end

function Sheet.PollUpdate()
    local u = Sheet.Upd
    local now = os.clock()
    if u.State == "restarting" then
        if u.ReloadAt and now >= u.ReloadAt then
            u.ReloadAt = nil
            if Engine and Engine.ReloadScriptSystem then pcall(Engine.ReloadScriptSystem) end
        end
        return
    end
    if u.State ~= "downloading" and u.State ~= "installing" then return end
    if now - u.LastOk > 20 then
        u.State = "error"
        u.Error = "offline"
        return
    end
    if now - u.LastPoll < 0.25 then return end
    u.LastPoll = now
    pcall(HTTP.Request, "GET", "http://127.0.0.1:45455/update/status", {}, function(res)
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
        Sheet.Upd.ReloadAt = now + 1.2
        pcall(HTTP.Request, "GET", "http://127.0.0.1:45455/update/restart", {}, function() end, "di_update_restart")
    elseif action == "seen" then
        Sheet.SeenVer = SCRIPT_VERSION
        Sheet.Forced = nil
        SaveAllConfig()
    elseif action == "nc_clear" then
        NotifCenter.Items = {}
    end
end

function Sheet.Button(x, y, w, h, label, primary, action, aMul, s)
    local C = Config.Colors
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), FadeColor(primary and C.Blue or C.FillSecondary, aMul), h / 2)
    local f, sz = TF("Headline", s)
    local ts = Render.TextSize(f, sz, label)
    Render.Text(f, sz, label, Vec2(math.floor(x + (w - ts.x) / 2), math.floor(y + (h - ts.y) / 2)), FadeColor(primary and Color(255, 255, 255, 255) or C.TextPrimary, aMul))
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
        Sheet.RenderUpdate(layout, alphaMul, yOffset)
    end
end

function Sheet.RenderUpdate(layout, alphaMul, yOffset)
    local a = alphaMul or 1
    local s = layout.scale
    local C = Config.Colors
    local u = Sheet.Upd
    local info = Sheet.UpdateInfo() or { title = "Dynamic Island", sub = "", canSelf = true }
    local pad = math.floor(16 * s)
    local isz = math.floor(44 * s)
    local ix = layout.x + pad
    local iy = math.floor(layout.y + pad + (yOffset or 0))
    local icx, icy = ix + isz / 2, iy + isz / 2
    local title, sub = info.title, info.sub
    local busy = u.State == "downloading" or u.State == "installing" or u.State == "restarting"

    if busy then
        local r = math.floor(18 * s)
        Render.Circle(Vec2(icx, icy), r, FadeColor(C.Fill, a), 3 * s, 0, 1.0, false, 48)
        local p = u.State == "downloading" and math.max(0.02, math.min(1, u.Progress)) or 1
        Render.Circle(Vec2(icx, icy), r, FadeColor(C.Blue, a), 3 * s, 270, p, true, 48)
        local fP, sP = TF("Caption2", s)
        local pct = string.format("%d", math.floor(p * 100 + 0.5))
        local pw = Odometer.Width(fP, sP, pct)
        local ph = Render.TextSize(fP, sP, pct).y
        Odometer.Draw(fP, sP, pct, Vec2(math.floor(icx - pw / 2), math.floor(icy - ph / 2)), FadeColor(C.TextPrimary, a))
        sub = title
        title = u.State == "downloading" and L("di_upd_downloading") or L("di_upd_installing")
    elseif u.State == "ready" then
        Render.FilledCircle(Vec2(icx, icy), isz / 2, FadeColor(C.Green, a), 0, 1.0, 32)
        Glyph("check", icx, icy, math.floor(isz * 0.5), FadeColor(Color(255, 255, 255, 255), a))
        title, sub = L("di_upd_ready"), L("di_upd_ready_sub")
    elseif u.State == "error" then
        Render.FilledCircle(Vec2(icx, icy), isz / 2, FadeColor(C.Red, a), 0, 1.0, 32)
        Glyph("close", icx, icy, math.floor(isz * 0.46), FadeColor(Color(255, 255, 255, 255), a))
        title, sub = L("di_upd_failed"), L("di_upd_failed_sub")
    else
        Render.FilledRect(Vec2(ix, iy), Vec2(ix + isz, iy + isz), FadeColor(C.Blue, a), math.floor(11 * s))
        Glyph("arrow_down", icx, icy, math.floor(isz * 0.52), FadeColor(Color(255, 255, 255, 255), a))
    end

    local tx = ix + isz + math.floor(12 * s)
    local maxW = layout.x + layout.w - pad - tx
    local fT, sT = TF("Title", s)
    local fS, sS = TF("Subhead", s)
    local th = Render.TextSize(fT, sT, "Ag").y
    local sh = Render.TextSize(fS, sS, "Ag").y
    local ty = math.floor(icy - (th + sh + 2 * s) / 2)
    Render.Text(fT, sT, TruncateToWidth(fT, sT, title, maxW), Vec2(tx, ty), FadeColor(C.TextPrimary, a))
    Render.Text(fS, sS, TruncateToWidth(fS, sS, sub, maxW), Vec2(tx, math.floor(ty + th + 2 * s)), FadeColor(C.TextSecondary, a))

    if busy then return end
    local by = iy + isz + math.floor(16 * s)
    if u.State == "ready" then
        Sheet.Buttons(layout, by, a, s, { L("di_upd_restart"), true, "restart" })
    elseif u.State == "error" then
        Sheet.Buttons(layout, by, a, s, { L("di_upd_later"), false, "later" }, { L("di_upd_retry"), true, "install" })
    elseif info.canSelf then
        Sheet.Buttons(layout, by, a, s, { L("di_upd_later"), false, "later" }, { L("di_upd_install"), true, "install" })
    else
        Sheet.Buttons(layout, by, a, s, { L("di_upd_ok"), true, "later" })
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
    table.insert(NotifCenter.Items, 1, { tag = n.Tag or "", title = n.Title or "", accent = n.AccentColor, fb = n.FallbackSvg, icon = n.Icon, t = os.clock() })
    while #NotifCenter.Items > 5 do table.remove(NotifCenter.Items) end
end

function NotifCenter.Height()
    local n = #NotifCenter.Items
    if n == 0 then return 96 end
    return 46 + n * 42 + 6
end

function NotifCenter.Ago(t)
    local d = math.max(0, os.clock() - t)
    if d < 60 then return L("di_nc_now") end
    if d < 3600 then return string.format(L("di_nc_min"), math.floor(d / 60)) end
    return string.format(L("di_nc_hour"), math.floor(d / 3600))
end

function NotifCenter.Render(layout, alphaMul, yOffset)
    local a = alphaMul or 1
    local s = layout.scale
    local C = Config.Colors
    local pad = math.floor(16 * s)
    local yOff = yOffset or 0
    local items = NotifCenter.Items
    local fH, sH = TF("FootnoteEm", s)
    local hy = math.floor(layout.y + 16 * s + yOff)
    Render.Text(fH, sH, L("di_nc_title"), Vec2(layout.x + pad, hy), FadeColor(C.TextSecondary, a))

    if #items == 0 then
        local fE, sE = TF("Subhead", s)
        local msg = L("di_nc_empty")
        local ts = Render.TextSize(fE, sE, msg)
        Render.Text(fE, sE, msg, Vec2(math.floor(layout.x + (layout.w - ts.x) / 2), math.floor(layout.y + 50 * s + yOff)), FadeColor(C.TextMuted, a))
        return
    end

    local clr = L("di_nc_clear")
    local cs = Render.TextSize(fH, sH, clr)
    local cx = math.floor(layout.x + layout.w - pad - cs.x)
    Render.Text(fH, sH, clr, Vec2(cx, hy), FadeColor(C.Blue, a))
    if a > 0.9 then
        table.insert(NotifCenter.Hits, { x1 = cx - 6, y1 = hy - 6, x2 = cx + cs.x + 6, y2 = hy + cs.y + 6, action = "nc_clear" })
    end

    local fT, sT = TF("Caption", s)
    local fB, sB = TF("Subhead", s)
    local isz = math.floor(28 * s)
    local rowY = math.floor(layout.y + 46 * s + yOff)
    for i, it in ipairs(items) do
        local ry = rowY + (i - 1) * math.floor(42 * s)
        local icx, icy = layout.x + pad + isz / 2, ry + isz / 2 + math.floor(2 * s)
        local accent = it.accent or C.Blue
        local img = it.icon and GetCachedImage(it.icon) or nil
        if not img and it.fb and not NotifGlyphs[it.fb] then img = GetCachedImage(nil, it.fb) end
        if img then
            Render.Image(img, Vec2(math.floor(icx - isz / 2), math.floor(icy - isz / 2)), Vec2(isz, isz), FadeColor(Color(255, 255, 255, 255), a), math.floor(isz / 2))
        else
            Render.FilledCircle(Vec2(icx, icy), isz / 2, FadeColor(accent, a), 0, 1.0, 24)
            Glyph(it.fb or "bell", icx, icy, math.floor(isz * 0.56), FadeColor(Color(255, 255, 255, 255), a))
        end
        local ago = NotifCenter.Ago(it.t)
        local aw = Render.TextSize(fT, sT, ago).x
        local tx = layout.x + pad + isz + math.floor(10 * s)
        local maxW = layout.x + layout.w - pad - tx - aw - math.floor(8 * s)
        local th = Render.TextSize(fT, sT, "Ag").y
        Render.Text(fT, sT, TruncateToWidth(fT, sT, it.tag, maxW), Vec2(tx, ry), FadeColor(Impl.OnLight(accent), a))
        Render.Text(fT, sT, ago, Vec2(math.floor(layout.x + layout.w - pad - aw), ry), FadeColor(C.TextMuted, a))
        Render.Text(fB, sB, TruncateToWidth(fB, sB, it.title, layout.x + layout.w - pad - tx), Vec2(tx, math.floor(ry + th)), FadeColor(C.TextPrimary, a))
    end
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
    elseif state == StateMachine.States.FOCUS_BANNER then
        Focus.RenderBanner(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.SHEET then
        Sheet.Render(layout, alphaMul, yOffset)
    elseif state == StateMachine.States.NOTIF_CENTER then
        NotifCenter.Render(layout, alphaMul, yOffset)
    end
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
                Impl.RenderShared(g.shared, layout, g.m)
            else
                RenderStateLayer(g.state, g.w and StateMachine.FrameFor(layout, g.w, g.h, g.r) or layout, 1.0, 0)
            end
        end)
        ContentFx.End()
        if not ok then error(err, 0) end
    end
    if tr.Active and tr.SharedPair then
        tr.Reveal = 1
        Impl.RenderShared(tr.SharedPair, layout, StateMachine.SharedM(tr.SharedPair))
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

    local fontBold, fs = TF("FootnoteEm", 1)
    local hintText = string.format("X: %d   Y: %d", math.floor(layout.x), math.floor(layout.y))
    local hw = Odometer.Width(fontBold, fs, hintText)
    local hx = math.floor(layout.x + (layout.w - hw) / 2)
    local hy = math.floor(layout.y + layout.h + 8)
    Odometer.Draw(fontBold, fs, hintText, Vec2(hx, hy), Config.Colors.TextPrimary)
end

local LastMenuOpenState = false

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
    end

    local curClock = os.clock()
    local dt = 0.016
    if StateMachine.LastDrawTime > 0 then
        dt = math.min(0.04, math.max(0.001, curClock - StateMachine.LastDrawTime))
    end
    StateMachine.LastDrawTime = curClock
    Impl.AdvancePosition(dt)
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
        local nC, nVC = MotionEngine.Step(VolumeState.Current or 50.0, VolumeState.CurrentVel or 0.0, VolumeState.Target or 50.0, dt, "SNAPPY", 0.1)
        VolumeState.Current = nC
        VolumeState.CurrentVel = nVC
        local nO, nVO = MotionEngine.Step(VolumeState.Overstretch or 0.0, VolumeState.OverstretchVel or 0.0, 0.0, dt, "SNAPPY", 0.15)
        VolumeState.Overstretch = nO
        VolumeState.OverstretchVel = nVO
    end

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
    if f ~= ThemeSpring.LastF then
        ThemeSpring.LastF = f
        local C = Config.Colors
        local function D(r1, g1, b1, a1, r2, g2, b2, a2)
            return LerpColor(Color(r1, g1, b1, a1), Color(r2, g2, b2, a2), f)
        end
        C.TextPrimary = D(255, 255, 255, 255, 0, 0, 0, 255)
        C.TextSecondary = D(235, 235, 245, 153, 60, 60, 67, 153)
        C.TextMuted = D(235, 235, 245, 77, 60, 60, 67, 77)
        C.TextQuaternary = D(235, 235, 245, 46, 60, 60, 67, 46)
        C.TextInverse = D(0, 0, 0, 255, 255, 255, 255, 255)
        C.Separator = D(84, 84, 88, 153, 60, 60, 67, 74)
        C.Fill = D(120, 120, 128, 92, 120, 120, 128, 51)
        C.FillSecondary = D(120, 120, 128, 82, 120, 120, 128, 41)
        C.FillTertiary = D(118, 118, 128, 61, 118, 118, 128, 31)
        C.FillQuaternary = D(118, 118, 128, 46, 116, 116, 128, 20)
        C.Border = D(255, 255, 255, 28, 0, 0, 0, 35)
        C.SegThumb = D(99, 99, 102, 255, 255, 255, 255, 255)
        C.ChipActiveBorder = D(255, 255, 255, 255, 0, 0, 0, 255)
        C.Red = D(255, 69, 58, 255, 255, 59, 48, 255)
        C.Orange = D(255, 159, 10, 255, 255, 149, 0, 255)
        C.Yellow = D(255, 214, 10, 255, 255, 204, 0, 255)
        C.Green = D(48, 209, 88, 255, 52, 199, 89, 255)
        C.Mint = D(99, 230, 226, 255, 0, 199, 190, 255)
        C.Teal = D(64, 200, 224, 255, 48, 176, 199, 255)
        C.Cyan = D(100, 210, 255, 255, 50, 173, 230, 255)
        C.Blue = D(10, 132, 255, 255, 0, 122, 255, 255)
        C.Indigo = D(94, 92, 230, 255, 88, 86, 214, 255)
        C.Purple = D(191, 90, 242, 255, 175, 82, 222, 255)
        C.Pink = D(255, 55, 95, 255, 255, 45, 85, 255)
        C.Brown = D(172, 142, 104, 255, 162, 132, 94, 255)
        C.TrackProgressBg = C.Fill
        C.ChipInactive = C.FillTertiary
        C.SegTrack = C.FillTertiary
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

    Sheet.RenderBadge(layout)
    Impl.RenderSecondarySatelliteBubble(layout)
    Focus.RenderBubble(layout)
    Impl.RenderMenuClosedHint(layout)
    Impl.RenderHUDDrawer(layout, dt)
end

function DynamicIsland.OnUpdateEx()
    local inGame = Engine.IsInGame and Engine.IsInGame()
    if inGame then
        WasInGame = true
        HeroData.Local = (Heroes and Heroes.GetLocal) and Heroes.GetLocal() or nil
        if HeroData.Local and HeroData.HeroName == "" then
            HeroData.HeroName = NPC.GetUnitName(HeroData.Local)
        end
        if HeroData.Local and not Demo.Active then
            Impl.ProcessFightDetector()
        end
        Impl.ProcessGameEvents()
        Reminders.Tick()
        Rampage.Tick()
        if not Demo.Active then
            Impl.ProcessPauseTracker()
            Impl.ProcessCourierTracker()
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
        CourierTracker.BasePos = nil
        CourierTracker.CachedCourier = nil
    end
    Impl.HandleInteractions()
    Impl.PollMediaBridge()
    Impl.PollBridgeStatus()
    Impl.PollSystem()
    Sheet.PollUpdate()
end

function DynamicIsland.OnScriptsLoaded()
    Impl.LoadScriptFonts()
    Impl.InitMenu()
    Impl.LoadAllConfig()
    Sheet.ConfigLoaded = true

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
end

DynamicIsland.HapticPlaySound = HapticPlaySound
DynamicIslandGlobal = DynamicIsland

return DynamicIsland
