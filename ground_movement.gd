class_name GroundMovement
extends Node2D

@export_group("Geschwindigkeit & Beschleunigung")
## Maximale Laufgeschwindigkeit
@export var speed: float = 350.0
## Beschleunigung beim Anlaufen
@export var acceleration: float = 3000.0
## Hohe Reibung beim Bremsen (verhindert Schlittschuhlaufen)
@export var friction: float = 4500.0

@export_group("Sprung & Schwerkraft")
@export var jump_velocity: float = -550.0
@export var gravity: float = 1400.0
## Wie viel von der Lift-Geschwindigkeit zusaetzlich in den Sprung einfliesst,
## GEDECKELT auf diesen Betrag (px/s). 0 = wie "Platform on Leave: Do Nothing"
## (kein Boost). Ein hoher Wert (z.B. 9999) waere effektiv wie "Add Velocity"
## (ungedeckelt). Sinnvoll ist meist ein Wert deutlich unter der maximalen
## Lift-Geschwindigkeit, damit sich der Sprung staerker/schwaecher anfuehlt,
## je nachdem wie schnell der Lift gerade faehrt, aber nie explodiert.
@export var max_platform_jump_boost: float = 250.0

@export_group("Kamera / Look Down")
## Um wie viel px die Kamera nach unten faehrt, waehrend "runter" gehalten wird
@export var camera_look_down_offset: float = 400.0
## Geschwindigkeit der Kamera-Bewegung in px/s (smooth, nicht sofort)
@export var camera_look_speed: float = 900.0

@export_group("Referenzen")
@export var sprite: AnimatedSprite2D

## NONE = normaler Zustand (stand/walking/jump)
## TRANSITIONING_IN = "lookdown" spielt vorwaerts (Uebergang ins Bücken)
## HOLDING = "lookdownLoop" laeuft (Pose gehalten, loopt von selbst)
## TRANSITIONING_OUT = "lookdown" spielt rueckwaerts (Uebergang zurueck)
enum LookdownPhase { NONE, TRANSITIONING_IN, HOLDING, TRANSITIONING_OUT }

var is_active: bool = false
var _player: CharacterBody2D = null
var _camera: Camera2D = null
var _looking_down: bool = false
var _lookdown_phase: int = LookdownPhase.NONE

func setup(player: CharacterBody2D) -> void:
	_player = player
	if not sprite:
		# "Walk" ist ein direktes Kind von GroundMovement selbst
		sprite = get_node_or_null("Walk") as AnimatedSprite2D
	if not sprite and _player:
		sprite = _player.find_child("*Sprite*", true, false) as AnimatedSprite2D
	if not _camera and _player:
		_camera = _player.get_node_or_null("Camera2D") as Camera2D
	if sprite and not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)

func set_active(active: bool) -> void:
	is_active = active
	if not is_active:
		_lookdown_phase = LookdownPhase.NONE
		_play_stand_animation()

## Wird vom player.gd im Haupt-_physics_process aufgerufen
func process_movement(delta: float) -> void:
	if not _player:
		return

	# 1. Schwerkraft
	# WICHTIG (Fix): Ohne das "else" bleibt velocity.y nach der Landung auf dem
	# Wert vom letzten Fall "eingefroren", statt auf 0 zu gehen. Auf einem
	# statischen Boden fällt das nicht auf (move_and_slide blockt die Kollision
	# einfach), aber auf einer sich bewegenden Plattform (z.B. dem Acclift)
	# kämpft diese alte Rest-Fallgeschwindigkeit jeden Physik-Tick gegen die
	# Kollisions-Verdrängung der Plattform - das erzeugt genau das
	# geschwindigkeitsabhängige Zittern/"Aneinanderschlagen".
	if not _player.is_on_floor():
		_player.velocity.y += gravity * delta
	else:
		_player.velocity.y = 0.0

	# 2. Sprung
	# "jump" wird nur abgefragt, wenn diese Action im Input Map überhaupt existiert
	# (verhindert die "InputMap action doesn't exist"-Fehlerflut)
	var jump_pressed: bool = Input.is_action_just_pressed("ui_up")
	if InputMap.has_action("jump"):
		jump_pressed = jump_pressed or Input.is_action_just_pressed("jump")
	if jump_pressed and _player.is_on_floor():
		# Plattform-Geschwindigkeit (z.B. vom Acclift) zum Sprung dazuaddieren,
		# aber gedeckelt - so bleibt es "Sprung + etwas Lift-Schwung" statt bei
		# einer schnellen Lift-Phase unkontrollierbar hoch zu katapultieren.
		# Voraussetzung: "Platform on Leave" am CharacterBody2D steht auf
		# "Do Nothing", sonst addiert Godot zusaetzlich noch seine eigene,
		# ungedeckelte Portion oben drauf.
		var platform_vy: float = _player.get_platform_velocity().y
		var platform_boost: float = 0.0
		if platform_vy < 0.0:
			# Nur der nach oben gerichtete Anteil zaehlt (negatives y = nach oben),
			# und wird auf max_platform_jump_boost begrenzt.
			platform_boost = max(platform_vy, -max_platform_jump_boost)
		_player.velocity.y = jump_velocity + platform_boost

	# 3. Vertikaler "Runter"-Input (Look-Down) - blockiert horizontale Bewegung,
	# solange gehalten und am Boden. In der Luft hat es keinen Effekt.
	var down_pressed: bool = Input.is_action_pressed("ui_down")
	if not down_pressed:
		down_pressed = Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	_looking_down = down_pressed and _player.is_on_floor()

	# 4. Horizontaler Input
	# Waehrend Look-Down wird kein neuer Input angenommen - der Player bremst
	# stattdessen ganz normal per Reibung bis zum Stillstand ab.
	var input_axis: float = 0.0
	if not _looking_down:
		input_axis = Input.get_axis("ui_left", "ui_right")
		if input_axis == 0.0:
			if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
				input_axis -= 1.0
			if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
				input_axis += 1.0

	# 5. Knackiges Beschleunigen & Sofort-Stopp
	if input_axis != 0.0:
		_player.velocity.x = move_toward(_player.velocity.x, input_axis * speed, acceleration * delta)
		# Spiegelt die Figur horizontal, sodass sie in Laufrichtung schaut
		if sprite:
			sprite.flip_h = (input_axis < 0.0)
		# Spiegelt zusaetzlich die asymmetrischen Collider (Headcoll, Footcoll)
		# am Player mit, damit sie visuell zur gespiegelten Figur passen.
		_player.set_facing(-1 if input_axis < 0.0 else 1)
	else:
		_player.velocity.x = move_toward(_player.velocity.x, 0.0, friction * delta)

	# 6. Animationssteuerung
	var is_moving: bool = input_axis != 0.0 and abs(_player.velocity.x) > 10.0
	_update_animation(is_moving)

	# 7. Kamera smooth nach unten/zurueck
	_update_camera(delta)

func _update_camera(delta: float) -> void:
	if not _camera:
		return
	var target_y: float = camera_look_down_offset if _looking_down else 0.0
	_camera.offset.y = move_toward(_camera.offset.y, target_y, camera_look_speed * delta)

func _update_animation(is_moving: bool) -> void:
	if not sprite:
		return
	var on_floor: bool = _player.is_on_floor()

	if not on_floor:
		_lookdown_phase = LookdownPhase.NONE
		_play_animation("jump")
		return

	if _looking_down:
		match _lookdown_phase:
			LookdownPhase.NONE:
				# Frischer Tastendruck -> "lookdown" von Frame 0 an vorwaerts
				sprite.play("lookdown")
				sprite.speed_scale = 1.0
				_lookdown_phase = LookdownPhase.TRANSITIONING_IN
			LookdownPhase.TRANSITIONING_OUT:
				# War am Rueckwaerts-Ausklingen -> nahtlos vom aktuellen Frame
				# aus wieder vorwaerts, ohne Reset.
				sprite.speed_scale = 1.0
				_lookdown_phase = LookdownPhase.TRANSITIONING_IN
			_:
				# TRANSITIONING_IN oder HOLDING: laeuft von selbst weiter
				pass
		return

	# Taste nicht (mehr) gehalten:
	match _lookdown_phase:
		LookdownPhase.TRANSITIONING_IN:
			# Kurzer Tap, "lookdown" lief noch vorwaerts -> nahtlos umkehren
			_lookdown_phase = LookdownPhase.TRANSITIONING_OUT
			sprite.speed_scale = -1.0
		LookdownPhase.HOLDING:
			# War in der Halte-Loop -> zurueck zu "lookdown" wechseln und von
			# dessen letztem Frame an rueckwaerts abspielen.
			_lookdown_phase = LookdownPhase.TRANSITIONING_OUT
			sprite.play_backwards("lookdown")
		LookdownPhase.TRANSITIONING_OUT:
			# Noch am Zurueckspielen - abwarten.
			pass
		LookdownPhase.NONE:
			if is_moving:
				_play_animation("walking")
			else:
				_play_animation("stand")

func _on_sprite_animation_finished() -> void:
	if not sprite:
		return
	if sprite.animation == "lookdown" and _lookdown_phase == LookdownPhase.TRANSITIONING_IN:
		# Vorwaerts-Uebergang fertig -> in die Halte-Loop wechseln
		sprite.play("lookdownLoop")
		sprite.speed_scale = 1.0
		_lookdown_phase = LookdownPhase.HOLDING
		return
	if sprite.animation == "lookdown" and _lookdown_phase == LookdownPhase.TRANSITIONING_OUT:
		# Rueckwaerts-Uebergang fertig (wieder bei Frame 0) -> zurueck zu normal
		_lookdown_phase = LookdownPhase.NONE
		sprite.speed_scale = 1.0

func _play_stand_animation() -> void:
	_play_animation("stand")

func _play_animation(anim_name: String) -> void:
	if not sprite:
		return
	sprite.speed_scale = 1.0
	if sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)
