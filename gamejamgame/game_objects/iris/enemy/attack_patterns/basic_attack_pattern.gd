extends AttackPattern
class_name BasicAttackPattern

## shoots consistently at regular intervals

@export var shots_per_attack: int = 1

func should_shoot() -> bool:
	return true

func on_shoot() -> void:
	pass
