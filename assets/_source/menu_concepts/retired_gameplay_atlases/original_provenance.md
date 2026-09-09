# Live menu gameplay

The main menu now runs an autonomous survival sandbox in a SubViewport. Six animated survivors defend, build/repair walls, and haul timber into shared supplies while zombies attack in waves. Projectiles move through the world and resolve hits; health, breached defenses and construction progress persist until the menu world is freed. It does not access player saves, handle input, or grant progress to the playable game.

The three scenes are **Last Watch** (forest camp), **Dead Air** (roadside convoy outpost with sandbags), and **The Drowned Mile** (marsh causeway). A shuffled deck selects one per application launch, without adjacent repeats. The title menu sits on the left to keep the fort visible. Reduce Motion freezes simulation, animation and viewport updates.

## Implementation

- `menu_demo.gd`: renders and pauses the isolated world and its status label.
- `menu_demo_world.gd`: fixed 30 Hz AI, AStar routes around props/defenses, supplies, building, repair, waves, health and projectile hit resolution. Live zombies, projectiles and effects have explicit caps; corpses expire; replacement survivors preserve the job mix.
- `menu_demo_actor.gd`: run, fire, hammer, attack, hit and death visuals follow actual simulation state.
- `menu_demo_structure.gd`: construction foundations, raised wall sections and damaged defenses.
- `menu_demo_ground.gd`: uses the project's terrain and vegetation art.

This is attract-mode gameplay for the menu. It is independent of the playable world's current feature set.

## Artwork

The built-in image-generation tool produced `actors/survivor.png` (4×3 animation atlas), `actors/zombie.png` (4×2 animation atlas), and `actors/outpost_props.png` (4×2 building/prop atlas). Runtime AtlasTextures slice the original transparent PNGs. The initial painted menu concepts and their prompts are archived under `assets/_source/menu_concepts/`, excluded from Godot importing; they are no longer menu backgrounds.

## Verification

`python3 tests/run_ui_checks.py --all --render` exercises normal menu navigation as well as 120 simulated seconds per location, projectile kills, construction, supply gathering, repair/breaches, bounded entities, fresh-process rotation, live Reduce Motion and GPU captures. `tools/art/capture_menu_demo.gd` captures 36 seconds of consecutive gameplay frames from the three locations in an isolated review profile.

## Original generation prompts

### Survivor

Use case: stylized-concept. Production 2D pixel-art CHARACTER ANIMATION SPRITE SHEET for a gritty survival game. Transparent PNG background, exactly FOUR equal columns and THREE equal rows, 12 isolated sprites, rectangular canvas 1024x768. Each cell 256x256; center each character horizontally, feet baseline at cell y=224, character ~170 pixels high. No text, no grid lines, no shadows, no scenery. SAME single adult survivor in every cell, three-quarter front/right facing RIGHT, wearing faded ochre brown jacket, dark blue trousers, heavy boots, small olive backpack, short dark hair. Small sturdy realistic-proportioned pixel-art figure, strong dark outline, crisp chunky pixel clusters, muted palette, detailed readable hands and face. NOT smooth illustrations. ROW 1: FOUR sequential RUN cycle poses, feet alternately far apart then passing then opposite apart then passing; carries a small rifle across chest while running right. ROW 2: FOUR sequential rifle FIRING poses, planted feet, rifle aimed horizontally right, shoulder recoil then recovery. NO drawn muzzle flash or bullet. ROW 3: FOUR sequential BUILDING poses without rifle: holding a hammer, arm lowered, hammer lifting, hammer above head, hammer striking down in front of character to right. Strong pose differences especially legs and hammer arm. Every cell fully isolated, generous transparent margin, consistent exact character size and costume. Orthographic three-quarter RPG game camera, visible top of head and shoulders. This image is an atlas that must slice into identical 4x3 grid cells. Genuine transparent background, not a drawn checkerboard.

### Zombie

Use case: stylized-concept. Production 2D pixel-art ZOMBIE ANIMATION SPRITE SHEET for gritty survival RTS game. Genuine transparent PNG background, exactly FOUR equal columns and TWO equal rows, 8 isolated sprites, canvas 1024x512. SAME single adult undead zombie each frame, three-quarter front/right facing RIGHT, torn faded grey green shirt, ripped charcoal trousers, muddy dark shoes, grey sickly skin, tousled dark hair. Strong readable silhouette, gritty detailed crisp pixel clusters, realistic sturdy proportions, dark outline, no smooth painting. ROW 1: FOUR distinct sequential walking/lurching animation frames, arms reaching forward RIGHT, legs alternately far apart then passing then opposite apart then passing. ROW 2: FOUR sequential attack and hit reaction poses: reaching out, raised striking hand, striking forward, recoiling backward from an impact. Each frame fully isolated within its own equal cell, generous transparent margin, feet same baseline at 90% of cell height, identical sprite scale in all cells. No scene, shadows, grid lines, text, visible cell borders, blood splashes, logos or watermark. Orthographic slightly elevated RPG game view, see top of head and shoulders. Match a brown-jacket survivor sprite aesthetic. Transparent means alpha, not a drawn checkerboard.

### Fortification props

Use case: stylized-concept. Production transparent pixel-art ENVIRONMENT PROP ATLAS for an elevated three-quarter top-down zombie survival strategy game. EXACTLY four equal columns by two equal rows, 8 separate isolated objects in a perfectly regular 4x2 grid on a wide canvas 1536x768. Transparent PNG alpha. Each object entirely inside its own equal cell with 24px minimum transparent margin; each grounded near bottom of cell. Detailed gritty hand-crafted pixel art, crisp square pixel clusters, muted weathered browns, olive greens, rusty iron, dark charcoal outlines, consistent camera from south looking down at 45 degrees, same lighting. TOP ROW left to right: 1 small fortified wooden survivor cabin with corrugated metal roof and tiny warm amber lit window, front door facing viewer; 2 short horizontal wooden palisade wall section made of six pointed timber stakes, horizontal cross braces; 3 short horizontal stacked sandbag defensive wall; 4 small supply depot consisting of three wooden crates and metal ammo boxes. BOTTOM ROW left to right: 1 small timber watchtower with shelter roof and ladder, empty; 2 stone-ring campfire with orange flame; 3 pile of cut timber logs and two stumps; 4 rusty olive pickup truck viewed from elevated three-quarter side. No characters, no terrain tile, no scene background, no ground shadows beyond small self-contact shadows, no text, no numbers, no grid lines, no labels, no watermark. Objects face down/right in same RPG perspective. Genuine alpha transparency, not checkerboard illustration. Equal cell spacing so game can slice all eight props by a simple 4x2 grid.

