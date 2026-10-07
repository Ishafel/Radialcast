-- Small settings widgets; caller owns layout and the control registry.
local _, ns = ...
local L = ns.L

local function Section(parent, text, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", 18, y)
    fs:SetText(text)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 18, y - 20)
    line:SetPoint("TOPRIGHT", -18, y - 20)
    line:SetColorTexture(0.8, 0.7, 0.5, 0.35)
    return fs
end

local function BetaChip(parent, anchor)
    local chip = CreateFrame("Frame", nil, parent)
    chip:SetSize(40, 16)
    chip:SetPoint("LEFT", anchor, "RIGHT", 8, 0)
    local bg = chip:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.85, 0.45, 0.10, 0.9)
    local t = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("CENTER", 0, 0)
    t:SetText(L["BETA"])
    return chip
end

local function Checkbox(onChanged, parent, label, x, y, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    fs:SetText(label)
    cb.label = fs
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        if onChanged then onChanged() end
    end)
    cb.Sync = function(self) self:SetChecked(get() and true or false) end
    return cb
end

local function Slider(width, parent, label, y, minV, maxV, step, fmt, get, set)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", 22, y)
    title:SetText(label)
    local val = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    val:SetPoint("TOPRIGHT", -22, y)
    local labels = { title, val }

    local sl = CreateFrame("Slider", nil, parent)
    sl:SetOrientation("HORIZONTAL")
    sl:SetSize(width - 44, 18)
    sl:SetPoint("TOPLEFT", 22, y - 16)
    sl:EnableMouse(true)
    local track = sl:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", 0, 0)
    track:SetPoint("RIGHT", 0, 0)
    track:SetHeight(4)
    track:SetColorTexture(0.30, 0.26, 0.20, 1)
    sl:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local thumb = sl:GetThumbTexture()
    if thumb then thumb:SetSize(32, 32) end
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(step)
    if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end

    sl:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / step + 0.5) * step
        val:SetText(fmt(v))
        if not self.syncing then set(v) end
    end)
    sl:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(self:GetValue() + delta * step)
    end)
    sl.Sync = function(self)
        self.syncing = true
        self:SetValue(get())
        val:SetText(fmt(get()))
        self.syncing = false
    end
    -- Grey out + block input (used when a feature is off).
    sl.SetActive = function(self, on)
        self:EnableMouse(on)
        self:SetAlpha(on and 1 or 0.35)
        for _, fs in ipairs(labels) do fs:SetAlpha(on and 1 or 0.35) end
    end
    return sl
end

ns.Widgets = { Section = Section, BetaChip = BetaChip, Checkbox = Checkbox, Slider = Slider }
