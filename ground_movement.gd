extends Node2D

## Referenz auf den Player (wird automatisch zugewiesen)
var player: CharacterBody2D
var is_active: bool = true

func setup(p_player: CharacterBody2D) -> void:
	player = p_player

func set_active(active: bool) -> void:
	is_active = active
	var walking_sprite = _get_walking_sprite()
	if walking_sprite:
		if active:
			# Schaltet über den Player ausnahmslos ALLE anderen Sprites aus!
			if player and player.has_method("show_only_sprite"):
				player.show_only_sprite(walking_sprite)
			else:
				walking_sprite.visible = true
				
			if walking_sprite.sprite_frames and walking_sprite.sprite_frames.has_animation("Walking"):
				walking_sprite.play("Walking")
			elif walking_sprite.sprite_frames and walking_sprite.sprite_frames.has_animation("default"):
				walking_sprite.play("default")
		else:
			walking_sprite.visible = false
			walking_sprite.stop()

func process_movement(delta: float) -> void:
	if not player or player.is_flying_active or player.is_on_path or player.is_driving_active:
		return

	var main_sprite = _get_walking_sprite()

	# 1. X-Bewegung / Horizontaler Input
	var input_dir = _handle_horizontal_movement(delta)

	# 2. Y-Bewegung / Sprung & Schwerkraft
	_handle_vertical_movement(delta, input_dir)

	# 3. Animation & Spiegelung
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
	elif Input.is_key_pressed(KEY_UP) or Input.is_action_just_pressed("ui_up"):
		var is_moving_right_in_fermata = player.is_fermata_active and (input_dir > 0.0 or player.velocity.x > 10.0)
		player.velocity.y = player.FERMATA_RIGHT_JUMP_VELOCITY if is_moving_right_in_fermata else player.JUMP_VELOCITY

func _is_in_any_zone() -> bool:
	if player.has_node("Area2D_Detector"):
		for area in player.get_node("Area2D_Detector").get_overlapping_areas():
			if area.has_method("_on_body_entered") or area.get_script() != null:
				if "zone_bpm" in area or "bpm" in area:
					return true
	return false

func _update_ground_animation(main_sprite: Node2D) -> void:
	if not main_sprite or not main_sprite.visible:
		return

	var is_moving: bool = abs(player.velocity.x) > 1.0

	# Spiegelung
	if is_moving and "flip_h" in main_sprite:
		main_sprite.flip_h = player.velocity.x < 0.0

	# Animation abspielen
	if main_sprite is AnimatedSprite2D:
		if is_moving:
			if main_sprite.sprite_frames and main_sprite.sprite_frames.has_animation("Walking"):
				if main_sprite.animation != "Walking" or not main_sprite.is_playing():
					main_sprite.play("Walking")
			elif main_sprite.sprite_frames and main_sprite.sprite_frames.has_animation("default"):
				if main_sprite.animation != "default" or not main_sprite.is_playing():
					main_sprite.play("default")
		else:
			if main_sprite.sprite_frames and main_sprite.sprite_frames.has_animation("idle"):
				if main_sprite.animation != "idle":
					main_sprite.play("idle")
			else:
				main_sprite.stop()

## Findet das Walking-Sprite zuverlässig
func _get_walking_sprite() -> AnimatedSprite2D:
	var sprite = get_node_or_null("Walking") as AnimatedSprite2D
	if not sprite and player:
		sprite = player.get_node_or_null("Walking") as AnimatedSprite2D
	return sprite
