extends Node
class_name LidarTrailEmitter

@export var lidar_manager_path: NodePath
@export var collision_object_path: NodePath  # optional override if auto-find fails

@export var trail_lifetime_s: float = 1.2
@export var emit_hz: float = 30.0            # how many samples per second
@export var color: Color = Color(0.2, 0.9, 1.0, 0.9)

@export var use_collision_shape_size: bool = true
@export var fallback_sphere_radius: float = 0.15

var _mgr: LidarManager
var _body: CollisionObject3D
var _timer := 0.0

func _ready() -> void:
	_mgr = get_node_or_null(lidar_manager_path) as LidarManager
	if _mgr == null:
		push_warning("LidarTrailEmitter: LidarManager not found at lidar_manager_path")
		return

	_body = _resolve_body()
	if _body == null:
		push_warning("LidarTrailEmitter: No CollisionObject3D found. Attach to a body or set collision_object_path.")
		return

func _physics_process(dt: float) -> void:
	if _mgr == null or _body == null:
		return

	_timer += dt
	var step :float= 1.0 / max(emit_hz, 0.001)
	while _timer >= step:
		_timer -= step
		_emit_once()

func _resolve_body() -> CollisionObject3D:
	# 1) explicit override
	if collision_object_path != NodePath():
		var node := get_node_or_null(collision_object_path)
		if node is CollisionObject3D:
			return node as CollisionObject3D

	# 2) if THIS node is a body (rare if you attach to body directly)
	var resolve : Node = self
	if resolve is CollisionObject3D:
		return resolve as CollisionObject3D

	# 3) check parent first (covers attaching to CollisionShape3D)
	var p := get_parent()
	if p is CollisionObject3D:
		return p as CollisionObject3D

	# 4) walk up
	var n: Node = p
	while n != null:
		if n is CollisionObject3D:
			return n as CollisionObject3D
		n = n.get_parent()

	return null

func _emit_once() -> void:
	var xf := _body.global_transform

	# If you attached this script to a CollisionShape3D and want its exact size, use it.
	var _self: Node = self
	if use_collision_shape_size and _self is CollisionShape3D:
		var cs := _self as CollisionShape3D
		var shape := cs.shape
		if shape != null:
			_emit_shape_volume(xf * cs.transform, shape)
			return

	# Otherwise: simple point trail
	_mgr.add_volume(
		Transform3D(Basis.IDENTITY, xf.origin),
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
		# unknown shape => fallback point
		_mgr.add_volume(Transform3D(Basis.IDENTITY, global_xf.origin), LidarManager.TYPE_POINT, Vector4(fallback_sphere_radius, 0, 0, 0), color, trail_lifetime_s)
