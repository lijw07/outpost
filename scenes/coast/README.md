# Meadow waterfront

The reference-inspired coastal quarter is assembled into Meadow Preview. Run `scenes/world/meadow_preview.tscn` with F6. V focuses the waterfront, P the park, Home the restaurant, and M the complete district. Camera orientation remains straight.

`meadow_waterfront.tscn` contains the beach, opaque pixel-shaded water, promenade, eastern plaza, timber pier, harbor office, shade tables, flower beds, hedges, trees, and twenty ambient pedestrians. The neighboring café and street-facing cottage are separate building scene instances in the district. Existing house entrances face the main street. The first restaurant plot and all permitted expansion strips remain clear of permanent coastal props.

Terrain and pier tiles retain the full block geometry and matching triangle collisions. Underlying ground is removed wherever coastal terrain, building floor, or pier replaces it. Water is visual scenery with no walking collision. Visitors follow fixed, checked promenade routes; they do not add new restaurant management systems.

Groundcover and tree placement are deterministic and saved. Existing texture assets are reused. Water shading has no time-based motion, preserving the stable pixel presentation.

Rebuild with `tools/coast/build_coastal_quarter.gd` after any full district regeneration. The script updates the current saved district, stores the standalone waterfront scene, and preserves a pre-coast backup under `output/coast/`. Reapplying the park layout keeps the waterfront.

Checks: `tests/coastal_quarter.gd` validates ground replacement, pier and promenade access, pedestrian route clearance, mesh-matching terrain collisions, and restaurant land clearance. With graphics enabled, it captures four views under `output/coast/review`. `tests/meadow_placement.gd` checks buildings against other buildings and streets. Use `-- --restaurant-test` during test launches to leave progress saves untouched.
