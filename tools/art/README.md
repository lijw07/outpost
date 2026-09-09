# UI artwork repair and slicing

The editable, repaired sheets live in `assets/ui/sheets/ui_frames_clean_sheet.png`
and `ui_frames_bloody_sheet.png`. The raw reference exports under `assets/_source`
remain untouched. `ui_slices.json` records all 106 recovered atlas regions, with
their existing filenames and sizes. The checked checkbox is a derived 107th
export, using the repaired unchecked box and `checkbox_check_overlay.png`.

The September 2026 repair affects 90 border/widget assets. It removes the
synthetic alpha-150 fringe, fits straight outlines with pixel-stepped bevels,
preserves projecting blood pixels, and maps normal warm trim onto a 32-color
palette sampled from the original large brass panel. Gold hover, dark pressed,
and steel disabled artwork retain their distinct colors. Empty RGB data is
cleared without changing the appearance of the accompanying icons and decals.

The original image files are backed up in `output/ui_cleanup/original_ui.zip`.
Review `output/ui_cleanup/before_after.png` and `repair_report.json`.

For later edits to the repaired sheets, run with Python plus Pillow and numpy:

```sh
python3 tools/art/repair_ui.py --slice
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/art/verify_ui.gd
```

`--repair` is a guarded, one-time operation; it refuses to run once the backup
exists. `--preview` prepares review candidates without replacing game artwork.
The slice-only command never repeats the outline fitting or color mapping.
Do not rebuild the theme to pick up PNG changes: its existing paths already
resolve the repaired assets.

The proposed future sprite sizes and display policy are in
`docs/pixel-art-plan.md`; the native-resolution migration is separate from this
repair.
