extends Node3D
class_name BossHealthBar


@export var bar_width: float = 3.0
@export var bar_height: float = 0.3
@export var offset_above_boss: float = 3.0
@export var show_boss_name: bool = true
@export var boss_display_name: String = "Boss"

var max_health: int = 100
var current_health: int = 100

var background_mesh: MeshInstance3D
var health_mesh: MeshInstance3D
var label_3d: Label3D

var bg_material: StandardMaterial3D
var health_material: StandardMaterial3D

func _ready() -> void:
	_create_visuals()
	
	position = Vector3(0, offset_above_boss, 0)

func _create_visuals() -> void:
	background_mesh = MeshInstance3D.new()
	var bg_box = BoxMesh.new()
	bg_box.size = Vector3(bar_width, bar_height, 0.05)
	background_mesh.mesh = bg_box
	
	bg_material = StandardMaterial3D.new()
	bg_material.albedo_color = Color(0.1, 0.1, 0.1, 0.9)
	bg_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	background_mesh.material_override = bg_material
	
	background_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	add_child(background_mesh)
	
	health_mesh = MeshInstance3D.new()
	var health_box = BoxMesh.new()
	health_box.size = Vector3(bar_width * 0.96, bar_height * 0.7, 0.06)
	health_mesh.mesh = health_box
	
	health_material = StandardMaterial3D.new()
	health_material.albedo_color = Color(1.0, 0.3, 0.3, 1.0)  # Brighter red
	health_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	health_mesh.material_override = health_material
	health_mesh.position = Vector3(0, 0, 0.01)  # Slightly in front
	
	health_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	add_child(health_mesh)
	
	if show_boss_name:
		label_3d = Label3D.new()
		label_3d.text = boss_display_name
		label_3d.font_size = 32
		label_3d.outline_size = 8
		label_3d.outline_modulate = Color.BLACK
		label_3d.modulate = Color.WHITE
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_3d.position = Vector3(0, bar_height + 0.5, 0)
		
		label_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
		add_child(label_3d)

func _process(_delta: float) -> void:
	if background_mesh:
		var camera = get_viewport().get_camera_3d()
		if camera:
			look_at(camera.global_position, Vector3.UP)
			rotation.y += PI
			rotation.x = 0
			rotation.z = 0

func initialize(boss_name: String, boss_max_health: int) -> void:
	"""Initialize health bar with boss data"""
	max_health = boss_max_health
	current_health = boss_max_health
	boss_display_name = boss_name
	
	if label_3d:
		label_3d.text = boss_name
	
	_update_visuals()

func update_health(new_health: int) -> void:
	"""Update health bar display"""
	current_health = clampi(new_health, 0, max_health)
	_update_visuals()

func _update_visuals() -> void:
	if not health_mesh:
		return
	
	var health_percent = float(current_health) / float(max_health)
	
	var current_width = bar_width * 0.96 * health_percent
	var health_box = health_mesh.mesh as BoxMesh
	health_box.size.x = current_width
	
	var offset = (bar_width * 0.96 - current_width) / 2.0
	health_mesh.position.x = -offset
	
	var color: Color
	if health_percent > 0.66:
		var t = (health_percent - 0.66) / 0.34
		color = Color.YELLOW.lerp(Color.GREEN, t)
	elif health_percent > 0.33:
		var t = (health_percent - 0.33) / 0.33
		color = Color.ORANGE.lerp(Color.YELLOW, t)
	else:
		var bright_red = Color(1.0, 0.3, 0.3, 1.0)
		var t = health_percent / 0.33
		color = bright_red.lerp(Color.ORANGE, t)
	
	health_material.albedo_color = color

func get_health_percentage() -> float:
	return float(current_health) / float(max_health)
