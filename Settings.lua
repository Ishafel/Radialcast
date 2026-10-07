-- Settings window, control synchronization and reset confirmation.
local _, ns = ...
local C, L, DB, Widgets = ns.Config, ns.L, ns.Database, ns.Widgets
local Settings = {}
ns.Settings = Settings

function Settings.Initialize()
    local Wheel = ns.Wheel
    local PANEL_W, PANEL_H = 800, 700
    local LEFT_W = 340
    local panel
    local controls = {}

    local function Checkbox(...)
        local control = Widgets.Checkbox(Settings.Sync, ...)
        controls[#controls + 1] = control
        return control
    end

    local function Slider(...)
        local control = Widgets.Slider(LEFT_W, ...)
        controls[#controls + 1] = control
        return control
    end

    local function Pct(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end
    local function Px(v) return (L["%+d px"]):format(v) end

    StaticPopupDialogs["RADIALCAST_CLEAR"] = {
        text = L["Clear every slot in the Base, Shift, and Ctrl rings for this character?\n\nThis can't be undone."],
        button1 = L["Clear all"],
        button2 = CANCEL or L["Cancel"],
        OnShow = function(self)
            self:SetFrameStrata("FULLSCREEN_DIALOG")   -- never hidden behind the settings window
        end,
        OnAccept = function()
            DB.ResetRings()
            ns.WheelView.Refresh()
            ns.Combat.SyncButtons()
            print("|cff6fd6f0RadialCast|r: " .. L["all rings cleared"])
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        showAlert = true,
        preferredIndex = 3,
    }

    local function CombatNote()
        return InCombatLockdown() and L["|cffff8080In combat: size and combat settings apply when combat ends.|r"]
            or L["Size and combat settings apply out of combat."]
    end

    local function CreatePanel()
        local ok, f = pcall(CreateFrame, "Frame", "RadialCastSettings", UIParent, "BasicFrameTemplateWithInset")
        if not ok or not f then
            f = CreateFrame("Frame", "RadialCastSettings", UIParent)
            local bg = f:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.06, 0.05, 0.04, 0.95)
            local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
            close:SetPoint("TOPRIGHT", 2, 2)
        end
        f:SetSize(PANEL_W, PANEL_H)
        f:SetPoint("RIGHT", UIParent, "RIGHT", -40, 0)   -- leaves room for the spellbook
        f:SetFrameStrata("DIALOG")
        f:SetClampedToScreen(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:Hide()
        -- Not in UISpecialFrames on purpose: WoW closes those whenever the
        -- spellbook opens. Escape is handled by the embedded editor instead.

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", 0, -6)
        title:SetText("RadialCast")

        -- Columns
        local left = CreateFrame("Frame", nil, f)
        left:SetPoint("TOPLEFT", 6, -24)
        left:SetPoint("BOTTOMLEFT", 6, 6)
        left:SetWidth(LEFT_W)

        local right = CreateFrame("Frame", nil, f)
        right:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
        right:SetPoint("BOTTOMRIGHT", -6, 6)

        local divider = f:CreateTexture(nil, "ARTWORK")
        divider:SetWidth(1)
        divider:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -12)
        divider:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 12)
        divider:SetColorTexture(0.8, 0.7, 0.5, 0.25)

        ---------------- left column: settings ----------------
        Widgets.Section(left, L["General"], -10)
        Checkbox(left, L["Enable RadialCast"], 18, -38,
            function() return not DB.data.disabled end,
            function(v) DB.data.disabled = not v; ns.Combat.ApplyActivation() end)
        local ringBoxes = {}
        local ringText = { base = L["Base ring  (middle mouse)"], shift = L["Shift ring  (Shift + middle)"],
                           ctrl = L["Ctrl ring  (Ctrl + middle)"] }
        for idx, r in ipairs(C.RINGS) do
            local key = r.key
            ringBoxes[#ringBoxes + 1] = Checkbox(left, ringText[key], 40, -38 - idx * 26,
                function() return not (DB.data.ringOff and DB.data.ringOff[key]) end,
                function(v)
                    DB.data.ringOff = DB.data.ringOff or {}
                    DB.data.ringOff[key] = (not v) or nil
                    ns.Combat.ApplyActivation()
                end)
        end

        Widgets.Section(left, L["Wheel"], -160)
        Checkbox(left, L["Open at cursor  (off = screen center)"], 18, -188,
            function() return DB.GetSetting("cursor") end,
            function(v) DB.SetSetting("cursor", v) end)
        Slider(left, L["Size"], -224, 0.6, 1.4, 0.05, Pct,
            function() return DB.GetSetting("scale") end,
            function(v) DB.SetSetting("scale", v); ns.Combat.RequestLayout() end)
        Slider(left, L["Edge padding"], -270, 0, 0.30, 0.01, Pct,
            function() return DB.GetSetting("padding") end,
            function(v) DB.SetSetting("padding", v) end)
        Slider(left, L["Background dim"], -316, 0, 0.6, 0.05, Pct,
            function() return DB.GetSetting("dim") end,
            function(v) DB.SetSetting("dim", v) end)

        local combatHeader = Widgets.Section(left, L["Combat"], -366)
        Widgets.BetaChip(left, combatHeader)
        local combatBox = Checkbox(left, L["Enable combat casting"], 18, -394,
            function() return DB.GetSetting("combatCast") end,
            function(v) DB.SetSetting("combatCast", v); ns.Combat.ApplyActivation() end)
        combatBox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["Combat casting (BETA)"])
            GameTooltip:AddLine(L["In combat, hold middle mouse, hover a slot, and click it with your chosen mouse button to cast."], 1, 1, 1, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["The wheel's slots stay clickable (invisibly) at the combat position for the whole fight, so that button casts a slot even while the wheel is closed. Other mouse buttons always pass through to the game."], 1, 0.82, 0.3, true)
            GameTooltip:Show()
        end)
        combatBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- "Cast with" button row
        local castLabel = left:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        castLabel:SetPoint("TOPLEFT", 22, -430)
        castLabel:SetText(L["Cast with"])
        local castRow = { buttons = {} }
        local bw = math.floor((LEFT_W - 44 - 3 * 4) / 4)
        for idx, info in ipairs(C.CAST_BUTTONS) do
            local b = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
            b:SetSize(bw, 22)
            b:SetPoint("TOPLEFT", 22 + (idx - 1) * (bw + 4), -448)
            b:SetText(info.short)
            b:SetScript("OnClick", function()
                DB.SetSetting("combatButton", info.key)
                ns.Combat.RequestLayout()
                if panel and panel.Sync then panel:Sync() end
            end)
            b:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(info.tip)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b.key = info.key
            castRow.buttons[idx] = b
        end
        castRow.Sync = function(self)
            local cur = DB.GetSetting("combatButton")
            for _, b in ipairs(self.buttons) do
                if b.key == cur then b:LockHighlight() else b:UnlockHighlight() end
            end
        end
        castRow.SetActive = function(self, on)
            for _, b in ipairs(self.buttons) do b:SetEnabled(on) end
            castLabel:SetAlpha(on and 1 or 0.35)
        end
        controls[#controls + 1] = castRow

        local combatSliders = {
            castRow,
            Slider(left, L["Combat wheel horizontal"], -490, -600, 600, 10, Px,
                function() return DB.GetSetting("combatX") end,
                function(v) DB.SetSetting("combatX", v); ns.Combat.RequestLayout() end),
            Slider(left, L["Combat wheel vertical"], -536, -400, 400, 10, Px,
                function() return DB.GetSetting("combatY") end,
                function(v) DB.SetSetting("combatY", v); ns.Combat.RequestLayout() end),
        }

        local note = left:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        note:SetPoint("TOPLEFT", 22, -584)
        note:SetWidth(LEFT_W - 44)
        note:SetJustifyH("LEFT")

        local clear = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
        clear:SetSize(LEFT_W - 44, 26)
        clear:SetPoint("BOTTOMLEFT", 22, 14)
        clear:SetText(L["Clear all rings"])
        clear:SetScript("OnClick", function() StaticPopup_Show("RADIALCAST_CLEAR") end)

        ---------------- right column: live ring editor ----------------
        local save = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
        save:SetSize(120, 26)
        save:SetPoint("BOTTOMRIGHT", -16, 14)
        save:SetText(L["Save"])
        save:SetScript("OnClick", function() f:Hide() end)   -- OnHide confirms in chat

        local layoutTitle = right:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        layoutTitle:SetPoint("TOPLEFT", 18, -10)
        layoutTitle:SetText(L["Layout"])

        function f:Sync()
            for _, c in ipairs(controls) do c:Sync() end
            local on = not DB.data.disabled
            for _, cb in ipairs(ringBoxes) do
                cb:SetEnabled(on)
                cb.label:SetAlpha(on and 1 or 0.4)
            end
            local combatOn = DB.GetSetting("combatCast") and true or false
            for _, sl in ipairs(combatSliders) do sl:SetActive(combatOn) end
            note:SetText(CombatNote())
            if Wheel.editing then ns.WheelView.ShowRing(Wheel.activeRing) end   -- tabs + "ring is off" overlay
        end
        f:SetScript("OnShow", function(self)
            self:Sync()
            Wheel.EmbedEditor(right)
        end)
        f:SetScript("OnHide", function()
            Wheel.ReleaseEditor()
            print("|cff6fd6f0RadialCast|r: " .. L["settings saved"])
        end)
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:RegisterEvent("PLAYER_REGEN_DISABLED")
        f:SetScript("OnEvent", function(self) if self:IsShown() then note:SetText(CombatNote()) end end)
        return f
    end

    local function ToggleSettings()
        panel = panel or CreatePanel()
        panel:SetShown(not panel:IsShown())
    end

    Settings.Close = function()
        if panel then panel:Hide() end
    end

    Settings.Sync = function()
        if panel and panel:IsShown() then panel:Sync() end
    end

    Settings.Toggle = ToggleSettings
end
