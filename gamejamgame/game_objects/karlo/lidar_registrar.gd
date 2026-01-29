extends Node
class_name LidarRegistrar

@export var lidar_manager_path: NodePath

# Marking
@export var use_group := true
@export var group_name := "lidar"
@export var use_metadata := true
@export var metadata_key := "lidar_enabled"

# Disable group/meta toggle support
@export var use_disable_group := true
@export var disable_group_name := "lidar_off"

@export var use_overlay_metadata := true
@export var overlay_metadata_key := "lidar_overlay_enabled" # bool; default true
@export var default_overlay_enabled := true

@export var overlay_enabled_uniform := "lidar_enabled" # must exist in shader

# Overlay auto-apply
@export var auto_apply_next_pass := true
@export var overlay_shader: Shader
@export var overlay_material_template: ShaderMaterial

# Scan behavior
@export var scan_on_ready := true

@onready var _mgr: LidarManager = get_node(lidar_manager_path)

# --- NEW: keep track of what we registered so we can unregister cleanly
var _registered: Dictionary = {} # GeometryInstance3D -> true

func _ready() -> void:
	if scan_on_ready:
		scan_and_register_all()

	get_tree().node_added.connect(_on_node_added)

func _on_node_added(n: Node) -> void:
	call_deferred("_try_register_node", n)

func scan_and_register_all() -> void:
	if use_group:
		for n in get_tree().get_nodes_in_group(group_name):
			_try_register_node(n)
		return

	_try_register_node(get_tree().root)

func _is_marked_for_lidar(n: Node) -> bool:
	if use_group and n.is_in_group(group_name):
		return true
	if use_metadata and n.has_meta(metadata_key) and bool(n.get_meta(metadata_key)):
		return true
	return false

func _is_overlay_enabled_for(n: Node) -> bool:
	var enabled := default_overlay_enabled

	if use_overlay_metadata and n.has_meta(overlay_metadata_key):
		enabled = bool(n.get_meta(overlay_metadata_key))

	if use_disable_group and n.is_in_group(disable_group_name):
		enabled = false

	return enabled

func _try_register_node(n: Node) -> void:
	if n == null:
		return

	if not _is_marked_for_lidar(n):
		for c in n.get_children():
			_try_register_node(c)
		return

	if n is GeometryInstance3D:
		var geo := n as GeometryInstance3D

		# already registered?
		if _registered.has(geo):
			# still re-apply toggle in case user changed meta/groups
			_apply_overlay_enabled(geo, _is_overlay_enabled_for(n))
		else:
			if auto_apply_next_pass:
				_ensure_overlay_next_pass(geo)

			_apply_overlay_enabled(geo, _is_overlay_enabled_for(n))

			_mgr.register_receiver(geo)
			_registered[geo] = true

			# --- AUTO UNREGISTER: when this node leaves the tree
			# Use CONNECT_ONE_SHOT so we don't leak connections.
			if not geo.tree_exited.is_connected(_on_registered_tree_exited):
				geo.tree_exited.connect(_on_registered_tree_exited.bind(geo), CONNECT_ONE_SHOT)

	for c in n.get_children():
		_try_register_node(c)

func _on_registered_tree_exited(geo: GeometryInstance3D) -> void:
	# Node left the scene tree; unregister + forget.
	_mgr.unregister_receiver(geo)
	_registered.erase(geo)

# -------------------------------------------------------------------------
# PUBLIC API: toggle lidar overlay for a specific node at runtime
# - This does NOT affect whether the node is registered, only whether the
#   overlay pass draws (and thus "darkness" / glow).
# - It stores the choice in metadata so future rescans keep it.
# -------------------------------------------------------------------------
func set_overlay_enabled_for(n: Node, enabled: bool) -> void:
	if n == null:
		return

	# Store override
	n.set_meta(overlay_metadata_key, enabled)

	# Apply immediately if it's geometry
	if n is GeometryInstance3D:
		_apply_overlay_enabled(n as GeometryInstance3D, enabled)

	# Also apply to children (nice when toggling a parent)
	for c in n.get_children():
		set_overlay_enabled_for(c, enabled)

func _make_overlay_material() -> ShaderMaterial:
	if overlay_material_template:
		return overlay_material_template.duplicate(true) as ShaderMaterial

	var sm := ShaderMaterial.new()
	sm.shader = overlay_shader
	return sm

func _ensure_overlay_next_pass(geo: GeometryInstance3D) -> void:
	if overlay_shader == null and overlay_material_template == null:
		push_warning("LidarRegistrar: auto_apply_next_pass is on but no overlay_shader or overlay_material_template is assigned.")
		return

	if geo is MeshInstance3D:
		var mi := geo as MeshInstance3D
		if mi.mesh == null:
			return
		var sc := mi.mesh.get_surface_count()
		for s in range(sc):
			_set_next_pass_if_possible(mi.get_active_material(s))
		return

	if geo is CSGShape3D:
		var csg := geo as CSGShape3D
		_set_next_pass_if_possible(csg.material)
		return

	_set_next_pass_if_possible(geo.material_override)

func _set_next_pass_if_possible(mat: Material) -> void:
	if mat is BaseMaterial3D:
		var bm := mat as BaseMaterial3D
		if bm.next_pass is ShaderMaterial and (bm.next_pass as ShaderMaterial).shader != null:
			return
		bm.next_pass = _make_overlay_material()

func _apply_overlay_enabled(geo: GeometryInstance3D, enabled: bool) -> void:
	if geo is MeshInstance3D:
		var mi := geo as MeshInstance3D
		if mi.mesh == null:
			return
		var sc := mi.mesh.get_surface_count()
		for s in range(sc):
			_set_overlay_uniform_on_material(mi.get_active_material(s), enabled)
		return

	if geo is CSGShape3D:
		var csg := geo as CSGShape3D
		_set_overlay_uniform_on_material(csg.material, enabled)
		return

	_set_overlay_uniform_on_material(geo.material_override, enabled)

func _set_overlay_uniform_on_material(mat: Material, enabled: bool) -> void:
	if not (mat is BaseMaterial3D):
		return
	var bm := mat as BaseMaterial3D
	if bm.next_pass is ShaderMaterial:
		(bm.next_pass as ShaderMaterial).set_shader_parameter(overlay_enabled_uniform, enabled)
