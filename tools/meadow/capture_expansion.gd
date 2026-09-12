extends SceneTree
func _initialize():call_deferred("run")
func capture(s,label,target,zoom):
 s.camera_target=target;s.zoom=zoom;s._update_camera()
 for i in 6:await process_frame
 RenderingServer.force_draw(false)
 s.viewport.get_texture().get_image().save_png("res://output/meadow_scene_integration/review/"+label+".png")
func run():
 var s=load("res://scenes/world/meadow_preview.tscn").instantiate();root.add_child(s);current_scene=s
 for i in 10:await process_frame
 s.set_process(false);s.viewport.size=Vector2i(1800,1250);s.hud.visible=false
 if is_instance_valid(s.plot_caption):s.plot_caption.visible=false
 if is_instance_valid(s.plot_overlay):s.plot_overlay.visible=false
 await capture(s,"integrated_district",Vector3(-1,0,15),130)
 await capture(s,"mall_and_plaza",Vector3(-46,0,-24),54)
 await capture(s,"beach_and_dock",Vector3(40,0,79),55)
 s.hud.visible=true
 var key=InputEventKey.new();key.keycode=KEY_HOME;key.pressed=true;s._unhandled_input(key)
 for i in 6:await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png("res://output/meadow_scene_integration/review/playable_restaurant.png")
 print("MEADOW_REVIEW_CAPTURED");quit()
