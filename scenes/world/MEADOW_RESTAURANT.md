# Meadow & Main: restaurant prototype

Open and run **`scenes/world/meadow_preview.tscn` (F6)**. This is the single playable entry scene for the meadow restaurant test. Its script extends `Control` directly; there is no restaurant base script or inherited preview. The town, camera, lighting, and HUD are present in its saved scene tree. Buildings, parks, waterfront, and HUD remain reusable child scenes. Restaurant furniture and owned land are populated from the starter layout or saved progress when playing. The main game and the separate all-assets Test Scene are unchanged.

Start with a 6×6-block restaurant, two tables and two separate chairs, a small kitchen, one chef, one waiter, and 180 coins. Existing character sprites stand in for customers and staff. Customers arrive from the street, take a seat, order soup, wait for cooking and delivery, eat, pay, and leave. The waiter walks to the kitchen to collect each order, then brings it to the table. There is no controllable player character.

## Controls

- **Build & Decorate / B:** pause service and open the shop.
- **Furniture & walls:** purchase tables, chairs, stoves, counters, refrigerators, bookshelves, walls, corners, and open doorways.
- **Plants & garden:** purchase daisies, lavender, ferns, grass, tall grass, shrubs, berry bushes, and young oak trees.
- **Left click:** place the selected item on the grid.
- **R:** rotate. **Right click / Escape:** finish building.
- **Reclaim:** remove unused furniture for a 75% refund.
- **Floor finish:** switch a tile between wood and patterned flooring, free in this prototype.
- **WASD / middle drag:** pan the management camera. **Wheel:** zoom.
- **Home:** return to the starter restaurant. **M:** view the district and skyline. **P:** visit Meadow Commons. **V:** visit the waterfront.
- **C:** pause/resume new customer arrivals. Seated customers finish their meals.
- **Land expansion:** leave building mode, hover over neighboring land to see the exact tile grid and price, then click the plot to purchase it. Buy adjacent plots in order. Hovering never spends coins.

Placement rejects occupied cells, locked property, blocked entrances, inaccessible seats and kitchens, and routes that would trap an existing customer or staff member. Doorways stay open and route people through their opening. Building mode pauses guests and staff; land purchases can happen during service. The purchase does not move or zoom the camera.

## Expansion and equipment

Hover directly outside any of the four restaurant edges. Only the next single row or column is highlighted. For example:

- 6×6 → buy right/left → 7×6 (one 1×6 strip).
- 7×6 → buy back → 7×7 (one 7×1 strip).
- 7×7 → buy left/right → 8×7 (one 1×7 strip).

Land costs 25 coins per tile. The hover label shows the full strip price before clicking. Buying left or back changes the owned origin; furniture stays at its world position, walls move to the new boundary, and new floor replaces existing terrain. Public streets, the park, and other scenery bound the available land.

Reaching Fern & Flour adds a clearly labeled 1,200-coin business acquisition charge to that strip. The building and its collisions are removed, but only the purchased column becomes buildable. Remaining columns must still be purchased separately. No hover, unaffordable click, or click on already-owned land spends money.

There are no kitchen upgrades or land-purchase menus. Grow capacity by purchasing equipment. Cooking takes 5.5 seconds and each finished meal pays 28 coins once. Legacy kitchen levels are ignored.

Progress saves to the separate `meadow_restaurant_prototype_v1.json` file. The data format now stores all four ownership boundaries. Earlier saves migrate without losing purchased land, furniture, or money.

## Meadow town

Thirteen background buildings plus the purchasable neighboring shop and harbor office surround the player's restaurant: houses, grocery, diner, hospital, police station, school, courtyard apartments, a gas station, six-floor residences, and a twelve-floor hotel. The tower scenes contain separate furnished levels; their upper floors can be inspected with Interior Preview and Preview Floor in the building inspector. Background hotel/apartment residents, lifts, and upper-floor business simulation are not implemented in this prototype.

The town includes mature trees, five reusable park scene variants, and grass, flower, fern, and rock groundcover planted per available grassy tile. Meadow Commons is integrated behind the restaurant with connections to the street and the southern trail. The other four parks are ready to place from `scenes/parks/`. Purchased trees reserve a 2×2 footprint. Terrain uses the existing full blocks and art palette. Streets and ground are batched in a GridMap. Floor blocks are replaced rather than overlaid. Building reservations use actual mesh bounds, including attached porches, vehicles, and canopies.

## Validation and rebuilding

- `tests/restaurant_preview.gd`: customer service, earnings, purchases, refunds, plot progression, business acquisition, save serialization, and rendered previews.
- `tests/restaurant_input.gd`: actual mouse selection/placement, rotation, invalid feedback, nature-shop purchases, camera controls, and file round-trip.
- `tests/meadow_placement.gd`: building-to-building and building-to-road footprint checks.
- `tests/restaurant_smoke.gd`: short startup check.
- `tests/restaurant_land_input.gd`: real mouse hover/purchase, affordability, single-strip expansion and protected-frontage rejection, business removal, camera alignment, and park integration.
- `tests/parks_review.gd`: all park entrances and destinations reachable with a swept capsule, full ground coverage, exact ground collision geometry, and rendered park previews.

Run gameplay/input checks with Godot graphics enabled and `-- --restaurant-test` to avoid writing user progress. Reports and images are in `output/restaurant/validation` and `output/restaurant/review`.

The district is assembled by `tools/restaurant/build_meadow_district.gd`; the two tower scenes are generated by `tools/restaurant/build_towers.gd`. Run the tower builder first, then rebuild the district and rerun placement validation. All scenes use the existing canonical modules. The previous meadow preview was backed up in `output/restaurant/meadow_preview_before_restaurant.tscn` and its companion script before conversion.

This is a playable first pass with one recipe, automatic staffing, one purchasable neighboring business, and no ingredient, social, or hotel-management systems yet.

The camera faces straight along the block grid with no sideways rotation, retaining its downward elevation. The only action buttons outside the equipment drawer open/close that drawer; coins and served totals remain informational.

## Coastal reference pass

The meadow district now reaches a beach and bay, with a connected promenade, eastern fountain plaza, fenced pier, harbor office, shade tables, raised flower beds, hedge borders, and denser tree canopy. A café fills the gap along the southern main street, and another cottage completes the eastern neighborhood. Twenty ambient pedestrians walk checked routes. Press V for the coast; the separate waterfront scene and rebuild instructions are under `scenes/coast/`. Restaurant purchases and single-row/column expansion continue to work.

## Public paths, camera limits, independent seating and traffic

Public sidewalks, crossings and streets cannot be bought as expansion strips. Hovering a protected edge shows **NOT FOR SALE** without a purchase price. Private land can still expand up to the neighboring property boundaries; rejecting a strip never charges coins. Existing purchased land remains intact when loading older saves.

Camera panning is limited by the visible ground footprint, taking zoom, screen shape and the downward viewing angle into account. Keyboard panning, middle-button dragging, zoom and view shortcuts all share the limit. The coast includes a small water margin for the pier and boats.

Tables cost 60 coins and chairs cost 20 coins, each with a one-tile footprint and its own shop card, preview and refund. Place a chair next to a table, facing it (R rotates). A table needs a reachable chair to receive a customer. The current service model admits one customer per table. Save version 3 stores independent furniture; version 1/2 table-and-chair bundles migrate into separate pieces without charging the player.

Town traffic runs automatically when the Meadow preview opens. Cars, vans, ambulances and buses follow right-hand lanes and curved junction routes at up to 25 km/h (buses about 20 km/h). The central signals alternate main-road and branch-road traffic with amber and clearance phases. Drivers stop at branch stop signs, yield to opposing traffic before left turns, leave a following gap, and yield at occupied crossings. Buses pause at the marked stop. Ambulances use normal traffic rules in this version. Traffic is a bounded ambient simulation, with fixed road routes and vehicle arrivals/departures at their ends; emergency response, police enforcement, overtaking and a full jurisdiction-specific traffic code are not modeled.

Validation: `tests/restaurant_boundaries_seating.gd`, `tests/restaurant_land_input.gd`, and `tests/town_traffic.gd`. Run with `-- --restaurant-test` to protect user saves. `tests/town_traffic_capture.gd` captures the live junction for review.
