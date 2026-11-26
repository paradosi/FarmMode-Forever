---- Options — the settings panel (Esc > Options > AddOns > FarmMode Forever)
--
-- Same dark, ElvUI-style widgets as the classic FarmMode, drawn by hand (no
-- libraries). Every control writes its setting and calls ns.Refresh(), so a
-- change shows on the minimap at once while farm mode is on.

local _, ns = ...

local FONT = "Fonts\\FRIZQT__.TTF"
local C_ACCENT = { 0.00, 0.70, 1.00 }
local C_TRACK  = { 0.12, 0.12, 0.12 }
local C_EDITBG = { 0.08, 0.08, 0.08 }
local C_HOVER  = { 0.25, 0.25, 0.25 }

local category
local panel

local function Text(parent, size, r, g, b, a)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size, "")
    fs:SetTextColor(r, g, b, a or 1)
    return fs
end

local function AddBorder(f)
    local function Edge(p1, x1, y1, p2, x2, y2)
        local t = f:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetColorTexture(0, 0, 0, 1)
        t:SetPoint(p1, x1, y1)
        t:SetPoint(p2, x2, y2)
        return t
    end
    Edge("TOPLEFT", -1, 1, "TOPRIGHT", 1, 1):SetHeight(1)
    Edge("BOTTOMLEFT", -1, -1, "BOTTOMRIGHT", 1, -1):SetHeight(1)
    Edge("TOPLEFT", -1, 1, "BOTTOMLEFT", -1, -1):SetWidth(1)
    Edge("TOPRIGHT", 1, 1, "BOTTOMRIGHT", 1, -1):SetWidth(1)
end

local function Round(value, step)
    return math.floor(value / step + 0.5) * step
end

-- Slider: label above, thin track with min/max either side, edit box below,
-- mouse wheel. Returns a wrapper with SetValue/GetValue and an onChange field.
local function MakeSlider(anchor, yOff, labelText, minVal, maxVal, step, wheelStep, suffix)
    local wrap = CreateFrame("Frame", nil, panel)
    wrap:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
    wrap:SetSize(270, 48)

    local label = Text(wrap, 11, unpack(C_ACCENT))
    label:SetPoint("TOP", wrap, "TOP", 0, 0)
    label:SetText(labelText)

    local s = CreateFrame("Slider", nil, wrap)
    s:SetPoint("TOP", label, "BOTTOM", 0, -4)
    s:SetSize(180, 6)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(minVal, maxVal)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true)
    local bg = s:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(C_TRACK[1], C_TRACK[2], C_TRACK[3], 1)
    AddBorder(s)
    s:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local thumb = s:GetThumbTexture()
    thumb:SetVertexColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 1)
    thumb:SetSize(10, 12)

    local minLbl = Text(wrap, 10, 0.5, 0.5, 0.5)
    minLbl:SetPoint("RIGHT", s, "LEFT", -6, 0)
    minLbl:SetText(minVal)
    local maxLbl = Text(wrap, 10, 0.5, 0.5, 0.5)
    maxLbl:SetPoint("LEFT", s, "RIGHT", 6, 0)
    maxLbl:SetText(maxVal)

    local eb = CreateFrame("EditBox", nil, wrap)
    eb:SetPoint("TOP", s, "BOTTOM", 0, -4)
    eb:SetSize(52, 18)
    eb:SetFont(FONT, 11, "")
    eb:SetAutoFocus(false)
    eb:SetJustifyH("CENTER")
    eb:SetTextColor(1, 1, 1)
    local eBg = eb:CreateTexture(nil, "BACKGROUND")
    eBg:SetAllPoints()
    eBg:SetColorTexture(C_EDITBG[1], C_EDITBG[2], C_EDITBG[3], 1)
    AddBorder(eb)

    local unit = Text(wrap, 10, 0.5, 0.5, 0.5)
    unit:SetPoint("LEFT", eb, "RIGHT", 4, 0)
    unit:SetText(suffix or "")

    local quiet = false -- SetValue from code: show it, don't write it back
    s:SetScript("OnValueChanged", function(_, value)
        value = Round(value, step)
        if not eb:HasFocus() then eb:SetText(value) end
        if not quiet and wrap.onChange then wrap.onChange(value) end
    end)
    s:SetScript("OnMouseWheel", function(self, delta)
        local v = self:GetValue() + delta * (wheelStep or step)
        self:SetValue(math.max(minVal, math.min(maxVal, v)))
    end)
    eb:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v then
            s:SetValue(Round(math.max(minVal, math.min(maxVal, v)), step))
        end
        self:SetText(Round(s:GetValue(), step))
        self:ClearFocus()
    end)
    eb:SetScript("OnEscapePressed", function(self)
        self:SetText(Round(s:GetValue(), step))
        self:ClearFocus()
    end)

    function wrap:SetValue(v)
        quiet = true
        s:SetValue(v)
        eb:SetText(Round(v, step))
        quiet = false
    end
    return wrap
end

local function MakeCheck(anchor, yOff, labelText)
    local btn = CreateFrame("Button", nil, panel)
    btn:SetSize(16, 16)
    btn:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(C_TRACK[1], C_TRACK[2], C_TRACK[3], 1)
    AddBorder(btn)
    local mark = btn:CreateTexture(nil, "ARTWORK")
    mark:SetPoint("TOPLEFT", 3, -3)
    mark:SetPoint("BOTTOMRIGHT", -3, 3)
    mark:SetColorTexture(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 1)

    function btn:SetChecked(val)
        self.checked = val and true or false
        mark:SetShown(self.checked)
    end
    btn:SetChecked(false)
    btn:SetScript("OnClick", function(self)
        self:SetChecked(not self.checked)
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        if self.onChange then self.onChange(self.checked) end
    end)

    local label = Text(panel, 11, 0.9, 0.9, 0.9)
    label:SetPoint("LEFT", btn, "RIGHT", 8, 0)
    label:SetText(labelText)
    btn.label = label
    return btn
end

local function MakeButton(text, width)
    local btn = CreateFrame("Button", nil, panel)
    btn:SetSize(width, 22)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    AddBorder(btn)
    local lbl = Text(btn, 11, 1, 1, 1)
    lbl:SetPoint("CENTER")
    lbl:SetText(text)

    -- selected: drawn in the accent colour (used by the shape buttons)
    local function Paint(hover)
        if btn.selected then
            bg:SetColorTexture(C_ACCENT[1] * 0.6, C_ACCENT[2] * 0.6, C_ACCENT[3] * 0.6, 1)
        elseif hover then
            bg:SetColorTexture(C_HOVER[1], C_HOVER[2], C_HOVER[3], 1)
        else
            bg:SetColorTexture(C_TRACK[1], C_TRACK[2], C_TRACK[3], 1)
        end
    end
    function btn:SetSelected(v)
        self.selected = v
        Paint(self:IsMouseOver())
    end
    btn:SetScript("OnEnter", function() Paint(true) end)
    btn:SetScript("OnLeave", function() Paint(false) end)
    Paint(false)
    return btn
end

function ns.CreateOptions()
    local db = ns.db
    panel = CreateFrame("Frame", "FarmModeForeverOptions", UIParent)
    panel.name = "FarmMode Forever"
    panel:Hide()

    local panelBg = panel:CreateTexture(nil, "BACKGROUND")
    panelBg:SetAllPoints()
    panelBg:SetColorTexture(0.05, 0.05, 0.05, 0.9)

    -- Header
    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", 16, -12)
    icon:SetTexture("Interface\\AddOns\\FarmModeForever\\media\\textures\\logo")

    local title = Text(panel, 16, unpack(C_ACCENT))
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    title:SetText("FarmMode Forever v" .. ns.version)

    local desc = Text(panel, 11, 0.6, 0.6, 0.6)
    desc:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -8)
    desc:SetText("The minimap as a big gathering map. Changes show at once while farm mode is on.")

    local headerLine = panel:CreateTexture(nil, "ARTWORK")
    headerLine:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -6)
    headerLine:SetSize(580, 1)
    headerLine:SetColorTexture(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.4)

    local function Set(key)
        return function(v)
            db[key] = v
            ns.Refresh()
        end
    end

    -- Left column: the map itself
    local size = MakeSlider(headerLine, -14, "Size", 140, 700, 10, 20, "px")
    size.onChange = Set("size")
    local zoom = MakeSlider(size, -8, "Zoom  (0 = farthest out)", 0, 5, 1, 1)
    zoom.onChange = Set("zoom")
    local opacity = MakeSlider(zoom, -8, "Opacity", 30, 100, 1, 5, "%")
    opacity.onChange = Set("opacity")
    local xOff = MakeSlider(opacity, -8, "Left / Right", -900, 900, 1, 10)
    xOff.onChange = Set("x")
    local yOff = MakeSlider(xOff, -8, "Down / Up", -600, 600, 1, 10)
    yOff.onChange = Set("y")

    -- Right column: shape and behaviour
    local col = CreateFrame("Frame", nil, panel)
    col:SetSize(1, 1)
    col:SetPoint("TOPLEFT", headerLine, "BOTTOMLEFT", 310, -14)

    local shapeLabel = Text(panel, 11, unpack(C_ACCENT))
    shapeLabel:SetPoint("TOPLEFT", col, "TOPLEFT", 0, 0)
    shapeLabel:SetText("Shape")

    local roundBtn = MakeButton("Round", 90)
    roundBtn:SetPoint("TOPLEFT", shapeLabel, "BOTTOMLEFT", 0, -6)
    local squareBtn = MakeButton("Square", 90)
    squareBtn:SetPoint("LEFT", roundBtn, "RIGHT", 8, 0)
    local function SetShape(shape)
        db.shape = shape
        roundBtn:SetSelected(shape == "ROUND")
        squareBtn:SetSelected(shape == "SQUARE")
        ns.Refresh()
    end
    roundBtn:SetScript("OnClick", function() SetShape("ROUND") end)
    squareBtn:SetScript("OnClick", function() SetShape("SQUARE") end)

    local border = MakeCheck(roundBtn, -14, "Show the border")
    border.onChange = Set("border")
    local drag = MakeCheck(border, -10, "Drag the map to move it")
    drag.onChange = Set("draggable")
    local buttons = MakeCheck(drag, -10, "Hide minimap buttons")
    buttons.onChange = Set("hideButtons")

    local combatLabel = Text(panel, 11, unpack(C_ACCENT))
    combatLabel:SetPoint("TOPLEFT", buttons, "BOTTOMLEFT", 0, -18)
    combatLabel:SetText("Combat")
    local combatClose = MakeCheck(combatLabel, -8, "Close farm mode when combat starts")
    local combatReopen = MakeCheck(combatClose, -10, "Open it again when combat ends")
    combatClose.onChange = function(v)
        db.combatClose = v
        combatReopen.label:SetAlpha(v and 1 or 0.4)
    end
    combatReopen.onChange = function(v) db.combatReopen = v end

    -- Footer
    local sep = panel:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", yOff, "BOTTOMLEFT", 0, -12)
    sep:SetSize(580, 1)
    sep:SetColorTexture(0.2, 0.2, 0.2, 1)

    local reset = MakeButton("Reset Defaults", 110)
    reset:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -10)

    local hint = Text(panel, 10, 0.4, 0.4, 0.4)
    hint:SetPoint("TOPLEFT", reset, "BOTTOMLEFT", 0, -12)
    hint:SetText("/farm toggles  |  Key Bindings > FarmMode Forever  |  Addon menu: left-click toggles, right-click opens this")

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
        combatReopen.label:SetAlpha(db.combatClose and 1 or 0.4)
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
