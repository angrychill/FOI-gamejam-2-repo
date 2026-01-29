extends CharacterBody3D
class_name Enemy
@onready var enemy_debug_label: Label3D = $EnemyDebugLabel
@onready var player_refresh_timer: Timer = $PlayerRefreshTimer


@export var enemy_data : EnemyData
@export var sprite_3d : Sprite3D
@export var nav_agent : NavigationAgent3D

var enemy_speed : float
var current_enemy_health : int
var max_enemy_health : int

func _ready() -> void:
	if not sprite_3d:
		push_error("Enemy needs a sprite3D!")
	if not enemy_data:
		push_error("Enemy must be initialized w EnemyData!")
		return
	
	sprite_3d.texture = enemy_data.sprite
	max_enemy_health = enemy_data.health
	current_enemy_health = enemy_data.health
	enemy_speed = enemy_data.move_speed
	nav_agent.target_position = GlobalData.get_player_position()
	player_refresh_timer.timeout.connect(_on_player_refresh_timeout)



func _physics_process(delta: float) -> void:
	enemy_debug_label.text = str(current_enemy_health)
	if nav_agent.is_navigation_finished():
		print_debug("Nav finished!")
		velocity = Vector3.ZERO
		nav_agent.velocity = Vector3.ZERO
		return
	
	var next_pos : Vector3 = nav_agent.get_next_path_position()
	var move_dir = (next_pos - global_position).normalized()
	print_debug("next pos: ", next_pos)
	print_debug("move dir ", move_dir)
	velocity = move_dir * enemy_speed
	nav_agent.velocity = velocity
		
	print_debug("velocity: ", velocity)
	
	move_and_slide()
		
		

func _on_player_refresh_timeout() -> void:
	nav_agent.target_position = GlobalData.get_player_position()
