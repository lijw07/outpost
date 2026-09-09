ARCHIVED CONCEPT: This painted-background approach was replaced by the live gameplay demo. Runtime paths below describe the earlier implementation.

# Menu landscapes

Three dedicated pixel-art paintings generated with the built-in image-generation tool on 2026-09-09. Originals are used without visual edits. Runtime weather and lighting are authored in `assets/shaders/menu_landscape.gdshader`.

## Locations

- **Last Watch** (`last_watch.png`): forest refuge, moving flame, warm light, smoke, rising embers and drifting ground mist.
- **Dead Air** (`dead_air.png`): abandoned roadside station, diagonal rain, pavement splashes, lamp flicker and mist.
- **The Drowned Mile** (`drowned_mile.png`): flooded town at dusk, restrained water distortion, lamp flicker and mist.

Each artwork has its own scene under `scenes/ui/backgrounds/`. The central area accommodates the existing menu plate. Keep landmark coordinates aligned with the shader when replacing paintings. Import losslessly, with no mipmaps; scenes use nearest filtering.

`menu_background.gd` draws from a persistent shuffled deck (`user://menu_scenery.cfg`), visits all three before reshuffling and prevents adjacent duplicates. The selection stays fixed within one application session, including returning from gameplay. No save/world data is used. A missing or unwritable preference file never blocks opening the menu.

`menu_landscape.gd` owns each scene’s shader material and advances an explicit clock. Reduce Motion stops this clock immediately, including flame, rain, mist and water; resuming continues from the frozen frame. There is no `TIME`-driven animation bypassing the setting. Effects render entirely behind the UI and ignore pointer events.

## Generation prompts

### Last Watch

Use case: stylized-concept. Create a production game main-menu background, wide 16:9 landscape 1920x1080, for OUTPOST, a gritty top-down pixel-art zombie survival game. Premium carefully hand-crafted pixel art, crisp square pixel clusters, detailed but controlled, no photorealism or smooth painted shapes. Scene: LAST WATCH, a fortified forest refuge at blue-hour night, viewed from elevated three-quarter perspective. Composition crucial: central 44% of image will be covered by a tall game menu, so put a detailed timber watchtower and glowing amber lantern at x=82%, y=32%, palisade gate and corrugated roof cabin at left x=17%, y=47%, a small campfire on the far right x=84%,y=76%, forest paths across foreground. In the center put a quiet dark clearing, no focal subject. Layer distant hazy midnight teal fir trees, midground weathered fortifications and orange window light, large very dark close pine branches framing outer corners. Abandoned supplies, weeds and sandbags tell survival story. Strong depth, cinematic beautiful teal/amber palette, tiny stars, textured damp earth. No humans or zombies frozen in motion. No rendered rain, particles, smoke or lens flares; those will be animated in engine. No letters, logos, UI, borders or watermark. Full bleed artwork. No blur.

### Dead Air

Use case: stylized-concept. Asset: full-bleed 16:9 1920x1080 game menu background for OUTPOST, gritty pixel-art zombie survival. Create DEAD AIR, an abandoned overgrown roadside gas station in cold midnight rain weather. Meticulous premium hand-crafted pixel art with crisp square pixel clusters, cinematic dark teal versus warm amber lighting, no smooth painting or photorealism. Elevated three-quarter view. Center 44% will be covered by tall menu, so keep center quiet dark wet empty roadway leading into distant forest valley. LEFT third has derelict small gas station canopy, two vintage red fuel pumps and warm amber work lamp sheltered beneath canopy at x=18%, y=44%. Far RIGHT third has a very tall leaning wooden power pole, broken hanging cables, weathered pickup truck, weeds and a small roadside garage window glowing warm amber at x=86%,y=51%. Cracked asphalt, scattered leaves, long warm puddle reflections and overgrown guardrails in foreground; silhouettes of mountains and pine forest behind; layered misty depth but clear pixel art. Strong cinematic composition, realistic survival environment, beautiful atmospheric detail. Frame lower corners with dark pine branches. No people, zombies, UI, readable lettering, logos, watermark, large signs or borders. No drawn rain streaks or drifting smoke (will be animated in engine). Full bleed finished artwork.

### The Drowned Mile

Use case: stylized-concept. Asset: 16:9 1920x1080 full-bleed game main-menu background for OUTPOST gritty pixel-art zombie survival game. Scene: THE DROWNED MILE. A deserted flooded small town at violet-blue dusk, beautiful ominous cinematic atmosphere. Carefully hand-crafted premium pixel art, crisp square pixel clusters and detailed surfaces; no smooth painting or photorealism. Camera elevated three-quarter looking along main street into distant wooded hills. Central 44% will be covered by tall menu so center is mostly quiet dark blue flooded street and distant skyline. LEFT outer third: crumbling red brick two-storey corner store with moss, boarded windows and a warm oil lamp in the upstairs window at x=16%,y=33%; rooftop improvised refuge, rain barrels, sagging antenna. RIGHT outer third: abandoned rusted delivery van half submerged beside a leaning lamppost with amber lamp at x=85%,y=39%, broken storefront and ivy. Water occupies bottom 40% with sparse reeds, floating leaves and beautiful long gold reflections under lamps. Foreground dark reeds and broken fencing frame lower corners. Layered distant town silhouettes, mauve sky, muted teal shadows and restrained warm amber lights. No people, zombies, UI, letters, watermarks, logos or borders. No drawn rain or smoke or particles (added in engine). No huge sun or moon. High detail, evocative lived-in post-apocalyptic storytelling. Designed to match forest refuge and abandoned roadside station in same game's menu collection.

