extends Node
class_name LidarTrailEmitter

# Optional: if you attach this script to a CollisionShape3D and want that exact shape size.
@export var use_collision_shape_size: bool = true
@export var fallback_sphere_radius: float = 0.15

@export var trail_lifetime_s: float = 1.2
@export var emit_hz: float = 30.0
@export var color: Color = Color(0.2, 0.9, 1.0, 0.9)

# Optional: register the receiver automatically (useful if you want this object
# to also be a lidar "receiver" mesh). If you only emit trail volumes and do not
# need the node to receive overlay, you can turn this off.
@export var auto_register_receiver := false

# Optional: if auto_register_receiver is on, which node do we register as receiver?
# - If empty, we’ll try to find a GeometryInstance3D near/above this node.
@export var receiver_node_path: NodePath

var _mgr: LidarManager
var _reg: LidarRegistrar
var _body: CollisionObject3D
var _timer := 0.0

func _ready() -> void:
	# --- Loose coupling: resolve from LidarAccess only ---
	_mgr = LidarAccess.manager(get_tree())
	_reg = LidarAccess.registrar(get_tree())

	if _mgr == null:
		push_warning("LidarTrailEmitter: LidarManager not found. Make sure your LidarAPI node is in group 'lidar_api'.")
		return

	_body = _resolve_body()
	if _body == null:
		push_warning("LidarTrailEmitter: No CollisionObject3D found. Attach to a body, or put this script on a child of a body.")
		return

	# Optional: auto-register a receiver (overlay target)
	if auto_register_receiver:
		var receiver := _resolve_receiver()
		if receiver != null:
			# Prefer registrar (so it can auto-apply next_pass + toggle uniform)
			if _reg != null:
				# If you exposed a public method on registrar, call it. Otherwise:
				# we can just register directly and let registrar handle scan normally.
				_reg._try_register_node(receiver) # If you want this public, rename to try_register_node() in registrar.
			else:
				_mgr.register_receiver(receiver)
		else:
			push_warning("LidarTrailEmitter: auto_register_receiver is on, but no GeometryInstance3D receiver was found.")

func _exit_tree() -> void:
	# Optional clean unregister if we registered a receiver via manager directly.
	# (If you rely on registrar’s auto-unregister, you can skip this.)
	pass

func _physics_process(dt: float) -> void:
	if _mgr == null or _body == null:
		return

	_timer += dt
	var step: float = 1.0 / max(emit_hz, 0.001)
	while _timer >= step:
		_timer -= step
		_emit_once()

# ------------------------------------------------------------
# Resolve the CollisionObject3D we sample the trail from
# ------------------------------------------------------------
func _resolve_body() -> CollisionObject3D:
	# If attached directly to a body
	var this: Node = self
	if this is CollisionObject3D:
		return this as CollisionObject3D

	# Parent first (common: script on CollisionShape3D under a body)
	var p := get_parent()
	if p is CollisionObject3D:
		return p as CollisionObject3D

	# Walk up
	var n: Node = p
	while n != null:
		if n is CollisionObject3D:
			return n as CollisionObject3D
		n = n.get_parent()

	return null

# ------------------------------------------------------------
# Resolve a GeometryInstance3D to register as receiver (optional)
# ------------------------------------------------------------
func _resolve_receiver() -> GeometryInstance3D:
	# Explicit path wins
	if receiver_node_path != NodePath():
		var node := get_node_or_null(receiver_node_path)
		if node is GeometryInstance3D:
			return node as GeometryInstance3D

	# If this node is geometry
	var this: Node = self
	if this is GeometryInstance3D:
		return this as GeometryInstance3D

	# Parent check
	var p := get_parent()
	if p is GeometryInstance3D:
		return p as GeometryInstance3D

	# Walk up
	var n: Node = p
	while n != null:
		if n is GeometryInstance3D:
			return n as GeometryInstance3D
		n = n.get_parent()

	return null

# ------------------------------------------------------------
# Emit one sample
# ------------------------------------------------------------
func _emit_once() -> void:
	var body_xf := _body.global_transform

	# If attached to a CollisionShape3D and using exact size:
	var this: Node = self
	if use_collision_shape_size and this is CollisionShape3D:
		var cs := this as CollisionShape3D
		var shape := cs.shape
		if shape != null:
			# CollisionShape3D's transform is local to the body, so compose it.
			var shape_global_xf := body_xf * cs.transform
			_emit_shape_volume(shape_global_xf, shape)
			return

	# Fallback: simple point trail at body origin
	_mgr.add_volume(
		Transform3D(Basis.IDENTITY, body_xf.origin),
		LidarManager.TYPE_POINT,
		Vector4(fallback_sphere_radius, 0, 0, 0),
		color,
		trail_lifetime_s
	)

func _emit_shape_volume(global_xf: Transform3D, shape: Shape3D) -> void:
	if shape is SphereShape3D:
		_mgr.add_volume(global_xf, LidarManager.TYPE_SPHERE, Vector4(shape.radius, 0, 0, 0), color, trail_lifetime_s)

	elif shape is BoxShape3D:
		var he := (shape as BoxShape3D).size * 0.5
		_mgr.add_volume(global_xf, LidarManager.TYPE_BOX, Vector4(he.x, he.y, he.z, 0), color, trail_lifetime_s)

	elif shape is CapsuleShape3D:
		var c := shape as CapsuleShape3D
		_mgr.add_volume(global_xf, LidarManager.TYPE_CAPSULE, Vector4(c.radius, c.height * 0.5, 0, 0), color, trail_lifetime_s)

	elif shape is CylinderShape3D:
		var cy := shape as CylinderShape3D
		_mgr.add_volume(global_xf, LidarManager.TYPE_CYLINDER, Vector4(cy.radius, cy.height * 0.5, 0, 0), color, trail_lifetime_s)

	else:
		_mgr.add_volume(
			Transform3D(Basis.IDENTITY, global_xf.origin),
			LidarManager.TYPE_POINT,
			Vector4(fallback_sphere_radius, 0, 0, 0),
			color,
			trail_lifetime_s
		)
