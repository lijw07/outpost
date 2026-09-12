# Canonical block library

All terrain and floor blocks live here. Use `scripts/world/block_library.gd` to resolve semantic names to these scenes. City assets are reserved for buildings, furnishings, props, and vehicles.

## Existing blocks

`grass_block`, `grass_flowers_block`, `dirt_block`, `sand_block`, and `stone_block` retain their original Blockbench models, glTF meshes, and shared `assets/models/shared/textures/terrain_atlas.png`. Their scenes now include collision and placement metadata for direct placement as well as GridMap use.

## Theme-matched additions

`road_block`, `road_lane_block`, `road_crossing_block`, `sidewalk_block`, and `gravel_block` use the existing stone cube geometry. Gravel retains the shared atlas texture treatment. Following the user's town reference, roads use quiet warm charcoal, thin golden yellow dashes, and separate cream crossing paint. Sidewalks have warm beige, staggered 16-pixel slabs with subtle expansion joints. These are new variants of the blocks kit, not relocated city terrain.

Eight indoor `floor_*_block` assets retain their existing wood, tile, carpet, and concrete appearance, as requested. Their source geometry and finishes were moved into this library unchanged.

All blocks are 32×32×32 model units, or 2×2×2 Godot units, with base Y=0. Place their bases at Y=-2 for a walking surface at Y=0. Nearest texture filtering preserves the pixel scale.

## Transitions and placed terrain

`transitions/` contains 54 edge, corner, strip, end, and island variants rebuilt from this library's texture sources. Grass sides retain the original dirt-and-turf appearance. Road/sidewalk transitions include a one-pixel curb with matching collision.

The meadow restaurant district, five park scenes, restaurant garden plots, building floors, and the terrain review scene all resolve blocks through this library. The original city-folder block scenes, exports, models, and collision files are retired from active assets. Historical rejected files are under the ignored `output/blocks_correction/rejected_city_blocks/` directory.

`scripts/world/meadow_street_markings.gd` places three crossings at the main district junction plus two waterfront crossings, and clears lane dashes through the junction. District transition application preserves this layout on regeneration. Crossings rotate their paint to follow each approach while keeping their curbs facing neighboring sidewalks.

Terrain joining also reads aligned neighboring GridMaps in the Meadow district, including translated park, plaza, and waterfront scenes. This preserves curbs and grass/path edges across separately assembled areas. Tiles on other height levels do not affect ground-level joins. `tests/terrain_district_seams.gd` checks both sides of a scene boundary and repeatable assembly.

Run `scenes/world/terrain_transitions_preview.tscn` for a visual review. B switches between plain and joined blocks; 1–3 choose views; Q/E orbit and the wheel zooms.

## Rebuilding

1. Run Godot with `--headless --path . --script res://tools/blocks/build_textures.gd`.
2. Run `python3 tools/blocks/build_sources.py` and let Godot import the generated assets.
3. Run Godot with `--headless --path . --script res://tools/blocks/build_terrain_transitions.gd`.
4. For editable transition source exports, run `tools/blocks/export_terrain_transitions.js` through Blockbench in a dedicated Generic Model project named **Outpost terrain transitions**. The exporter restores the previously selected project.
5. Run `tools/blocks/replace_placed_blocks.gd` in Godot to replace terrain meshes in existing park and district GridMaps while preserving their cells and placed objects. Future district, park, tower, and building builders already resolve to this library.

`tests/terrain_transitions.gd` verifies imported transition bounds, 55,296 collision heights, all 256 grass/dirt neighbor combinations, placement preservation, and repeatability. `tests/restaurant_smoke.gd -- --restaurant-test` checks the live restaurant loads without changing its saved game.

`source.lock.json` records the current library's source hashes and provenance. Original nature models and the original shared atlas are unchanged; no external assets were used.
