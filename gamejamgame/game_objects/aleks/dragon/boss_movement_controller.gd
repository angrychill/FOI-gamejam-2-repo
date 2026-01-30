extends Node
class_name BossMovementController

signal movement_changed(new_state: MovementState)

enum MovementState {
	APPROACHING,
	STRAFING_LEFT, 
	STRAFING_RIGHT, 
	RETREATING,    
	IDLE           
}

@export_group("Movement Settings")
@export var move_speed: float = 5.0
@export var strafe_speed: float = 4.0
@export var retreat_speed: float = 6.0

@export_group("Distance Management")
@export var preferred_min_distance: float = 8.0 
@export var preferred_max_distance: float = 18.0 
@export var optimal_distance: float = 12.0

@export_group("Behavior Timing")
@export var min_state_duration: float = 1.5
@export var max_state_duration: float = 4.0
@export var movement_change_chance: float = 0.3 

@export_group("Forced Retreat Settings")
@export var forced_retreat_duration: float = 2.0 


var current_state: MovementState = MovementState.APPROACHING
var state_timer: float = 0.0
var next_state_change: float = 0.0

var movement_direction: Vector3 = Vector3.ZERO
var parent_enemy: CharacterBody3D

var strafe_preference: float = 0.0
var unpredictability_timer: float = 0.0
const UNPREDICTABILITY_INTERVAL: float = 2.0

var is_forced_retreating: bool = false
var forced_retreat_timer: float = 0.0

func _ready() -> void:
	parent_enemy = get_parent() as CharacterBody3D
	if not parent_enemy:
		push_error("BossMovementController must be child of CharacterBody3D!")
		return
	
	_choose_new_state()

func _process(delta: float) -> void:
	if not parent_enemy:
		return
	
	if is_forced_retreating:
		forced_retreat_timer -= delta
		if forced_retreat_timer <= 0.0:
			is_forced_retreating = false
			print("✓ Forced retreat ended, resuming normal movement")
			_choose_new_state()
		return
	
	state_timer += delta
	
	if state_timer >= next_state_change:
		_choose_new_state()
	
	unpredictability_timer += delta
	if unpredictability_timer >= UNPREDICTABILITY_INTERVAL:
		unpredictability_timer = 0.0
		_update_unpredictability()

func _update_unpredictability() -> void:
	strafe_preference = randf_range(-1.0, 1.0)

func _choose_new_state() -> void:
	if is_forced_retreating:
		return
	
	var player_pos = GlobalData.get_player_position()
	var distance = parent_enemy.global_position.distance_to(player_pos)
	
	var old_state = current_state
	
	if distance < preferred_min_distance:
		if randf() < 0.7:
			current_state = MovementState.RETREATING
		else:
			current_state = MovementState.STRAFING_LEFT if randf() < 0.5 else MovementState.STRAFING_RIGHT
	
	elif distance > preferred_max_distance:
		if randf() < 0.8:
			current_state = MovementState.APPROACHING
		else:
			current_state = MovementState.STRAFING_LEFT if randf() < 0.5 else MovementState.STRAFING_RIGHT
	
	else:
		var rand_choice = randf()
		
		if rand_choice < 0.3:
			current_state = MovementState.APPROACHING
		elif rand_choice < 0.6:
			if strafe_preference < -0.3:
				current_state = MovementState.STRAFING_LEFT
			elif strafe_preference > 0.3:
				current_state = MovementState.STRAFING_RIGHT
			else:
				current_state = MovementState.STRAFING_LEFT if randf() < 0.5 else MovementState.STRAFING_RIGHT
		elif rand_choice < 0.85:
			current_state = MovementState.RETREATING
		else:
			current_state = MovementState.IDLE
	
	if old_state == current_state and randf() < movement_change_chance:
		var states = [MovementState.APPROACHING, MovementState.STRAFING_LEFT, 
					  MovementState.STRAFING_RIGHT, MovementState.RETREATING]
		states.erase(current_state)
		current_state = states[randi() % states.size()]
	
	state_timer = 0.0
	next_state_change = randf_range(min_state_duration, max_state_duration)
	
	if old_state != current_state:
		movement_changed.emit(current_state)

func force_retreat() -> void:
	is_forced_retreating = true
	forced_retreat_timer = forced_retreat_duration
	current_state = MovementState.RETREATING
	state_timer = 0.0
	
	if parent_enemy:
		var player_pos = GlobalData.get_player_position()
		var boss_pos = parent_enemy.global_position
		var away_from_player = (boss_pos - player_pos).normalized()
		away_from_player.y = 0 
		
		var boost_velocity = away_from_player * retreat_speed * 3.0
		parent_enemy.velocity.x = boost_velocity.x
		parent_enemy.velocity.z = boost_velocity.z
	
	movement_changed.emit(current_state)


func get_movement_direction() -> Vector3:
	"""Calculate the current movement direction based on state"""
	
	var player_pos = GlobalData.get_player_position()
	var boss_pos = parent_enemy.global_position
	
	var to_player = player_pos - boss_pos
	to_player.y = 0
	var to_player_normalized = to_player.normalized()
	
	var perpendicular = Vector3(-to_player_normalized.z, 0, to_player_normalized.x)
	
	match current_state:
		MovementState.APPROACHING:
			movement_direction = to_player_normalized
		
		MovementState.RETREATING:
			movement_direction = -to_player_normalized
		
		MovementState.STRAFING_LEFT:
			movement_direction = (to_player_normalized * 0.3 + perpendicular).normalized()
		
		MovementState.STRAFING_RIGHT:
			movement_direction = (to_player_normalized * 0.3 - perpendicular).normalized()
		
		MovementState.IDLE:
			movement_direction = Vector3.ZERO
	
	var wobble = Vector3(
		randf_range(-0.2, 0.2),
		0,
		randf_range(-0.2, 0.2)
	)
	movement_direction = (movement_direction + wobble).normalized()
	
	return movement_direction

func get_movement_speed() -> float:
	"""Return the appropriate speed for current state"""
	if is_forced_retreating:
		return retreat_speed * 2.5
	
	match current_state:
		MovementState.APPROACHING:
			return move_speed
		MovementState.RETREATING:
			return retreat_speed
		MovementState.STRAFING_LEFT, MovementState.STRAFING_RIGHT:
			return strafe_speed
		MovementState.IDLE:
			return 0.0
		_:
			return move_speed

func apply_movement(delta: float) -> void:
	"""Apply calculated movement to parent enemy"""
	if not parent_enemy:
		return
	
	var direction = get_movement_direction()
	var speed = get_movement_speed()
	
	if parent_enemy is CharacterBody3D:
		var velocity = direction * speed
		velocity.y = parent_enemy.velocity.y
		parent_enemy.velocity.x = velocity.x
		parent_enemy.velocity.z = velocity.z

func is_moving() -> bool:
	return current_state != MovementState.IDLE

func get_state_name() -> String:
	var state_str = ""
	match current_state:
		MovementState.APPROACHING: state_str = "Approaching"
		MovementState.RETREATING: state_str = "Retreating"
		MovementState.STRAFING_LEFT: state_str = "Strafing Left"
		MovementState.STRAFING_RIGHT: state_str = "Strafing Right"
		MovementState.IDLE: state_str = "Idle"
		_: state_str = "Unknown"
	
	if is_forced_retreating:
		state_str += " (FORCED)"
	
	return state_str
