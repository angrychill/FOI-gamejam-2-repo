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

@export var current_weapon : Weapon

@onready var dodge_component: DodgeComponent = $DodgeComponent

@export var can_move : bool = true

var current_health : int:
	set(value):
		current_health = value
		player_health_changed.emit(current_health)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	current_health = max_health
	add_to_group("player")
	
	current_health = max_health
	
	if not camera:
		camera = get_node_or_null("Camera3D")
		if not camera:
			camera = get_node_or_null("Head/Camera3D")
		if not camera:
			push_error("No camera found!")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if can_move:
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = jump_speed
		
		if dodge_component and dodge_component.is_currently_dodging():
			move_and_slide()
			return
		
		var input = Input.get_vector("move_left", "move_right", "move_forward", "move_down")
		var move_dir = transform.basis * Vector3(input.x, 0, input.y)
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
	
	else:
		velocity = Vector3.ZERO
	
	move_and_slide()

func set_carryable(node : Weapon) -> void:
	if node == null:
		remove_carryable()
		print_debug("carryable is null")
		return
	
	if hand == null:
		push_error("Hand node is not assigned in the inspector!")
		return
	
	if hand.get_child_count() > 0:
		remove_carryable()
	
	hand.add_child(node)
	current_weapon = node
	print_debug("Set new carryable: ", current_weapon.name)

func remove_carryable() -> void:
	if hand == null:
		return
		
	if hand.get_child_count() > 0:
		for c in hand.get_children():
			c.queue_free()

func _input(event: InputEvent) -> void:
	if not camera:
		return
	
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	
	
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if not can_move:
			return
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -deg_to_rad(camera_clamp), deg_to_rad(camera_clamp))
	
	if event.is_action_pressed("primary_click"):
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		if check_for_item():
			return
		else:
			if current_weapon != null:
				current_weapon.attack()




func take_damage(damage : int) -> void:
	current_health -= damage
	# print("Player took ", damage, " damage!")

func die() -> void:
	var level : Level = get_tree().get_first_node_in_group("level")
	if level:
		level.restart_level()


func check_for_item():

	if not camera:
		return
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(camera.global_position,
		camera.global_position - camera.global_transform.basis.z * 100)
	
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 1 << 3
	
	var collision = space.intersect_ray(query)
	
	if collision and collision.collider.get_parent() is Carryable:
		# pick item up
		var carryable : Carryable = collision.collider.get_parent()
		var item := carryable.pickup_item
		var inst := item.instantiate()
		set_carryable(inst)
		carryable.trigger_pickup_dialogue()
		carryable.remove_pickup()
		return true
	else:

		return false
