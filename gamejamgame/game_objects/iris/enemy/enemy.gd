extends CharacterBody3D
class_name Enemy
@onready var enemy_debug_label: Label3D = $EnemyDebugLabel
@onready var player_refresh_timer: Timer = $PlayerRefreshTimer

@onready var shooting_component: ShootingComponent = $ShootingComponent

@export var enemy_data : EnemyData
@export var sprite_3d : Sprite3D
@export var nav_agent : NavigationAgent3D


@export var telegraph_light : Node3D
@export var damage_light : Node3D
@export var damage_light_duration : float = 0.1

@export var is_active : bool = false

var enemy_speed : float
var current_enemy_health : int
var max_enemy_health : int
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var is_dead : bool = false

var shoot_timer: Timer

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
	
	if not shoot_timer:
		shoot_timer = Timer.new()
		add_child(shoot_timer)
		shoot_timer.timeout.connect(_on_shoot_timer_timeout)
		
		if shooting_component:
			shoot_timer.wait_time = shooting_component.get_current_interval()
		else:
			shoot_timer.wait_time = 2.0
		
		# shoot_timer.start()


func activate() -> void:
	is_active = true
	shoot_timer.start()

func disable() -> void:
	is_active = false
	shoot_timer.stop()

func _physics_process(delta: float) -> void:
	enemy_debug_label.text = str(current_enemy_health)

	
	if not is_on_floor():
		velocity.y -= gravity * delta
	if is_active:
		if not is_dead:
			if nav_agent.is_navigation_finished():
				print_debug("Nav finished!")
				velocity = Vector3.ZERO
				nav_agent.velocity = Vector3.ZERO
				return
			
			var next_pos : Vector3 = nav_agent.get_next_path_position()
			var move_dir = (next_pos - global_position).normalized()

			velocity = move_dir * enemy_speed
			nav_agent.velocity = velocity
			
		else:
			velocity = Vector3.ZERO
		
	move_and_slide()
		
		

func _on_player_refresh_timeout() -> void:
	nav_agent.target_position = GlobalData.get_player_position()

func take_damage(damage : int) ->void:
	if is_active:
		if not is_dead:
			current_enemy_health -= damage
			damage_light.show()
			if current_enemy_health <= 0:
				die()
			
			await get_tree().create_timer(damage_light_duration).timeout
			damage_light.hide()

func die() -> void:
	is_dead = true
	
	# dodaj kasnije
	queue_free()
	
	

func _on_shoot_timer_timeout() -> void:
	if not is_dead and shooting_component:
		shooting_component.shoot_at_player()
		
		if shooting_component:
			shoot_timer.wait_time = shooting_component.get_current_interval()
