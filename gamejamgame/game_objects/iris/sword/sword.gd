extends Weapon
class_name Sword

@export var particles : GPUParticles3D
@export var sword_range : int = 10

var is_attacking : bool = false

func _ready() -> void:
	particles.emitting = false

func attack() -> void:
	
	var camera = GlobalData.get_player().camera
	if not camera:
		return
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(camera.global_position,
		camera.global_position - camera.global_transform.basis.z * sword_range)
	
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var collision = space.intersect_ray(query)
	
	if collision and collision.collider is Enemy:
		var enemy : Enemy = collision.collider
		enemy.take_damage(damage)


	

func _input(event: InputEvent) -> void:
	# only if mouse mode is captured
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:

			var vel = event.screen_relative.length()
			print("vel", vel)
			if vel > 5.0:
				attack()
				particles.emitting = true
			else:
				
				particles.emitting = false
				is_attacking = false
		
		else:
			is_attacking = false
			particles.emitting = false
