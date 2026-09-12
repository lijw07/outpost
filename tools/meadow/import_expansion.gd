extends SceneTree
const BASE="res://assets/models/meadow_expansion/"
var report=[]
func _initialize():call_deferred("run")
func own(n,r):
 for c in n.get_children():c.owner=r;own(c,r)
func collect(n,t,groups):
 if n is Node3D:t=t*n.transform
 if n is MeshInstance3D:
  for i in n.mesh.get_surface_count():
   var mat=n.get_active_material(i)
   if mat is BaseMaterial3D:
    mat=mat.duplicate();mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
   var key=str(mat.albedo_texture.get_rid()) if mat is BaseMaterial3D and mat.albedo_texture else str(mat)
   if not groups.has(key):groups[key]={"st":SurfaceTool.new(),"mat":mat};groups[key].st.begin(Mesh.PRIMITIVE_TRIANGLES)
   groups[key].st.append_from(n.mesh,i,t)
 for c in n.get_children():collect(c,t,groups)
func run():
 var catalog=JSON.parse_string(FileAccess.get_file_as_string(BASE+"catalog.json"))
 var entries=catalog.assets.duplicate(true)
 var door=entries.filter(func(a):return a.id=="mall_double_glass_door")[0].duplicate(true);door.id="mall_double_glass_door_open";entries.append(door)
 for a in entries:
  var source_id="mall_double_glass_door" if a.id=="mall_double_glass_door_open" else a.id
  var src=load(BASE+"gltf/"+source_id+".gltf").instantiate()
  if a.id.ends_with("_open"):
   for h in src.find_children("*hinge*","Node3D",true,false):h.rotation.y=PI/2 if "left" in h.name else -PI/2
  var n=Node3D.new();n.name=a.id.to_pascal_case()
  n.set_meta("asset_id",a.id);n.set_meta("tile_units",32);n.set_meta("tile_size",2.0)
  var groups={};collect(src,Transform3D.IDENTITY,groups);src.free()
  var mesh=ArrayMesh.new()
  for g in groups.values():g.st.set_material(g.mat);g.st.commit(mesh)
  var visual=MeshInstance3D.new();visual.name="Visual";visual.mesh=mesh;n.add_child(visual)
  if a.category=="people":
   visual.free();var sprite=Sprite3D.new();sprite.name="Sprite";sprite.texture=load(BASE+"textures/"+a.id+"_front_0.png");sprite.pixel_size=1.0/16;sprite.position.y=1;sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;n.add_child(sprite)
  elif not a.id.begins_with("water_") and a.id not in ["fountain_spout","arch_glass_left","arch_glass_right","dune_grass","beach_towel","boat_oar","fishing_rod"]:
   var body=StaticBody3D.new();body.name="Body";n.add_child(body)
   var c=CollisionShape3D.new();c.name="MeshCollision";c.shape=mesh.create_trimesh_shape();c.shape.backface_collision=true;body.add_child(c)
  var box=mesh.get_aabb();assert(box.position.y>=-.002 and box.end.y<=2.002 and box.size.x<=2.002 and box.size.z<=2.002,a.id+" has wrong imported scale")
  own(n,n);var packed=PackedScene.new();assert(packed.pack(n)==OK);assert(ResourceSaver.save(packed,BASE+"scenes/"+a.id+".tscn")==OK)
  report.append({"id":a.id,"bounds":str(box),"surfaces":mesh.get_surface_count(),"triangles":mesh.get_faces().size()/3});n.free()
 FileAccess.open("res://output/meadow_scene_integration/import.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"assets":report},"\t"))
 print("MEADOW_IMPORT_OK assets=",report.size());quit()
