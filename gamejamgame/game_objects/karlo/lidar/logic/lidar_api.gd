extends Node
class_name LidarAPI

@export var manager: LidarManager 
@export var registrar: LidarRegistrar 

func _ready() -> void:
	manager.add_to_group("lidar_manager")
	registrar.add_to_group("lidar_registrar")
