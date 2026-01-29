extends CharacterBody3D
class_name FPSPlayer

@export var camera : Camera3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var speed : float = 5.0
@export var jump_speed : float = 5.0
@export var mouse_sensitivity = 0.002
@export var camera_clamp : float = 70

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	velocity.y += -gravity * delta
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_down")
	var move_dir = transform.basis * Vector3(input.x, 0, input.y)
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed
	
	move_and_slide()

func _input(event: InputEvent) -> void:
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
	
	if event.is_action("scroll_up"):
		print_debug("Scrolling up!")
	if event.is_action("scroll_down"):
		print_debug("Scrolling down!")

func shoot() -> void:
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(camera.global_position,
		camera.global_position - $Camera3D.global_transform.basis.z * 100)
	var collision = space.intersect_ray(query)
	if collision:
		print_debug("hit collider ", collision.collider.name, collision.position)
	else:
		print_debug("hit nothing")
	
