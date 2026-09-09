# Outpost

A top-down pixel-art base-building zombie survival game built in Godot 4.7.

Up to four players hold a fortified outpost against waves of zombies, venturing
out between waves to gather resources and upgrades.

## Running

Open the project folder in Godot 4.7 and press F5, or from a terminal:

```
godot --path . 
```

## Layout

```
assets/     art, fonts, audio and the generated theme
scenes/     scene files — ui/panels, ui/components, world
scripts/    autoloads, ui controllers, world logic
tools/      headless generators run from the command line
tests/      headless and windowed verification scenes
```

## Autoloads

| Name | Script | Responsibility |
| --- | --- | --- |
| `Settings` | `scripts/autoload/settings_manager.gd` | resolution, window mode, vsync, volumes, key bindings |
| `UiAudio` | `scripts/autoload/ui_audio.gd` | wires hover and click sounds to every button in the tree |
| `SaveManager` | `scripts/autoload/save_manager.gd` | save slots under `user://saves/` |
| `GameSession` | `scripts/autoload/game_session.gd` | the chosen save and mode, and starting or leaving a run |
| `NetSession` | `scripts/autoload/net_session.gd` | co-op lobby state: host or join, the roster, the invite code |

No UI or autoload script declares `class_name` — a script with a global class
that references an autoload whose script also has one fails Godot's global-class
resolution pass. Autoloads load resources with `ResourceLoader.load()` in
`_ready()` rather than `preload()`, which fails on a project's first import.

## Menu rig

Every menu screen is one `ChainRig` (`scenes/ui/components/chain_rig.tscn`): a
single plate hung from two chains that drops in from off screen, rocks, and
settles to a stop. Panels feed it a heading, a plate width and a height, then hand it their content
with `adopt()`. A non-zero `body_height` is the plate's exact height, so a screen
does not grow or shrink with how much is inside it; set it to zero to size to
content.

The plate is one rigid body — a damped pendulum for the swing plus a pull-only
chain spring for the drop. Interacting with the UI does not disturb it, and the
motion decays to exactly zero rather than swaying forever.

The chains hang from fixed ceiling points off the top of the screen rather than
rotating with the sign, so they lean as it swings and bow with its angular
velocity.

Blood is seeded from each panel's heading, so every screen gets its own stable
arrangement of splatter decals and drip positions. Splatters stay in a band
around the frame so they never land on the text.

Dropdowns (`scripts/ui/dropdown.gd`) are in-tree controls rather than Godot
popups, so the open list rotates and translates with the sign instead of sitting
level beside it.

## Play and co-op preview

Play > Single Player selects a survivor and a world. Survivor and world lists
show their six-slot limits and paginate three entries at a time. Continue on the
title screen reopens the last valid single-player survivor/world pair; deleting
either record hides Continue. The current game is a terrain preview, so Continue
restores that selection, not a gameplay simulation or camera position.

Play > Co-op Preview selects a survivor and opens Host/Join without requiring a
local world. Hosts can choose a world with Change; Join does not use local world
selection. Networking is not connected yet: Open Server, Connect, Copy, and
Start are disabled rather than reporting a successful server or fake invite.
Back and Escape clear the lobby consistently.

## Settings and pause

Settings has Display, Audio, and Controls tabs with section-specific resets.
All ten bindings fit in two columns. Conflicting bindings offer Swap, Replace,
and Cancel; explicitly unbound actions remain unbound after restarting. Open
dropdowns support arrows, Enter, and Escape, and dialogs keep keyboard focus
inside their buttons.

Display includes Reduce Motion, which skips the sign's drop, swing, and hoist.
Escape in-game opens a pause menu with Resume, Settings, and Return to Menu.
The camera stays paused while settings are open, and HUD hints use the current
bindings. Selected survivor and world names appear in the HUD.

## Menu music

The menu plays an original 1:47 looping cue, **Last Light at the Outpost**:
muted plucked melody, low harmonies, and a sparse pulse. It fades in on entry,
continues across the menu screens, and fades out on game launch or Quit. The
Music and Master sliders control its volume. See `assets/audio/music/README.md`
for the composition details and rebuild command.

## UI scaling

The UI is always laid out at 1920x1080 logical. Windowed mode uses
`CANVAS_ITEMS` scaling with a window resize; fullscreen uses `VIEWPORT` scaling
with `content_scale_size` and a matching `content_scale_factor`. 39 resolution
presets from 640x360 to 7680x4320 are offered, and the display resolution is
detected on first launch.

## Display safety net

Changing resolution or window mode previews the change without writing it to
disk and puts up a ten-second "keep these display settings?" prompt. Keep saves
it; Revert, or letting the timer run out, restores what you had. Reset Display uses the same preview, and Escape reverts immediately. Changes
to audio or other preferences cannot accidentally save a pending display preview.

## Generators

The theme and the blood-drip sprite frames are generated, not hand-edited. After
changing `tools/build_theme.gd`, rebuild with:

```
godot --headless --path . -s tools/build_theme.gd
godot --headless --path . -s tools/build_sprite_frames.gd
```

## Tests

Run the regression suite with Python 3 and Godot installed:

```
python3 tests/run_ui_checks.py
# Or choose an executable:
python3 tests/run_ui_checks.py --godot /path/to/godot
```

The runner uses a disposable project and a separate temporary user profile.
It checks clean importing, editor loading, keyboard/modal input, binding conflicts, settings
persistence in a fresh process, display keep/revert/timeout/reset, save creation
and pagination, lobby cleanup, loading into the game, pause/resume, and Continue.
Do not run `ui_regression.gd` against your real user profile; it deliberately
creates and deletes test saves, and refuses an ordinary profile.

Use a windowed playthrough to inspect layout and motion after scene changes.
The September UI fixes were also checked in a separate rendered game instance.

## Controls

| Action | Default |
| --- | --- |
| Move | W A S D |
| Sprint | Shift |
| Interact | F |
| Attack | Left mouse |
| Build mode | B |
| Inventory | Tab |
| Pause | Escape |

All of these are rebindable in Settings > Controls.
