"""Compare a static interior patch after compensating for camera translation."""

import json
import re
from pathlib import Path

import numpy as np
from PIL import Image


root = Path(__file__).resolve().parents[2] / "output/barren_city/08_motion_fix"
results = {}
for label in ("before", "after"):
    folder = root / label
    report = json.loads((folder / "report.json").read_text())
    first = np.asarray(Image.open(folder / "000.png"))
    render_width, render_height = map(int, re.findall(r"\d+", report["render"]))
    pixel_scale = np.array([first.shape[1] / render_width, first.shape[0] / render_height])
    reference = np.array(report["frames"][0]["point"]) * pixel_scale
    unit = first.shape[0] / 1080
    x, y = reference
    region = (slice(round(y - 300 * unit), round(y - 40 * unit)),
              slice(round(x - 250 * unit), round(x + 250 * unit)))
    mismatch = []
    for frame in report["frames"][1:24]:
        current = np.asarray(Image.open(folder / f'{frame["i"]:03d}.png'))
        shift = np.array(frame["point"]) * pixel_scale - reference
        dx, dy = np.rint(shift).astype(int)
        aligned = np.roll(current, (-dy, -dx), axis=(0, 1))
        error = np.abs(first[region].astype(int) - aligned[region].astype(int)).max(axis=2)
        mismatch.append(float(np.mean(error > 8)))
    stop = np.array(report["frames"][-1]["point"]) - report["frames"][40]["point"]
    results[label] = {"mean_changed_fraction": float(np.mean(mismatch)),
                      "max_changed_fraction": max(mismatch),
                      "stop_drift_render_pixels": float(np.linalg.norm(stop)),
                      "actual_image_size": [first.shape[1], first.shape[0]]}
results["reduction_percent"] = 100 * (1 - results["after"]["mean_changed_fraction"] / results["before"]["mean_changed_fraction"])
results["passed"] = results["after"]["mean_changed_fraction"] < 0.001 and results["after"]["stop_drift_render_pixels"] < 0.01
(root / "comparison.json").write_text(json.dumps(results, indent=2) + "\n")
print(json.dumps(results, indent=2))
raise SystemExit(0 if results["passed"] else 1)
