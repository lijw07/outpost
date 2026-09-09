# Outpost meadow starter artwork

**Terrain implementation:** the game world now uses the sliced, paintable terrain in `meadow_terrain_tileset.tres` and `scenes/world/meadow_terrain.tscn`. See [terrain setup and editor instructions](terrain_atlases/README.md). Tree artwork remains an unapproved study and is deferred; it is excluded from the game world. The older all-art preview below is retained for reference.

Designed for the requested **1920 × 1080** composition, with **64 × 64 terrain tiles**, nearest filtering and native-pixel sprite exports. This is the first meadow art set and an interactive Godot review scene. Combat, navigation, loot persistence and multiplayer integration are separate from these reusable art controllers.

## Side-by-side scene (start here)

Open **`scenes/environment/meadow_showcase.tscn`** in Godot's 2D editor. All **103 assets are saved as actual, individually positioned nodes**: terrain tiles, transition pieces, paths, grasses, flowers, rocks, shrubs, complete trees, crowns, trunks, stumps and logs. They are arranged side by side in labeled sections at a shared 2× placement scale. No runtime gallery creation is needed to see them in the editor.

Press **F6** to run the showcase. Drag or use WASD to pan, use the mouse wheel to zoom, press **1** for native sprite size, **2** for double size, or **Space** to see the whole board. Click a plant to brush it; click a standing tree three times to fell it, then click to collect its log. **R** restores everything. Tree design remains available for review without revising it in this task.

The earlier `meadow_art_lab.tscn` is a separate inspector UI; `meadow_showcase.tscn` is the scene with every item physically placed together.

## Individual asset testing

Open `scenes/environment/meadow_art_lab.tscn` and press **F6**. The gallery contains all 103 exported assets, individually named and sized. Search or filter by category, then click an asset to inspect it.

- Zoom from 1× to 4× and drag the preview to pan; choose charcoal, light or meadow backgrounds.
- Animated assets offer play/pause, animation selection, previous/next frame and a frame slider. Frame numbers start at 1.
- Plants have left/right brush tests and automatically recover to wind.
- Select a `*_standing` tree to test hit shake, chopping, log collection and Reset asset. Individual crown, stump and log pieces can also be inspected separately.
- Ground/path/effect assets include a dust-burst test.

This standalone scene does not replace the world scene or change saves. Tree design work remains deferred; the gallery includes the current tree studies for testing.

The neighboring-tree fragments were caused by source crop boundaries cutting across an unevenly spaced sheet. `tools/art/meadow_tree_slices.json` now records transparent gutters, and the builder rejects boundaries touching visible artwork or slices containing a second separated object. Corrected crops feed all eight wind frames for each crown. Review the birch comparison and complete frame strip under `output/meadow/slice_repair/`.

To refresh only tree exports and resources:

```sh
python3 tools/art/build_meadow.py --trees-only
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/art/build_meadow_resources.gd -- --trees-only
```

To verify the gallery controls:

```sh
godot --headless --path . scenes/environment/meadow_art_lab.tscn -- --meadow-lab-test
```

## Original combined preview

Open `scenes/environment/meadow_preview.tscn` and run the current scene (F6). Move the marker with WASD or move the mouse through plants. Click a tree three times to fell it; click again to collect the log. R resets the demonstration.

The preview contains grass, flowers, shrubs, rocks, a dirt clearing, a connected path, and four layered tree species. Captures are in `output/meadow/`: `meadow_scene.png`, `meadow_tree_chop.gif`, `meadow_motion.gif`, and `meadow_catalog.png`.

## Contents

- 16 ground tiles: eight grass and eight soil variations.
- 18 grass/soil transitions, covering all 16 corner combinations with additional patch variants. Matching neighboring boundaries share exact pixels.
- 16 transparent path pieces: isolated patch, ends, straights, bends, junctions and crossing.
- 24 grass/flower/shrub/rock and small woodland props.
- Four choppable tree families: oak, birch, young oak and deadwood. Each has crown, bare trunk, exposed stump, horizontal log, standing composite and two standing join textures.
- One leaf particle chip.
- 21 SpriteFrames sets: 17 plants with wind, brush and recovery in both directions; four tree crowns with wind.

`manifest.json` contains sprite sizes, pivots, animation rates and terrain masks. `meadow_tileset.tres` is ready for Godot's terrain painting using **Match Corners**. `tile_sources.json` maps tile names to source IDs. Paths are manually paintable atlas tiles; their connection mask uses north=1, east=2, south=4, west=8. Grass corner masks use top-left=1, top-right=2, bottom-left=4, bottom-right=8.

## Matching tree states

The stump cut diameter determines the bare shaft width. Each exported horizontal log is the **same trunk pixels rotated clockwise 90 degrees**; it is not independently painted. Living bark join textures cover the cut faces while standing, then reveal the exposed wood on the final hit.

1. Standing: the crown sways while the stump remains fixed.
2. Hit: the crown/trunk pivot shakes briefly and sheds a few particles.
3. Final hit: the crown and branches drop and fade over 0.28 seconds.
4. Once the crown disappears, the bare shaft tips over 0.65 seconds and settles with a small bounce.
5. The rooted stump remains. Collecting the log hides only the fallen shaft.

Tree scenes are in `scenes/environment/meadow/`. Their controller exposes `hit(damage = 1)`, `collect_log()`, `hits_to_fell`, and the `hit_received`, `felled`, and `log_collected` signals. The demonstration uses three hits; tune this per species or tool. The falling direction is currently rightward. Crown shedding is a short falling/fading layer effect, not separately simulated branches.

## Vegetation and footsteps

Attach `scripts/environment/meadow_plant.gd` to an AnimatedSprite2D using a matching SpriteFrames resource. Use the manifest pivot as its negative offset and disable centering. Players in the `players` group trigger brush/recovery automatically within 34 pixels; the controller also exposes `brush_from(world_position)`.

Wind is an eight-frame loop at 8 fps. Each brush and recovery animation has six frames at 12 fps. Plants hold the bent pose while occupied and return to wind after the player leaves. Sprite feet stay anchored. Animation phase varies between plants.

Ground tiles stay still. `scripts/environment/meadow_footsteps.gd` supplies a small pixel dust effect via `step_at(world_position)` for dirt footfalls. The preview demonstrates that effect; the gameplay movement controller must call it at real footstep events and select surfaces from its map.

## Sources and rebuilding

Source art was created with the **built-in ImageGen tool**, then sliced, normalized onto the native grid, and prepared as binary-alpha pixel sprites. The full prompt set is saved in `prompts.json`. Generated masters are retained under `source/`, excluded from Godot import. `trees.png` and `chopped.png` are earlier studies; `tree_layers.png` is the source for the final matched tree families.

With Python, Pillow and NumPy installed:

```sh
python3 tools/art/build_meadow.py
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/art/build_meadow_resources.gd
godot --headless --path . scenes/environment/meadow_preview.tscn -- --meadow-test
```

The artwork builder checks tile dimensions, binary alpha, all compatible grass/soil boundary pairs, path connections, identical rotated log pixels and anchored animation feet. The Godot check covers plant contact/recovery, hit shake, foliage-before-trunk timing, the persistent stump and log collection. This does not establish full-game support at every display size; `docs/pixel-art-plan.md` records the remaining scaling and readability review.
