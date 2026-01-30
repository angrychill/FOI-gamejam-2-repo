extends Node3D
class_name TeslaCoilShotgunHoles

@export_category("Shotgun Holes")
@export var pellets: int = 18
@export var pellet_radius: float = 0.08
@export var pellet_lifetime_s: float = 0.25

# If you want some randomness in size:
@export var pellet_radius_jitter: float = 0.03 # 0 = off

# Lidar color is mainly used as intensity (alpha) in many lidar setups.
# If your shader uses alpha as mask strength, keep a high alpha.
@export var lidar_color: Color = Color(1, 1, 1, 1)

# Limits ray length to cylinder height (recommended)
@export var use_cylinder_height_as_ray: bool = true

# Extra: if true, each pellet uses the "closest hit" only
@export var stop_on_first_hit: bool = true


func emit_holes_from_cylinder_query(
	query_xf: Transform3D,
	cyl: CylinderShape3D,
	exclude: Array = []
) -> void:
	var mgr := LidarAccess.manager(get_tree())
	if mgr == null:
		push_warning("TeslaCoilShotgunHoles: LidarManager not found (missing LidarAPI in group 'lidar_api').")
		return

	var space := get_world_3d().direct_space_state
	if space == null:
		return

	# 1) Get the set of colliders inside the cylinder query (your requirement)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cyl
	q.transform = query_xf
	q.collide_with_bodies = true
	q.collide_with_areas = true
	q.exclude = exclude
	q.collision_mask = 0xFFFFFFFF # or your desired mask


	var hits: Array[Dictionary] = space.intersect_shape(q, 256)
	if hits.is_empty():
		return

	var collider_set := {} # ObjectID -> true
	for h in hits:
		var c: Object = h.get("collider")
		if c != null:
			collider_set[c.get_instance_id()] = true

	# 2) Fire pellet rays strictly within the cylinder volume:
	#    We raycast from one cap plane to the other cap plane, along the cylinder axis.
	var axis: Vector3 = query_xf.basis.y.normalized() # cylinder axis (+Y in your convention)
	var half_h: float = cyl.height * 0.5
	var radius: float = cyl.radius

	# Cap centers in world space
	var cap_a: Vector3 = query_xf.origin - axis * half_h
	var cap_b: Vector3 = query_xf.origin + axis * half_h

	# Build an orthonormal basis for the radial offsets
	var x_axis: Vector3 = query_xf.basis.x.normalized()
	var z_axis: Vector3 = query_xf.basis.z.normalized()

	# Ray length
	var ray_len: float = cyl.height if use_cylinder_height_as_ray else (cyl.height + radius * 2.0)

	for i in range(max(pellets, 0)):
		# Random point inside circle (uniform area)
		var u := randf()
		var v := randf()
		var r := sqrt(u) * radius
		var ang := TAU * v
		var offset: Vector3 = x_axis * (cos(ang) * r) + z_axis * (sin(ang) * r)

		# Ray goes from cap A -> cap B (same offset), staying in cylinder
		var from: Vector3 = cap_a + offset
		var to: Vector3 = cap_b + offset  # clearer than from + axis * ray_len

		var rq := PhysicsRayQueryParameters3D.create(from, to)
		rq.collide_with_bodies = true
		rq.collide_with_areas = true
		rq.exclude = exclude

		# IMPORTANT: if the ray starts inside geometry (likely), allow hits.
		rq.hit_from_inside = true

		# IMPORTANT: if you hit the "back" of triangles (common), allow it.
		rq.hit_back_faces = true

		# IMPORTANT: match masks with the shape query (otherwise ray may see nothing)
		rq.collision_mask = q.collision_mask

		var rh := space.intersect_ray(rq)
		if rh.is_empty():
			continue

		var hit_collider: Object = rh.get("collider")
		if hit_collider == null:
			continue

		# Only accept hits on colliders that are inside the intersect_shape result
		if not collider_set.has(hit_collider.get_instance_id()):
			continue

		var pos: Vector3 = rh.get("position")

		# Pellet radius (with jitter)
		var pr := pellet_radius
		if pellet_radius_jitter > 0.0:
			pr = max(0.001, pellet_radius + randf_range(-pellet_radius_jitter, pellet_radius_jitter))

		# Emit as a lidar point (spherical SDF in your manager)
		print("pellet @", pos, " collider=", (hit_collider as Node).name)
		mgr.add_volume(
			Transform3D(Basis.IDENTITY, pos),
			LidarManager.TYPE_POINT,
			Vector4(pr, 0, 0, 0),
			lidar_color,
			pellet_lifetime_s
		)

		if stop_on_first_hit:
			# This only stops "within this pellet ray"; intersect_ray already returns the first hit.
			pass
