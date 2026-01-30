extends Node
class_name BossAIController


@export var boss_data: DragonBossData
@export var shooting_component: ShootingComponent
@export var melee_component: MeleeAttackComponent

@export_group("AI Behavior")
@export var melee_preferred_range: float = 10.0
@export var ranged_preferred_range: float = 15.0
@export var decision_interval: float = 1.0

var decision_timer: float = 0.0
var parent_enemy: Enemy

func _ready() -> void:
	parent_enemy = get_parent() as Enemy
	if not parent_enemy:
		push_error("BossAIController must be child of Enemy!")
	
	if not shooting_component:
		shooting_component = parent_enemy.get_node_or_null("DragonShootingComponent")
	if not melee_component:
		melee_component = parent_enemy.get_node_or_null("MeleeAttackComponent")

func _process(delta: float) -> void:
	if not parent_enemy or parent_enemy.is_dead:
		return
	
	decision_timer -= delta
	if decision_timer <= 0:
		decision_timer = decision_interval
		_make_attack_decision()

func _make_attack_decision() -> void:
	var player_pos = GlobalData.get_player_position()
	var distance = parent_enemy.global_position.distance_to(player_pos)
	
	if melee_component and melee_component.is_available() and distance <= melee_preferred_range:
		melee_component.start_melee_attack()
		return
	

func is_in_melee_mode() -> bool:
	return melee_component and (melee_component.is_rushing() or melee_component.is_attacking())
