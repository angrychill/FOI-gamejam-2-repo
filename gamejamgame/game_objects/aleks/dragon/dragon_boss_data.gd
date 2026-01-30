extends EnemyData
class_name DragonBossData

## Extended enemy data specifically for boss enemies

@export_group("Boss Stats")
@export var boss_name: String = "Ancient Dragon"
@export var phase_count: int = 1 
@export var phase_health_thresholds: Array[float] = [0.5]

@export_group("Movement Settings")
@export var boss_move_speed: float = 5.0
@export var boss_strafe_speed: float = 4.0
@export var boss_retreat_speed: float = 6.0

@export_group("Melee Attack")
@export var melee_damage: int = 50
@export var melee_rush_speed: float = 15.0 
@export var melee_activation_range: float = 15.0
@export var melee_launch_distance: float = 20.0
@export var melee_telegraph_time: float = 0.5
@export var melee_cooldown: float = 5.0

@export_group("Fireball Attack")
@export var fireball_damage: int = 30
@export var fireball_speed: float = 20.0
@export var fireball_size: float = 1.5
@export var shots_per_volley: int = 3
@export var volley_delay: float = 0.3
