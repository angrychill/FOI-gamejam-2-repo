extends Node
class_name LidarRegistrar

@export_category("Lidar Registrar")

# ✅ Export the manager directly (drag LidarManager node here in Inspector)
@export var manager: LidarManager

# -------------------------------------------------------------------
# MARKING (who counts as "lidar receiver")
# -------------------------------------------------------------------
@export_category("Marking")
@export_group("Discovery", "mark_")
@export var mark_use_group := true
@export var mark_group_name := "lidar"

@export_subgroup("Metadata", "mark_meta_")
@export var mark_meta_use := true
@export var mark_meta_key := "lidar_enabled"

# -------------------------------------------------------------------
# TOGGLE / DISABLE (who gets overlay applied or turned off)
# -------------------------------------------------------------------
@export_category("Toggle")
@export_group("Disable by Group", "toggle_group_")
@export var toggle_group_use_disable := true
@export var toggle_group_disable_name := "lidar_off"

@export_subgroup("Overlay Enabled Metadata", "toggle_meta_")
@export var toggle_meta_use_overlay := true
@export var toggle_meta_overlay_key := "lidar_overlay_enabled" # bool; default true
@export var toggle_meta_default_overlay_enabled := true

@export_subgroup("Shader Uniform", "toggle_uniform_")
@export var toggle_uniform_enabled_name := "lidar_enabled" # must exist in shader

# -------------------------------------------------------------------
# OVERLAY AUTO-APPLY
# -------------------------------------------------------------------
@export_category("Overlay")
@export_group("Base Material", "base_")
@export var base_material_template: BaseMaterial3D
# If a surface has ShaderMaterial, we normally can't attach next_pass.
# If you want the registrar to force your base material on it, enable this.
@export var base_replace_shader_materials := false

@export_group("Next Pass Overlay", "apply_")
@export var apply_auto_apply_next_pass := true
@export var apply_overlay_shader: Shader
@export var apply_overlay_shader_template: ShaderMaterial # optional; duplicated per object if set

# -------------------------------------------------------------------
# SCANNING
# -------------------------------------------------------------------
@export_category("Scanning")
@export_group("Startup", "scan_")
@export var scan_on_ready := true

# Track what we registered so we can unregister cleanly
var _registered: Dictionary = {} # GeometryInstance3D -> true

func _ready() -> void:
	if manager == null:
		push_warning("LidarRegistrar: 'manager' is not assigned. Drag your LidarManager node into the inspector.")
		return

	if scan_on_ready:
		scan_and_register_all()

	get_tree().node_added.connect(_on_node_added)

func _on_node_added(n: Node) -> void:
	call_deferred("_try_register_node", n)

func scan_and_register_all() -> void:
	if manager == null:
		return

	# Group search is fastest
	if mark_use_group:
		for n in get_tree().get_nodes_in_group(mark_group_name):
			_try_register_node(n)
		return

	# Full walk fallback
	_try_register_node(get_tree().root)

func _is_marked_for_lidar(n: Node) -> bool:
	if mark_use_group and n.is_in_group(mark_group_name):
		return true
	if mark_meta_use and n.has_meta(mark_meta_key) and bool(n.get_meta(mark_meta_key)):
		return true
	return false

func _is_overlay_enabled_for(n: Node) -> bool:
	var enabled := toggle_meta_default_overlay_enabled

	if toggle_meta_use_overlay and n.has_meta(toggle_meta_overlay_key):
		enabled = bool(n.get_meta(toggle_meta_overlay_key))

	if toggle_group_use_disable and n.is_in_group(toggle_group_disable_name):
		enabled = false

	return enabled

func _try_register_node(n: Node) -> void:
	if n == null or manager == null:
		return

	if not _is_marked_for_lidar(n):
		for c in n.get_children():
			_try_register_node(c)
		return

	if n is GeometryInstance3D:
		var geo := n as GeometryInstance3D
		var enabled := _is_overlay_enabled_for(n)

		if _registered.has(geo):
			_apply_overlay_enabled(geo, enabled)
		else:
			if apply_auto_apply_next_pass:
				_ensure_overlay_next_pass(geo)

			_apply_overlay_enabled(geo, enabled)

			manager.register_receiver(geo)
			_registered[geo] = true

			if not geo.tree_exited.is_connected(_on_registered_tree_exited):
				geo.tree_exited.connect(_on_registered_tree_exited.bind(geo), CONNECT_ONE_SHOT)

	for c in n.get_children():
		_try_register_node(c)

func _on_registered_tree_exited(geo: GeometryInstance3D) -> void:
	if manager:
		manager.unregister_receiver(geo)
	_registered.erase(geo)

# -------------------------------------------------------------------------
# PUBLIC API: toggle lidar overlay for a node at runtime
# -------------------------------------------------------------------------
func set_overlay_enabled_for(n: Node, enabled: bool) -> void:
	if n == null:
		return

	n.set_meta(toggle_meta_overlay_key, enabled)

	if n is GeometryInstance3D:
		_apply_overlay_enabled(n as GeometryInstance3D, enabled)

	for c in n.get_children():
		set_overlay_enabled_for(c, enabled)

# ===================== MATERIAL / NEXT_PASS HELPERS ======================

func _dup_base_material() -> BaseMaterial3D:
	if base_material_template == null:
		# Reasonable default if you forgot to set one:
		var bm := StandardMaterial3D.new()
		return bm
	return base_material_template.duplicate(true) as BaseMaterial3D

func _make_overlay_shader_material() -> ShaderMaterial:
	if apply_overlay_shader_template:
		return apply_overlay_shader_template.duplicate(true) as ShaderMaterial

	var sm := ShaderMaterial.new()
	sm.shader = apply_overlay_shader
	return sm

func _ensure_overlay_next_pass(geo: GeometryInstance3D) -> void:
	if apply_overlay_shader == null and apply_overlay_shader_template == null:
		push_warning("LidarRegistrar: auto_apply_next_pass is on but no overlay shader/template is assigned.")
		return

	# --- MeshInstance3D: per-surface ---
	if geo is MeshInstance3D:
		var mi := geo as MeshInstance3D
		if mi.mesh == null:
			return

		var sc := mi.mesh.get_surface_count()
		for s in range(sc):
			# Prefer override material if present, else use active, else null
			var mat := mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.get_active_material(s)

			mat = _ensure_has_base_material_on_mesh_surface(mi, s, mat)
			_set_next_pass_if_possible(mat)
		return

	# --- CSG: single material ---
	if geo is CSGShape3D:
		var csg := geo as CSGShape3D
		var mat: Material = csg.material

		# If missing, assign base material
		if mat == null:
			mat = _dup_base_material()
			csg.material = mat

		# If it's ShaderMaterial and replacement enabled, replace
		if (mat is ShaderMaterial) and base_replace_shader_materials:
			mat = _dup_base_material()
			csg.material = mat

		_set_next_pass_if_possible(mat)
		return

	# --- Fallback: material_override ---
	if geo.material_override == null and base_material_template != null:
		geo.material_override = _dup_base_material()
	_set_next_pass_if_possible(geo.material_override)

func _ensure_has_base_material_on_mesh_surface(mi: MeshInstance3D, surface: int, mat: Material) -> Material:
	# If no material at all, assign base template to override slot
	if mat == null:
		var bm := _dup_base_material()
		mi.set_surface_override_material(surface, bm)
		return bm

	# If it's ShaderMaterial, we cannot set next_pass.
	# Optionally replace with base material.
	if (mat is ShaderMaterial) and base_replace_shader_materials:
		var bm2 := _dup_base_material()
		mi.set_surface_override_material(surface, bm2)
		return bm2

	# If it's already BaseMaterial3D, good.
	return mat

func _set_next_pass_if_possible(mat: Material) -> void:
	if mat is BaseMaterial3D:
		var bm := mat as BaseMaterial3D
		# Already has something? keep it if it's a ShaderMaterial with a shader
		if bm.next_pass is ShaderMaterial and (bm.next_pass as ShaderMaterial).shader != null:
			return
		bm.next_pass = _make_overlay_shader_material()

func _apply_overlay_enabled(geo: GeometryInstance3D, enabled: bool) -> void:
	# IMPORTANT: only works if overlay is in next_pass (ShaderMaterial)
	if geo is MeshInstance3D:
		var mi := geo as MeshInstance3D
		if mi.mesh == null:
			return
		for s in range(mi.mesh.get_surface_count()):
			var mat := mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.get_active_material(s)
			_set_overlay_uniform_on_material(mat, enabled)
		return

	if geo is CSGShape3D:
		var csg := geo as CSGShape3D
		_set_overlay_uniform_on_material(csg.material, enabled)
		return

	_set_overlay_uniform_on_material(geo.material_override, enabled)

func _set_overlay_uniform_on_material(mat: Material, enabled: bool) -> void:
	if mat is BaseMaterial3D:
		var bm := mat as BaseMaterial3D
		if bm.next_pass is ShaderMaterial:
			(bm.next_pass as ShaderMaterial).set_shader_parameter(toggle_uniform_enabled_name, enabled)
