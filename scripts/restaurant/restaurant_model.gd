extends RefCounted

const CATALOG := {
	"fridge": {"title":"Fridge", "cost":120, "asset":"fridge", "size":Vector2i.ONE},
	"shelf": {"title":"Bookshelf", "cost":50, "asset":"bookcase", "size":Vector2i.ONE},
	"dining": {"title":"Table", "cost":60, "asset":"table", "size":Vector2i.ONE},
	"chair": {"title":"Chair", "cost":20, "asset":"chair", "size":Vector2i.ONE},
	"stove": {"title":"Stove", "cost":160, "asset":"stove", "size":Vector2i.ONE},
	"counter": {"title":"Counter", "cost":45, "asset":"sink_counter", "size":Vector2i.ONE},
	"wall": {"title":"Wood wall", "cost":20, "asset":"wall_wood_solid", "size":Vector2i.ONE},
	"corner": {"title":"Wall corner", "cost":25, "asset":"wall_wood_corner", "size":Vector2i.ONE},
	"door": {"title":"Open doorway", "cost":45, "asset":"doorway_wood", "size":Vector2i.ONE},
	"window": {"title":"Window wall", "cost":30, "asset":"wall_wood_window", "size":Vector2i.ONE},
	"flowers": {"title":"Daisies", "cost":12, "asset":"nature:flowers_daisy", "size":Vector2i.ONE},
	"lavender": {"title":"Lavender", "cost":15, "asset":"nature:flowers_lavender", "size":Vector2i.ONE},
	"fern": {"title":"Fern", "cost":10, "asset":"nature:fern", "size":Vector2i.ONE},
	"grass": {"title":"Meadow grass", "cost":5, "asset":"nature:grass_tufts", "size":Vector2i.ONE},
	"tall_grass": {"title":"Tall grass", "cost":8, "asset":"nature:tall_grass", "size":Vector2i.ONE},
	"shrub": {"title":"Round shrub", "cost":20, "asset":"nature:bush_round", "size":Vector2i.ONE},
	"tree": {"title":"Young oak", "cost":60, "asset":"tree:meadow_oak_young", "size":Vector2i(2,2)},
	"plant": {"title":"Planter", "cost":35, "asset":"planter", "size":Vector2i.ONE}
}
const LAND_TILE_COST := 25
const LAND_LIMIT := Rect2i(-2,-2,22,10)
const PUBLIC_PATHS := [Rect2i(-2,7,22,1), Rect2i(2,6,1,1), Rect2i(12,6,8,1)]
const BUSINESS_LAND := Rect2i(13,0,7,6)
const ENTRY := Vector2i(2,5)
const STREET := Vector2i(2,14)
var coins := 180
var served := 0
var earned := 0
var land := Rect2i(0,0,6,6)
var business_owned := false
var kitchen_level := 1
var objects: Array[Dictionary] = []
var next_id := 1
var floors: Dictionary = {}
var public_cells: Dictionary = {}

func width() -> int:
	return land.size.x

func height() -> int:
	return land.size.y

func owned(cell: Vector2i) -> bool:
	return land.has_point(cell)

func expansion_strip(edge: int) -> Rect2i:
	match edge:
		0:return Rect2i(land.position-Vector2i(1,0),Vector2i(1,height()))
		1:return Rect2i(Vector2i(land.end.x,land.position.y),Vector2i(1,height()))
		2:return Rect2i(land.position-Vector2i(0,1),Vector2i(width(),1))
		3:return Rect2i(Vector2i(land.position.x,land.end.y),Vector2i(width(),1))
	return Rect2i()

func expansion_cost(edge: int) -> int:
	var strip := expansion_strip(edge)
	return strip.get_area()*LAND_TILE_COST+(1200 if not business_owned and strip.intersects(BUSINESS_LAND) else 0)

func expansion_boundary_error(edge: int) -> String:
	var strip := expansion_strip(edge)
	if strip.get_area()==0:return "Choose an edge of your restaurant."
	if not LAND_LIMIT.encloses(strip):return "This edge meets public paths or neighboring property."
	for path_rect in PUBLIC_PATHS:
		if strip.intersects(path_rect):return "Public sidewalks and streets are not for sale."
	for x in range(strip.position.x,strip.end.x):
		for z in range(strip.position.y,strip.end.y):
			if public_cells.has(Vector2i(x,z)):return "Public sidewalks and streets are not for sale."
	return ""

func expansion_error(edge: int) -> String:
	var boundary := expansion_boundary_error(edge)
	if not boundary.is_empty():return boundary
	if coins<expansion_cost(edge):return "Need %d more coins."%(expansion_cost(edge)-coins)
	return ""

func offset(point: Vector2i, rotation: int) -> Vector2i:
	for i in posmod(rotation,4):
		point = Vector2i(-point.y,point.x)
	return point

func cells(item: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = [item.cell]
	if item.kind == "tree":
		for delta in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:result.append(item.cell+offset(delta,item.rotation))
	return result

func seat(item: Dictionary) -> Vector2i:
	var chair := table_chair(item)
	return chair.cell if not chair.is_empty() else Vector2i(-99,-99)

func table_chair(table: Dictionary, layout: Array = objects) -> Dictionary:
	for item in layout:
		if item.kind == "chair" and item.cell + offset(Vector2i.UP,item.rotation) == table.cell:
			if not path(ENTRY,item.cell,layout).is_empty():return item
	return {}

func path(from: Vector2i, to: Vector2i, layout: Array = objects) -> Array[Vector2i]:
	var blocked := {}
	var doors := {}
	for item in layout:
		if item.kind=="door":
			doors[item.cell]=item.rotation
			continue
		for cell in cells(item):
			blocked[cell] = true
	blocked.erase(from)
	blocked.erase(to)
	var queue: Array[Vector2i] = [from]
	var parents := {from:from}
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		if current == to:
			var result: Array[Vector2i] = [to]
			while result[-1] != from:
				result.append(parents[result[-1]])
			result.reverse()
			return result
		for step in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next: Vector2i = current + step
			if doors.has(current) and ((doors[current]%2==0 and step.x!=0) or (doors[current]%2==1 and step.y!=0)):continue
			if doors.has(next) and ((doors[next]%2==0 and step.x!=0) or (doors[next]%2==1 and step.y!=0)):continue
			var accessible := owned(next) or (next.x == ENTRY.x and next.y >= 6 and next.y <= STREET.y)
			if accessible and not blocked.has(next) and not parents.has(next):
				parents[next] = current
				queue.append(next)
	return []

func service_cell(item: Dictionary, layout: Array = objects) -> Vector2i:
	var occupied := {}
	for other in layout:
		for cell in cells(other):occupied[cell] = true
	for delta in [Vector2i.DOWN,Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP]:
		var candidate: Vector2i = item.cell + offset(delta,item.rotation)
		if owned(candidate) and not occupied.has(candidate) and not path(ENTRY,candidate,layout).is_empty():
			return candidate
	return Vector2i(-99,-99)

func validate_layout(layout: Array) -> String:
	var occupied := {}
	for item in layout:
		for cell in cells(item):
			if not owned(cell):return "Buy this plot before building here."
			if cell == ENTRY:return "Keep the entrance clear."
			if occupied.has(cell):return "There is already something here."
			occupied[cell] = true
	if path(STREET,ENTRY,layout).is_empty():return "Keep a clear route from the street."
	for item in layout:
		if item.kind == "chair" and path(ENTRY,item.cell,layout).is_empty():
			return "This would block a customer’s seat."
		if item.kind in ["stove","dining"] and service_cell(item,layout).x == -99:
			return "Leave an accessible side for staff to work."
	return ""

func placement_error(kind: String, cell: Vector2i, rotation: int) -> String:
	if not CATALOG.has(kind):return "Choose something to build."
	if coins < CATALOG[kind].cost:return "Not enough coins. Serve more customers first."
	var candidate := objects.duplicate(true)
	candidate.append({"id":next_id,"kind":kind,"cell":cell,"rotation":rotation})
	return validate_layout(candidate)

func place(kind: String, cell: Vector2i, rotation: int) -> String:
	var error := placement_error(kind,cell,rotation)
	if not error.is_empty():return error
	objects.append({"id":next_id,"kind":kind,"cell":cell,"rotation":posmod(rotation,4)})
	next_id += 1
	coins -= CATALOG[kind].cost
	return ""

func remove_at(cell: Vector2i) -> bool:
	for i in objects.size():
		if cell in cells(objects[i]):
			coins += int(CATALOG[objects[i].kind].cost * .75)
			objects.remove_at(i)
			return true
	return false

func expand(edge: int=1) -> bool:
	if not expansion_error(edge).is_empty():return false
	var strip := expansion_strip(edge)
	coins-=expansion_cost(edge)
	if strip.intersects(BUSINESS_LAND):business_owned=true
	land=land.merge(strip)
	return true

func starter() -> void:
	for data in [["fridge",0,0],["shelf",5,0],["stove",1,0],["counter",2,0],["dining",1,2],["dining",4,2],["chair",1,3],["chair",4,3]]:
		objects.append({"id":next_id,"kind":data[0],"cell":Vector2i(data[1],data[2]),"rotation":0})
		next_id += 1

func serialize() -> Dictionary:
	var saved: Array = []
	for item in objects:
		saved.append({"id":item.id,"kind":item.kind,"x":item.cell.x,"z":item.cell.y,"rotation":item.rotation})
	return {"version":3,"coins":coins,"served":served,"earned":earned,"land":[land.position.x,land.position.y,width(),height()],"business_owned":business_owned,"kitchen_level":kitchen_level,"objects":saved,"floors":floors}

func restore(data: Dictionary) -> bool:
	if int(data.get("version",0)) not in [1,2,3]:return false
	if data.version==1:
		var legacy := clampi(int(data.get("expansion",0)),0,3)
		land=Rect2i(0,0,20 if legacy==3 else 6+legacy*3,6)
		business_owned=legacy==3
	else:
		var dimensions=data.get("land",[])
		if not dimensions is Array or dimensions.size()!=4:return false
		land=Rect2i(int(dimensions[0]),int(dimensions[1]),int(dimensions[2]),int(dimensions[3]))
		business_owned=bool(data.get("business_owned",false))
		if not LAND_LIMIT.encloses(land) or not land.encloses(Rect2i(0,0,6,6)):return false
		if land.intersects(BUSINESS_LAND) and not business_owned:return false
	var restored: Array[Dictionary] = []
	for item in data.get("objects",[]):
		if not CATALOG.has(item.get("kind","")):return false
		restored.append({"id":int(item.id),"kind":item.kind,"cell":Vector2i(item.x,item.z),"rotation":posmod(int(item.rotation),4)})
	if int(data.version)<3:
		var migrated_id := 1
		for item in restored:migrated_id=maxi(migrated_id,item.id+1)
		for item in restored.duplicate():
			if item.kind == "dining":
				var chair_cell: Vector2i = item.cell + offset(Vector2i.DOWN,item.rotation)
				if restored.any(func(other):return other.kind=="chair" and other.cell==chair_cell):continue
				restored.append({"id":migrated_id,"kind":"chair","cell":chair_cell,"rotation":item.rotation})
				migrated_id+=1
	if not validate_layout(restored).is_empty():return false
	objects = restored
	coins = maxi(0,int(data.get("coins",180)))
	served = maxi(0,int(data.get("served",0)))
	earned = maxi(0,int(data.get("earned",0)))
	kitchen_level = clampi(int(data.get("kitchen_level",1)),1,3)
	floors = data.get("floors",{})
	next_id = 1
	for item in objects:next_id = maxi(next_id,item.id+1)
	return true
