extends Node
class_name MeleeAttackComponent

signal melee_started
signal melee_telegraphing
signal melee_launching
signal melee_attacking
signal melee_finished

@export var melee_damage: int = 50
@export var launch_speed: float = 25.0
@export var launch_distance: float = 15.0
@export var telegraph_duration: float = 1.0
@export var cooldown_duration: float = 5.0
@export var attack_hitbox_size: Vector3 = Vector3(3, 2, 3)

enum MeleeState {
	IDLE,
	TELEGRAPHING,
	LAUNCHING,
	COOLDOWN
}

var current_state: MeleeState = MeleeState.IDLE
var state_timer: float = 0.0
var can_melee: bool = true
var parent: CharacterBody3D
var original_speed: float = 0.0
var launch_direction: Vector3 = Vector3.ZERO
var launch_traveled: float = 0.0
var has_hit_player: bool = false

func _ready() -> void:
	parent = get_parent() as CharacterBody3D
	if not parent:
		push_error("MeleeAttackComponent must be child of CharacterBody3D!")

func _process(delta: float) -> void:
	match current_state:
		MeleeState.IDLE:
			_process_idle()
		MeleeState.TELEGRAPHING:
			_process_telegraphing(delta)
		MeleeState.LAUNCHING:
			_process_launching(delta)
		MeleeState.COOLDOWN:
			_process_cooldown(delta)

func start_melee_attack() -> bool:
	if not can_melee or current_state != MeleeState.IDLE:
		return false
	
	if parent is Enemy:
		original_speed = parent.enemy_speed
	
	_start_telegraph()
	melee_started.emit()
	return true

func _process_idle() -> void:
	pass

func _start_telegraph() -> void:
	current_state = MeleeState.TELEGRAPHING
	state_timer = telegraph_duration
	
	if parent is Enemy:
		parent.enemy_speed = 0.0
	
	var player_pos = GlobalData.get_player_position()
	launch_direction = (player_pos - parent.global_position).normalized()
	
	melee_telegraphing.emit()

func _process_telegraphing(delta: float) -> void:
	state_timer -= delta
	
	if state_timer <= 0:
		_start_launch()

func _start_launch() -> void:
	current_state = MeleeState.LAUNCHING
	launch_traveled = 0.0
	has_hit_player = false
	
	melee_launching.emit()
	melee_attacking.emit()

func _process_launching(delta: float) -> void:
	if parent:
		parent.velocity = launch_direction * launch_speed
		parent.move_and_slide()
		
		launch_traveled += launch_speed * delta
		
		_check_attack_hit()
	
	if launch_traveled >= launch_distance:
		_start_cooldown()

func _check_attack_hit() -> void:
	if has_hit_player:
		return
	
	var player = GlobalData.get_player()
	if not player:
		return
	
	# Create attack hitbox
	var attack_origin = parent.global_position
	var player_pos = player.global_position
	
	var to_player = player_pos - attack_origin
	var distance = to_player.length()
	
	if distance <= attack_hitbox_size.x:
		if player.has_method("take_damage"):
			player.take_damage(melee_damage)
			has_hit_player = true

func _start_cooldown() -> void:
	current_state = MeleeState.COOLDOWN
	state_timer = cooldown_duration
	can_melee = false
	
	if parent is Enemy:
		parent.enemy_speed = original_speed
	
	melee_finished.emit()

func _process_cooldown(delta: float) -> void:
	state_timer -= delta
	
	if state_timer <= 0:
		can_melee = true
		current_state = MeleeState.IDLE

func is_available() -> bool:
	return can_melee and current_state == MeleeState.IDLE

func is_attacking() -> bool:
	return current_state == MeleeState.LAUNCHING

func is_rushing() -> bool:
	return current_state == MeleeState.LAUNCHING
