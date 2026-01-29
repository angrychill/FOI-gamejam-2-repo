extends Node
class_name LidarFX

const MAX_SHAPES := 256

const SHAPE_POINT  := 0
const SHAPE_SPHERE := 1
const SHAPE_CONE   := 2

class Shape:
	var type: int
	var pos: Vector3
	var dir: Vector3
	var params: Vector4
	var color: Color
	var ttl: float

	func _init(t: int, p: Vector3, d: Vector3, pr: Vector4, c: Color, time_to_live: float) -> void:
		type = t
		pos = p
		dir = d
		params = pr
		color = c
		ttl = time_to_live

var _shapes: Array[Shape] = []
var _dirty := true

# Receiver materials (weak refs so freed nodes don’t leak)
var _receivers: Array[WeakRef] = []

# Fixed-size buffers that match shader uniforms
var _shape_count: int = 0
var _types := PackedInt32Array()
var _pos := PackedVector3Array()
var _dir := PackedVector3Array()
var _params := PackedVector4Array()
var _colors := PackedColorArray()

func _ready() -> void:
	_types.resize(MAX_SHAPES)
	_pos.resize(MAX_SHAPES)
	_dir.resize(MAX_SHAPES)
	_params.resize(MAX_SHAPES)
	_colors.resize(MAX_SHAPES)
	_clear_buffers()
	_commit_to_receivers()

func _process(delta: float) -> void:
	var changed := false

	# TTL countdown
	for i in range(_shapes.size() - 1, -1, -1):
		var s := _shapes[i]
		if s.ttl > 0.0:
			s.ttl -= delta
			if s.ttl <= 0.0:
				_shapes.remove_at(i)
				changed = true

	if changed:
		_dirty = true

	# Clean dead receiver refs
	for i in range(_receivers.size() - 1, -1, -1):
		var m:Object= _receivers[i].get_ref()
		if m == null:
			_receivers.remove_at(i)

	if _dirty:
		_rebuild_buffers()
		_commit_to_receivers()
		_dirty = false

# ---------------- Receiver registration ----------------

func register_material(mat: ShaderMaterial) -> void:
	if mat == null:
		return

	# Avoid duplicates
	for w in _receivers:
		if w.get_ref() == mat:
			return

	_receivers.append(weakref(mat))

	# Ensure the shader has the expected params immediately
	_commit_to_material(mat)

func unregister_material(mat: ShaderMaterial) -> void:
	for i in range(_receivers.size() - 1, -1, -1):
		if _receivers[i].get_ref() == mat:
			_receivers.remove_at(i)

# ---------------- Public API (simple) ----------------

func clear() -> void:
	_shapes.clear()
	_dirty = true

func add_point(world_pos: Vector3, color: Color, radius: float = 0.08, soft_edge: float = 0.06, strength: float = 1.0, ttl: float = 0.0) -> void:
	_add_shape(SHAPE_POINT, world_pos, Vector3.UP, Vector4(radius, soft_edge, strength, 0.0), color, ttl)

func add_sphere(center: Vector3, color: Color, radius: float = 0.6, soft_edge: float = 0.25, strength: float = 1.0, ttl: float = 0.0) -> void:
	_add_shape(SHAPE_SPHERE, center, Vector3.UP, Vector4(radius, soft_edge, strength, 0.0), color, ttl)

func add_cone(apex: Vector3, direction: Vector3, color: Color, angle_deg: float = 18.0, length: float = 3.0, soft_edge: float = 0.2, strength: float = 1.0, ttl: float = 0.0) -> void:
	var dir := direction.normalized()
	var cos_angle := cos(deg_to_rad(angle_deg))
	# params: x=length, y=cos(angle), z=soft_edge, w=strength
	_add_shape(SHAPE_CONE, apex, dir, Vector4(length, cos_angle, soft_edge, strength), color, ttl)

func add_from_hit(hit: Dictionary, shape_type: int = SHAPE_POINT, color: Color = Color(0.2, 1.0, 0.4), radius: float = 0.12, ttl: float = 1.5) -> void:
	if hit.is_empty():
		return
	var p: Vector3 = hit.position
	var n: Vector3 = hit.normal

	match shape_type:
		SHAPE_POINT:
			add_point(p, color, radius, radius * 0.75, 1.0, ttl)
		SHAPE_SPHERE:
			add_sphere(p, color, radius, radius * 0.5, 1.0, ttl)
		SHAPE_CONE:
			add_cone(p + n * 0.02, n, color, 18.0, radius * 12.0, radius * 2.0, 1.0, ttl)

# ---------------- Internals ----------------

func _add_shape(t: int, p: Vector3, d: Vector3, pr: Vector4, c: Color, ttl: float) -> void:
	if _shapes.size() >= MAX_SHAPES:
		_shapes.pop_front()
	_shapes.append(Shape.new(t, p, d, pr, c, ttl))
	_dirty = true

func _clear_buffers() -> void:
	_shape_count = 0
	for i in range(MAX_SHAPES):
		_types[i] = -1
		_pos[i] = Vector3.ZERO
		_dir[i] = Vector3.UP
		_params[i] = Vector4.ZERO
		_colors[i] = Color(0, 0, 0, 0)

func _rebuild_buffers() -> void:
	_clear_buffers()

	_shape_count = min(_shapes.size(), MAX_SHAPES)
	for i in range(_shape_count):
		var s := _shapes[i]
		_types[i] = s.type
		_pos[i] = s.pos
		_dir[i] = s.dir
		_params[i] = s.params
		_colors[i] = s.color

func _commit_to_receivers() -> void:
	for w in _receivers:
		var mat :ShaderMaterial= w.get_ref()
		if mat != null:
			_commit_to_material(mat)

func _commit_to_material(mat: ShaderMaterial) -> void:
	# These uniform names MUST match the shader code below
	mat.set_shader_parameter("lidar_shape_count", _shape_count)
	mat.set_shader_parameter("lidar_shape_types", _types)
	mat.set_shader_parameter("lidar_shape_pos", _pos)
	mat.set_shader_parameter("lidar_shape_dir", _dir)
	mat.set_shader_parameter("lidar_shape_params", _params)
	mat.set_shader_parameter("lidar_shape_colors", _colors)
