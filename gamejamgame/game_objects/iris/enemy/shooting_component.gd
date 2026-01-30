extends Node
class_name ShootingComponent

@export var projectile_scene: PackedScene
@export var shoot_interval: float = 2.0
@export var shoot_offset: Vector3 = Vector3(0, 1.5, 0.5)  ## Offset from enemy to spawn projectile (higher and forward)
@export var projectile_speed: float = 15.0
@export var projectile_damage: int = 10  ## Damage dealt by projectiles

@export_group("Aiming")
@export var aim_height_offset: float = 1.0  ## Height offset to aim at (player chest height)
@export var horizontal_aim_only: bool = false  ## If true, ignores height difference (shoots straight)

@export_group("Random Variability")
@export var use_random_interval: bool = false
@export var min_shoot_interval: float = 1.0
@export var max_shoot_interval: float = 3.0

@export_group("Attack Pattern")
@export var attack_pattern: AttackPattern

var shoot_timer: float = 0.0
var can_shoot: bool = true
var parent: Node3D

func _ready() -> void:
	parent = get_parent() as Node3D
	if not parent:
		push_error("ShootingComponent must be child of Node3D!")
	
	# Initialize attack pattern if exists
	if attack_pattern:
		attack_pattern.initialize(self)

func _process(delta: float) -> void:
	if not can_shoot:
		shoot_timer -= delta
		if shoot_timer <= 0:
			can_shoot = true
	
	# Update attack pattern
	if attack_pattern:
		attack_pattern.update(delta)

func shoot_at_player() -> void:
	if not can_shoot or not projectile_scene:
		return
	
	# Use attack pattern if available
	if attack_pattern and attack_pattern.should_shoot():
		_perform_shoot()
		attack_pattern.on_shoot()
	elif not attack_pattern:
		_perform_shoot()

func _perform_shoot() -> void:
	var player_pos = GlobalData.get_player_position()
	var spawn_pos = parent.global_position + shoot_offset
	
	# Calculate target position with aiming options
	var target_pos = player_pos
	
	if horizontal_aim_only:
		# Shoot horizontally - ignore height difference
		target_pos.y = spawn_pos.y
	else:
		# Aim at player chest/center height
		target_pos += Vector3(0, aim_height_offset, 0)
	
	var direction = (target_pos - spawn_pos).normalized()
	
	# Create projectile
	var projectile = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	
	# Initialize it with shooter reference
	if projectile.has_method("initialize"):
		projectile.initialize(spawn_pos, direction, parent)  # Pass parent as shooter
	
	if "speed" in projectile:
		projectile.speed = projectile_speed
	
	# Set damage with attack pattern multiplier
	if "damage" in projectile:
		var final_damage = projectile_damage
		if attack_pattern and attack_pattern.has_method("get_damage_multiplier"):
			final_damage = int(projectile_damage * attack_pattern.get_damage_multiplier())
		projectile.damage = final_damage
	
	# Start cooldown with random interval if enabled
	can_shoot = false
	if use_random_interval:
		shoot_timer = randf_range(min_shoot_interval, max_shoot_interval)
	else:
		shoot_timer = shoot_interval
	
	#print_debug("Enemy shot at player from ", spawn_pos, " towards ", target_pos)

func get_current_interval() -> float:
	if use_random_interval:
		return randf_range(min_shoot_interval, max_shoot_interval)
	return shoot_interval
