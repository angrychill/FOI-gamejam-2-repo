extends Resource
class_name AttackPattern

var shooter_component: ShootingComponent

func initialize(shooter: ShootingComponent) -> void:
	shooter_component = shooter

func update(_delta: float) -> void:
	pass

func should_shoot() -> bool:
	return true

func on_shoot() -> void:
	pass

func get_damage_multiplier() -> float:
	return 1.0
