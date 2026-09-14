class_name PathBassMovement
extends Node
## Eigenständiges Bewegungsmodul für den Kontrabass-Sliding-Abschnitt.
## Bewusst als SEPARATE Kopie von PathMovement.gd angelegt (keine
## Vererbung/Erweiterung), damit die bestehende, bereits funktionierende
## PathMovement.gd für die ursprüngliche SlidingZone komplett unangetastet
## bleibt.
##
## Unterschiede zu PathMovement.gd:
## - Spielt immer die "slide_bass"-Animation
## - Unterstützt Lane-Wechsel zwischen mehreren parallelen Saiten-Pfaden
##   (links/rechts, per Tween)
## - Bei Hindernis-Treffer: Fade to Black + Respawn am Checkpoint (über
##   BassSlideZone.respawn_after_obstacle_hit), statt nur zu stoppen
##
## SETUP: Als eigener Node "PathBassMovement" (Node, dieses Skript) als
## Geschwister-Node von PathMovement in player.tscn einfügen.

var player: CharacterBody2D
var _last_global_pos: Vector2 = Vector2.ZERO

@export_group("Hindernis-Sprung (beat-synchron)")
@export var obstacle_mask_bit: int = 1
@export var jump_animation_name: String = "SlideJump"
## Steuert, wie schnell der Sprung insgesamt abläuft, OHNE die Sprunghöhe zu
## verändern: Werte < 1.0 machen den Sprung kürzer/schneller, > 1.0 länger.
@export var jump_duration_multiplier: float = 1.0

@export_group("Staubpartikel")
@export var dust_particles: GPUParticles2D

@export_group("Lane-Wechsel (Kontrabass-Saiten)")
## Wie lange der seitliche "Hüpfer" beim Lane-Wechsel dauert (Tween).
@export var lane_switch_duration: float = 0.15

@export_group("Animation")
@export var slide_animation_name: String = "slide_bass"

var _is_jumping: bool = false
var _jump_velocity_y: float = 0.0
var _jump_offset_y: float = 0.0
var _jump_gravity: float = 0.0

var _sliding_sprite_base_y: float = 0.0
var _sliding_sprite_base_x: float = 0.0
var _sliding_sprite_base_cached: bool = false

@export_group("Visueller Versatz")
## Verschiebt den Slide-Sprite waehrend des Bass-Slidens leicht zur Seite,
## damit die Figur optisch die Saite haelt/umfasst, statt mittig drauf zu
## stehen. Wird NUR zur Laufzeit gesetzt und beim Verlassen wieder auf die
## urspruengliche Position zurueckgesetzt - die Slide-Node selbst bleibt
## also fuer die andere Szene (alte SlidingZone) unveraendert.
@export var sprite_x_offset: float = -5.0
## Wie stark die Figur der leichten seitlichen Neigung der Saite folgt
## (in Grad, maximale Abweichung von der Senkrechten in beide Richtungen).
## 0 = komplett starr aufrecht, hoehere Werte = deutlicheres Mitschwingen.
@export var max_tilt_degrees: float = 15.0

var _stopped_by_obstacle: bool = false
var _was_on_path: bool = false

var _cached_path_follow: PathFollow2D = null
var _cached_sequencer: SlidingObstacleSequencer = null

# --- Multi-Lane Zustand ---
var _bass_path_follows: Array[PathFollow2D] = []
var _current_lane_index: int = -1
var _can_switch_lane: bool = false
var _is_switching_lane: bool = false
var _lane_switch_zone: Node = null
var _obstacle_hit_in_progress: bool = false


func setup(p_player: CharacterBody2D) -> void:
	player = p_player
	if player:
		_last_global_pos = player.global_position
		player.set_meta("path_bass_movement_module", self)


## Wird von BassSlideZone beim Betreten (Taste F) aufgerufen.
func begin_bass_slide(path_follows: Array[PathFollow2D], start_index: int, zone: Node) -> void:
	_bass_path_follows = path_follows
	_current_lane_index = start_index
	_lane_switch_zone = zone
	_can_switch_lane = false
	_is_switching_lane = false
	_obstacle_hit_in_progress = false
	_stopped_by_obstacle = false


## Setzt den kompletten Zustand zurück - beim normalen Pfadende UND nach
## einem Checkpoint-Respawn aufgerufen.
func reset_bass_slide_state() -> void:
	_bass_path_follows = []
	_current_lane_index = -1
	_lane_switch_zone = null
	_can_switch_lane = false
	_is_switching_lane = false
	_obstacle_hit_in_progress = false
	_stopped_by_obstacle = false


## Wird von LaneSwitchToggle an Punkt B aufgerufen: Wechsel wird erlaubt.
func enable_lane_switch() -> void:
	_can_switch_lane = true


## Wird von LaneSwitchToggle an Punkt C aufgerufen: Wechsel wird gesperrt,
## Spieler bleibt auf der aktuellen Saite bis zum Pfadende.
func disable_lane_switch() -> void:
	_can_switch_lane = false


func process_movement(delta: float) -> void:
	if not player or not player.is_on_path:
		if _was_on_path:
			_set_dust_emitting(false)
			_was_on_path = false
			_reset_sprite_x_offset()
		return

	_was_on_path = true

	# Während eines Hindernis-Treffers (Fade to Black + Respawn läuft
	# gerade in BassSlideZone.respawn_after_obstacle_hit) komplett
	# einfrieren. is_on_path wird erst NACH dem Fade-out von aussen auf
	# false gesetzt, bis dahin muss hier jeder Frame übersprungen werden.
	if _obstacle_hit_in_progress:
		player.velocity = Vector2.ZERO
		_set_dust_emitting(false)
		return

	var parent_path_follow := player.get_parent() as PathFollow2D

	# 0. Pfadende erreicht? -> zurück in den normalen Levelbaum
	if parent_path_follow and parent_path_follow.progress_ratio >= 1.0:
		_set_dust_emitting(false)
		_was_on_path = false
		_reset_sprite_x_offset()
		player.keep_upright = true
		player.global_rotation = 0.0
		player.is_bass_slide_active = false
		if player.has_meta("sliding_zone"):
			var zone = player.get_meta("sliding_zone")
			if zone and zone.has_method("detach_from_path"):
				zone.detach_from_path(player)
		reset_bass_slide_state()
		return

	# 1. Vorwärtsbewegung entlang des Pfads
	if parent_path_follow and not _stopped_by_obstacle:
		var speed: float = _get_slide_speed(parent_path_follow)
		parent_path_follow.progress += speed * delta

	# WICHTIG: keep_upright bleibt TRUE (anders als bei der alten,
	# horizontalen SlidingZone) - der Spieler seilt sich an der Saite AB,
	# richtet sich also NICHT voll am Pfadwinkel aus. Er uebernimmt aber
	# die LEICHTE seitliche Neigung der Saite: die Pfad-Tangente wird mit
	# der Senkrechten (PI/2, "gerade nach unten") verglichen, die Differenz
	# ist die eigentliche Neigung - geclampt auf max_tilt_degrees, damit
	# es niemals wie ein 90-Grad-Umkippen aussieht, egal wie stark die
	# Kurve an einer Stelle abbiegt.
	player.keep_upright = true
	if parent_path_follow:
		var tangent_angle: float = parent_path_follow.rotation
		var tilt: float = wrapf(tangent_angle - (PI / 2.0), -PI, PI)
		var max_tilt_rad: float = deg_to_rad(max_tilt_degrees)
		tilt = clampf(tilt, -max_tilt_rad, max_tilt_rad)
		player.global_rotation = tilt
	else:
		player.global_rotation = 0.0

	# 2. Schlitten-Sprite holen, sichtbar schalten & animieren
	var sliding_sprite = player.get_node_or_null("PathMovement/Slide") as AnimatedSprite2D
	if sliding_sprite:
		if not _sliding_sprite_base_cached:
			_sliding_sprite_base_y = sliding_sprite.position.y
			_sliding_sprite_base_x = sliding_sprite.position.x
			_sliding_sprite_base_cached = true
		sliding_sprite.position.x = _sliding_sprite_base_x + sprite_x_offset
		player.show_only_sprite(sliding_sprite)
		_update_sliding_animation(sliding_sprite)

	# 3. Sprung über Hindernisse verarbeiten
	_handle_obstacle_jump(delta, sliding_sprite)

	# 3b. Lane-Wechsel (links/rechts zwischen den Kontrabass-Saiten)
	_handle_lane_switch()

	# 4. Staubpartikel
	_set_dust_emitting(true)
	if dust_particles:
		dust_particles.global_position = player.global_position

	# 5. Keine Physik/Gravity auf dem Pfad
	player.velocity = Vector2.ZERO

	# 6. Position merken (fuer eventuelle spaetere Nutzung) - KEINE Rotation
	# mehr, da der Spieler aufrecht bleibt (siehe keep_upright oben).
	_last_global_pos = player.global_position
	player._last_global_x = player.global_position.x


## Wird vom BassSlideObstacle.gd-Trigger aufgerufen: löst den
## Checkpoint-Respawn aus (Fade to Black -> Teleport -> Fade zurück),
## statt nur zu stoppen.
func on_obstacle_hit() -> void:
	if _is_jumping or _obstacle_hit_in_progress:
		return

	if _lane_switch_zone and _lane_switch_zone.has_method("respawn_after_obstacle_hit"):
		_obstacle_hit_in_progress = true
		_stopped_by_obstacle = true
		player.velocity = Vector2.ZERO
		# Fire-and-forget: respawn_after_obstacle_hit ist eine async-Funktion
		# (verwendet intern "await" für den Fade). process_movement() friert
		# den Spieler währenddessen über _obstacle_hit_in_progress ein.
		_lane_switch_zone.respawn_after_obstacle_hit(player)
	else:
		_stopped_by_obstacle = true


func clear_obstacle_stop() -> void:
	_stopped_by_obstacle = false


func _set_dust_emitting(value: bool) -> void:
	if dust_particles:
		dust_particles.emitting = value


## Setzt die X-Position des Slide-Sprites zurueck auf den Ausgangswert,
## den er VOR dem Bass-Sliden hatte - wichtig, da dieselbe Slide-Node
## auch in anderen Szenen/Zonen unveraendert genutzt wird.
func _reset_sprite_x_offset() -> void:
	if not _sliding_sprite_base_cached:
		return
	var sliding_sprite = player.get_node_or_null("PathMovement/Slide") as AnimatedSprite2D
	if sliding_sprite:
		sliding_sprite.position.x = _sliding_sprite_base_x


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


## Liest links/rechts-Input und stösst bei Bedarf einen Lane-Wechsel zur
## Nachbar-Saite an. Inaktiv während eines Sprungs, während bereits ein
## Wechsel-Tween läuft, oder wenn der Wechsel gerade gesperrt ist
## (zwischen Punkt C und Pfadende).
func _handle_lane_switch() -> void:
	if _bass_path_follows.is_empty():
		return
	if _is_jumping or _is_switching_lane or not _can_switch_lane:
		return

	var dir: int = 0
	if Input.is_action_just_pressed("ui_left"):
		dir = -1
	elif Input.is_action_just_pressed("ui_right"):
		dir = 1
	if dir == 0:
		return

	var target_index: int = _current_lane_index + dir
	if target_index < 0 or target_index >= _bass_path_follows.size():
		return

	_switch_to_lane(target_index)


## Reparentet den Spieler sofort auf die Ziel-Saite (an der Position, die
## der aktuellen Weltposition am nächsten liegt), belässt ihn dort aber
## zunächst optisch an seiner ALTEN Weltposition und tweent ihn dann
## sanft auf die neue Saitenmitte - erzeugt den kurzen, fliessenden
## "Hüpfer" zur Nachbarsaite statt eines harten Sprungs.
func _switch_to_lane(target_index: int) -> void:
	var old_pf := player.get_parent() as PathFollow2D
	if not old_pf:
		return

	var new_pf := _bass_path_follows[target_index]
	var new_path2d := new_pf.get_parent() as Path2D
	if not new_path2d or not new_path2d.curve:
		return

	var old_global_pos: Vector2 = player.global_position
	var local_pos: Vector2 = new_path2d.to_local(old_global_pos)
	var new_progress: float = new_path2d.curve.get_closest_offset(local_pos)

	_is_switching_lane = true
	_current_lane_index = target_index

	old_pf.remove_child(player)
	new_pf.add_child(player)
	new_pf.progress = new_progress

	player.global_position = old_global_pos
	player.reset_physics_interpolation()

	var tween := create_tween()
	tween.tween_property(player, "position", Vector2.ZERO, lane_switch_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void: _is_switching_lane = false)


func _update_sliding_animation(sliding_sprite: AnimatedSprite2D) -> void:
	if _is_jumping:
		return
	if not sliding_sprite.sprite_frames:
		return
	if sliding_sprite.sprite_frames.has_animation(slide_animation_name):
		if not sliding_sprite.is_playing() or sliding_sprite.animation != slide_animation_name:
			sliding_sprite.play(slide_animation_name)
