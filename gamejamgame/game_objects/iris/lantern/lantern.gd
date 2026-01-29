extends Node3D
class_name Lantern

@export var shooting_rate_timer : Timer
@export var shooting_decay_timer : Timer
@export var max_shooting_rate : float = 100
@export var shooting_rate_increment : float = 0.2
@export var shooting_decay_rate : float = 0.5

var _current_shooting_rate := 0.0

var current_shooting_rate : float:
	get:
		return _current_shooting_rate
	set(value):
		_current_shooting_rate = clamp(value, 0.0, max_shooting_rate)
		update_shooting_timer()

func _ready() -> void:
	current_shooting_rate = 0.1
	shooting_decay_timer.wait_time = shooting_decay_rate
	shooting_rate_timer.timeout.connect(_on_shooting_rate_timer_timeout)
	shooting_decay_timer.timeout.connect(_on_shooting_decay_timer_timeout)

func _physics_process(delta: float) -> void:
	#print_debug("shooting rate: ", current_shooting_rate)
	pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("scroll_down"):
		print_debug("setting shooting rate")
		current_shooting_rate += shooting_rate_increment
		

func _on_shooting_decay_timer_timeout() -> void:
	current_shooting_rate -= shooting_rate_increment


func _on_shooting_rate_timer_timeout() -> void:
	# fire pulse
	print_debug("firing a pulse")

func update_shooting_timer() ->void:
	if current_shooting_rate <= 0.0:
		shooting_rate_timer.stop()
	else:
		shooting_rate_timer.wait_time = 1.0 / current_shooting_rate
		if shooting_rate_timer.is_stopped():
			shooting_rate_timer.start()
		
		
		
