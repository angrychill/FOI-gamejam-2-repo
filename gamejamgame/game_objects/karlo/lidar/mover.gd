extends Node3D
class_name LeftRightMover

@export var axis := Vector3.RIGHT      # direction of movement
@export var amplitude := 2.0            # distance from center (meters)
@export var speed := 1.0                # oscillations per second
@export var phase_offset := 0.0         # optional phase shift
@export var start_offset := Vector3.ZERO

var _t := 0.0
var _origin: Vector3

func _ready() -> void:
	_origin = global_position + start_offset
	axis = axis.normalized()

func _process(delta: float) -> void:
	_t += delta * speed * TAU
	var s := sin(_t + phase_offset)
	global_position = _origin + axis * (s * amplitude)
