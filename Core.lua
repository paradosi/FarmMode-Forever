---- Core — FarmMode Forever: the minimap as a big gathering map, and back again
--
-- Written for WoW Forever only (16001, Retail 12's minimap). The classic
-- FarmMode runs on four clients and scales the minimap; this one RESIZES it, so
-- the map shows more ground while node and quest icons stay their normal size,
-- and adds a square shape, a border toggle and closing during combat.
--
-- Everything farm mode changes is snapshotted first and put back exactly when
-- it switches off. Blizzard's minimap art lives in MinimapBackdrop (a child of
-- Minimap, so it moves with it) and is sized for a 198 px map, so a resize
-- scales the border art by the same factor. Its mask and border are set by
-- MinimapCluster:UpdateMinimapConfig() (Blizzard_Minimap/Camelot/Minimap.lua),
-- which runs again when the "rotate minimap" option changes; a hook re-applies
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

ns.defaults = {
    size = 400,         -- the minimap's own width and height, in pixels
    shape = "ROUND",    -- "ROUND" or "SQUARE"
    zoom = 0,
    opacity = 100,      -- percent
    border = true,
    x = 0,              -- centre offset from the screen centre, UIParent units
    y = 150,
    draggable = true,
    hideButtons = false,
    combatClose = true,     -- put the minimap back when combat starts
    combatReopen = true,    -- and bring farm mode back when it ends
}

local db
local farming = false
local snapshot              -- the minimap as it was before farm mode
local maskChanged = false   -- farm mode set the square mask
local hidden = {}           -- frames farm mode hid; only these are shown again
local savedDrag             -- Minimap's own drag scripts, put back by DisableDrag
local squareBorder
local closedByCombat = false
local wantAfterCombat       -- nil, or the state the player asked for during combat
local applying = false      -- guards the UpdateMinimapConfig hook

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
    for k, v in pairs(ns.defaults) do
        if db[k] == nil then db[k] = v end
    end
    ns.db = db
end

---- Snapshot and restore

local function TakeSnapshot()
    local s = { points = {}, zoomPoints = {} }
    for i = 1, Minimap:GetNumPoints() do
        s.points[i] = { Minimap:GetPoint(i) }
    end
    s.width, s.height = Minimap:GetSize()
    s.alpha = Minimap:GetAlpha()
    s.zoom = Minimap:GetZoom()
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

    Minimap:SetAlpha(db.opacity / 100)
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

local function CursorInUI()
    local cx, cy = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return cx / s, cy / s
end

mover:SetScript("OnUpdate", function()
    local cx, cy = CursorInUI()
    db.x, db.y = cx - grabX, cy - grabY
    Place()
end)

local function OnDragStart()
    local cx, cy = CursorInUI()
    grabX, grabY = cx - db.x, cy - db.y
    mover:Show()
end

local function OnDragStop()
    if not mover:IsShown() then return end
    mover:Hide()
    db.x, db.y = math.floor(db.x + 0.5), math.floor(db.y + 0.5)
    Place()
    if ns.OnSettingsChanged then ns.OnSettingsChanged() end
    Print(("Position saved (%d, %d)."):format(db.x, db.y))
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

---- On and off

local function FarmOn(quiet)
    if farming then return end
    TakeSnapshot()
    farming = true
    ApplyLook()
    Place()
    if db.draggable then EnableDrag() end
    if db.hideButtons then HideButtons() end
    if not quiet then
        Print("On." .. (db.draggable and " Drag the map to move it." or ""))
    end
end

local function FarmOff(quiet)
    if not farming then return end
    DisableDrag()
    ShowButtons()
    RestoreLook()
    RestorePosition()
    farming = false
    if not quiet then Print("Off.") end
end

function ns.IsFarming() return farming end

-- Apply changed settings while farm mode is on.
function ns.Refresh()
    if not farming then return end
    ApplyLook()
    Place()
    if db.draggable then EnableDrag() else DisableDrag() end
    if db.hideButtons then HideButtons() else ShowButtons() end
end

-- A toggle during combat waits for it to end: farm mode closes for combat by
-- default, and only the moment before lockdown (PLAYER_REGEN_DISABLED) is
-- known to be safe for moving the minimap.
function ns.Toggle()
    if InCombatLockdown() then
        local now = wantAfterCombat
        if now == nil then now = farming or (closedByCombat and db.combatReopen) end
        wantAfterCombat = not now
        Print(wantAfterCombat and "Will switch on when combat ends." or "Will stay off after combat.")
        return
    end
    if farming then FarmOff() else FarmOn() end
end

function FarmModeForever_Toggle()
    ns.Toggle()
end

function FarmModeForever_OnCompartmentClick(_, button)
    if button == "RightButton" then ns.OpenOptions() else ns.Toggle() end
end

---- Events

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        self:UnregisterEvent("ADDON_LOADED")
        InitDB()
        ns.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
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
        if C_AddOns.IsAddOnLoaded("FarmMode") then
            Print("the classic FarmMode is also enabled. Both use /farm and move the minimap: disable one of them.")
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Fires just before combat lockdown, so the minimap can still move.
        if farming and db.combatClose then
            FarmOff(true)
            closedByCombat = true
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        local want, asked = wantAfterCombat, wantAfterCombat ~= nil
        if want == nil and closedByCombat then want = db.combatReopen end
        wantAfterCombat, closedByCombat = nil, false
        if want == true then FarmOn(not asked) elseif want == false then FarmOff(not asked) end
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
        Print("/farm toggles farm mode. /farm config opens the options. /farm square, /farm round change the shape.")
    else
        ns.Toggle()
    end
end
