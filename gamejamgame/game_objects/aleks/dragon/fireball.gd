extends Area3D
class_name Fireball

## Powerful fireball projectile for dragon boss
## Extends base projectile with visual effects and area damage

@export var speed: float = 20.0
@export var damage: int = 30
@export var lifetime: float = 8.0
@export var explosion_radius: float = 2.0
@export var has_trail: bool = true

var direction: Vector3 = Vector3.FORWARD
var shooter: Node3D = null
var fireball_scale: float = 1.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Scale the fireball visual
	if mesh_instance:
		mesh_instance.scale = Vector3.ONE * fireball_scale
	
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func initialize(start_position: Vector3, target_direction: Vector3, projectile_shooter: Node3D = null, scale: float = 1.0) -> void:
	global_position = start_position
	direction = target_direction.normalized()
	shooter = projectile_shooter
	fireball_scale = scale

func _on_body_entered(body: Node3D) -> void:
	# Create explosion effect on impact
	_create_explosion_effect()
	
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

func _create_explosion_effect() -> void:
	# TODO:
	print_debug("Fireball exploded at: ", global_position)
