extends Weapon
class_name Lantern
@onready var lantern_debug_label: Label = $LanternDebugLabel
@onready var trail: LidarTrailEmitter = $LanternArea/LidarEmitterCollision

@export var lantern_area : Area3D

@export var shooting_decay_timer : Timer
@export var max_shooting_rate : float = 10
@export var shooting_rate_increment : float = 0.1
@export var shooting_decay_rate : float = 0.25

var _current_shooting_rate := 0.0

var current_shooting_rate : float: # = strength
	get:
		return _current_shooting_rate
	set(value):
		_current_shooting_rate = clamp(value, 0.0, max_shooting_rate)

var fire_accumulator : float = 0.0

func _ready() -> void:

	trail.set_mode_manual()
	current_shooting_rate = 0.0
	shooting_decay_timer.wait_time = shooting_decay_rate

	shooting_decay_timer.timeout.connect(_on_shooting_decay_timer_timeout)

func _physics_process(delta: float) -> void:
	
	lantern_debug_label.text = str(current_shooting_rate)
	
	if current_shooting_rate <= 0.0:
		fire_accumulator = 0.0
		return
	
	fire_accumulator += delta * current_shooting_rate
	
	while fire_accumulator >= 1.0:
		fire_accumulator -= 1.0
		fire_pulse()
	

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("scroll_down"):
		play_carry_sound_effect()
		current_shooting_rate += shooting_rate_increment
		

func _on_shooting_decay_timer_timeout() -> void:
	current_shooting_rate -= shooting_rate_increment


func fire_pulse() -> void:

	# Example mapping:
	# radius uses fire_accumulator, hz uses current_shooting_rate (clamped inside emitter)
	trail.emit_now(
		trail.shape.radius - trail.shape.radius/2 + current_shooting_rate
	)
	

	play_attack_sound_effect(remap(current_shooting_rate, max_shooting_rate, 0, 1.5, 0.5))

	var overlaps := lantern_area.get_overlapping_bodies()
	for node: Node3D in overlaps:
		if node is Enemy:
			node.take_damage(damage)

func attack() -> void:
	fire_pulse()
