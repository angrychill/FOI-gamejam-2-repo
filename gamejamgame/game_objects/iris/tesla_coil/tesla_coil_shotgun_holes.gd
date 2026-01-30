extends Node3D
class_name TeslaCoilShotgunHoles

@export_category("Shotgun Holes")
@export var pellets: int = 18
@export var pellet_radius: float = 0.08
@export var pellet_lifetime_s: float = 0.25
@export var pellet_radius_jitter: float = 0.03
@export var lidar_color: Color = Color(1, 1, 1, 1)
@export var use_cylinder_height_as_ray: bool = true
@export var stop_on_first_hit: bool = true

# -------------------------------------------------------------------
# DEBUG CIRCLES (visualize pellet positions)
# -------------------------------------------------------------------
@export_category("Debug")
@export var debug_draw_circles := false
@export var debug_circle_radius := 0.18
@export var debug_circle_thickness := 0.04
@export var debug_circle_lifetime_s := 1.2
@export var debug_circle_color := Color(1, 0.2, 0.2, 0.95) # red-ish
@export var debug_toggle_key: Key = KEY_H

# optional: sometimes the physics hit position is on the collision shape,
# but you want to nudge the visual marker slightly above the surface.
@export var debug_surface_offset := 0.02

var _debug_root: Node3D

func _ready() -> void:
	_debug_root = Node3D.new()
	_debug_root.name = "DebugCircles"
	add_child(_debug_root)

	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == debug_toggle_key:
			debug_draw_circles = not debug_draw_circles
			print("TeslaCoilShotgunHoles debug circles:", debug_draw_circles)

func _spawn_debug_circle(world_pos: Vector3, world_normal: Vector3 = Vector3.UP) -> void:
	if not debug_draw_circles:
		return

	# Ring mesh (flat, visible)
	var mi := MeshInstance3D.new()

	var ring := TorusMesh.new()
	ring.ring_radius = max(0.001, debug_circle_radius)
	ring.pipe_radius = max(0.001, debug_circle_thickness)
	mi.mesh = ring

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = debug_circle_color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat

	# Place it at the hit position, nudged along normal
	mi.global_position = world_pos + world_normal.normalized() * debug_surface_offset

	# Orient ring to lie on the surface (torus axis is local Y)
	var up := world_normal.normalized()
	var basis := Basis()
	# Make local Y = normal
	basis.y = up
	# pick any perpendicular vector for X
	var t := up.cross(Vector3.FORWARD)
	if t.length() < 0.001:
		t = up.cross(Vector3.RIGHT)
	t = t.normalized()
	basis.x = t
	basis.z = basis.x.cross(basis.y).normalized()
	mi.global_basis = basis

	_debug_root.add_child(mi)

	# Auto-delete
	var timer := get_tree().create_timer(debug_circle_lifetime_s)
	timer.timeout.connect(func():
		if is_instance_valid(mi):
			mi.queue_free()
	)


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
		
		var nrm: Vector3 = rh.get("normal", Vector3.UP)

		_spawn_debug_circle(pos, nrm)

		# Pellet radius (with jitter)
		var pr := pellet_radius
		if pellet_radius_jitter > 0.0:
			pr = max(0.001, pellet_radius + randf_range(-pellet_radius_jitter, pellet_radius_jitter))

		# Emit as a lidar point (spherical SDF in your manager)
		print("pellet @", pos, " collider=", (hit_collider as Node).name)
		mgr.add_volume(
			Transform3D(Basis.IDENTITY, pos),
			LidarManager.TYPE_SPHERE,
			Vector4(pr, 0, 0, 0), # sphere radius
			lidar_color,
			pellet_lifetime_s
		)


		if stop_on_first_hit:
			# This only stops "within this pellet ray"; intersect_ray already returns the first hit.
			pass
