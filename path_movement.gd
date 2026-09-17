class_name PathMovement
extends Node

const NOTE_FRACTIONS: Array[float] = [1.0, 0.5, 0.25, 0.125, 0.0625]  # Ganze, Halbe, Viertel, Achtel, Sechzehntel

var player: CharacterBody2D
var _last_global_pos: Vector2 = Vector2.ZERO

@export_group("Countoff (Einzähler vor Bewegungsstart)")
## Eigenes Tempo fuer den Countoff - unabhaengig von slide_speed/den
## bpm-Werten der einzelnen SlidingObstacleStep-Eintraege. Am besten auf
## denselben Wert stellen wie den Einzaehler, den deine Musik beim Einstieg
## in diesen Pfad spielt.
@export var countoff_bpm: float = 130.0
@export_enum("Ganze", "Halbe", "Viertel", "Achtel", "Sechzehntel") var countoff_note_value: int = 2
## Anzahl Notenwerte, die nach dem Attachen auf den Pfad abgewartet werden,
## bevor die eigentliche Vorwaertsbewegung (das Sliden) losgeht - der
## Spieler haengt bis dahin schon auf dem Pfad (Sprite/Ausrichtung normal),
## bewegt sich aber noch nicht vorwaerts. 0 = kein Countoff (Standard,
## Bewegung startet wie bisher sofort beim Attach).
@export var countoff_count: int = 0

@export_group("Hindernis-Sprung (beat-synchron)")
@export var obstacle_mask_bit: int = 1
@export var jump_animation_name: String = "SlideJump"
## Steuert, wie schnell der Sprung insgesamt abläuft, OHNE die Sprunghöhe zu
## verändern: Werte < 1.0 machen den Sprung kürzer/schneller, > 1.0 länger.
@export var jump_duration_multiplier: float = 1.0

@export_group("Erfolgs-Sprung (Ramp-Test bestanden)")
## Wie viel schneller (im Vergleich zu jump_duration_multiplier) der
## kurze Jubel-Sprung ablaeuft, wenn ein Ramp-Test-Fenster erfolgreich
## bestanden wird - rein optisch, aendert nichts an der Kollision danach.
## Werte < 1.0 = schneller als der normale Sprung.
@export var success_hop_duration_multiplier: float = 0.4

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

var _countoff_elapsed: float = 0.0
var _countoff_done: bool = false

var _cached_path_follow: PathFollow2D = null
var _cached_sequencer: SlidingObstacleSequencer = null
var _cached_ramp_test: RampTestSequencer = null

# --- Optionale Respawn-Zone (Checkpoint-Fade bei Hindernis-Treffer) ---
## Wird von SlidingZone.gd beim Attach per set_respawn_zone() gesetzt, falls
## diese Zone einen respawn_point/screen_fade konfiguriert hat. Bleibt NULL
## (Standardverhalten unveraendert: nur stoppen) fuer Zonen, die das nicht
## nutzen.
var _respawn_zone: Node = null
var _obstacle_hit_in_progress: bool = false


func setup(p_player: CharacterBody2D) -> void:
	player = p_player
	if player:
		_last_global_pos = player.global_position
		player.set_meta("path_movement_module", self)


## Wird von SlidingZone.gd beim Attach aufgerufen, falls die Zone
## Checkpoint-Respawn unterstuetzt (respawn_point + optional screen_fade
## gesetzt hat). Setzt den Hindernis-Zustand frisch zurueck.
func set_respawn_zone(zone: Node) -> void:
	_respawn_zone = zone
	_obstacle_hit_in_progress = false
	_stopped_by_obstacle = false


## Wird von SlidingZone.gd beim Verlassen des Pfads aufgerufen (normal ODER
## nach einem Respawn), damit die naechste Zone wieder sauber startet.
func clear_respawn_zone() -> void:
	_respawn_zone = null
	_obstacle_hit_in_progress = false


func process_movement(delta: float) -> void:
	if not player or not player.is_on_path:
		# Falls wir gerade eben noch aktiv waren, sauber Staub abschalten
		if _was_on_path:
			_set_dust_emitting(false)
			_was_on_path = false
		return

	# Frisch attached (letzter Frame noch nicht auf dem Pfad, jetzt schon)?
	# -> Countoff fuer diesen Durchlauf zuruecksetzen, bevor _was_on_path
	# ueberschrieben wird.
	if not _was_on_path:
		_countoff_elapsed = 0.0
		_countoff_done = countoff_count <= 0

	_was_on_path = true

	# Waehrend eines Hindernis-Treffers (Fade to Black + Respawn laeuft
	# gerade in _respawn_zone.respawn_after_obstacle_hit) komplett
	# einfrieren: keine Vorwaertsbewegung, kein Sprung. is_on_path wird
	# erst NACH dem Fade-out von aussen auf false gesetzt, bis dahin muss
	# hier jeder Frame uebersprungen werden. Bleibt inaktiv (false), wenn
	# keine Respawn-Zone gesetzt ist - dann bleibt alles wie bisher.
	if _obstacle_hit_in_progress:
		player.velocity = Vector2.ZERO
		_set_dust_emitting(false)
		return

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

		# Sicherheitsnetz: falls ein RampTestSequencer auf diesem Pfad
		# existiert, aber nie erfolgreich abgeschlossen wurde (z.B. weil
		# das Testfenster falsch konfiguriert ist und hinter dem
		# tatsaechlichen Kurvenende liegt), NICHT normal durchrutschen
		# lassen - stattdessen erzwungen als Fehlschlag werten.
		var ramp_test := _get_ramp_test(parent_path_follow)
		if ramp_test and ramp_test.force_fail_if_unresolved(player):
			clear_respawn_zone()
			return

		if player.has_meta("sliding_zone"):
			var zone = player.get_meta("sliding_zone")
			if zone and zone.has_method("handle_path_end"):
				# Zone hat ein eigenes Pfadende-Verhalten (z.B. RampSlideZone
				# mit Schanzen-Launch) - Vorrang vor dem normalen Detach.
				zone.handle_path_end(player)
			elif zone and zone.has_method("detach_from_path"):
				zone.detach_from_path(player)
		clear_respawn_zone()
		return

	# Countoff: countoff_count Notenwerte bei countoff_bpm abwarten, bevor
	# die eigentliche Vorwaertsbewegung losgeht (siehe _countoff_duration()).
	# Laeuft nur hoch, wenn noch nicht fertig - danach bleibt _countoff_done
	# fuer den Rest dieses Pfad-Durchlaufs einfach true.
	if not _countoff_done:
		_countoff_elapsed += delta
		if _countoff_elapsed >= _countoff_duration():
			_countoff_done = true

	# 1. Vorwärtsbewegung entlang des Pfads (erst NACH dem Countoff)
	if _countoff_done and parent_path_follow and not _stopped_by_obstacle:
		var speed: float = _get_slide_speed(parent_path_follow)
		var ramp_test := _get_ramp_test(parent_path_follow)
		var speed_multiplier: float = 1.0
		if ramp_test:
			speed_multiplier = ramp_test.process_test(player, parent_path_follow, delta)
		parent_path_follow.progress += speed * speed_multiplier * delta

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


## Wird vom Obstacle-Trigger (SlidingObstacle.gd) aufgerufen. OHNE gesetzte
## _respawn_zone: exakt das alte Verhalten (Vorwaertsbewegung stoppt, bis
## darueber gesprungen wird). MIT gesetzter _respawn_zone (siehe
## set_respawn_zone): loest stattdessen den Checkpoint-Respawn aus (Fade to
## Black -> Teleport -> Fade zurueck), analog zu PathBassMovement.
func on_obstacle_hit() -> void:
	if _is_jumping or _obstacle_hit_in_progress:
		return

	if _respawn_zone and _respawn_zone.has_method("respawn_after_obstacle_hit"):
		_obstacle_hit_in_progress = true
		_stopped_by_obstacle = true
		player.velocity = Vector2.ZERO
		# Fire-and-forget: respawn_after_obstacle_hit ist eine async-Funktion
		# (verwendet intern "await" fuer den Fade). process_movement()
		# friert den Spieler waehrenddessen ueber _obstacle_hit_in_progress
		# ein, bis die Funktion is_on_path von aussen auf false setzt.
		_respawn_zone.respawn_after_obstacle_hit(player)
	else:
		_stopped_by_obstacle = true


func clear_obstacle_stop() -> void:
	_stopped_by_obstacle = false


## Loest einen kurzen, sichtbar SCHNELLEREN Sprung aus (rein optisch, wie
## ein kleiner Jubel-Hopser) - wird von RampTestSequencer bei erfolgreich
## bestandenem Test aufgerufen. Nutzt dieselbe Sprung-Mechanik wie
## _handle_obstacle_jump, nur mit success_hop_duration_multiplier statt
## jump_duration_multiplier.
func trigger_success_hop() -> void:
	if _is_jumping:
		return
	_is_jumping = true

	var ground_module = player.get_node_or_null("GroundMovement")
	var base_velocity: float = ground_module.jump_velocity if ground_module else player.JUMP_VELOCITY
	var base_gravity: float = ground_module.gravity if ground_module else player.gravity

	var m: float = max(success_hop_duration_multiplier, 0.01)
	_jump_velocity_y = base_velocity / m
	_jump_gravity = base_gravity / (m * m)

	player.set_collision_layer_value(obstacle_mask_bit, false)

	var sliding_sprite = player.get_node_or_null("PathMovement/Slide") as AnimatedSprite2D
	if sliding_sprite and sliding_sprite.sprite_frames and sliding_sprite.sprite_frames.has_animation(jump_animation_name):
		sliding_sprite.play(jump_animation_name)


func _set_dust_emitting(value: bool) -> void:
	if dust_particles:
		dust_particles.emitting = value


## Dauer des Countoffs in Sekunden, aus countoff_count Notenwerten à
## countoff_note_value im countoff_bpm-Tempo - gleiche Rechnung wie
## _delay_seconds() in VibratingString.gd/BowRotator.gd.
func _countoff_duration() -> float:
	if countoff_count <= 0 or countoff_bpm <= 0.0:
		return 0.0
	var fraction: float = NOTE_FRACTIONS[countoff_note_value]
	return float(countoff_count) * fraction * 4.0 * (60.0 / countoff_bpm)


func _get_slide_speed(parent_path_follow: PathFollow2D) -> float:
	if parent_path_follow != _cached_path_follow:
		_cached_path_follow = parent_path_follow
		_cached_sequencer = null
		_cached_ramp_test = null
		var path2d := parent_path_follow.get_parent() as Path2D
		if path2d:
			for child in path2d.get_children():
				if child is SlidingObstacleSequencer:
					_cached_sequencer = child
				elif child is RampTestSequencer:
					_cached_ramp_test = child

	if _cached_sequencer:
		return _cached_sequencer.slide_speed
	return player.forward_speed


func _get_ramp_test(parent_path_follow: PathFollow2D) -> RampTestSequencer:
	# Nutzt denselben Cache-Refresh wie _get_slide_speed() (beide werden
	# im selben Frame kurz hintereinander aufgerufen, daher hier nur ein
	# erneuter Zugriff auf den ggf. schon aktualisierten Cache).
	if parent_path_follow != _cached_path_follow:
		_get_slide_speed(parent_path_follow)
	return _cached_ramp_test


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
