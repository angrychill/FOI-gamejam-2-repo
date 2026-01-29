extends Node
class_name LidarManager

const MAX_SHAPES := 256

const TYPE_POINT    := 0
const TYPE_SPHERE   := 1
const TYPE_BOX      := 2
const TYPE_CAPSULE  := 3
const TYPE_CYLINDER := 4

var _count := 0

var _t0 := PackedVector4Array()
var _t1 := PackedVector4Array()
var _t2 := PackedVector4Array()
var _t3 := PackedVector4Array()
var _params := PackedVector4Array()
var _colors := PackedColorArray()

var _receivers: Array[MeshInstance3D] = []

func _ready() -> void:
	_t0.resize(MAX_SHAPES)
	_t1.resize(MAX_SHAPES)
	_t2.resize(MAX_SHAPES)
	_t3.resize(MAX_SHAPES)
	_params.resize(MAX_SHAPES)
	_colors.resize(MAX_SHAPES)

	for i in range(MAX_SHAPES):
		_t0[i] = Vector4(1, 0, 0, 0)
		_t1[i] = Vector4(0, 1, 0, 0)
		_t2[i] = Vector4(0, 0, 1, 0)
		_t3[i] = Vector4(0, 0, 0, 0)
		_params[i] = Vector4(0, 0, 0, 0)
		_colors[i] = Color(0, 0, 0, 0)

func register_receiver(mesh: MeshInstance3D) -> void:
	if mesh == null:
		return
	if not _receivers.has(mesh):
		_receivers.append(mesh)
		# push current state immediately so it "syncs" when added
		_push_to_mesh(mesh)

func unregister_receiver(mesh: MeshInstance3D) -> void:
	_receivers.erase(mesh)

func clear() -> void:
	_count = 0
	for i in range(MAX_SHAPES):
		_colors[i] = Color(0, 0, 0, 0)
	_push_to_all()

func add_volume(global_xform: Transform3D, type: int, params: Vector4, color: Color) -> void:
	var idx := _count % MAX_SHAPES
	_count += 1

	var B := global_xform.basis.orthonormalized()
	var O := global_xform.origin

	_t0[idx] = Vector4(B.x.x, B.x.y, B.x.z, 0.0)
	_t1[idx] = Vector4(B.y.x, B.y.y, B.y.z, 0.0)
	_t2[idx] = Vector4(B.z.x, B.z.y, B.z.z, 0.0)
	_t3[idx] = Vector4(O.x, O.y, O.z, float(type))

	_params[idx] = params
	_colors[idx] = color

	_push_to_all()

func _push_to_all() -> void:
	for m in _receivers:
		if is_instance_valid(m):
			_push_to_mesh(m)

func _push_to_mesh(mesh: MeshInstance3D) -> void:
	var mat := mesh.get_active_material(0)
	if mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		sm.set_shader_parameter("lidar_shape_count", min(_count, MAX_SHAPES))
		sm.set_shader_parameter("lidar_t0", _t0)
		sm.set_shader_parameter("lidar_t1", _t1)
		sm.set_shader_parameter("lidar_t2", _t2)
		sm.set_shader_parameter("lidar_t3", _t3)
		sm.set_shader_parameter("lidar_params", _params)
		sm.set_shader_parameter("lidar_colors", _colors)
