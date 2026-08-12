extends Node2D

## Referenz auf den Player (wird automatisch zugewiesen)
var player: CharacterBody2D
var is_active: bool = false

@export_group("Lane Einstellungen")
## Y-Positionen der 4 Zwischenräume (Lanes)
@export var lane_y_positions: Array[float] = [240.0, 440.0, 640.0, 840.0]
## Aktuelle Start-Lane (0 = ganz oben, 3 = ganz unten)
@export var current_lane: int = 1
## Geschwindigkeit des Lane-Wechsels (Smoothing)
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

	var lane_sprite = _get_sprite()

	if active:
		# 1. Schwerkraft & Startposition auf Y zurücksetzen
		player.velocity.y = 0.0
		if current_lane >= 0 and current_lane < lane_y_positions.size():
			target_y = lane_y_positions[current_lane]
			player.global_position.y = target_y

		# 2. LaneSprite aktivieren & Sequenz per Frame-Dauer starten
		if lane_sprite:
			if player.has_method("show_only_sprite"):
				player.show_only_sprite(lane_sprite)

			_play_transition_by_time(lane_sprite)

func _play_transition_by_time(lane_sprite: AnimatedSprite2D) -> void:
	lane_sprite.play("fastcartrans")
	
	# Berechne die genaue Dauer der Trans-Animation
	var frames = lane_sprite.sprite_frames
	if frames and frames.has_animation("fastcartrans"):
		var frame_count = frames.get_frame_count("fastcartrans")
		var fps = frames.get_animation_speed("fastcartrans")
		
		if fps > 0.0:
			var duration = frame_count / fps
			# Warte exakt die Sekunden ab, die die Animation lang ist
			await get_tree().create_timer(duration).timeout

	# Schalte sicher auf den Loop um
	if is_active and lane_sprite and lane_sprite.animation == "fastcartrans":
		lane_sprite.play("fastcardrive")

func process_movement(delta: float) -> void:
	if not player or not is_active:
		return

	# 1. Input abfangen (Pfeil Oben / Unten oder W / S)
	if Input.is_action_just_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		_change_lane(-1)
	elif Input.is_action_just_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		_change_lane(1)

	# 2. X-Bewegung (Konstantes Vorwärtsgleiten)
	player.velocity.x = player.forward_speed

	# 3. Y-Bewegung (Sanftes Anfahren der Ziel-Lane via Lerp)
	player.global_position.y = lerp(player.global_position.y, target_y, lane_change_speed * delta)
	player.velocity.y = 0.0

func _change_lane(direction: int) -> void:
	var new_lane = clamp(current_lane + direction, 0, lane_y_positions.size() - 1)
	if new_lane != current_lane:
		current_lane = new_lane
		target_y = lane_y_positions[current_lane]
