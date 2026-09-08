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

## Co-op

Play > Co-op opens the lobby (`scenes/ui/panels/lobby_panel.tscn`), which hosts
a server or joins one, shows an invite code, and seats up to four players.

No transport is wired up yet. `NetSession` holds the lobby state behind
`host()`, `join()` and `leave()`; the UI only reads `roster`, `invite_code` and
`role`, so dropping in a `MultiplayerPeer` — ENet for direct IP, or a Steam or
relay backend — means filling in those three methods and emitting
`roster_changed`. `join()` currently reports that no transport is configured
rather than pretending to connect.

## UI scaling

The UI is always laid out at 1920x1080 logical. Windowed mode uses
`CANVAS_ITEMS` scaling with a window resize; fullscreen uses `VIEWPORT` scaling
with `content_scale_size` and a matching `content_scale_factor`. 39 resolution
presets from 640x360 to 7680x4320 are offered, and the display resolution is
detected on first launch.

## Display safety net

Changing resolution or window mode previews the change without writing it to
disk and puts up a ten-second "keep these display settings?" prompt. Keep saves
it; Revert, or letting the timer run out, restores what you had. A setting you
cannot see well enough to undo therefore cannot get stuck.

## Generators

The theme and the blood-drip sprite frames are generated, not hand-edited. After
changing `tools/build_theme.gd`, rebuild with:

```
godot --headless --path . -s tools/build_theme.gd
godot --headless --path . -s tools/build_sprite_frames.gd
```

## Tests

Each test is a scene that prints a single `OK` or `FAILED` line and quits.

```
godot --path . tests/flow_test.tscn        # every panel has a script, buttons wired
godot --path . tests/physics_test.tscn     # the rig settles, stops, and hoists clear
godot --path . tests/bead_test.tscn        # blood beads travel the chain and reset
godot --path . tests/drip_test.tscn        # every drip is anchored to the plate
godot --path . tests/dropdown_test.tscn    # lists stay tied to the UI and fit the plate
godot --path . tests/save_test.tscn        # save slots round-trip and respect the cap
godot --path . tests/lobby_test.tscn       # hosting seats a player, ports validate, leaving resets
godot --path . tests/confirm_test.tscn     # display changes preview, then keep, revert or time out
godot --path . tests/pick_test.tscn        # an open dropdown receives hover and clicks over the content
```

Before shipping a change, wipe `.godot`, run `--headless --path . --import`,
then `--headless --editor --quit` (this catches global-class errors that a
headless run does not), then the tests above.

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
