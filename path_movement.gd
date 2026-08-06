class_name PathMovement
extends Node

## Referenz auf den Player (wird automatisch zugewiesen)
var player: CharacterBody2D

func setup(p_player: CharacterBody2D) -> void:
	player = p_player

func process_movement(_delta: float) -> void:
	if not player or not player.is_on_path:
		return

	# 1. Schlitten-Sprite holen, sichtbar schalten & animieren
	var sliding_sprite = player.get_node_or_null("Sliding") as AnimatedSprite2D
	if sliding_sprite:
		player.show_only_sprite(sliding_sprite)
		_update_sliding_animation(sliding_sprite)

	# 2. Keine Physik/Gravity auf dem Pfad
	player.velocity = Vector2.ZERO

	# 3. Ausrichtung & Spiegelung (flip_h)
	_handle_path_orientation(sliding_sprite)

func _update_sliding_animation(sliding_sprite: AnimatedSprite2D) -> void:
	if not sliding_sprite.sprite_frames:
		return

	var anim_names = sliding_sprite.sprite_frames.get_animation_names()
	if anim_names.is_empty():
		return

	var anim_to_play = "Sliding" if sliding_sprite.sprite_frames.has_animation("Sliding") else anim_names[0]
	if not sliding_sprite.is_playing() or sliding_sprite.animation != anim_to_play:
		sliding_sprite.play(anim_to_play)

func _handle_path_orientation(sliding_sprite: AnimatedSprite2D) -> void:
	if player.keep_upright:
		player.global_rotation = 0.0

	var current_global_x = player.global_position.x
	var delta_x = current_global_x - player._last_global_x
	
	if abs(delta_x) > 0.01 and sliding_sprite and "flip_h" in sliding_sprite:
		sliding_sprite.flip_h = delta_x < 0.0

	player._last_global_x = current_global_x
