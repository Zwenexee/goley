-- The in-game report form: one player complaint or one bug, sent straight to the backend. The
-- model is native: report_script.cpp for the roster and the state, report_send.cpp for the POST.
-- This file draws the form, keeps the selection and forwards the send. player.lua's setup
-- and tick call in here, the way they call into replays.lua.
--
-- Every element id the panel has, in document order. The preview harness under tools/ui_preview
-- renders exactly this list, so a new id belongs here as well as in hud.rml.
--
--   report             the panel. `open` while the card is down, `bug` while the kind is a bug
--   reporthead         the header row; a click toggles the card
--   reportbadge        the flag glyph
--   reporttitle        "Bildir"
--   reportchevron      up while closed, down while open: the card hangs ABOVE the header
--   reportcard         the form
--   reportkind         the segmented switch
--   reportkindplayer   "Oyuncu Şikayeti"
--   reportkindbug      "Hata Bildir"
--   reporttargets      the roster rows, written here from Revival.report_targets()
--   reporttargetmanual the secondary line under the rows: opens the typed field, or says the
--                      roster is empty. Its text is written here
--   reporttargetinput  a typed team name, for someone the roster cannot name. Hidden while the
--                      roster can name somebody, which is what makes picking the first way in
--   reportcats         the category chips, written here, different per kind
--   reporttext         the report itself, capped at 300 characters
--   reportcount        the live character counter
--   reportsend         the send button, greyed while sending, for the cooldown, and for good once
--                      this match's report is in
--   reportsendtext     its label
--   reportstatus       what the server said
--
-- What C++ binds (report_script.cpp), which is all this file needs from the game:
--   Revival.report_targets()                          -> array of team-name strings, may be empty
--   Revival.report_send(kind, target, category, text) -> true when the POST was queued
--   Revival.report_state()                            -> { sending, cooldown_s, last_error,
--                                                          blocked }
--
-- `blocked` is the one-report-per-match rule seen from here: report_send remembers the room id
-- the last accepted report was filed for and compares it against the room the player is in right
-- now, so it is true for the rest of that match and false again in the next one. Nothing in this
-- file counts anything down for it -- a new match is a new room id, which is what clears it.

local ui = {}

-- The cap is the server's, restated so the counter and the rejection agree.
local MAX_TEXT = 300

-- Both halves of the wire contract: the id is what the request carries, the label is what the
-- player reads. Kept in one table so a label can be reworded without touching the wire.
--
-- A complaint is about cheating or about what somebody said, and nothing else: the two the staff
-- queue can actually act on. AFK and "Diğer" were dropped rather than left as a chip that files
-- a report nobody does anything with -- the 300 characters below say the rest either way, and
-- the backend's own catalog was cut to the same two so a hand-made request cannot reinstate one.
local CATEGORIES = {
	player = {
		{ id = "cheat", label = "Hile" },
		{ id = "chat", label = "Sohbet" },
	},
	bug = {
		{ id = "crash", label = "Çökme" },
		{ id = "graphics", label = "Görüntü" },
		{ id = "gameplay", label = "Oynanış" },
		{ id = "other", label = "Diğer" },
	},
}

-- report_send hands back a code when the server gave no sentence of its own; anything else it
-- returns is the server's `message` and is printed as it came.
local REASONS = {
	unauthorized = "Hesap anahtarı yok; oyunu launcher'dan başlat.",
	rate_limited = "Çok sık bildirim gönderildi.",
	validation_error = "Bildirim kabul edilmedi.",
	already_reported = "Bu maç için bildirim zaten gönderilmiş.",
	network = "Sunucuya ulaşılamadı; bağlantını kontrol et.",
}

-- The roster only changes when a match starts or ends, and rebuilding the rows is a relayout that
-- would reset the scroll under the pointer. Read on a slow timer, written only when it differs.
local ROSTER_EVERY = 0.5

local kind = "player"
local targets = {}
local picked = nil          -- index into targets; nil means "use whatever was typed"
-- The player asked for the typed field even though the roster could name somebody. Picking is
-- the first way in and the typed name is the way out of a roster that is wrong, so the field is
-- out of sight until it is asked for -- and a roster that names nobody asks for it on its own.
local manual = false
local chosen = { player = nil, bug = nil }
-- What the last submit refused to do, which is ours and not the server's. Cleared on the next
-- edit that could fix it, so it never outlives the mistake.
local notice = ""
-- True between a queued send and the worker's answer, so draw knows whose turn it is to clear the
-- form: the text is kept on failure, because losing what someone just typed is worse than a
-- second click.
local pending = false
local rows_drawn = nil
local hint_drawn = nil
local roster_at = nil
local count_drawn = nil
local label_drawn = nil
local status_drawn = nil

-- Characters, not bytes. `#text` counts bytes, and half of Turkish is two of them in UTF-8, so a
-- byte count would tell a player they were at the cap with 160 characters typed. Every byte that
-- is not a 10xxxxxx continuation starts a character, so counting those counts characters.
local function chars(text)
	local _, count = text:gsub("[^\128-\191]", "")
	return count
end

local function trim(text)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- A form control's text lives in its `value` attribute and RmlUi's own widget writes it back
-- there on every keystroke. It is reached by attribute and not by `.value` because
-- GetElementById hands Lua a plain Element, and the value property belongs to the form control
-- type it was never pushed as.
local function value_of(element)
	local text = element:GetAttribute("value")
	if text == nil then return "" end
	return tostring(text)
end

-- Whether the typed field is in play. Picking is the first way in, so the field is hidden while
-- the roster can name somebody -- unless the player asked for it, or already typed into it and
-- hiding it would throw that away.
local function typing()
	return manual or #targets == 0 or trim(value_of(ui.reporttargetinput)) ~= ""
end

local function build_targets()
	targets = Revival.report_targets() or {}
	if picked ~= nil and targets[picked] == nil then picked = nil end

	local parts = {}
	for index, team in ipairs(targets) do
		-- The name is in a <span> and not loose in the row, which is what .replayrow and .row do
		-- and for a reason that is not style: .reportrow is a flex container, and RmlUi lays out
		-- no anonymous text node inside one. Written loose, the row drew its box, its hover and
		-- its lit border with nothing in them -- measured, the text child came back 0px wide.
		parts[#parts + 1] = string.format(
			'<div class="reportrow%s" onclick="Revival.report_pick(%d)">' ..
			'<span class="reportteam">%s</span></div>',
			picked == index and " on" or "", index, Revival.escape(team))
	end
	if #targets == 0 then
		parts[1] = '<span class="reportempty">Kimse listelenmedi; adı aşağıya yaz.</span>'
	end

	local text = table.concat(parts)
	if text ~= rows_drawn then
		rows_drawn = text
		ui.reporttargets.inner_rml = text
	end

	-- The second way in, worded as what pressing it does. With nobody to pick there is no second
	-- way -- the line above already says the field is all there is -- so it says nothing.
	local open = typing()
	local hint = ""
	if #targets > 0 then
		hint = open and "Listeden seç" or "Listede yoksa takım adını yaz"
	end
	ui.reporttargetmanual:SetClass("link", #targets > 0)
	ui.report:SetClass("typed", kind == "player" and open)
	if hint ~= hint_drawn then
		hint_drawn = hint
		ui.reporttargetmanual.inner_rml = hint
	end
end

local function build_cats()
	local list = CATEGORIES[kind]
	local parts = {}
	for index, category in ipairs(list) do
		parts[#parts + 1] = string.format(
			'<div class="reportchip%s" onclick="Revival.report_cat(%d)">%s</div>',
			chosen[kind] == index and " on" or "", index, category.label)
	end
	ui.reportcats.inner_rml = table.concat(parts)
end

-- draw runs every frame, so the line is written only when it actually changes. The tone is part
-- of the key: the same sentence in a different colour is a different line.
local function say(text, tone)
	local key = (tone or "") .. "\0" .. text
	if key == status_drawn then return end
	status_drawn = key
	ui.reportstatus.inner_rml = text
	ui.reportstatus:SetClass("bad", tone == "bad")
	ui.reportstatus:SetClass("good", tone == "good")
end

function Revival.report_setup(document)
	for _, id in ipairs({ "report", "reportchevron", "reportkindplayer", "reportkindbug",
	                      "reporttargets", "reporttargetmanual", "reporttargetinput",
	                      "reportcats", "reporttext", "reportcount", "reportsend",
	                      "reportsendtext", "reportstatus" }) do
		ui[id] = document:GetElementById(id)
	end

	picked = nil
	manual = false
	notice = ""
	pending = false
	rows_drawn = nil
	hint_drawn = nil
	roster_at = nil
	count_drawn = nil
	label_drawn = nil
	status_drawn = nil

	-- On the namespace, like the music card: a hot reload keeps the panel open while its
	-- stylesheet is being edited.
	ui.report:SetClass("open", Revival.report_open == true)
	ui.report:SetClass("bug", kind == "bug")
	-- Closed on a cold load, so the roster is unread and the typed field is the only one that
	-- could be used: the card opening is what decides otherwise.
	ui.report:SetClass("typed", kind == "player")
	ui.reportkindplayer:SetClass("on", kind == "player")
	ui.reportkindbug:SetClass("on", kind == "bug")
	ui.reportchevron:SetAttribute("src", Revival.report_open and "../icons/chevron_down.svg"
	                                     or "../icons/chevron_up.svg")
	-- The chips are local, so they are always there for the card to open onto. The rows are not:
	-- building them asks the game for its roster, and a panel that is closed on every load but
	-- the one after a hot reload should not make that call -- nor make Revival.setup depend on
	-- the native binding being in place, which is the same bargain replays.lua strikes.
	build_cats()
	if Revival.report_open then build_targets() end
end

function Revival.report_draw(now)
	-- Closed, the card is not laid out and nothing in it can have changed: the only thing worth a
	-- frame is the countdown on the button, and that is not visible either.
	if Revival.report_open ~= true then return end

	if now == nil or roster_at == nil or now - roster_at >= ROSTER_EVERY then
		roster_at = now
		if kind == "player" then build_targets() end
	end

	local state = Revival.report_state()

	-- The worker has answered. A report that went through leaves nothing behind to send twice;
	-- one that failed keeps every word, because the player may only need to fix the target.
	if pending and not state.sending then
		pending = false
		if state.last_error == "" then
			ui.reporttext:SetAttribute("value", "")
			ui.reporttargetinput:SetAttribute("value", "")
			-- Rebuilt here rather than left to the next roster tick: that is up to half a second
			-- away, and the row would stay lit for it as if the report were still unsent.
			picked = nil
			manual = false
			rows_drawn = nil
			if kind == "player" then build_targets() end
		end
	end

	-- After the clear above, so the frame that empties the field is the frame the counter reads
	-- zero rather than the one after it.
	local typed = chars(value_of(ui.reporttext))
	if typed ~= count_drawn then
		count_drawn = typed
		ui.reportcount.inner_rml = string.format("%d/%d", typed, MAX_TEXT)
		ui.reportcount:SetClass("full", typed >= MAX_TEXT)
	end

	-- Three different reasons the button cannot be pressed, one greyed button: sending is for a
	-- second or two, the cooldown is the server's gap between two reports, and `blocked` is this
	-- match's report already being in and does not run out while the match does not.
	local off = state.sending or state.cooldown_s > 0 or state.blocked
	ui.reportsend:SetClass("off", off)

	local label = "Gönder"
	if state.sending then
		label = "Gönderiliyor…"
	elseif state.blocked then
		-- Ahead of the countdown, which is running too right after a report is taken: a number
		-- ticking down says the button is coming back, and for this match it is not.
		label = "Gönderildi"
	elseif state.cooldown_s > 0 then
		label = string.format("%d sn", state.cooldown_s)
	end
	if label ~= label_drawn then
		label_drawn = label
		ui.reportsendtext.inner_rml = label
	end

	if state.sending then
		say("Gönderiliyor…", nil)
	elseif state.blocked then
		-- Ahead of the error line, because a 409 arrives here as `already_reported`: the report
		-- is filed either way, and what the player needs told is that it is -- not that the
		-- attempt they just made was refused.
		say("Bu maç için bildirim gönderildi.", "good")
	elseif state.last_error ~= "" then
		-- A refusal that came with a wait is shown as the wait: the seconds are the only part of
		-- it the player can act on.
		if state.cooldown_s > 0 then
			say(string.format("Çok sık bildirim. %d sn sonra tekrar dene.", state.cooldown_s), "bad")
		else
			say(REASONS[state.last_error] or state.last_error, "bad")
		end
	elseif state.cooldown_s > 0 then
		say("Bildirin alındı. Teşekkürler.", "good")
	else
		say(notice, notice ~= "" and "bad" or nil)
	end
end

function Revival.report_toggle()
	Revival.report_open = not Revival.report_open
	ui.report:SetClass("open", Revival.report_open)
	ui.reportchevron:SetAttribute("src", Revival.report_open and "../icons/chevron_down.svg"
	                                     or "../icons/chevron_up.svg")
	if Revival.report_open then
		roster_at = nil
		build_targets()
	end
end

function Revival.report_kind(next_kind)
	if CATEGORIES[next_kind] == nil or next_kind == kind then return end
	kind = next_kind
	notice = ""
	status_drawn = nil
	ui.report:SetClass("bug", kind == "bug")
	ui.reportkindplayer:SetClass("on", kind == "player")
	ui.reportkindbug:SetClass("on", kind == "bug")
	build_cats()
	-- A bug has no target, so the rows are not redrawn until the player comes back to a
	-- complaint; the group is hidden by the stylesheet meanwhile. The typed field is part of that
	-- group, so its class goes with it rather than waiting for a rebuild that will not come.
	if kind == "player" then
		rows_drawn = nil
		hint_drawn = nil
		build_targets()
	else
		ui.report:SetClass("typed", false)
	end
end

function Revival.report_pick(index)
	if targets[index] == nil then return end
	-- A second press on the chosen row clears it, which is how someone goes back to typing a name
	-- after picking one by mistake.
	picked = picked == index and nil or index
	-- A picked row is the answer, so the typed field puts itself away and takes what was in it
	-- with it: two names in the form and only one of them sent is how the wrong player gets
	-- reported.
	if picked ~= nil then
		manual = false
		ui.reporttargetinput:SetAttribute("value", "")
	end
	notice = ""
	rows_drawn = nil
	build_targets()
end

-- The second way in, from the line under the rows: it opens the typed field when the roster
-- could name somebody and closes it again, which is the way back to picking. With an empty
-- roster the field is already the only way in and there is nothing to toggle.
function Revival.report_manual()
	if #targets == 0 then return end
	manual = not manual
	if manual then
		picked = nil
	else
		ui.reporttargetinput:SetAttribute("value", "")
	end
	notice = ""
	rows_drawn = nil
	build_targets()
end

function Revival.report_cat(index)
	if CATEGORIES[kind][index] == nil then return end
	chosen[kind] = index
	notice = ""
	build_cats()
end

function Revival.report_wheel(event)
	ui.reporttargets.scroll_top = ui.reporttargets.scroll_top -
		(event.parameters["wheel_delta_y"] or 0) * 40
end

function Revival.report_submit()
	local state = Revival.report_state()
	if state.sending or state.cooldown_s > 0 or state.blocked then return end

	local body = trim(value_of(ui.reporttext))
	local category = CATEGORIES[kind][chosen[kind] or 0]
	local target = ""
	if kind == "player" then
		target = picked ~= nil and targets[picked] or trim(value_of(ui.reporttargetinput))
	end

	-- Said here rather than spent as a request: the server would refuse all three, and a refusal
	-- costs the player one of the three reports an hour buys.
	if kind == "player" and target == "" then
		notice = "Kimi bildirdiğini seç ya da adını yaz."
	elseif category == nil then
		notice = "Bir başlık seç."
	elseif body == "" then
		notice = "Ne olduğunu kısaca yaz."
	else
		notice = ""
	end
	if notice ~= "" then
		status_drawn = nil
		return
	end

	if Revival.report_send(kind, target, category.id, body) then
		pending = true
		status_drawn = nil
	end
end
