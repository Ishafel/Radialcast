-- Secure action buttons, mouse bindings and deferred combat updates.
local _, ns = ...
local C, L, DB = ns.Config, ns.L, ns.Database
local Combat = { applied = { x = 0, y = 0, scale = 1, combat = false, button = "LeftButton" } }
ns.Combat = Combat

function Combat.Initialize()
    local Wheel = ns.Wheel
    local combatFrame = CreateFrame("Frame", "RadialCastCombatFrame", UIParent, "SecureFrameTemplate")
    combatFrame:SetSize(C.SIZE, C.SIZE)
    combatFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    combatFrame:SetFrameStrata("DIALOG")
    combatFrame:Hide()

    local combatBtns = {}
    for i = 1, C.N do
        local a = (i - 0.5) * C.SEG
        local b = CreateFrame("Button", "RadialCastCombat" .. i, combatFrame, "SecureActionButtonTemplate")
        b:SetSize(C.HIT_SIZE, C.HIT_SIZE)
        b:SetPoint("CENTER", math.sin(a) * C.ICON_R, math.cos(a) * C.ICON_R)
        b:RegisterForClicks("LeftButtonUp")
        b:SetAttribute("useOnKeyDown", false)
        -- Let middle (wheel) and right (camera) clicks through to the game.
        if b.SetPassThroughButtons then
            pcall(b.SetPassThroughButtons, b, "MiddleButton", "RightButton")
        end
        -- Close the wheel once a click casts (insecure hook, allowed in combat).
        b:HookScript("PostClick", function()
            if ns.WheelView.frame:IsShown() and not Wheel.editing then
                Wheel.Close()
                Wheel.selected = nil   -- don't let the later middle release reuse it
            end
        end)
        combatBtns[i] = b
    end

    -- Which ring each modifier prefix casts from, skipping disabled rings.
    -- nil = no attributes for that prefix, so the game falls back to Base.
    local ALL_PREFIXES = { "", "shift-", "ctrl-", "ctrl-shift-" }
    local function RingForPrefix(prefix)
        if prefix == "" then return DB.RingEnabled("base") and "base" or nil end
        if prefix == "shift-" then return DB.RingEnabled("shift") and "shift" or nil end
        if prefix == "ctrl-" then return DB.RingEnabled("ctrl") and "ctrl" or nil end
        if DB.RingEnabled("ctrl") then return "ctrl" end          -- ctrl-shift-
        if DB.RingEnabled("shift") then return "shift" end
    end

    local function ClearPrefix(btn, prefix)
        for _, k in ipairs({ "type", "spell", "item", "macro" }) do
            btn:SetAttribute(prefix .. k, nil)
        end
    end

    local function ApplySlot(btn, prefix, s)
        for _, k in ipairs({ "spell", "item", "macro" }) do
            btn:SetAttribute(prefix .. k, nil)
        end
        if not s then
            -- Empty modifier slots get a do-nothing type so they don't fall
            -- back to the Base spell. Empty Base slots just have no type.
            btn:SetAttribute(prefix .. "type", prefix ~= "" and "radialnone" or nil)
            return
        end
        btn:SetAttribute(prefix .. "type", s.type)
        if s.type == "item" and s.id then
            btn:SetAttribute(prefix .. "item", "item:" .. s.id)
        else
            btn:SetAttribute(prefix .. s.type, s.name)
        end
    end

    local combatPending = false
    local function SyncCombatButtons()
        if not DB.data then return end
        if InCombatLockdown() then combatPending = true return end
        combatPending = false
        for i = 1, C.N do
            for _, prefix in ipairs(ALL_PREFIXES) do
                local ring = RingForPrefix(prefix)
                if ring then
                    ApplySlot(combatBtns[i], prefix, DB.data.rings[ring][i])
                else
                    ClearPrefix(combatBtns[i], prefix)
                end
            end
        end
    end

    local trigger = CreateFrame("Button", "RadialCastTrigger", UIParent, "SecureActionButtonTemplate")
    trigger:RegisterForClicks("AnyDown", "AnyUp")
    trigger:SetAttribute("useOnKeyDown", false)

    local function ClearAction()
        for _, k in ipairs({ "type", "spell", "item", "macro" }) do
            trigger:SetAttribute(k, nil)
        end
    end

    trigger:SetScript("PreClick", function(_, _, down)
        if Wheel.editing then return end
        if down then
            if not InCombatLockdown() then ClearAction() end
            Wheel.Open()
            return
        end
        local s = Wheel.selected and Wheel.GetSlots()[Wheel.selected]
        if s and not InCombatLockdown() then
            trigger:SetAttribute("type", s.type)
            if s.type == "item" and s.id then
                trigger:SetAttribute("item", "item:" .. s.id)
            else
                trigger:SetAttribute(s.type, s.name)
            end
        end
        -- In combat, casting happens by left-clicking the hovered slot instead.
    end)

    trigger:SetScript("PostClick", function(_, _, down)
        if down or Wheel.editing then return end
        Wheel.Close()
        if not InCombatLockdown() then ClearAction() end
    end)

    local BIND_RULES = {
        { "",            function() return DB.RingEnabled("base") end },
        { "SHIFT-",      function() return DB.RingEnabled("shift") end },
        { "CTRL-",       function() return DB.RingEnabled("ctrl") end },
        { "CTRL-SHIFT-", function() return DB.RingEnabled("ctrl") or DB.RingEnabled("shift") end },
    }

    local function AnyRingEnabled()
        return DB.RingEnabled("base") or DB.RingEnabled("shift") or DB.RingEnabled("ctrl")
    end

    -- Move/scale the combat buttons to match settings (out of combat only).
    local function ApplyCombatLayout()
        local sc, x, y = DB.GetSetting("scale"), DB.GetSetting("combatX"), DB.GetSetting("combatY")
        combatFrame:SetScale(sc)
        combatFrame:ClearAllPoints()
        combatFrame:SetPoint("CENTER", UIParent, "CENTER", x / sc, y / sc)
        ns.Combat.applied.x, ns.Combat.applied.y, ns.Combat.applied.scale = x, y, sc

        -- Only the chosen button casts; every other mouse button passes
        -- through to the game, even over the invisible slots.
        local key = DB.GetSetting("combatButton")
        local pass = {}
        for _, k in ipairs(C.ALL_MOUSE) do if k ~= key then pass[#pass + 1] = k end end
        for _, b in ipairs(combatBtns) do
            b:RegisterForClicks(key .. "Up")
            if b.SetPassThroughButtons then pcall(b.SetPassThroughButtons, b, unpack(pass)) end
        end
        ns.Combat.applied.button = key
    end

    local statePending = false
    local function ApplyActivation()
        if InCombatLockdown() then statePending = true return false end
        statePending = false
        ApplyCombatLayout()
        ClearOverrideBindings(trigger)
        for _, rule in ipairs(BIND_RULES) do
            if rule[2]() then
                SetOverrideBindingClick(trigger, true, rule[1] .. C.BIND, "RadialCastTrigger")
            end
        end
        ns.Combat.applied.combat = AnyRingEnabled() and DB.GetSetting("combatCast") and true or false
        if ns.Combat.applied.combat then
            -- The game shows/hides these itself, so it works in combat.
            RegisterStateDriver(combatFrame, "visibility", "[combat] show; hide")
        else
            UnregisterStateDriver(combatFrame, "visibility")
            combatFrame:Hide()
        end
        SyncCombatButtons()
        return true
    end

    local function RequestCombatLayout()
        if InCombatLockdown() then statePending = true return false end
        ApplyCombatLayout()
        return true
    end

    Combat.SyncButtons = SyncCombatButtons
    Combat.ApplyActivation = ApplyActivation
    Combat.RequestLayout = RequestCombatLayout
    function Combat.FlushPending()
        if statePending then ApplyActivation()
        elseif combatPending then SyncCombatButtons() end
    end
end
