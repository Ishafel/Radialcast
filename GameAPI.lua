-- Compatibility helpers for spells, items, macros and cooldowns.
local _, ns = ...
local L = ns.L

local function SpellIcon(x)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(x) end
    if GetSpellTexture then return GetSpellTexture(x) end
end
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
end
local function ItemIcon(x)
    if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(x) end
    if GetItemIcon then return GetItemIcon(x) end
end
local function ItemName(id)
    if C_Item and C_Item.GetItemNameByID then return C_Item.GetItemNameByID(id) end
    if GetItemInfo then return (GetItemInfo(id)) end
end
local function PickupSpellAny(x)
    if C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(x)
    elseif PickupSpell then PickupSpell(x) end
end
local function PickupItemAny(x)
    if C_Item and C_Item.PickupItem then C_Item.PickupItem(x)
    elseif PickupItem then PickupItem(x) end
end

local function SpellCD(x)
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(x)
        if info then return info.startTime, info.duration, info.modRate end
    elseif GetSpellCooldown then
        local st, dur = GetSpellCooldown(x)
        return st, dur
    end
end
local function ItemCD(id)
    if C_Container and C_Container.GetItemCooldown then
        local st, dur = C_Container.GetItemCooldown(id)
        return st, dur
    elseif GetItemCooldown then
        local st, dur = GetItemCooldown(id)
        return st, dur
    end
end
local function SlotCD(s)
    if s.type == "spell" then return SpellCD(s.id or s.name) end
    if s.type == "item" and s.id then return ItemCD(s.id) end
    if s.type == "macro" then
        local sid = GetMacroSpell and GetMacroSpell(s.name)
        if sid then return SpellCD(sid) end
        local _, link = GetMacroItem and GetMacroItem(s.name)
        local iid = link and tonumber(link:match("item:(%d+)"))
        if iid then return ItemCD(iid) end
    end
end

local function FormatCD(left)
    if left >= 3600 then return (L["%dh"]):format(math.ceil(left / 3600)), 1, 1, 1 end
    if left >= 60   then return (L["%dm"]):format(math.ceil(left / 60)), 1, 1, 1 end
    if left >= 3    then return ("%d"):format(math.ceil(left)), 1, 1, 1 end
    return ("%.1f"):format(left), 1, 0.25, 0.25
end

local function SlotIcon(s)
    if not s then return nil end
    if s.type == "spell" then return SpellIcon(s.id or s.name) end
    if s.type == "item"  then return ItemIcon(s.id or s.name) end
    if s.type == "macro" then
        local _, icon = GetMacroInfo(s.name)
        return icon or s.icon
    end
end

local function PickupSlot(s)
    if s.type == "spell" then PickupSpellAny(s.id or s.name)
    elseif s.type == "item" then PickupItemAny(s.id or s.name)
    elseif s.type == "macro" and PickupMacro then PickupMacro(s.name) end
end

-- Turn whatever is on the cursor into a slot entry.
local function SlotFromCursor()
    local kind, a, b, c = GetCursorInfo()
    if kind == "spell" then
        local name = c and SpellName(c)
        if not name and GetSpellBookItemName then name = GetSpellBookItemName(a, b) end
        if name then return { type = "spell", id = c, name = name } end
    elseif kind == "item" then
        return { type = "item", id = a, name = ItemName(a) or ("item:" .. a) }
    elseif kind == "macro" then
        local name, icon = GetMacroInfo(a)
        if name then return { type = "macro", name = name, icon = icon } end
    end
end

ns.API = {
    SpellIcon = SpellIcon,
    SpellName = SpellName,
    ItemIcon = ItemIcon,
    ItemName = ItemName,
    PickupSpellAny = PickupSpellAny,
    PickupItemAny = PickupItemAny,
    SpellCD = SpellCD,
    ItemCD = ItemCD,
    SlotCD = SlotCD,
    FormatCD = FormatCD,
    SlotIcon = SlotIcon,
    PickupSlot = PickupSlot,
    SlotFromCursor = SlotFromCursor,
}
