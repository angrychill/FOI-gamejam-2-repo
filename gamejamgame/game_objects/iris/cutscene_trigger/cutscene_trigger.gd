extends Area3D
class_name CutsceneTrigger

@export var is_active : bool = true


@export var cutscene_dialogue : DialogueResource

func _ready() -> void:
	# is_active = true
	body_entered.connect(_on_body_entered)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _on_body_entered(body : Node3D) ->void:
	if not is_active:
		# disabled bitch
		print("disabled!")
		return
	if body is not FPSPlayer:
		# do not do shit
		return
	
	# once triggered and then never again
	is_active = false
	var level : Level = get_tree().get_first_node_in_group("level")
	level.is_in_cutscene = true
	trigger_dialogue()

func trigger_dialogue() -> void:
	DialogueManager.show_dialogue_balloon(cutscene_dialogue)

func _on_dialogue_ended(res : DialogueResource) -> void:
	if res == cutscene_dialogue:
		var level : Level = get_tree().get_first_node_in_group("level")
		level.is_in_cutscene = false
	
