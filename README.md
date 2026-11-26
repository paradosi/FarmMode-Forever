<p align="center"><img src="https://raw.githubusercontent.com/paradosi/FarmMode-Forever/main/media/art/logo_400.png" width="160" alt="FarmMode Forever logo"></p>

# FarmMode Forever

Turns the minimap into a big gathering map in the middle of your screen, and puts it back exactly as it was when you are done. Written for **WoW Forever** only.

It is a rewrite of [FarmMode](https://github.com/paradosi/FarmMode) for Forever's Retail-engine minimap, with a square shape, a real resize and combat handling added.

> [!NOTE]
> Version 0.1.0 has not been run in game yet. If the minimap ends up somewhere odd, `/reload` puts Blizzard's minimap back.

## Features

- **One key.** `/farm`, a key binding or the addon compartment button switches farm mode on and off.
- **Resize, not scale.** The minimap gets bigger and shows more ground. Gathering nodes, quest markers and party dots stay their normal size, so they're easy to read across a large map.
- **Round or square**, with Blizzard's border, a thin black border, or no border at all.
- **Opacity** from 30% to 100%, so the map can sit over the middle of the screen without hiding the world.
- **Zoom and position.** You can set them with the sliders, or turn on dragging and move the map with the mouse.
- **Clicks go through the map.** A big map in the middle of the screen would catch clicks meant for the herb or mob under it, so it lets them through. Hold **Alt** to drag it, ping it or zoom it with the wheel.
- **Combat: close, fade or stay.** *Close* puts the minimap back in its corner for the fight and (optionally) brings farm mode back after. *Fade* keeps it where it is at low opacity. *Stay* leaves it alone.
- **Turns itself on and off.** It can remember being on across `/reload` and logins, turn on when you mount up, and hide in dungeons, battlegrounds, cities and inns, coming back when you leave. `/farm` still opens it in those places if you want it there.
- **Coordinates** under the map.
- **Rotate the map as you turn** while farming: Blizzard's *Rotate Minimap*, put back as it was afterwards.
- **Alternates herb and ore tracking.** Vanilla tracks one resource at a time; with Herbalism and Mining, farm mode can switch between Find Herbs and Find Minerals every few seconds. It waits while you cast, fight, ride a taxi or are dead.
- **Hides the clutter.** Optionally hides the zone text, tracking, calendar, addon compartment, Blizzard's event button and other addons' minimap buttons while farming. Only what farm mode hid is shown again.
- **Exact restore.** Turning farm mode off puts back the minimap's anchors, size, border art, mask, opacity and zoom.

## Requirements

| | |
|---|---|
| Client | WoW Forever (Interface 16001) |
| Libraries | none |
| Conflicts | the classic **FarmMode**: both use `/farm` and move the minimap. Enable one or the other (FarmMode Forever warns at login if both are on) |

## Installation

Copy the `FarmModeForever` folder into `World of Warcraft\_forever_\Interface\AddOns\` and `/reload` (or restart the game).

## Usage

| Command | Does |
|---|---|
| `/farm` | Toggle farm mode |
| `/farm config` | Open the options (also `options`, `settings`) |
| `/farm square`, `/farm round` | Change the shape |
| `/farm help` | List the commands |

- **Key binding**: *Esc → Options → Keybindings → AddOns → FarmMode Forever → Toggle Farm Mode*.
- **Addon compartment** (the button by the minimap): left-click toggles, right-click opens the options.

### Examples

- *A big see-through square for herbing*: `/farm config`, then **Square**, Size 500, Opacity 60%. Turn on *Hide minimap buttons*.
- *Move it once and leave it there*: turn farm mode on, drag the map to where you want it, and let go. The position is saved, and the sliders follow.
- *Stay in farm mode through fights*: untick *Close farm mode when combat starts*.

## Settings

All settings are per account (`FarmModeForeverDB`) and take effect immediately while farm mode is on.

| Setting | Default | Range | Notes |
|---|---|---|---|
| Size | 400 px | 140–700 | The minimap's own width and height. Blizzard's is 198 |
| Zoom | 0 | 0–5 | 0 is farthest out. Clamped to what the client offers |
| Opacity | 100% | 30–100% | Applies to the whole minimap, border included |
| Left / Right | 0 | −900–900 | Offset of the map's centre from the screen's centre |
| Down / Up | 150 | −600–600 | Same, vertically |
| Shape | Round | Round, Square | |
| Show the border | on | | Blizzard's ring when round, a 2 px black frame when square |
| Drag the map to move it | on | | Left-drag. The position is saved on release |
| Hide minimap buttons | off | | See *Features* |
| Clicks go through (hold Alt to use it) | on | | While farming, the map takes the mouse only with Alt held |
| Show coordinates | on | | Under the map. Blank in instances, which have no map position |
| Rotate the map as you turn | off | | Turns on Blizzard's *Rotate Minimap* while farming, puts it back after (and at logout) |
| In combat | Close | Close, Fade, Stay | |
| Open it again when combat ends | on | | *Close* only |
| Opacity in combat | 20% | 0–80% | *Fade* only |
| Remember it across reloads and logins | on | | |
| Turn on when you mount up | off | | Dismounting leaves it on: you dismount to gather |
| Hide in dungeons and battlegrounds | on | | Any instance |
| Hide in cities and inns | off | | Anywhere you're resting |
| Alternate herb and ore tracking | off | | Needs Herbalism and Mining |
| Every | 5 s | 3–15 s | How often it switches |

**Reset defaults** puts every setting back to these values. The settings window scrolls with the mouse wheel; over a slider, the wheel moves the slider.

## How it works

The work is in `Core.lua`.

**Wanted vs shown.** The addon keeps two states apart: whether you *want* farm mode (`/farm`, the key binding, mounting up, or remembered from last session) and whether it is *on screen*. `Reconcile()` makes the second follow the first unless something blocks it: combat in *Close* mode, an instance, or a resting area. So a fight or a capital puts the minimap back, and it returns by itself afterwards. Turning it on by hand inside a blocked place overrides that block until you leave the place. During combat lockdown nothing moves: a press flips the intent (so a second press cancels the first), and the change happens when combat ends.

The steps of switching on and off: `Options.lua` only draws the settings panel, in the wowdb.dev look shared with Forever Alts and Nightclaw Ears (`Theme.lua`).

1. **Snapshot.** Before changing anything, farm mode records the minimap's anchors, size, opacity and zoom. It also records the size and visibility of Blizzard's border art (`MinimapBackdrop`, `MinimapCompassTexture`, `MinimapCompassTextureUnderlay`) and the anchors of the zoom buttons.
2. **Look.** The minimap is resized with `SetSize`. The border art is a child of the minimap that was drawn for a 198 px map, so it is scaled by the same factor (`size / 198`), and so are the zoom buttons' offsets. *Square* swaps the mask for a plain white texture, hides Blizzard's ring and shows a frame of four textures. The zoom is then stepped away and back, which is what makes the minimap redraw after a resize or a mask change.
3. **Position.** The saved offsets are in UIParent units. They are converted to the minimap's own scale, which includes the Edit Mode minimap size, and the map is anchored to the screen's centre.
4. **Restore.** Everything from the snapshot is put back in reverse.

Dragging is driven by an `OnUpdate` on a frame of the addon's own. Blizzard uses the minimap's own `OnUpdate` for its mouseover tooltip.

Blizzard re-applies its minimap look (mask, border art, sizes) in `MinimapCluster:UpdateMinimapConfig()` whenever the *Rotate Minimap* option changes. A `hooksecurefunc` on it re-takes the art sizes and re-applies farm mode's look if farm mode is on.

Combat uses `PLAYER_REGEN_DISABLED`, which fires just before combat lockdown starts, so the minimap can still be moved. A toggle pressed during combat is remembered and carried out on `PLAYER_REGEN_ENABLED`.

**Click-through** turns the minimap's mouse and wheel (and its zoom-button hit area) off while farming and back on while Alt is held (`MODIFIER_STATE_CHANGED`). A drag in progress keeps the mouse, and stops itself if the button is released while the map no longer gets mouse events.

**Tracking swap** finds Find Herbs (spells 2383, 8387) and Find Minerals (2580, 8388) in `C_Minimap.GetTrackingInfo` and turns the inactive one on with `C_Minimap.SetTracking`, as Blizzard's tracking menu does. `UnitCastingInfo` can return secret values on Forever, so casting is detected with `type()`, never by truthiness.

**Coordinates** come from `C_Map.GetPlayerMapPosition` five times a second while shown, guarded with `canaccessvalue`.

## Design decisions

- **A new addon, not a fourth flavour of FarmMode.** FarmMode keeps one codebase running on TBC, Classic Era, Retail and Forever, and its published users are on all of them. Forever's minimap is Retail's, with its own art (`Blizzard_Minimap/Camelot`). Writing for that one client removed every version guard and made shape and resize practical.
- **Resize instead of scale.** Scaling (what FarmMode does) enlarges the icons along with the map. Resizing keeps icons readable and shows more terrain at the same zoom. The trade-off is that the border art has to be scaled by hand.
- **Restore by snapshot, not by asking Blizzard.** Calling `MinimapCluster:UpdateMinimapConfig()` would also reset the look, but calling Blizzard's Edit Mode-managed code from an addon risks taint. Farm mode only sets values it recorded itself.
- **Toggles wait for the end of combat.** Only the moment before lockdown is known to be safe for moving the minimap.
- **Dismounting doesn't switch it off.** You dismount to gather, so an automatic off on dismount would close the map at every node.
- **Click-through on by default, with Alt.** The map's whole point is to sit where you are looking, which is also where you click.
- **No libraries.** The addon toggles constantly and should cost nothing while idle.

## Troubleshooting

| Problem | Fix |
|---|---|
| `/farm` does something different | The classic FarmMode is also enabled. Disable one of them |
| Clicking the map does nothing | *Clicks go through* is on: hold Alt |
| Tracking doesn't alternate | You need both Herbalism and Mining. It also waits while you cast, fight, ride a taxi or are dead. If it never switches, Forever may not allow it from an addon: please report it |
| The map is off screen | `/farm config` → **Reset Defaults**, or drag it back |
| The map looks blank or stale after a change | Zoom in and out once with the mouse wheel. Farm mode does this itself, but report it if it happens |
| Another addon's minimap button stays visible | Only LibDBIcon buttons (named `LibDBIcon10_*`) are recognised |
| The minimap is in the wrong place after farm mode | `/reload`. Please report what you did, since farm mode is meant to restore it exactly |

## Development

There is no build step. From `~/projects/wowaddons`:

```sh
./check FarmMode-Forever             # syntax, luacheck, TOC lint, Forever API scan
./check FarmMode-Forever --package   # also build the release zip and inspect it
cd FarmMode-Forever && lua5.1 tests/smoke.lua   # headless run against a stubbed WoW API
```

`tests/smoke.lua` loads the addon in TOC order against stubs and plays through toggling, shapes, all three combat modes, cities, dungeons, mounting, rotate, click-through, coordinates, the tracking swap and logout, checking the minimap's state after each step. It draws nothing, so layout still needs the game. It is not shipped.

| Path | Holds |
|---|---|
| `FarmModeForever.toc` | Forever TOC (16001) |
| `Core.lua` | Wanted/shown state, snapshot, look, position, drag, click-through, buttons, coordinates, tracking swap, combat, slash command |
| `tests/smoke.lua` | Headless test (not shipped) |
| `Theme.lua` | wowdb.dev's look (colours, fonts, borders, hover glow), copied from Forever Alts and trimmed |
| `Options.lua` | The settings panel, built on `Theme.lua` |
| `media/fonts/` | Oswald and JetBrains Mono (SIL OFL; the licence files ship with them) |
| `Bindings.xml` | The key binding (loaded by the client, not listed in the TOC) |
| `media/textures/logo.tga` | Icon, shipped |
| `media/art/logo.svg` | Logo source. Render with `rsvg-convert -w 400` / `-w 64`; the TGA comes from the 64 px PNG via Pillow (`uv run --with pillow`) |
| `media/art/*.png` | Rendered logo for the README, not shipped |

## License

MIT. See [LICENSE](LICENSE). The fonts in `media/fonts` are under the SIL Open Font License (`OFL-*.txt` beside them).
