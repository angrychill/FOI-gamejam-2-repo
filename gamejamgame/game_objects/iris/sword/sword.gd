extends Weapon
class_name Sword

@export_category("Sword")
@export var particles: GPUParticles3D

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

@export_category("Lidar Trail (hit ray)")
@export var emit_trail_while_attacking: bool = true
@export_range(0.01, 2.0, 0.01) var trail_radius: float = 0.15
@export_range(1, 256, 1) var max_trail_points: int = 48
@export_range(0.05, 30.0, 0.05) var trail_lifetime_s: float = 1.2
@export var hit_volume_color: Color = Color(0.2, 0.9, 1.0, 0.9)

var _mgr: LidarManager = null

var _moving_until_s: float = -1.0
var _emit_accum: float = 0.0
var _hits_this_swing: int = 0
var _had_mouse_movement_this_frame: bool = false
var sword_range: float = 0.0

# enemy multi-hit control per swing (only stores a handful ids)
var _already_hit: Dictionary = {} # int -> true


func _ready() -> void:
	_mgr = LidarAccess.manager(get_tree())

	if particles:
		particles.emitting = false

	if hit_ray:
		hit_ray.enabled = true
		var tp := hit_ray.target_position
		var len := tp.length()
		if len <= 0.0001:
			# Sensible default if the ray has no length in the scene.
			tp = Vector3(0, 0, -1.0)
			len = 1.0
			hit_ray.target_position = tp
		sword_range = len


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

		# 1) trail (manual) at fixed frequency, only when there was mouse movement
		if emit_trail_while_attacking and _had_mouse_movement_this_frame:
			_emit_trail_sample()

	# 2) hit test at fixed frequency (perf win vs. every frame)
		if hit_ray:
			hit_ray.force_raycast_update()
			if hit_ray.is_colliding():
				_handle_hit()

	# Reset movement flag at end of physics frame
	_had_mouse_movement_this_frame = false


func _input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouseMotion:
		var vel :float= event.screen_relative.length()
		if vel > swing_velocity_threshold:
			_had_mouse_movement_this_frame = true
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


func _emit_trail_sample() -> void:
	if _mgr == null or hit_ray == null:
		return

	var hz :float= max(emit_hz, 0.001)

	# Base lifetime from export, optionally clamped by max_trail_points
	var trail_life :float= clamp(trail_lifetime_s, 0.05, 10.0)
	if max_trail_points > 0:
		var max_life := float(max_trail_points) / hz
		trail_life = min(trail_life, max_life)

	var start := hit_ray.global_transform.origin
	var end := start + hit_ray.global_transform.basis * hit_ray.target_position

	var dir := end - start
	var len := dir.length()

	if len < 0.0001:
		var xf_sphere := Transform3D(Basis.IDENTITY, start)
		_mgr.add_volume(
			xf_sphere,
			LidarManager.TYPE_SPHERE,
			Vector4(trail_radius, 0, 0, 0),
			hit_volume_color,
			trail_life
		)
		return

	var mid := start + dir * 0.5
	var basis := Basis.looking_at(dir, Vector3.UP)
	var xf := Transform3D(basis, mid)

	_mgr.add_volume(
		xf,
		LidarManager.TYPE_CAPSULE,
		Vector4(trail_radius, len * 0.5, 0, 0),
		hit_volume_color,
		trail_life
	)
