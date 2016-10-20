function gine.env.util.AddNetworkString(str)
	return network.AddString(str)
end

function gine.env.util.NetworkStringToID(str)
	return network.StringToID(str)
end

function gine.env.util.NetworkIDToString(id)
	return network.IDToString(id) or ""
end

function gine.env.GetHostName()
	return network.GetHostname()
end

do
	local nw_globals = {}

	local function ADD(name)
		gine.env["SetGlobal" .. name] = function(key, val) nw_globals[key] = val end
		gine.env["GetGlobal" .. name] = function(key) return nw_globals[key] end
	end

	ADD("String")
	ADD("Int")
	ADD("Float")
	ADD("Vector")
	ADD("Angle")
	ADD("Entity")
	ADD("Bool")
end

function gine.env.game.MaxPlayers()
	return 32
end

function gine.env.game.SinglePlayer()
	return false
end