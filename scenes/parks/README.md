# Meadow parks

Five reusable Godot scenes assembled from the existing pixel-art modules:

| Scene | Tile footprint | Features |
| --- | --- | --- |
| meadow_commons.tscn | 12×8 | Fountain plaza, four seating areas, oak trees, flowers, lamps |
| pocket_garden.tscn | 6×5 | Reading bench, looping dirt path, lavender, berry bush |
| picnic_grove.tscn | 8×6 | Two picnic settings, meadow seating, trees and flowers |
| wildflower_walk.tscn | 10×4 | Wide gravel promenade, flower borders and benches |
| woodland_retreat.tscn | 8×8 | Winding woodland trail, rocks, ferns and resting bench |

One tile is two world units with the existing 32×32 artwork. All parks have walking surface Y=0 and full ground blocks extending to Y=-2. Replace underlying ground cells instead of stacking the park on another surface. Existing props retain their mesh collisions; generated terrain has matching triangle collisions. Named Entrances and Places markers document navigable destinations.

Meadow Commons is at (0, 0, -24) in the meadow district. Press P while playing Meadow Preview to inspect it, Home to return to the restaurant, or M for the town view. These are environment scenes; the restaurant customers do not yet visit the park.

`tools/parks/build_parks.gd` regenerates the five scenes. `tools/parks/add_to_meadow.gd` updates the park and deterministic groundcover on every available grass tile in the current district while preserving buildings and terrain transitions. Its shared layout helper is also called by the district generator. Ground underneath the commons is removed and its entrances connect to existing paths.

`tests/parks_review.gd` checks collision paths, ground coverage, and terrain collision geometry. Run with graphics enabled to refresh renders in `output/parks/review`; results are in `output/parks/validation/parks.json`.

Groundcover is grouped into MultiMesh batches with matching triangle collision instances. Trees, furnishings, roads, paths, and reserved restaurant land are excluded from district planting; the restaurant controller plants unowned grass within its own land area and clears only purchased strips.

Scatter uses saved seeded positions, continuous rotations, varied sizes, and spatial flower/fern patches. Per-tile coverage keeps the meadow dense without centering every prop on a tile. `groundcover_batch.gd` restores the saved render transforms on load, including scenes generated with the headless renderer.
