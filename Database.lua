-- Per-character storage, defaults, migrations and enabled rings.
local _, ns = ...
local C, L = ns.Config, ns.L
local DB = {}
ns.Database = DB

function DB.GetSetting(key)
    local v = DB.data and DB.data.settings and DB.data.settings[key]
    if v == nil then return C.DEFAULTS[key] end
    return v
end

function DB.RingEnabled(key)
    return DB.data and not DB.data.disabled and not (DB.data.ringOff and DB.data.ringOff[key])
end

-- Ring the held modifiers point at, skipping disabled rings. Returns nil
-- when nothing enabled fits, and callers keep the current ring.
function DB.ModifierRing()
    if IsControlKeyDown() and DB.RingEnabled("ctrl") then return "ctrl" end
    if IsShiftKeyDown() and DB.RingEnabled("shift") then return "shift" end
    if DB.RingEnabled("base") then return "base" end
end

function DB.ResetRings()
    DB.data.rings = {}
    for _, r in ipairs(C.RINGS) do
        DB.data.rings[r.key] = {}
        for i = 1, C.N do DB.data.rings[r.key][i] = false end
    end
end

function DB.SetSetting(key, value)
    DB.data.settings = DB.data.settings or {}
    DB.data.settings[key] = value
end

function DB.GetSlots(key)
    return DB.data.rings[key]
end

function DB.Load()
    -- The first character without a layout inherits the legacy account layout.
    -- Later characters start empty once the account migration is marked done.
    if not RadialCastCharDB then
        RadialCastCharDB = {}
        local acct = RadialCastDB
        if acct and not acct.migrated and (acct.rings or acct.slots) then
            RadialCastCharDB.rings = acct.rings
            RadialCastCharDB.slots = acct.slots
            print("|cff6fd6f0RadialCast|r: " .. L["moved your existing layout to this character"])
        end
        RadialCastDB = { migrated = true }
    end
    DB.data = RadialCastCharDB
    if not DB.data.rings then
        local old = DB.data.slots      -- v0.4 single-ring layout
        DB.ResetRings()
        if old then
            for i = 1, C.N do DB.data.rings.base[i] = old[i] or false end
        end
        DB.data.slots = nil
    end
    for _, r in ipairs(C.RINGS) do
        DB.data.rings[r.key] = DB.data.rings[r.key] or {}
        for i = 1, C.N do
            if DB.data.rings[r.key][i] == nil then DB.data.rings[r.key][i] = false end
        end
    end
end

function DB.HasSlots()
    for _, ring in ipairs(C.RINGS) do
        for i = 1, C.N do
            if DB.data.rings[ring.key][i] then return true end
        end
    end
    return false
end
