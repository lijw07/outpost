"""Build theme-matched block variants from the project's existing stone cube."""
import base64
import copy
import json
import re
import shutil
import struct
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "assets/models/blocks"
CITY = ROOT / "assets/models/city"
mapping = json.loads((ROOT / "output/blocks_correction/mapping.json").read_text())
template_native = json.loads((BASE / "blockbench/stone_block.bbmodel").read_text())
template_gltf = json.loads((BASE / "gltf/stone_block.gltf").read_text())
generated = ["gravel", "sidewalk", "road_asphalt", "road_lane", "road_crossing"]
for kind in generated:
    name = mapping[kind]
    texture_path = BASE / "textures" / (name + ".png")
    model = copy.deepcopy(template_native)
    model["name"] = name
    model["resolution"] = {"width": 64, "height": 32}
    texture = model["textures"][0]
    texture.update(name=name + ".png", width=64, height=32, uv_width=64, uv_height=32, path=str(texture_path), relative_path="../textures/" + name + ".png", uuid=str(uuid.uuid5(uuid.NAMESPACE_URL, "outpost/blocks/" + name)))
    texture["source"] = "data:image/png;base64," + base64.b64encode(texture_path.read_bytes()).decode()
    for cube in model["elements"]:
        cube["name"] = name
        for face_name, face in cube["faces"].items():
            if face["texture"] is not None:
                face["uv"] = [0, 0, 32, 32] if face_name == "up" else [32, 0, 64, 32]
    model["outpost"] = {"derived_from": "assets/models/blocks/blockbench/stone_block.bbmodel", "palette_source": "assets/models/shared/textures/terrain_atlas.png", "tile_units": 32}
    (BASE / "blockbench" / (name + ".bbmodel")).write_text(json.dumps(model, separators=(",", ":")))
    gltf = copy.deepcopy(template_gltf)
    uv_accessor = gltf["accessors"][gltf["meshes"][0]["primitives"][0]["attributes"]["TEXCOORD_0"]]
    view = gltf["bufferViews"][uv_accessor["bufferView"]]
    buffer = gltf["buffers"][view["buffer"]]
    data = bytearray(base64.b64decode(buffer["uri"].split(",", 1)[1]))
    for i in range(uv_accessor["count"]):
        offset = view.get("byteOffset", 0) + uv_accessor.get("byteOffset", 0) + i * view.get("byteStride", 8)
        u, v = struct.unpack_from("<ff", data, offset)
        struct.pack_into("<ff", data, offset, u, round((v * 176 - 128) / 32, 6))
    uv_accessor["min"], uv_accessor["max"] = [0, 0], [1, 1]
    buffer["uri"] = "data:application/octet-stream;base64," + base64.b64encode(data).decode()
    for image in gltf["images"]:
        image.update(uri="../textures/" + name + ".png", name=name + ".png")
    for node in gltf["nodes"]:
        node["name"] = name
    for texture in gltf["textures"]:
        texture["name"] = name + ".png"
    (BASE / "gltf" / (name + ".gltf")).write_text(json.dumps(gltf, separators=(",", ":")))

for kind, name in mapping.items():
    if kind.startswith("floor_"):
        for folder, extension in [("blockbench", "bbmodel"), ("gltf", "gltf"), ("collision", "res")]:
            (BASE / folder).mkdir(exist_ok=True)
            src = CITY / folder / (kind + "." + extension)
            dst = BASE / folder / (name + "." + extension)
            if src.exists():
                shutil.copyfile(src, dst)
        gltf_path = BASE / "gltf" / (name + ".gltf")
        gltf = json.loads(gltf_path.read_text())
        for image in gltf.get("images", []):
            if image.get("uri", "").startswith("../textures/"):
                src = CITY / "textures" / Path(image["uri"]).name
                
                if src.exists():
                    shutil.copyfile(src, BASE / "textures" / src.name)
    path = BASE / "scenes" / (name + ".tscn")
    path.write_text(f'''[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://assets/models/blocks/gltf/{name}.gltf" id="1_model"]

[sub_resource type="BoxShape3D" id="Shape"]
size = Vector3(2, 2, 2)

[node name="{''.join(part.title() for part in name.split('_'))}" type="Node3D"]
metadata/asset_id = "{name}"
metadata/terrain_type = "{kind}"
metadata/terrain_block = true
metadata/tile_size = 2.0
metadata/placement_anchor = "base"

[node name="Model" parent="." instance=ExtResource("1_model")]

[node name="Body" type="StaticBody3D" parent="."]

[node name="CollisionShape3D" type="CollisionShape3D" parent="Body"]
position = Vector3(0, 1, 0)
shape = SubResource("Shape")
''')
catalog = {"assets": [{"id": name, "terrain_type": kind, "scene": "res://assets/models/blocks/scenes/" + name + ".tscn", "model": "res://assets/models/blocks/gltf/" + name + ".gltf", "placement": {"terrain_block": True, "anchor": "base", "top_surface_y": 32}} for kind, name in mapping.items()]}
(BASE / "catalog.json").write_text(json.dumps(catalog, indent=2))
print("Canonical block scenes:", len(mapping), "; new atlas-derived variants:", len(generated), "; indoor finishes preserved.")
