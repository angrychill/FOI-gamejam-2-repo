extends Node3D
class_name TeslaCoilShotgunHoles

@export var pellets: int = 3
@export_range(0.01, 5.0, 0.01) var pellet_radius: float = 1.0

# How far to push the sphere off the surface along the normal (prevents z-fighting)
@export_range(0.0, 0.2, 0.001) var surface_offset: float = 0.02

# Optional: how long the holes live (seconds). <= 0 means infinite (per your LidarManager)
@export_range(0.0, 30.0, 0.05) var lifetime_s: float = 1.25

# Color passed to the lidar shader
@export var hole_color: Color = Color(0.2, 1.0, 1.0, 1.0)

# If true, rays also collide with Areas
@export var collide_with_areas: bool = true
@export var collide_with_bodies: bool = true

# If true, will attempt to spawn multiple rays per pellet to find a valid surface
@export_range(1, 16, 1) var max_attempts_per_pellet: int = 6

# If true, also allow a "back hit" (reverse cast) when forward cast misses
@export var try_reverse_cast: bool = true

@export var use_spherecast_fallback := true
@export_range(0.001, 0.2, 0.001) var spherecast_radius := 0.02

@export_flags_3d_physics var collision_mask: int = 0xFFFFFFFF

var _rng := RandomNumberGenerator.new()
var _lidar: LidarManager

func _ready() -> void:
	_rng.randomize()
	_lidar = _get_lidar_manager()
	if _lidar == null:
		push_warning("TeslaCoilShotgunHoles: LidarManager not found. Make sure it's an Autoload named 'LidarManager' or available at /root/LidarManager.")


func emit_holes_from_cylinder_query(
	query_xform: Transform3D,
	cylinder_shape: CylinderShape3D,
	exclude: Array = []
) -> void:
	if _lidar == null:
		_lidar = _get_lidar_manager()
		if _lidar == null:
			return

	var world := get_world_3d()
	if world == null:
		return

	var space := world.direct_space_state
	if space == null:
		return

	var height := cylinder_shape.height
	var radius := cylinder_shape.radius

	# Cylinder assumed aligned to its local +Y axis, centered at origin.
	# We'll cast rays from -h/2 to +h/2 (local Y), at random points in the disc (local XZ).
	var y0 := -height * 0.5
	var y1 :=  height * 0.5

	for _i in range(pellets):
		var hit := _find_surface_hit_in_cylinder(space, query_xform, radius, y0, y1, exclude)
		if hit.is_empty():
			continue

		var hit_pos: Vector3 = hit["position"]
		var hit_nrm: Vector3 = hit.get("normal", Vector3.UP)

		# Spawn slightly off the surface along the normal.
		var spawn_pos := hit_pos + hit_nrm * surface_offset

		var t := Transform3D.IDENTITY
		t.origin = spawn_pos

		# LidarManager params: for TYPE_SPHERE we store radius in params.x
		_lidar.add_volume(
			t,
			LidarManager.TYPE_SPHERE,
			Vector4(pellet_radius, 0.0, 0.0, 0.0),
			hole_color,
			lifetime_s
		)

func _oriented_normal(hit_normal: Vector3, ray_dir: Vector3) -> Vector3:
	var n := hit_normal
	# Avoid repeated normalization if possible.
	var rd := ray_dir
	if rd.length_squared() > 0.0:
		rd = rd.normalized()
	if n == Vector3.ZERO:
		return -rd
	# If normal points in same direction as ray, flip it.
	if n.dot(rd) > 0.0:
		n = -n
	return n.normalized()

func _find_surface_hit_in_cylinder(
	space: PhysicsDirectSpaceState3D,
	query_xform: Transform3D,
	cyl_radius: float,
	y0: float,
	y1: float,
	exclude: Array
) -> Dictionary:
	var max_attempts :int= max(max_attempts_per_pellet, 1)
	for _attempt in range(max_attempts_per_pellet):
		# Random point in disc (uniform)
		var p2 := _random_point_in_disc(cyl_radius)
		# Cast from the coil toward the target (near -> far along the beam)
		var local_a := Vector3(p2.x, y1, p2.y)
		var local_b := Vector3(p2.x, y0, p2.y)

		var a := query_xform * local_a
		var b := query_xform * local_b

		# --- Forward cast ---
		var hit := _ray(space, a, b, exclude)
		if not hit.is_empty():
			# Orient normal so surface_offset pushes OUT of the surface.
			var ray_dir := (b - a)
			if ray_dir.length_squared() > 0.0:
				hit["normal"] = _oriented_normal(hit.get("normal", Vector3.ZERO), ray_dir)
			return hit

		# --- Optional reverse cast ---
		if try_reverse_cast:
			hit = _ray(space, b, a, exclude)
			if not hit.is_empty():
				var ray_dir := (a - b)
				if ray_dir.length_squared() > 0.0:
					hit["normal"] = _oriented_normal(hit.get("normal", Vector3.ZERO), ray_dir)
				return hit

	return {}




func _ray(
	space: PhysicsDirectSpaceState3D,
	from_p: Vector3,
	to_p: Vector3,
	exclude: Array
) -> Dictionary:
	var dir := to_p - from_p
	var dir_len_sq := dir.length_squared()
	if dir_len_sq < 0.0000001:
		return {}
	dir /= sqrt(dir_len_sq)

	# Nudge start forward a hair to avoid edge cases when starting inside/at the surface
	var start := from_p + dir * 0.002

	var rq := PhysicsRayQueryParameters3D.create(start, to_p)
	rq.collide_with_bodies = collide_with_bodies
	rq.collide_with_areas = collide_with_areas
	rq.collision_mask = collision_mask
	rq.exclude = exclude
	rq.hit_from_inside = true
	rq.hit_back_faces = true

	return space.intersect_ray(rq)

func _random_point_in_disc(r: float) -> Vector2:
	# Uniform area distribution
	var theta := _rng.randf_range(0.0, TAU)
	var u := _rng.randf() # 0..1
	var rr := sqrt(u) * r
	return Vector2(cos(theta) * rr, sin(theta) * rr)


func _get_lidar_manager() -> LidarManager:
	# Most common: Autoload named "LidarManager"
	var n := get_node_or_null("/root/LidarManager")
	if n != null and n is LidarManager:
		return n as LidarManager

	# Fallback: search the scene tree for the first LidarManager
	var root := get_tree().root
	if root == null:
		return null
	return _find_lidar_recursive(root)


func _find_lidar_recursive(node: Node) -> LidarManager:
	if node is LidarManager:
		return node as LidarManager
	for c in node.get_children():
		var res := _find_lidar_recursive(c)
		if res != null:
			return res
	return null
