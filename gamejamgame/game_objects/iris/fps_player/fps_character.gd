extends CharacterBody3D
class_name FPSPlayer

signal player_health_changed(new_val : int)

@export var camera : Camera3D
@export var hand : Node3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var speed : float = 5.0
@export var jump_speed : float = 5.0
@export var mouse_sensitivity = 0.002
@export var camera_clamp : float = 70

@export var max_health : int = 100

@export var current_carryable : Carryable

var current_health : int:
	set(value):
		current_health = value
		player_health_changed.emit(current_health)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	current_health = max_health
	add_to_group("player")

func _physics_process(delta: float) -> void:
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_down")
	var move_dir = transform.basis * Vector3(input.x, 0, input.y)
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed
	
	move_and_slide()

func set_carryable(carryable : Carryable) -> void:
	
	if carryable == null:
		remove_carryable()
		print_debug("carryable is null")
		return
	
	if hand.get_child_count() > 0:
		remove_carryable()
	
	hand.add_child(carryable)
	current_carryable = carryable
	print_debug("Set new carryable")

func remove_carryable() ->void:
	if hand.get_child_count() > 0:
		for c in hand.get_children():
			c.queue_free()

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
		
		check_for_item()

	
	if event.is_action("scroll_up"):
		print_debug("Scrolling up!")
	if event.is_action("scroll_down"):
		print_debug("Scrolling down!")

func shoot() -> void:
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(camera.global_position,
		camera.global_position - camera.global_transform.basis.z * 100)
	var collision = space.intersect_ray(query)
	if collision:
		print_debug("hit collider ", collision.collider.name, collision.position)
		if collision.collider is Enemy:
			shoot_enemy(collision.collider)
		
		if collision.collider is Carryable:
			set_carryable(collision.collider)
	else:
		print_debug("hit nothing")

func take_damage(damage : int) -> void:
	current_health -= damage
	print("Player took ", damage, " damage!")


func shoot_enemy(enemy : Enemy) -> void:
	print_debug("shooting enemy: ", enemy)
	# hard coded for now
	enemy.take_damage(10)
	pass


func check_for_item():
	
	print("checking for item")
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(camera.global_position,
		camera.global_position - camera.global_transform.basis.z * 100)
	
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 1 << 3
	
	var collision = space.intersect_ray(query)
	
	if collision and collision.collider.get_parent() is Carryable:
		# pick item up
		set_carryable(collision.collider.get_parent())
	else:
		# if no item, shoot
		print("no item")
		shoot()
