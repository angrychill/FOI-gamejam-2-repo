extends Node
class_name DodgeComponent

@export var dodge_distance: float = 3.0
@export var dodge_duration: float = 0.2
@export var dodge_cooldown: float = 1.0
@export var dodge_button: String = "dodge"

var can_dodge: bool = true
var is_dodging: bool = false
var dodge_timer: float = 0.0
var cooldown_timer: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO
var dodge_speed: float = 0.0
var parent: CharacterBody3D

func _ready() -> void:
	parent = get_parent() as CharacterBody3D
	if not parent:
		push_error("DodgeComponent must be child of CharacterBody3D!")
		return
	dodge_speed = dodge_distance / dodge_duration

func _process(delta: float) -> void:
	if not can_dodge:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			can_dodge = true
	
	if is_dodging:
		dodge_timer -= delta
		if dodge_timer <= 0:
			is_dodging = false

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed(dodge_button) and can_dodge and not is_dodging:
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_down")
		if input_dir.length() > 0.1:
			start_dodge(input_dir)
	
	if is_dodging:
		apply_dodge_movement()

func start_dodge(input_direction: Vector2) -> void:
	var camera = parent.get_node_or_null("Camera3D")
	if not camera:
		camera = parent.get_node_or_null("Head/Camera3D")
	
	if camera:
		var cam_basis = camera.global_transform.basis
		var forward = -Vector3(cam_basis.z.x, 0, cam_basis.z.z).normalized()
		var right = Vector3(cam_basis.x.x, 0, cam_basis.x.z).normalized()
		dodge_direction = (forward * -input_direction.y + right * input_direction.x).normalized()
	else:
		dodge_direction = Vector3(input_direction.x, 0, input_direction.y).normalized()
	
	is_dodging = true
	can_dodge = false
	dodge_timer = dodge_duration
	cooldown_timer = dodge_cooldown

func apply_dodge_movement() -> void:
	if parent:
		parent.velocity.x = dodge_direction.x * dodge_speed
		parent.velocity.z = dodge_direction.z * dodge_speed

func is_currently_dodging() -> bool:
	return is_dodging
