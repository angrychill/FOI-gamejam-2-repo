extends Node
class_name LidarAccess

static func api(tree: SceneTree) -> LidarAPI:
	var hits := tree.get_nodes_in_group("lidar_api")
	if hits.size() > 0 and hits[0] is LidarAPI:
		return hits[0] as LidarAPI
	return null

static func manager(tree: SceneTree) -> LidarManager:
	var a := api(tree)
	return a.manager if a != null else null

static func registrar(tree: SceneTree) -> LidarRegistrar:
	var a := api(tree)
	return a.registrar if a != null else null
