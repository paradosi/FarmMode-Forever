---- Core — FarmMode Forever: the minimap as a big gathering map, and back again
--
-- Written for WoW Forever only (16001, Retail 12's minimap). The classic
-- FarmMode runs on four clients and scales the minimap; this one RESIZES it, so
-- the map shows more ground while node and quest icons stay their normal size.
--
-- Two states, kept apart on purpose:
--   wanted   the player's intent: /farm, the key binding, mounting up (if
--            that option is on), and remembered across /reload and login
--   farming  whether the big map is on screen right now
-- Reconcile() makes `farming` follow `wanted` unless something blocks it:
-- combat (in "Close" mode), a dungeon, or a city or inn. So a fight or a
-- capital puts the minimap back, and it returns by itself afterwards.
--
-- Everything farm mode changes is snapshotted first and put back exactly when
-- it switches off. Blizzard's minimap art lives in MinimapBackdrop (a child of
-- Minimap, so it moves with it) and is sized for a 198 px map, so a resize
-- scales the border art by the same factor. Its mask and border are set by
-- MinimapCluster:UpdateMinimapConfig() (Blizzard_Minimap/Camelot/Minimap.lua),
-- which runs again when the "rotate minimap" CVar changes; a hook re-applies
-- farm mode's look after it.

local addonName, ns = ...

-- Forever's round mask, the same atlas for both rotate modes.
local ROUND_MASK = "ui-hud-minimap-frame-generic-mask"
local SQUARE_MASK = "Interface\\Buttons\\WHITE8X8"

-- Children of Minimap anchored by offsets from its centre, sized for 198 px.
local ZOOM_KEYS = { "ZoomIn", "ZoomOut", "ZoomHitArea" }

-- Buttons around the minimap that "Hide minimap buttons" hides. Paths, since
-- Blizzard keeps most of them as child keys. A missing one resolves to nil.
local BUTTONS = {
    "MinimapCluster.ZoneTextButton",
    "MinimapCluster.Tracking",
    "GameTimeFrame",
    "AddonCompartmentFrame",
    "ExpansionLandingPageMinimapButton",
    "MinimapBackdrop.ExternalEventURLButton",
}

-- Tracking spells as Blizzard's tracking menu lists them (Minimap.lua's
-- TRACKING_SPELL_OVERRIDE_ATLAS): ranks 1 and 2 of each.
local HERB_SPELLS = { [2383] = true, [8387] = true }
local ORE_SPELLS = { [2580] = true, [8388] = true }

ns.defaults = {
    -- the map
    size = 400,             -- the minimap's own width and height, in pixels
    shape = "ROUND",        -- "ROUND" or "SQUARE"
    zoom = 0,
    opacity = 100,          -- percent
    border = true,
    x = 0,                  -- centre offset from the screen centre, UIParent units
    y = 150,
    -- behaviour
    draggable = true,
    hideButtons = false,
    clickThrough = true,    -- clicks reach the world; hold Alt to use the map
    coords = true,          -- x, y under the map
    rotate = false,         -- turn on Blizzard's Rotate Minimap while farming
    -- combat
    combatMode = "CLOSE",   -- "CLOSE", "FADE" or "STAY"
    combatReopen = true,    -- Close: bring farm mode back when combat ends
    combatOpacity = 20,     -- Fade: percent
    -- automatic
    remember = true,        -- farm mode comes back after /reload and login
    autoMount = false,      -- mounting up turns it on
    offInstance = true,     -- hidden in dungeons, raids, battlegrounds
    offResting = false,     -- hidden in cities and inns
    -- tracking
    swapTracking = false,   -- alternate Find Herbs and Find Minerals
    swapInterval = 5,       -- seconds
}

local db
local farming = false       -- the big map is on screen
local wanted = false        -- the player wants farm mode (see the top)
local forced = false        -- turned on by hand inside a city or dungeon: ignore that block
local inCombat = false
local faded = false         -- Fade mode: the map is at combat opacity
local snapshot              -- the minimap as it was before farm mode
local maskChanged = false   -- farm mode set the square mask
local hidden = {}           -- frames farm mode hid; only these are shown again
local savedDrag             -- Minimap's own drag scripts, put back by DisableDrag
local savedRotate           -- the rotateMinimap CVar before farm mode changed it
local squareBorder, coordFrame
local coordTicker, swapTicker
local applying = false      -- guards the UpdateMinimapConfig hook
local wasMounted = false
local lastPlace             -- "instance|resting", to notice moving in or out of one

BINDING_HEADER_FARMMODEFOREVER = "FarmMode Forever"
BINDING_NAME_FARMMODEFOREVER_TOGGLE = "Toggle Farm Mode"

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00b3ffFarmMode:|r " .. msg)
end
ns.Print = Print

local function ResolveFrame(path)
    local f = _G
    for key in path:gmatch("[^.]+") do
        if type(f) ~= "table" then return nil end
        f = f[key]
    end
    return f
end

---- Database

local function InitDB()
    FarmModeForeverDB = FarmModeForeverDB or {}
    db = FarmModeForeverDB
    -- 0.1.0 before its release had a combatClose switch
    if db.combatClose == false and db.combatMode == nil then db.combatMode = "STAY" end
    db.combatClose = nil
    for k, v in pairs(ns.defaults) do
        if db[k] == nil then db[k] = v end
    end
    ns.db = db
end

---- Snapshot

local function TakeSnapshot()
    local s = { points = {}, zoomPoints = {} }
    for i = 1, Minimap:GetNumPoints() do
        s.points[i] = { Minimap:GetPoint(i) }
    end
    s.width, s.height = Minimap:GetSize()
    s.alpha = Minimap:GetAlpha()
    s.zoom = Minimap:GetZoom()
    s.mouse = Minimap:IsMouseEnabled()
    s.wheel = Minimap:IsMouseWheelEnabled()
    s.zoomHitMouse = Minimap.ZoomHitArea and Minimap.ZoomHitArea:IsMouseEnabled()
    s.backdropW, s.backdropH = MinimapBackdrop:GetSize()
    s.compassW, s.compassH = MinimapCompassTexture:GetSize()
    s.compassShown = MinimapCompassTexture:IsShown()
    s.underlayW, s.underlayH = MinimapCompassTextureUnderlay:GetSize()
    s.underlayShown = MinimapCompassTextureUnderlay:IsShown()
    for _, key in ipairs(ZOOM_KEYS) do
        local f = Minimap[key]
        if f and f:GetNumPoints() > 0 then s.zoomPoints[key] = { f:GetPoint(1) } end
    end
    snapshot = s
end

-- Blizzard re-sized the border art (the rotate option changed): take its new
-- sizes as the base the next ApplyLook scales from.
local function RetakeArt()
    snapshot.backdropW, snapshot.backdropH = MinimapBackdrop:GetSize()
    snapshot.compassW, snapshot.compassH = MinimapCompassTexture:GetSize()
    snapshot.underlayW, snapshot.underlayH = MinimapCompassTextureUnderlay:GetSize()
    snapshot.underlayShown = MinimapCompassTextureUnderlay:IsShown()
    maskChanged = false
end

---- Look

-- Changing the zoom is also what makes the minimap redraw after a resize or a
-- mask change, so step away and back.
local function SetZoom(level)
    local max = (Minimap:GetZoomLevels() or 6) - 1
    level = math.max(0, math.min(max, level))
    Minimap:SetZoom(level > 0 and level - 1 or level + 1)
    Minimap:SetZoom(level)
end

local function SquareBorder()
    if not squareBorder then
        squareBorder = CreateFrame("Frame", nil, Minimap)
        squareBorder:SetAllPoints()
        squareBorder:SetFrameLevel(Minimap:GetFrameLevel() + 5)
        -- A 2 px black frame just outside the map's edge.
        local B = 2
        local function Edge(p1, rel1, x1, y1, p2, rel2, x2, y2)
            local t = squareBorder:CreateTexture(nil, "OVERLAY")
            t:SetColorTexture(0, 0, 0, 1)
            t:SetPoint(p1, squareBorder, rel1, x1, y1)
            t:SetPoint(p2, squareBorder, rel2, x2, y2)
        end
        Edge("BOTTOMLEFT", "TOPLEFT", -B, 0, "TOPRIGHT", "TOPRIGHT", B, B)            -- top
        Edge("TOPLEFT", "BOTTOMLEFT", -B, 0, "BOTTOMRIGHT", "BOTTOMRIGHT", B, -B)     -- bottom
        Edge("TOPRIGHT", "TOPLEFT", 0, 0, "BOTTOMLEFT", "BOTTOMLEFT", -B, 0)          -- left
        Edge("TOPLEFT", "TOPRIGHT", 0, 0, "BOTTOMRIGHT", "BOTTOMRIGHT", B, 0)         -- right
    end
    return squareBorder
end

local function ScaleZoomButtons(k)
    for key, p in pairs(snapshot.zoomPoints) do
        local f = Minimap[key]
        f:ClearAllPoints()
        f:SetPoint(p[1], p[2], p[3], (p[4] or 0) * k, (p[5] or 0) * k)
    end
end

local function MapAlpha()
    return (faded and db.combatOpacity or db.opacity) / 100
end

local function ApplyLook()
    applying = true
    local k = db.size / snapshot.width
    Minimap:SetSize(db.size, db.size)
    MinimapBackdrop:SetSize(snapshot.backdropW * k, snapshot.backdropH * k)
    ScaleZoomButtons(k)

    if db.shape == "SQUARE" then
        Minimap:SetMaskTexture(SQUARE_MASK)
        maskChanged = true
        MinimapCompassTexture:Hide()
        MinimapCompassTextureUnderlay:Hide()
        SquareBorder():SetShown(db.border)
    else
        if maskChanged then
            Minimap:SetMaskTexture(ROUND_MASK)
            maskChanged = false
        end
        MinimapCompassTexture:SetSize(snapshot.compassW * k, snapshot.compassH * k)
        MinimapCompassTexture:SetShown(db.border and snapshot.compassShown)
        MinimapCompassTextureUnderlay:SetSize(snapshot.underlayW * k, snapshot.underlayH * k)
        MinimapCompassTextureUnderlay:SetShown(db.border and snapshot.underlayShown)
        if squareBorder then squareBorder:Hide() end
    end

    Minimap:SetAlpha(MapAlpha())
    SetZoom(db.zoom)
    applying = false
end

local function RestoreLook()
    applying = true
    if maskChanged then
        Minimap:SetMaskTexture(ROUND_MASK)
        maskChanged = false
    end
    if squareBorder then squareBorder:Hide() end
    Minimap:SetSize(snapshot.width, snapshot.height)
    MinimapBackdrop:SetSize(snapshot.backdropW, snapshot.backdropH)
    MinimapCompassTexture:SetSize(snapshot.compassW, snapshot.compassH)
    MinimapCompassTexture:SetShown(snapshot.compassShown)
    MinimapCompassTextureUnderlay:SetSize(snapshot.underlayW, snapshot.underlayH)
    MinimapCompassTextureUnderlay:SetShown(snapshot.underlayShown)
    ScaleZoomButtons(1)
    Minimap:SetAlpha(snapshot.alpha)
    SetZoom(snapshot.zoom)
    applying = false
end

-- Rotate Minimap is a CVar Blizzard's look follows (the hook above re-applies
-- ours). Farm mode turns it on and puts the old value back, at logout too.
local function ApplyRotate()
    local want = farming and db.rotate
    if want and not savedRotate then
        savedRotate = GetCVar("rotateMinimap")
        if savedRotate == "1" then savedRotate = nil else SetCVar("rotateMinimap", "1") end
    elseif not want and savedRotate then
        SetCVar("rotateMinimap", savedRotate)
        savedRotate = nil
    end
end

---- Position

-- db.x/db.y are in UIParent units; SetPoint offsets are in Minimap's own scale,
-- which includes the Edit Mode minimap size.
local function Place()
    local k = UIParent:GetEffectiveScale() / Minimap:GetEffectiveScale()
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", UIParent, "CENTER", db.x * k, db.y * k)
end

local function RestorePosition()
    Minimap:ClearAllPoints()
    for _, p in ipairs(snapshot.points) do
        Minimap:SetPoint(unpack(p))
    end
end

---- Dragging
--
-- Driven by a frame of our own: Blizzard uses Minimap's OnUpdate for its
-- mouseover tooltip, so taking it over would break that.

local mover = CreateFrame("Frame")
mover:Hide()
local grabX, grabY
local OnDragStop
local ApplyMouse    -- defined under Click-through; a drag ending updates it

local function CursorInUI()
    local cx, cy = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return cx / s, cy / s
end

mover:SetScript("OnUpdate", function()
    -- With click-through, letting go of Alt mid-drag can swallow OnDragStop.
    if not IsMouseButtonDown("LeftButton") then OnDragStop() return end
    local cx, cy = CursorInUI()
    db.x, db.y = cx - grabX, cy - grabY
    Place()
end)

local function OnDragStart()
    local cx, cy = CursorInUI()
    grabX, grabY = cx - db.x, cy - db.y
    mover:Show()
end

OnDragStop = function()
    if not mover:IsShown() then return end
    mover:Hide()
    db.x, db.y = math.floor(db.x + 0.5), math.floor(db.y + 0.5)
    Place()
    ApplyMouse()
    if ns.OnSettingsChanged then ns.OnSettingsChanged() end
end

local function EnableDrag()
    if savedDrag then return end
    savedDrag = {
        OnDragStart = Minimap:GetScript("OnDragStart"),
        OnDragStop = Minimap:GetScript("OnDragStop"),
    }
    Minimap:RegisterForDrag("LeftButton")
    Minimap:SetScript("OnDragStart", OnDragStart)
    Minimap:SetScript("OnDragStop", OnDragStop)
end

local function DisableDrag()
    mover:Hide()
    if not savedDrag then return end
    Minimap:RegisterForDrag()
    Minimap:SetScript("OnDragStart", savedDrag.OnDragStart)
    Minimap:SetScript("OnDragStop", savedDrag.OnDragStop)
    savedDrag = nil
end

---- Click-through
--
-- A 400 px map in the middle of the screen catches clicks meant for the world
-- (a herb, a mob). With this on it takes the mouse only while Alt is held.

ApplyMouse = function()
    local on
    if farming and db.clickThrough then
        on = IsAltKeyDown() or mover:IsShown()
        Minimap:EnableMouse(on)
        Minimap:EnableMouseWheel(on)
        if Minimap.ZoomHitArea then Minimap.ZoomHitArea:EnableMouse(on) end
    elseif snapshot then
        Minimap:EnableMouse(snapshot.mouse)
        Minimap:EnableMouseWheel(snapshot.wheel)
        if Minimap.ZoomHitArea then Minimap.ZoomHitArea:EnableMouse(snapshot.zoomHitMouse) end
    end
end

---- Minimap buttons

local function HideOne(f)
    if type(f) == "table" and f.IsShown and f:IsShown() then
        f:Hide()
        hidden[f] = true
    end
end

local function HideButtons()
    for _, path in ipairs(BUTTONS) do
        HideOne(ResolveFrame(path))
    end
    -- Other addons' minimap buttons (LibDBIcon) are children of Minimap and
    -- would sit at the old radius inside the big map.
    for _, child in ipairs({ Minimap:GetChildren() }) do
        local name = child:GetName()
        if name and name:find("^LibDBIcon10_") then HideOne(child) end
    end
    Minimap.ZoomIn:Hide()
    Minimap.ZoomOut:Hide()
end

-- Show only what HideButtons hid: a button the player or another addon had
-- hidden stays hidden.
local function ShowButtons()
    for f in pairs(hidden) do f:Show() end
    wipe(hidden)
end

---- Coordinates

local function UpdateCoords()
    local text = coordFrame.text
    local map = C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition(map, "player")
    if not pos then text:SetText("") return end    -- instances have no map position
    local x, y = pos:GetXY()
    if not (canaccessvalue(x) and canaccessvalue(y)) or (x == 0 and y == 0) then
        text:SetText("")
        return
    end
    text:SetFormattedText("%.1f, %.1f", x * 100, y * 100)
end

local function ApplyCoords()
    local on = farming and db.coords
    if on and not coordFrame then
        coordFrame = CreateFrame("Frame", nil, Minimap)
        coordFrame:SetSize(120, 16)
        coordFrame:SetPoint("TOP", Minimap, "BOTTOM", 0, -6)
        coordFrame:SetFrameLevel(Minimap:GetFrameLevel() + 6)
        coordFrame.text = coordFrame:CreateFontString(nil, "OVERLAY")
        coordFrame.text:SetFont(ns.T.mono, 12, "OUTLINE")
        coordFrame.text:SetTextColor(ns.T.C.primary[1], ns.T.C.primary[2], ns.T.C.primary[3])
        coordFrame.text:SetPoint("CENTER")
    end
    if coordFrame then coordFrame:SetShown(on) end
    if on and not coordTicker then
        UpdateCoords()
        coordTicker = C_Timer.NewTicker(0.2, UpdateCoords)
    elseif not on and coordTicker then
        coordTicker:Cancel()
        coordTicker = nil
    end
end

---- Tracking swap
--
-- Vanilla tracks one resource at a time. Turning one tracking on switches the
-- other off, the way Blizzard's tracking menu does (C_Minimap.SetTracking). It
-- is a spell cast, so it waits while you cast, fight, ride a taxi or are dead.

local function TrackingIndexes()
    local herb, ore, herbOn
    for i = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(i)
        local id = info and info.spellID
        if id and HERB_SPELLS[id] then herb, herbOn = i, info.active
        elseif id and ORE_SPELLS[id] then ore = i end
    end
    return herb, ore, herbOn
end

-- UnitCastingInfo returns no values at all when not casting, and type() with no
-- argument errors: the extra parentheses make it exactly one value (nil). The
-- values may be secret on Forever, so presence is tested with type(), never by
-- truthiness.
local function SwapTracking()
    if InCombatLockdown() or UnitIsDeadOrGhost("player") or UnitOnTaxi("player")
        or type((UnitCastingInfo("player"))) ~= "nil" or type((UnitChannelInfo("player"))) ~= "nil" then
        return
    end
    local herb, ore, herbOn = TrackingIndexes()
    if not (herb and ore) then return end   -- needs both Herbalism and Mining
    C_Minimap.SetTracking(herbOn and ore or herb, true)
end

local function ApplySwap(restart)
    local on = farming and db.swapTracking
    if swapTicker and (restart or not on) then
        swapTicker:Cancel()
        swapTicker = nil
    end
    if on and not swapTicker then
        swapTicker = C_Timer.NewTicker(db.swapInterval, SwapTracking)
    end
end

---- On and off (the mechanics; Reconcile decides when)

local function FarmOn()
    TakeSnapshot()
    farming = true
    ApplyLook()
    Place()
    ApplyRotate()
    if db.draggable then EnableDrag() end
    if db.hideButtons then HideButtons() end
    ApplyMouse()
    ApplyCoords()
    ApplySwap()
end

local function FarmOff()
    DisableDrag()
    ShowButtons()
    RestoreLook()
    RestorePosition()
    farming = false
    ApplyMouse()
    ApplyRotate()   -- after farming=false, so Blizzard's own look comes back untouched
    ApplyCoords()
    ApplySwap()
end

-- Why farm mode should not show right now, or nil
local function Blocked()
    if inCombat and db.combatMode == "CLOSE" then return "combat" end
    if forced then return nil end
    if db.offInstance and IsInInstance() then return "instance" end
    if db.offResting and IsResting() then return "resting" end
    return nil
end

local function Reconcile()
    local show = wanted and not Blocked()
    if show == farming then return end
    -- Only the moment before lockdown (PLAYER_REGEN_DISABLED) is known to be
    -- safe for moving the minimap; anything else waits for combat to end.
    if InCombatLockdown() then return end
    if show then FarmOn() else FarmOff() end
end

function ns.IsFarming() return farming end

-- Apply changed settings
function ns.Refresh()
    Reconcile()
    if not farming then return end
    ApplyLook()
    Place()
    ApplyRotate()
    if db.draggable then EnableDrag() else DisableDrag() end
    if db.hideButtons then HideButtons() else ShowButtons() end
    ApplyMouse()
    ApplyCoords()
    ApplySwap(true)
end

function ns.Toggle()
    if InCombatLockdown() then
        -- Nothing moves until combat ends, so flip the intent: a second press
        -- cancels the first.
        wanted = not wanted
        if wanted then forced = true end
        if wanted == farming then
            Print(wanted and "On." or "Off.")
        else
            Print(wanted and "Will switch on when combat ends." or "Will switch off when combat ends.")
        end
        return
    end
    if farming then
        wanted = false
    else
        wanted, forced = true, true     -- by hand: show it even in a city or dungeon
    end
    Reconcile()
    if farming then
        Print("On." .. (db.clickThrough and " Hold Alt to drag or click the map." or ""))
    else
        Print("Off.")
    end
end

function FarmModeForever_Toggle()
    ns.Toggle()
end

function FarmModeForever_OnCompartmentClick(_, button)
    if button == "RightButton" then ns.OpenOptions() else ns.Toggle() end
end

---- Events

local frame = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT",
                     "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "MODIFIER_STATE_CHANGED",
                     "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_UPDATE_RESTING", "ZONE_CHANGED_NEW_AREA" }) do
    frame:RegisterEvent(e)
end

-- Moving into or out of a city or dungeon ends a by-hand override.
local function PlaceChanged()
    local key = tostring(IsInInstance() and true) .. "|" .. tostring(IsResting() and true)
    if key ~= lastPlace then
        lastPlace = key
        forced = false
        Reconcile()
    end
end

frame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        self:UnregisterEvent("ADDON_LOADED")
        InitDB()
        ns.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
        ns.website = C_AddOns.GetAddOnMetadata(addonName, "X-Website")
        wanted = db.remember and db.wanted or false
        ns.CreateOptions()

    elseif event == "PLAYER_LOGIN" then
        -- Blizzard re-applies its minimap look when "rotate minimap" changes.
        if MinimapCluster and MinimapCluster.UpdateMinimapConfig then
            hooksecurefunc(MinimapCluster, "UpdateMinimapConfig", function()
                if farming and not applying then
                    RetakeArt()
                    ApplyLook()
                end
            end)
        end
        -- Blizzard shows the zoom buttons on mouseover.
        Minimap:HookScript("OnEnter", function(map)
            if farming and db.hideButtons then
                map.ZoomIn:Hide()
                map.ZoomOut:Hide()
            end
        end)
        wasMounted = IsMounted()
        if C_AddOns.IsAddOnLoaded("FarmMode") then
            Print("the classic FarmMode is also enabled. Both use /farm and move the minimap: disable one of them.")
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        local isLogin, isReload = arg1, arg2
        if isLogin or isReload then
            -- Let Blizzard finish laying out the minimap before snapshotting it.
            C_Timer.After(1, function()
                lastPlace = nil
                PlaceChanged()
            end)
        else
            PlaceChanged()
        end

    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_UPDATE_RESTING" then
        PlaceChanged()

    elseif event == "PLAYER_LOGOUT" then
        db.wanted = wanted
        if savedRotate then SetCVar("rotateMinimap", savedRotate) end

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Fires just before combat lockdown, so the minimap can still move.
        inCombat = true
        if farming and db.combatMode == "CLOSE" and not db.combatReopen then wanted = false end
        if farming and db.combatMode == "FADE" then
            faded = true
            Minimap:SetAlpha(MapAlpha())
        end
        Reconcile()

    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        if faded then
            faded = false
            if farming then Minimap:SetAlpha(MapAlpha()) end
        end
        Reconcile()

    elseif event == "MODIFIER_STATE_CHANGED" then
        if farming and db.clickThrough then ApplyMouse() end

    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        local mounted = IsMounted()
        if db.autoMount and mounted and not wasMounted and not wanted then
            wanted = true
            Reconcile()
        end
        wasMounted = mounted
    end
end)

---- Slash command

SLASH_FARMMODEFOREVER1 = "/farm"
SlashCmdList.FARMMODEFOREVER = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "config" or msg == "options" or msg == "settings" then
        ns.OpenOptions()
    elseif msg == "square" or msg == "round" then
        db.shape = msg:upper()
        ns.Refresh()
        if ns.OnSettingsChanged then ns.OnSettingsChanged() end
        Print("Shape: " .. msg .. ".")
    elseif msg == "help" then
        Print("version " .. (ns.version or "?") .. (ns.website and ("  ·  help and bug reports: " .. ns.website) or ""))
        Print("/farm toggles farm mode. /farm config opens the options. /farm square, /farm round change the shape.")
    else
        ns.Toggle()
    end
end
