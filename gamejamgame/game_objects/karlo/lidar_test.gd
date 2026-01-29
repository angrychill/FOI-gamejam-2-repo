extends Camera3D

@export var target_mesh: MeshInstance3D
@export var material_slot := 0   # which surface material to update

func _unhandled_input(event):
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		shoot_lidar(event.position)

func shoot_lidar(screen_pos: Vector2) -> void:
	var space := get_world_3d().direct_space_state

	var from := project_ray_origin(screen_pos)
	var dir  := project_ray_normal(screen_pos)
	var to   := from + dir * 1000.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result := space.intersect_ray(query)
	if result.is_empty():
		return

	var hit_pos: Vector3 = result.position
	_apply_lidar_origin(hit_pos)

func _apply_lidar_origin(world_pos: Vector3) -> void:
	if not target_mesh:
		return

	var mat := target_mesh.get_active_material(material_slot)
	print(mat, world_pos)
	if mat is ShaderMaterial:
		mat.set_shader_parameter("lidar_origin", world_pos)
	else:
		push_warning("Target material is not a ShaderMaterial")
