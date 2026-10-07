-- Slash commands; storage, UI and combat work stay in their modules.
local _, ns = ...
local C, L, DB, Wheel = ns.Config, ns.L, ns.Database, ns.Wheel

SLASH_RADIALCAST1 = "/rcast"
SLASH_RADIALCAST2 = "/radialcast"

local function Status()
    if DB.data.disabled then return L["disabled"] end
    local parts = {}
    for _, r in ipairs(C.RINGS) do
        parts[#parts + 1] = r.label .. (DB.RingEnabled(r.key) and L[" on"] or L[" off"])
    end
    return table.concat(parts, ", ")
end

SlashCmdList.RADIALCAST = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")

    if cmd == "reset" then
        StaticPopup_Show("RADIALCAST_CLEAR")   -- same confirmation as the button

    elseif cmd == "disable" or cmd == "enable" then
        local off = (cmd == "disable")
        DB.data.ringOff = DB.data.ringOff or {}
        if rest == "" then
            DB.data.disabled = off
            if not off then DB.data.ringOff = {} end   -- plain enable = everything on
        else
            local list, bad = {}, {}
            for word in rest:gmatch("[^,%s]+") do
                if C.RING_BY_KEY[word] then list[#list + 1] = word else bad[#bad + 1] = word end
            end
            if #bad > 0 then
                print("|cff6fd6f0RadialCast|r: " .. (L["unknown ring '%s' (use base, shift, ctrl)"]):format(table.concat(bad, ", ")))
                return
            end
            for _, k in ipairs(list) do DB.data.ringOff[k] = off or nil end
            if not off then DB.data.disabled = false end
        end
        local ok = ns.Combat.ApplyActivation()
        if Wheel.editing then ns.WheelView.ShowRing(Wheel.activeRing) end   -- refresh "(off)" tab labels
        ns.Settings.Sync()
        print("|cff6fd6f0RadialCast|r: " .. Status()
              .. (ok and "" or L[" (applies when combat ends)"]))

    elseif cmd == "status" then
        print("|cff6fd6f0RadialCast|r: " .. Status())

    else
        -- /rcast and /rcast edit both open the settings window
        if Wheel.editing and not Wheel.embedded then ns.WheelView.frame:Hide() end
        ns.Settings.Toggle()
    end
end
