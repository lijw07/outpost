extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_verify")
func check(value: bool,message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func _verify() -> void:
	var active: Array[Node2D] = []
	for species in ["oak","birch","young_oak","deadwood"]:
		for side in [-1,1]:
			var tree: Node2D = load("res://scenes/environment/trees/"+species+".tscn").instantiate()
			root.add_child(tree)
			active.append(tree)
			check(not tree.hit(Vector2.ZERO,0),"zero damage rejected")
			check(tree.hit(Vector2(-side*100,0)),"first hit accepted")
			check(not tree.hit(Vector2(-side*100,0)),"rapid duplicate hit rejected")
			check(tree._puffs.is_empty(),"axe hits emit no dust")
	while active.any(func(t: Node2D) -> bool: return t._cooldown > 0.0): await physics_frame
	for i in range(active.size()):
		var side := -1 if i%2==0 else 1
		check(active[i].hit(Vector2(-side*100,0),2),"final hit accepted")
		check(active[i].state=="cutting","short cut reaction before full tree fall")
	while active.any(func(t: Node2D) -> bool: return t.state=="cutting"): await physics_frame
	for tree in active:
		check(tree.state=="falling","physics fall starts "+tree.species)
		check(tree._body is RigidBody3D,"real rigid body created")
		check(tree._fall_art.visible and tree._fall_art.modulate.a==1.0,"entire tree visible during fall")
		check(not tree.log_sprite.visible and tree._puffs.is_empty(),"no early log or dust before landing")
	for frame in range(600):
		await physics_frame
		for tree in active:
			if tree.state=="landing":
				check(tree._puffs.is_empty(),"landing creates no dust "+tree.species)
				check(tree.effects.get_node_or_null("LandingDust") == null,"landing stays unobscured "+tree.species)
		if active.all(func(t: Node2D) -> bool: return t.state=="fallen"): break
	for i in range(active.size()):
		var tree := active[i]
		print(tree.species," dir=",tree.fall_direction," state=",tree.state," impacts=",tree.impact_count)
		check(tree.state=="fallen","ground collision creates log and sticks "+tree.species)
		check(tree.impact_count==1,"exactly one impact "+tree.species)
		check(not tree._fall_art.visible and tree.sticks.size()==3,"canopy disappears only on landing with three sticks")
		check(tree.stump.visible and not tree.standing.visible,"persistent stump")
		check(not tree.hit(Vector2.ZERO),"felled tree rejects hit")
		check(is_instance_valid(tree._body) and tree.log_sprite.visible,"log appears after impact")
		check(tree._world.get_children().filter(func(n: Node) -> bool: return n is RigidBody3D).size()==4,"one log and three stick bodies")
		if tree.state=="fallen":
			check(signf(tree.log_sprite.position.x)==tree.fall_direction,"falls away from hitter "+tree.species)
	await create_timer(6.0).timeout
	for tree in active:
		var expected: int = tree.wood_yield+3
		check(tree.collect_wood(Vector2(9000,9000))==0,"out-of-range collection rejected")
		var collected: int = tree.collect_wood(tree.global_position,500.0)
		check(collected==expected,"settled wood collectable "+tree.species+" got "+str(collected))
		check(tree.collect_wood(tree.global_position,500.0)==0,"wood only collected once")
		check(tree._puffs.is_empty(),"dust cleaned up")
		tree.free()
	await process_frame
	print("Tree verification: ",failures.size()," failures across four species / both directions.")
	quit(0 if failures.is_empty() else 1)
