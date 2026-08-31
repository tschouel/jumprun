class_name GroundMovement
extends Node2D
@export_group("Geschwindigkeit & Beschleunigung")
## Maximale Laufgeschwindigkeit
@export var speed: float = 350.0
## Beschleunigung beim Anlaufen
@export var acceleration: float = 3000.0
## Hohe Reibung beim Bremsen (verhindert Schlittschuhlaufen)
@export var friction: float = 4500.0
## Reibung, mit der ein externer Stoß (z.B. Druckwelle) wieder abklingt
@export var push_friction: float = 800.0
@export_group("Sprung & Schwerkraft")
@export var jump_velocity: float = -550.0
@export var gravity: float = 1400.0
@export var max_platform_jump_boost: float = 250.0
@export_group("Leiter (Ladder)")
## Geschwindigkeit beim Hoch-/Runterklettern
@export var climb_speed: float = 180.0
## Name der Loop-Animation im Walk-SpriteFrames
@export var ladder_animation_name: String = "ladder"
## Wenn true, wird der Player beim Einsteigen horizontal auf die Leitermitte eingerastet
@export var snap_to_ladder_center: bool = true
@export_group("Kamera / Look Down")
@export var camera_look_down_offset: float = 400.0
@export var camera_look_speed: float = 900.0
@export_group("Schock-Reaktion")
## Name der Einstiegs-Animation im Walk-SpriteFrames, wird bei starkem Stoß EINMAL abgespielt
@export var shock_animation_name: String = "shockres"
## Name der Loop-Animation, die direkt nach shock_animation_name gestartet wird
@export var shock_loop_animation_name: String = "shockresloop"
## Ab diesem absoluten Stoß-Betrag (siehe apply_push) wird die Schock-Animation ausgelöst
@export var shock_threshold: float = 100.0
## Wie lange die Loop-Animation läuft, bevor's normal weitergeht
@export var shock_hold_time: float = 0.3
@export_group("Referenzen")
@export var sprite: AnimatedSprite2D
enum LookdownPhase { NONE, TRANSITIONING_IN, HOLDING, TRANSITIONING_OUT }
var is_active: bool = false
var _player: CharacterBody2D = null
var _camera: Camera2D = null
var _looking_down: bool = false
var _lookdown_phase: int = LookdownPhase.NONE
var _external_push_x: float = 0.0
var _is_shocked: bool = false
var _shock_hold_remaining: float = 0.0
## true, sobald shock_animation_name fertig ist und in shock_loop_animation_name gewechselt wurde.
var _shock_in_loop: bool = false
# --- Leiter-Zustand ---
var near_ladder: bool = false
var current_ladder: Node2D = null
var is_climbing: bool = false
var _platforms_currently_passable: bool = false
# --- Externer Animations-Override ---
## Solange aktiv, uebernimmt process_movement() NICHTS mehr (keine Bewegung,
## keine interne Animationslogik) - fuer Minigames/Mechanismen (Fader,
## TuningPeg, SinkButton, Gitarre, ...), die dem Player von aussen eine eigene
## Pose geben wollen, ohne dass diese Datei dafuer je wissen muss WAS das ist
## oder wachsen muss, wenn ein neues Minigame dazukommt.
var _animation_override_active: bool = false
var _animation_override_name: String = ""
func setup(player: CharacterBody2D) -> void:
	_player = player
	if not sprite:
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
## Ueberschreibt die Spieler-Animation von aussen. Ab dem Aufruf laeuft KEINE
## interne Bewegungs-/Animationslogik mehr (process_movement() gibt sofort
## zurueck), bis clear_animation_override() aufgerufen wird. Beliebig viele
## externe Skripte koennen das benutzen (Fader, TuningPeg, SinkButton,
## guitar_mechanism.gd, ...) - diese Datei muss dafuer nie erweitert werden.
func set_animation_override(animation_name: String) -> void:
	_animation_override_active = true
	_animation_override_name = animation_name
	if sprite and animation_name != "":
		sprite.speed_scale = 1.0
		if sprite.animation != animation_name or not sprite.is_playing():
			sprite.play(animation_name)
## Beendet einen aktiven Override - ab dem naechsten process_movement()-Aufruf
## uebernimmt die normale Logik wieder (Stand/Walk/Jump/... je nach aktuellem
## Zustand), ganz ohne dass hier explizit etwas zurueckgesetzt werden muss.
func clear_animation_override() -> void:
	_animation_override_active = false
	_animation_override_name = ""
## Fügt der Bewegung einen einmaligen Stoß hinzu (z.B. Druckwelle), klingt über push_friction ab.
## Löst zusätzlich die Schock-Animation aus, wenn der Betrag über shock_threshold liegt -
## aber nur, wenn nicht schon eine Schock-Reaktion läuft (verhindert Dauer-Neustart bei Beat-Serien).
func apply_push(amount: float) -> void:
	_external_push_x += amount
	if not _is_shocked and abs(amount) >= shock_threshold:
		_trigger_shock()
func _trigger_shock() -> void:
	if not sprite or shock_animation_name == "":
		return
	_is_shocked = true
	_shock_in_loop = false
	_shock_hold_remaining = 0.0
	_lookdown_phase = LookdownPhase.NONE
	sprite.speed_scale = 1.0
	sprite.play(shock_animation_name)
## Wird vom Ladder-Area2D über player.gd aufgerufen
func set_near_ladder(value: bool, ladder: Node2D = null) -> void:
	if current_ladder and current_ladder != ladder and current_ladder.has_method("set_platforms_passable"):
		current_ladder.set_platforms_passable(false)
		_platforms_currently_passable = false
	near_ladder = value
	current_ladder = ladder
	if not value:
		is_climbing = false
		if current_ladder and current_ladder.has_method("set_platforms_passable"):
			current_ladder.set_platforms_passable(false)
		_platforms_currently_passable = false
func process_movement(delta: float) -> void:
	if not _player:
		return
	if _animation_override_active:
		return
	if _handle_ladder(delta):
		return
	if not _player.is_on_floor():
		_player.velocity.y += gravity * delta
	else:
		_player.velocity.y = 0.0
	var jump_pressed: bool = Input.is_action_just_pressed("ui_up")
	if InputMap.has_action("jump"):
		jump_pressed = jump_pressed or Input.is_action_just_pressed("jump")
	if jump_pressed and _player.is_on_floor():
		var platform_vy: float = _player.get_platform_velocity().y
		var platform_boost: float = 0.0
		if platform_vy < 0.0:
			platform_boost = max(platform_vy, -max_platform_jump_boost)
		_player.velocity.y = jump_velocity + platform_boost
	var down_pressed: bool = Input.is_action_pressed("ui_down")
	if not down_pressed:
		down_pressed = Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	_looking_down = down_pressed and _player.is_on_floor()
	var input_axis: float = 0.0
	if not _looking_down:
		input_axis = Input.get_axis("ui_left", "ui_right")
		if input_axis == 0.0:
			if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
				input_axis -= 1.0
			if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
				input_axis += 1.0
	if input_axis != 0.0:
		_player.velocity.x = move_toward(_player.velocity.x, input_axis * speed, acceleration * delta)
		if sprite:
			sprite.flip_h = (input_axis < 0.0)
		_player.set_facing(-1 if input_axis < 0.0 else 1)
	else:
		_player.velocity.x = move_toward(_player.velocity.x, 0.0, friction * delta)
	_external_push_x = move_toward(_external_push_x, 0.0, push_friction * delta)
	_player.velocity.x += _external_push_x
	if _is_shocked and _shock_in_loop:
		_shock_hold_remaining -= delta
		if _shock_hold_remaining <= 0.0:
			_is_shocked = false
			_shock_in_loop = false
	var is_moving: bool = input_axis != 0.0 and abs(_player.velocity.x) > 10.0
	_update_animation(is_moving)
	_update_camera(delta)
func _handle_ladder(delta: float) -> bool:
	var up_pressed: bool = Input.is_action_pressed("ui_up")
	var down_pressed: bool = Input.is_action_pressed("ui_down")
	var vertical_input: float = Input.get_axis("ui_up", "ui_down")
	var just_entered: bool = false
	if not is_climbing and near_ladder and (up_pressed or down_pressed):
		is_climbing = true
		just_entered = true
		_player.velocity.x = 0.0
		if snap_to_ladder_center and current_ladder:
			_player.global_position.x = current_ladder.global_position.x
	if not is_climbing:
		_set_platforms_passable(false)
		return false
	if not near_ladder:
		is_climbing = false
		_set_platforms_passable(false)
		return false
	if not just_entered and _player.is_on_floor() and vertical_input > 0.0:
		is_climbing = false
		_set_platforms_passable(false)
		return false
	_set_platforms_passable(true)
	_player.velocity.y = vertical_input * climb_speed
	_player.velocity.x = 0.0
	if sprite:
		if vertical_input != 0.0:
			if sprite.animation != ladder_animation_name or not sprite.is_playing():
				sprite.speed_scale = 1.0
				sprite.play(ladder_animation_name)
		else:
			if sprite.animation != ladder_animation_name:
				sprite.play(ladder_animation_name)
			sprite.pause()
	return true
func _set_platforms_passable(passable: bool) -> void:
	if _platforms_currently_passable == passable:
		return
	if current_ladder and current_ladder.has_method("set_platforms_passable"):
		current_ladder.set_platforms_passable(passable)
	_platforms_currently_passable = passable
func _update_camera(delta: float) -> void:
	if not _camera:
		return
	var target_y: float = camera_look_down_offset if _looking_down else 0.0
	_camera.offset.y = move_toward(_camera.offset.y, target_y, camera_look_speed * delta)
func _update_animation(is_moving: bool) -> void:
	if not sprite:
		return
	if _is_shocked:
		return
	var on_floor: bool = _player.is_on_floor()
	if not on_floor:
		_lookdown_phase = LookdownPhase.NONE
		_play_animation("jump")
		return
	if _looking_down:
		match _lookdown_phase:
			LookdownPhase.NONE:
				sprite.play("lookdown")
				sprite.speed_scale = 1.0
				_lookdown_phase = LookdownPhase.TRANSITIONING_IN
			LookdownPhase.TRANSITIONING_OUT:
				sprite.speed_scale = 1.0
				_lookdown_phase = LookdownPhase.TRANSITIONING_IN
			_:
				pass
		return
	match _lookdown_phase:
		LookdownPhase.TRANSITIONING_IN:
			_lookdown_phase = LookdownPhase.TRANSITIONING_OUT
			sprite.speed_scale = -1.0
		LookdownPhase.HOLDING:
			_lookdown_phase = LookdownPhase.TRANSITIONING_OUT
			sprite.play_backwards("lookdown")
		LookdownPhase.TRANSITIONING_OUT:
			pass
		LookdownPhase.NONE:
			if is_moving:
				_play_animation("walking")
			else:
				_play_animation("stand")
func _on_sprite_animation_finished() -> void:
	if not sprite:
		return
	if sprite.animation == shock_animation_name and _is_shocked and not _shock_in_loop:
		_shock_in_loop = true
		_shock_hold_remaining = shock_hold_time
		sprite.speed_scale = 1.0
		sprite.play(shock_loop_animation_name)
		return
	if sprite.animation == shock_loop_animation_name and _is_shocked:
		# Loop-Durchlauf zu Ende - das Herunterzählen von _shock_hold_remaining
		# passiert in process_movement(), hier ist nichts weiter zu tun.
		return
	if sprite.animation == "lookdown" and _lookdown_phase == LookdownPhase.TRANSITIONING_IN:
		sprite.play("lookdownLoop")
		sprite.speed_scale = 1.0
		_lookdown_phase = LookdownPhase.HOLDING
		return
	if sprite.animation == "lookdown" and _lookdown_phase == LookdownPhase.TRANSITIONING_OUT:
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
