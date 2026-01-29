extends Node
class_name ShootingComponent

@export var projectile_scene: PackedScene
@export var shoot_interval: float = 2.0
@export var shoot_offset: Vector3 = Vector3(0, 1, 0)
@export var projectile_speed: float = 15.0

var shoot_timer: float = 0.0
var can_shoot: bool = true
var parent: Node3D

func _ready() -> void:
	parent = get_parent() as Node3D
	if not parent:
		push_error("ShootingComponent must be child of Node3D!")

func _process(delta: float) -> void:
	if not can_shoot:
		shoot_timer -= delta
		if shoot_timer <= 0:
			can_shoot = true

func shoot_at_player() -> void:
	if not can_shoot or not projectile_scene:
		return
	
	var player_pos = GlobalData.get_player_position()
	var spawn_pos = parent.global_position + shoot_offset
	var direction = (player_pos - spawn_pos).normalized()
	
	# Create projectile
	var projectile = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	
	# Initialize it
	if projectile.has_method("initialize"):
		projectile.initialize(spawn_pos, direction)
	
	if "speed" in projectile:
		projectile.speed = projectile_speed
	
	# Start cooldown
	can_shoot = false
	shoot_timer = shoot_interval
	
	print_debug("Enemy shot at player!")
