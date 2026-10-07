-- Run from repository root: lua tests/smoke.lua (Lua 5.1).
-- Optional baseline TOC: lua tests/smoke.lua /path/to/baseline.toc
local Mock = dofile("tests/wow_mock.lua")
local manifest = arg and arg[1] or "Radialcast.toc"
local files = {}
for line in io.lines(manifest) do
    line = line:gsub("\r$", "")
    if line:match("%.lua$") then files[#files+1] = line end
end
local function equal(actual, expected, message)
    assert(actual == expected, (message or "Unexpected value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function spell(id) return { type = "spell", id = id, name = "Spell " .. id } end
local count = 0
local function test(name, fn)
    fn()
    count = count + 1
    print("PASS " .. name)
end
local function load(locale, saved, account)
    local mock = Mock.New(locale)
    mock.env.RadialCastCharDB, mock.env.RadialCastDB = saved, account
    mock:Load(files)
    mock:Login()
    return mock, mock.env, mock.env.RadialCastCharDB
end

for _, locale in ipairs({ "enUS", "ruRU" }) do
    test(locale .. ": fresh login, commands and editor", function()
        local mock, env, db = load(locale)
        for _, ring in ipairs({ "base", "shift", "ctrl" }) do
            for i = 1, 8 do equal(db.rings[ring][i], false) end
        end
        equal(mock.bindings.BUTTON3, "RadialCastTrigger")
        equal(mock.bindings["CTRL-SHIFT-BUTTON3"], "RadialCastTrigger")
        equal(env.RadialCastWheel:IsShown(), false)
        env.SlashCmdList.RADIALCAST("")
        equal(env.RadialCastSettings:IsShown(), true)
        equal(mock:Slot(1).mouse, true)
        mock.cursor = { "spell", 1, "spell", 5487 }
        mock:Slot(1):Fire("OnReceiveDrag")
        equal(db.rings.base[1].id, 5487)
        equal(env.RadialCastCombat1:GetAttribute("spell"), "Spell 5487")
        mock:Slot(1):Fire("OnClick", "LeftButton")
        equal(mock.spellbook, true)
        env.RadialCastSettings:Hide()
        equal(env.RadialCastWheel:IsShown(), false)
        equal(mock:Slot(1).mouse, false)
        equal(env.RadialCastWheel.parent, env.UIParent)
        env.SlashCmdList.RADIALCAST("status")
        assert(mock.messages[#mock.messages]:find(locale == "ruRU" and "Основное" or "Base", 1, true))
    end)
end

test("legacy account and single-ring migration", function()
    local _, env, db = load("enUS", nil, { slots = { spell(5487) } })
    equal(db.rings.base[1].id, 5487)
    equal(db.slots, nil)
    equal(env.RadialCastDB.migrated, true)
    local _, _, second = load("enUS", nil, env.RadialCastDB)
    equal(second.rings.base[1], false)
    local _, _, character = load("enUS", { slots = { spell(768) }, settings = { scale = 1.2 } })
    equal(character.rings.base[1].id, 768)
    equal(character.settings.scale, 1.2)
end)

test("ring modifiers, disabled rings and activation", function()
    local mock, env = load("enUS", { rings = { base = { spell(1) }, shift = { spell(2) }, ctrl = { spell(3) } } })
    equal(env.RadialCastCombat1:GetAttribute("shift-spell"), "Spell 2")
    equal(env.RadialCastCombat1:GetAttribute("ctrl-shift-spell"), "Spell 3")
    env.SlashCmdList.RADIALCAST("disable ctrl")
    equal(mock.bindings["CTRL-BUTTON3"], nil)
    equal(env.RadialCastCombat1:GetAttribute("ctrl-shift-spell"), "Spell 2")
    env.SlashCmdList.RADIALCAST("disable")
    equal(next(mock.bindings), nil)
    env.SlashCmdList.RADIALCAST("enable")
    equal(mock.bindings["CTRL-BUTTON3"], "RadialCastTrigger")
end)

test("out-of-combat release and center cancellation", function()
    local mock, env = load("enUS", { rings = { base = { spell(5487) }, shift = { spell(768) } } })
    mock:Click(env.RadialCastTrigger, "LeftButton", true)
    equal(env.RadialCastWheel:IsShown(), true)
    mock.x, mock.y = 1060, 740
    env.RadialCastWheel:Fire("OnUpdate", 0.1)
    mock:Click(env.RadialCastTrigger, "LeftButton", false)
    equal(#mock.casts, 1)
    equal(mock.casts[1][2], "Spell 5487")
    equal(env.RadialCastTrigger:GetAttribute("type"), nil)
    mock:Click(env.RadialCastTrigger, "LeftButton", true)
    env.RadialCastWheel:Fire("OnUpdate", 0.1)
    mock:Click(env.RadialCastTrigger, "LeftButton", false)
    equal(#mock.casts, 1)
    mock:Click(env.RadialCastTrigger, "LeftButton", true)
    mock.x, mock.y, mock.shift = 1160, 940, true
    env.RadialCastWheel:Fire("OnUpdate", 0.1)
    mock:Click(env.RadialCastTrigger, "LeftButton", false)
    equal(mock.casts[2][2], "Spell 768")
end)

test("combat clicks and deferred changes", function()
    local mock, env, db = load("enUS", { rings = { base = { spell(5487) } } })
    mock:SetCombat(true)
    equal(env.RadialCastCombatFrame:IsShown(), true)
    mock:Click(env.RadialCastTrigger, "LeftButton", true)
    mock:Click(env.RadialCastTrigger, "LeftButton", false)
    equal(#mock.casts, 0)
    mock:Click(env.RadialCastTrigger, "LeftButton", true)
    mock:Click(env.RadialCastCombat1, "LeftButton", false)
    equal(mock.casts[1][2], "Spell 5487")
    equal(env.RadialCastWheel:IsShown(), false)
    env.SlashCmdList.RADIALCAST("disable base")
    equal(db.ringOff.base, true)
    equal(env.RadialCastCombat1:GetAttribute("spell"), "Spell 5487")
    mock:SetCombat(false)
    equal(env.RadialCastCombat1:GetAttribute("spell"), nil)
    equal(mock.bindings.BUTTON3, nil)
end)

test("reset confirmation, item and macro drag/drop", function()
    local mock, env, db = load("ruRU")
    env.SlashCmdList.RADIALCAST("")
    mock.cursor = { "item", 123 }
    mock:Slot(1):Fire("OnReceiveDrag")
    equal(env.RadialCastCombat1:GetAttribute("item"), "item:123")
    mock.cursor = { "macro", "My Macro" }
    mock:Slot(2):Fire("OnReceiveDrag")
    equal(env.RadialCastCombat2:GetAttribute("macro"), "My Macro")
    mock:Slot(1):Fire("OnDragStart")
    equal(db.rings.base[1], false)
    equal(mock.cursor[1], "item")
    mock:Slot(2):Fire("OnClick", "RightButton")
    equal(db.rings.base[2], false)
    mock.cursor = { "spell", 1, "spell", 768 }
    mock:Slot(1):Fire("OnReceiveDrag")
    env.SlashCmdList.RADIALCAST("reset")
    equal(mock.popup, "RADIALCAST_CLEAR")
    equal(db.rings.base[1].id, 768)
    env.StaticPopupDialogs.RADIALCAST_CLEAR.OnAccept()
    equal(db.rings.base[1], false)
    equal(env.RadialCastCombat1:GetAttribute("spell"), nil)
end)

test("settings widgets and post-combat layout update", function()
    local mock, env = load("enUS")
    env.SlashCmdList.RADIALCAST("")
    local size, right
    for _, frame in ipairs(mock.frames) do
        if frame.kind == "Slider" and frame.min == 0.6 then size = frame end
        if frame.kind == "Button" and frame.text == "Right" then right = frame end
    end
    assert(size and right)
    mock:SetCombat(true)
    size:SetValue(1.25)
    right:Fire("OnClick")
    equal(env.RadialCastCombatFrame.scale, 1)
    equal(env.RadialCastCombat1.clicks[1], "LeftButtonUp")
    mock:SetCombat(false)
    equal(env.RadialCastCombatFrame.scale, 1.25)
    equal(env.RadialCastCombat1.clicks[1], "RightButtonUp")
end)

print("Passed " .. count .. " scenarios")
