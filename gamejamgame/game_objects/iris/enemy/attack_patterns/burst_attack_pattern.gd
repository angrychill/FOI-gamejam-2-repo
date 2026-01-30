extends AttackPattern
class_name BurstAttackPattern

@export var default_burst_count: int = 3
@export var default_burst_delay: float = 0.2 
@export var default_cooldown_after_burst: float = 2.0

var burst_count: int = 3
var burst_delay: float = 0.2
var cooldown_after_burst: float = 2.0

var current_burst_shots: int = 0
var burst_timer: float = 0.0
var is_bursting: bool = false
var cooldown_timer: float = 0.0
var in_cooldown: bool = false

func initialize(shooter: ShootingComponent) -> void:
	super.initialize(shooter)
	burst_count = default_burst_count
	burst_delay = default_burst_delay
	cooldown_after_burst = default_cooldown_after_burst
	reset()

func set_burst_parameters(new_burst_count: int, new_burst_delay: float, new_cooldown: float = -1) -> void:
	burst_count = new_burst_count
	burst_delay = new_burst_delay
	if new_cooldown >= 0:
		cooldown_after_burst = new_cooldown
	
	if is_bursting and burst_timer > new_burst_delay:
		burst_timer = new_burst_delay

func update(delta: float) -> void:
	if in_cooldown:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			in_cooldown = false
			reset()
	elif is_bursting:
		burst_timer -= delta
		
		if shooter_component:
			shooter_component.can_shoot = true
			shooter_component.shoot_timer = 0.0

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
	
	if shooter_component:
		shooter_component.can_shoot = true
		shooter_component.shoot_timer = 0.0
	
	if current_burst_shots >= burst_count:
		is_bursting = false
		in_cooldown = true
		cooldown_timer = cooldown_after_burst
		
		if shooter_component:
			shooter_component.can_shoot = false
			shooter_component.shoot_timer = cooldown_after_burst

func reset() -> void:
	current_burst_shots = 0
	burst_timer = 0.0
	is_bursting = false
	in_cooldown = false
	cooldown_timer = 0.0
