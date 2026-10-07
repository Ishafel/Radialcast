-- Addon entry point: initialize modules, then route game lifecycle events.
local ADDON, ns = ...
local DB, Wheel, Combat, L = ns.Database, ns.Wheel, ns.Combat, ns.L

ns.WheelView.Initialize()
Wheel.Initialize()
Combat.Initialize()
ns.Settings.Initialize()

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon == ADDON then
        DB.Load()
    elseif event == "PLAYER_REGEN_ENABLED" then
        Combat.FlushPending()
    elseif event == "PLAYER_LOGIN" then
        Combat.ApplyActivation()
        if DB.data.disabled then
            print("|cff6fd6f0RadialCast|r: " .. L["disabled (/rcast enable to turn it back on)"])
        end
        Wheel.SetEditing(false)
        if not DB.HasSlots() then
            print("|cff6fd6f0RadialCast|r: " .. L["type /rcast to set up your wheel"])
        end
    end
end)
