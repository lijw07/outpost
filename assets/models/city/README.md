# City asset library

143 building modules, props, and vehicles remain in this catalog. All 16 terrain/floor blocks have been removed from the active city library. The canonical [blocks library](../blocks/README.md) now supplies all terrain, roads, sidewalks, transitions, and indoor floors. Indoor floor appearances are preserved.

## Placement

Standing assets use a base at local Y=0. Terrain and floor placement is documented in the blocks library.

Mount signs, roof pieces, wall decorations, and tabletop objects at their intended support height. Their base anchor does not choose that mounting height for you. `catalog.json` records each asset's bounds and anchor.

The five `wall_*_window` variants contain open spaces between their frames and mullions. They have no opaque pane or collision panel across those spaces. Separate `window_boards` remain available for intentionally boarding a window.

## Collisions

Every scene contains a combined triangle collider generated from every rendered mesh, including accumulated child transforms. It preserves holes and curved polygon wheel geometry. Back-face collision is enabled. These are environment colliders, intended for static placement.

`doorway_wood` is a single native Blockbench model and a single placeable Godot scene, replacing the old separate `door_wood` and `wall_wood_door` assets. It contains a fixed `Body` for the frame and an `AnimatableBody3D` named `Hinge` for the panelled leaf, handle, and hinges. Rotate `Hinge` around Y to move the leaf and its collision together while the frame remains fixed. `sync_to_physics` is disabled so parenting and placement stay aligned. The Test Scene demonstrates a 90-degree opening. The separate metal leaf retains its existing hinge setup.

## Source and rebuilding

`blockbench/` contains native source models, `gltf/` the exports, `textures/` the shared pixel textures, and `collision/` generated mesh shapes. `source.lock.json` preserves the historical migration receipt; `retired_terrain_blocks.json` lists the block sources subsequently retired from this library. The current local production archive is `output/barren_city/09_terrain_blocks`; earlier source revisions remain preserved alongside it. The retired separate wood door/frame Godot files are archived under `output/barren_city/02_blockbench_v4_doorway/retired_godot/`.

The sedan, van, and ambulance have reshaped bodies with raked windshields, wheel clearance, panel divisions, and fitted mirror mounts. All five vehicles use dedicated 32×32 muted paint, glass, and trim textures related to the structures' warm brown, olive, cream, and gray palette. Their four 12-sided tires and ground anchors are retained. Terrain and floor modules are managed exclusively by the blocks library.

The migration helper verifies that archive against its manifest, excludes retired terrain blocks, and refuses to replace independently edited destination files. After deliberately updating the native model, its glTF export, and source receipt, regenerate the scenes with Godot:

```sh
Godot --headless --path . --script res://tools/city/build_asset_scenes.gd
Godot --headless --path . --script res://tools/city/build_preview.gd
Godot --headless --path . --script res://tests/city_asset_collision.gd
```

Use the installed Godot executable in place of `Godot`. The generated Test Scene is `scenes/world/test_scene.tscn`. Rebuilding it replaces the generated assembly, so preserve any manual scene edits first.
