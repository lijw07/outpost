# Existing world assets for the Test Scene

73 reusable scene wrappers provide the project's existing terrain blocks, trees and tree parts, rocks, plants, mushrooms, structures, and existing house assembly with consistent placement and exact mesh collisions.

`sources.json` lists the original assets; `catalog.json` maps them to the derived `scenes/` files and records their bounds. Original gameplay scenes are preserved. The derived scenes copy all rendered mesh parts and materials, remove automatic mesh LODs, and generate one matching triangle collision shape. Full terrain blocks use base Y=0, so the whole block stands above the ground. Thin floor modules use top-surface Y=0; other models use base Y=0.

These environment colliders include the full mesh, including foliage. This is useful for checking the asset library; gameplay can choose different interaction rules separately.

To refresh these wrappers after editing their original sources, run Godot with `--headless --path . --script res://tools/city/build_existing_library.gd`, then rebuild the Test Scene using `tools/city/build_preview.gd`.
