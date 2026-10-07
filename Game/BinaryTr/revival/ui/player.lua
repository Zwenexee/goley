-- Music bar behaviour. Transport state belongs to C++; this document owns presentation and input so
-- it remains hot-reloadable without restarting or interrupting playback.

local ui = {}
-- What the station list and the art were last built from: rebuilding is a relayout, so only on
-- change. The list's key is deliberately NOT what the stations are playing -- that moves, and a
-- relayout every time any station changed track would reset the scroll under the pointer.
local rows_key = nil
local art_key = nil
-- Per row, the two elements redrawn without a rebuild, and what is in them.
local rows = {}

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- Names come from the station's editors, and a row is RML.
local function escape(text)
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- What a station is playing, for its row: the track its own clock is on, else its tagline, which
-- is all there is to say about a station whose files have not arrived.
local function row_now(station)
	local now = station.title or ""
	local artist = station.artist or ""
	if now ~= "" and artist ~= "" then now = now .. " · " .. artist end
	if now == "" then now = station.tagline or "" end
	return now
end

-- The listener count, as the whole right-hand side of a row: a headphone glyph and the number,
-- or nothing at all. `listeners` is -1 until the backend has reported any, and an empty string
-- rather than "0" is the point -- a radio nobody has counted is not a radio nobody is hearing.
local function row_heads(station)
	local count = station.listeners or -1
	if count < 0 then return "" end
	return string.format('<span class="icon">&#xE7F6;</span><span class="rowcount">%d</span>',
	                     math.floor(count))
end

-- The rows themselves: one per station, rebuilt only when the stations, their art or the chosen
-- one change. What each is PLAYING is written afterwards, per row, by draw_rows.
local function build_rows(player, stations)
	local key = tostring(player.selected)
	for _, station in ipairs(stations) do
		key = key .. "\n" .. (station.name or "") .. "\n" .. (station.art or "")
	end
	if key == rows_key then return false end
	rows_key = key

	local parts = {}
	for index, station in ipairs(stations) do
		-- An <img> reads its file from `src`; the built-in is an <svg>, a different element, so
		-- which one a row holds is settled here rather than swapped later.
		local file = station.art or ""
		local art = file ~= "" and string.format('<img src="%s"/>', escape(file))
			or '<svg src="../icons/station.svg"/>'
		parts[#parts + 1] = string.format(
			'<div class="row%s" onclick="Revival.select_station(%d)">' ..
			'<div class="rowart">%s</div>' ..
			'<div class="rowtext"><span class="rowname">%s</span>' ..
			'<span class="rownow" id="rownow%d"></span></div>' ..
			'<div class="rowheads" id="rowheads%d"></div></div>',
			index == player.selected and " on" or "", index, art, escape(station.name or ""),
			index, index)
	end
	ui.stations.inner_rml = table.concat(parts)

	rows = {}
	for index = 1, #stations do
		rows[index] = {
			now = ui.document:GetElementById("rownow" .. index),
			heads = ui.document:GetElementById("rowheads" .. index),
		}
	end
	return true
end

local function draw_rows(player)
	local stations = player.stations or {}
	build_rows(player, stations)
	-- Written only when the text changed: draw() runs every frame, and an inner_rml that is
	-- assigned every frame is a relayout every frame.
	for index, station in ipairs(stations) do
		local row = rows[index]
		if row ~= nil then
			local now = row_now(station)
			if now ~= row.now_text then
				row.now_text = now
				row.now.inner_rml = escape(now)
			end
			local heads = row_heads(station)
			if heads ~= row.heads_text then
				row.heads_text = heads
				row.heads.inner_rml = heads
			end
		end
	end
end

-- The station's own thumbnail, or the built-in when it has none. An <img> reads its file from
-- `src`, and swapping it is a texture load, so only on change.
local function draw_art(player)
	local art = player.art or ""
	if art == art_key then return end
	art_key = art
	ui.art:SetClass("custom", art ~= "")
	if art ~= "" then ui.artimg:SetAttribute("src", art) end
end

-- A headline, title or tagline wider than its box scrolls instead of clipping. The RML is written
-- only when the TEXT changes: draw() runs every frame, and rebuilding it there would relayout
-- constantly and reset the scroll before it ever moved.
local MARQUEE_SPEED = 30  -- px per second
local MARQUEE_HOLD = 1.5  -- seconds held at the start of each pass, so a short overflow is readable
local MARQUEE_GAP = 24    -- px between the two copies; the separator's own width, see .sep
-- A station name is read once and then known, so it rests between passes rather than circling all
-- session. A song title and a tagline keep moving: those change, and the part cut off is the part
-- worth waiting for.
local MARQUEE_PAUSE = 7   -- seconds at rest between passes, station names only

local marquee = {}
local last_clock = nil

-- Plain text to begin with: whether it needs to scroll is a question about the width it wants,
-- which nothing can answer until the frame has been laid out.
local function marquee_text(id, text)
	local state = marquee[id]
	if state == nil then
		state = {}
		marquee[id] = state
	end
	if state.text == text then return end
	state.text = text
	state.offset = 0
	state.hold = MARQUEE_HOLD
	state.period = nil
	state.scroll = nil
	-- The text written just now is not laid out until this frame ends, so the first measurement
	-- after it would read the PREVIOUS string -- and a short one would record "fits" for good.
	state.settle = true
	-- Escaped: station names and track titles are their editors' text, and a segment is RML. The
	-- backend strips tab/CR/LF from them and nothing else, so `<` would otherwise open a tag.
	ui[id].inner_rml = escape(text)
end

-- `pause`: seconds to rest between passes. Absent means a continuous loop.
local function marquee_step(id, dt, pause)
	local state = marquee[id]
	if state == nil then return end
	local view = ui[id]

	if state.settle then
		state.settle = false
		return
	end

	if state.period == nil then
		-- scroll_width is what the text wants, client_width what it gets. Measuring the segment
		-- instead cannot work: an inline-block shrink-to-fits to the room available, so it would
		-- report the width of the very box it overflows.
		local wanted, room = view.scroll_width, view.client_width
		-- Asked again every frame until it overflows, never latched. A box that is not on screen
		-- yet -- the pill before the lobby shows it -- reports its content as exactly its own
		-- width, and remembering THAT answer leaves the text still for the rest of the track.
		-- Slack of a pixel so text that just fits does not twitch.
		if wanted <= 0 or room <= 0 or wanted <= room + 1 then return end
		-- Whole pixels: scroll_width is a float, and "%d" refuses one that is not an integer.
		state.period = math.ceil(wanted) + MARQUEE_GAP
		-- The dot trails each copy rather than sitting between them, so the loop reads the same
		-- wherever the wrap happens to be: one period is the text and its separator, always.
		local body = escape(state.text) .. '<span class="sep">·</span>'
		local segment = function(name)
			return string.format('<span class="seg" id="%s" style="width: %dpx;">%s</span>',
			                     name, state.period, body)
		end
		view.inner_rml = string.format(
			'<span class="scroll" id="%s_scroll" style="width: %dpx;">%s%s</span>',
			id, state.period * 2, segment(id .. "_seg"), segment(id .. "_dup"))
		state.scroll = ui.document:GetElementById(id .. "_scroll")
		return
	end

	if state.scroll == nil then return end
	if state.hold > 0 then
		state.hold = state.hold - dt
		return
	end
	local moved = state.offset + MARQUEE_SPEED * dt
	if pause ~= nil and moved >= state.period then
		-- A pass has finished. The second copy sits exactly one period along, so snapping back to
		-- the start is invisible, and the name then rests long enough to be read before it moves
		-- again. Without a pause it just carries on, which is what a song title wants.
		state.offset = 0
		state.hold = pause
	else
		state.offset = moved % state.period
	end
	state.scroll.style.transform = string.format("translateX(%.1fpx)", -state.offset)
end

-- `dt` is the seconds since the last tick, and only a tick has one: setup and the chevron redraw
-- without time passing, which must not nudge a marquee along.
local function draw(dt)
	dt = dt or 0
	local player = Revival.music_state()
	local duration = math.max(0, player.duration)
	local fraction = duration > 0 and math.min(100, player.position / duration * 100) or 0
	local track = player.title
	if player.artist ~= "" then track = track .. " · " .. player.artist end

	local headline, subline, tagline
	if player.station then
		headline = player.station_name ~= "" and player.station_name or "Revival FM"
		subline = track ~= "" and track or player.note
		tagline = player.tagline ~= "" and player.tagline or "Canlı yayın"
	else
		headline = player.available and player.title or "No music"
		-- The reason comes from C++: an empty folder and an unusable audio engine look identical
		-- here, and telling an operator to add files they already added sends them the wrong way.
		subline = player.available and "revival/music" or player.note
		tagline = subline
	end
	ui.music:SetClass("station", player.station)
	-- The host draws the hint only once the game has asked for music: `wanted` is that moment.
	ui.document:SetClass("lobby", player.wanted)
	marquee_text("headline", headline)
	marquee_text("subline", subline)
	marquee_text("name", headline)
	marquee_text("tagline", tagline)
	marquee_step("headline", dt, MARQUEE_PAUSE)
	marquee_step("subline", dt)
	-- The card's two are laid out even while it is closed, so they measure fine, but animating them
	-- unseen would only burn the hold and open the card mid-scroll.
	if Revival.open == true then
		marquee_step("name", dt, MARQUEE_PAUSE)
		marquee_step("tagline", dt)
	end
	draw_rows(player)
	draw_art(player)

	ui.played.style.width = fraction .. "%"
	ui.playhead.style.left = fraction .. "%"
	ui.elapsed.inner_rml = clock(player.position)
	ui.duration.inner_rml = clock(duration)
	-- The transport icons are SVG files, so the state swap is the image, not a glyph. SetAttribute is
	-- the only way in: an <svg> reads its source from `src`, and nothing about it is text.
	ui.playicon:SetAttribute("src", player.playing and "../icons/pause.svg" or "../icons/play.svg")
	ui.toggleicon:SetAttribute("src", player.playing and "../icons/pause_glyph.svg" or
	                                  "../icons/play_glyph.svg")
	ui.chevronicon:SetAttribute("src", Revival.open and "../icons/chevron_up.svg" or
	                                   "../icons/chevron_down.svg")
	ui.loudness.style.width = player.volume .. "%"
	ui.loudknob.style.left = player.volume .. "%"
	ui.repeats:SetClass("on", player.repeat_track)
	ui.mute:SetAttribute("src", player.volume == 0 and "../icons/volume_mute.svg" or
	                            "../icons/volume.svg")
end

-- Distance from the context's left edge, which the Element binding does not expose directly: it
-- offers offset_left (relative to offset_parent) and the chain to walk. This reproduces what
-- Element::GetAbsoluteOffset sums in C++ -- each element's own offset plus its offset parent's,
-- less that parent's scroll -- and is exact for this document, whose rails sit in static boxes
-- under the absolutely positioned #card. A `position: relative` box introduced BETWEEN a rail and
-- #card would need its own offset added, as the C++ does.
local function absolute_left(element)
	local left = 0
	local at = element
	while at ~= nil do
		left = left + at.offset_left
		local parent = at.offset_parent
		if parent ~= nil then left = left - parent.scroll_left end
		at = parent
	end
	return left
end

-- The rails answer three events. A press applies at once, so the value jumps to where the pointer
-- went down rather than waiting for a release; drag events then follow it, including off the rail.
-- Only the primary button: a right-press dispatches mousedown too, and moving the volume by opening
-- a context menu would be a surprise. Drag events carry no button at all, hence the nil case.
local function primary(event)
	local button = event.parameters["button"]
	return button == nil or button == 0
end

-- Where along an element the pointer landed, as a fraction of its width. The event carries context
-- coordinates, so the element's own position has to come out of them. A drag that has left the rail
-- returns a value outside 0..1 -- deliberately not clamped here, because music_player::seek and
-- ::set_volume both saturate and reject non-finite input, and an invariant enforced twice is one
-- that can disagree with itself.
local function fraction_of(element, event)
	local width = element.client_width
	if width <= 0 then return 0 end
	return (event.parameters["mouse_x"] - absolute_left(element)) / width
end

-- replays.lua's bar has rails too.
Revival.primary = primary
Revival.fraction_of = fraction_of
-- peerpaths.lua and report.lua print team names.
Revival.escape = escape

function Revival.setup(document)
	for _, id in ipairs({ "music", "headline", "subline", "toggleicon", "chevronicon", "name",
	                      "tagline", "art", "artimg", "stations", "played", "playhead", "elapsed",
	                      "duration", "playicon", "loudness", "loudknob", "mute", "seek",
	                      "volume" }) do
		ui[id] = document:GetElementById(id)
	end
	ui.repeats = document:GetElementById("repeat")
	ui.document = document
	rows_key = nil
	rows = {}
	art_key = nil
	-- The marquees hold element handles from the document being replaced.
	marquee = {}
	last_clock = nil
	-- Whether the card is open lives on the namespace table, not in a local: a hot reload re-runs
	-- this file, and the card should stay open while its stylesheet is edited.
	ui.music:SetClass("open", Revival.open == true)
	draw()
	Revival.replays_setup(document)
	Revival.peers_setup(document)
	Revival.report_setup(document)
	-- Last: it puts the saved positions back, which means reading classes and boxes the setups
	-- above have just settled.
	Revival.layout_setup(document)
end

-- The host hands the tick its own elapsed seconds (ui::tick_scripts), which beats reading a clock
-- in here: no platform question about what os.clock() counts, and nothing for the sandbox to allow.
function Revival.tick(now)
	local dt = 0
	if now ~= nil then
		-- Clamped: a stall -- an alt-tab, a long frame -- must not teleport a marquee.
		dt = last_clock and math.min(now - last_clock, 0.25) or 0
		last_clock = now
	end
	draw(dt)
	Revival.replays_draw()
	Revival.peers_draw(now)
	Revival.report_draw(now)
	Revival.layout_draw()
end

function Revival.expand_toggle()
	Revival.open = not Revival.open
	ui.music:SetClass("open", Revival.open)
	draw()
end

-- The list scrolls by wheel or by dragging it. A drag ends in a click on whatever row the pointer
-- is over, so a list that moved swallows that one click.
local strip = nil

function Revival.rows_press(event)
	if not primary(event) then return end
	strip = { y = event.parameters["mouse_y"], top = ui.stations.scroll_top, moved = false }
end

function Revival.rows_drag(event)
	if strip == nil then return end
	local dy = event.parameters["mouse_y"] - strip.y
	if math.abs(dy) > 4 then strip.moved = true end
	ui.stations.scroll_top = strip.top - dy
end

function Revival.rows_wheel(event)
	ui.stations.scroll_top = ui.stations.scroll_top - (event.parameters["wheel_delta_y"] or 0) * 40
end

function Revival.select_station(index)
	local dragged = strip ~= nil and strip.moved
	strip = nil
	if dragged then return end
	Revival.music_select(index)
	draw()
end

function Revival.toggle()
	Revival.music_toggle()
	draw()
end

function Revival.next()
	Revival.music_next()
	draw()
end

function Revival.previous()
	Revival.music_previous()
	draw()
end

function Revival.mute_toggle()
	Revival.music_mute()
	draw()
end

function Revival.repeat_toggle()
	Revival.music_repeat()
	draw()
end

function Revival.seek(event)
	if not primary(event) then return end
	Revival.music_seek(fraction_of(ui.seek, event))
	draw()
end

function Revival.set_volume(event)
	if not primary(event) then return end
	Revival.music_volume(fraction_of(ui.volume, event))
	draw()
end
