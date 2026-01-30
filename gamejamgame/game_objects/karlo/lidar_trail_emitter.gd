extends Node
class_name LidarTrailEmitter

# -------------------------------------------------------------------
# EMISSION MODE (Public API)
# -------------------------------------------------------------------
@export_category("Lidar Trail Emitter")
@export_enum("Continuous", "Manual") var emission_mode: int = 0
const MODE_CONTINUOUS := 0
const MODE_MANUAL := 1

# If true, even in Manual mode, calling emit_now() is allowed (recommended).
# (This mostly exists to let you quickly "disable" an emitter without removing it.)
@export var manual_emission_enabled: bool = true


# -------------------------------------------------------------------
# Shape / Radius
# -------------------------------------------------------------------
@export_category("Shape")
@export var use_collision_shape_size: bool = true
@export var fallback_sphere_radius: float = 0.15

# If true, we prefer this radius over a CollisionShape3D's sphere radius.
@export var override_radius_enabled: bool = false
@export var override_radius_value: float = 0.15

# Optional loose-coupled binding:
# If set, we read a float from this node every emit and use it as radius.
# Example: bind_node_path = ".." and bind_radius_property = "fire_accumulator"
@export var bind_node_path: NodePath
@export var bind_radius_property: StringName = &"" # e.g. &"fire_accumulator"

# Clamp radius (avoids zero/negative or huge volumes)
@export var radius_min: float = 0.01
@export var radius_max: float = 10.0


# -------------------------------------------------------------------
# Emission timing / visuals
# -------------------------------------------------------------------
@export_category("Emission")
@export var trail_lifetime_s: float = 1.2
@export var emit_hz: float = 30.0
@export var color: Color = Color(0.2, 0.9, 1.0, 0.9)

# Optional overrides / binding for emit_hz
@export var override_emit_hz_enabled: bool = false
@export var override_emit_hz_value: float = 30.0

@export var bind_emit_hz_property: StringName = &"" # e.g. &"current_shooting_rate"
@export var emit_hz_min: float = 1.0
@export var emit_hz_max: float = 60.0


# -------------------------------------------------------------------
# Optional: auto-register receiver
# -------------------------------------------------------------------
@export_category("Receiver")
@export var auto_register_receiver := false
@export var receiver_node_path: NodePath


var _mgr: LidarManager
var _reg: LidarRegistrar
var _body: CollisionObject3D
var _timer := 0.0
var _bind_node: Node = null


func _ready() -> void:
	_mgr = LidarAccess.manager(get_tree())
	_reg = LidarAccess.registrar(get_tree())

	if _mgr == null:
		push_warning("LidarTrailEmitter: LidarManager not found. Ensure LidarAPI is in group 'lidar_api'.")
		return

	_body = _resolve_body()
	if _body == null:
		push_warning("LidarTrailEmitter: No CollisionObject3D found. Attach to a body or a child of a body.")
		return

	# Cache bind node (optional)
	if bind_node_path != NodePath():
		_bind_node = get_node_or_null(bind_node_path)

	# Optional auto receiver register
	if auto_register_receiver:
		var receiver := _resolve_receiver()
		if receiver != null:
			if _reg != null and _reg.has_method("register_node"):
				_reg.call("register_node", receiver)
			else:
				_mgr.register_receiver(receiver)


func _physics_process(dt: float) -> void:
	if emission_mode != MODE_CONTINUOUS:
		return
	if _mgr == null or _body == null:
		return

	var hz := _get_emit_hz()
	if hz <= 0.0:
		return

	_timer += dt
	var step: float = 1.0 / max(hz, 0.001)

	while _timer >= step:
		_timer -= step
		_emit_once(-1.0, Color(0, 0, 0, 0), -1.0, false)


# -------------------------------------------------------------------
# PUBLIC API: switch modes at runtime
# -------------------------------------------------------------------
func set_mode_continuous() -> void:
	emission_mode = MODE_CONTINUOUS
	_timer = 0.0

func set_mode_manual() -> void:
	emission_mode = MODE_MANUAL
	_timer = 0.0


# -------------------------------------------------------------------
# PUBLIC API: manual emission
#
# Call this from gameplay code to emit exactly one trail sample now.
#
# Parameters are OPTIONAL and only affect THIS emission:
#  - radius_override < 0 => use normal radius logic
#  - color_override_alpha <= 0 and use_color_override=false => use emitter's color
#  - lifetime_override < 0 => use emitter's trail_lifetime_s
#
# Example:
#   $LidarTrailEmitter.emit_now()
#   $LidarTrailEmitter.emit_now(0.35)
#   $LidarTrailEmitter.emit_now(0.35, Color.RED, 0.25, true)
# -------------------------------------------------------------------
func emit_now(
	radius_override: float = -1.0,
	color_override: Color = Color(0, 0, 0, 0),
	lifetime_override: float = -1.0,
	use_color_override: bool = false
) -> void:
	if emission_mode == MODE_MANUAL and not manual_emission_enabled:
		return
	if _mgr == null or _body == null:
		return

	_emit_once(radius_override, color_override, lifetime_override, use_color_override)


# -------------------------------------------------------------------
# Resolve body (keep "this: Node = self" to avoid editor inference issues)
# -------------------------------------------------------------------
func _resolve_body() -> CollisionObject3D:
	var this: Node = self
	if this is CollisionObject3D:
		return this as CollisionObject3D

	var p := get_parent()
	if p is CollisionObject3D:
		return p as CollisionObject3D

	var n: Node = p
	while n != null:
		if n is CollisionObject3D:
			return n as CollisionObject3D
		n = n.get_parent()

	return null


func _resolve_receiver() -> GeometryInstance3D:
	if receiver_node_path != NodePath():
		var node := get_node_or_null(receiver_node_path)
		if node is GeometryInstance3D:
			return node as GeometryInstance3D

	var this: Node = self
	if this is GeometryInstance3D:
		return this as GeometryInstance3D

	var p := get_parent()
	if p is GeometryInstance3D:
		return p as GeometryInstance3D

	var n: Node = p
	while n != null:
		if n is GeometryInstance3D:
			return n as GeometryInstance3D
		n = n.get_parent()

	return null


# -------------------------------------------------------------------
# Emit (internal)
# - Supports per-call overrides (manual emission API uses this)
# -------------------------------------------------------------------
func _emit_once(
	radius_override: float,
	color_override: Color,
	lifetime_override: float,
	use_color_override: bool
) -> void:
	var xf := _body.global_transform

	# Determine radius
	var radius :=  _clamp_radius(radius_override) if (radius_override >= 0.0) else _get_radius()

	# Determine color + lifetime
	var out_color := color_override if use_color_override else color
	var out_life := lifetime_override if  (lifetime_override >= 0.0) else trail_lifetime_s

	# If collision-shape-size is enabled and we are a CollisionShape3D,
	# we can emit box/capsule/cylinder volumes.
	# BUT if radius_override is provided or override/bind is active, we can override a sphere radius.
	var this: Node = self
	if use_collision_shape_size and this is CollisionShape3D:
		var cs := this as CollisionShape3D
		var shape := cs.shape
		if shape != null:
			var shape_global_xf := xf * cs.transform

			# Sphere override path:
			var wants_sphere_override := (radius_override >= 0.0) or override_radius_enabled or (bind_radius_property != &"")
			if wants_sphere_override and shape is SphereShape3D:
				_mgr.add_volume(
					shape_global_xf,
					LidarManager.TYPE_SPHERE,
					Vector4(radius, 0, 0, 0),
					out_color,
					out_life
				)
				return

			# Otherwise emit the actual shape
			_emit_shape_volume(shape_global_xf, shape, out_color, out_life)
			return

	# Fallback: point (uses radius as point "sphere" radius)
	_mgr.add_volume(
		Transform3D(Basis.IDENTITY, xf.origin),
		LidarManager.TYPE_POINT,
		Vector4(radius, 0, 0, 0),
		out_color,
		out_life
	)


func _emit_shape_volume(global_xf: Transform3D, shape: Shape3D, out_color: Color, out_life: float) -> void:
	if shape is SphereShape3D:
		var r := (shape as SphereShape3D).radius
		_mgr.add_volume(global_xf, LidarManager.TYPE_SPHERE, Vector4(r, 0, 0, 0), out_color, out_life)

	elif shape is BoxShape3D:
		var he := (shape as BoxShape3D).size * 0.5
		_mgr.add_volume(global_xf, LidarManager.TYPE_BOX, Vector4(he.x, he.y, he.z, 0), out_color, out_life)

	elif shape is CapsuleShape3D:
		var c := shape as CapsuleShape3D
		_mgr.add_volume(global_xf, LidarManager.TYPE_CAPSULE, Vector4(c.radius, c.height * 0.5, 0, 0), out_color, out_life)

	elif shape is CylinderShape3D:
		var cy := shape as CylinderShape3D
		_mgr.add_volume(global_xf, LidarManager.TYPE_CYLINDER, Vector4(cy.radius, cy.height * 0.5, 0, 0), out_color, out_life)

	else:
		_mgr.add_volume(
			Transform3D(Basis.IDENTITY, global_xf.origin),
			LidarManager.TYPE_POINT,
			Vector4(_clamp_radius(fallback_sphere_radius), 0, 0, 0),
			out_color,
			out_life
		)


# -------------------------------------------------------------------
# Value getters (radius / hz)
# -------------------------------------------------------------------
func _get_radius() -> float:
	# 1) bound property wins (if set and node exists)
	if bind_radius_property != &"" and _bind_node != null:
		var v = _bind_node.get(bind_radius_property)
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			return _clamp_radius(float(v))

	# 2) explicit override
	if override_radius_enabled:
		return _clamp_radius(override_radius_value)

	# 3) default fallback
	return _clamp_radius(fallback_sphere_radius)


func _get_emit_hz() -> float:
	# 1) bound property (if set)
	if bind_emit_hz_property != &"" and _bind_node != null:
		var v = _bind_node.get(bind_emit_hz_property)
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			return clamp(float(v), emit_hz_min, emit_hz_max)

	# 2) explicit override
	if override_emit_hz_enabled:
		return clamp(override_emit_hz_value, emit_hz_min, emit_hz_max)

	# 3) default
	return clamp(emit_hz, emit_hz_min, emit_hz_max)


func _clamp_radius(r: float) -> float:
	return clamp(r, radius_min, radius_max)
