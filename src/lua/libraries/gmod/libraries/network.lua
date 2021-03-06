local fake = {}
local counter = 0
function gine.env.util.AddNetworkString(str)
	counter = counter + 1
	fake[str] = counter
	return counter
	--return network.AddString(str)
end

function gine.env.util.NetworkStringToID(str)
	--return network.StringToID(str)
	return fake[str] or tonumber(crypto.CRC32(str))
end

function gine.env.util.NetworkIDToString(id)
	--return network.IDToString(id) or ""
	for k,v in pairs(fake) do
		if v == id then
			return k
		end
	end
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

function gine.env.net.Start()

end

function gine.env.net.BytesWritten()
	return 0
end

for k,v in pairs(gine.env.net) do
	if k:startswith("Write") or k:startswith("Start") then
		gine.env.net[k] = function() end
	end
end
