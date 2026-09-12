# Test Scene

Open `test_scene.tscn` in Godot and run the current scene (F6). The project's main game scene is unchanged.

The scene contains 159 city assets and 73 existing 3D assets, plus four character sprite sets shown in four directions and 12 blood decals. The existing house is included as a reference; the new city pieces remain independent modules for building your own scenes. The wooden doorway is one placeable asset containing a fixed frame and an opening leaf.

Use the section picker to jump between the assembled room, city construction, props, vehicles, terrain, trees, tree parts, rocks, plants, mushrooms, existing structures, existing house, characters, and blood decals.

| Control | Action |
| --- | --- |
| WASD | Walk |
| Shift | Sprint |
| F | Open or close the nearest building door or demonstration door |
| R | Preview building interiors |
| C | Toggle actual mesh collision wireframes |
| Q / E | Rotate the camera |
| Mouse wheel | Zoom |
| 1–4 | Jump to the first four sections |

All 3D catalogue instances sit at Y=0. Standing models and all 16 city terrain/floor modules use a base anchor. City terrain modules are full 2×2×2 blocks; the unchanged legacy structure floors retain their surface anchor. Full terrain blocks extend upward from the ground with their sides visible. Ground geometry has cutouts under placed floor tiles so their surfaces do not overlap. The assembled room and road place their terrain course at Y=-2, keeping its top at the existing Y=0 walking height. Catalogue blocks stand at Y=0 so their full sides are visible. Objects on tables and rugs use the corresponding support height. The five city window-wall variants have open gaps and matching open collisions.

The character and blood displays are sprite references, with no invented 3D mesh colliders.

## Pixel-stable movement

Player collision movement stays on physics ticks. The camera and character interpolate the same position on render frames and align to the same native screen-pixel grid. The camera follows directly, with no trailing easing or continued drift after stopping. Teleports reset both samples immediately.

The Test Scene temporarily disables root-window content stretching and uses a scale factor of 1. This avoids the fullscreen viewport scaling path, which was shrinking the already pixel-snapped world before enlarging it again. It restores the previous display mode and scale factor when leaving the scene; saved settings and the main game are unchanged. The viewport container compensates for the actual canvas-to-screen transform, including window resizing. The artwork still uses nearest-filtered 32×32 textures.

Run `tests/test_scene_display_motion.tscn` as a normal Godot scene with `-- --scaled --after` to test the full startup and display path. It records walking, reversal, vertical movement, and stopping, then checks native render dimensions, integer screen movement, resize alignment, and restoration of settings. It measures frame pacing separately from image capture. Reports and before/after frames are in `output/barren_city/08_motion_fix`.

The older controlled-camera tests in `tests/test_scene_motion.gd` remain useful for rotation and zoom, but do not establish stability through fullscreen presentation. Frame comparisons are a bounded rendering check, not a guarantee of comfort or frame rate on every display.

## Validation

Godot checks passed for 232 grounded assets, 234 transformed mesh/collision comparisons, and 4,212 mesh-versus-physics ray checks. Additional checks cover full terrain blocks standing from Y=0 to Y=2, six open window models, door-leaf movement, clear passage through the open door, blocked passage through the closed door, and all 25 section destinations. The native 159-piece kit also passed grounding and coplanar-overlap checks.

Run `tests/city_asset_collision.gd` headlessly for geometry/physics checks. Run `tests/city_preview_walkthrough.gd` with graphics enabled for the walking and section-navigation checks. Reports and actual Godot renders are saved in `output/barren_city/03_godot/validation` and `output/barren_city/03_godot/review`.

The source Blockbench models live in `assets/models/city/blockbench`. Use the ready-to-place Godot assets in `assets/models/city/scenes` and `assets/models/test_library/scenes`.

## Furnished buildings

The section picker now includes 11 independent scenes from `scenes/buildings`: Cedar Cottage, Maple Family House, Ash Walk-up Apartments, Courtyard Apartments, Corner Grocery, Morrow Community Hospital, Ash Street Diner, The Lantern Restaurant, Fuel Stop Gas Station, Oakwood School, and District Police Station. They occupy a separate area west of the original asset displays. The original 14 sections are preserved.

Each scene contains editable modular floors, walls, furniture, hinged doors, room markers, and a roof that hides while the player is inside. Ash Walk-up Apartments has two floors connected by two walkable stair flights. Their origin is the ground-floor walking surface, with full block foundations extending down to Y=-2. R previews interiors; the building inspector's Preview Floor selects the floor when previewing a multistory building.

The hospital contains reception and waiting, pharmacy, emergency/triage with its own entrance, two treatment bays, a patient ward, staff room, washroom, medical equipment, and an ambulance. The school includes four classrooms, a library, staff office, washroom, and lockers. The police station includes reception, interview and evidence rooms, briefing space, and two holding cells. The gas station includes pumps, canopy, convenience shop, stockroom, and washroom.

Duplicate wall faces at modular junctions are trimmed within these building scenes. Affected wall instances are localized and retain their original asset path as metadata; the canonical city models are unchanged. Collisions are regenerated from the trimmed visible geometry. Furniture intersections are resolved in the layouts.

Validation passed for 82 reachable room markers, 2,571 mesh/collision geometry comparisons including hinged doors, all 11 entrances, upstairs traversal and automatic cutaways. Coplanar checks found no same-facing overlaps between separately placed assets with doors fully closed or fully open. These checks do not evaluate every intermediate door angle. Godot exterior/interior renders and reports are in `output/buildings`.

`buildings_test_scene.tscn` is an optional building-only gallery. The main `test_scene.tscn` contains the complete collection.
