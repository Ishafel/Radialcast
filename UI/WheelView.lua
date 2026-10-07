-- Wheel frames, slot rendering, cooldowns and drag/drop editing.
local _, ns = ...
local C, L, API, DB = ns.Config, ns.L, ns.API, ns.Database
local View = {}
ns.WheelView = View

function View.Initialize()
    local Wheel = ns.Wheel
    local dim = CreateFrame("Frame", nil, UIParent)
    dim:SetAllPoints(UIParent)
    dim:SetFrameStrata("HIGH")
    local dimTex = dim:CreateTexture(nil, "BACKGROUND")
    dimTex:SetAllPoints()
    dimTex:SetColorTexture(0, 0, 0, 1)
    dim:Hide()

    local wheel = CreateFrame("Frame", "RadialCastWheel", UIParent)
    wheel:SetSize(C.SIZE, C.SIZE)
    wheel:SetFrameStrata("DIALOG")
    wheel:SetClampedToScreen(true)
    wheel:SetMovable(true)
    wheel:Hide()

    -- Escape closes the editor. (Not using UISpecialFrames: WoW closes
    -- those whenever the spellbook opens.) Every other key passes through.
    wheel:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" and Wheel.editing then
            if not InCombatLockdown() then self:SetPropagateKeyboardInput(false) end
            if Wheel.embedded and ns.Settings.Close then ns.Settings.Close() else self:Hide() end
        end
    end)

    local bg = wheel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(C.MEDIA .. "wheel")

    local hl = wheel:CreateTexture(nil, "BORDER")
    hl:SetAllPoints()
    hl:SetTexture(C.MEDIA .. "highlight")
    hl:Hide()

    local function Text(font, size, r, g, b, y)
        local fs = wheel:CreateFontString(nil, "OVERLAY")
        if not fs:SetFont(font, size, "") then fs:SetFontObject(GameFontNormal) end
        fs:SetTextColor(r, g, b)
        fs:SetPoint("CENTER", 0, y)
        fs:SetWidth(180 * C.K)
        fs:SetWordWrap(true)
        return fs
    end
    local title    = Text(C.DISPLAY_FONT, 18, 0.90, 0.85, 0.75, 26 * C.K)
    local category = Text(C.BODY_FONT, 12, 0.72, 0.50, 1.00, 8 * C.K)
    local label    = Text(C.DISPLAY_FONT, 16, 1, 1, 1, -24 * C.K)

    -- Ring indicator: a single disabled tab-style button in the hub,
    -- under the spell name, showing which ring is active.
    local ringBadge = CreateFrame("Button", nil, wheel, "UIPanelButtonTemplate")
    ringBadge:SetSize(70, 20)
    ringBadge:SetPoint("CENTER", wheel, "CENTER", 0, -54 * C.K)
    ringBadge:EnableMouse(false)
    ringBadge:Disable()

    local function UpdateRingIndicator()
        ringBadge:SetText(C.RING_BY_KEY[Wheel.activeRing].label)
        ringBadge:SetShown(not Wheel.editing)   -- the editor has its own tabs
        local t = C.RING_BY_KEY[Wheel.activeRing].tint
        hl:SetVertexColor(t[1], t[2], t[3])
    end

    local hint = wheel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", wheel, "BOTTOM", 0, -8)
    hint:SetTextColor(0.85, 0.80, 0.70)
    hint:SetWidth(C.SIZE)
    hint:SetWordWrap(true)

    local complete = CreateFrame("Button", nil, wheel, "UIPanelButtonTemplate")
    complete:SetSize(140, 26)
    complete:SetPoint("TOP", hint, "BOTTOM", 0, -8)
    complete:SetText(L["COMPLETE"])
    complete:Hide()

    -- Ring tabs above the wheel (edit mode only)
    local tabs = {}
    local tabRow = CreateFrame("Frame", nil, wheel)
    tabRow:SetSize(3 * 86, 24)
    tabRow:SetPoint("BOTTOM", wheel, "TOP", 0, 6)
    tabRow:Hide()
    for idx, r in ipairs(C.RINGS) do
        local tab = CreateFrame("Button", nil, tabRow, "UIPanelButtonTemplate")
        tab:SetSize(80, 22)
        tab:SetPoint("LEFT", (idx - 1) * 86, 0)
        tab:SetText(r.label)
        tab.key = r.key
        tabs[idx] = tab
    end

    -- "Ring is off" overlay (edit mode only). Dims the ring using the wheel
    -- art tinted black, blocks editing, and offers an Enable button.
    local offOverlay = CreateFrame("Frame", nil, wheel)
    offOverlay:SetAllPoints()
    offOverlay:EnableMouse(true)
    offOverlay:Hide()
    local offShade = offOverlay:CreateTexture(nil, "BACKGROUND")
    offShade:SetAllPoints()
    offShade:SetTexture(C.MEDIA .. "wheel")
    offShade:SetVertexColor(0, 0, 0, 0.75)
    local offText = offOverlay:CreateFontString(nil, "OVERLAY")
    if not offText:SetFont(C.DISPLAY_FONT, 18, "") then offText:SetFontObject(GameFontNormalLarge) end
    offText:SetTextColor(0.90, 0.85, 0.75)
    offText:SetPoint("CENTER", 0, 22)
    local offBtn = CreateFrame("Button", nil, offOverlay, "UIPanelButtonTemplate")
    offBtn:SetSize(150, 26)
    offBtn:SetPoint("CENTER", 0, -16)

    local function UpdateOffOverlay()
        local off = Wheel.editing and DB.data and not DB.RingEnabled(Wheel.activeRing)
        -- The hub text sits right where the overlay message goes, so hide it
        -- (and the highlight wedge) while the ring is off.
        title:SetShown(not off)
        category:SetShown(not off)
        label:SetShown(not off)
        if off then hl:Hide() end
        if off then
            offOverlay:SetFrameLevel(wheel:GetFrameLevel() + 20)  -- above the slot hit areas
            if DB.data.disabled then
                offText:SetText(L["RadialCast is disabled"])
                offBtn:SetText(L["Enable RadialCast"])
            else
                offText:SetText((L["Ring %s is off"]):format(C.RING_BY_KEY[Wheel.activeRing].label))
                offBtn:SetText(L["Enable"])
            end
            offOverlay:Show()
        else
            offOverlay:Hide()
        end
    end

    local fade = wheel:CreateAnimationGroup()
    local fa = fade:CreateAnimation("Alpha")
    fa:SetFromAlpha(0)
    fa:SetToAlpha(1)
    fa:SetDuration(0.08)

    ------------------------------------------------------------
    -- Selection display
    ------------------------------------------------------------
    local icons, pluses, hits, cells = {}, {}, {}, {}

    -- Classic action-button art that ships with the client.
    local TEX_BORDER = "Interface\\Buttons\\UI-Quickslot2"        -- button frame
    local TEX_SOCKET = "Interface\\Buttons\\UI-Quickslot"         -- empty recessed slot
    local TEX_HILITE = "Interface\\Buttons\\ButtonHilight-Square" -- hover glow
    local FRAME_RATIO = 66 / 36  -- the frame art is drawn larger than the icon it wraps

    local function SizeCell(j, scale)
        local c, sz = cells[j], C.ICON_SIZE * scale
        c.back:SetSize(sz + 4, sz + 4)
        c.socket:SetSize(sz * FRAME_RATIO, sz * FRAME_RATIO)
        c.border:SetSize(sz * FRAME_RATIO, sz * FRAME_RATIO)
        c.hilite:SetSize(sz, sz)
        icons[j]:SetSize(sz, sz)
    end

    local function SetSelected(i)
        if i == Wheel.selected then return end
        Wheel.selected = i
        for j, t in ipairs(icons) do
            local v = (Wheel.editing or j == i) and 1 or 0.6
            t:SetVertexColor(v, v, v)
            SizeCell(j, (j == i) and 1.12 or 1)
            cells[j].hilite:SetShown(j == i)
            pluses[j]:SetAlpha(j == i and 1 or 0.5)
        end
        if not i then
            hl:Hide()
            label:SetText("")
            category:SetText("")
            return
        end
        hl:SetRotation(-(i - 0.5) * C.SEG)  -- SetRotation is counterclockwise
        hl:Show()
        local s = DB.data and Wheel.GetSlots()[i]
        if s then
            label:SetText(s.name or "?")
            category:SetText(L[s.type:upper()])
            local c = C.TYPE_COLORS[s.type] or C.TYPE_COLORS.spell
            category:SetTextColor(c[1], c[2], c[3])
        else
            label:SetText(L["Empty"])
            category:SetText(Wheel.editing and "" or L["/rcast to customize"])
            category:SetTextColor(0.80, 0.70, 0.50)
        end
    end

    local function ClearCD(c)
        if c.cd.Clear then c.cd:Clear() else c.cd:SetCooldown(0, 0) end
        c.cdStart, c.cdDur = nil, nil
        c.cdText:SetText("")
    end

    local function UpdateCooldown(i)
        local c, s = cells[i], Wheel.GetSlots()[i]
        if not s then ClearCD(c) return end
        local start, dur, rate = API.SlotCD(s)
        local ok = pcall(function()
            if start and dur and dur > 0 then
                if c.cdStart ~= start or c.cdDur ~= dur then
                    c.cd:SetCooldown(start, dur, rate)
                    c.cdStart, c.cdDur = start, dur
                end
                local left = start + dur - GetTime()
                if dur > 1.5 and left > 0 then       -- no number for the GCD
                    local txt, r, g, b = API.FormatCD(left)
                    c.cdText:SetText(txt)
                    c.cdText:SetTextColor(r, g, b)
                else
                    c.cdText:SetText("")
                end
            elseif c.cdDur then
                ClearCD(c)
            else
                c.cdText:SetText("")
            end
        end)
        if not ok then
            -- If the client hides cooldown math from addons, still hand the
            -- values to the swipe, which can display them natively.
            if start and dur then pcall(c.cd.SetCooldown, c.cd, start, dur) end
            c.cdText:SetText("")
        end
    end

    -- Each slot is isolated: a cooldown API problem can't break the wheel.
    local function UpdateCooldowns()
        for i = 1, C.N do pcall(UpdateCooldown, i) end
    end

    local function Refresh()
        if not DB.data then return end
        UpdateRingIndicator()
        for i = 1, C.N do pcall(ClearCD, cells[i]) end  -- slot contents may have changed
        for i = 1, C.N do
            local s = Wheel.GetSlots()[i]
            icons[i]:SetTexture(API.SlotIcon(s) or 134400)
            icons[i]:SetShown(s and true or false)
            pluses[i]:SetShown(not s)
            cells[i].socket:SetShown(not s)
        end
        UpdateCooldowns()
        local sel = Wheel.selected
        Wheel.selected = -1
        SetSelected(sel)
        UpdateOffOverlay()   -- last, so selection can't re-show hub text or the wedge
    end

    ------------------------------------------------------------
    -- Slots: icon, empty marker, and an edit-mode hit area
    ------------------------------------------------------------
    local function OpenSpellbook()
        if InCombatLockdown() then
            print("|cff6fd6f0RadialCast|r: " .. L["can't open the spellbook in combat"])
            return
        end
        if PlayerSpellsUtil and PlayerSpellsUtil.OpenToSpellBookTab then
            PlayerSpellsUtil.OpenToSpellBookTab()          -- retail 11.x
        elseif SpellBookFrame and not SpellBookFrame:IsShown() and ToggleSpellBook then
            ToggleSpellBook(BOOKTYPE_SPELL or "spell")     -- classic / older retail
        end
    end

    local function DropOn(i)
        local new = API.SlotFromCursor()
        if not new then return end
        local old = Wheel.GetSlots()[i]
        Wheel.GetSlots()[i] = new
        ClearCursor()
        if old then API.PickupSlot(old) end  -- swap: old entry goes on the cursor
        Refresh()
        ns.Combat.SyncButtons()
    end

    for i = 1, C.N do
        local a = (i - 0.5) * C.SEG
        local x, y = math.sin(a) * C.ICON_R, math.cos(a) * C.ICON_R

        -- Layers, back to front: black backing, empty socket, icon,
        -- classic frame, hover glow.
        local back = wheel:CreateTexture(nil, "ARTWORK", nil, -3)
        back:SetPoint("CENTER", x, y)
        back:SetColorTexture(0, 0, 0, 0.85)

        local socket = wheel:CreateTexture(nil, "ARTWORK", nil, -2)
        socket:SetPoint("CENTER", x, y)
        socket:SetTexture(TEX_SOCKET)
        socket:SetAlpha(0.9)

        local t = wheel:CreateTexture(nil, "ARTWORK", nil, 0)
        t:SetPoint("CENTER", x, y)
        t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icons[i] = t

        local border = wheel:CreateTexture(nil, "OVERLAY", nil, 0)
        border:SetPoint("CENTER", x, y - 1)  -- the art sits 1px low in Blizzard's own buttons too
        border:SetTexture(TEX_BORDER)

        local hilite = wheel:CreateTexture(nil, "OVERLAY", nil, 1)
        hilite:SetPoint("CENTER", x, y)
        hilite:SetTexture(TEX_HILITE)
        hilite:SetBlendMode("ADD")
        hilite:Hide()

        -- Cooldown swipe tracks the icon (and its hover scale) exactly.
        local cd = CreateFrame("Cooldown", nil, wheel, "CooldownFrameTemplate")
        cd:SetAllPoints(t)
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end

        -- Our own countdown text, on a layer above the swipe.
        local over = CreateFrame("Frame", nil, wheel)
        over:SetAllPoints(t)
        over:SetFrameLevel(cd:GetFrameLevel() + 2)
        local cdText = over:CreateFontString(nil, "OVERLAY")
        if not cdText:SetFont(C.BODY_FONT, 16, "OUTLINE") then
            cdText:SetFontObject(NumberFontNormalLarge or GameFontHighlightLarge)
        end
        cdText:SetPoint("CENTER")

        cells[i] = { back = back, socket = socket, border = border, hilite = hilite,
                     cd = cd, cdText = cdText }
        SizeCell(i, 1)

        -- Empty-slot marker: a thin gold plus
        local plus = CreateFrame("Frame", nil, wheel)
        plus:SetSize(C.ICON_SIZE, C.ICON_SIZE)
        plus:SetPoint("CENTER", x, y)
        local arm = C.ICON_SIZE * 0.42
        for _, dims in ipairs({ { arm, 2 }, { 2, arm } }) do
            local bar = plus:CreateTexture(nil, "ARTWORK")
            bar:SetSize(dims[1], dims[2])
            bar:SetPoint("CENTER")
            bar:SetColorTexture(0.80, 0.70, 0.50, 1)
        end
        plus:SetAlpha(0.5)
        plus:Hide()
        pluses[i] = plus

        local hit = CreateFrame("Button", nil, wheel)
        hit:SetSize(C.HIT_SIZE, C.HIT_SIZE)
        hit:SetPoint("CENTER", x, y)
        hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        hit:RegisterForDrag("LeftButton")
        hit:EnableMouse(false)
        hits[i] = hit

        hit:SetScript("OnEnter", function(self)
            SetSelected(i)
            local s = Wheel.GetSlots()[i]
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if s and s.type == "spell" and s.id and GameTooltip.SetSpellByID then
                GameTooltip:SetSpellByID(s.id)
            elseif s and s.type == "item" and s.id and GameTooltip.SetItemByID then
                GameTooltip:SetItemByID(s.id)
            elseif s then
                GameTooltip:SetText(s.name or "?")
            end
            if s then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L["Click to open your spellbook"], 0.7, 0.7, 0.7)
                GameTooltip:AddLine(L["Drag to pick up  ·  Right-click to clear"], 0.7, 0.7, 0.7)
            else
                GameTooltip:SetText(L["Empty slot"])
                GameTooltip:AddLine(L["Click to open your spellbook"], 1, 1, 1)
                GameTooltip:AddLine(L["Drag a spell, item, or macro here"], 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        hit:SetScript("OnLeave", function()
            SetSelected(nil)
            GameTooltip:Hide()
        end)
        hit:SetScript("OnReceiveDrag", function() DropOn(i) end)
        hit:SetScript("OnClick", function(_, btn)
            if btn == "RightButton" then
                Wheel.GetSlots()[i] = false
                Refresh()
                ns.Combat.SyncButtons()
            elseif GetCursorInfo() then
                DropOn(i)
            else
                OpenSpellbook()   -- empty or filled: open it so they can pick/change
            end
        end)
        hit:SetScript("OnDragStart", function()
            local s = Wheel.GetSlots()[i]
            if not s then return end
            Wheel.GetSlots()[i] = false
            API.PickupSlot(s)
            Refresh()
            ns.Combat.SyncButtons()
        end)
    end

    -- Center hub: drag to move the wheel in edit mode
    local hub = CreateFrame("Button", nil, wheel)
    hub:SetSize(C.INNER_R * 1.6, C.INNER_R * 1.6)
    hub:SetPoint("CENTER")
    hub:RegisterForDrag("LeftButton")
    hub:EnableMouse(false)
    hub:SetScript("OnDragStart", function() wheel:StartMoving() end)
    hub:SetScript("OnDragStop", function() wheel:StopMovingOrSizing() end)

    local function ShowRing(key)
        Wheel.activeRing = key
        for _, tab in ipairs(tabs) do
            if tab.key == key then tab:LockHighlight() else tab:UnlockHighlight() end
            tab:SetText(C.RING_BY_KEY[tab.key].label)
            tab:SetEnabled(DB.RingEnabled(tab.key) and true or false)
        end
        Refresh()
    end

    for _, tab in ipairs(tabs) do
        tab:SetScript("OnClick", function(self)
            ClearCursor()
            ShowRing(self.key)
        end)
    end

    offBtn:SetScript("OnClick", function()
        if DB.data.disabled then
            DB.data.disabled = false
        else
            DB.data.ringOff = DB.data.ringOff or {}
            DB.data.ringOff[Wheel.activeRing] = nil
        end
        ns.Combat.ApplyActivation()
        ShowRing(Wheel.activeRing)
        if ns.Settings.Sync then ns.Settings.Sync() end
    end)

    View.dim = dim
    View.frame = wheel
    View.hits = hits
    View.hub = hub
    View.complete = complete
    View.tabRow = tabRow
    View.title = title
    View.hint = hint
    View.fade = fade
    View.Refresh = Refresh
    View.SetSelected = SetSelected
    View.ShowRing = ShowRing
    View.UpdateCooldowns = UpdateCooldowns
end
