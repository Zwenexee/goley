-- Where the player has put the panels.
--
-- Four panels move: the radio pill, the replay list, the report panel and the peer paths. Each is
-- grabbed by a handle, dropped where he wants it, and found there again next session. The file is
-- layout_store.cpp's; this owns the pixels.
--
-- THE DRAG IS RMLUI'S, NOT OURS. `drag: drag` on a handle (theme.rcss) makes the context latch
-- that element on a primary press, decide for itself when a press has become a drag, keep the
-- capture while the pointer leaves the element, and release it on the button coming up. All that
-- is left here is turning the pointer position the events carry into a `left` and a `top`. Three
-- consequences worth stating, because they are the reasons this file is short:
--
--   * "primary button only" is free. Context::ProcessMouseButtonDown only looks for a drag element
--     under button 0, so a right-press cannot move anything.
--   * "a press on a control must not move the panel" is a stylesheet rule, not a check in here.
--     RmlUi walks up from whatever was pressed looking for a drag element; `drag: block` on
--     .control stops that walk, so the play glyph inside the pill's handle plays and nothing else.
--   * the existing rails keep working untouched. #volume, #stations and #rpseek each declare
--     `drag: drag` themselves, so the walk stops at them and never reaches a panel.
--
-- Loaded before the panels' own scripts (name order, see ui::load_scripts); player.lua's setup and
-- tick call in here.

-- Handle id -> panel id. The pill, the replay list and the report panel are grabbed by their
-- header; #peerpaths has no header, so it is its own handle. #replaybar is deliberately absent: it
-- is a transient transport that exists only while a replay plays, it already owns three drag
-- handlers of its own on #rpseek, and a bar the player moves once and then loses under the HUD
-- mid-match is worse than one that is always in the same place.
local HANDLES = {
	bar = "music",
	replayhead = "replays",
	reporthead = "report",
	peerpaths = "peerpaths",
}

local ui = {}
local panels = {}
-- The drag in flight: which panel, and where inside it the pointer went down.
local grab = nil
-- Set for exactly as long as RmlUi's click for this press is still to come. See layout_dragged.
local dragged = false
-- Panels restored from the file whose box could not be measured yet, so the clamp is still owed.
local pending = {}

-- The viewport, which is what a saved fraction is a fraction OF. Read live rather than cached at
-- setup: the game changes backbuffer size on a display-mode change and the overlay follows it
-- (overlay::on_device_reset -> Context::SetDimensions) without reloading the document.
local function viewport()
	local context = ui.document ~= nil and ui.document.context or nil
	if context == nil then return 0, 0 end
	local size = context.dimensions
	return size.x, size.y
end

-- Distance from the context's origin, the two-axis twin of player.lua's absolute_left and for the
-- same reason: the Element binding offers offset_left/offset_top against the offset parent and the
-- chain to walk, not the absolute offset the C++ sums.
local function absolute_of(element)
	local left = 0
	local top = 0
	local at = element
	while at ~= nil do
		left = left + at.offset_left
		top = top + at.offset_top
		local parent = at.offset_parent
		if parent ~= nil then
			left = left - parent.scroll_left
			top = top - parent.scroll_top
		end
		at = parent
	end
	return left, top
end

-- Whole pixels, like every other length in this UI: RmlUi snaps geometry to the pixel grid, and a
-- fractional offset would drift the panel's border a pixel from where its text lands.
local function place(element, x, y)
	element.style.left = string.format("%dpx", math.floor(x + 0.5))
	element.style.top = string.format("%dpx", math.floor(y + 0.5))
end

-- Fully on screen: no negative corner, and no edge past the far side. A panel wider than the
-- viewport pins to 0 rather than to a negative left, because the part of a panel worth seeing is
-- the end with the header on it.
local function clamp(element, x, y)
	local width, height = viewport()
	x = math.max(0, math.min(x, width - element.offset_width))
	y = math.max(0, math.min(y, height - element.offset_height))
	return x, y
end

-- Everything `moved` means: the inline corner, and the class that tells theme.rcss to stop
-- anchoring the panel to whichever edge it was built against.
local function move_to(panel, x, y)
	panel:SetClass("moved", true)
	place(panel, x, y)
end

-- A right press has no `drag: block` to obey -- that property is read by the context for button 0
-- only -- so the one rule the stylesheet cannot state for it is stated here. Right-pressing the
-- play glyph to send the pill home would be exactly the surprise `drag: block` exists to prevent.
local function on_control(element, handle)
	local at = element
	while at ~= nil and at ~= handle do
		if at:IsClassSet("control") then return true end
		at = at.parent_node
	end
	return false
end

local function panel_of(event)
	local handle = event.current_element
	if handle == nil then return nil, nil, nil end
	local id = HANDLES[handle.id]
	if id == nil then return nil, nil, nil end
	return id, panels[id], handle
end

function Revival.layout_setup(document)
	ui.document = document
	panels = {}
	grab = nil
	dragged = false
	pending = {}
	for _, id in pairs(HANDLES) do
		panels[id] = document:GetElementById(id)
	end

	local saved = Revival.layout_load() or {}
	local width, height = viewport()
	for id, spot in pairs(saved) do
		local panel = panels[id]
		if panel ~= nil and type(spot) == "table" and spot.x ~= nil and spot.y ~= nil then
			move_to(panel, spot.x * width, spot.y * height)
			-- Clamping has to wait for a box: nothing is laid out at load, and a panel whose
			-- state is not on screen yet -- the report panel outside a match -- has no size to
			-- clamp against until it is.
			pending[id] = true
		end
	end
end

-- The clamp the restore could not do yet, retried until each panel has been measured once.
--
-- What is NOT done here is writing the clamped position back. A layout built on a 1920x1080 panel
-- and then played once at 1280x720 must survive that session: saving the squeezed position would
-- turn one evening in a window into the permanent layout.
function Revival.layout_draw()
	if next(pending) == nil then return end
	for id in pairs(pending) do
		local panel = panels[id]
		if panel == nil then
			pending[id] = nil
		elseif panel.offset_width > 0 then
			place(panel, clamp(panel, absolute_of(panel)))
			pending[id] = nil
		end
	end
end

function Revival.layout_grab(event)
	local id, panel = panel_of(event)
	if panel == nil then return end

	-- The corner it is at NOW, written before the class lands: `moved` turns off whichever of
	-- right/bottom/auto-margin the stylesheet had been anchoring this panel with, and a panel that
	-- lost its anchor without having been given a left/top first would jump to the origin.
	local x, y = absolute_of(panel)
	move_to(panel, x, y)

	-- Where inside the panel the pointer went down, so it travels with the pointer instead of
	-- snapping its corner under the cursor. `dragstart` carries the PRESS position -- RmlUi sends
	-- it with the previous mouse position, not the one that triggered it -- which is the only
	-- position this offset is correct against.
	grab = {
		id = id,
		panel = panel,
		dx = event.parameters["mouse_x"] - x,
		dy = event.parameters["mouse_y"] - y,
	}
	dragged = true
end

function Revival.layout_move(event)
	if grab == nil then return end
	place(grab.panel, event.parameters["mouse_x"] - grab.dx, event.parameters["mouse_y"] - grab.dy)
end

function Revival.layout_drop(event)
	if grab == nil then return end
	local id = grab.id
	local panel = grab.panel

	-- From the event rather than from the element: the last `drag` wrote a style the context has
	-- not laid out yet, so the panel's own offset is still a frame behind the pointer.
	local x, y = clamp(panel, event.parameters["mouse_x"] - grab.dx,
	                   event.parameters["mouse_y"] - grab.dy)
	grab = nil
	place(panel, x, y)

	local width, height = viewport()
	if width > 0 and height > 0 then Revival.layout_save(id, x / width, y / height) end
	-- It has been placed by hand now; whatever the file said is settled.
	pending[id] = nil
	-- Last, not first: RmlUi dispatches the click for this press BEFORE the dragend that brought
	-- us here, so the flag has to outlive the click it is there to swallow.
	dragged = false
end

-- Right press on a handle: back to where the stylesheet had it, and forgotten on disk.
function Revival.layout_press(event)
	if event.parameters["button"] ~= 1 then return end
	local id, panel, handle = panel_of(event)
	if panel == nil or on_control(event.target_element, handle) then return end
	-- A panel that was never moved has nothing to restore and nothing on disk to erase. Worth the
	-- check: right-clicking the HUD is something players do idly, and each one of those would
	-- otherwise rewrite the file.
	if not panel:IsClassSet("moved") then return end

	panel:SetClass("moved", false)
	-- nil removes the property, which is what puts the panel back under the stylesheet's own
	-- anchoring rather than at left: 0.
	panel.style.left = nil
	panel.style.top = nil
	pending[id] = nil
	Revival.layout_forget(id)
end

-- Whether the click RmlUi is delivering right now is the tail of a drag.
--
-- Context::ProcessMouseButtonUp dispatches the click before the dragend, and a header the player
-- has just dragged is still under his pointer, so the click lands. Without this, moving the replay
-- list would also open and close it. hud.rml asks before acting on a header click.
function Revival.layout_dragged()
	return dragged
end
