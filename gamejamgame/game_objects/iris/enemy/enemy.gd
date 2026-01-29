extends CharacterBody3D
class_name Enemy
@onready var enemy_debug_label: Label = $EnemyDebugLabel

@export var enemy_data : EnemyData
@export var sprite_3d : Sprite3D

var enemy_speed : float
var current_enemy_health : int
var max_enemy_health : int

func _ready() -> void:
	if not sprite_3d:
		push_error("Enemy needs a sprite3D!")
	if not enemy_data:
		push_error("Enemy must be initialized w EnemyData!")
		return
	
	sprite_3d.texture = enemy_data.sprite
	max_enemy_health = enemy_data.health
	current_enemy_health = enemy_data.health
	enemy_speed = enemy_data.move_speed
	
