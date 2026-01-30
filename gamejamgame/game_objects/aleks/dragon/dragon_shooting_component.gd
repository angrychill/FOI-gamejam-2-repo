extends ShootingComponent
class_name DragonShootingComponent

var fireball_scale: float = 1.0

@export var prediction_chance: float = 0.33
@export var prediction_time: float = 0.5

var last_player_pos: Vector3 = Vector3.ZERO
var player_velocity: Vector3 = Vector3.ZERO
var velocity_update_timer: float = 0.0
const VELOCITY_UPDATE_INTERVAL: float = 0.1

func _process(delta: float) -> void:
	super._process(delta)
	
	velocity_update_timer += delta
	if velocity_update_timer >= VELOCITY_UPDATE_INTERVAL:
		_update_player_velocity()
		velocity_update_timer = 0.0

func _update_player_velocity() -> void:
	var current_player_pos = GlobalData.get_player_position()
	
	if last_player_pos != Vector3.ZERO:
		player_velocity = (current_player_pos - last_player_pos) / VELOCITY_UPDATE_INTERVAL
	
	last_player_pos = current_player_pos

func _perform_shoot() -> void:
	var player_pos = GlobalData.get_player_position()
	var spawn_pos = parent.global_position + shoot_offset
	
	var should_predict = randf() < prediction_chance
	
	var target_pos = player_pos
	
	if should_predict and player_velocity.length() > 0.1:
		var predicted_offset = player_velocity * prediction_time
		target_pos += predicted_offset
		
		var prediction_variance = Vector3(
			randf_range(-0.5, 0.5),
			0, 
			randf_range(-0.5, 0.5)
		)
		target_pos += prediction_variance
	
	if horizontal_aim_only:
		target_pos.y = spawn_pos.y
	else:
		target_pos += Vector3(0, aim_height_offset, 0)
	
	var direction = (target_pos - spawn_pos).normalized()
	
	var projectile = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	
	if projectile.has_method("initialize"):
		projectile.initialize(spawn_pos, direction, parent, fireball_scale)
	
	if "speed" in projectile:
		projectile.speed = projectile_speed
	
	if "damage" in projectile:
		var final_damage = projectile_damage
		if attack_pattern and attack_pattern.has_method("get_damage_multiplier"):
			final_damage = int(projectile_damage * attack_pattern.get_damage_multiplier())
		projectile.damage = final_damage
	
	can_shoot = false
	if use_random_interval:
		shoot_timer = randf_range(min_shoot_interval, max_shoot_interval)
	else:
		shoot_timer = shoot_interval
