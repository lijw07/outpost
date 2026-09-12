# Block transitions

These 54 transition blocks use the canonical [blocks library](../README.md). Their texture sources come from the original nature atlas and its matching road/sidewalk variants.

Each family has `edge`, `outer_corner`, `inner_corner`, `strip`, `end`, and `island` shapes. The first material in a filename is the block being replaced; the second is its neighbor. An edge faces -Z, an outer corner faces -Z/-X, an inner corner faces the -Z/-X diagonal, a strip faces ±X, an end faces -Z/±X, and an island faces all four sides. Rotate in 90-degree steps to fit placement.

The top is Y=2 with a base at Y=0. Curbs reach Y=2.0625. Each scene includes matching mesh collision. `catalog.json` lists all scenes and native sources; use `tools/blocks/build_terrain_transitions.gd` and `tools/blocks/export_terrain_transitions.js` to rebuild.
