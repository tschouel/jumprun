class_name GroundMovement
extends Node

## Referenz auf den Player (wird automatisch zugewiesen)
var player: CharacterBody2D

func setup(p_player: CharacterBody2D) -> void:
	player = p_player

func process_movement(delta: float) -> void:
	if not player or player.is_flying_active or player.is_on_path:
		return

	# 1. Nur Lauf-Sprite (Walking) sichtbar schalten
	var main_sprite = player._get_main_sprite_node()
	if main_sprite:
		player.show_only_sprite(main_sprite)

	# 2. X-Bewegung / Horizontaler Input
	var input_dir = _handle_horizontal_movement(delta)

	# 3. Y-Bewegung / Sprung & Schwerkraft
	_handle_vertical_movement(delta, input_dir)

	# 4. Animation & Spiegelung
	_update_ground_animation(main_sprite)

func _handle_horizontal_movement(delta: float) -> float:
	var input_dir: float = 0.0
	
	if player.is_fermata_active:
		input_dir = Input.get_axis("ui_left", "ui_right")
		if input_dir != 0.0:
			player.velocity.x = move_toward(player.velocity.x, input_dir * player.forward_speed, player.fermata_acceleration * delta)
		else:
			player.velocity.x = move_toward(player.velocity.x, 0.0, player.fermata_friction * delta)
	else:
		player.velocity.x = player.forward_speed
		
	return input_dir

func _handle_vertical_movement(delta: float, input_dir: float) -> void:
	if _is_in_any_zone():
		return

	if not player.is_on_floor():
		player.velocity.y += player.gravity * delta
	elif Input.is_key_pressed(KEY_UP):
		var is_moving_right_in_fermata = player.is_fermata_active and (input_dir > 0.0 or player.velocity.x > 10.0)
		player.velocity.y = player.FERMATA_RIGHT_JUMP_VELOCITY if is_moving_right_in_fermata else player.JUMP_VELOCITY

func _is_in_any_zone() -> bool:
	if player.has_node("Area2D_Detector"):
		for area in player.get_node("Area2D_Detector").get_overlapping_areas():
			if area is GameZone:
				return true
	return false

func _update_ground_animation(main_sprite: Node2D) -> void:
	if not main_sprite:
		return

	var is_moving: bool = abs(player.velocity.x) > 1.0

	# Spiegelung nach links/rechts
	if is_moving and "flip_h" in main_sprite:
		main_sprite.flip_h = player.velocity.x < 0.0

	# Animationen umschalten
	if main_sprite is AnimatedSprite2D:
		if is_moving:
			if not main_sprite.is_playing() or main_sprite.animation != "Walking":
				main_sprite.play("Walking")
		else:
			if main_sprite.sprite_frames and main_sprite.sprite_frames.has_animation("idle"):
				if main_sprite.animation != "idle":
					main_sprite.play("idle")
			else:
				main_sprite.stop()
