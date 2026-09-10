# Live menu gameplay

The menu runs an autonomous survival sandbox in a separate viewport. Survivors
defend, build and repair walls, and haul timber while zombies attack in waves.
It does not access player saves, handle input, or grant progress to the playable game.

Three locations rotate across application launches: Last Watch (forest camp),
Dead Air (roadside outpost), and The Drowned Mile (marsh causeway). Returning to
this menu preserves the current session's location. Reduce Motion freezes the
whole simulation and its rendered frame.

## Art and perspective

The camera uses an elevated, top-down 2.5D presentation: visible roof and front
surfaces, grounded sprite pivots, shadows, and depth sorted at ground contact.
The world renders at 960×540 and enlarges with nearest-neighbor filtering,
keeping a common two-pixel presentation grid at the 1920×1080 design size.
Trees reuse the meadow's native artwork and registration, with a crisp dark
outline shader. Trees and rocks reserve full visual bounds so their artwork
cannot overlap one another or camp props. Construction uses discrete, fixed-size
wall sections rather than stretching artwork.

Five transparent character sheets provide 80 directional walk, carry, build,
and zombie death poses, generated with the built-in image-generation tool.
Exact prompts and source identifiers are in `characters/provenance.json` and
`action_provenance.json`. Each sheet contains front, right, back, and left rows
with strong dark outlines and an intact, shared ochre/olive palette.
`tools/art/register_menu_characters.py` measures their connected silhouettes and
writes `characters/frames.json`; it does not edit the source artwork. Each frame
is registered to its waist and foot baseline, preserving consistent scale.
The engine chooses direction from actual motion or aiming, and advances walking
frames by distance travelled. Stationary characters do not walk in place.

Front/back strides alternate their contact leg; neutral and working poses keep
feet planted. Carried timber is drawn in the character's two-handed grip.
Construction has rest, raised hammer, contact, and recovery poses. Zombies reel,
buckle, fall, and remain prone before fading; standing sprites are not rotated.

`camp/outlined_camp.png` supplies ten outlined 2.5D props: cabin, lookout,
crates, timber, truck, fire, and horizontal/vertical timber and sandbag defenses.
`camp/frames.json` holds measured bounds; `menu_demo_art.gd` shares atlas frames.
Buildings preserve their proportions, and construction reveals fixed-size fence
sections on contact. Small work-site supplies and muzzle flashes use pixel drawings.
The discarded detailed
atlases and their prompts are archived in `assets/_source/menu_concepts/`, outside
Godot's imported assets.

The new `characters/survivor_shoot.png` sheet adds sixteen directional aim,
recoil, settle, and recovery poses, bringing the character total to 96 frames.
Shots trigger a single firing cycle; the rifle is drawn in the pose, and flash
and projectile origins use measured muzzle anchors. Source artwork is retained
unchanged. This RGB sheet uses an opt-in neutral-background key in the actor
shader; other animation clips retain their original alpha behavior. The exact
built-in ImageGen prompts and source identifiers are in
`characters/shooting_provenance.json`.

`characters/survivor_move_shoot.png` adds sixteen armed walking poses, bringing
the character total to 112 frames. Strides follow distance traveled independently
of firing; backing away reverses the gait while the rifle remains aimed at the
enemy. Stopping returns to planted firing poses. A small upper-body recoil keeps
the feet anchored, and projectiles use the current moving pose's muzzle anchor.
Ranged survivors begin retreating at 180 units, before close-range engagement.
The exact built-in ImageGen prompt is in
`characters/moving_shooting_provenance.json`.

All three locations include bounded, seeded patches of existing meadow grass,
clover, ferns, flowers, mushrooms, pebbles, and fallen branches. Decorations stay
outside roads, water, construction footprints, and the working camp clearing.
Grass responds to wind and passing characters. Its clock advances only with the
menu simulation, so Reduce Motion freezes it along with the actors. These small
props are nonblocking; their placement does not change navigation or combat RNG.

## Simulation

- `menu_demo.gd`: viewport, status, and Reduce Motion.
- `menu_demo_world.gd`: fixed-step AI, navigation, collision, construction,
  resource deliveries, waves, health, projectiles, and bounded cleanup.
- `menu_demo_actor.gd`: registered directional frames and action visuals.
- `menu_demo_ground.gd`: native meadow tiles with matching edge transitions.
- `menu_demo_scatter.gd`: small ground props, wind, and contact bending.

Navigation checks a complete body path around wall corners, buildings, trunks,
and rocks. Workers reserve separate jobs and loading positions. Work positions
remain outside the completed wall footprint. All teams share body separation.
Projectiles originate at the visible muzzle; opaque props block firing lines.
Builders load material at the depot, carry it to a reserved work site, and spend
one item per hammer contact. Recovery cannot spend the same strike twice.

## Verification

`python3 tests/run_ui_checks.py --all --render` checks menu navigation, scene
loading, warnings, four simulated minutes per location, worker stalls, scenery
and body overlap, construction, hauling, combat, bounded entities, persistent
rotation, Reduce Motion, and GPU captures at multiple window shapes.
`tools/art/capture_menu_demo.gd` records 36 seconds of consecutive gameplay from
all three scenes in a disposable review profile.
`tools/art/capture_menu_actions.gd` renders sixteen enlarged action poses to
review foot registration, timber grip, hammer contact, and the collapse sequence.

`tools/art/verify_menu_shooting.gd` checks all four firing directions, recoil
timing, muzzle bounds, decoration placement, foliage pause/contact behavior, and
combat in all three locations. With a graphical renderer it also saves action
and world captures into `output/menu-shooting/`. These additions affect only the
animated menu world; the rejected meadow art experiment remains removed.

## Modular equipment and movement follow-up

The demo now caps survivors at four. See `equipment/README.md` for the clothing,
weapons, throwables, and ammunition catalogs. Equipped firearms use separate
sprites attached to animated hand grips; the original authored rifle clips
remain available for unmodularized actors. Headgear, bags, and armor follow
per-frame head/torso sockets instead of fixed screen offsets. A designated melee
survivor uses windup/contact/recovery attacks and cannot fire bullets.

Active body detours retain their collision constraints during route smoothing.
Passing-side persistence and short target commitment prevent repeated steering
reversals. Zombies start beyond the visible frame, including their full height.

`tests/menu_equipment_checks.gd` covers attachments, melee timing, firearm identity,
magazines, reloads, resupply, and detour smoothing. `capture_menu_live_review.gd`
records the actual menu through Godot Movie Maker at 60 fps with synchronized
audio. It runs only in a disposable test profile.
