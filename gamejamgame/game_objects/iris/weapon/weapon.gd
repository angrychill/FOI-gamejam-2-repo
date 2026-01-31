@abstract
extends Node3D
class_name Weapon

@export var carry_sound_effects : Array[AudioStream]
@export var attack_sound_effects : Array[AudioStream]
@export var damage : int

@export var audio_player : AudioStreamPlayer3D


func attack() -> void:
	pass

func play_carry_sound_effect() -> void:
	audio_player.bus = &"SFX"
	if carry_sound_effects:
		var rand_sfx : AudioStream = carry_sound_effects.pick_random()
		audio_player.stream = rand_sfx
		audio_player.pitch_scale = randf_range(-0.5, 1.5)
		audio_player.play()

func play_attack_sound_effect(pitch_scale : float = -1) -> void:
	audio_player.bus = &"SFX"
	if attack_sound_effects:
		var rand_sfx : AudioStream = attack_sound_effects.pick_random()
		audio_player.stream = rand_sfx
		if pitch_scale < 0:
			audio_player.pitch_scale = randf_range(-0.5, 1.5)
		else:
			audio_player.pitch_scale = pitch_scale
		audio_player.play()
		
