extends Node

func get_player() -> FPSPlayer:
	var player : FPSPlayer = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("Couldn't find player; returning null!")
		return null
	
	else:
		return player

func get_player_position() -> Vector3:
	var player : FPSPlayer = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("Couldn't find player; returning zero!")
		return Vector3.ZERO
	
	else:
		return player.global_position
