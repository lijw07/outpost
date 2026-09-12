# Outpost oak art direction

The five oak variants use crisp cube geometry and a restrained olive palette to sit beside the existing pixel characters and earthy terrain.

- Keep the original Blockbench cube positions, sizes, hidden faces, trunks, and variant silhouettes. Do not smooth, round, or subdivide the foliage.
- Use the four shared `textures/oak_leaf_*.png` tiles. Each tile is 16 × 16 pixels, with flat colors and sparse square leaf marks.
- Map one texture pixel to one Blockbench model unit. A face eight units wide must cover eight texture pixels. Repeat the texture on longer faces rather than stretching it.
- Use the light tile for upper faces, mid for south/east, shade for north/west, and deep for undersides.
- Use nearest-neighbor filtering, repeat wrapping, and no mipmaps. Keep the game's existing pixel viewport.
- Keep the existing bark texture and UV mapping. New foliage textures are separate so they cannot overwrite the trunk.
- Export native glTF at scale 16 with metallic 0 and roughness 1. Reference the shared PNGs from `../textures/`; keep editable sources in `blockbench/` and engine exports in `gltf/`.
- Avoid photographic foliage, large painted leaves, gradients, texture noise, neon greens, and rounded meshes.

## Palette

| Tile | Colors |
| --- | --- |
| Mid | `#455832`, `#526638`, `#637744` |
| Light | `#586B39`, `#687D43`, `#809450` |
| Shade | `#34452C`, `#3C5030`, `#4C6037` |
| Deep | `#2F402A`, `#3B4E30` |

The leaf tiles were generated with the built-in ImageGen tool, reduced with nearest-neighbor sampling, and restricted to this palette. The full prompt and source image are preserved in `output/tree_restyle/` for this editing session.

## Verification and recovery

All five native Blockbench models were exported through the live Blockbench MCP connection and checked in Godot. Cube dimensions, rotations, and hidden faces match the original models. The final editor import and scene capture completed without warnings or errors.

Session backups, including the unsaved live oak and tall-oak state, are in `output/tree_restyle/before/live/`. Original disk assets are in the other folders under `output/tree_restyle/before/`. Godot before/after captures are in `output/tree_restyle/review/`.

## Blockbench connection

Codex has a global `blockbench` MCP entry using `http://127.0.0.1:3000/bb-mcp`. Blockbench's installed MCP plugin must be running. A fresh Codex session can load the newly configured tools; the connection was also exercised directly during this task to inspect, edit, capture, and export all five trees.
