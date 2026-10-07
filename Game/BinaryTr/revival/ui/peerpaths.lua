-- The corner panel: how each peer's game traffic travels and its round trip. The model is native
-- (peer_paths.cpp); player.lua's setup and tick call in here.

local ui = {}
local drawn = nil
local read_at = nil

-- The engine pings a peer every 4.3 s; reading more often would only redraw the same numbers.
local READ_EVERY = 0.25

function Revival.peers_setup(document)
	ui.document = document
	ui.panel = document:GetElementById("peerpaths")
	drawn = nil
	read_at = nil
end

function Revival.peers_draw(now)
	if now ~= nil and read_at ~= nil and now - read_at < READ_EVERY then return end
	read_at = now
	local paths = Revival.peer_paths()
	-- nil: the client's network tables were busy this time, so what is shown stays.
	if paths == nil then return end

	local rows = {}
	for _, path in ipairs(paths) do
		-- One path needs no name; a 2v2 host's three do.
		local team = ""
		if #paths > 1 and path.team ~= "" then
			team = string.format('<span class="peerteam">%s</span>', Revival.escape(path.team))
		end
		local ms = path.ms > 0 and string.format("%dms", path.ms) or "—"
		rows[#rows + 1] = string.format('<div class="peerpath">%s<span class="peermode">%s</span>' ..
		                                '<span class="peerms">%s</span></div>', team, path.mode, ms)
	end
	local text = table.concat(rows)
	if text == drawn then return end
	drawn = text
	ui.panel.inner_rml = text
	ui.document:SetClass("peers", #rows > 0)
end
