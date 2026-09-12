# Outpost terrain textures

Texture work must preserve the user's models. Do not change geometry, cube sizes, positions, rotations, topology, UV mappings, collisions, scene placement, or camera settings without a separate request.

Use the shared `textures/terrain_atlas.png`, which matches the oak foliage's muted olive palette and crisp pixel rendering. Grass should have restrained blade clusters, dirt should use warm desaturated browns, sand should be subdued tan, and stone should use low-contrast gray-green planes. Avoid photographic noise, gradients, neon greens, bright gold sand, and glossy shading.

The atlas stays at **64 × 168 pixels**, with two 32-pixel columns. Left is the upper surface; right is the side surface. Keep these regions fixed:

| Pixel rows | Material |
| --- | --- |
| 0–31 | Grass |
| 32–63 | Grass with small cream flowers |
| 64–95 | Dirt |
| 96–127 | Sand |
| 128–159 | Stone |
| 160–167 | Existing vegetation, flower, earth, and rock swatches |

Use nearest-neighbor texture filtering and no mipmaps. Preserve the original alpha mask and swatch locations. The 11 Blockbench terrain files and their Godot exports already reference the shared PNG externally. Update that PNG directly; keep every model file unchanged. No geometry re-export or embedded texture update is needed.

Primary colors:

- Grass: `#455832`, `#526638`, `#637744`.
- Dirt: `#41392F`, `#514536`, `#685740`, `#827762`.
- Sand: `#917D57`, `#A48D62`, `#B4A074`.
- Stone: `#53594F`, `#656961`, `#7C8076`.
- Flower petals: `#CBC79C`.

The source was edited with the built-in ImageGen tool, fitted to the original atlas regions, reduced with nearest-neighbor sampling, and restricted to the material palettes. The full generation prompt, source, backups, verification record, and in-engine before/after captures are in `output/terrain_restyle/` for this session.
