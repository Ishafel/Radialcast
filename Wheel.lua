-- Wheel input, selection, visibility and editor placement.
local _, ns = ...
local C, L, DB = ns.Config, ns.L, ns.Database
local Wheel = { activeRing = "base", editing = false, embedded = false, curScale = 1 }
ns.Wheel = Wheel

function Wheel.GetSlots()
    return DB.GetSlots(Wheel.activeRing)
end

function Wheel.Initialize()
    local View = ns.WheelView
    local Open, Close
    local function SetEditing(on)
        Wheel.editing = on
        for i = 1, C.N do View.hits[i]:EnableMouse(on) end
        View.hub:EnableMouse(on and not Wheel.embedded)      -- no dragging inside the window
        View.complete:SetShown(on and not Wheel.embedded)    -- closing the window finishes editing
        View.tabRow:SetShown(on)
        -- Keyboard only in edit mode, and only set up out of combat so keys
        -- can never get swallowed.
        if on and not InCombatLockdown() then
            View.frame:EnableKeyboard(true)
            View.frame:SetPropagateKeyboardInput(true)
        else
            View.frame:EnableKeyboard(false)
        end
        View.title:SetText(on and L["Customize"] or L["Quick Spell"])
        if on and Wheel.embedded then
            View.hint:SetText(L["Drag spells, items, or macros onto a slot  ·  Click a slot to open your spellbook  ·  Right-click clears"])
        elseif on then
            View.hint:SetText(L["Drag spells, items, or macros onto a slot  ·  Right-click clears  ·  Drag center to move"])
        else
            View.hint:SetText(L["Move mouse to select  ·  Shift / Ctrl swap rings  ·  Release to confirm"])
        end
        View.Refresh()
    end

    local function OpenEditor()
        if View.frame:IsShown() then View.frame:Hide() end
        SetEditing(true)
        View.ShowRing("base")
        Wheel.curScale = DB.GetSetting("scale")
        View.frame:SetScale(Wheel.curScale)
        View.frame:ClearAllPoints()
        View.frame:SetPoint("CENTER", UIParent, "CENTER")
        Wheel.selected = -1
        View.SetSelected(nil)
        View.frame:Show()
        View.fade:Play()
    end

    View.complete:SetScript("OnClick", function()
        View.frame:Hide()
        print("|cff6fd6f0RadialCast|r: " .. L["wheel saved"])
    end)

    View.frame:SetScript("OnHide", function()
        View.dim:Hide()
        GameTooltip:Hide()
        if Wheel.editing then SetEditing(false) end
    end)

    local cdTimer = 0

    local function UpdateSelection()
        -- Live ring swap: Shift/Ctrl change the slot contents instantly.
        -- Aim is untouched, so you stay on the same segment.
        local ring = DB.ModifierRing() or Wheel.activeRing
        if ring ~= Wheel.activeRing then
            Wheel.activeRing = ring
            View.Refresh()
        end
        -- Direction is measured from where the cursor was on press, so it
        -- still works when the wheel got pushed inward by PADDING.
        local scale = UIParent:GetEffectiveScale()
        local mx, my = GetCursorPosition()
        local dx, dy = mx / scale - Wheel.originX, my / scale - Wheel.originY
        local dead = C.INNER_R * Wheel.curScale
        if dx * dx + dy * dy < dead * dead then
            View.SetSelected(nil)
            return
        end
        local a = C.atan2(dx, dy)
        if a < 0 then a = a + 2 * math.pi end
        View.SetSelected(math.floor(a / C.SEG) % C.N + 1)
    end

    View.frame:SetScript("OnUpdate", function(self, elapsed)
        -- Order matters: closing and selection first, cosmetics last, so a
        -- problem in one can't freeze the others.
        if not Wheel.editing then
            if IsMouseButtonDown and not IsMouseButtonDown("MiddleButton") then
                Close()
                return
            end
            UpdateSelection()
        end
        cdTimer = cdTimer + (elapsed or 0)
        if cdTimer >= 0.1 then
            cdTimer = 0
            View.UpdateCooldowns()
        end
    end)

    local combatOffNotified = false

    function Open()
        if Wheel.editing then return end
        if InCombatLockdown() and not ns.Combat.applied.combat then
            if not combatOffNotified then
                combatOffNotified = true
                print("|cff6fd6f0RadialCast|r: " .. L["combat casting is off. Turn it on in /rcast (BETA)."])
            end
            return
        end
        View.frame:ClearAllPoints()
        if InCombatLockdown() then
            -- Visuals must sit exactly on top of the secure buttons, so use
            -- where they really are (settings changed mid-fight wait for later).
            Wheel.curScale = ns.Combat.applied.scale
            View.frame:SetScale(Wheel.curScale)
            View.frame:SetPoint("CENTER", UIParent, "CENTER", ns.Combat.applied.x / Wheel.curScale, ns.Combat.applied.y / Wheel.curScale)
            Wheel.originX = UIParent:GetWidth() / 2 + ns.Combat.applied.x
            Wheel.originY = UIParent:GetHeight() / 2 + ns.Combat.applied.y
            local verb = L["left-click"]
            for _, b in ipairs(C.CAST_BUTTONS) do if b.key == ns.Combat.applied.button then verb = b.verb end end
            View.hint:SetText((L["Hover a spell and %s to cast  ·  Shift / Ctrl swap rings"]):format(verb))
        else
            View.hint:SetText(L["Move mouse to select  ·  Shift / Ctrl swap rings  ·  Release to confirm"])
            Wheel.curScale = DB.GetSetting("scale")
            View.frame:SetScale(Wheel.curScale)
            local w, h = UIParent:GetWidth(), UIParent:GetHeight()
            local x, y
            if DB.GetSetting("cursor") then
                local cx, cy = GetCursorPosition()
                local s = UIParent:GetEffectiveScale()
                x, y = cx / s, cy / s
                Wheel.originX, Wheel.originY = x, y
                -- Keep the whole wheel inside a box inset by the padding setting.
                -- If the screen is too small for that, fall back to centered.
                local pad, half = DB.GetSetting("padding"), C.SIZE * Wheel.curScale / 2
                local minX, maxX = w * pad + half, w * (1 - pad) - half
                local minY, maxY = h * pad + half, h * (1 - pad) - half
                x = (minX <= maxX) and math.max(minX, math.min(maxX, x)) or w / 2
                y = (minY <= maxY) and math.max(minY, math.min(maxY, y)) or h / 2
            else
                x, y = w / 2, h / 2
                Wheel.originX, Wheel.originY = x, y
            end
            -- SetPoint offsets are in the wheel's own (scaled) units.
            View.frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / Wheel.curScale, y / Wheel.curScale)
        end
        Wheel.activeRing = DB.ModifierRing() or Wheel.activeRing
        cdTimer = 0
        View.Refresh()
        Wheel.selected = -1
        View.SetSelected(nil)
        local d = DB.GetSetting("dim")
        View.dim:SetAlpha(d)
        if d > 0 then View.dim:Show() end
        View.frame:Show()
        View.fade:Play()
    end

    function Close()
        if Wheel.editing or not View.frame:IsShown() then return end
        View.frame:Hide()
        if DB.GetSetting("debug") then
            local s = Wheel.selected and Wheel.GetSlots()[Wheel.selected]
            print("|cff6fd6f0RadialCast|r: " .. (s and s.name or L["cancelled"]))
        end
    end

    local function EmbedEditor(host)
        if View.frame:IsShown() then View.frame:Hide() end   -- resets any play/editor state
        Wheel.embedded = true
        View.frame:SetParent(host)
        View.frame:SetFrameStrata("DIALOG")
        View.frame:SetFrameLevel(host:GetFrameLevel() + 5)
        -- Fit the ring (plus tabs above and hint below) into the column.
        local w, h = host:GetWidth(), host:GetHeight()
        Wheel.curScale = math.min((w - 30) / C.SIZE, (h - 150) / C.SIZE)
        View.frame:SetScale(Wheel.curScale)
        View.frame:ClearAllPoints()
        View.frame:SetPoint("CENTER", host, "CENTER", 0, -6 / Wheel.curScale)
        SetEditing(true)
        View.ShowRing("base")
        Wheel.selected = -1
        View.SetSelected(nil)
        View.frame:Show()
    end

    local function ReleaseEditor()
        if not Wheel.embedded then return end
        View.frame:Hide()          -- OnHide ends edit mode
        Wheel.embedded = false
        View.frame:SetParent(UIParent)
        View.frame:SetFrameStrata("DIALOG")
        SetEditing(false)
    end

    Wheel.SetEditing = SetEditing
    Wheel.OpenEditor = OpenEditor
    Wheel.Open = Open
    Wheel.Close = Close
    Wheel.EmbedEditor = EmbedEditor
    Wheel.ReleaseEditor = ReleaseEditor
end
