# Reusable menu equipment

These assets currently dress the four survivors in the autonomous main-menu demo. They do not create a playable inventory or equipment screen.

- Five outfit palettes: civilian, military, police, streetwear, and ghillie. Shirts, jackets, trousers, shoes, and the base backpack follow the animated body pixels.
- Directional caps, helmets, police caps, beanies, hair, earmuffs, bags, armor, and ghillie pieces. Head and torso sockets are measured for each walk, carry, build, and shooting frame, including mirrored poses.
- Sixteen melee weapons: bat, spiked bat, knife, machete, golf club, crowbar, axe, pipe, katana, sledgehammer, shovel, spear, wrench, pickaxe, hockey stick, and fire poker.
- Twelve firearms: pistol, assault rifle, sniper rifle, machine gun, rocket launcher, grenade launcher, shotgun, SMG, SCAR-style rifle, M4-style carbine, AK-style rifle, and DMR.
- Frag grenade, flashbang, smoke grenade, and flare.
- Sixteen ammunition, magazine, shell, belt, and rocket sprites. Firearm metadata defines capacity, reserve-ammo transfer, reload duration, and matching reusable ammunition assets.

The PNG sheets remain unchanged from their generated originals. `provenance.json` records the exact generation prompts and source files. `frames.json` contains 104 measured sprite regions. The source headgear sheet has a neutral background removed by the runtime shader; the other sheets use alpha cutouts.

`menu_demo_equipment.gd` loads the independent catalogs; `menu_demo_wardrobe.gd` attaches their visuals. Body head/torso registrations live in `../characters/frames.json`. Rebuild registrations with `tools/art/register_menu_characters.py` and `tools/art/register_menu_equipment.py` using Python with Pillow and NumPy. The registration tools measure pixels and write metadata without modifying the raster artwork.

Melee uses windup, contact, and recovery with coordinated hand/weapon movement. The primary melee survivor cannot fire. Guns retain independent target aiming, two-handed grips, perspective shortening, muzzle alignment, and reloads. Reloading consumes reserve ammunition; exhausted survivors visit the camp supply crate.

## Weapon pose and hat follow-up

Melee weapons are held upright beside the shoulder while idle or walking. All
sixteen use an overhead windup, downward contact, and a return to that upright
hold. Long weapons use the supporting hand during the strike. Rear-facing
strikes reach toward the target and are drawn behind the body. The raised
weapon keeps its full length in elevation rather than receiving gun-style
perspective shortening.

Firearms keep target aiming and recoil. There is no reload tilt, magazine
attachment, or reload hand animation. The existing refill delay and reserve
ammunition accounting remain in the simulation.

Zombies draw back both arms, reach toward their committed target, then recover. Damage
occurs at 42% of the 0.85-second attack cycle and only once. Survivors can evade
by leaving range or the attack direction; fences take damage at contact too.
Stuns interrupt the windup. The attacking arms replace the baked-in arms,
with upper-body lean and rear-facing occlusion.

Hats enable `cover_hair` on the base character shader. This clips the baked-in
crown under the hat, rather than trying to cover stray hair by enlarging the
entire hat. The cut follows the registered head in each frame, is bounded above
the face, and stops before raised tools outside the head. Removing a hat turns
the cut off again.

`tests/menu_hat_render_checks.gd` compares capped and uncapped base renders for
64 directional walk/carry/build/shoot frames. `capture_menu_weapon_poses.gd`
shows upright holds, overhead strikes, recoil, and zombie attacks from four
facing directions; `-- --motion` records an enlarged animation comparison.

## Jointed arm and directional weapon revision

`menu_demo_limb_rig.gd` draws rounded, shaded upper arms, cuffs, forearms, and
hands. The actor supplies shoulder/elbow/wrist poses, with separate near and far
layers. The free arm follows the walking stride and eases back to rest; overhead
grips stay attached throughout the swing. Source sleeves are masked through the
shoulder to prevent leftover pixels. Rear-facing elbows remain visible outside
the body, while hands and weapons pass behind it. Axe/knife orientation mirrors
with the swing direction.

`menu_demo_firearm_views.gd` creates cached, outlined plan-view textures for
vertical aiming, including a stock, receiver, rail, and barrel. These are
code-authored runtime views; the generated source PNG sheets are unchanged.
Side-facing weapons retain their authored art. Vertical muzzle positions follow
the center of the top view, and every firearm retains exact target aiming.

The updated comparison is `output/menu-review/jointed-arms-review.mp4`.
