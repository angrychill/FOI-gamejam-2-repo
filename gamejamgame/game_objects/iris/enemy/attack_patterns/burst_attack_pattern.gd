extends AttackPattern
class_name BurstAttackPattern

## shoots multiple projectiles in quick succession, then pauses

@export var burst_count: int = 3  ## Number of shots in a burst
@export var burst_delay: float = 0.2  ## Delay between shots in burst
@export var cooldown_after_burst: float = 2.0  ## Pause after completing burst

var current_burst_shots: int = 0
var burst_timer: float = 0.0
var is_bursting: bool = false
var cooldown_timer: float = 0.0
var in_cooldown: bool = false

func initialize(shooter: ShootingComponent) -> void:
	super.initialize(shooter)
	reset()

func update(delta: float) -> void:
	if in_cooldown:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			in_cooldown = false
			reset()
	elif is_bursting:
		burst_timer -= delta

func should_shoot() -> bool:
	if in_cooldown:
		return false
	
	if not is_bursting:
		is_bursting = true
		current_burst_shots = 0
		burst_timer = 0
		return true
	
	if burst_timer <= 0 and current_burst_shots < burst_count:
		return true
	
	return false

func on_shoot() -> void:
	current_burst_shots += 1
	burst_timer = burst_delay
	
	if current_burst_shots >= burst_count:
		is_bursting = false
		in_cooldown = true
		cooldown_timer = cooldown_after_burst

func reset() -> void:
	current_burst_shots = 0
	burst_timer = 0.0
	is_bursting = false
	in_cooldown = false
	cooldown_timer = 0.0
