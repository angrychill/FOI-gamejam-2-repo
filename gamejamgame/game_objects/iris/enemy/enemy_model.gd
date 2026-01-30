extends Node3D
class_name EnemyModel

var skeleton_3d : Skeleton3D
var anim_player : AnimationPlayer

var player : Node3D

@export var walk_anim_name : StringName
@export var attack_anim_name : StringName

func _ready() -> void:
	for child in get_children():
		if child is Skeleton3D:
			skeleton_3d = child
		if child is AnimationPlayer:
			anim_player = child
	
	if not skeleton_3d:
		return
	if not anim_player:
		return
	
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not player:
		player = GlobalData.get_player()
	
	turn_towards_player()

func turn_towards_player() -> void:
	look_at(player.global_position, Vector3.UP, true)
	await get_tree().create_timer(0.5).timeout
	
	

func play_attack_anim() -> void:
	anim_player.play(attack_anim_name, 0.25)
	

func play_walk_anim() -> void:
	anim_player.play(walk_anim_name, 0.25)
	pass
