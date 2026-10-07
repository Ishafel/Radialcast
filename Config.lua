-- Shared configuration, ring metadata, fonts and geometry.
local ADDON, ns = ...

local L = ns.L
local BODY_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local DISPLAY_FONT = GetLocale() == "ruRU" and BODY_FONT or "Fonts\\MORPHEUS.TTF"
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\media\\"

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local SIZE = 420           -- base wheel diameter in pixels (the Size setting scales it)
local BIND = "BUTTON3"     -- middle mouse (Shift/Ctrl variants are bound automatically)

-- Defaults for the settings panel. Saved per character once changed.
-- The combat wheel's slots are live secure buttons for the whole fight,
-- so a left-click on one casts it even while the wheel is closed.
local DEFAULTS = {
    scale   = 1,      -- wheel size multiplier
    cursor  = true,   -- open at cursor (false = screen center)
    padding = 0.20,   -- wheel stays this far (fraction of screen) from every edge
    dim     = 0.35,   -- background dim while open (0 = off)
    combatCast = true,  -- BETA: hover + click casting in combat
    combatButton = "LeftButton", -- which mouse button casts in combat
    combatX = 0,      -- combat wheel offset from screen center, in pixels
    combatY = 0,
    debug   = false,  -- print selection on release
}


-- Rings, in tab order. Ctrl wins if both modifiers are held.
-- color = ring indicator text; tint = multiplier on the cyan wedge art.
local RINGS = {
    { key = "base",  label = L["Base"],  color = { 0.43, 0.84, 0.94 }, tint = { 1, 1,    1    } },
    { key = "shift", label = "Shift", color = { 0.78, 0.58, 1.00 }, tint = { 1, 0.65, 1    } },
    { key = "ctrl",  label = "Ctrl",  color = { 0.55, 1.00, 0.40 }, tint = { 1, 1,    0.43 } },
}
local RING_BY_KEY = {}
for _, r in ipairs(RINGS) do RING_BY_KEY[r.key] = r end

-- Mouse buttons that can cast from the combat wheel (middle opens it).
-- Named by physical position: on most mice Button4 is the back thumb
-- button and Button5 is forward (mouse software can remap these).
local CAST_BUTTONS = {
    { key = "LeftButton",  short = L["Left"],    verb = L["left-click"],                    tip = L["Left mouse button"] },
    { key = "RightButton", short = L["Right"],   verb = L["right-click"],                   tip = L["Right mouse button"] },
    { key = "Button4",     short = L["Back"],    verb = L["press your back thumb button"],  tip = L["Back thumb button (mouse button 4)"] },
    { key = "Button5",     short = L["Forward"], verb = L["press your forward thumb button"], tip = L["Forward thumb button (mouse button 5)"] },
}
local ALL_MOUSE = { "LeftButton", "RightButton", "MiddleButton", "Button4", "Button5" }

local TYPE_COLORS = {
    spell = { 0.72, 0.50, 1.00 },
    item  = { 0.90, 0.80, 0.55 },
    macro = { 0.85, 0.85, 0.85 },
}

------------------------------------------------------------
-- Geometry (matches the 512px art)
------------------------------------------------------------
local N         = 8
local SEG       = 2 * math.pi / N
local K         = SIZE / 512
local ICON_R    = 174 * K
local INNER_R   = 104 * K
local ICON_SIZE = 56 * K
local HIT_SIZE  = 84 * K
local atan2     = math.atan2 or function(y, x) return math.atan(y, x) end

ns.Config = {
    SIZE = SIZE,
    BIND = BIND,
    DEFAULTS = DEFAULTS,
    RINGS = RINGS,
    RING_BY_KEY = RING_BY_KEY,
    CAST_BUTTONS = CAST_BUTTONS,
    ALL_MOUSE = ALL_MOUSE,
    TYPE_COLORS = TYPE_COLORS,
    N = N,
    SEG = SEG,
    K = K,
    ICON_R = ICON_R,
    INNER_R = INNER_R,
    ICON_SIZE = ICON_SIZE,
    HIT_SIZE = HIT_SIZE,
    atan2 = atan2,
    BODY_FONT = BODY_FONT,
    DISPLAY_FONT = DISPLAY_FONT,
    MEDIA = MEDIA,
}
