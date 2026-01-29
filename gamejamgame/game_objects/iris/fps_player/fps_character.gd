extends Camera3D

@export var target_mesh: MeshInstance3D
@export var material_slot := 0            # which surface material to update

@export var max_points: int = 256         # shader buffer size (must match shader constant)
@export var add_on_click := true

# Color options
@export var use_distance_gradient := true # if true: color is based on distance from camera
@export var near_color: Color = Color(0.1, 1.0, 0.2, 1.0)
@export var far_color: Color  = Color(1.0, 0.2, 0.1, 1.0)
@export var max_color_distance: float = 50.0

# Alternative: random colors per point (used if use_distance_gradient == false)
@export var random_color_min: Color = Color(0.2, 0.4, 1.0, 1.0)
@export var random_color_max: Color = Color(1.0, 0.3, 0.9, 1.0)

var _points: PackedVector3Array = PackedVector3Array()
var _colors: Array[Color] = []
var _count: int = 0

func _ready() -> void:
	# Pre-size buffers so we can always send fixed-size arrays to the shader.
	_points.resize(max_points)
	_colors.resize(max_points)
	for i in range(max_points):
		_points[i] = Vector3.ZERO
		_colors[i] = Color(0, 0, 0, 0) # alpha 0 = unused slot

	_push_to_shader()

func _unhandled_input(event) -> void:
	if not add_on_click:
		return

	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		shoot_lidar(event.position)

func shoot_lidar(screen_pos: Vector2) -> void:
	var space := get_world_3d().direct_space_state

	var from := project_ray_origin(screen_pos)
	var dir  := project_ray_normal(screen_pos)
	var to   := from + dir * 1000.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result := space.intersect_ray(query)
	if result.is_empty():
		return

	var hit_pos: Vector3 = result.position
	_add_lidar_point(hit_pos)

func _add_lidar_point(world_pos: Vector3) -> void:
	if not target_mesh:
		return

	# Decide the point color
	var c: Color
	if use_distance_gradient:
		var d := global_position.distance_to(world_pos)
		var t := clamp(d / max_color_distance, 0.0, 1.0)
		c = near_color.lerp(far_color, t)
	else:
		c = Color(
			randf_range(random_color_min.r, random_color_max.r),
			randf_range(random_color_min.g, random_color_max.g),
			randf_range(random_color_min.b, random_color_max.b),
			1.0
		)

	# Write into ring buffer
	var idx := _count % max_points
	_points[idx] = world_pos
	_colors[idx] = c
	_count += 1

	_push_to_shader()

func _push_to_shader() -> void:
	var mat := target_mesh.get_active_material(material_slot)
	if mat is ShaderMaterial:
		mat.set_shader_parameter("lidar_point_count", min(_count, max_points))
		mat.set_shader_parameter("lidar_points", _points)
		mat.set_shader_parameter("lidar_colors", _colors)
	else:
		push_warning("Target material is not a ShaderMaterial")
