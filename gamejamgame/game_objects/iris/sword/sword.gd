extends Weapon
class_name Sword

# ----------------------------
# Node references (drag in Inspector)
# ----------------------------
@export var particles: GPUParticles3D
@export var hit_ray: RayCast3D                 # child RayCast3D (HitRay)
@export var camera: Camera3D                   # optional; if empty we auto grab player camera

# ----------------------------
# Sword hit tuning
# ----------------------------
@export var sword_range: float = 5.0
@export var min_mouse_speed_to_attack: float = 5.0

# How often to apply damage while the swing is "active"
@export_range(0.01, 1.0, 0.01) var damage_tick_s: float = 0.12
var _damage_timer: float = 0.0

# ----------------------------
# Lidar emission (separate from hit ray)
# ----------------------------
@export var emit_lidar: bool = true
@export var lidar_shape: int = LidarManager.TYPE_SPHERE  # or TYPE_CAPSULE if you want
@export var lidar_radius: float = 0.15
@export var lidar_capsule_half_height: float = 0.25      # used if capsule
@export var lidar_color: Color = Color(0.2, 0.9, 1.0, 0.9)
@export var lidar_lifetime_s: float = 0.12

# Emit lidar even if not an Enemy? (useful for impact/trace feedback)
@export var lidar_emit_on_any_hit: bool = true

var _mgr: LidarManager = null
var _is_attacking: bool = false

func _ready() -> void:
	if particles:
		particles.emitting = false

	# Auto camera if not assigned
	if camera == null and GlobalData.get_player() and GlobalData.get_player().camera:
		camera = GlobalData.get_player().camera

	# Ensure ray exists and is configured
	if hit_ray == null:
		push_warning("Sword: hit_ray is not assigned (RayCast3D).")
		return

	hit_ray.enabled = true
	hit_ray.collide_with_areas = false
	hit_ray.collide_with_bodies = true
	_update_hit_ray()

	# LidarManager via LidarAccess (no NodePaths)
	_mgr = LidarAccess.manager(get_tree())

func _physics_process(dt: float) -> void:
	if hit_ray == null:
		return

	_update_hit_ray()

	# Manage "continuous" hit check while attacking
	if not _is_attacking:
		return

	_damage_timer -= dt
	if _damage_timer > 0.0:
		return

	_damage_timer = damage_tick_s

	# RayCast3D collision is already computed by engine
	if not hit_ray.is_colliding():
		return

	var collider := hit_ray.get_collider()
	var hit_pos: Vector3 = hit_ray.get_collision_point()

	# Lidar emission (separate shape at hit position)
	if emit_lidar and _mgr != null and (lidar_emit_on_any_hit or collider is Enemy):
		_emit_lidar_at(hit_pos)

	# Damage
	if collider is Enemy:
		(collider as Enemy).take_damage(damage)

func _update_hit_ray() -> void:
	# Use camera direction when available (feels correct for FPS)
	if camera != null:
		var from := camera.global_transform.origin
		var dir := -camera.global_transform.basis.z.normalized()
		hit_ray.global_transform.origin = from
		hit_ray.target_position = dir * sword_range
	else:
		# Fallback: ray from the sword node forward
		hit_ray.target_position = -global_transform.basis.z.normalized() * sword_range

	# If you ever set target_position in editor, this keeps it updated with sword_range.
	# Force update if needed when you change transforms quickly.
	hit_ray.force_raycast_update()

func _emit_lidar_at(world_pos: Vector3) -> void:
	match lidar_shape:
		LidarManager.TYPE_CAPSULE:
			_mgr.add_volume(
				Transform3D(Basis.IDENTITY, world_pos),
				LidarManager.TYPE_CAPSULE,
				Vector4(lidar_radius, lidar_capsule_half_height, 0, 0),
				lidar_color,
				lidar_lifetime_s
			)
		_:
			# default sphere
			_mgr.add_volume(
				Transform3D(Basis.IDENTITY, world_pos),
				LidarManager.TYPE_SPHERE,
				Vector4(lidar_radius, 0, 0, 0),
				lidar_color,
				lidar_lifetime_s
			)

func _input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouseMotion:
		var speed :float = event.screen_relative.length()

		var want_attack := speed > min_mouse_speed_to_attack
		if want_attack != _is_attacking:
			_is_attacking = want_attack
			_damage_timer = 0.0  # hit immediately on start
			if particles:
				particles.emitting = _is_attacking
	else:
		# Stop attack when mouse stops / other events
		_is_attacking = false
		if particles:
			particles.emitting = false
