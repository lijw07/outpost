# Modular survivor artwork

Original pixel-art character layers generated for Outpost with the built-in image-generation tool. The unmodified source sheets and full prompts are retained in this directory. No third-party game art is included.

The creator and playable survivor use the same compositor. Appearance is stored in each survivor save; older saves receive compatible defaults. Nothing in the creator grants armor or equipment.

## Starter customization

- Male or female base body; six skin tones.
- Crop, bob, ponytail, curls, or bald; eight hair colors.
- Six eye colors.
- T-shirt, sweatshirt, or civilian jacket; eight top colors.
- Jeans, chinos, or shorts; six pants colors.
- Sneakers, high-tops, or loafers; five shoe colors.

Skin, eyes, hair, tops, pants, and shoes are independent. The creator preview is static, with front, right, back, and left views. Name, turning, cancellation, and creation are available in the themed creator opened by **New Survivor**.

## World-acquired equipment assets

These layers are available for future loot/equipment integration and are explicitly excluded from starter creation:

- Civilian cap and small backpack.
- Military helmet, field jacket, cargo pants, combat boots, plate carrier, and rucksack.
- Ghillie hood, jacket, and trousers.

The catalog declares each equipment slot and its world-acquisition requirement. It does not add a new loot-spawning or inventory UI system in this pass. `set_appearance(profile, equipment)` on the hybrid character applies equipped assets. Hats mask hair above their brim; hair below the brim may remain visible. Ghillie hoods fully cover hair.

## Layer contract

104 directional layers represent 26 independently authored modules. Every module includes front, right, back, and left views. The two body bases share garment sockets.

| Sheet | Modules |
| --- | --- |
| base_source.png | Male and female body bases |
| hair_source.png | Crop, bob, ponytail, curls |
| tops_source.png | Tee, sweatshirt, civilian jacket, military jacket |
| bottoms_source.png | Jeans, cargo pants, sneakers, combat boots |
| civilian_source.png | Chinos, shorts, high-tops, loafers |
| gear_source.png | Cap, helmet, backpack, plate carrier |
| ghillie_source.png | Hood, jacket, trousers, field rucksack |

`atlas.json` records each source rectangle, native size, and attachment position. `tools/art/register_modular_characters.py` rebuilds this metadata without changing the source PNGs.

The runtime composes on a **72 x 96 pixel transparent canvas**, with a 72-pixel base body, a shared ground anchor at row 90, and room above the crown for hair and headwear. The renderer preserves crisp alpha and nearest filtering. Neutral grayscale garment layers retain their source shading when recolored; dark outlines are preserved. Atlas attachment positions use logical 24 x 32 units, resolved at three times that density. Gameplay compensates the sprite pixel size to preserve its original world dimensions. Eye colors occupy actual face pixels, rather than an unrelated UI swatch.

Implementation:

- `scripts/characters/appearance.gd`: permitted creator choices, defaults, save validation, and world-equipment catalog.
- `scripts/characters/compositor.gd`: layer order, recoloring, shared sockets, headwear occlusion, walking poses, bounded caches.
- `scripts/characters/preview.gd`: creator preview using the same textures as gameplay.
- `scenes/ui/panels/character_creator.tscn`: themed creator UI.
- `tests/character_creation_checks.gd`: persistence, starter restrictions, clothing combinations, directional equipment, hat clipping, walking, and game handoff.

Run `python3 tests/run_ui_checks.py --all --render` for isolated save-profile validation. `tools/art/capture_character_creator.gd` captures the creator and its saved survivor in native Godot. `tools/art/capture_modular_characters.gd` renders a directional outfit sheet. Both capture tools are development utilities; the creator itself exposes only starter choices.
