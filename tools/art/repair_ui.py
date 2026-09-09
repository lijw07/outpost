"""Repair the existing UI atlas pixels and re-export its original Godot slices.

Run once with --repair to clean the current artwork (backs it up first).
Run with --slice after subsequent atlas edits; no cleanup is reapplied.
Requires Pillow and numpy. All coordinates and image sizes stay unchanged.
"""
from pathlib import Path
import argparse
import json
import zipfile

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).with_name("ui_slices.json")
OUTPUT = ROOT / "output/ui_cleanup"
CHECK_OVERLAY = Path(__file__).with_name("checkbox_check_overlay.png")
SHEETS = {name: ROOT / f"assets/ui/sheets/ui_frames_{name}_sheet.png"
          for name in ("clean", "bloody")}


def read(path):
    return np.array(Image.open(path).convert("RGBA"))


def mode(values):
    return int(np.bincount(np.asarray(values, dtype=int)).argmax())


def silhouette(a):
    """Fit the straight runs and pixel-stepped bevel to the solid original ink."""
    solid = a[:, :, 3] == 255
    h, w = solid.shape
    left = mode([np.where(solid[y])[0][0] for y in range(h//3, h*2//3)])
    right = mode([np.where(solid[y])[0][-1] for y in range(h//3, h*2//3)])
    top = mode([np.where(solid[:, x])[0][0] for x in range(w//3, w*2//3)])
    bottom = mode([np.where(solid[:, x])[0][-1] for x in range(w//3, w*2//3)])
    yy, xx = np.indices(solid.shape)
    box = (xx >= left) & (xx <= right) & (yy >= top) & (yy <= bottom)
    distances = [xx-left+yy-top, right-xx+yy-top,
                 xx-left+bottom-yy, right-xx+bottom-yy]
    corners = [(xx <= (left+right)//2) & (yy <= (top+bottom)//2),
               (xx > (left+right)//2) & (yy <= (top+bottom)//2),
               (xx <= (left+right)//2) & (yy > (top+bottom)//2),
               (xx > (left+right)//2) & (yy > (top+bottom)//2)]
    limit = min(22, (right-left)//3, (bottom-top)//3)
    bevels = [min(range(limit+1), key=lambda b: np.count_nonzero(((box & (distance >= b)) != solid) & corner))
              for distance, corner in zip(distances, corners)]
    # Match left and right bevels, while preserving square-bottomed wide buttons.
    bevels[:2] = [round(sum(bevels[:2])/2)]*2
    bevels[2:] = [round(sum(bevels[2:])/2)]*2
    if max(bevels)-min(bevels) <= 2:
        bevels = [round(sum(bevels)/4)]*4
    mask = box.copy()
    for distance, bevel in zip(distances, bevels): mask &= distance >= bevel
    return mask, [left, top, right, bottom, bevels]


def warm_palette():
    # The existing clean large plate is the shared material reference.
    a = read(ROOT / "assets/ui/panels/panel_square.png")
    rgb = a[:, :, :3].astype(int)
    y, x = np.indices(a.shape[:2])
    band = (x < 28) | (x >= a.shape[1]-28) | (y < 28) | (y >= a.shape[0]-28)
    warm = (rgb[:, :, 0] > rgb[:, :, 1]+7) & (rgb[:, :, 1] > rgb[:, :, 2]+7)
    pixels = a[:, :, :3][band & warm & (a[:, :, 3] == 255)]
    swatch = Image.fromarray(pixels.reshape(1, -1, 3)).quantize(colors=32)
    return np.asarray(swatch.getpalette(), dtype=np.uint8).reshape(-1, 3)[:32]


def repair(a, path, palette):
    before = a.copy()
    if path.endswith("checkbox_check.png"):
        a[:, :, 3] = np.where(a[:, :, 3] == 255, 255, 0)
        a[a[:, :, 3] == 0] = 0
        return a, None
    mask, geometry = silhouette(a)
    left, top, right, bottom, bevel = geometry
    rgb = a[:, :, :3].astype(int)
    blood = (rgb[:, :, 0] > 45) & (rgb[:, :, 0] > rgb[:, :, 1]*2.2) & (rgb[:, :, 1] < 65)
    # Blood dripping beyond a plate is intentional artwork, not an outline error.
    if "blood" in path:
        mask |= blood & (a[:, :, 3] == 255)
    added = mask & (a[:, :, 3] != 255)
    # New outline pixels use neighboring solid ink, never the removed checkerboard.
    for y, x in zip(*np.where(added)):
        neighbors = []
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                ny, nx = y+dy, x+dx
                if 0 <= ny < a.shape[0] and 0 <= nx < a.shape[1] and before[ny, nx, 3] == 255:
                    neighbors.append((dx*dx+dy*dy, int(before[ny, nx, :3].sum()), ny, nx))
        if neighbors:
            _, _, ny, nx = min(neighbors)
            a[y, x, :3] = before[ny, nx, :3]
        else:
            a[y, x, :3] = (12, 14, 14)
    a[:, :, 3] = np.where(mask, 255, 0)
    # Preserve panel interiors, rivets, blood and deliberately different UI states.
    y, x = np.indices(a.shape[:2])
    thickness = 26 if "/panels/" in path else 9
    band = (x < left+thickness) | (x > right-thickness) | (y < top+thickness) | (y > bottom-thickness)
    normal = not any(s in path for s in ("/gold/", "/dark/", "/steel/", "hover", "pressed", "disabled", "slider_fill"))
    if normal and "_center" not in path:
        rgb = a[:, :, :3].astype(int)
        warm = (rgb[:, :, 0] > rgb[:, :, 1]+7) & (rgb[:, :, 1] > rgb[:, :, 2]+7)
        # Bright brass bolt highlights stay intact; recolor only the metal trim.
        selected = band & mask & warm & ~blood & (rgb.max(axis=2) < 220)
        colors = rgb[selected]
        if len(colors):
            distances = ((colors[:, None, :] - palette[None, :, :].astype(int))**2).sum(axis=2)
            a[:, :, :3][selected] = palette[distances.argmin(axis=1)]
    a[a[:, :, 3] == 0] = 0
    return a, geometry


def checked_box(original_checked, original_unchecked, repaired_unchecked):
    result = repaired_unchecked.copy()
    mark = np.any(original_checked != original_unchecked, axis=2)
    result[mark] = original_checked[mark]
    result[:, :, 3] = np.where(result[:, :, 3] == 255, 255, 0)
    result[result[:, :, 3] == 0] = 0
    return result


def preview(originals, repaired):
    names = ["assets/ui/widgets/button_square_normal.png", "assets/ui/widgets/button_square_hover.png",
             "assets/ui/widgets/checkbox_unchecked.png", "assets/ui/widgets/slider_track_mid.png",
             "assets/ui/panels/panel_banner.png", "assets/ui/panels/panel_square_blood_light.png"]
    canvas = Image.new("RGB", (1200, 1900), "#566673")
    draw = ImageDraw.Draw(canvas)
    draw.text((24, 18), "OUTPOST / UI PIXEL REPAIR", fill="#f7e3b0")
    draw.text((24, 43), "BEFORE", fill="white")
    draw.text((620, 43), "AFTER / original dimensions retained", fill="white")
    y = 76
    for path in names:
        draw.text((24, y), Path(path).stem, fill="white")
        a = originals[path]
        scale = min(4, 550/a.shape[1], 290/a.shape[0])
        if "panel_banner" in path: scale = 1.1
        for x, data in [(24, a), (620, repaired[path])]:
            im = Image.fromarray(data)
            im = im.resize((int(im.width*scale), int(im.height*scale)), Image.Resampling.NEAREST)
            canvas.paste(im, (x, y+22), im)
        y += int(a.shape[0]*scale)+48
    canvas.crop((0, 0, 1200, y+15)).save(OUTPUT / "before_after.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repair", action="store_true")
    parser.add_argument("--slice", action="store_true")
    parser.add_argument("--preview", action="store_true", help="Prepare candidates without changing game art")
    args = parser.parse_args()
    entries = json.loads(MANIFEST.read_text())["slices"]
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT.parent / ".gdignore").touch()
    if args.repair and (OUTPUT / "original_ui.zip").exists():
        raise RuntimeError("Already repaired. Use --slice for subsequent atlas edits; originals are backed up.")
    if args.slice:
        for entry in entries:
            x, y, w, h = entry["rect"]
            Image.open(SHEETS[entry["sheet"]]).crop((x, y, x+w, y+h)).save(ROOT / entry["path"])
        unchecked = Image.open(ROOT / "assets/ui/widgets/checkbox_unchecked.png").convert("RGBA")
        unchecked.alpha_composite(Image.open(CHECK_OVERLAY).convert("RGBA"))
        unchecked.save(ROOT / "assets/ui/widgets/checkbox_checked.png")
        print(f"Exported {len(entries)} original atlas regions and the derived checked box.")
        return
    if not (args.repair or args.preview): parser.error("Choose --repair, --preview or --slice")
    originals = {e["path"]: read(ROOT / e["path"]) for e in entries}
    checked = "assets/ui/widgets/checkbox_checked.png"
    unchecked = "assets/ui/widgets/checkbox_unchecked.png"
    originals[checked] = read(ROOT / checked)
    repaired = {}
    geometries = {}
    palette = warm_palette()
    for path, a in originals.items():
        if any(f"/{group}/" in path for group in ("frames", "panels", "widgets")) and path != checked:
            repaired[path], geometries[path] = repair(a.copy(), path, palette)
        else:
            repaired[path] = a.copy()
            repaired[path][repaired[path][:, :, 3] == 0] = 0
    repaired[checked] = checked_box(originals[checked], originals[unchecked], repaired[unchecked])
    overlay = np.zeros_like(originals[checked])
    mark = np.any(originals[checked] != originals[unchecked], axis=2)
    overlay[mark] = originals[checked][mark]
    overlay[:, :, 3] = np.where(overlay[:, :, 3] == 255, 255, 0)
    overlay[overlay[:, :, 3] == 0] = 0
    Image.fromarray(overlay).save(CHECK_OVERLAY)
    preview(originals, repaired)
    report = {"assets": []}
    for path, a in repaired.items():
        if path not in geometries and path != checked: continue
        orig = originals[path]
        report["assets"].append({"path": path, "size": [a.shape[1], a.shape[0]],
            "alpha_pixels_changed": int(np.count_nonzero(a[:, :, 3] != orig[:, :, 3])),
            "visible_color_pixels_changed": int(np.count_nonzero(np.any(a[:, :, :3] != orig[:, :, :3], axis=2) & (a[:, :, 3] != 0))),
            "geometry": geometries.get(path)})
    (OUTPUT / "repair_report.json").write_text(json.dumps(report, indent=2)+"\n")
    for path, a in repaired.items():
        target = OUTPUT / "candidate" / path
        target.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(a).save(target)
    if args.preview:
        print(f"Prepared {len(report['assets'])} repaired candidates; game art unchanged.")
        return
    backup = OUTPUT / "original_ui.zip"
    if backup.exists(): raise RuntimeError("Backup already exists; use --slice for later atlas edits.")
    with zipfile.ZipFile(backup, "w", zipfile.ZIP_DEFLATED) as z:
        for path in list(originals) + [str(p.relative_to(ROOT)) for p in SHEETS.values()]:
            z.write(ROOT / path, path)
    # Rebuild real transparent sheets with original placement, without extraction debris.
    atlases = {name: Image.new("RGBA", Image.open(path).size) for name, path in SHEETS.items()}
    for entry in entries:
        x, y, w, h = entry["rect"]
        atlases[entry["sheet"]].paste(Image.fromarray(repaired[entry["path"]]), (x, y))
    for name, atlas in atlases.items(): atlas.save(SHEETS[name])
    for entry in entries:
        x, y, w, h = entry["rect"]
        atlases[entry["sheet"]].crop((x, y, x+w, y+h)).save(ROOT / entry["path"])
    Image.fromarray(repaired[checked]).save(ROOT / checked)
    print(f"Repaired {len(report['assets'])} assets and re-sliced {len(entries)} regions. Backup: {backup}")


if __name__ == "__main__": main()
