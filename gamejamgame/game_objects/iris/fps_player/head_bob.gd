extends Node
class_name HeadBob

@export_group("Bob Settings")
@export var bob_frequency: float = 10
@export var bob_amplitude: float = 0.09
@export var bob_horizontal_amplitude: float = 0.07

@export_group("Advanced")
@export var lerp_speed: float = 10.0

var camera: Camera3D
var player: CharacterBody3D
var time_passed: float = 0.0
var target_bob_offset: Vector3 = Vector3.ZERO
var current_bob_offset: Vector3 = Vector3.ZERO
var initial_camera_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	camera = get_parent() as Camera3D
	if not camera:
		push_error("HeadBob must be child of Camera3D!")
		return
	
	initial_camera_position = camera.position
	
	player = camera.get_parent() as CharacterBody3D
	if not player:
		player = camera.get_parent().get_parent() as CharacterBody3D
	
	if not player:
		push_error("Could not find player CharacterBody3D!")

func _process(delta: float) -> void:
	if not camera or not player:
		return
	
	var velocity = player.velocity
	var horizontal_velocity = Vector2(velocity.x, velocity.z).length()
	
	if horizontal_velocity > 0.1 and player.is_on_floor():
		time_passed += delta * bob_frequency
		
		var bob_offset_y = sin(time_passed) * bob_amplitude
		var bob_offset_x = cos(time_passed * 0.5) * bob_horizontal_amplitude
		
		target_bob_offset = Vector3(bob_offset_x, bob_offset_y, 0)
	else:
		target_bob_offset = Vector3.ZERO
		time_passed = 0.0
	
	current_bob_offset = current_bob_offset.lerp(target_bob_offset, lerp_speed * delta)
	
	camera.position = initial_camera_position + current_bob_offset

func reset_bob() -> void:
	"""Reset bob to center position"""
	time_passed = 0.0
	target_bob_offset = Vector3.ZERO
	current_bob_offset = Vector3.ZERO
	if camera:
		camera.position = initial_camera_position
