extends Node

## Steuert den (vereinfachten) Gopichand-Mechanismus: Taste F in der
## Interaktionszone aktiviert/verlaesst den Spielmodus. Waehrend aktiv,
## loest Taste E (pluck_key) das Anspielen der Saite aus - eigene
## Zupf-Animation (pluck_sprite, optional), kurz danach (pluck_delay)
## string_node.pluck(). Keine Hebel, kein Fretting, kein zweites Pedal -
## anders als guitarmech.gd (das volle 6-Mechanik-Original) gibt es hier nur
## diese eine Aktion.
##
## CALL-AND-RESPONSE (optional): Falls call_and_response gesetzt ist, wird
## bei JEDEM tatsaechlichen Zupfen (nach pluck_delay) zusaetzlich
## call_and_response.register_note() mit der aktuellen Tonhoehe
## (string_node.tension_level) aufgerufen. Das Starten/Abbrechen einer
## Herausforderung passiert NICHT hier, sondern eigenstaendig in
## call_and_response.gd selbst (das denselben Interaktionszone-Trigger
## eigenstaendig ueberwacht) - siehe call_and_response.gd.
##
## AUSSTIEGS-SPERRE (neu): waehrend lock_exit() aktiv ist (siehe
## unlock_exit()), ignoriert _deactivate() JEDEN Aufruf - egal ob durch F
## oder durch Verlassen von interaction_zone. Gedacht fuer Momente wie das
## Finale in tuner_butterfly_sequence_controller.gd, waehrend derer der
## Spieler das Instrument/Vehicle nicht verlassen koennen soll (z.B.
## waehrend die Kamera rauszoomt und die Abschluss-Animation laeuft).
## Oeffentlich aufrufbar von aussen ueber lock_exit()/unlock_exit() bzw.
## abfragbar ueber is_exit_locked().
##
## KAMERA-EFFEKT BEIM AKTIVIEREN (optional, standardmaessig AUS):
## camera_offset_x/camera_offset_y = 0.0 (Default) -> kein Offset-Effekt.
## Ungleich 0 gesetzt: beim Aktivieren (F) faehrt die Kamera ueber
## ground_module.set_camera_offset_override() auf diesen Ziel-Offset (z.B.
## um das Instrument ganz sichtbar zu machen), beim Deaktivieren wieder
## smooth zurueck.
##
## ZUSAETZLICH: camera_zoom_enabled = false (Default) -> kein Zoom-Effekt.
## Aktiviert und camera_zoom_target gesetzt (z.B. Vector2(0.6, 0.6) zum
## Reinzoomen): beim Aktivieren faehrt die Kamera ueber
## ground_module.set_camera_zoom_override() auf diesen Zoom, beim
## Deaktivieren wieder zurueck auf den Zoom-Wert, der VOR dem Aktivieren
## galt (wird von groundmovement.gd automatisch gemerkt).
##
## camera_transition_duration/camera_transition_curve gelten GEMEINSAM fuer
## Offset UND Zoom - es gibt hier absichtlich nur EINE Zeit/Kurve fuer
## beide Effekte, damit sie sich als EINE einheitliche Kamerafahrt anfuehlen.
##
## Diese Kamera-Logik hier verwenden statt sie in einen separaten
## Zonen-Node auszulagern - _activate()/_deactivate() tracken hier schon
## den Aktivierungszustand und die Player-Referenz, ein zweiter Node
## wuerde dieselbe Zustandsverwaltung nur duplizieren.
##
## Setup: interaction_zone auf die Area2D zeigen lassen, die den Spieler
## erkennt. string_node auf den Line2D-Saiten-Node zeigen lassen (z.B. mit
## guitar_string_tunable.gd oder PluckableString.gd - beide haben eine
## pluck()-Methode UND eine tension_level-Property). player auf den
## CharacterBody2D-Player zeigen lassen.

@export_group("Zone & Aktivierung")
@export var interaction_zone: Area2D
@export var toggle_key: Key = KEY_F
@export var player: CharacterBody2D
@export var freeze_player_while_active: bool = true
## Animationsname, der waehrend des Spielmodus per
## GroundMovement.set_animation_override() angezeigt wird. Leer lassen, um
## die Player-Animation nicht anzufassen.
@export var player_animation_override: String = ""
## Optional: eigenes AnimatedSprite2D (eigenes SpriteFrames) fuer eine
## eigene Gopichand-Spielhaltung des Players, statt sie ins
## Haupt-SpriteFrames zu quetschen - wird waehrend des Spielmodus sichtbar,
## der normale Player-Sprite wird solange versteckt. Leer lassen, um
## stattdessen nur player_animation_override im normalen Sprite abzuspielen.
@export var player_override_sprite: AnimatedSprite2D

@export_group("Saite")
@export var string_node: Node

@export_group("Call & Response (optional)")
## Falls gesetzt: register_note(string_node.tension_level) wird bei jedem
## Zupfen aufgerufen. Start/Abbruch einer Herausforderung passiert
## eigenstaendig in call_and_response.gd, nicht hier.
@export var call_and_response: Node

@export_group("Zupf-Animation")
## Loest das Anspielen der Saite aus, solange der Spielmodus aktiv ist.
@export var pluck_key: Key = KEY_E
## Optional: eigene AnimatedSprite2D fuer den Zupf-Moment (z.B. eine Hand
## oder ein Schlegel). Kann leer bleiben - dann wird trotzdem geplueckt, nur
## ohne eigene Animation dafuer.
@export var pluck_sprite: AnimatedSprite2D
@export var pluck_animation_name: String = "pluck"
## Wie lange nach dem Tastendruck gewartet wird, bevor die Saite tatsaechlich
## vibriert (string_node.pluck()) - fuer den Sync mit der Zupf-Animation. 0 = sofort.
@export var pluck_delay: float = 0.1

@export_group("Kamera")
## X-Ziel-Offset (in Pixeln), den die Kamera beim Aktivieren smooth anfaehrt.
## 0.0 (Standard) = kein horizontaler Kamera-Effekt.
@export var camera_offset_x: float = 0.0
## Y-Ziel-Offset (in Pixeln), den die Kamera beim Aktivieren smooth anfaehrt.
## 0.0 (Standard) = kein vertikaler Kamera-Effekt.
@export var camera_offset_y: float = 0.0
## Aktiviert den Zoom-Effekt beim Aktivieren des Spielmodus. Standard AUS.
@export var camera_zoom_enabled: bool = false
## Ziel-Zoom, den die Kamera beim Aktivieren smooth anfaehrt (nur wirksam,
## wenn camera_zoom_enabled = true). Werte < 1 zoomen naeher ran, Werte > 1
## zoomen weiter raus (im Zweifel kurz ausprobieren, welche Richtung fuer
## dein Setup "reinzoomen" bedeutet).
@export var camera_zoom_target: Vector2 = Vector2(0.6, 0.6)
## GLOBALE Dauer in Sekunden fuer die gesamte Kamerafahrt (Offset UND Zoom
## GEMEINSAM). 0.0 (Standard) = altes, geschwindigkeitsbasiertes Smoothing
## ohne feste Dauer (camera_look_speed/camera_zoom_speed in
## groundmovement.gd). > 0 = beide Effekte dauern GENAU so lange, per Tween.
@export var camera_transition_duration: float = 0.0
## Optionale Curve-Ressource fuer frei editierbare, interpolierte Keyframes
## der Kamerafahrt (nur wirksam, wenn camera_transition_duration > 0). Gilt
## GEMEINSAM fuer Offset UND Zoom. Leer lassen fuer eine Standard-Ease-
## Bewegung.
@export var camera_transition_curve: Curve

var _player_in_zone: bool = false
var _is_active: bool = false
var _exit_locked: bool = false
var _ground_movement: Node = null

func _ready() -> void:
	if player:
		_ground_movement = player.get_node_or_null("GroundMovement")
	if interaction_zone:
		interaction_zone.body_entered.connect(_on_zone_body_entered)
		interaction_zone.body_exited.connect(_on_zone_body_exited)

func _on_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_zone = true

func _on_zone_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_zone = false
		if _is_active:
			_deactivate()

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_zone:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == toggle_key:
		if _is_active:
			_deactivate()
		else:
			_activate()
	elif event.physical_keycode == pluck_key and _is_active:
		_trigger_pluck_sequence()

## Verhindert ab sofort jedes Deaktivieren (weder per F noch durch
## Verlassen von interaction_zone), bis unlock_exit() aufgerufen wird.
## Macht NICHTS, falls der Spielmodus gerade gar nicht aktiv ist - eine
## Sperre "faengt" den Modus also nicht nachtraeglich ein.
func lock_exit() -> void:
	_exit_locked = true

## Hebt eine mit lock_exit() gesetzte Sperre wieder auf - deaktiviert den
## Spielmodus dabei NICHT selbst, macht ihn nur wieder verlassbar.
func unlock_exit() -> void:
	_exit_locked = false

func is_exit_locked() -> bool:
	return _exit_locked

func _activate() -> void:
	_is_active = true
	if freeze_player_while_active and player:
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO
	if _ground_movement and _ground_movement.has_method("set_animation_override"):
		if player_animation_override != "" or player_override_sprite:
			_ground_movement.set_animation_override(player_animation_override, player_override_sprite)
	_apply_camera_offset(true)
	_apply_camera_zoom(true)

## Verlaesst den Spielmodus - tut NICHTS, solange _exit_locked gesetzt ist
## (siehe lock_exit()), egal ob der Aufruf von der F-Taste oder vom
## Verlassen der interaction_zone kommt.
func _deactivate() -> void:
	if _exit_locked:
		return
	_is_active = false
	if freeze_player_while_active and player:
		player.set_physics_process(true)
	if _ground_movement and _ground_movement.has_method("clear_animation_override"):
		_ground_movement.clear_animation_override()
	if pluck_sprite:
		pluck_sprite.stop()
	_apply_camera_offset(false)
	_apply_camera_zoom(false)

## Setzt bzw. loescht den Kamera-Offset-Override (X+Y) auf ground_module
## (siehe groundmovement.gd), unter Verwendung der GLOBALEN
## camera_transition_duration/camera_transition_curve. Macht nichts, falls
## sowohl camera_offset_x als auch camera_offset_y == 0 sind (Standard aus).
func _apply_camera_offset(activate: bool) -> void:
	if camera_offset_x == 0.0 and camera_offset_y == 0.0:
		return
	if not _ground_movement:
		return
	if activate:
		if _ground_movement.has_method("set_camera_offset_override"):
			_ground_movement.set_camera_offset_override(Vector2(camera_offset_x, camera_offset_y), camera_transition_duration, camera_transition_curve)
	else:
		if _ground_movement.has_method("clear_camera_offset_override"):
			_ground_movement.clear_camera_offset_override(camera_transition_duration, camera_transition_curve)

## Setzt bzw. loescht den Kamera-Zoom-Override auf ground_module (siehe
## groundmovement.gd), unter Verwendung derselben GLOBALEN
## camera_transition_duration/camera_transition_curve wie der Offset-Effekt.
## Macht nichts, wenn camera_zoom_enabled = false ist (Standard aus).
func _apply_camera_zoom(activate: bool) -> void:
	if not camera_zoom_enabled:
		return
	if not _ground_movement:
		return
	if activate:
		if _ground_movement.has_method("set_camera_zoom_override"):
			_ground_movement.set_camera_zoom_override(camera_zoom_target, camera_transition_duration, camera_transition_curve)
	else:
		if _ground_movement.has_method("clear_camera_zoom_override"):
			_ground_movement.clear_camera_zoom_override(camera_transition_duration, camera_transition_curve)

func _pluck() -> void:
	if string_node and string_node.has_method("pluck"):
		string_node.pluck()
	if call_and_response and call_and_response.has_method("register_note") and string_node and ("tension_level" in string_node):
		call_and_response.register_note(string_node.tension_level)

## Wird nur beim WECHSEL "nicht gehalten -> gehalten" ausgeloest (nicht bei
## jedem Frame, in dem die Taste gehalten wird) - also einmal pro Tastendruck.
func _trigger_pluck_sequence() -> void:
	if pluck_sprite:
		pluck_sprite.stop()
		pluck_sprite.play(pluck_animation_name)
	if pluck_delay <= 0.0:
		_pluck()
	else:
		get_tree().create_timer(pluck_delay).timeout.connect(_deferred_pluck)

func _deferred_pluck() -> void:
	# Falls der Modus zwischen Tastendruck und Ablauf des delays schon
	# verlassen wurde, soll nicht nachtraeglich noch geplueckt werden.
	if _is_active:
		_pluck()
