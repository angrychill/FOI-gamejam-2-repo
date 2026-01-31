extends Control
class_name PlayerUI

@onready var health_bar: TextureProgressBar = %HealthBar

var player : FPSPlayer

func _ready() -> void:
	player = GlobalData.get_player()
	player.player_health_changed.connect(_on_player_health_changed)
	
	health_bar.max_value = player.max_health
	
	_on_player_health_changed(player.max_health)

func _on_player_health_changed(new_val : int) -> void:
	print("new val: ", new_val)
	health_bar.value = new_val
	health_bar.tint_progress.a = remap(new_val, player.max_health, 0, 1.0, 0.0)
	
