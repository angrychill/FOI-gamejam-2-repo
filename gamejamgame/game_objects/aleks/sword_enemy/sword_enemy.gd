extends Enemy
class_name SwordEnemy

@onready var sword_component: SwordComponent = $SwordComponent

@export var sword_attack_range: float = 5.0

@export var enemy_model : EnemyModel


var attack_check_timer: Timer

func _ready() -> void:
	super._ready()
	
	telegraph_light.hide()
	damage_light.hide()
	
	if sword_component:
		sword_component.sword_telegraph.connect(_on_sword_telegraph)
		sword_component.sword_swing.connect(_on_sword_swing)
		sword_component.sword_hit.connect(_on_sword_hit)
	
	attack_check_timer = Timer.new()
	add_child(attack_check_timer)
	attack_check_timer.timeout.connect(_on_attack_check)
	attack_check_timer.wait_time = 0.5
	if is_active:
		attack_check_timer.start()

func activate() -> void:
	is_active = true
	attack_check_timer.start()

func disable() -> void:
	is_active = false
	attack_check_timer.stop()

func _physics_process(_delta: float) -> void:
	enemy_debug_label.text = str(current_enemy_health)
	
	if not is_active:
		return
	
	if not is_dead:
		if sword_component and (sword_component.is_telegraphing() or sword_component.is_attacking()):
			velocity = Vector3.ZERO
		else:
			if nav_agent.is_navigation_finished():
				velocity = Vector3.ZERO
			else:
				var next_pos: Vector3 = nav_agent.get_next_path_position()
				var move_dir = (next_pos - global_position).normalized()
				velocity = move_dir * enemy_speed
	else:
		velocity = Vector3.ZERO
	
	move_and_slide()

func _on_attack_check() -> void:
	if is_dead or not sword_component:
		return
	
	var distance_to_player = global_position.distance_to(GlobalData.get_player_position())
	
	if distance_to_player <= sword_attack_range:
		sword_component.start_attack()

func _on_sword_telegraph() -> void:
	print("sword  telegraph")
	if sprite_3d:
		sprite_3d.modulate = Color.RED
	
	if enemy_model:
		enemy_model.play_attack_anim()
	
	if telegraph_light:
		telegraph_light.show()

func _on_sword_swing() -> void:
	print("sword  swing")
	if sprite_3d:
		sprite_3d.modulate = Color.YELLOW
	
	if telegraph_light:
		telegraph_light.hide()
	
	await get_tree().create_timer(sword_component.swing_duration).timeout
	if sprite_3d and not is_dead:
		sprite_3d.modulate = Color.WHITE
	if enemy_model:
		enemy_model.play_walk_anim()

func _on_sword_hit() -> void:
	if sprite_3d:
		sprite_3d.modulate = Color.WHITE
