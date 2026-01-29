extends Node3D
class_name Carryable
@onready var label_3d: Label3D = %Label3D

@export var pickup_area : Area3D
@export var pickup_item : PackedScene
@export var pickup_mesh : MeshInstance3D

func _ready() -> void:
	pickup_area.mouse_entered.connect(_on_mouse_entered)
	pickup_area.mouse_exited.connect(_on_mouse_exited)
	label_3d.hide()

func _on_mouse_entered() -> void:
	print("showing")
	label_3d.show()

func _on_mouse_exited() -> void:
	print("hiding")
	label_3d.hide()
