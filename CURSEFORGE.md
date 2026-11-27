![FarmMode Forever](https://raw.githubusercontent.com/paradosi/FarmMode-Forever/main/media/art/logo_400.png)

**Your minimap as a big gathering map in the middle of the screen, made for WoW Forever.**

Press `/farm` (or a key) and the minimap grows into a large, see-through map where you're looking, so herb and ore nodes are easy to spot. Press it again and the minimap goes back to its corner exactly as it was.

**WoW Forever only** (interface 16001). A rewrite of FarmMode for Forever's minimap. Don't enable both: they share `/farm`.

## Features

- **One key.** `/farm`, a key binding or the addon compartment button switches farm mode on and off.
- **Resize, not scale.** The map gets bigger and shows more ground, while gathering nodes, quest markers and party dots stay their normal size.
- **Round or square**, with Blizzard's border, a thin black border, or none.
- **Opacity** from 30% to 100%, so the map can sit over the world without hiding it.
- **Zoom and position** with sliders, or drag the map where you want it.
- **Clicks go through the map** to the herb or mob under it. Hold **Alt** to drag it, ping it or zoom it.
- **Combat: close, fade or stay.** Close puts the minimap back for the fight and can bring farm mode back after; Fade dims it; Stay leaves it alone.
- **Turns itself on and off.** Remembers being on across reloads and logins, can turn on when you mount up, and can hide in dungeons, battlegrounds, cities and inns until you leave.
- **Coordinates** under the map.
- **Rotate the map as you turn** while farming, put back as it was afterwards.
- **Alternate herb and ore tracking** for herbalist-miners, every few seconds; it waits while you cast, fight, fly or are dead.
- **Hides the clutter**: zone text, tracking, calendar and other addons' minimap buttons while farming.
- **Settings window** in a navy-and-gold look: `/farm config`, or right-click the addon compartment entry.

## Slash commands

| Command | Does |
|---|---|
| `/farm` | Toggle farm mode |
| `/farm config` | Open the settings |
| `/farm square` / `/farm round` | Change the shape |
| `/farm help` | The version, the GitHub link and the commands |

Key binding: Esc > Options > Keybindings > AddOns > FarmMode Forever > Toggle Farm Mode.

## Troubleshooting

- **Clicking the map does nothing:** *Clicks go through* is on; hold Alt.
- **`/farm` does something different:** the older FarmMode is enabled too. Disable one.
- **The map is off screen:** `/farm config` > Reset defaults, or drag it back.
- **The minimap is in the wrong place afterwards:** `/reload`, and please report what you did.

## Help and bug reports

The settings window shows the installed version, and its **Help and bug reports** button gives you the GitHub address to copy. Source, full documentation and issue tracker: [github.com/paradosi/FarmMode-Forever](https://github.com/paradosi/FarmMode-Forever)

Licence: MIT. The bundled fonts (Oswald, JetBrains Mono) are under the SIL Open Font License.
