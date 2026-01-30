extends Enemy
class_name DragonBoss

@onready var melee_component: MeleeAttackComponent = $MeleeAttackComponent if has_node("MeleeAttackComponent") else null
@onready var boss_ai: BossAIController = $BossAIController if has_node("BossAIController") else null
@onready var movement_controller: BossMovementController = $BossMovementController if has_node("BossMovementController") else null
@onready var health_bar: BossHealthBar = $BossHealthBar if has_node("BossHealthBar") else null

@export var boss_data_override: DragonBossData

var is_in_melee_launch: bool = false
var use_base_enemy_movement: bool = false

func _ready() -> void:
	if has_node("ShootingComponent"):
		shooting_component = $ShootingComponent
		print("✓ Found DragonShootingComponent")
	else:
		push_warning("ShootingComponent node not found!")
	
	if boss_data_override:
		enemy_data = boss_data_override
	else:
		push_error("DragonBoss requires boss_data_override to be set!")
		return
	
	super._ready()
	
	if health_bar and boss_data_override:
		health_bar.initialize(boss_data_override.boss_name, boss_data_override.health)
		print("✓ Health bar initialized: ", boss_data_override.boss_name, " HP:", boss_data_override.health)
	
	if boss_data_override and shooting_component:
		shooting_component.projectile_damage = boss_data_override.fireball_damage
		shooting_component.projectile_speed = boss_data_override.fireball_speed
		
		if shooting_component is DragonShootingComponent:
			var dragon_shooter = shooting_component as DragonShootingComponent
			dragon_shooter.fireball_scale = boss_data_override.fireball_size
	
	if boss_data_override and melee_component:
		melee_component.melee_damage = boss_data_override.melee_damage
		melee_component.launch_speed = boss_data_override.melee_rush_speed
		melee_component.launch_distance = boss_data_override.melee_launch_distance
		melee_component.telegraph_duration = boss_data_override.melee_telegraph_time
		melee_component.cooldown_duration = boss_data_override.melee_cooldown
	
	if boss_data_override and boss_ai:
		boss_ai.melee_preferred_range = boss_data_override.melee_activation_range
	
	if boss_data_override and movement_controller:
		movement_controller.move_speed = boss_data_override.boss_move_speed
		movement_controller.strafe_speed = boss_data_override.boss_strafe_speed
		movement_controller.retreat_speed = boss_data_override.boss_retreat_speed
		use_base_enemy_movement = false
		print("✓ Movement controller initialized with speeds: move=", boss_data_override.boss_move_speed)
	else:
		use_base_enemy_movement = true
		push_warning("No movement controller - using base enemy movement")
	
	if melee_component:
		melee_component.melee_started.connect(_on_melee_started)
		melee_component.melee_telegraphing.connect(_on_melee_telegraphing)
		melee_component.melee_launching.connect(_on_melee_launching)
		melee_component.melee_attacking.connect(_on_melee_attacking)
		melee_component.melee_finished.connect(_on_melee_finished)
	
	if movement_controller:
		movement_controller.movement_changed.connect(_on_movement_changed)

func _physics_process(delta: float) -> void:
	if is_in_melee_launch:
		move_and_slide()
		return
	
	if movement_controller and not use_base_enemy_movement:
		movement_controller.apply_movement(delta)
		move_and_slide()
	else:
		super._physics_process(delta)

func _on_melee_started() -> void:
	pass

func _on_melee_telegraphing() -> void:
	is_in_melee_launch = false
	_show_attack_warning()

func _on_melee_launching() -> void:
	is_in_melee_launch = true

func _on_melee_attacking() -> void:
	pass

func _on_melee_finished() -> void:
	is_in_melee_launch = false

func _on_movement_changed(new_state) -> void:
	if movement_controller:
		print("Boss movement: ", movement_controller.get_state_name())

func _show_attack_warning() -> void:
	if sprite_3d:
		var tween = create_tween()
		tween.tween_property(sprite_3d, "modulate", Color.RED, 0.2)
		tween.tween_property(sprite_3d, "modulate", Color(1.5, 0, 0, 1), 0.2)
		tween.set_loops(3)
		tween.tween_property(sprite_3d, "modulate", Color.WHITE, 0.1)

func take_damage(damage: int) -> void:
	if not is_dead:
		var health_before = current_enemy_health
		current_enemy_health -= damage
		
		if health_bar:
			health_bar.update_health(current_enemy_health)
		
		var damage_percent = float(damage) / float(max_enemy_health)
		if damage_percent >= 0.20:
			print("💥 HEAVY DAMAGE! ", damage, " (", int(damage_percent * 100), "%)")
			
			if movement_controller:
				movement_controller.force_retreat()
			
			if sprite_3d:
				var tween = create_tween()
				tween.tween_property(sprite_3d, "modulate", Color.YELLOW, 0.1)
				tween.tween_property(sprite_3d, "modulate", Color.WHITE, 0.1)
				tween.set_loops(2)
		
		if current_enemy_health <= 0:
			die()

func die() -> void:
	super.die()

func update_volley_parameters(new_shots: int, new_delay: float) -> void:
	if shooting_component and shooting_component.attack_pattern is BurstAttackPattern:
		var burst_pattern = shooting_component.attack_pattern as BurstAttackPattern
		burst_pattern.set_burst_parameters(new_shots, new_delay)
		print("✓ Updated volley: shots=", new_shots, " delay=", new_delay)
	else:
		push_warning("Cannot update volley parameters - BurstAttackPattern not found!")
