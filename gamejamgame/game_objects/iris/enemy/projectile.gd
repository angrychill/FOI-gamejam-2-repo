extends Area3D

@export var speed: float = 15.0
@export var damage: int = 10
@export var lifetime: float = 5.0

var direction: Vector3 = Vector3.FORWARD
var shooter: Node3D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func initialize(start_position: Vector3, target_direction: Vector3, projectile_shooter: Node3D = null) -> void:
	global_position = start_position
	direction = target_direction.normalized()
	shooter = projectile_shooter

func _on_body_entered(body: Node3D) -> void:
	if body == shooter:
		return
	
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
		return
	
	if body is StaticBody3D or body is CSGShape3D:
		queue_free()
		return
	
	if body is Enemy:
		return

func _on_area_entered(area: Area3D) -> void:
	pass
