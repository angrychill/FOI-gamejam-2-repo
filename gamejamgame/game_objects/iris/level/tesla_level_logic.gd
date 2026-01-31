extends Node

@export var intro_level_path: String = "res://game_objects/iris/level/intro_level.tscn"

var _completed: bool = false


func _ready() -> void:
	# Defer to ensure all Vukodlak instances are in the tree.
	call_deferred("_register_vukodlaks")


func _register_vukodlaks() -> void:
	if _completed:
		return

	var vukodlaks := get_tree().get_nodes_in_group("vukodlak")
	if vukodlaks.is_empty():
		return

	for enemy in vukodlaks:
		enemy.tree_exited.connect(_on_vukodlak_removed)


func _on_vukodlak_removed() -> void:
	if _completed or not is_inside_tree():
		return

	# Defer the check to the next idle step so the group
	# membership is fully updated, and avoid using get_tree()
	# during scene teardown.
	call_deferred("_check_all_dead")


func _check_all_dead() -> void:
	if _completed or not is_inside_tree():
		return

	var remaining := get_tree().get_nodes_in_group("vukodlak")
	if remaining.is_empty():
		_completed = true
		GlobalData.switch_to_level(intro_level_path)
