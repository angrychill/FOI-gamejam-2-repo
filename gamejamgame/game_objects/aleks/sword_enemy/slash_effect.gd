extends Node3D
class_name SwordSlashEffect

@export var slash_texture: Texture2D
@export var effect_duration: float = 0.3
@export var effect_size: Vector2 = Vector2(1.5, 1.5)

var sprite_3d: Sprite3D

func _ready() -> void:
	sprite_3d = Sprite3D.new()
	add_child(sprite_3d)
	
	if slash_texture:
		sprite_3d.texture = slash_texture
	
	sprite_3d.pixel_size = 0.01
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = slash_texture
	sprite_3d.material_override = mat
	
	sprite_3d.scale = Vector3(effect_size.x, effect_size.y, 1)
		
	var tween = create_tween()
	tween.tween_property(sprite_3d, "modulate:a", 0.0, effect_duration)
	tween.tween_callback(queue_free)

func _process(delta: float) -> void:
	rotate(Vector3.FORWARD, delta * 15.0)
