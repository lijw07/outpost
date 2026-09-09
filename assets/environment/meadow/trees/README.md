# Simplified meadow trees

Four saved scenes: `res://scenes/environment/trees/{oak,birch,young_oak,deadwood}.tscn`.
The side-by-side test is `res://scenes/environment/meadow_tree_lab.tscn` (F6).
Click three times to chop. The whole tree falls away from the clicked side, with
branches and leaves attached. On landing it becomes one matching log and three
sticks. Point near settled drops and press F to collect them. R reloads all trees.

## Artwork

The new trees use large leaf clusters, simple bark, a shared explicit 16-color
palette, binary alpha, and 2×2 pixel blocks. Birch cream shades are reserved in
the palette. The lab enlarges them another 2× for inspection; the meadow uses
native sizes. The 1920×1080 viewport and existing 64×64 terrain are unchanged.

Each standing tree is one continuous drawing. Crown, joined shaft and joined
stump reconstruct that drawing exactly, verified during slicing. Separate cut
faces become visible only when chopped. The fallen log keeps the same shaft bark and cut faces. Earlier piece sprites
are retained as unused artwork; no fragments are spawned. Padded canvases and offsets in `catalog.json` preserve registration.
The source and exact generation prompt are recorded in `simple_art_prompt.json`.
The six dust frames and their prompt are recorded in `provenance.json`.

## Behavior and limits

Hits add a directional impulse to a damped spring, so the tree bends away from
the axe and eases back. No dust appears on hits, while falling, or when the tree lands. The full tree
above the stump cut rotates as one sprite driven by a hinged rigid body.

Ground contact has no dust effect. After 0.12 seconds the tree changes to a
matching log and three sticks. The landing remains visible, and the stump stays behind.
The log and sticks settle with physics before collection; each can be collected
once. The log awards `wood_yield` (default two), and each stick awards one wood.
Pause freezes motion and physics with the game.

A hidden isolated 3D world supplies gravity, the hinge, ground contact and drop
settling. Its positions and angles are projected into the 2D scene. Each tree has
its own ground plane; drops do not collide with players or world obstacles yet.
Tree and wood state reset on scene reload and are not saved or replicated to co-op.
Sticks reuse `../props/branch.png`.

## Rebuild and verify

From the project root, with Python/Pillow/NumPy and Godot available:

```sh
python3 tools/art/prepare_meadow_trees.py
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/art/build_meadow_trees.gd
godot --headless --path . --script tools/art/build_tree_lab.gd
godot --headless --path . --script tools/art/verify_meadow_trees.gd
godot --headless --path . --script tools/art/verify_tree_game.gd
godot --path . --resolution 1920x1080 --fixed-fps 60 scenes/environment/meadow_tree_lab.tscn -- --tree-capture
```

The physics check exercises all four species in both directions, hit cooldown,
one impact, stump retention, one log and three sticks, collection and dust cleanup. The game check
covers range, pause mid-fall, repeated collection and scene exit during transitions.
The visual capture records standing, hits, whole-tree falling, impact and drop settling
under `output/meadow/trees_physics/frames/` for review.
