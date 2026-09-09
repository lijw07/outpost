# Outpost meadow starter artwork

Designed for a **1920 × 1080** composition, using **64 × 64 terrain tiles**, nearest filtering and native-pixel sprite exports.

## Playable meadow

Start a game from the menu, or open `scenes/environment/meadow_playground.tscn` and press **F6**. The meadow includes grass/soil terrain, paths and 168 saved prop instances, including all 17 animated plant types. The gold diamond is a temporary walk marker: move using your configured movement keys (default WASD), walk through plants to bend them, or click plants to brush them. Wind starts automatically with continuous motion, plants recover after contact, and walking on dirt produces dust. Walk close to flowers or mushrooms and press the displayed interaction key (default **F**) to pick them. Six types have picked artwork: white/yellow/purple flowers, clover, flowering shrubs and mushrooms. Counters show what you have collected; each patch can be picked once per preview session. The depleted plant or ground patch remains visible. Picking and counters reset when the scene reloads; these preview pickups are not saved to the world or inventory yet. Esc opens the existing pause menu.

The terrain and `meadow_dressing.tscn` are instanced into the game, so placements are also visible in the 2D editor. To rebuild the dressing, run `godot --headless --path . --script tools/art/build_meadow_playground.gd`. This is an art test area; the marker is not a finished player character.

## Side-by-side scene

Open **`scenes/environment/meadow_showcase.tscn`** in Godot's 2D editor. All **80 active assets** are saved as individually positioned nodes in labeled sections: ground tiles, grass/dirt transitions, paths, grasses, flowers, rocks, shrubs and small props. The placement scale is 2×.

Press **F6** to run it. Drag or use WASD to pan, use the wheel to zoom, press **1** for native sprite size, **2** for double size, or **Space** for the overview. Click plants to test brush movement. **R** resets the scene.

## Other review scenes

- `scenes/environment/meadow_art_lab.tscn`: searchable asset inspector with category filters, backgrounds, zoom, animation selection, play/pause, frame stepping, plant brush tests and ground dust tests.
- `scenes/environment/meadow_preview.tscn`: terrain, a connected path and scattered plants/props. Use WASD or move the mouse to brush plants; R resets it.

## Contents

- 16 ground tiles: eight grass and eight soil variations.
- 18 grass/soil transitions covering all 16 corner combinations plus patch variants.
- 16 transparent path pieces: ends, straights, bends, junctions and crossing.
- 24 grass, flower, shrub, rock and small decorative props.
- 17 plant SpriteFrames sets with wind, brush and recovery in both directions.
- Six picked-state sprites in `harvested/`, on the original sprite canvases and pivots.

Tree support is paused. Tree scenes, sprites, chopping, shaking, crown wind animations and tree-building tools are removed from the active pack and previews. They are preserved under `output/meadow/trees_paused/`, excluded from Godot import, with a snapshot of their previous integration. The ordinary `stump_old` and `branch` decorative props remain static; they have no chopping behavior.

## Terrain and vegetation

The game world uses `meadow_terrain_tileset.tres` and `scenes/world/meadow_terrain.tscn`. See [terrain setup and editor instructions](terrain_atlases/README.md). The older `meadow_tileset.tres` and `tile_sources.json` support the combined preview.

`manifest.json` contains active sprite sizes, pivots, animation rates and terrain masks. Grass corner masks use top-left=1, top-right=2, bottom-left=4, bottom-right=8. Path connections use north=1, east=2, south=4, west=8.

Attach `scripts/environment/meadow_plant.gd` to an AnimatedSprite2D with matching SpriteFrames. Use its manifest pivot as the negative offset and disable centering. Players in the `players` group trigger brush/recovery within 34 pixels; `brush_from(world_position)` also triggers it directly.

Live plants now use a per-instance continuous spring and the `meadow_foliage.gdshader` rest-texture renderer. Wind combines two frequencies with position-based phase offsets. The `wind_strength` Inspector setting defaults to **3.0**, three times the previous gentle sway; 1.0 restores that earlier strength. The speed and recovery timing remain the same. Contact applies a stronger bend and releases into damped recovery. The bottom eight pixels stay fixed. Pixel interiors remain sharp at enlarged scales, with a small filtered transition at moving edges. Timing advances through the plant controller, so pause freezes motion.

The original eight-frame wind and six-frame contact atlases are retained for source-frame inspection and fallback. The Art Lab shows those source frames; use the playground or showcase to review the current smooth motion. Set `smooth_motion = false` for the original frame-only rendering. Ground tiles remain still; `scripts/environment/meadow_footsteps.gd` provides dirt dust through `step_at(world_position)`.

## Sources and rebuilding

Source artwork was generated with ImageGen. Historical prompts remain in `prompts.json`; the built-in ImageGen prompt for the picked-state sheet is recorded in `harvested/generation.json`. The chosen master is `source/props_picked.png`; its neutral checkerboard matte is removed during slicing. Original canvas size, crop, scale and pivot are retained, though the generated remaining foliage is not an exact pixel-for-pixel subtraction. Active source sheets are under `source/`, excluded from Godot import. Archived tree prompts do not indicate active support.

With Python, Pillow and NumPy installed:

```sh
python3 tools/art/build_meadow.py
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/art/build_meadow_resources.gd
godot --headless --path . --script tools/art/build_meadow_showcase.gd
godot --headless --path . --script tools/art/build_meadow_playground.gd
godot --headless --path . scenes/environment/meadow_showcase.tscn -- --showcase-test
godot --headless --path . scenes/environment/meadow_art_lab.tscn -- --meadow-lab-test
godot --headless --path . scenes/environment/meadow_preview.tscn -- --meadow-test
```

The artwork builder validates tile dimensions, binary alpha, compatible grass/soil boundaries, path connections and anchored plant animation feet. See `terrain_atlases/README.md` for rebuilding the game's packed terrain resources, and `docs/pixel-art-plan.md` for display scaling plans.
