-- Minimal, explicit WoW API double. Does not emulate secure execution or rendering.
local Mock = {}

function Mock.New(locale)
    local mock = { frames = {}, bindings = {}, casts = {}, messages = {}, drivers = {},
        combat = false, shift = false, ctrl = false, middle = true, x = 960, y = 540 }
    local env = setmetatable({}, { __index = _G })
    mock.env = env
    env._G = env
    local methods = {}
    local function protected(frame)
        return frame.secure or (frame.parent and protected(frame.parent))
    end
    local function check(frame)
        assert(not (mock.combat and protected(frame)), "Protected mutation in combat: " .. (frame.name or "frame"))
    end
    local function new(kind, name, parent, template)
        local frame = setmetatable({ kind = kind, name = name, parent = parent, scripts = {},
            attributes = {}, events = {}, shown = true, scale = 1, level = 1,
            secure = template and template:find("Secure") ~= nil }, { __index = methods })
        mock.frames[#mock.frames + 1] = frame
        if name then env[name] = frame end
        return frame
    end
    function methods:SetScript(event, fn) self.scripts[event] = fn end
    function methods:GetScript(event) return self.scripts[event] end
    function methods:HookScript(event, fn)
        local previous = self.scripts[event]
        self.scripts[event] = function(...)
            if previous then previous(...) end
            fn(...)
        end
    end
    function methods:Fire(event, ...) if self.scripts[event] then self.scripts[event](self, ...) end end
    function methods:RegisterEvent(event) self.events[event] = true end
    function methods:Show() local changed = not self.shown; self.shown = true; if changed then self:Fire("OnShow") end end
    function methods:Hide() local changed = self.shown; self.shown = false; if changed then self:Fire("OnHide") end end
    function methods:SetShown(on) if on then self:Show() else self:Hide() end end
    function methods:IsShown() return self.shown end
    function methods:SetAttribute(key, value) check(self); self.attributes[key] = value end
    function methods:GetAttribute(key) return self.attributes[key] end
    function methods:SetSize(w, h) check(self); self.width, self.height = w, h end
    function methods:SetWidth(w) self.width = w end
    function methods:SetHeight(h) self.height = h end
    function methods:GetWidth() return self.width or 420 end
    function methods:GetHeight() return self.height or 620 end
    function methods:SetScale(scale) check(self); self.scale = scale end
    function methods:GetEffectiveScale() return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1) end
    function methods:SetParent(parent) check(self); self.parent = parent end
    function methods:SetPoint(...) check(self); self.point = {...} end
    function methods:ClearAllPoints() check(self); self.point = nil end
    function methods:SetFrameLevel(level) check(self); self.level = level end
    function methods:GetFrameLevel() return self.level end
    function methods:SetText(text) self.text = text end
    function methods:GetText() return self.text end
    function methods:AddLine(text) self.lines = self.lines or {}; self.lines[#self.lines+1] = text end
    function methods:SetFont(...) self.font = {...}; return true end
    function methods:SetTexture(texture) self.texture = texture end
    function methods:CreateTexture(name) return new("Texture", name, self) end
    function methods:CreateFontString(name) return new("FontString", name, self) end
    function methods:CreateAnimationGroup() return new("AnimationGroup", nil, self) end
    function methods:CreateAnimation() return new("Animation", nil, self) end
    function methods:RegisterForClicks(...) check(self); self.clicks = {...} end
    function methods:RegisterForDrag(...) self.drag = {...} end
    function methods:SetPassThroughButtons(...) check(self); self.passThrough = {...} end
    function methods:EnableMouse(on) self.mouse = on end
    function methods:SetChecked(on) self.checked = on end
    function methods:GetChecked() return self.checked end
    function methods:SetEnabled(on) self.enabled = on end
    function methods:Disable() self.enabled = false end
    function methods:SetValue(value) self.value = value; self:Fire("OnValueChanged", value) end
    function methods:GetValue() return self.value end
    function methods:SetMinMaxValues(low, high) self.min, self.max = low, high end
    function methods:SetThumbTexture() self.thumb = new("Texture", nil, self) end
    function methods:GetThumbTexture() return self.thumb end
    function methods:SetCooldown(start, duration) self.cooldown = { start, duration } end
    function methods:Clear() self.cooldown = nil end
    for _, name in ipairs({ "SetAllPoints", "SetFrameStrata", "SetColorTexture", "SetClampedToScreen",
        "SetMovable", "SetPropagateKeyboardInput", "SetFontObject", "SetTextColor", "SetWordWrap",
        "SetVertexColor", "SetFromAlpha", "SetToAlpha", "SetDuration", "SetAlpha", "SetRotation",
        "SetTexCoord", "SetBlendMode", "SetHideCountdownNumbers", "SetDrawEdge", "SetOwner",
        "SetSpellByID", "SetItemByID", "StartMoving", "StopMovingOrSizing", "LockHighlight",
        "UnlockHighlight", "EnableKeyboard", "Play", "SetJustifyH", "SetOrientation",
        "SetValueStep", "SetObeyStepOnDrag" }) do
        methods[name] = function() end
    end
    env.CreateFrame = new
    env.UIParent = new("Frame", "UIParent")
    env.UIParent:SetSize(1920, 1080)
    env.GameTooltip = new("Frame", "GameTooltip", env.UIParent)
    env.GetLocale = function() return locale or "enUS" end
    env.STANDARD_TEXT_FONT = "client-font.ttf"
    env.CANCEL = locale == "ruRU" and "Отмена" or "Cancel"
    env.SlashCmdList, env.StaticPopupDialogs = {}, {}
    env.StaticPopup_Show = function(id) mock.popup = id end
    env.print = function(message) mock.messages[#mock.messages+1] = message end
    env.InCombatLockdown = function() return mock.combat end
    env.IsShiftKeyDown = function() return mock.shift end
    env.IsControlKeyDown = function() return mock.ctrl end
    env.IsMouseButtonDown = function() return mock.middle end
    env.GetCursorPosition = function() return mock.x, mock.y end
    env.GetTime = function() return 100 end
    env.GetCursorInfo = function() if mock.cursor then return unpack(mock.cursor) end end
    env.ClearCursor = function() mock.cursor = nil end
    env.C_Spell = {
        GetSpellName = function(id) return "Spell " .. id end,
        GetSpellTexture = function() return 134400 end,
        GetSpellCooldown = function() return { startTime = 95, duration = 10, modRate = 1 } end,
        PickupSpell = function(id) mock.cursor = { "spell", 1, "spell", id } end,
    }
    env.C_Item = {
        GetItemNameByID = function(id) return "Item " .. id end,
        GetItemIconByID = function() return 134400 end,
        PickupItem = function(id) mock.cursor = { "item", id } end,
    }
    env.C_Container = { GetItemCooldown = function() return 95, 10 end }
    env.GetMacroInfo = function(name) return tostring(name), 134400 end
    env.GetMacroSpell = function() return 5487 end
    env.PickupMacro = function(name) mock.cursor = { "macro", name } end
    env.PlayerSpellsUtil = { OpenToSpellBookTab = function() mock.spellbook = true end }
    env.ClearOverrideBindings = function() assert(not mock.combat); mock.bindings = {} end
    env.SetOverrideBindingClick = function(_, _, key, button) assert(not mock.combat); mock.bindings[key] = button end
    env.RegisterStateDriver = function(frame, _, condition)
        assert(not mock.combat); mock.drivers[frame] = condition; frame:SetShown(mock.combat)
    end
    env.UnregisterStateDriver = function(frame) assert(not mock.combat); mock.drivers[frame] = nil end
    return setmetatable(mock, { __index = Mock })
end

function Mock:Load(files)
    local ns = {}
    for _, file in ipairs(files) do
        local chunk = assert(loadfile(file))
        setfenv(chunk, self.env)
        chunk("RadialCast", ns)
    end
    self.ns = ns
    return ns
end

function Mock:Event(event, ...)
    for _, frame in ipairs(self.frames) do
        if frame.events[event] then frame:Fire("OnEvent", event, ...) end
    end
end

function Mock:Login()
    self:Event("ADDON_LOADED", "RadialCast")
    self:Event("PLAYER_LOGIN")
end

function Mock:SetCombat(on)
    self.combat = on
    for frame in pairs(self.drivers) do frame:SetShown(on) end
    self:Event(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end

function Mock:Slot(index)
    local count = 0
    for _, frame in ipairs(self.frames) do
        if frame.parent == self.env.RadialCastWheel and frame.scripts.OnReceiveDrag then
            count = count + 1
            if count == index then return frame end
        end
    end
    error("Missing editor slot " .. index)
end

function Mock:Click(frame, button, down)
    local registered = false
    for _, click in ipairs(frame.clicks or {}) do
        if click == button .. (down and "Down" or "Up") or click == (down and "AnyDown" or "AnyUp") then
            registered = true
        end
    end
    if not registered then return end
    frame:Fire("PreClick", button, down)
    if not down then
        local prefix = (self.ctrl and "ctrl-" or "") .. (self.shift and "shift-" or "")
        local kind = frame.attributes[prefix .. "type"] or frame.attributes.type
        if kind and kind ~= "radialnone" then
            self.casts[#self.casts+1] = { kind, frame.attributes[prefix .. kind] or frame.attributes[kind] }
        end
    end
    frame:Fire("OnClick", button, down)
    frame:Fire("PostClick", button, down)
end

return Mock
