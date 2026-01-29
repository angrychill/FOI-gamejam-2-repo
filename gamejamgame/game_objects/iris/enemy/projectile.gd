extends Area3D

@export var speed: float = 15.0
@export var damage: int = 10
@export var lifetime: float = 5.0

var direction: Vector3 = Vector3.FORWARD

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func initialize(start_position: Vector3, target_direction: Vector3) -> void:
	global_position = start_position
	direction = target_direction.normalized()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	
	elif body is StaticBody3D or body is CSGShape3D:
		queue_free()
