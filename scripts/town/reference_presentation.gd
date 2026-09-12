@tool
extends Node3D
const PALETTE=preload("res://scripts/town/reference_palette.gdshader")
var materials:Dictionary={}
func _ready()->void:
	apply_to(get_parent())
func apply_to(root:Node)->void:
	for child in root.get_children():apply_to(child)
	var mesh:Mesh
	if root is MeshInstance3D:mesh=root.mesh
	elif root is MultiMeshInstance3D and root.multimesh!=null:mesh=root.multimesh.mesh
	else:return
	if mesh==null:return
	for index in mesh.get_surface_count():
		var original:Material=root.get_active_material(index) if root is MeshInstance3D else mesh.surface_get_material(index)
		if not original is StandardMaterial3D or original.albedo_texture==null:continue
		var path:String=original.albedo_texture.resource_path
		var foliage:bool="/trees/textures/" in path or "/plants/" in path
		var roof:bool=path.ends_with("/roof.png")
		if not foliage and not roof:continue
		if not materials.has(path):
			var material:=ShaderMaterial.new();material.shader=PALETTE
			material.set_shader_parameter("source_texture",original.albedo_texture)
			material.set_shader_parameter("foliage",foliage)
			materials[path]=material
		if root is MeshInstance3D:root.set_surface_override_material(index,materials[path])
		elif mesh.get_surface_count()==1:root.material_override=materials[path]
