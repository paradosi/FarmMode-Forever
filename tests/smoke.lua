-- luacheck: ignore
-- (this file stubs the WoW API by assigning its globals; nothing here ships)
--
-- Headless test: loads the addon in TOC order against a stubbed WoW API, then
-- plays through toggling, shapes, combat (all three modes), cities, mounting,
-- reloads, click-through and the tracking swap, checking the minimap's state
-- after each step. Catches nil calls, typos and state-machine slips that the
-- static gate can't. It does not draw anything: layout still needs the game.
--
--   cd FarmMode-Forever && lua5.1 tests/smoke.lua

local failures = 0
local function check(cond, msg)
    if cond then print("ok   " .. msg) else failures = failures + 1; print("FAIL " .. msg) end
end

---- A permissive widget: unknown methods are no-ops; the ones the addon reads
---- keep real state

local methods = {}
local Widget = {
    -- Methods are CamelCase: an unknown one is a no-op. Fields are lowercase
    -- and read as nil, as on a real frame.
    __index = function(_, k)
        if methods[k] then return methods[k] end
        if type(k) == "string" and k:match("^%u") then return function() end end
    end,
}
local function NewWidget(kind, name)
    return setmetatable({ kind = kind, name = name, scripts = {}, shown = true, points = {},
                          w = 100, h = 100, alpha = 1, mouse = true, wheel = true, value = 0,
                          min = 0, max = 100, children = {} }, Widget)
end
function methods.SetScript(self, k, fn) self.scripts[k] = fn end
function methods.GetScript(self, k) return self.scripts[k] end
function methods.HookScript(self, k, fn)
    local before = self.scripts[k]
    self.scripts[k] = function(...) if before then before(...) end fn(...) end
end
function methods.Show(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods.Hide(self) self.shown = false end
function methods.SetShown(self, on) if on then self:Show() else self:Hide() end end
function methods.IsShown(self) return self.shown end
function methods.SetSize(self, w, h) self.w, self.h = w, h end
function methods.SetWidth(self, w) self.w = w end
function methods.SetHeight(self, h) self.h = h end
function methods.GetSize(self) return self.w, self.h end
function methods.GetWidth(self) return self.w end
function methods.GetHeight(self) return self.h end
function methods.GetTop() return 600 end
function methods.GetBottom() return 0 end
function methods.GetEffectiveScale() return 1 end
function methods.GetFrameLevel() return 1 end
function methods.ClearAllPoints(self) self.points = {} end
function methods.SetPoint(self, ...) table.insert(self.points, { ... }) end
function methods.GetNumPoints(self) return #self.points end
function methods.GetPoint(self, i) return unpack(self.points[i or 1] or {}) end
function methods.SetAlpha(self, a) self.alpha = a end
function methods.GetAlpha(self) return self.alpha end
function methods.EnableMouse(self, on) self.mouse = on and true or false end
function methods.IsMouseEnabled(self) return self.mouse end
function methods.EnableMouseWheel(self, on) self.wheel = on and true or false end
function methods.IsMouseWheelEnabled(self) return self.wheel end
function methods.IsMouseOver() return false end
function methods.HasFocus() return false end
function methods.SetText(self, t) self.text = t end
function methods.SetFormattedText(self, f, ...) self.text = f:format(...) end
function methods.GetText(self) return self.text end
function methods.GetName(self) return self.name end
function methods.GetChildren(self) return unpack(self.children) end
function methods.CreateTexture(self) return NewWidget("Texture") end
function methods.CreateFontString(self) return NewWidget("FontString") end
function methods.CreateMaskTexture(self) return NewWidget("MaskTexture") end
function methods.GetThumbTexture(self)
    self.thumb = self.thumb or NewWidget("Texture")
    return self.thumb
end
function methods.SetMinMaxValues(self, a, b) self.min, self.max = a, b end
function methods.SetValue(self, v)
    self.value = v
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end
end
function methods.GetValue(self) return self.value end
function methods.GetVerticalScrollRange() return 100 end
function methods.GetVerticalScroll() return 0 end
function methods.RegisterEvent(self, e) self.events = self.events or {}; self.events[e] = true end
function methods.SetMaskTexture(self, m) self.mask = m end
function methods.GetZoom(self) return self.zoom or 2 end
function methods.SetZoom(self, z) self.zoom = z end
function methods.GetZoomLevels() return 6 end
function methods.RegisterForDrag(self, b) self.dragButton = b end

---- Globals the addon and Blizzard's minimap provide

local frames = {}
function CreateFrame(kind, name, parent)
    local f = NewWidget(kind, name)
    if name then _G[name] = f end
    if parent then table.insert(parent.children, f) end
    table.insert(frames, f)
    return f
end
UIParent = NewWidget("Frame", "UIParent")
Minimap = NewWidget("Minimap", "Minimap")
Minimap.w, Minimap.h, Minimap.mask = 198, 198, "ui-hud-minimap-frame-generic-mask"
Minimap.points = { { "CENTER", "MinimapContainer", "CENTER", 0, 0 } }
Minimap.ZoomIn = NewWidget("Button"); Minimap.ZoomIn.shown = false
Minimap.ZoomOut = NewWidget("Button"); Minimap.ZoomOut.shown = false
Minimap.ZoomHitArea = NewWidget("Frame")
for _, k in ipairs({ "ZoomIn", "ZoomOut", "ZoomHitArea" }) do
    Minimap[k].points = { { "CENTER", nil, "CENTER", 77, -77 } }
end
local libdb = NewWidget("Button", "LibDBIcon10_Something")
table.insert(Minimap.children, libdb)
MinimapBackdrop = NewWidget("Frame"); MinimapBackdrop.w, MinimapBackdrop.h = 215, 226
MinimapBackdrop.ExternalEventURLButton = NewWidget("Button")
MinimapCompassTexture = NewWidget("Texture"); MinimapCompassTexture.w, MinimapCompassTexture.h = 215, 226
MinimapCompassTextureUnderlay = NewWidget("Texture"); MinimapCompassTextureUnderlay.shown = false
MinimapCluster = NewWidget("Frame", "MinimapCluster")
MinimapCluster.ZoneTextButton = NewWidget("Button")
MinimapCluster.Tracking = NewWidget("Frame")
function MinimapCluster:UpdateMinimapConfig() end
GameTimeFrame = NewWidget("Button")
AddonCompartmentFrame = NewWidget("Button")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) LAST_PRINT = m end }
SOUNDKIT = { U_CHAT_SCROLL_BUTTON = 1115 }
function PlaySound() end
function CreateColor(r, g, b, a) return { r, g, b, a } end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function hooksecurefunc(t, name, fn)
    local orig = t[name]
    t[name] = function(...) local r = orig(...); fn(...); return r end
end
function canaccessvalue() return true end
function GetCursorPosition() return 0, 0 end
function IsMouseButtonDown() return false end

local state = { combat = false, resting = false, instance = false, mounted = false, alt = false,
                casting = false, cvars = { rotateMinimap = "0" } }
function InCombatLockdown() return state.combat end
function IsResting() return state.resting end
function IsInInstance() return state.instance end
function IsMounted() return state.mounted end
function IsAltKeyDown() return state.alt end
function UnitIsDeadOrGhost() return false end
function UnitOnTaxi() return false end
function UnitCastingInfo() if state.casting then return "Herb Gathering" end end
function UnitChannelInfo() return nil end
function GetCVar(k) return state.cvars[k] end
function SetCVar(k, v) state.cvars[k] = v end

local timers = {}
C_Timer = {
    After = function(_, fn) table.insert(timers, fn) end,
    NewTicker = function(sec, fn)
        local t = { sec = sec, fn = fn, cancelled = false }
        function t:Cancel() self.cancelled = true end
        table.insert(timers, t)
        return t
    end,
}
local function RunAfters()
    local i = 1
    while i <= #timers do
        if type(timers[i]) == "function" then table.remove(timers, i)() else i = i + 1 end
    end
end
local function Tick()  -- fire every live ticker once
    for _, t in ipairs(timers) do
        if type(t) == "table" and not t.cancelled then t.fn() end
    end
end
local function LiveTickers()
    local n = 0
    for _, t in ipairs(timers) do if type(t) == "table" and not t.cancelled then n = n + 1 end end
    return n
end

local tracking = {
    { name = "Find Herbs", spellID = 2383, active = true },
    { name = "Find Minerals", spellID = 2580, active = false },
    { name = "Track Humanoids", spellID = nil, active = false },
}
C_Minimap = {
    GetNumTrackingTypes = function() return #tracking end,
    GetTrackingInfo = function(i) return tracking[i] end,
    SetTracking = function(i, on)
        for j, t in ipairs(tracking) do if t.spellID then t.active = (j == i) and on end end
    end,
}
C_Map = {
    GetBestMapForUnit = function() return 1429 end,
    GetPlayerMapPosition = function()
        return { GetXY = function() return 0.4123, 0.6789 end }
    end,
}
C_AddOns = {
    GetAddOnMetadata = function() return "0.1.0" end,
    IsAddOnLoaded = function() return false end,
}
local registered
Settings = {
    RegisterCanvasLayoutCategory = function(p) registered = p; return { GetID = function() return 1 end } end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function() end,
}
SlashCmdList = {}

---- Load in TOC order

local ns = {}
for line in io.lines("FarmModeForever.toc") do
    if line:match("%.lua$") then
        local chunk = assert(loadfile(line))
        chunk("FarmModeForever", ns)
    end
end

local eventFrame
for _, f in ipairs(frames) do
    if f.events and f.events.ADDON_LOADED then eventFrame = f end
end
local function Fire(event, ...) eventFrame.scripts.OnEvent(eventFrame, event, ...) end

---- Scenarios

FarmModeForeverDB = nil
Fire("ADDON_LOADED", "FarmModeForever")
Fire("PLAYER_LOGIN")
Fire("PLAYER_ENTERING_WORLD", true, false)
RunAfters()
check(not ns.IsFarming(), "starts off")
check(registered and registered.name == "FarmMode Forever", "settings panel registered")

-- the panel builds and syncs
registered:Show()
check(true, "settings panel OnShow runs")

-- on, default look
SlashCmdList.FARMMODEFOREVER("")
check(ns.IsFarming(), "/farm turns it on")
check(Minimap.w == 400, "resized to 400")
check(MinimapCompassTexture.w > 215 * 2, "round border art scaled up")
check(Minimap.mask == "ui-hud-minimap-frame-generic-mask", "round mask untouched")
check(Minimap.points[1][2] == UIParent, "anchored to the screen")
check(not Minimap.mouse, "click-through: mouse off")
state.alt = true; Fire("MODIFIER_STATE_CHANGED")
check(Minimap.mouse, "click-through: Alt gives the mouse back")
state.alt = false; Fire("MODIFIER_STATE_CHANGED")
check(not Minimap.mouse, "click-through: releasing Alt takes it again")
Tick()
local coordText
for _, f in ipairs(Minimap.children) do if f.text and f.text.text then coordText = f.text.text end end
check(coordText == "41.2, 67.9", "coordinates shown (" .. tostring(coordText) .. ")")

-- square, then off: everything back
SlashCmdList.FARMMODEFOREVER("square")
check(Minimap.mask == "Interface\\Buttons\\WHITE8X8", "square mask")
check(not MinimapCompassTexture.shown, "round border hidden when square")
SlashCmdList.FARMMODEFOREVER("")
check(not ns.IsFarming(), "/farm turns it off")
check(Minimap.w == 198 and Minimap.h == 198, "size restored")
check(Minimap.mask == "ui-hud-minimap-frame-generic-mask", "round mask restored")
check(MinimapCompassTexture.shown and MinimapCompassTexture.w == 215, "border art restored")
check(Minimap.points[1][2] == "MinimapContainer", "anchor restored")
check(Minimap.mouse and Minimap.wheel, "mouse restored")
check(Minimap.alpha == 1, "opacity restored")
check(LiveTickers() == 0, "no tickers left running")
SlashCmdList.FARMMODEFOREVER("round")

-- hide buttons: only what we hid comes back
ns.db.hideButtons = true
GameTimeFrame.shown = false   -- hidden by someone else
SlashCmdList.FARMMODEFOREVER("")
check(not MinimapCluster.ZoneTextButton.shown and not libdb.shown, "buttons and LibDBIcon hidden")
SlashCmdList.FARMMODEFOREVER("")
check(MinimapCluster.ZoneTextButton.shown and libdb.shown, "buttons shown again")
check(not GameTimeFrame.shown, "a button hidden by someone else stays hidden")
GameTimeFrame.shown = true
ns.db.hideButtons = false

-- combat: Close and reopen
SlashCmdList.FARMMODEFOREVER("")
Fire("PLAYER_REGEN_DISABLED"); state.combat = true
check(not ns.IsFarming(), "Close: off in combat")
SlashCmdList.FARMMODEFOREVER("")
SlashCmdList.FARMMODEFOREVER("")
check(not ns.IsFarming(), "two presses in combat cancel out")
state.combat = false; Fire("PLAYER_REGEN_ENABLED")
check(ns.IsFarming(), "Close: back after combat")

-- combat: Close without reopen
ns.db.combatReopen = false
Fire("PLAYER_REGEN_DISABLED"); state.combat = true
state.combat = false; Fire("PLAYER_REGEN_ENABLED")
check(not ns.IsFarming(), "Close without reopen: stays off")
ns.db.combatReopen = true

-- combat: Fade
ns.db.combatMode = "FADE"
SlashCmdList.FARMMODEFOREVER("")
Fire("PLAYER_REGEN_DISABLED"); state.combat = true
check(ns.IsFarming() and math.abs(Minimap.alpha - 0.2) < 1e-6, "Fade: stays, at 20%")
state.combat = false; Fire("PLAYER_REGEN_ENABLED")
check(Minimap.alpha == 1, "Fade: full opacity after combat")

-- combat: Stay, and a toggle-off during combat waits
ns.db.combatMode = "STAY"
Fire("PLAYER_REGEN_DISABLED"); state.combat = true
check(ns.IsFarming(), "Stay: stays")
SlashCmdList.FARMMODEFOREVER("")
check(ns.IsFarming(), "toggle in combat waits")
state.combat = false; Fire("PLAYER_REGEN_ENABLED")
check(not ns.IsFarming(), "then switches off after combat")
ns.db.combatMode = "CLOSE"

-- cities
ns.db.offResting = true
SlashCmdList.FARMMODEFOREVER("")
state.resting = true; Fire("PLAYER_UPDATE_RESTING")
check(not ns.IsFarming(), "hidden on entering a city")
SlashCmdList.FARMMODEFOREVER("")
check(ns.IsFarming(), "/farm opens it in a city anyway")
state.resting = false; Fire("PLAYER_UPDATE_RESTING")
check(ns.IsFarming(), "still on after leaving")
state.resting = true; Fire("PLAYER_UPDATE_RESTING")
check(not ns.IsFarming(), "hidden again in the next city")
state.resting = false; Fire("PLAYER_UPDATE_RESTING")
check(ns.IsFarming(), "and back outside it")
ns.db.offResting = false

-- dungeons (on by default)
state.instance = true; Fire("PLAYER_ENTERING_WORLD", false, false)
check(not ns.IsFarming(), "hidden in a dungeon")
state.instance = false; Fire("PLAYER_ENTERING_WORLD", false, false)
check(ns.IsFarming(), "back outside")
SlashCmdList.FARMMODEFOREVER("")

-- mounting
ns.db.autoMount = true
state.mounted = true; Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
check(ns.IsFarming(), "mounting turns it on")
state.mounted = false; Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
check(ns.IsFarming(), "dismounting leaves it on (you dismount to gather)")
ns.db.autoMount = false

-- rotate
ns.db.rotate = true; ns.Refresh()
check(state.cvars.rotateMinimap == "1", "rotate on while farming")
SlashCmdList.FARMMODEFOREVER("")
check(state.cvars.rotateMinimap == "0", "rotate put back when off")
ns.db.rotate = false

-- tracking swap
ns.db.swapTracking = true
SlashCmdList.FARMMODEFOREVER("")
Tick()
check(tracking[2].active and not tracking[1].active, "swap: herbs -> minerals")
Tick()
check(tracking[1].active and not tracking[2].active, "swap: minerals -> herbs")
state.casting = true; Tick()
check(tracking[1].active, "swap waits while casting")
state.casting = false

-- remember across a reload
Fire("PLAYER_LOGOUT")
check(FarmModeForeverDB.wanted == true, "logout saves that farm mode was on")
check(state.cvars.rotateMinimap == "0", "logout leaves rotate as it was")

-- reset defaults through the panel's own path
for k, v in pairs(ns.defaults) do ns.db[k] = v end
ns.Refresh()
check(ns.db.size == 400 and ns.db.combatMode == "CLOSE", "defaults")

print(failures == 0 and "\nall passed" or ("\n" .. failures .. " FAILED"))
os.exit(failures == 0 and 0 or 1)
