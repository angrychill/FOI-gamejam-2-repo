@tool
extends Node3D
class_name Carryable
@onready var label_3d: Label3D = %Label3D

var _debug_label := ""

@export var pickup_area : Area3D
@export var pickup_item : PackedScene
@export var pickup_mesh : MeshInstance3D

@export var debug_label : String:
	set(value):
		_debug_label = value
		_update_label()
			
	get:
		return _debug_label

func _ready() -> void:
	_update_label()

func _update_label() -> void:
	if label_3d == null:
		return
	label_3d.text = debug_label
