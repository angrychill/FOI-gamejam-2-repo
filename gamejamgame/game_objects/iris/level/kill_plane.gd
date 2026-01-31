extends Area3D
class_name KillPlane

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body : Node3D) -> void:
	if body is FPSPlayer:
		GlobalData.get_player().die()
		
		# restart
		#print_debug("restart")
		#var level : Level = get_tree().get_first_node_in_group("level")
		#if level:
			#level.restart_level()
