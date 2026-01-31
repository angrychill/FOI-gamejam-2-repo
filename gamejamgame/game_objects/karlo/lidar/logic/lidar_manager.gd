extends Node
class_name LidarManager

const MAX_SHAPES := 256

const TYPE_POINT    := 0
const TYPE_SPHERE   := 1
const TYPE_BOX      := 2
const TYPE_CAPSULE  := 3
const TYPE_CYLINDER := 4

# --- Shape storage ---
var _count := 0
var _t0 := PackedVector4Array()
var _t1 := PackedVector4Array()
var _t2 := PackedVector4Array()
var _t3 := PackedVector4Array()
var _params := PackedVector4Array()
var _colors := PackedColorArray()
var _fade := PackedFloat32Array()
var _time_now_s: float = 0.0

# Lifetime bookkeeping (in seconds)
var _birth_ms := PackedInt64Array()
var _lifetime_s := PackedFloat32Array() # <=0 => infinite
var _dirty := true

# Receivers (any geometry instance)
var _receivers: Array[GeometryInstance3D] = []

func _ready() -> void:
	_ensure_buffers()
	set_process(true)

func _ensure_buffers() -> void:
	# If already initialized, do nothing
	if _t0.size() == MAX_SHAPES:
		return

	_t0.resize(MAX_SHAPES)
	_t1.resize(MAX_SHAPES)
	_t2.resize(MAX_SHAPES)
	_t3.resize(MAX_SHAPES)
	_params.resize(MAX_SHAPES)
	_colors.resize(MAX_SHAPES)
	_fade.resize(MAX_SHAPES)
	_birth_ms.resize(MAX_SHAPES)
	_lifetime_s.resize(MAX_SHAPES)

	for i in range(MAX_SHAPES):
		_t0[i] = Vector4(1, 0, 0, 0)
		_t1[i] = Vector4(0, 1, 0, 0)
		_t2[i] = Vector4(0, 0, 1, 0)
		_t3[i] = Vector4(0, 0, 0, 0)
		_params[i] = Vector4(0, 0, 0, 0)
		_colors[i] = Color(0, 0, 0, 0)
		_fade[i] = 0.0
		_birth_ms[i] = 0
		_lifetime_s[i] = 0.0


# ✅ Accept any GeometryInstance3D (MeshInstance3D, CSGMesh3D, MultiMeshInstance3D, etc.)
func register_receiver(geo: GeometryInstance3D) -> void:
	if geo == null:
		return
	if not _receivers.has(geo):
		_receivers.append(geo)
		_dirty = true

func unregister_receiver(geo: GeometryInstance3D) -> void:
	_receivers.erase(geo)

func clear() -> void:
	_count = 0
	for i in range(MAX_SHAPES):
		_colors[i] = Color(0, 0, 0, 0)
		_fade[i] = 0.0
	_dirty = true

# lifetime_s:
#  - <= 0 => infinite
#  - > 0  => fades from 1 -> 0 over that duration
func add_volume(global_xform: Transform3D, type: int, params: Vector4, color: Color, lifetime_s: float = 0.0) -> int:
	_ensure_buffers()

	var idx := _count % MAX_SHAPES
	_count += 1

	var B := global_xform.basis.orthonormalized()
	var O := global_xform.origin

	_t0[idx] = Vector4(B.x.x, B.x.y, B.x.z, 0.0)
	_t1[idx] = Vector4(B.y.x, B.y.y, B.y.z, 0.0)
	_t2[idx] = Vector4(B.z.x, B.z.y, B.z.z, 0.0)
	_t3[idx] = Vector4(O.x, O.y, O.z, float(type))

	# Store birth time in params.w
	var birth_s := float(Time.get_ticks_msec()) * 0.001
	_params[idx] = Vector4(params.x, params.y, params.z, birth_s)

	_colors[idx] = color

	# Store lifetime in _fade (repurposed)
	_fade[idx] = lifetime_s # <=0 => infinite

	_dirty = true

	return idx


func clear_volume(idx: int) -> void:
	if idx < 0 or idx >= MAX_SHAPES:
		return

	_colors[idx] = Color(0, 0, 0, 0)
	_fade[idx] = 0.0
	_dirty = true


func _process(_dt: float) -> void:
	_time_now_s = float(Time.get_ticks_msec()) * 0.001

	if _dirty:
		_push_to_all(true)   # push arrays + time
		_dirty = false
	else:
		_push_to_all(false)  # push only time



func _push_to_all(push_arrays: bool) -> void:
	for i in range(_receivers.size() - 1, -1, -1):
		if not is_instance_valid(_receivers[i]):
			_receivers.remove_at(i)
			continue
		_push_to_receiver(_receivers[i], push_arrays)




func _push_to_receiver(geo: GeometryInstance3D, push_arrays: bool) -> void:
	# 0) material_override (covers MultiMeshInstance3D and many others)
	var sm := _pick_overlay_shader(geo.material_override)
	if sm != null:
		_copy_base_material_into_lidar_shader(geo.material_override, sm)
		_apply_uniforms(sm, push_arrays)

	# 1) MeshInstance3D: per-surface materials (this is what you were missing)
	if geo is MeshInstance3D:
		var mi := geo as MeshInstance3D
		var mesh := mi.mesh
		if mesh != null:
			var sc := mesh.get_surface_count()
			for s in range(sc):
				# Prefer surface override, otherwise active
				var mat: Material = mi.get_surface_override_material(s)
				if mat == null:
					mat = mi.get_active_material(s)

				var sm_s := _pick_overlay_shader(mat)
				if sm_s != null:
					_copy_base_material_into_lidar_shader(mat, sm_s)
					_apply_uniforms(sm_s, push_arrays)

	# 2) CSGShape3D / CSGMesh3D: single material
	if geo is CSGShape3D:
		var csg := geo as CSGShape3D
		var mat_csg: Material = csg.material
		var sm_csg := _pick_overlay_shader(mat_csg)
		if sm_csg != null:
			_copy_base_material_into_lidar_shader(mat_csg, sm_csg)
			_apply_uniforms(sm_csg, push_arrays)


# --- Material selection helpers ---

# Returns the ShaderMaterial that should receive uniforms:
# - if mat itself is ShaderMaterial -> use it
# - else if mat is BaseMaterial3D and has next_pass ShaderMaterial -> use next_pass
func _pick_overlay_shader(mat: Material) -> ShaderMaterial:
	if mat == null:
		return null

	if mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		return sm if sm.shader != null else null

	if mat is BaseMaterial3D:
		var np := (mat as BaseMaterial3D).next_pass
		if np is ShaderMaterial:
			var sm2 := np as ShaderMaterial
			return sm2 if sm2.shader != null else null

	return null

func _apply_uniforms(sm: ShaderMaterial, push_arrays: bool) -> void:
	# Always update time
	sm.set_shader_parameter("time_now_s", _time_now_s)

	# Arrays are still valid even when we skip pushing them,
	# because the ShaderMaterial keeps the last values.
	# Only set false if you *truly* want to disable lidar evaluation.
	sm.set_shader_parameter("lidar_arrays_valid", true)

	if not push_arrays:
		return

	sm.set_shader_parameter("lidar_shape_count", min(_count, MAX_SHAPES))
	sm.set_shader_parameter("lidar_t0", _t0)
	sm.set_shader_parameter("lidar_t1", _t1)
	sm.set_shader_parameter("lidar_t2", _t2)
	sm.set_shader_parameter("lidar_t3", _t3)
	sm.set_shader_parameter("lidar_params", _params)
	sm.set_shader_parameter("lidar_colors", _colors)

	# IMPORTANT: lidar_fade now stores lifetime_s (<=0 => infinite)
	sm.set_shader_parameter("lidar_fade", _fade)


func _copy_base_material_into_lidar_shader(base_mat: Material, sm: ShaderMaterial) -> void:
	if base_mat == null or sm == null:
		return

	if base_mat is BaseMaterial3D:
		var bm := base_mat as BaseMaterial3D
		sm.set_shader_parameter("base_albedo_color", bm.albedo_color)
		sm.set_shader_parameter("base_albedo_tex", bm.albedo_texture)
