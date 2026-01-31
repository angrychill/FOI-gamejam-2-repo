extends Node3D

func _on_dragon_trigger_area_entered(area: Area3D) -> void:
	var sword := GlobalData.get_player().current_weapon as Sword
	sword.trail_radius = 5
