extends Weapon
class_name TeslaCoil

const TESLA_COIL_RAY_SHAPE = preload("res://game_objects/iris/tesla_coil/tesla_coil_ray_shape.tres")

func attack() -> void:
	var camera : Camera3D = GlobalData.get_player().camera
	if not camera:
		push_warning("There's no camera!")
		return
	
	var space = get_world_3d().direct_space_state

	var query_shape = PhysicsShapeQueryParameters3D.new()
	query_shape.collide_with_bodies = true
	query_shape.collide_with_areas = true
	query_shape.shape = TESLA_COIL_RAY_SHAPE
	#query_shape.motion = GlobalData.get_player().velocity
	query_shape.transform = global_transform
	var collision: Array[Dictionary]= space.intersect_shape(query_shape)
	
	if collision.size() > 0:
		for collider_res in collision:
			var collider : Node3D = collider_res.get("collider")
			var pos = collider.global_transform
			print_debug("hit pos: ", pos)
			print_debug("hit collider: ", collider.name)
			if collider is Enemy:
				print_debug("hit enemy ", collider)
				
				shoot_enemy(collider)
	
	else:
		print_debug("hit nothing")


func shoot_enemy(enemy : Enemy) -> void:
	print_debug("shooting enemy: ", enemy)
	# hard coded for now
	enemy.take_damage(damage)
	pass
