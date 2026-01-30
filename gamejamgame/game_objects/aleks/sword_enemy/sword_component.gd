extends Node
class_name SwordComponent

signal sword_telegraph
signal sword_swing
signal sword_hit

@export var sword_damage: int = 25
@export var attack_range: float = 4.5
@export var attack_arc_angle: float = 120.0
@export var telegraph_duration: float = 0.5
@export var swing_duration: float = 0.3
@export var cooldown_duration: float = 2.0
@export var slash_effect_scene: PackedScene

enum SwordState {
	READY,
	TELEGRAPHING,
	SWINGING,
	COOLDOWN
}

var current_state: SwordState = SwordState.READY
var state_timer: float = 0.0
var parent: CharacterBody3D
var has_hit_this_swing: bool = false

func _ready() -> void:
	parent = get_parent() as CharacterBody3D
	if not parent:
		push_error("SwordComponent must be child of CharacterBody3D!")

func _process(delta: float) -> void:
	match current_state:
		SwordState.READY:
			pass
		SwordState.TELEGRAPHING:
			_process_telegraphing(delta)
		SwordState.SWINGING:
			_process_swinging(delta)
		SwordState.COOLDOWN:
			_process_cooldown(delta)

func can_attack() -> bool:
	return current_state == SwordState.READY

func start_attack() -> bool:
	if current_state != SwordState.READY:
		return false
	
	_start_telegraph()
	return true

func _start_telegraph() -> void:
	current_state = SwordState.TELEGRAPHING
	state_timer = telegraph_duration
	sword_telegraph.emit()

func _process_telegraphing(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0:
		_start_swing()

func _start_swing() -> void:
	current_state = SwordState.SWINGING
	state_timer = swing_duration
	has_hit_this_swing = false
	
	if slash_effect_scene and parent:
		var slash = slash_effect_scene.instantiate()
		
		var root = parent.get_tree().root
		root.add_child(slash)
		
		slash.global_position = parent.global_position + Vector3(0, 0.8, 0)
		
		var to_player = (GlobalData.get_player_position() - parent.global_position).normalized()
		
		slash.global_position += to_player * 0.5
		
		slash.look_at(GlobalData.get_player_position())
		
	
	sword_swing.emit()
	
	_check_hit()

func _process_swinging(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0:
		_start_cooldown()

func _check_hit() -> void:
	if has_hit_this_swing:
		return
	
	var player = GlobalData.get_player()
	if not player or not parent:
		return
	
	var to_player = player.global_position - parent.global_position
	var distance = to_player.length()
	
	
	if distance > attack_range:
		return
	
	var forward = (GlobalData.get_player_position() - parent.global_position).normalized()
	var dot = forward.dot(to_player.normalized())
	
	
	if dot > 0.0:
		if player.has_method("take_damage"):
			player.take_damage(sword_damage)
			has_hit_this_swing = true
			sword_hit.emit()

func _start_cooldown() -> void:
	current_state = SwordState.COOLDOWN
	state_timer = cooldown_duration

func _process_cooldown(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0:
		current_state = SwordState.READY

func is_attacking() -> bool:
	return current_state == SwordState.SWINGING

func is_telegraphing() -> bool:
	return current_state == SwordState.TELEGRAPHING
