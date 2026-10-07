-- The replay list and the bar a replay plays under. The model is native (replay_script.cpp); this
-- file only draws it and forwards clicks. player.lua's setup and tick call in here.

local ui = {}
local rows = {}
local confirm = nil
local goals_key = nil
local bar = nil
-- Where the knob is held, if it is. Only a release seeks: a seek rebuilds the whole match, and a
-- drag that sought on every move asked for one a frame.
local held = nil

local SPEEDS = { 0.5, 1, 2, 4 }
-- A goal is watched from its build-up, not from the net bulging.
local GOAL_LEAD = 8

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function escape(text)
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function speed_label(speed)
	if speed == math.floor(speed) then return string.format("%d×", speed) end
	return string.format("%.1f×", speed)
end

local function build_list()
	rows = Revival.replay_list()
	confirm = nil
	local parts = {}
	for index, row in ipairs(rows) do
		local teams = string.format("%s %d–%d %s", escape(row.home ~= "" and row.home or "?"),
		                            row.score_a, row.score_b, escape(row.away ~= "" and row.away or "?"))
		if row.pen_a ~= nil then teams = teams .. string.format(" (pen. %d–%d)", row.pen_a, row.pen_b) end
		-- Beside the date, a length written m:ss read as a second time of day.
		local seconds = math.max(0, math.floor(row.length + 0.5))
		local length = string.format("%d dk %d sn", math.floor(seconds / 60), seconds % 60)
		local meta = string.format("%s · %s · %s", escape(row.date), length,
		                           row.practice and "Antrenman" or "Maç")
		parts[#parts + 1] = table.concat({
			'<div class="replayrow">',
			'<div class="replayinfo"><span class="replayteams">', teams, '</span>',
			'<span class="replaymeta">', meta, '</span></div>',
			string.format('<div class="control quiet replaysave%s" onclick="Revival.replays_keep(%d)">',
			              row.saved and " on" or "", index),
			'<span class="icon">', row.saved and "&#xE735;" or "&#xE734;", '</span></div>',
			string.format('<div class="control quiet replaydelete" id="replaydelete%d" ' ..
			              'onclick="Revival.replays_delete(%d)"><span class="icon">&#xE74D;</span></div>',
			              index, index),
			string.format('<div class="control" onclick="Revival.replays_watch(%d)">', index),
			'<svg src="../icons/play_glyph.svg"/></div>',
			'</div>',
		})
	end
	ui.replaylist.inner_rml = table.concat(parts)
	ui.replaycount.inner_rml = tostring(#rows)
	ui.replaynote.inner_rml = #rows == 0 and "Bitirdiğin maçlar burada görünür."
		or "★ ile kaydettiklerin kalır; diğerlerinden son 20 maç tutulur."
end

local function draw_bar(state)
	ui.document:SetClass("replaywait", state.requested)
	ui.document:SetClass("replaying", state.playing)
	bar = state.playing and state or nil
	if not state.playing then
		held = nil
		return
	end

	local position = held or state.position
	local span = math.max(0.001, state.finish - state.start)
	local fraction = math.max(0, math.min(1, (position - state.start) / span)) * 100
	ui.rpplayed.style.width = string.format("%.2f%%", fraction)
	ui.rphead.style.left = string.format("%.2f%%", fraction)
	ui.rpclock.inner_rml = clock(position - state.start)
	ui.rpfinish.inner_rml = clock(span)
	ui.rpplayicon:SetAttribute("src", (state.paused or state.finished) and "../icons/play.svg"
	                                  or "../icons/pause.svg")
	ui.rpspeedtext.inner_rml = speed_label(state.speed)

	local status = ""
	if state.finished then
		status = "Tekrar bitti"
	elseif state.paused then
		status = "Duraklatıldı"
	end
	ui.rpstatus.inner_rml = status

	-- Rebuilt only when the goals change: draw runs every frame.
	local key = #state.goals .. ":" .. span
	if key ~= goals_key then
		goals_key = key
		local parts = {}
		for _, goal in ipairs(state.goals) do
			local at = math.max(0, math.min(1, (goal.at - state.start) / span)) * 100
			parts[#parts + 1] = string.format('<div class="rpgoal" style="left: %.2f%%;"/>', at)
		end
		ui.rpgoals.inner_rml = table.concat(parts)
	end
end

function Revival.replays_setup(document)
	for _, id in ipairs({ "replays", "replaylist", "replaycount", "replaynote", "rpplayicon",
	                      "rpclock", "rpfinish", "rpseek", "rpplayed", "rphead", "rpgoals",
	                      "rpspeedtext", "rpstatus" }) do
		ui[id] = document:GetElementById(id)
	end
	ui.document = document
	goals_key = nil
	-- On the namespace, like the music card: a hot reload keeps the list open.
	ui.replays:SetClass("open", Revival.replays_open == true)
	if Revival.replays_open then build_list() end
end

function Revival.replays_draw()
	draw_bar(Revival.replay_state())
end

function Revival.replays_toggle()
	Revival.replays_open = not Revival.replays_open
	ui.replays:SetClass("open", Revival.replays_open)
	if Revival.replays_open then build_list() end
end

function Revival.replays_wheel(event)
	ui.replaylist.scroll_top = ui.replaylist.scroll_top - (event.parameters["wheel_delta_y"] or 0) * 40
end

function Revival.replays_watch(index)
	local row = rows[index]
	if row == nil then return end
	if Revival.replay_watch(row.name, row.saved) then
		Revival.replays_open = false
		ui.replays:SetClass("open", false)
	else
		ui.replaynote.inner_rml = "Tekrar açılamadı."
	end
end

function Revival.replays_keep(index)
	local row = rows[index]
	if row ~= nil and Revival.replay_keep(row.name, not row.saved) then build_list() end
end

-- Two presses: the first arms the row, so one stray click cannot lose a saved match.
function Revival.replays_delete(index)
	local row = rows[index]
	if row == nil then return end
	if confirm ~= index then
		confirm = index
		local icon = ui.document:GetElementById("replaydelete" .. index)
		if icon ~= nil then icon:SetClass("confirm", true) end
		ui.replaynote.inner_rml = "Silmek için bir kez daha tıkla."
		return
	end
	if Revival.replay_delete(row.name, row.saved) then build_list() end
end

function Revival.rp_pause()
	Revival.replay_pause()
end

function Revival.rp_step(seconds)
	if bar ~= nil then Revival.replay_seek(bar.position + seconds) end
end

function Revival.rp_seek(event)
	if bar == nil or not Revival.primary(event) then return end
	local fraction = math.max(0, math.min(1, Revival.fraction_of(ui.rpseek, event)))
	held = bar.start + fraction * (bar.finish - bar.start)
end

-- Bound to both mouseup and dragend: a click never starts a drag, and a drag let go off the rail
-- sends its mouseup elsewhere. Whichever comes second finds nothing held.
function Revival.rp_seek_done()
	if held == nil then return end
	Revival.replay_seek(held)
	held = nil
end

function Revival.rp_next_goal()
	if bar == nil or #bar.goals == 0 then return end
	local target = bar.goals[1]
	for _, goal in ipairs(bar.goals) do
		if goal.at - GOAL_LEAD > bar.position + 1 then
			target = goal
			break
		end
	end
	Revival.replay_seek(target.at - GOAL_LEAD)
end

function Revival.rp_speed()
	local current = bar ~= nil and bar.speed or 1
	local choice = SPEEDS[1]
	for _, speed in ipairs(SPEEDS) do
		if speed > current + 0.01 then
			choice = speed
			break
		end
	end
	Revival.replay_speed(choice)
end

function Revival.rp_exit()
	Revival.replay_exit()
end
