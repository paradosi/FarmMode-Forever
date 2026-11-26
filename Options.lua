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

local function Upper(s) return s:upper() end

-- Section header: small gold capitals over a hairline
local function Section(anchor, yOff, label, width)
    local text = T.Text(panel, T.display, 11, C.accent)
    text:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
    text:SetText(Upper(label))
    local line = T.Line(panel, C.divider)
    line:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -5)
    line:SetWidth(width or COL_W)
    return line
end

-- Slider: LABEL on the left, the value (editable, mono) on the right, and a
-- 3 px gold track below that fills up to the thumb. Mouse wheel steps it.
local function MakeSlider(anchor, yOff, label, minVal, maxVal, step, wheelStep, suffix)
    local row = CreateFrame("Frame", nil, panel)
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
    local btn = CreateFrame("Button", nil, panel)
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
    local b = CreateFrame("Button", nil, panel)
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

function ns.CreateOptions()
    local db = ns.db
    panel = CreateFrame("Frame", "FarmModeForeverOptions", UIParent)
    panel.name = "FarmMode Forever"
    panel:Hide()

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    T.Fill(bg, C.bg)

    -- Header: logo, name, version chip, gold line
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

    -- An invisible anchor at the top of each column
    local function ColumnTop(x)
        local f = CreateFrame("Frame", nil, panel)
        f:SetSize(1, 1)
        f:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -80)
        return f
    end
    local left, right = ColumnTop(18), ColumnTop(18 + COL_W + 40)

    local function Set(key)
        return function(v)
            db[key] = v
            ns.Refresh()
        end
    end

    -- Left column: the map and where it sits
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

    -- Right column: shape, behaviour, combat
    local shape = Section(right, 0, "Shape")
    local roundBtn = MakeButton("Round", (COL_W - 8) / 2)
    roundBtn:SetPoint("TOPLEFT", shape, "BOTTOMLEFT", 0, -12)
    local squareBtn = MakeButton("Square", (COL_W - 8) / 2)
    squareBtn:SetPoint("LEFT", roundBtn, "RIGHT", 8, 0)
    local function SetShape(v)
        db.shape = v
        roundBtn:SetSelected(v == "ROUND")
        squareBtn:SetSelected(v == "SQUARE")
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        ns.Refresh()
    end
    roundBtn:SetScript("OnClick", function() SetShape("ROUND") end)
    squareBtn:SetScript("OnClick", function() SetShape("SQUARE") end)
    local border = MakeCheck(roundBtn, -12, "Show the border")
    border.onChange = Set("border")

    local behaviour = Section(border, -18, "Behaviour")
    local drag = MakeCheck(behaviour, -10, "Drag the map to move it")
    drag.onChange = Set("draggable")
    local buttons = MakeCheck(drag, -6, "Hide minimap buttons")
    buttons.onChange = Set("hideButtons")

    local combat = Section(buttons, -18, "Combat")
    local combatClose = MakeCheck(combat, -10, "Close farm mode when combat starts")
    local combatReopen = MakeCheck(combatClose, -6, "Open it again when combat ends")
    combatClose.onChange = function(v)
        db.combatClose = v
        combatReopen:SetEnabledLook(v)
    end
    combatReopen.onChange = function(v) db.combatReopen = v end

    -- Footer
    local foot = T.Line(panel, C.divider)
    foot:SetPoint("TOPLEFT", yOff, "BOTTOMLEFT", 0, -16)
    foot:SetWidth(COL_W * 2 + 40)

    local reset = MakeButton("Reset defaults", 130)
    reset:SetPoint("TOPLEFT", foot, "BOTTOMLEFT", 0, -12)

    local hint = T.Text(panel, T.mono, 10, C.muted)
    hint:SetPoint("LEFT", reset, "RIGHT", 16, 0)
    hint:SetText("/farm toggles  ·  right-click the addon menu entry for this")

    local function Sync()
        size:SetValue(db.size)
        zoom:SetValue(db.zoom)
        opacity:SetValue(db.opacity)
        xOff:SetValue(db.x)
        yOff:SetValue(db.y)
        roundBtn:SetSelected(db.shape == "ROUND")
        squareBtn:SetSelected(db.shape == "SQUARE")
        border:SetChecked(db.border)
        drag:SetChecked(db.draggable)
        buttons:SetChecked(db.hideButtons)
        combatClose:SetChecked(db.combatClose)
        combatReopen:SetChecked(db.combatReopen)
        combatReopen:SetEnabledLook(db.combatClose)
    end
    panel:SetScript("OnShow", Sync)
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
