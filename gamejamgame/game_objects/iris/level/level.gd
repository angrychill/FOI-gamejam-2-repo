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
			
