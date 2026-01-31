@tool
extends Node3D
class_name Carryable
@onready var label_3d: Label3D = %Label3D

var _debug_label := ""

@export var pickup_area : Area3D
@export var pickup_item : PackedScene
@export var pickup_dialogue : DialogueResource

@export var debug_label : String:
	set(value):
		_debug_label = value
		_update_label()
			
	get:
		return _debug_label

func _ready() -> void:
	_update_label()
	
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	if pickup_area:
		pickup_area.collision_layer = 8

func _on_dialogue_ended(res : DialogueResource) -> void:
	if res == pickup_dialogue:
		var level : Level = get_tree().get_first_node_in_group("level")
		level.is_in_cutscene = false

func _update_label() -> void:
	if label_3d == null:
		return
	label_3d.text = debug_label

func remove_pickup() -> void:
	for child in get_children():
		child.queue_free()

func trigger_pickup_dialogue() -> void:
	if pickup_dialogue:
		var level : Level = get_tree().get_first_node_in_group("level")
		level.is_in_cutscene = true
		DialogueManager.show_dialogue_balloon(pickup_dialogue)
