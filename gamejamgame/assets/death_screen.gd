extends Control
@export var da_button : Button
@export var ne_button : Button


func _on_da_button_pressed() -> void:
	var level : Level = get_tree().get_first_node_in_group("level")
	if level:
		level.restart_level()
	pass
	


func _on_ne_button_pressed() -> void:
	var level : Level = get_tree().get_first_node_in_group("level")
	if level:
		# TODO: switch to intro level
		pass
	pass
