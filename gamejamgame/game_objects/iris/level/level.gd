extends Node3D
class_name Level

signal cutscene_started
signal cutscene_ended

@export var is_finished : bool = false
@export var next_level : PackedScene
@export var is_in_cutscene : bool = false:
	set(value):
		is_in_cutscene = value
		if is_in_cutscene == false:
			cutscene_ended.emit()
		if is_in_cutscene:
			cutscene_started.emit()
			
func _ready() -> void:
	add_to_group("level")
	cutscene_ended.connect(_on_cutscene_ended)
	cutscene_started.connect(_on_cutscene_started)
	call_deferred("_defer_next_level")

func on_level_complete():
	if next_level:
		SceneLoader.change_scene_to_resource()

func _defer_next_level():
	if next_level:
		SceneLoader.load_scene(next_level.resource_path, true)

func _on_cutscene_started() -> void:
	var player : FPSPlayer = GlobalData.get_player()
	player.can_move = false
	
	var enemies : Array = get_tree().get_nodes_in_group("enemy")
	for enemy : Enemy in enemies:
		enemy.enemy_speed = 0
		enemy.shooting_component.can_shoot = false


func _on_cutscene_ended() -> void:
	var player : FPSPlayer = GlobalData.get_player()
	player.can_move = true
	
	var enemies : Array = get_tree().get_nodes_in_group("enemy")
	for enemy : Enemy in enemies:
		enemy.enemy_speed = 1.0
		enemy.shooting_component.can_shoot = true
