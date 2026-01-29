extends CharacterBody3D
class_name FPSPlayerAleks

signal player_health_changed(new_val : int)

@export var camera : Camera3D
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var speed : float = 5.0
@export var jump_speed : float = 5.0
@export var mouse_sensitivity = 0.002
@export var camera_clamp : float = 70
@export var max_health : int = 100

@onready var dodge_component: DodgeComponent = $DodgeComponent

var current_health : int:
	set(value):
		current_health = value
		player_health_changed.emit(current_health)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	current_health = max_health
	add_to_group("player")
	
	if not camera:
		camera = get_node_or_null("Camera3D")
		if not camera:
			camera = get_node_or_null("Head/Camera3D")
		if not camera:
			push_error("No camera found!")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_speed
	
	if dodge_component and dodge_component.is_currently_dodging():
		move_and_slide()
		return
	
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_down")
	var move_dir = transform.basis * Vector3(input.x, 0, input.y)
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed
	
	move_and_slide()

func _input(event: InputEvent) -> void:
	if not camera:
		return
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -deg_to_rad(camera_clamp), deg_to_rad(camera_clamp))
	
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	if event.is_action_pressed("primary_click"):
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		shoot()

func shoot() -> void:
	if not camera:
		return
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(camera.global_position,
		camera.global_position - camera.global_transform.basis.z * 100)
	var collision = space.intersect_ray(query)
	if collision:
		if collision.collider is Enemy:
			shoot_enemy(collision.collider)

func take_damage(damage : int) -> void:
	current_health -= damage

func shoot_enemy(enemy : Enemy) -> void:
	enemy.take_damage(10)
