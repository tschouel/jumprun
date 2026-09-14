class_name PathMovement
extends Node

var player: CharacterBody2D
var _last_global_pos: Vector2 = Vector2.ZERO

@export_group("Hindernis-Sprung (beat-synchron)")
@export var obstacle_mask_bit: int = 1
@export var jump_animation_name: String = "SlideJump"
## Steuert, wie schnell der Sprung insgesamt abläuft, OHNE die Sprunghöhe zu
## verändern: Werte < 1.0 machen den Sprung kürzer/schneller, > 1.0 länger.
@export var jump_duration_multiplier: float = 1.0

@export_group("Staubpartikel")
## GPUParticles2D-Node (Emitting im Editor AUS, One Shot AUS, Local Coords
## AUS) - wird bei Rutschbeginn auf emitting=true geschaltet, jeden Frame auf
## die aktuelle Spielerposition gesetzt, und bei Verlassen des Pfads wieder
## auf emitting=false. Analog zu StringSlide.gd. Leer lassen fuer kein
## Partikel-Feedback.
@export var dust_particles: GPUParticles2D

var _is_jumping: bool = false
var _jump_velocity_y: float = 0.0
var _jump_offset_y: float = 0.0
var _jump_gravity: float = 0.0

var _sliding_sprite_base_y: float = 0.0
var _sliding_sprite_base_y_cached: bool = false

var _stopped_by_obstacle: bool = false
var _was_on_path: bool = false

var _cached_path_follow: PathFollow2D = null
var _cached_sequencer: SlidingObstacleSequencer = null


func setup(p_player: CharacterBody2D) -> void:
	player = p_player
	if player:
		_last_global_pos = player.global_position
		player.set_meta("path_movement_module", self)


func process_movement(delta: float) -> void:
	if not player or not player.is_on_path:
		# Falls wir gerade eben noch aktiv waren, sauber Staub abschalten
		if _was_on_path:
			_set_dust_emitting(false)
			_was_on_path = false
		return

	_was_on_path = true

	var parent_path_follow := player.get_parent() as PathFollow2D

	# 0. Pfadende erreicht? -> zurück in den normalen Levelbaum, Rest überspringen
	if parent_path_follow and parent_path_follow.progress_ratio >= 1.0:
		_set_dust_emitting(false)
		_was_on_path = false
		# WICHTIG: Spieler-Zustand VOR dem eigentlichen Detach zuruecksetzen -
		# keep_upright wurde weiter unten in dieser Funktion (Schritt 6,
		# _handle_path_orientation) waehrend des Rutschens auf false
		# gesetzt, damit sich der Sprite entlang der Pfadneigung dreht.
		# Ohne dieses Zuruecksetzen wuerde der Spieler nach dem Verlassen
		# schief/liegend bleiben UND (da GroundMovement bei keep_upright
		# =false in player.gd typischerweise uebersprungen bzw. seine
		# eigene Rotation nicht mehr durchsetzen wuerde) nicht mehr sauber
		# auf die normale Boden-/Sprung-/Schwerkraft-Logik reagieren.
		player.keep_upright = true
		player.global_rotation = 0.0
		if player.has_meta("sliding_zone"):
			var zone = player.get_meta("sliding_zone")
			if zone and zone.has_method("detach_from_path"):
				zone.detach_from_path(player)
		return

	# 1. Vorwärtsbewegung entlang des Pfads
	if parent_path_follow and not _stopped_by_obstacle:
		var speed: float = _get_slide_speed(parent_path_follow)
		parent_path_follow.progress += speed * delta

	player.keep_upright = false

	# 2. Schlitten-Sprite holen, sichtbar schalten & animieren
	var sliding_sprite = player.get_node_or_null("PathMovement/Slide") as AnimatedSprite2D
	if sliding_sprite:
		if not _sliding_sprite_base_y_cached:
			_sliding_sprite_base_y = sliding_sprite.position.y
			_sliding_sprite_base_y_cached = true
		player.show_only_sprite(sliding_sprite)
		_update_sliding_animation(sliding_sprite)

	# 3. Sprung über Hindernisse verarbeiten
	_handle_obstacle_jump(delta, sliding_sprite)

	# 4. Staubpartikel: solange auf dem Pfad, an die aktuelle Spielerposition
	#    setzen (analog StringSlide.gd) - egal ob gerade gesprungen wird oder
	#    nicht, es soll wie kontinuierliches Rutschen wirken.
	_set_dust_emitting(true)
	if dust_particles:
		dust_particles.global_position = player.global_position

	# 5. Keine Physik/Gravity auf dem Pfad
	player.velocity = Vector2.ZERO

	# 6. Ausrichtung, Neigung & Spiegelung
	_handle_path_orientation(sliding_sprite)


func on_obstacle_hit() -> void:
	if _is_jumping:
		return
	_stopped_by_obstacle = true


func clear_obstacle_stop() -> void:
	_stopped_by_obstacle = false


func _set_dust_emitting(value: bool) -> void:
	if dust_particles:
		dust_particles.emitting = value


func _get_slide_speed(parent_path_follow: PathFollow2D) -> float:
	if parent_path_follow != _cached_path_follow:
		_cached_path_follow = parent_path_follow
		_cached_sequencer = null
		var path2d := parent_path_follow.get_parent() as Path2D
		if path2d:
			for child in path2d.get_children():
				if child is SlidingObstacleSequencer:
					_cached_sequencer = child
					break

	if _cached_sequencer:
		return _cached_sequencer.slide_speed
	return player.forward_speed


func _handle_obstacle_jump(delta: float, sliding_sprite: AnimatedSprite2D) -> void:
	var jump_pressed: bool = Input.is_action_just_pressed("ui_up")
	if InputMap.has_action("jump"):
		jump_pressed = jump_pressed or Input.is_action_just_pressed("jump")

	var ground_module = player.get_node_or_null("GroundMovement")

	if jump_pressed and not _is_jumping:
		_is_jumping = true

		var base_velocity: float = ground_module.jump_velocity if ground_module else player.JUMP_VELOCITY
		var base_gravity: float = ground_module.gravity if ground_module else player.gravity

		var m: float = max(jump_duration_multiplier, 0.01)
		_jump_velocity_y = base_velocity / m
		_jump_gravity = base_gravity / (m * m)

		player.set_collision_layer_value(obstacle_mask_bit, false)
		if sliding_sprite and sliding_sprite.sprite_frames and sliding_sprite.sprite_frames.has_animation(jump_animation_name):
			sliding_sprite.play(jump_animation_name)

	if _is_jumping:
		_jump_velocity_y += _jump_gravity * delta
		_jump_offset_y += _jump_velocity_y * delta

		if _jump_offset_y >= 0.0:
			_jump_offset_y = 0.0
			_jump_velocity_y = 0.0
			_is_jumping = false
			player.set_collision_layer_value(obstacle_mask_bit, true)

		if sliding_sprite:
			sliding_sprite.position.y = _sliding_sprite_base_y + _jump_offset_y
	elif sliding_sprite:
		sliding_sprite.position.y = _sliding_sprite_base_y


func _update_sliding_animation(sliding_sprite: AnimatedSprite2D) -> void:
	if _is_jumping:
		return
	if not sliding_sprite.sprite_frames:
		return
	if sliding_sprite.sprite_frames.has_animation("default"):
		if not sliding_sprite.is_playing() or sliding_sprite.animation != "default":
			sliding_sprite.play("default")


func _handle_path_orientation(sliding_sprite: AnimatedSprite2D) -> void:
	var current_pos = player.global_position

	var move_vector: Vector2
	var parent_path_follow := player.get_parent() as PathFollow2D
	if player.is_on_path and parent_path_follow:
		move_vector = Vector2.RIGHT.rotated(parent_path_follow.rotation)
	else:
		move_vector = current_pos - _last_global_pos

	if move_vector.length_squared() > 0.001:
		if not player.keep_upright:
			var angle = move_vector.angle()
			if move_vector.x < 0.0:
				angle += PI
			player.global_rotation = angle

		if sliding_sprite and "flip_h" in sliding_sprite:
			sliding_sprite.flip_h = move_vector.x < 0.0

	_last_global_pos = current_pos
	player._last_global_x = current_pos.x
