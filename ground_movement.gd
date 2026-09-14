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
## Geschwindigkeit (px/s) fuer das geschwindigkeitsbasierte Kamera-Smoothing
## (Look-Down UND jeder Kamera-Override mit duration=0, siehe
## set_camera_offset_override). Gilt fuer X und Y gleichermassen.
@export var camera_look_speed: float = 900.0
## Geschwindigkeit fuer das geschwindigkeitsbasierte Zoom-Smoothing (Einheiten
## Zoom-Faktor pro Sekunde), analog zu camera_look_speed - nur wirksam, wenn
## set_camera_zoom_override MIT duration=0 aufgerufen wird.
@export var camera_zoom_speed: float = 2.0
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
## Falls gesetzt: ein KOMPLETT eigenes AnimatedSprite2D (eigenes SpriteFrames),
## das waehrend des Overrides sichtbar ist statt nur eine Animation im
## normalen sprite umzuschalten - fuer Minigames mit vielen eigenen,
## diversen Animationen, die nicht ins Haupt-SpriteFrames sollen.
var _override_sprite: AnimatedSprite2D = null
# --- Externer Kamera-Offset-Override (X UND Y) ---
## Solange aktiv (duration=0-Modus), gilt ZUSAETZLICH zum normalen
## Look-Down-Verhalten ein von aussen gesetzter Ziel-Offset fuer die Kamera
## (siehe set_camera_offset_override/clear_camera_offset_override, aufgerufen
## z.B. von TensionTrigger.gd). Die X-Komponente hat IMMER Vorrang (Look-Down
## kennt nur Y), die Y-Komponente hat Vorrang vor dem normalen
## Look-Down-Ziel.
var _camera_offset_override_active: bool = false
var _camera_offset_override_target: Vector2 = Vector2.ZERO
## Laeuft eine Tween-basierte Kamerafahrt (duration>0, siehe
## _animate_camera_to)? Waehrend dieser aktiv ist, greift _update_camera()
## NICHT per move_toward ein, um Konflikte mit dem Tween zu vermeiden.
var _camera_tween_active: bool = false
var _camera_offset_tween: Tween
# --- Externer Kamera-Zoom-Override ---
## Analog zum Offset-Override, aber fuer camera.zoom. Da Zoom multiplikativ
## ist und KEINEN natuerlichen "Aus"-Wert wie (0,0) beim Offset hat, wird
## beim ERSTEN Zoom-Override der aktuelle Zoom als _camera_zoom_base
## gemerkt - clear_camera_zoom_override() faehrt exakt dorthin zurueck,
## statt hart auf einen festen Wert wie Vector2.ONE zu springen (robust
## gegenueber Leveln, die selbst schon einen abweichenden Basis-Zoom
## nutzen, z.B. fuer grosse World Scale). _camera_zoom_base_captured bleibt
## nach dem ersten Erfassen dauerhaft TRUE (wird NICHT beim Loslassen
## zurueckgesetzt) - siehe _update_camera fuer den Grund.
var _camera_zoom_override_active: bool = false
var _camera_zoom_override_target: Vector2 = Vector2.ONE
var _camera_zoom_base: Vector2 = Vector2.ONE
var _camera_zoom_base_captured: bool = false
var _camera_zoom_tween_active: bool = false
var _camera_zoom_tween: Tween
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
##
## override_sprite leer lassen: nur animation_name wird im normalen sprite
## gespielt (wie bisher). override_sprite gesetzt: der normale sprite wird
## versteckt, override_sprite stattdessen sichtbar gemacht und darauf
## animation_name gespielt - fuer Minigames mit eigenem, umfangreichem
## SpriteFrames voller diverser Animationen (z.B. beim Gitarre-Spielen), die
## nicht ins Haupt-SpriteFrames des Players gequetscht werden sollen.
func set_animation_override(animation_name: String, override_sprite: AnimatedSprite2D = null) -> void:
	_animation_override_active = true
	_animation_override_name = animation_name
	_override_sprite = override_sprite
	if _override_sprite:
		if sprite:
			sprite.visible = false
		_override_sprite.visible = true
		if animation_name != "":
			_override_sprite.speed_scale = 1.0
			if _override_sprite.animation != animation_name or not _override_sprite.is_playing():
				_override_sprite.play(animation_name)
	elif sprite and animation_name != "":
		sprite.speed_scale = 1.0
		if sprite.animation != animation_name or not sprite.is_playing():
			sprite.play(animation_name)
## Wechselt WAEHREND ein Override aktiv ist die Animation auf dem aktuell
## sichtbaren Sprite (dem override_sprite von set_animation_override, oder dem
## normalen sprite, falls keiner gesetzt wurde) - ohne Sichtbarkeiten
## anzufassen. Fuer Minigames, bei denen waehrend des Steuerns mehrere
## verschiedene Animationen nacheinander drankommen (z.B. je nachdem, welche
## Taste gerade gedrueckt wird), ohne jedes Mal den Override neu zu setzen.
func set_override_animation(animation_name: String) -> void:
	if not _animation_override_active or animation_name == "":
		return
	_animation_override_name = animation_name
	var target: AnimatedSprite2D = _override_sprite if _override_sprite else sprite
	if not target:
		return
	target.speed_scale = 1.0
	if target.animation != animation_name or not target.is_playing():
		target.play(animation_name)
## Beendet einen aktiven Override - ab dem naechsten process_movement()-Aufruf
## uebernimmt die normale Logik wieder (Stand/Walk/Jump/... je nach aktuellem
## Zustand), ganz ohne dass hier explizit etwas zurueckgesetzt werden muss.
## Macht ein evtl. genutztes override_sprite wieder unsichtbar und den
## normalen sprite wieder sichtbar.
func clear_animation_override() -> void:
	_animation_override_active = false
	_animation_override_name = ""
	if _override_sprite:
		_override_sprite.visible = false
	if sprite:
		sprite.visible = true
	_override_sprite = null
## Setzt einen von aussen erzwungenen Kamera-Ziel-Offset (X UND Y, siehe
## TensionTrigger.gd).
##
## duration <= 0 (Standard): altes Verhalten - Ziel wird ab jetzt jeden
## Frame per move_toward(camera_look_speed) in _update_camera() smooth
## angefahren, ganz ohne feste Dauer (X und Y gemeinsam als Vektor).
##
## duration > 0: neue Tween-basierte Kamerafahrt ueber GENAU diese Zeit.
## curve = null: Standard-Ease (TRANS_SINE/EASE_IN_OUT). curve gesetzt: die
## Kamera folgt exakt der uebergebenen Curve-Ressource (frei im Inspector
## mit beliebig vielen Punkten/Tangenten editierbar - "interpolierte
## Keyframes") ueber den Zeitraum 0..1 -> Start-Offset..target_offset,
## fuer X und Y gleichzeitig entlang derselben Kurve (linear interpoliert
## zwischen Start- und Zielposition, nur das Tempo/die Ease-Form kommt aus
## der Curve).
##
## Bleibt auch waehrend eines aktiven Animation-Overrides wirksam, da die
## Kamera in einem eigenen, immer aktiven _process() aktualisiert wird.
func set_camera_offset_override(target_offset: Vector2, duration: float = 0.0, curve: Curve = null) -> void:
	_camera_offset_override_active = true
	_camera_offset_override_target = target_offset
	_animate_camera_to(target_offset, duration, curve)
## Hebt einen per set_camera_offset_override gesetzten Ziel-Offset wieder auf
## - die Kamera faehrt danach (wieder wahlweise per move_toward ODER Tween,
## siehe duration/curve) zurueck auf ihr normales Ziel (X=0, Y=0 bzw.
## camera_look_down_offset falls gerade nach unten geschaut wird).
func clear_camera_offset_override(duration: float = 0.0, curve: Curve = null) -> void:
	_camera_offset_override_active = false
	var target_y: float = camera_look_down_offset if _looking_down else 0.0
	_animate_camera_to(Vector2(0.0, target_y), duration, curve)
## Gemeinsame Umsetzung fuer set_camera_offset_override/
## clear_camera_offset_override: entweder Tween starten (duration>0) oder
## den bisherigen Tween-Zustand aufraeumen und dem normalen
## move_toward-Pfad in _update_camera() die Fuehrung ueberlassen
## (duration<=0). Animiert IMMER offset.x UND offset.y gemeinsam.
func _animate_camera_to(target_offset: Vector2, duration: float, curve: Curve) -> void:
	if not _camera:
		return
	if _camera_offset_tween and _camera_offset_tween.is_valid():
		_camera_offset_tween.kill()
	if duration <= 0.0:
		_camera_tween_active = false
		return
	_camera_tween_active = true
	var start_offset: Vector2 = _camera.offset
	_camera_offset_tween = create_tween()
	if curve:
		_camera_offset_tween.tween_method(
			func(progress: float) -> void:
				_camera.offset = start_offset.lerp(target_offset, curve.sample(progress)),
			0.0, 1.0, duration
		)
	else:
		_camera_offset_tween.tween_property(_camera, "offset", target_offset, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_offset_tween.finished.connect(func() -> void: _camera_tween_active = false)
## Setzt einen von aussen erzwungenen Kamera-ZOOM-Ziel (Vector2, meist
## gleichmaessig x=y fuer proportionalen Zoom, z.B. Vector2(0.6, 0.6) zum
## Reinzoomen bei World-Scale-Werten < 1, oder Vector2(1.5, 1.5) zum
## Rauszoomen). Beim ERSTEN Aufruf wird der aktuelle camera.zoom als
## Rueckkehrpunkt gemerkt (siehe _camera_zoom_base) - clear_camera_zoom_override()
## faehrt spaeter exakt dorthin zurueck, unabhaengig vom Level-Basiswert.
##
## duration/curve verhalten sich analog zu set_camera_offset_override (0 =
## geschwindigkeitsbasiertes Smoothing ueber camera_zoom_speed, > 0 =
## Tween ueber exakt diese Zeit, curve optional fuer eigene Keyframes).
func set_camera_zoom_override(target_zoom: Vector2, duration: float = 0.0, curve: Curve = null) -> void:
	if not _camera:
		return
	if not _camera_zoom_base_captured:
		_camera_zoom_base = _camera.zoom
		_camera_zoom_base_captured = true
	_camera_zoom_override_active = true
	_camera_zoom_override_target = target_zoom
	_animate_camera_zoom_to(target_zoom, duration, curve)
## Hebt einen per set_camera_zoom_override gesetzten Zoom wieder auf - die
## Kamera faehrt zurueck auf den beim ersten Override gemerkten
## Basis-Zoom (_camera_zoom_base). _camera_zoom_base_captured bleibt dabei
## bewusst TRUE (nicht zuruecksetzen!) - sonst wuesste _update_camera beim
## naechsten Frame nicht mehr, wohin der Zoom zurueckfahren soll, und die
## Kamera wuerde einfach beim eingezoomten Wert haengen bleiben, statt nach
## dem Loslassen (z.B. erneutes F) wieder zurueckzufahren.
func clear_camera_zoom_override(duration: float = 0.0, curve: Curve = null) -> void:
	_camera_zoom_override_active = false
	var target: Vector2 = _camera_zoom_base if _camera_zoom_base_captured else Vector2.ONE
	_animate_camera_zoom_to(target, duration, curve)
## Analog zu _animate_camera_to, nur fuer camera.zoom statt camera.offset -
## eigener Tween, damit Offset- und Zoom-Fahrten unabhaengig voneinander
## gleichzeitig laufen koennen.
func _animate_camera_zoom_to(target_zoom: Vector2, duration: float, curve: Curve) -> void:
	if not _camera:
		return
	if _camera_zoom_tween and _camera_zoom_tween.is_valid():
		_camera_zoom_tween.kill()
	if duration <= 0.0:
		_camera_zoom_tween_active = false
		return
	_camera_zoom_tween_active = true
	var start_zoom: Vector2 = _camera.zoom
	_camera_zoom_tween = create_tween()
	if curve:
		_camera_zoom_tween.tween_method(
			func(progress: float) -> void:
				_camera.zoom = start_zoom.lerp(target_zoom, curve.sample(progress)),
			0.0, 1.0, duration
		)
	else:
		_camera_zoom_tween.tween_property(_camera, "zoom", target_zoom, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_zoom_tween.finished.connect(func() -> void: _camera_zoom_tween_active = false)
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
## Laeuft jeden Frame, UNABHAENGIG davon ob process_movement() gerade aktiv
## ist oder durch einen Animation-Override blockiert wird - dadurch bleibt
## die Kamera (Look-Down, Offset-Override UND Zoom-Override) immer smooth,
## selbst waehrend z.B. TensionTrigger die normale Bewegung sperrt.
func _process(delta: float) -> void:
	_update_camera(delta)
## Solange eine Tween-basierte Kamerafahrt laeuft (_camera_tween_active,
## siehe _animate_camera_to), greift diese Funktion NICHT ein - der Tween
## schreibt _camera.offset direkt. Sonst (duration<=0-Modus, klassisches
## Verhalten) wird weiterhin per move_toward(camera_look_speed) interpoliert
## - X und Y unabhaengig, aber mit derselben Geschwindigkeit. Zoom laeuft
## unabhaengig davon nach demselben Prinzip - WICHTIG: bewegt sich auch
## dann weiter (Richtung _camera_zoom_base), wenn _camera_zoom_override_active
## gerade false ist, sonst wuerde die Kamera nach clear_camera_zoom_override()
## einfach beim eingezoomten Wert stehen bleiben statt zurueckzufahren
## (identisches Prinzip wie beim Offset, der ja auch immer Richtung Vector2.ZERO
## bzw. Look-Down-Ziel weiterlaeuft, unabhaengig vom Override-Status).
func _update_camera(delta: float) -> void:
	if not _camera:
		return
	if not _camera_tween_active:
		var target: Vector2 = Vector2.ZERO
		if _camera_offset_override_active:
			target = _camera_offset_override_target
		elif _looking_down:
			target.y = camera_look_down_offset
		_camera.offset.x = move_toward(_camera.offset.x, target.x, camera_look_speed * delta)
		_camera.offset.y = move_toward(_camera.offset.y, target.y, camera_look_speed * delta)
	if not _camera_zoom_tween_active and _camera_zoom_base_captured:
		var zoom_target: Vector2 = _camera_zoom_override_target if _camera_zoom_override_active else _camera_zoom_base
		_camera.zoom.x = move_toward(_camera.zoom.x, zoom_target.x, camera_zoom_speed * delta)
		_camera.zoom.y = move_toward(_camera.zoom.y, zoom_target.y, camera_zoom_speed * delta)
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
