extends Weapon
class_name TeslaCoil

const TESLA_COIL_RAY_SHAPE = preload("uid://cuc458ufw3sty")

func attack() -> void:
	var camera : Camera3D = GlobalData.get_player().camera
	if not camera:
		push_warning("There's no camera!")
		return
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(camera.global_position,
		camera.global_position - camera.global_transform.basis.z * 100)
	
	var query_shape = PhysicsShapeQueryParameters3D.new()
	query_shape.collide_with_bodies = true
	query_shape.collide_with_areas = false
	query_shape.shape = TESLA_COIL_RAY_SHAPE
	query_shape.motion = GlobalData.get_player().velocity
	query_shape.transform = transform
	var collision = space.intersect_shape(query_shape)
	
	if collision:
		for collider in collision.values():
			print_debug("hit collider ", collision.collider.name, collision.position)
			if collision.collider is Enemy:
				shoot_enemy(collision.collider)
	
	else:
		print_debug("hit nothing")


func shoot_enemy(enemy : Enemy) -> void:
	print_debug("shooting enemy: ", enemy)
	# hard coded for now
	enemy.take_damage(damage)
	pass
