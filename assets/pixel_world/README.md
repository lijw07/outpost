# Outpost hybrid pixel world

The active menu backgrounds and playable Outpost scene now share `scripts/pixel_world/world.gd`. The existing UI theme and panel artwork remain unchanged.

## Rendering contract

- Actual 3D block terrain, building walls, roofs, fences, lights, shadows, and collision bodies.
- Orthographic camera at 45 degrees. World depth is stretched by sqrt(2), so ground tiles appear square rather than diamond shaped.
- A 640 x 360 menu viewport, nearest filtering, and a 16-pixel world unit. Gameplay uses a closer 480 x 270 view and preserves the 270-pixel vertical resolution at different aspect ratios.
- Characters are 24 pixels tall. Props use 12–40 pixel silhouettes. Equipment uses 8–20 pixel silhouettes. Characters, clothes, and footwear move together on this common grid.
- Four directional character views; upright melee rest poses; overhead melee/building poses; separate foreshortened front/back firearm views.
- Foliage, fire, and water use discrete pixel animation. Reduced Motion freezes the menu simulation and presentation. Pausing freezes the playable world.

The generated PNG sources are retained intact. `atlas.json` stores measured alpha bounds and native target sizes. `art.gd` samples those source regions with nearest filtering; it does not shrink detailed UI assets or apply a screen-wide pixelation filter. The 2D simulation remains the deterministic menu AI/combat model, while the new presentation and playable collision world are 3D.

## Art sources

Original AI-generated art, created for this project through the built-in image generation tool. Prompts are retained in `generation-prompts.json`. These are original assets inspired by broad low-resolution top-down conventions; no Core Keeper artwork is included.

| Source | Contents |
| --- | --- |
| characters_source.png | Civilian, military, police, zombie; four directions each |
| clothing_source.png | Streetwear, ghillie suit, ponytail/jacket, armor/ear defenders; four directions each |
| props_source.png | Trees, rocks, supplies, vegetation, truck, workbench, fire |
| weapons_source.png | Melee weapons, firearms, consumables, magazine/ammunition |
| gunviews_source.png | Front, back, left, and right firearm family views |
| variations_source.png | Eight additional melee silhouettes and SCAR, M4, AK, DMR, machine gun, shotgun, SMG, grenade launcher |

Run `tools/art/register_pixel_world.py` after changing source sheets. It measures source images and rebuilds metadata without editing the originals.

## World and QA

`scenes/world/game.tscn` is the active hybrid game. Its HUD is retained. The previous meadow is preserved in `scenes/environment/legacy_meadow_game.tscn` as an art-development reference, reached by the existing meadow playground. Its old art checks remain separate from `tests/pixel_world_checks.gd`, which exercises the active game, projection, collision, harvesting, and pause behavior.

Run `python3 tests/run_ui_checks.py --all --render` for isolated save-profile regression checks. Native review captures use `tools/art/capture_pixel_world.gd` in that disposable profile; options include `--variant=0`, `--variant=1`, `--variant=2`, `--game`, and `--motion`.

## Research

Core Keeper's developer explains that its world uses **3D blocks combined with 2D characters and objects**, with camera adjustments and 3D lighting. It is not an environment made entirely from modeled 3D props. Source: the September 1, 2023 “5 Core Keeper Facts!” [official Steam announcement](https://store.steampowered.com/news/posts/?enddate=1693581107&feed=steam_community_announcements).
