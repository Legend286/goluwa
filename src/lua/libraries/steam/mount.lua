local steam = ... or _G.steam

commands.Add("mount", function(game)
	local game_info = assert(steam.MountSourceGame(game))
	llog("mounted %s %s", game_info.game, game_info.title2)
end)

commands.Add("unmount", function(game)
	local game_info = assert(steam.UnmountSourceGame(game))
	llog("unmounted %s %s", game_info.game, game_info.title2 or game_info.title)
end)

commands.Add("mount_all", function(game)
	local game_info = assert(steam.MountSourceGame(game))
	llog("mounted %s %s", game_info.game, game_info.title2)
end)

commands.Add("unmount_all", function()
	steam.UnmountAllSourceGames()
end)

commands.Add("list_games", function()
	for _, info in pairs(steam.GetSourceGames()) do
		logn(info.game)
		logn("\tgame_dir = ", info.game_dir)
		logn("\tappid = ", info.filesystem.steamappid)
		logn()
	end
end)

commands.Add("list_maps", function(search)
	for _, name in ipairs(vfs.Find("maps/%.bsp$")) do
		if not search or name:find(search) then
			logn(name:sub(0, -5))
		end
	end
end)

commands.Add("game_info", function(game)
	local info = steam.FindSourceGame(game)
	print(vfs.Read(info.gameinfo_path))
	table.print(info)
end)

function steam.GetInstallPath()
	local path

	if WINDOWS then
		path = system.GetRegistryValue("CurrentUser/Software/Valve/Steam/SteamPath") or (X64 and "C:\\Program Files (x86)\\Steam" or "C:\\Program Files\\Steam")
	elseif LINUX then
		path = os.getenv("HOME") .. "/.steam/steam"
		if not vfs.IsDirectory(path) then
			path = os.getenv("HOME") .. "/.local/share/Steam"
		end
	end

	return path --lfs.symlinkattributes(path, "mode") and path or nil
end

function steam.GetLibraryFolders()
	local base = steam.GetInstallPath()

	local str = vfs.Read(base .. "/config/config.vdf", "r")

	if not str then return {} end

	local tbl = {base .. "/steamapps/"}

	local config = utility.VDFToTable(str, true)

	for key, path in pairs(config.installconfigstore.software.valve.steam) do
		if key:find("baseinstallfolder_") then
			table.insert(tbl, vfs.FixPathSlashes(path) .. "/steamapps/")
		end
	end

	return tbl
end

function steam.GetGamePath(game)
	for _, dir in pairs(steam.GetLibraryFolders()) do
		local path = dir .. "common/" .. game .. "/"
		if vfs.IsDirectory(path) then
			return path
		end
	end

	return ""
end

function steam.GetGameFolders(skip_mods)
	local games = {}

	for _, library in ipairs(steam.GetLibraryFolders()) do
		for _, game in ipairs(vfs.Find(library .. "/common/", true)) do
			table.insert(games, game .. "/")
		end
		if not skip_mods then
			for _, mod in ipairs(vfs.Find(library .. "/sourcemods/", true)) do
				table.insert(games, mod .. "/")
			end
		end
	end

	return games
end

function steam.GetSourceGames()
	local found = {}

	for _, game_dir in ipairs(steam.GetGameFolders()) do
		for _, folder in ipairs(vfs.Find("os:" .. game_dir, true)) do
			local path = folder .. "/gameinfo.txt"
			local str = vfs.Read("os:" .. path)

			if not str then
				str = vfs.Read("os:" .. folder .. "/GameInfo.txt")
			end

			local dir = path:match("(.+/).+/")

			if str then
				local tbl = utility.VDFToTable(str, true)
				if tbl and tbl.gameinfo and tbl.gameinfo.game then
					tbl = tbl.gameinfo
					tbl.gameinfo_path = path

					tbl.game_dir = game_dir


					if tbl.filesystem then
						local fixed = {}

						local done = {}

						for _, v in pairs(tbl.filesystem.searchpaths) do
							for _, v in pairs(type(v) == "string" and {v} or v) do
								if v:find("|gameinfo_path|") then
									v = v:gsub("|gameinfo_path|", path:match("(.+/)"))
								elseif v:find("|all_source_engine_paths|") then
									v = v:gsub("|all_source_engine_paths|", dir)
								else
									v = dir .. v
								end

								if v:endswith(".") then
									v = v:sub(0,-2)
								end

								if not done[v] and not done[v.."/"] then

									if tbl.filesystem.steamappid == 4000 then
										-- is there an internal fix in gmod for this?
										v = v:gsub("GarrysMod/hl2", "GarrysMod/sourceengine")
									end

									v = v:gsub("/+", "/") -- TODO

									table.insert(fixed, v)
									done[v] = true
								end
							end
						end

						tbl.filesystem.searchpaths = fixed

						table.insert(found, tbl)
					end
				end
			end
		end
	end

	return found
end

local cache_mounted = {}

function steam.MountSourceGame(game_info)

	if cache_mounted[game_info] then
		return cache_mounted[game_info]
	end

	local str_game_info

	if type(game_info) == "string" then
		str_game_info = game_info:trim()

		game_info = steam.FindSourceGame(str_game_info)
	end

	if not game_info then return nil, "could not find " .. str_game_info end

	steam.UnmountSourceGame(game_info)
	for _, path in pairs(game_info.filesystem.searchpaths) do
		if path:endswith(".vpk") then
			path = "os:" .. path:gsub("(.+)%.vpk", "%1_dir.vpk")
		else

			if path:endswith("*") then
				path = "os:" .. path

				path = path:sub(0, -2)
				for _, v in pairs(vfs.Find(path)) do
					if vfs.IsDirectory(path .. "/" .. v) or v:endswith(".vpk") then
						llog("mounting custom folder/vpk %s", v)
						vfs.Mount(path .. "/" .. v, nil, game_info)
					end
				end
			else
				for _, v in pairs(vfs.Find(path .. "addons/")) do
					if vfs.IsDirectory(path .. "addons/" .. v) then
						local where = path .. "addons/" .. v
						llog("mounting addon %s", v)
						if v:endswith(".gma") then
							where = "gmod addon archive:" .. where
						end
						vfs.Mount(where, nil, game_info)
					end
				end

				path = "os:" .. path

				for _, v in pairs(vfs.Find(path .. "maps/workshop/")) do
					llog("mounting workshop map %s", v)
					vfs.Mount(path .. "maps/workshop/" .. v, "maps/", game_info)
				end
			end


			local pak = path .. "pak01_dir.vpk"
			if vfs.IsFile(pak) then
				llog("mounting %s", pak)
				vfs.Mount(pak, nil, game_info)
			end
		end

		if vfs.Exists(path) then
			llog("mounting %s", path)
			vfs.Mount(path, nil, game_info)
		else
			llog("%s not found", path)
		end
	end

	if str_game_info then
		cache_mounted[str_game_info] = game_info
	end

	return game_info
end

function steam.UnmountSourceGame(game_info)
	local str_game_info = game_info

	if type(game_info) == "string" then
		cache_mounted[game_info] = nil
		str_game_info = game_info
		game_info = steam.FindSourceGame(game_info)
	end

	if not game_info then return nil, "could not find " .. str_game_info end

	if game_info then
		for _, v in pairs(vfs.GetMounts()) do
			if v.userdata and v.userdata.filesystem.steamappid == game_info.filesystem.steamappid then
				vfs.Unmount(v.full_where, v.full_to)
			end
		end
	end

	return game_info
end


do
	local translate = {
		[630] = {"alien swarm", "as"},
		[420] = {"hl2ep2", "half-life 2: episode two", "ep2"},
		[320] = {"hl2dm", "half-life 2: deathmatch"},
		[240] = {"css", "counter-strike: source"},
		[730] = {"counter-strike: global offensive", "csgo"},
		[360] = {"hldm", "hl1dm", "half-life deathmatch: source"},
		[4000] = {"gmod", "gm", "garrysmod", "garrys mod"},
		[550] = {"left 4 dead 2", "l4d2"},
		[280] = {"half-life: source", "hls"},
		[500] = {"left 4 dead"},
		[220] = {"half-life 2: lost coast", "hl2lc"},
		[400] = {"portal"},
		[300] = {"day of defeat: source", "dods", "dod"},
		[380] = {"half-life 2: episode one", "hl2e1", "ep1"},
		[570] = {"dota 2", "dota"},
		[440] = {"tf2", "team fortress 2"},
		[620] = {"portal 2"},
	}

	local temp = {}

	for k, v in pairs(translate) do
		for _, name in ipairs(v) do
			temp[name] = k
		end
	end

	translate = temp

	function steam.FindSourceGame(name)
		local games = steam.GetSourceGames()

		if type(name) == "number" then
			for _, game_info in ipairs(games) do
				if game_info.filesystem.steamappid == name then
					return game_info
				end
			end
		else
			local id = translate[name:lower()]

			if id then
				for _, game_info in ipairs(games) do
					if game_info.filesystem.steamappid == id then
						return game_info
					end
				end
			end

			for _, game_info in ipairs(games) do
				if game_info.game:lower() == name then
					return game_info
				end
			end

			for _, game_info in ipairs(games) do
				if game_info.game:compare(name) then
					return game_info
				end
			end

			for _, game_info in ipairs(games) do
				if game_info.filesystem.searchpaths.mod and game_info.filesystem.searchpaths.mod:compare(name) then
					return game_info
				end
			end
		end
	end

end

function steam.MountSourceGames()
	for _, game_info in ipairs(steam.GetSourceGames()) do
		steam.MountSourceGame(game_info)
	end
end

function steam.UnmountAllSourceGames()
	for _, game_info in ipairs(steam.GetSourceGames()) do
		steam.UnmountSourceGame(game_info)
	end
end

local mount_info = {
	["gm_.+"] = {"garry's mod", "tf2", "css"},
	["rp_.+"] = {"garry's mod", "tf2", "css"},
	["ep1_.+"] = {"half-life 2: episode one"},
	["ep2_.+"] = {"half-life 2: episode two"},
	["trade_.+"] = {"half-life 2", "team fortress 2"},
	["d%d_.+"] = {"half-life 2"},
	["dm_.*"] = {"half-life 2: deathmatch"},
	["c%dm%d_.+"] = {"left 4 dead 2"},

	["esther"] = {"dear esther"},
	["jakobson"] = {"dear esther"},
	["donnelley"] = {"dear esther"},
	["paul"] = {"dear esther"},

	["aramaki_4d"] = {"team fortress 2", "garry's mod"},
	["de_overpass"] = {"counter-strike: global offensive"},
	["de_bank"] = {"counter-strike: global offensive"},
	["sp_a4_finale1"] = {"portal 2"},
	["c3m1_plankcountry"] = {"left 4 dead 2"},
	["achievement_apg_r11b"] = {"half-life 2", "team fortress 2"},
}

function steam.MountGamesFromMapPath(path)
	local name = path:match("maps/(.+)%.bsp")

	if name == "gm_old_flatgrass" then return end

	if name then
		local mounts = mount_info[name]

		if not mounts then
			for k,v in pairs(mount_info) do
				if name:find(k) then
					mounts = v
					break
				end
			end
		end

		if mounts then
			for _, mount in ipairs(mounts) do
				steam.MountSourceGame(mount)
			end
		end
	end
end

