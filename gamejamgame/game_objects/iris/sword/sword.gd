extends Weapon
class_name Sword

@export_category("Sword")
@export var particles: GPUParticles3D
@export var sword_range: float = 2.5

@export_category("Hit Detection")
@export var hit_ray: RayCast3D
@export var damage_per_hit: int = 2
@export var allow_multi_hit_same_enemy: bool = false

@export_category("Attack Input")
@export var swing_velocity_threshold: float = 5.0

# How long we consider the sword "active" after the last mouse motion
@export var motion_grace_time: float = 0.12

@export_category("Emission Throttle")
@export var emit_hz: float = 20.0              # limits both trail + hit checks while moving
@export var max_hits_per_swing: int = 8         # perf safety (prevents spam on jittery colliders)

@export_category("Lidar Trail (separate shape)")
@export var trail_emitter: LidarTrailEmitter
@export var emit_trail_while_attacking: bool = true

@export_category("Lidar Hit Volume (separate shape)")
@export var emit_hit_volume: bool = true
@export var hit_volume_shape: Shape3D
@export var hit_volume_color: Color = Color(0.2, 0.9, 1.0, 0.9)

# Make lidar last long
@export var lidar_lifetime_s: float = 30.0

# Slight push off the surface so it doesn't z-fight / sit inside
@export var hit_volume_offset_along_normal: float = 0.02

var _mgr: LidarManager = null

var _moving_until_s: float = -1.0
var _emit_accum: float = 0.0
var _hits_this_swing: int = 0

# enemy multi-hit control per swing (only stores a handful ids)
var _already_hit: Dictionary = {} # int -> true


func _ready() -> void:
	_mgr = LidarAccess.manager(get_tree())

	if particles:
		particles.emitting = false

	if hit_ray:
		hit_ray.enabled = true
		hit_ray.target_position = Vector3(0, 0, -sword_range)

	# (Optional) Ensure trail emitter uses long lifetime too
	if trail_emitter:
		trail_emitter.trail_lifetime_s = lidar_lifetime_s


func _physics_process(dt: float) -> void:
	# Only run while we're in "moving window"
	var now_s := Time.get_ticks_msec() * 0.001
	if now_s > _moving_until_s:
		# stop visuals and reset timers cheaply
		if particles and particles.emitting:
			particles.emitting = false
		_emit_accum = 0.0
		return

	# We are "attacking" while mouse is moving
	if particles and not particles.emitting:
		particles.emitting = true

	# Throttle expensive work by emit_hz
	var hz :float= max(emit_hz, 0.001)
	var step :float= 1.0 / hz
	_emit_accum += dt

	while _emit_accum >= step:
		_emit_accum -= step

		# 1) trail (manual) at fixed frequency
		if emit_trail_while_attacking and trail_emitter:
			# Emit exactly one lidar sample using long lifetime
			trail_emitter.emit_now(-1.0, Color(0, 0, 0, 0), lidar_lifetime_s, false)

		# 2) hit test at fixed frequency (perf win vs. every frame)
		if hit_ray:
			hit_ray.force_raycast_update()
			if hit_ray.is_colliding():
				_handle_hit()


func _input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouseMotion:
		var vel :float= event.screen_relative.length()
		if vel > swing_velocity_threshold:
			# extend moving window
			var now_s := Time.get_ticks_msec() * 0.001
			var new_until := now_s + motion_grace_time

			# if we were previously "not moving", start a new swing
			if now_s > _moving_until_s:
				_on_swing_started()

			_moving_until_s = max(_moving_until_s, new_until)


func _on_swing_started() -> void:
	_hits_this_swing = 0
	_already_hit.clear()


func _handle_hit() -> void:
	if _hits_this_swing >= max_hits_per_swing:
		return

	var col := hit_ray.get_collider()
	if col == null:
		return

	var id := col.get_instance_id()
	if (not allow_multi_hit_same_enemy) and _already_hit.has(id):
		return
	_already_hit[id] = true
	_hits_this_swing += 1

	if col is Enemy:
		(col as Enemy).take_damage(damage_per_hit)

	if emit_hit_volume:
		_emit_lidar_hit_volume(hit_ray.get_collision_point(), hit_ray.get_collision_normal())


func _emit_lidar_hit_volume(pos: Vector3, normal: Vector3) -> void:
	if _mgr == null:
		return

	var n := normal.normalized()
	var origin := pos + n * hit_volume_offset_along_normal

	# Build a basis whose +Y points along normal (good for capsule/cylinder "Y axis")
	var basis := Basis.IDENTITY
	if n.length() > 0.0001:
		basis = Basis.looking_at(n, Vector3.UP)

	var xf := Transform3D(basis, origin)

	# If no shape provided, fallback sphere
	if hit_volume_shape == null:
		_mgr.add_volume(xf, LidarManager.TYPE_SPHERE, Vector4(0.12, 0, 0, 0), hit_volume_color, lidar_lifetime_s)
		return

	if hit_volume_shape is SphereShape3D:
		var s := hit_volume_shape as SphereShape3D
		_mgr.add_volume(xf, LidarManager.TYPE_SPHERE, Vector4(s.radius, 0, 0, 0), hit_volume_color, lidar_lifetime_s)

	elif hit_volume_shape is BoxShape3D:
		var b := hit_volume_shape as BoxShape3D
		var he := b.size * 0.5
		_mgr.add_volume(xf, LidarManager.TYPE_BOX, Vector4(he.x, he.y, he.z, 0), hit_volume_color, lidar_lifetime_s)

	elif hit_volume_shape is CapsuleShape3D:
		var c := hit_volume_shape as CapsuleShape3D
		_mgr.add_volume(xf, LidarManager.TYPE_CAPSULE, Vector4(c.radius, c.height * 0.5, 0, 0), hit_volume_color, lidar_lifetime_s)

	elif hit_volume_shape is CylinderShape3D:
		var cy := hit_volume_shape as CylinderShape3D
		_mgr.add_volume(xf, LidarManager.TYPE_CYLINDER, Vector4(cy.radius, cy.height * 0.5, 0, 0), hit_volume_color, lidar_lifetime_s)

	else:
		_mgr.add_volume(xf, LidarManager.TYPE_SPHERE, Vector4(0.12, 0, 0, 0), hit_volume_color, lidar_lifetime_s)
