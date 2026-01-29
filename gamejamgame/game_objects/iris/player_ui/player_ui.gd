extends Control
class_name PlayerUI

@onready var health_bar: TextureProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel

var player : FPSPlayer

func _ready() -> void:
	player = GlobalData.get_player()
	player.player_health_changed.connect(_on_player_health_changed)
	
	_on_player_health_changed(player.max_health)

func _on_player_health_changed(new_val : int) -> void:
	health_bar.value = new_val
	health_label.text = str(new_val)
