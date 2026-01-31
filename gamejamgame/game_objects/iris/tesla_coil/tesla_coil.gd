extends Weapon
class_name TeslaCoil

const TESLA_COIL_RAY_SHAPE: CylinderShape3D = preload("res://game_objects/iris/tesla_coil/tesla_coil_ray_shape.tres")

signal fired
signal cooldown_finished

@export var debug_draw_query_shape := true

@export_range(0.0, 10.0, 0.05) var cooldown_time: float = 0.35
@export_range(0.0, 50.0, 0.1) var camera_adjust_min_distance: float = 2.0
@export_range(0.0, 10.0, 0.1) var camera_adjust_max_distance: float = 1000.0 # optional clamp


var _next_attack_time: float = 0.0
var _cooldown_active: bool = false


@onready var holes_vfx: TeslaCoilShotgunHoles = $TeslaCoilShotgunHoles
var _debug_mesh_instance: MeshInstance3D


func _ready() -> void:
	if debug_draw_query_shape:
		_create_debug_shape()
	
	play_carry_sound_effect()


func _process(_delta: float) -> void:
	if debug_draw_query_shape and _debug_mesh_instance:
		_update_debug_shape_transform()

	if _cooldown_active:
		var now := Time.get_ticks_msec() * 0.001
		if now >= _next_attack_time:
			_cooldown_active = false
			emit_signal("cooldown_finished")


func _get_query_transform() -> Transform3D:
	var t := global_transform
	t.basis *= Basis(Vector3.RIGHT, deg_to_rad(90.0)) # rotate X +90

	if GlobalData.get_player() and GlobalData.get_player().camera:
		var camera: Camera3D = GlobalData.get_player().camera
		var viewport := camera.get_viewport()
		var screen_center := viewport.get_visible_rect().size * 0.5

		var ray_origin := camera.project_ray_origin(screen_center)
		var ray_dir := camera.project_ray_normal(screen_center)

		var space := get_world_3d().direct_space_state
		var ray_to := ray_origin + ray_dir * 1000.0

		var rq := PhysicsRayQueryParameters3D.create(ray_origin, ray_to)
		rq.collide_with_bodies = true
		rq.collide_with_areas = true
		rq.exclude = _build_exclude_list()
		rq.hit_from_inside = true
		rq.hit_back_faces = true


		var hit := space.intersect_ray(rq)

		var target_point: Vector3 = ray_to
		if hit.size() > 0:
			target_point = hit["position"]

		var to_target := target_point - t.origin
		var dist := to_target.length()

		# Only do camera-based correction after a minimum distance (prevents close-up snapping)
		if dist >= camera_adjust_min_distance:
			# Optional clamp so you don't do tiny rotations toward very far rays
			if camera_adjust_max_distance > 0.0:
				dist = min(dist, camera_adjust_max_distance)
				to_target = to_target.normalized() * dist

			var aim_dir := to_target.normalized()
			var current_axis := t.basis.y.normalized()

			var rot := current_axis.cross(aim_dir)
			var angle := acos(clamp(current_axis.dot(aim_dir), -1.0, 1.0))

			if rot.length() > 0.0001:
				t.basis = Basis(rot.normalized(), angle) * t.basis

			# keep your existing flip
			t.basis = Basis(t.basis.x.normalized(), PI) * t.basis

	t.origin += t.basis.y * -5.0
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
	var now := Time.get_ticks_msec() * 0.001
	if now < _next_attack_time:
		return

	_next_attack_time = now + cooldown_time
	_cooldown_active = true
	emit_signal("fired")
	
	play_attack_sound_effect()

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
	query_shape.exclude = _build_exclude_list()

	var collision: Array[Dictionary] = space.intersect_shape(query_shape)
	
	if collision.size() > 0:
		if holes_vfx:
			holes_vfx.emit_holes_from_cylinder_query(
				query_shape.transform,
				TESLA_COIL_RAY_SHAPE,
				query_shape.exclude
			)

		for collider_res in collision:
			var collider: Node3D = collider_res.get("collider")
			if collider is Enemy:
				shoot_enemy(collider)

func _build_exclude_list() -> Array:
	var ex: Array = [self]

	var player := GlobalData.get_player()
	if player:
		# Exclude the player root node (often enough if it owns the colliders)
		ex.append(player)

		# If your player has explicit CollisionObject3D children, exclude them too
		# (safe even if none exist)
		for child in player.get_children():
			if child is CollisionObject3D:
				ex.append(child)

	return ex


func shoot_enemy(enemy: Enemy) -> void:
	enemy.take_damage(damage)
