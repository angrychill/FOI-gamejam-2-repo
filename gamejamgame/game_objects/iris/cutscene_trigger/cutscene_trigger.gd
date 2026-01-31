extends Area3D
class_name CutsceneTrigger

@export var is_active : bool = true
@export var enemies_to_trigger : Array[Enemy]
@export var cutscene_dialogue : DialogueResource

@export var change_music : bool = false
@export var old_music : AudioStreamPlayer 
@export var new_music : AudioStreamPlayer
@export var fade_duration : float = 1.5 

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _on_body_entered(body : Node3D) ->void:
	if not is_active:
		print("trigger disabled!")
		return
	if body is not FPSPlayer:
		return
	
	trigger_cutscene()
	
func trigger_cutscene() -> void:
	is_active = false
	var level : Level = get_tree().get_first_node_in_group("level")
	level.is_in_cutscene = true
	
	if change_music:
		switch_music()
	
	trigger_dialogue()

func trigger_dialogue() -> void:
	DialogueManager.show_dialogue_balloon(cutscene_dialogue)

func _on_dialogue_ended(res : DialogueResource) -> void:
	if res == cutscene_dialogue:
		var level : Level = get_tree().get_first_node_in_group("level")
		level.is_in_cutscene = false
		
		trigger_enemy()

func trigger_enemy() -> void:
	if enemies_to_trigger:
		for enemy : Enemy in enemies_to_trigger:
			enemy.activate()

func switch_music() -> void:
	if not old_music or not new_music:
		print("Music players nisu postavljeni!")
		return
	
	var tween = create_tween()
	tween.tween_property(old_music, "volume_db", -80, fade_duration)
	tween.tween_callback(old_music.stop)
	
	new_music.volume_db = -80
	new_music.play()
	var tween2 = create_tween()
	tween2.tween_property(new_music, "volume_db", 0, fade_duration)
