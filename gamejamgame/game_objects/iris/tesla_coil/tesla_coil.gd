extends Weapon
class_name TeslaCoil

const TESLA_COIL_RAY_SHAPE: CylinderShape3D = preload("res://game_objects/iris/tesla_coil/tesla_coil_ray_shape.tres")

@export var debug_draw_query_shape := true

var _debug_mesh_instance: MeshInstance3D


func _ready() -> void:
	if debug_draw_query_shape:
		_create_debug_shape()


func _process(_delta: float) -> void:
	if debug_draw_query_shape and _debug_mesh_instance:
		_update_debug_shape_transform()


func _get_query_transform() -> Transform3D:
	var t := global_transform
	t.basis *= Basis(Vector3.RIGHT, deg_to_rad(90.0)) # rotate X +90

	var camera: Camera3D = GlobalData.get_player().camera
	if camera:
		var viewport := camera.get_viewport()
		var screen_center := viewport.get_visible_rect().size * 0.5

		var ray_origin := camera.project_ray_origin(screen_center)
		var ray_dir := camera.project_ray_normal(screen_center)

		# --- NEW: raycast to get the real point under the crosshair ---
		var space := get_world_3d().direct_space_state
		var ray_to := ray_origin + ray_dir * 1000.0

		var rq := PhysicsRayQueryParameters3D.create(ray_origin, ray_to)
		rq.collide_with_bodies = true
		rq.collide_with_areas = true
		rq.exclude = [self] # avoid hitting the weapon node

		var hit := space.intersect_ray(rq)

		var target_point: Vector3 = ray_to
		if hit.size() > 0:
			target_point = hit["position"]
		# -------------------------------------------------------------

		var aim_dir := (target_point - t.origin).normalized()

		# After +90° X rotation, cylinder axis is +Y
		var current_axis := t.basis.y.normalized()

		var rot := current_axis.cross(aim_dir)
		var angle := acos(clamp(current_axis.dot(aim_dir), -1.0, 1.0))
		if rot.length() > 0.0001:
			t.basis = Basis(rot.normalized(), angle) * t.basis

		# Keep your 180° flip fix
		t.basis = Basis(t.basis.x.normalized(), PI) * t.basis

	t.origin += t.basis.y * -5.0 # local y = -5
	return t




func _create_debug_shape() -> void:
	_debug_mesh_instance = MeshInstance3D.new()
	_debug_mesh_instance.name = "TeslaCoilQueryDebug"

	var m := CylinderMesh.new()
	m.height = TESLA_COIL_RAY_SHAPE.height
	m.top_radius = TESLA_COIL_RAY_SHAPE.radius
	m.bottom_radius = TESLA_COIL_RAY_SHAPE.radius
	_debug_mesh_instance.mesh = m

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 1.0, 1.0, 0.25)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_debug_mesh_instance.material_override = mat

	get_tree().current_scene.add_child(_debug_mesh_instance)
	_update_debug_shape_transform()


func _update_debug_shape_transform() -> void:
	_debug_mesh_instance.global_transform = _get_query_transform()

func _exit_tree() -> void:
	if _debug_mesh_instance and is_instance_valid(_debug_mesh_instance):
		_debug_mesh_instance.queue_free()
		_debug_mesh_instance = null


func attack() -> void:
	var camera: Camera3D = GlobalData.get_player().camera
	if not camera:
		push_warning("There's no camera!")
		return

	var space := get_world_3d().direct_space_state

	var query_shape := PhysicsShapeQueryParameters3D.new()
	query_shape.collide_with_bodies = true
	query_shape.collide_with_areas = true
	query_shape.shape = TESLA_COIL_RAY_SHAPE
	query_shape.transform = _get_query_transform()

	var collision: Array[Dictionary] = space.intersect_shape(query_shape)

	if collision.size() > 0:
		for collider_res in collision:
			var collider: Node3D = collider_res.get("collider")
			print_debug("hit collider: ", collider.name)
			if collider is Enemy:
				shoot_enemy(collider)
	else:
		print_debug("hit nothing")


func shoot_enemy(enemy: Enemy) -> void:
	enemy.take_damage(damage)
