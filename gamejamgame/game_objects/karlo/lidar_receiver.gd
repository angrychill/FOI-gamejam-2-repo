extends MeshInstance3D

@export var lidar_manager_path: NodePath 

func _ready() -> void:
	var mgr := get_node_or_null(lidar_manager_path)
	if mgr is LidarManager:
		mgr.register_receiver(self)

func _exit_tree() -> void:
	var mgr := get_node_or_null(lidar_manager_path)
	if mgr is LidarManager:
		mgr.unregister_receiver(self)
