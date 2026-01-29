extends Camera3D

@export var lidar_manager_path: NodePath = NodePath("/root/LidarManager")
@onready var mgr: LidarManager = get_node(lidar_manager_path)

@export var max_distance := 1000.0

@export var point_radius := 0.10
@export var point_color := Color(1.0, 0.2, 0.4, 0.9)
@export var point_lifetime_s := 1.5 # <=0 => infinite

@export var volume_color := Color(0.2, 0.9, 1.0, 0.9)
@export var volume_lifetime_s := 0.0 # infinite

# --- NEW: percentage placement for right-click spawn ---
@export_range(0.0, 100.0, 0.1) var spawn_percent := 0.0
@export var scroll_step_percent := 2.5

# --- NEW: random shape size ranges ---
@export var sphere_radius_range := Vector2(0.10, 0.50)
@export var box_half_extents_range := Vector2(0.10, 0.60) # each axis sampled in this range
@export var capsule_radius_range := Vector2(0.10, 0.35)
@export var capsule_half_height_range := Vector2(0.15, 0.80)
@export var cylinder_radius_range := Vector2(0.10, 0.45)
@export var cylinder_half_height_range := Vector2(0.15, 0.90)

# --- NEW: HUD label ---
var _hud_layer: CanvasLayer
var _percent_label: Label

func _ready() -> void:
	make_current()
	_setup_hud()
	_update_percent_label()
	randomize()

func _setup_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 100
	add_child(_hud_layer)

	_percent_label = Label.new()
	_percent_label.text = "Spawn %: 0.0"
	_percent_label.position = Vector2(16, 16)
	_percent_label.add_theme_font_size_override("font_size", 18)
	_hud_layer.add_child(_percent_label)

func _update_percent_label() -> void:
	if _percent_label:
		_percent_label.text = "Spawn %: {0} (Wheel to change)".format(
			[snappedf(spawn_percent, 0.01)]
		)


func _unhandled_input(event) -> void:
	# Mouse wheel adjusts spawn_percent
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spawn_percent = clamp(spawn_percent + scroll_step_percent, 0.0, 100.0)
		else:
			spawn_percent = clamp(spawn_percent - scroll_step_percent, 0.0, 100.0)
		_update_percent_label()
		return

	# Left click = original lidar hit + optional collider volume
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		shoot(event.position)
		return

	# Right click = spawn random collision shape volume between hit and camera
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		spawn_random_volume_between_hit_and_camera(event.position)
		return

func shoot(screen_pos: Vector2) -> void:
	var space := get_world_3d().direct_space_state
	var from := project_ray_origin(screen_pos)
	var dir := project_ray_normal(screen_pos)
	var to := from + dir * max_distance

	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = false
	q.collide_with_bodies = true

	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return

	var hit_pos: Vector3 = hit.position

	# point mark
	mgr.add_volume(
		Transform3D(Basis.IDENTITY, hit_pos),
		LidarManager.TYPE_POINT,
		Vector4(point_radius, 0, 0, 0),
		point_color,
		point_lifetime_s
	)

	# optional: collider volume (sphere/box/capsule/cylinder)
	_try_add_collision_shape_volume(hit.collider, int(hit.shape))

func spawn_random_volume_between_hit_and_camera(screen_pos: Vector2) -> void:
	var space := get_world_3d().direct_space_state
	var from := project_ray_origin(screen_pos)
	var dir := project_ray_normal(screen_pos)
	var to := from + dir * max_distance

	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = false
	q.collide_with_bodies = true

	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return

	var hit_pos: Vector3 = hit.position
	var cam_pos: Vector3 = global_position

	# 0% = hit point, 100% = camera
	var t :float= clamp(spawn_percent / 100.0, 0.0, 1.0)
	var spawn_pos := hit_pos.lerp(cam_pos, t)

	# Orient the volume so its +Z faces toward the camera (purely aesthetic)
	var look_dir := (cam_pos - spawn_pos).normalized()
	var basis := Basis()
	if look_dir.length() > 0.0001:
		basis = Basis.looking_at(look_dir, Vector3.UP)
	else:
		basis = Basis.IDENTITY

	var xf := Transform3D(basis, spawn_pos)

	_add_random_shape_volume(xf)

func _add_random_shape_volume(global_xf: Transform3D) -> void:
	var pick := randi() % 4

	match pick:
		0:
			# Sphere
			var r := randf_range(sphere_radius_range.x, sphere_radius_range.y)
			mgr.add_volume(global_xf, LidarManager.TYPE_SPHERE, Vector4(r, 0, 0, 0), volume_color, volume_lifetime_s)

		1:
			# Box (half extents)
			var hx := randf_range(box_half_extents_range.x, box_half_extents_range.y)
			var hy := randf_range(box_half_extents_range.x, box_half_extents_range.y)
			var hz := randf_range(box_half_extents_range.x, box_half_extents_range.y)
			mgr.add_volume(global_xf, LidarManager.TYPE_BOX, Vector4(hx, hy, hz, 0), volume_color, volume_lifetime_s)

		2:
			# Capsule (radius, half_height)
			var r := randf_range(capsule_radius_range.x, capsule_radius_range.y)
			var hh := randf_range(capsule_half_height_range.x, capsule_half_height_range.y)
			mgr.add_volume(global_xf, LidarManager.TYPE_CAPSULE, Vector4(r, hh, 0, 0), volume_color, volume_lifetime_s)

		_:
			# Cylinder (radius, half_height)
			var r := randf_range(cylinder_radius_range.x, cylinder_radius_range.y)
			var hh := randf_range(cylinder_half_height_range.x, cylinder_half_height_range.y)
			mgr.add_volume(global_xf, LidarManager.TYPE_CYLINDER, Vector4(r, hh, 0, 0), volume_color, volume_lifetime_s)

func _try_add_collision_shape_volume(collider: Object, shape_idx: int) -> void:
	if collider == null or not (collider is CollisionObject3D):
		return

	var co := collider as CollisionObject3D
	var owner_id := co.shape_find_owner(shape_idx)
	if owner_id == 0:
		return
	if co.shape_owner_get_shape_count(owner_id) <= 0:
		return

	var shape: Shape3D = co.shape_owner_get_shape(owner_id, 0)
	if shape == null:
		return

	var local_owner_xf: Transform3D = co.shape_owner_get_transform(owner_id)
	var global_xf: Transform3D = co.global_transform * local_owner_xf

	if shape is SphereShape3D:
		mgr.add_volume(global_xf, LidarManager.TYPE_SPHERE, Vector4(shape.radius, 0, 0, 0), volume_color, volume_lifetime_s)

	elif shape is BoxShape3D:
		var he := (shape as BoxShape3D).size * 0.5
		mgr.add_volume(global_xf, LidarManager.TYPE_BOX, Vector4(he.x, he.y, he.z, 0), volume_color, volume_lifetime_s)

	elif shape is CapsuleShape3D:
		var c := shape as CapsuleShape3D
		mgr.add_volume(global_xf, LidarManager.TYPE_CAPSULE, Vector4(c.radius, c.height * 0.5, 0, 0), volume_color, volume_lifetime_s)

	elif shape is CylinderShape3D:
		var cy := shape as CylinderShape3D
		mgr.add_volume(global_xf, LidarManager.TYPE_CYLINDER, Vector4(cy.radius, cy.height * 0.5, 0, 0), volume_color, volume_lifetime_s)
