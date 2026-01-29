extends Resource
class_name AttackPattern

var shooting_component: ShootingComponent

func initialize(shooter: ShootingComponent) -> void:
	shooting_component = shooter

func update(delta: float) -> void:
	pass

func should_shoot() -> bool:
	return true

func on_shoot() -> void:
	pass

func reset() -> void:
	pass

func get_damage_multiplier() -> float:
	return 1.0
