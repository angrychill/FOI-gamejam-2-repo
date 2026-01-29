extends Camera3D

@export var lidar_manager_path: NodePath
@export var max_distance := 1000.0

@export var add_point := true
@export var point_radius := 0.10
@export var point_color := Color(1.0, 0.2, 0.4, 0.9)

@export var add_collider_volume := true
@export var volume_color := Color(0.2, 0.9, 1.0, 0.9)

@onready var mgr: LidarManager = get_node(lidar_manager_path)

func _ready() -> void:
	make_current()

func _unhandled_input(event) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		shoot_lidar(event.position)

func shoot_lidar(screen_pos: Vector2) -> void:
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

	if add_point:
		mgr.add_volume(Transform3D(Basis.IDENTITY, hit_pos), LidarManager.TYPE_POINT, Vector4(point_radius, 0, 0, 0), point_color)

	if add_collider_volume:
		_try_add_collision_shape_volume(hit.collider, int(hit.shape))

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
		mgr.add_volume(global_xf, LidarManager.TYPE_SPHERE, Vector4(shape.radius, 0, 0, 0), volume_color)

	elif shape is BoxShape3D:
		var he := (shape as BoxShape3D).size * 0.5
		mgr.add_volume(global_xf, LidarManager.TYPE_BOX, Vector4(he.x, he.y, he.z, 0), volume_color)

	elif shape is CapsuleShape3D:
		var c := shape as CapsuleShape3D
		mgr.add_volume(global_xf, LidarManager.TYPE_CAPSULE, Vector4(c.radius, c.height * 0.5, 0, 0), volume_color)

	elif shape is CylinderShape3D:
		var cy := shape as CylinderShape3D
		mgr.add_volume(global_xf, LidarManager.TYPE_CYLINDER, Vector4(cy.radius, cy.height * 0.5, 0, 0), volume_color)
