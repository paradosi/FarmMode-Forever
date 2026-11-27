---- Options — the settings panel (Esc > Options > AddOns > FarmMode Forever)
--
-- wowdb.dev's look, shared with Forever Alts and Nightclaw Ears (Theme.lua): a
-- navy panel, Oswald capitals for labels, JetBrains Mono for numbers, gold for
-- whatever is active. Every control writes its setting and calls ns.Refresh(),
-- so a change shows on the minimap at once while farm mode is on.
--
-- Widths are fixed rather than measured: a custom font may not be loaded yet
-- when the panel is built, and then strings measure ~0 wide.

local _, ns = ...
local T = ns.T
local C = T.C

local COL_W = 260       -- one column of controls
local category
local panel
local host     -- the scrolling content frame the widgets are made in

local function Upper(s) return s:upper() end

-- Section header: small gold capitals over a hairline
local function Section(anchor, yOff, label, width)
    local text = T.Text(host, T.display, 11, C.accent)
    text:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
    text:SetText(Upper(label))
    local line = T.Line(host, C.divider)
    line:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -5)
    line:SetWidth(width or COL_W)
    return line
end

-- Slider: LABEL on the left, the value (editable, mono) on the right, and a
-- 3 px gold track below that fills up to the thumb. Mouse wheel steps it.
local function MakeSlider(anchor, yOff, label, minVal, maxVal, step, wheelStep, suffix)
    local row = CreateFrame("Frame", nil, host)
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
    row:SetSize(COL_W, 38)

    local name = T.Text(row, T.display, 11, C.secondary)
    name:SetPoint("TOPLEFT", 0, 0)
    name:SetText(Upper(label))

    local unit = T.Text(row, T.mono, 10, C.muted, "LEFT")
    unit:SetPoint("TOPRIGHT", 0, -1)
    unit:SetWidth(suffix and 18 or 0.01)
    unit:SetText(suffix or "")

    local eb = CreateFrame("EditBox", nil, row)
    eb:SetPoint("RIGHT", unit, "LEFT", -2, 0)
    eb:SetSize(48, 16)
    eb:SetFont(T.mono, 11, "")
    eb:SetTextColor(C.primary[1], C.primary[2], C.primary[3])
    eb:SetJustifyH("RIGHT")
    eb:SetAutoFocus(false)
    eb:SetTextInsets(0, 3, 0, 0)
    local ebBg = eb:CreateTexture(nil, "BACKGROUND")
    ebBg:SetAllPoints()
    T.Fill(ebBg, C.raised)
    ebBg:Hide()     -- only while typing

    local s = CreateFrame("Slider", nil, row)
    s:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
    s:SetSize(COL_W, 14)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(minVal, maxVal)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true)

    local track = s:CreateTexture(nil, "BACKGROUND")
    T.Fill(track, C.track)
    track:SetHeight(3)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")

    s:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local thumb = s:GetThumbTexture()
    thumb:SetVertexColor(C.accentHi[1], C.accentHi[2], C.accentHi[3], 1)
    thumb:SetSize(4, 12)

    local fill = s:CreateTexture(nil, "ARTWORK")
    T.Fill(fill, C.accent)
    fill:SetHeight(3)
    fill:SetPoint("LEFT", track, "LEFT")
    fill:SetPoint("RIGHT", thumb, "CENTER")     -- follows the thumb by itself

    local function Round(v) return math.floor(v / step + 0.5) * step end
    local function Show(v)
        if not eb:HasFocus() then eb:SetText(Round(v)) end
    end

    local quiet = false -- SetValue from code: show it, don't write it back
    s:SetScript("OnValueChanged", function(_, v)
        v = Round(v)
        Show(v)
        if not quiet and row.onChange then row.onChange(v) end
    end)
    s:SetScript("OnMouseWheel", function(self, delta)
        local v = self:GetValue() + delta * (wheelStep or step)
        self:SetValue(math.max(minVal, math.min(maxVal, v)))
    end)
    s:SetScript("OnEnter", function()
        thumb:SetVertexColor(1, 0.95, 0.82, 1)
        name:SetTextColor(C.primary[1], C.primary[2], C.primary[3])
    end)
    s:SetScript("OnLeave", function()
        thumb:SetVertexColor(C.accentHi[1], C.accentHi[2], C.accentHi[3], 1)
        name:SetTextColor(C.secondary[1], C.secondary[2], C.secondary[3])
    end)

    eb:SetScript("OnEditFocusGained", function(self)
        ebBg:Show()
        self:HighlightText()
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        ebBg:Hide()
        self:SetText(Round(s:GetValue()))
    end)
    eb:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v then s:SetValue(Round(math.max(minVal, math.min(maxVal, v)))) end
        self:ClearFocus()
    end)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)

    function row:SetEnabledLook(on)
        self:SetAlpha(on and 1 or 0.4)
    end

    function row:SetValue(v)
        quiet = true
        s:SetValue(v)
        eb:SetText(Round(v))
        quiet = false
    end
    return row
end

-- Checkbox: a hairline box that fills gold when on, label beside it. The whole
-- row is clickable.
local function MakeCheck(anchor, yOff, label)
    local btn = CreateFrame("Button", nil, host)
    btn:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
    btn:SetSize(COL_W, 18)

    local box = CreateFrame("Frame", nil, btn)
    box:SetSize(14, 14)
    box:SetPoint("LEFT")
    local boxBg = box:CreateTexture(nil, "BACKGROUND")
    boxBg:SetAllPoints()
    T.Fill(boxBg, C.raised)
    T.Border(box)
    local mark = box:CreateTexture(nil, "ARTWORK")
    mark:SetPoint("TOPLEFT", 3, -3)
    mark:SetPoint("BOTTOMRIGHT", -3, 3)
    T.Fill(mark, C.accent)

    local text = T.Text(btn, T.display, 12, C.secondary)
    text:SetPoint("LEFT", box, "RIGHT", 9, 0)
    text:SetText(label)
    btn.label = text

    function btn:SetChecked(v)
        self.checked = v and true or false
        mark:SetShown(self.checked)
    end
    btn:SetChecked(false)
    btn:SetScript("OnClick", function(self)
        self:SetChecked(not self.checked)
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        if self.onChange then self.onChange(self.checked) end
    end)
    btn:SetScript("OnEnter", function() text:SetTextColor(C.primary[1], C.primary[2], C.primary[3]) end)
    btn:SetScript("OnLeave", function() text:SetTextColor(C.secondary[1], C.secondary[2], C.secondary[3]) end)
    function btn:SetEnabledLook(on)
        self:SetAlpha(on and 1 or 0.4)
    end
    return btn
end

-- A bordered text button; `selected` paints it gold (the shape switch)
local function MakeButton(label, width)
    local b = CreateFrame("Button", nil, host)
    b:SetSize(width, 24)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    T.Border(b)
    local text = T.Text(b, T.display, 11, C.muted, "CENTER")
    text:SetPoint("CENTER")
    text:SetText(Upper(label))

    local function Paint(hover)
        if b.selected then
            T.Fill(bg, C.chip)
            text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
        else
            T.Fill(bg, hover and C.raised or { 0, 0, 0, 0 })
            local c = hover and C.primary or C.muted
            text:SetTextColor(c[1], c[2], c[3])
        end
    end
    function b:SetSelected(on)
        self.selected = on
        Paint(self:IsMouseOver())
    end
    b:SetScript("OnEnter", function() Paint(true) end)
    b:SetScript("OnLeave", function() Paint(false) end)
    T.HoverGlow(b)
    Paint(false)
    return b
end

-- A row of buttons, one of them chosen: { {value, label}, ... }
local function MakeSegment(anchor, yOff, choices, onSelect)
    local seg = { buttons = {} }
    local w = (COL_W - 8 * (#choices - 1)) / #choices
    for i, c in ipairs(choices) do
        local b = MakeButton(c[2], w)
        if i == 1 then
            b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
        else
            b:SetPoint("LEFT", seg.buttons[i - 1], "RIGHT", 8, 0)
        end
        b:SetScript("OnClick", function()
            seg:Set(c[1])
            PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
            onSelect(c[1])
        end)
        b.value = c[1]
        seg.buttons[i] = b
    end
    function seg:Set(value)
        for _, b in ipairs(self.buttons) do b:SetSelected(b.value == value) end
    end
    seg.first = seg.buttons[1]
    return seg
end

-- A muted line of explanation under a control
local function Note(anchor, yOff, text)
    local fs = T.Text(host, T.mono, 9, C.muted)
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
    fs:SetText(text)
    return fs
end

function ns.CreateOptions()
    local db = ns.db
    panel = CreateFrame("Frame", "FarmModeForeverOptions", UIParent)
    panel.name = "FarmMode Forever"
    panel:Hide()

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    T.Fill(bg, C.bg)

    ---- Header (fixed): logo, name, version chip, gold line

    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetSize(40, 40)
    logo:SetPoint("TOPLEFT", 18, -16)
    logo:SetTexture("Interface\\AddOns\\FarmModeForever\\media\\textures\\logo")

    local title = T.Text(panel, T.display, 20, C.primary)
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -1)
    title:SetText("FARMMODE FOREVER")

    local version = T.Chip(panel)
    version:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -26, -24)
    version:SetText("V" .. ns.version)

    local sub = T.Text(panel, T.mono, 10, C.muted)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetText("the minimap as a gathering map  ·  changes apply live")

    T.GoldLine(panel, -70)

    ---- Scrolling body
    --
    -- Blizzard's options window leaves an addon about 650 x 600; this panel is
    -- taller. The mouse wheel scrolls it (over a slider it moves the slider),
    -- and a thin gold bar on the right shows where you are.

    local scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", 0, -72)
    scroll:SetPoint("BOTTOMRIGHT", -12, 4)
    host = CreateFrame("Frame", nil, scroll)
    host:SetSize(COL_W * 2 + 80, 700)
    scroll:SetScrollChild(host)

    local barTrack = panel:CreateTexture(nil, "ARTWORK")
    T.Fill(barTrack, C.divider)
    barTrack:SetWidth(2)
    barTrack:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -80)
    barTrack:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 10)
    local barThumb = panel:CreateTexture(nil, "OVERLAY")
    T.Fill(barThumb, C.accent)
    barThumb:SetWidth(2)

    local function UpdateBar()
        local range = scroll:GetVerticalScrollRange()
        local shown = range > 1
        barTrack:SetShown(shown)
        barThumb:SetShown(shown)
        if not shown then return end
        local trackH = barTrack:GetHeight()
        local view = scroll:GetHeight()
        local thumbH = math.max(24, trackH * view / (view + range))
        barThumb:SetHeight(thumbH)
        local y = (trackH - thumbH) * scroll:GetVerticalScroll() / range
        barThumb:ClearAllPoints()
        barThumb:SetPoint("TOP", barTrack, "TOP", 0, -y)
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40)))
        UpdateBar()
    end)
    scroll:SetScript("OnScrollRangeChanged", UpdateBar)
    scroll:SetScript("OnSizeChanged", function(self, w)
        host:SetWidth(math.max(w, COL_W * 2 + 80))
        UpdateBar()
    end)

    local function ColumnTop(x)
        local f = CreateFrame("Frame", nil, host)
        f:SetSize(1, 1)
        f:SetPoint("TOPLEFT", host, "TOPLEFT", x, -8)
        return f
    end
    local left, right = ColumnTop(18), ColumnTop(18 + COL_W + 40)

    local function Set(key)
        return function(v)
            db[key] = v
            ns.Refresh()
        end
    end

    ---- Left column: the map, where it sits, when it turns on by itself

    local map = Section(left, 0, "Map")
    local size = MakeSlider(map, -12, "Size", 140, 700, 10, 20, "px")
    size.onChange = Set("size")
    local zoom = MakeSlider(size, -10, "Zoom", 0, 5, 1, 1)
    zoom.onChange = Set("zoom")
    local opacity = MakeSlider(zoom, -10, "Opacity", 30, 100, 1, 5, "%")
    opacity.onChange = Set("opacity")

    local pos = Section(opacity, -18, "Position")
    local xOff = MakeSlider(pos, -12, "Left / Right", -900, 900, 1, 10)
    xOff.onChange = Set("x")
    local yOff = MakeSlider(xOff, -10, "Down / Up", -600, 600, 1, 10)
    yOff.onChange = Set("y")

    local auto = Section(yOff, -18, "Automatic")
    local remember = MakeCheck(auto, -10, "Remember it across reloads and logins")
    remember.onChange = Set("remember")
    local autoMount = MakeCheck(remember, -6, "Turn on when you mount up")
    autoMount.onChange = Set("autoMount")
    local offInstance = MakeCheck(autoMount, -6, "Hide in dungeons and battlegrounds")
    offInstance.onChange = Set("offInstance")
    local offResting = MakeCheck(offInstance, -6, "Hide in cities and inns")
    offResting.onChange = Set("offResting")
    Note(offResting, -6, "/farm still opens it there, until you leave")

    ---- Right column: shape, the map's behaviour, combat, tracking

    local shapeSec = Section(right, 0, "Shape")
    local shape = MakeSegment(shapeSec, -12, { { "ROUND", "Round" }, { "SQUARE", "Square" } }, Set("shape"))
    local border = MakeCheck(shape.first, -12, "Show the border")
    border.onChange = Set("border")

    local onMap = Section(border, -18, "On the map")
    local drag = MakeCheck(onMap, -10, "Drag the map to move it")
    drag.onChange = Set("draggable")
    local through = MakeCheck(drag, -6, "Clicks go through (hold Alt to use it)")
    through.onChange = Set("clickThrough")
    local buttons = MakeCheck(through, -6, "Hide minimap buttons")
    buttons.onChange = Set("hideButtons")
    local coords = MakeCheck(buttons, -6, "Show coordinates")
    coords.onChange = Set("coords")
    local rotate = MakeCheck(coords, -6, "Rotate the map as you turn")
    rotate.onChange = Set("rotate")

    local mini = MakeCheck(rotate, -6, "Show the minimap button")
    mini.onChange = function(v)
        db.minimap = v
        if ns.minimapButton then ns.minimapButton:Update() end
    end
    local miniNote = Note(mini, -4, "left: farm mode  ·  right: this  ·  drag: move it")

    local combatSec = Section(miniNote, -18, "In combat")
    local reopen, combatAlpha
    local function CombatLooks(mode)
        reopen:SetEnabledLook(mode == "CLOSE")
        combatAlpha:SetEnabledLook(mode == "FADE")
    end
    local combat = MakeSegment(combatSec, -12, { { "CLOSE", "Close" }, { "FADE", "Fade" }, { "STAY", "Stay" } },
        function(v)
            db.combatMode = v
            CombatLooks(v)
            ns.Refresh()
        end)
    reopen = MakeCheck(combat.first, -12, "Open it again when combat ends")
    reopen.onChange = Set("combatReopen")
    combatAlpha = MakeSlider(reopen, -10, "Opacity in combat", 0, 80, 5, 5, "%")
    combatAlpha.onChange = Set("combatOpacity")

    local trackSec = Section(combatAlpha, -18, "Tracking")
    local swap = MakeCheck(trackSec, -10, "Alternate herb and ore tracking")
    local interval = MakeSlider(swap, -10, "Every", 3, 15, 1, 1, "s")
    swap.onChange = function(v)
        db.swapTracking = v
        interval:SetEnabledLook(v)
        ns.Refresh()
    end
    interval.onChange = Set("swapInterval")
    local swapNote = Note(interval, -4, "needs Herbalism and Mining; waits while you cast or fight")

    ---- Footer, under the taller (right) column

    local foot = T.Line(host, C.divider)
    foot:SetPoint("TOP", swapNote, "BOTTOM", 0, -16)
    foot:SetPoint("LEFT", host, "LEFT", 18, 0)
    foot:SetWidth(COL_W * 2 + 40)

    local reset = MakeButton("Reset defaults", 130)
    reset:SetPoint("TOPLEFT", foot, "BOTTOMLEFT", 0, -12)

    -- Addons can't open a browser: the link opens selected, for Ctrl+C
    -- (W.CopyDialog, from the shared Widgets.lua)
    local help = MakeButton("Help and bug reports", 180)
    help:SetPoint("LEFT", reset, "RIGHT", 10, 0)
    help:SetScript("OnClick", function()
        if ns.website then ns.W.CopyDialog("Help and bug reports", ns.website) end
    end)
    help:SetShown(ns.website ~= nil)

    local hint = T.Text(host, T.mono, 10, C.muted)
    hint:SetPoint("TOPLEFT", reset, "BOTTOMLEFT", 0, -10)
    hint:SetText("/farm toggles  ·  right-click the addon menu entry for this")

    local function Sync()
        size:SetValue(db.size)
        zoom:SetValue(db.zoom)
        opacity:SetValue(db.opacity)
        xOff:SetValue(db.x)
        yOff:SetValue(db.y)
        remember:SetChecked(db.remember)
        autoMount:SetChecked(db.autoMount)
        offInstance:SetChecked(db.offInstance)
        offResting:SetChecked(db.offResting)
        shape:Set(db.shape)
        border:SetChecked(db.border)
        drag:SetChecked(db.draggable)
        through:SetChecked(db.clickThrough)
        buttons:SetChecked(db.hideButtons)
        coords:SetChecked(db.coords)
        rotate:SetChecked(db.rotate)
        mini:SetChecked(db.minimap)
        combat:Set(db.combatMode)
        reopen:SetChecked(db.combatReopen)
        combatAlpha:SetValue(db.combatOpacity)
        CombatLooks(db.combatMode)
        swap:SetChecked(db.swapTracking)
        interval:SetValue(db.swapInterval)
        interval:SetEnabledLook(db.swapTracking)
    end
    panel:SetScript("OnShow", function()
        Sync()
        -- Size the scroll area to what is actually there (fonts are loaded by now).
        local top, bottom = host:GetTop(), hint:GetBottom()
        if top and bottom then host:SetHeight(top - bottom + 20) end
        UpdateBar()
    end)
    ns.OnSettingsChanged = function()
        if panel:IsShown() then Sync() end
    end

    reset:SetScript("OnClick", function()
        for k, v in pairs(ns.defaults) do db[k] = v end
        Sync()
        ns.Refresh()
        ns.Print("Settings reset to defaults.")
    end)

    category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
end

function ns.OpenOptions()
    if category then Settings.OpenToCategory(category:GetID()) end
end
