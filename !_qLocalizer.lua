--[[
     ~ qLocalization
     ~ automatic localization wrapper for Lua menu interfaces

     ~ author: qfun (qfun_g9s)
]]

qLocalization = {}

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

---Creates a new localization instance.
---@param translations table<string, table>
---@return table
function qLocalization.new(translations)
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

				proxy = setmetatable({}, {
					__index = function(_, key)
						local member = target[key]

						if type(member) ~= "function" then
							return member
						end

						return function(...)
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

return qLocalization
