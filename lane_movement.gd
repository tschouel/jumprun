extends Node2D

enum AnimState { OFF, WALK, TRANS, DRIVE, LANE_UP, LANE_DOWN, CRASH }
var current_anim_state: AnimState = AnimState.OFF

## Referenz auf den Player
var player: CharacterBody2D
var is_active: bool = false

@export_group("Lane Einstellungen")
@export var lane_y_positions: Array[float] = [240.0, 440.0, 640.0, 840.0]
@export var current_lane: int = 1
@export var lane_change_speed: float = 18.0

var target_y: float = 440.0

func _get_sprite() -> AnimatedSprite2D:
	return get_node_or_null("LaneSprite") as AnimatedSprite2D

func setup(p_player: CharacterBody2D) -> void:
	player = p_player

func set_active(active: bool) -> void:
	is_active = active
	if not player:
		return

	if active:
		current_anim_state = AnimState.WALK
		if current_lane >= 0 and current_lane < lane_y_positions.size():
			target_y = lane_y_positions[current_lane]
	else:
		current_anim_state = AnimState.OFF
		if player:
			player.is_lane_active = false

func start_transition() -> void:
	if not player or not is_active:
		return

	player.is_lane_active = true
	current_anim_state = AnimState.TRANS
	
	player.velocity = Vector2.ZERO
	if current_lane >= 0 and current_lane < lane_y_positions.size():
		target_y = lane_y_positions[current_lane]
		player.global_position.y = target_y

	var lane_sprite = _get_sprite()
	if lane_sprite:
		if player.has_method("show_only_sprite"):
			player.show_only_sprite(lane_sprite)
		lane_sprite.play("trans")

func trigger_crash() -> void:
	current_anim_state = AnimState.CRASH
	var lane_sprite = _get_sprite()
	if lane_sprite:
		if player and player.has_method("show_only_sprite"):
			player.show_only_sprite(lane_sprite)
		lane_sprite.play("crash")

func process_movement(delta: float) -> void:
	if not player or not is_active:
		return

	var lane_sprite = _get_sprite()

	# 1. TRANSITION (Wartet auf das Ende der trans-Animation)
	if current_anim_state == AnimState.TRANS and lane_sprite:
		player.velocity.x = 0.0
		if not lane_sprite.is_playing() or lane_sprite.frame >= lane_sprite.sprite_frames.get_frame_count("trans") - 1:
			current_anim_state = AnimState.DRIVE
			lane_sprite.play("drive")

	# 2. SCHALTEN NACH OBEN (Hals wächst, Y bleibt NOCH auf alter Spur)
	elif current_anim_state == AnimState.LANE_UP and lane_sprite:
		player.velocity.x = player.forward_speed
		player.global_position.y = lerp(player.global_position.y, target_y, lane_change_speed * delta)
		
		# Sobald 'up' durchgelaufen ist -> Zielspur ändern & wieder auf 'drive' zurück
		if not lane_sprite.is_playing() or lane_sprite.frame >= lane_sprite.sprite_frames.get_frame_count("up") - 1:
			current_lane -= 1
			target_y = lane_y_positions[current_lane]
			current_anim_state = AnimState.DRIVE
			lane_sprite.play("drive")

	# 3. SCHALTEN NACH UNTEN (Falls du auch eine 'down'-Animation hast)
	elif current_anim_state == AnimState.LANE_DOWN and lane_sprite:
		player.velocity.x = player.forward_speed
		player.global_position.y = lerp(player.global_position.y, target_y, lane_change_speed * delta)
		
		if not lane_sprite.is_playing() or lane_sprite.frame >= lane_sprite.sprite_frames.get_frame_count("down") - 1:
			current_lane += 1
			target_y = lane_y_positions[current_lane]
			current_anim_state = AnimState.DRIVE
			lane_sprite.play("drive")

	# 4. NORMALES FAHREN & INPUT-ABFRAGE
	elif current_anim_state == AnimState.DRIVE:
		player.velocity.x = player.forward_speed
		player.global_position.y = lerp(player.global_position.y, target_y, lane_change_speed * delta)
		player.velocity.y = 0.0

		# Input abfangen und Animation triggern
		if Input.is_action_just_pressed("ui_up") or Input.is_key_pressed(KEY_W):
			if current_lane > 0: # Nur wenn noch eine Spur weiter oben da ist
				if lane_sprite and lane_sprite.sprite_frames.has_animation("up"):
					current_anim_state = AnimState.LANE_UP
					lane_sprite.play("up")
				else:
					# Fallback falls 'up' Animation fehlen sollte
					_change_lane(-1)

		elif Input.is_action_just_pressed("ui_down") or Input.is_key_pressed(KEY_S):
			if current_lane < lane_y_positions.size() - 1:
				if lane_sprite and lane_sprite.sprite_frames.has_animation("down"):
					current_anim_state = AnimState.LANE_DOWN
					lane_sprite.play("down")
				else:
					_change_lane(1)

	elif current_anim_state == AnimState.CRASH:
		player.velocity = Vector2.ZERO

func _change_lane(direction: int) -> void:
	var new_lane = clamp(current_lane + direction, 0, lane_y_positions.size() - 1)
	if new_lane != current_lane:
		current_lane = new_lane
		target_y = lane_y_positions[current_lane]
