# Street mobility assets

30 editable assets authored and exported in Blockbench. The revised vehicles preserve the existing Outpost mesh geometry and muted 32-pixel textures. All 30 assets also have reusable Godot scenes in `scenes/`. Run `res://scenes/world/street_mobility_test.tscn`, or choose **Vehicle driving test** from the asset library, for the assembled playable street.

The supplied neighborhood image guided warm paving, lanterns, wooden slats, dark ironwork, and planted borders. Open `review/reference_street.bbmodel` for the assembled street study (`review/reference_street.png`). This is a small street-furniture study, not a recreation of the entire reference city.

Open `review/street_mobility_gallery.bbmodel` in Blockbench to inspect the complete set. Open individual files in `blockbench/` to edit or play their animations. `review/gallery.png` shows the set; `review/vehicle_movement.gif` cycles through forward wheel rotation, left steering, right steering, and reverse wheel rotation on the sedan.

## Vehicles

Sedan, van, ambulance and bus each have 15 clips. Forklift has 17, including fork raise/lower. All have four axle-centered wheel pivots, independent steering parents and a body suspension group. The forklift steers with its rear wheels; other vehicles steer with their front wheels. The model faces -Z, with Y up. The vehicle root sits at ground level.

| Clips | Intended use |
| --- | --- |
| `idle` | Subtle body vibration |
| `drive_forward`, `reverse` | Looping wheel rotation in place |
| `turn_left`, `turn_right` | Looping forward rotation with steering |
| `reverse_turn_left`, `reverse_turn_right` | Looping reverse rotation with steering |
| `steer_left`, `steer_right`, `steer_center` | Steering-only poses for blending |
| `brake` | Short body pitch and settle |
| `preview_forward`, `preview_reverse` | One-shot root translation, matched to one tire revolution |
| `preview_turn_left`, `preview_turn_right` | One-shot 45-degree curved movement demonstrations |
| `fork_raise`, `fork_lower` | Forklift only |

Drive clips complete one tire revolution per second. Tire radius is 7 Blockbench units for the road vehicles and 6 for the forklift. Export scale is 16 Blockbench units per Godot unit. The Godot driver rotates wheels from signed travel distance divided by tire radius and controls steering pivots continuously. Gameplay moves the vehicle root. The `preview_*` clips are demonstrations, not a driving controller. The native turning loops use a shared wheel rate and steering angle. The Godot controller uses a continuous bicycle steering model with a shared wheel rate; it does not simulate individual tire traction or differential wheel speeds.

## Street props

Octagonal stop sign with readable face; single and double lantern street lights; bus-stop sign with timetable; shelter with bench and timetable; round open trash can; wheelie bin with opening lid; fire hydrant; traffic cone; reflective bollard; traffic signal with separate red/amber/green poses; street bench; brick hedge and flower planters; iron fence.

All props have a ground anchor at Y=0. Street lamps include named luminous geometry and warm Godot light nodes. Traffic signals cycle red, green, and amber through their native animation poses. The wheelie bin exposes `toggle_lid()` and carries a moving lid collider. The shelter retains the opaque, tinted window style of the existing kit.

## Terrain blocks

Crosswalk, stop line, bus lane, parking bay, tactile paving, asphalt, warm paver sidewalk, dashed center line, and straight/corner curb paving. Every source is exactly 32×32×32, with bounds [-16, 0, -16] to [16, 32, 16]. The imported size is 2×2×2 Godot units. All markings are in the top texture, so they add no height or overlapping paint faces. Tile matching blocks on 32-unit centers, rotating around Y as needed. Place bases 32 units below the desired walking surface. Existing terrain and the 54-piece transition kit remain available under `assets/models/blocks/` (including `transitions/`), following the existing library reorganization.

## Validation and scope

The native validation checks group references, animation targets and time ranges, exact block bounds, ground anchors, and unchanged vehicle mesh coordinates. Blockbench sampled 250 vehicle poses. The isolated Godot import check loaded all 30 exports, sampled all 82 animation clips, verified opposite drive/reverse rotations and left/right steering, root travel direction, and ten imported 2×2×2 terrain bounds. The headless host also reported certificate/editor-settings environment warnings, unrelated to these checks.

`review/asset_inventory.json` records all 271 pre-existing native models across the eight asset libraries. This is a source inventory, not a visual audit of every existing prop. `manifest.json` records file hashes and source provenance.

## Playable Godot integration

The driving test contains all five vehicles, the complete prop/block set, a street with crossings and bus stop, and a practice yard. WASD drives, reverses and steers; Space brakes; 1–5 or the buttons select a vehicle; Tab selects the next vehicle; R resets; Q/E lower/raise forklift forks; N changes day/dusk; P opens the overview; Escape returns to the asset library.

Vehicle scenes use a kinematic `CharacterBody3D` driver, a convex body collider, four tire colliders, and separate moving fork colliders. Braking stops at obstacles without storing speed, and reversing can release a vehicle from a wall. Static fixtures and terrain use mesh-matching triangle collision. Enable `controlled` for player input, or use `set_commands()` for scripted control. Native AnimationPlayer clips remain available in the model; the driving controller applies wheel, steering and suspension poses directly while driving.

The standalone driving test remains available. The main Meadow restaurant scene now uses these vehicles for automatic lane-following traffic, signals, stop signs, crossing priority, vehicle spacing and bus-stop dwell. Entering/exiting cars, passenger simulation, emergency response and police enforcement are not implemented. See `scenes/world/MEADOW_RESTAURANT.md` for the integrated traffic rules.

The physics regression checks pass 47 assertions across all five vehicles, including forward/reverse travel, steering direction, braking, wheel motion, fork/collider alignment and wall recovery. The rendered playthrough passes 25 checks for mouse selection, driving/reversing/steering, braking, forklift controls, day/dusk, overview, animated bin collision and traffic-light phases. Screenshots and both reports are under `output/street_mobility/`.

Rebuild with `tools/city/build_street_mobility.js` evaluated in Blockbench, then `tools/city/review_street_mobility.js`, `tools/city/review_reference_street.js` and `tools/city/capture_street_mobility.js`. Run `tools/city/validate_street_mobility.py` and `tests/street_mobility_import.gd` to refresh validation. The builder creates its own projects and stops if the active project changes during a build.

Rebuild Godot scenes with `godot --headless --path . --script res://tools/city/integrate_street_mobility.gd`. Validate physics with `tests/street_mobility_drive.gd` and rendered controls with `tests/street_mobility_playthrough.gd` (graphics required).
