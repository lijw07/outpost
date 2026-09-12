# Building assemblies

`prepare_buildings.py` defines the 11 furnished layouts using the canonical city modules. `build_buildings.gd` assembles independent scenes and their catalog. `scripts/buildings/modular_building.gd` controls doors and per-floor roof cutaways.

Rebuild from the project root with Python 3 and the Godot executable on PATH (or substitute the macOS app executable):

```sh
python3 tools/buildings/prepare_buildings.py
godot --headless --path . --script res://tools/buildings/build_buildings.gd
godot --headless --path . --script res://tests/export_building_surfaces.gd
python3 tools/buildings/trim_wall_junctions.py
godot --headless --path . --script res://tools/buildings/apply_wall_junctions.gd
godot --headless --path . --script res://tests/export_building_surfaces.gd
python3 tools/buildings/check_coplanar_surfaces.py
godot --headless --path . --script res://tests/export_building_surfaces.gd -- --open-doors
python3 tools/buildings/check_coplanar_surfaces.py --open-doors
godot --headless --path . --script res://tests/building_access.gd
godot --headless --path . --script res://tools/buildings/build_gallery.gd
godot --headless --path . --script res://tools/buildings/add_to_test_scene.gd
```

Run each step only after the preceding step succeeds. Always export the closed-door pose before trimming. Do not regenerate scenes after trimming without repeating the junction repair. The trimming subtracts positive-area coplanar duplicate polygons, interpolates UVs, and regenerates matching collisions. Original module files remain unchanged; only affected wall instances inside each building are unpacked. Layout edits should be made in the Python source to survive rebuilding.

The main Test Scene integration is idempotent and only replaces its tagged building gallery group, ground, and picker entries. It preserves the original scene contents and camera implementation. If the original city preview builder is run again, repeat `add_to_test_scene.gd` afterwards.

Visual and live walkthrough validation require graphics:

```sh
godot --path . --script res://tests/building_renders.gd
godot --path . --script res://tests/building_walkthrough.gd
godot --path . --script res://tests/city_preview_walkthrough.gd
```

Reports and review images are in `output/buildings/validation` and `output/buildings/review`. The room audit uses a swept player capsule through the real collision geometry. Geometry comparisons include doors and compare transformed triangles, not just counts. Coplanar checks evaluate the fully closed and fully open poses, excluding opposing internal contact surfaces.
