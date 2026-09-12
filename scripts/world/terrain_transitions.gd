extends RefCounted

const OFFSETS := [Vector3i(0,0,-1), Vector3i(1,0,0), Vector3i(0,0,1), Vector3i(-1,0,0), Vector3i(1,0,-1), Vector3i(1,0,1), Vector3i(-1,0,1), Vector3i(-1,0,-1)]
const Blocks := preload("res://scripts/world/block_library.gd")
const TEXTURES := {"grass":"grass_side", "grass_flowers":"grass_flowers_side", "sand":"sand_side", "dirt":"dirt_side", "stone":"stone_side", "gravel":"gravel_side", "sidewalk":"sidewalk_side", "road_asphalt":"road_asphalt_side", "road_lane":"road_lane_side", "road_crossing":"road_crossing_side"}
const PRIORITY := {"grass":6,"grass_flowers":6,"sand":5,"dirt":4,"gravel":3,"stone":3,"sidewalk":2,"road_asphalt":1}
const BASE := "res://assets/models/blocks/"
var blocks := Blocks.new()
var materials: Dictionary = {}
var variants: Dictionary = {}

func family(id: String) -> String:
	id = Blocks.type_for(id)
	return "road_asphalt" if id in ["road_lane", "road_crossing"] else "grass" if id == "grass_flowers" else id

func source_image(id: String) -> Image:
	return blocks.tile(id,id == "sidewalk")

func surface_image(id: String) -> Image:
	return blocks.tile(id)

func material_for(id: String) -> StandardMaterial3D:
	if not materials.has(id):
		var material := StandardMaterial3D.new()
		material.albedo_texture = ImageTexture.create_from_image(blocks.tile(id,true))
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.roughness = 1.0
		materials[id] = material
	return materials[id]

func normalized_neighbors(id: String, neighbors: Array) -> Array:
	var result: Array = []
	for neighbor in neighbors:
		var other := family(String(neighbor))
		result.append(other if PRIORITY.get(other, 0) > PRIORITY.get(family(id), 0) else "")
	return result

func variant(id: String, neighbors: Array, vertical_lane: bool = false) -> Dictionary:
	var edges := normalized_neighbors(id, neighbors)
	var key := id + ":" + ",".join(edges) + (":vertical" if vertical_lane else "")
	if variants.has(key):
		return variants[key]
	var base_tile := surface_image(id).duplicate() as Image
	if vertical_lane:
		base_tile.rotate_90(CLOCKWISE)
	var tile := base_tile.duplicate() as Image
	var heights := PackedInt32Array()
	heights.resize(1024)
	heights.fill(32)
	for z in 32:
		for x in 32:
			var best := 0.0
			var chosen := ""
			var chosen_distance := 100.0
			for i in 8:
				var other: String = edges[i]
				if other.is_empty():
					continue
				var offset: Vector3i = OFFSETS[i]
				var dx := float(x) + 0.5 if offset.x < 0 else 31.5 - x if offset.x > 0 else 0.0
				var dz := float(z) + 0.5 if offset.z < 0 else 31.5 - z if offset.z > 0 else 0.0
				var distance := Vector2(dx, dz).length() if i >= 4 else dx + dz
				var width := 6.5 if other == "grass" else 5.5
				var strength := width - distance
				if strength > best or (is_equal_approx(strength, best) and PRIORITY.get(other,0) > PRIORITY.get(chosen,0)):
					best = strength
					chosen = other
					chosen_distance = distance
			if chosen.is_empty():
				continue
			var original := base_tile.get_pixel(x,z)
			var incoming := source_image(chosen).get_pixel(x,z)
			var noise := posmod((x / 2) * 17 + (z / 2) * 31 + (x / 2) * (z / 2) * 7, 11)
			var speckle := posmod(x * 73 + z * 37 + x * z * 13, 17)
			var distance := chosen_distance
			if chosen == "sidewalk" and family(id) == "road_asphalt":
				if distance < 2.0:
					incoming = incoming.lightened(0.18) if distance < 1.0 else incoming.lightened(0.05)
					heights[z*32+x] = 33
					if (x % 16 == 0 and (edges[0] == "sidewalk" or edges[2] == "sidewalk")) or (z % 16 == 0 and (edges[1] == "sidewalk" or edges[3] == "sidewalk")):
						incoming = incoming.darkened(0.18)
				elif distance < 3.0:
					incoming = original.darkened(0.25)
				elif distance < 5.0:
					incoming = original.lerp(source_image("sidewalk").get_pixel(x,z),0.35)
				else:
					incoming = original
			else:
				var reach := (3.0 if chosen == "grass" else 2.0) + float(noise % 3)
				if distance > reach:
					incoming = incoming.darkened(0.10) if distance < reach + 1.0 else original
					if distance >= reach + 1.0 and speckle < 3:
						incoming = source_image(chosen).get_pixel(x,z)
				elif distance > reach - 1.0 and chosen == "grass":
					incoming = incoming.lightened(0.07)
			tile.set_pixel(x,z,incoming)
	var top_material := StandardMaterial3D.new()
	top_material.albedo_texture = ImageTexture.create_from_image(tile)
	top_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	top_material.roughness = 1.0
	var mesh := build_mesh(heights, top_material, material_for(id))
	var result := {"mesh":mesh, "image":tile, "heights":heights, "neighbors":edges, "id":id}
	variants[key] = result
	return result

func quad(st: SurfaceTool, points: Array, normal: Vector3, uv: Array) -> void:
	for index in [0,1,2,0,2,3]:
		st.set_normal(normal)
		st.set_uv(uv[index])
		st.add_vertex(points[index] / 16.0)

func build_mesh(heights: PackedInt32Array, top: Material, side: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(top)
	var visited := PackedByteArray()
	visited.resize(1024)
	for z in 32:
		for x in 32:
			if visited[z*32+x]:
				continue
			var h := heights[z*32+x]
			var width := 1
			while x+width < 32 and not visited[z*32+x+width] and heights[z*32+x+width] == h:
				width += 1
			var depth := 1
			while z+depth < 32:
				var fits := true
				for dx in width:
					if visited[(z+depth)*32+x+dx] or heights[(z+depth)*32+x+dx] != h:
						fits = false
				if not fits:
					break
				depth += 1
			for dz in depth:
				for dx in width:
					visited[(z+dz)*32+x+dx] = 1
			quad(st,[Vector3(x-16,h,z-16),Vector3(x+width-16,h,z-16),Vector3(x+width-16,h,z+depth-16),Vector3(x-16,h,z+depth-16)],Vector3.UP,[Vector2(x,z)/32.0,Vector2(x+width,z)/32.0,Vector2(x+width,z+depth)/32.0,Vector2(x,z+depth)/32.0])
	var mesh := st.commit()
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(side)
	for z in 32:
		for x in 32:
			var h := heights[z*32+x]
			for direction in 4:
				var offset: Vector3i = OFFSETS[direction]
				var nx := x + offset.x
				var nz := z + offset.z
				var low := heights[nz*32+nx] if nx >= 0 and nx < 32 and nz >= 0 and nz < 32 else 0
				if low >= h:
					continue
				var a: Vector3
				var b: Vector3
				match direction:
					0:
						a=Vector3(x+1-16,low,z-16); b=Vector3(x-16,low,z-16)
					1:
						a=Vector3(x+1-16,low,z+1-16); b=Vector3(x+1-16,low,z-16)
					2:
						a=Vector3(x-16,low,z+1-16); b=Vector3(x+1-16,low,z+1-16)
					3:
						a=Vector3(x-16,low,z-16); b=Vector3(x-16,low,z+1-16)
				var along := x if direction % 2 == 0 else z
				quad(st,[b,a,Vector3(a.x,h,a.z),Vector3(b.x,h,b.z)],Vector3(offset),[Vector2(along+1,32-low)/32.0,Vector2(along,32-low)/32.0,Vector2(along,32-h)/32.0,Vector2(along+1,32-h)/32.0])
	quad(st,[Vector3(-16,0,16),Vector3(16,0,16),Vector3(16,0,-16),Vector3(-16,0,-16)],Vector3.DOWN,[Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)])
	st.commit(mesh)
	return mesh

func district_neighbors(grid: GridMap) -> Dictionary:
	var district := grid.get_parent()
	while district != null and not district.has_node("MeadowBlocks"):
		district = district.get_parent()
	if district == null:
		return {}
	var neighbors: Dictionary = {}
	for other in district.find_children("*","GridMap",true,false):
		if other == grid or other.mesh_library == null:
			continue
		for cell in other.get_used_cells():
			var position: Vector3 = grid.to_local(other.to_global(other.map_to_local(cell)))
			var local_cell := grid.local_to_map(position)
			if not grid.map_to_local(local_cell).is_equal_approx(position):
				continue
			var name: String = other.mesh_library.get_item_name(other.get_cell_item(cell)).split(":")[0]
			neighbors[local_cell] = Blocks.type_for(name)
	for node in district.find_children("*","Node3D",true,false):
		if not node.get_meta("terrain_block",false):
			continue
		var position: Vector3 = grid.to_local(node.global_position)
		var cell := grid.local_to_map(position)
		if grid.map_to_local(cell).is_equal_approx(position):
			neighbors[cell] = Blocks.type_for(node.get_meta("terrain_type",node.get_meta("asset_id","")))
	return neighbors

func apply_grid(grid: GridMap, external_cells: Dictionary = {}) -> Dictionary:
	var library := grid.mesh_library.duplicate() as MeshLibrary
	var cells := district_neighbors(grid)
	cells.merge(external_cells,true)
	var original_ids: Dictionary = {}
	var base_items: Dictionary = {}
	for item in library.get_item_list():
		var name := library.get_item_name(item)
		if not ":" in name:
			base_items[Blocks.type_for(name)] = item
	for cell in grid.get_used_cells():
		var item := grid.get_cell_item(cell)
		var id := Blocks.type_for(library.get_item_name(item).split(":")[0])
		cells[cell] = id
		original_ids[cell] = base_items.get(id,item)
	for item in library.get_item_list():
		if ":" in library.get_item_name(item):
			library.remove_item(item)
	var added: Dictionary = {}
	var count := 0
	for cell in grid.get_used_cells():
		var id: String = cells[cell]
		if not TEXTURES.has(id):
			continue
		var neighbors: Array = []
		for offset in OFFSETS:
			neighbors.append(cells.get(cell+offset,""))
		var edges := normalized_neighbors(id,neighbors)
		if id not in ["road_lane","road_crossing"] and edges.all(func(value): return value == ""):
			grid.set_cell_item(cell,original_ids[cell],grid.get_cell_item_orientation(cell))
			continue
		var vertical_lane: bool = id == "road_lane" and (neighbors[0] == "road_lane" or neighbors[2] == "road_lane") and neighbors[1] != "road_lane" and neighbors[3] != "road_lane"
		if id == "road_crossing":
			vertical_lane = (neighbors[1] == "road_crossing" or neighbors[3] == "road_crossing") and neighbors[0] != "road_crossing" and neighbors[2] != "road_crossing"
		var key := id + ":" + ",".join(edges) + (":vertical" if vertical_lane else "")
		if not added.has(key):
			var data := variant(id, neighbors, vertical_lane)
			var mesh: ArrayMesh = data.mesh.duplicate()
			var item := library.get_last_unused_item_id()
			library.create_item(item)
			library.set_item_name(item,key)
			library.set_item_mesh(item,mesh)
			library.set_item_shapes(item,[mesh.create_trimesh_shape(),Transform3D.IDENTITY])
			added[key] = item
		grid.set_cell_item(cell,added[key],0)
		count += 1
	grid.mesh_library = library
	return {"changed_cells":count,"variants":added.size()}

func apply_district(district: Node3D) -> Dictionary:
	var grid: GridMap = district.get_node("MeadowBlocks")
	preload("res://scripts/world/meadow_street_markings.gd").apply(grid)
	var external: Dictionary = {}
	for node in district.find_children("*","Node3D",true,false):
		if node.get_meta("terrain_block",false) and absf(node.global_position.y-grid.global_position.y) < 0.01:
			external[grid.local_to_map(grid.to_local(node.global_position))] = Blocks.type_for(node.get_meta("asset_id",""))
	return apply_grid(grid,external)
