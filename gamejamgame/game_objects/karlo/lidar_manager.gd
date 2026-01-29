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

# Lifetime bookkeeping (in seconds)
var _birth_ms := PackedInt64Array()
var _lifetime_s := PackedFloat32Array() # <=0 => infinite
var _dirty := true

# Receivers (any geometry instance)
var _receivers: Array[GeometryInstance3D] = []

func _ready() -> void:
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

	set_process(true)

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
func add_volume(global_xform: Transform3D, type: int, params: Vector4, color: Color, lifetime_s: float = 0.0) -> void:
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

	_birth_ms[idx] = Time.get_ticks_msec()
	_lifetime_s[idx] = lifetime_s
	_fade[idx] = 1.0

	_dirty = true

func _process(_dt: float) -> void:
	_update_fades()
	if _dirty:
		_push_to_all()
		_dirty = false

func _update_fades() -> void:
	var now := Time.get_ticks_msec()
	var active :int = min(_count, MAX_SHAPES)
	var any_changed := false

	for i in range(active):
		if _colors[i].a <= 0.0:
			if _fade[i] != 0.0:
				_fade[i] = 0.0
				any_changed = true
			continue

		var life := _lifetime_s[i]
		if life <= 0.0:
			if _fade[i] != 1.0:
				_fade[i] = 1.0
				any_changed = true
			continue

		var age_s := float(now - _birth_ms[i]) / 1000.0
		var f :float= clamp(1.0 - (age_s / life), 0.0, 1.0)

		if abs(_fade[i] - f) > 0.001:
			_fade[i] = f
			any_changed = true

		if f <= 0.0 and _colors[i].a > 0.0:
			_colors[i].a = 0.0
			any_changed = true

	if any_changed:
		_dirty = true

func _push_to_all() -> void:
	for geo in _receivers:
		if is_instance_valid(geo):
			_push_to_receiver(geo)

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

func _apply_uniforms(sm: ShaderMaterial) -> void:
	sm.set_shader_parameter("lidar_shape_count", min(_count, MAX_SHAPES))
	sm.set_shader_parameter("lidar_t0", _t0)
	sm.set_shader_parameter("lidar_t1", _t1)
	sm.set_shader_parameter("lidar_t2", _t2)
	sm.set_shader_parameter("lidar_t3", _t3)
	sm.set_shader_parameter("lidar_params", _params)
	sm.set_shader_parameter("lidar_colors", _colors)
	sm.set_shader_parameter("lidar_fade", _fade)

func _push_to_receiver(geo: GeometryInstance3D) -> void:
	# 1) material_override (works for many geometry nodes)
	var sm := _pick_overlay_shader(geo.material_override)
	if sm != null:
		_apply_uniforms(sm)

	# 2) MeshInstance3D surfaces (per-surface materials)
	if geo is MeshInstance3D:
		var mi := geo as MeshInstance3D
		if mi.mesh:
			var sc := mi.mesh.get_surface_count()
			for s in range(sc):
				var surf_mat := mi.get_active_material(s)
				var sm_s := _pick_overlay_shader(surf_mat)
				if sm_s != null:
					_apply_uniforms(sm_s)

	# 3) CSG nodes: CSGShape3D has a single `material` property
	# (CSGMesh3D inherits CSGShape3D)
	if geo is CSGShape3D:
		var csg := geo as CSGShape3D
		var sm_csg := _pick_overlay_shader(csg.material)
		if sm_csg != null:
			_apply_uniforms(sm_csg)

	# 4) MultiMeshInstance3D: usually only material_override
	# (already covered by #1). Included here only for clarity.
