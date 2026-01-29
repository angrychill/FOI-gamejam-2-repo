extends Node
class_name LidarRegistrar

@export var lidar_manager_path: NodePath

# How to mark geometry for lidar
@export var use_group := true
@export var group_name := "lidar"
@export var use_metadata := true
@export var metadata_key := "lidar_enabled"

# Apply overlay next_pass automatically
@export var auto_apply_next_pass := true
@export var overlay_shader: Shader # assign lidar_overlay.gdshader in Inspector
@export var overlay_material_template: ShaderMaterial # optional: if set, duplicates this per geometry

# Scan behavior
@export var scan_on_ready := true

@onready var _mgr: LidarManager = get_node(lidar_manager_path)

func _ready() -> void:
	if scan_on_ready:
		scan_and_register_all()

	# Catch nodes that appear later (instanced scenes, runtime spawning)
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(n: Node) -> void:
	# Defer one frame so materials/meshes are ready on freshly instanced nodes.
	call_deferred("_try_register_node", n)

func scan_and_register_all() -> void:
	# Group search is fastest and cleanest
	if use_group:
		for n in get_tree().get_nodes_in_group(group_name):
			_try_register_node(n)
		return

	# Otherwise full tree walk
	_try_register_node(get_tree().root)
	for child in get_tree().root.get_children():
		_try_register_node(child)

func _is_marked_for_lidar(n: Node) -> bool:
	if use_group and n.is_in_group(group_name):
		return true
	if use_metadata and n.has_meta(metadata_key) and bool(n.get_meta(metadata_key)):
		return true
	return false

func _try_register_node(n: Node) -> void:
	if n == null:
		return

	# If it's not marked, still check children (in case parent isn't marked)
	if not _is_marked_for_lidar(n):
		for c in n.get_children():
			_try_register_node(c)
		return

	# Only register geometry instances
	if n is GeometryInstance3D:
		var geo := n as GeometryInstance3D

		if auto_apply_next_pass:
			_ensure_overlay_next_pass(geo)

		_mgr.register_receiver(geo)

	# Also scan children (so you can tag a parent node)
	for c in n.get_children():
		_try_register_node(c)

func _make_overlay_material() -> ShaderMaterial:
	# If user provided a template material, duplicate it so per-object edits are possible.
	if overlay_material_template:
		return overlay_material_template.duplicate(true) as ShaderMaterial

	var sm := ShaderMaterial.new()
	sm.shader = overlay_shader
	return sm

func _ensure_overlay_next_pass(geo: GeometryInstance3D) -> void:
	if overlay_shader == null and overlay_material_template == null:
		push_warning("LidarRegistrar: auto_apply_next_pass is on but no overlay_shader or overlay_material_template is assigned.")
		return

	# MeshInstance3D: per-surface materials
	if geo is MeshInstance3D:
		var mi := geo as MeshInstance3D
		if mi.mesh == null:
			return
		var sc := mi.mesh.get_surface_count()
		for s in range(sc):
			var mat := mi.get_active_material(s)
			_set_next_pass_if_possible(mat)
		return

	# CSGShape3D has a single `material`
	if geo is CSGShape3D:
		var csg := geo as CSGShape3D
		_set_next_pass_if_possible(csg.material)
		return

	# Otherwise, try material_override
	_set_next_pass_if_possible(geo.material_override)

func _set_next_pass_if_possible(mat: Material) -> void:
	# If the material is BaseMaterial3D, attach overlay as next_pass
	if mat is BaseMaterial3D:
		var bm := mat as BaseMaterial3D
		if bm.next_pass is ShaderMaterial and (bm.next_pass as ShaderMaterial).shader != null:
			return # already set

		bm.next_pass = _make_overlay_material()
		return

	# If the material is a ShaderMaterial, we can't use next_pass. If you want,
	# you can choose to replace it with overlay (not recommended). We'll skip.
	# If mat is null, also skip.
