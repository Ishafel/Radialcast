# RadialCast

A radial spell wheel on middle mouse. Hold it, flick toward a spell, release to cast.

## Features

- **Three spell rings:** Base, Shift, and Ctrl. Hold a modifier while the wheel is open to swap instantly.
- **Drag and drop setup** straight from your spellbook, bags, or macros.
- **Cooldown swipes and timers** on every slot.
- **Per-character layouts** that persist across reloads.
- **Combat casting (beta):** hover a slot and click with your choice of left, right, back, or forward mouse button.

## Language

Russian WoW clients (`ruRU`) automatically use Russian interface text and messages. Other clients use English. Commands such as `/rcast`, `enable`, `disable`, and ring names (`base`, `shift`, `ctrl`) stay the same.

## Setup

1. Drop the `RadialCast` folder into `Interface/AddOns`.
2. Restart the game. WoW only detects new addon folders at launch, so `/reload` won't pick it up the first time.
3. Type `/rcast` to open settings.
4. Drag your spells onto the ring and hit **Save**.

## Commands

| Command | Description |
|---|---|
| `/rcast` | Open settings and the layout editor |
| `/rcast enable` / `/rcast disable` | Turn everything on or off |
| `/rcast enable <rings>` / `/rcast disable <rings>` | Turn specific rings on or off, e.g. `/rcast disable shift,ctrl` |
| `/rcast status` | See which rings are active |
| `/rcast reset` | Clear all rings (asks to confirm) |

Ring names: `base`, `shift`, `ctrl`.

## Combat Casting (BETA)

- Hold middle mouse, hover a slot, and click to cast. Pick the button in `/rcast` under **Cast with**: Left, Right, Back, or Forward.
- Shift and Ctrl still swap rings live in combat.
- The combat wheel opens at a fixed screen position, adjustable in `/rcast`.
- **Limitation:** WoW locks addon buttons during combat, so the wheel's slots stay clickable (invisibly) at that position for the whole fight. Clicking one with your cast button casts it even when the wheel is closed. Other mouse buttons pass through normally.
- **Why not flick-and-release?** That needs secure code this client can't currently run. Out of combat, flick-and-release works as normal.
- Combat casting can be turned off in `/rcast`.

Combat casting is still in beta, so let me know if you run into anything.

## Code structure

WoW loads the Lua files in the order listed in `Radialcast.toc`. Modules share the
addon's private namespace (the second `...` argument); no module loader or runtime
dependency is required.

| File | Responsibility |
|---|---|
| `Localization.lua` | Russian text and English fallback |
| `Config.lua` | Defaults, ring metadata, geometry, and fonts |
| `GameAPI.lua` | Spell, item, macro, and cooldown API compatibility helpers |
| `Database.lua` | Saved variables, migration, settings, and ring availability |
| `UI/Widgets.lua` | Reusable settings controls |
| `UI/WheelView.lua` | Wheel frames, slot rendering, cooldowns, and drag/drop |
| `Wheel.lua` | Transient selection state, mouse input, opening/closing, and editor placement |
| `Combat.lua` | Secure buttons, mouse bindings, and deferred combat updates |
| `Settings.lua` | Settings window and reset confirmation |
| `Commands.lua` | `/rcast` and `/radialcast` commands |
| `Radialcast.lua` | Module initialization and game lifecycle events |

The entry point initializes the view, wheel controller, combat controls, and settings
after all modules have loaded. Cross-module UI callbacks run after initialization.
`Database.data` owns persistent data, `Wheel` owns transient selection state, and
`Combat.applied` records the combat layout actually applied to secure buttons.
Combat changes stay deferred until `PLAYER_REGEN_ENABLED`; this split does not
change casting behavior.

## Development checks

From the repository root, with Lua 5.1 installed:

```sh
lua tests/smoke.lua
```

The tests use a small WoW API double and cover both locales, saved-data migration,
the editor, ring activation, release-to-cast outside combat, combat clicks, reset,
and deferred settings updates. The double rejects protected attribute/layout
changes during simulated combat. It does not emulate WoW's secure execution,
hit testing, or rendering; those still need validation in the game client.
