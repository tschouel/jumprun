extends Area2D
## Zone direkt beim Stimmschluessel: Spieler steht rein, drueckt zuerst
## engage_key (Standard F), um den Stimmschluessel "anzufassen" - das
## BLOCKIERT NUR die Spielerbewegung (ueber ground_module.set_animation_override,
## siehe groundmovement.gd), loest aber selbst KEINE Armanimation aus. Erst
## danach reagieren increase_key/decrease_key (Standard rechts/links), um die
## Saite tatsaechlich zu spannen bzw. zu lockern - UND jeder erfolgreiche
## Dreh-Tastendruck loest dabei die Handgreif-Animation aus (falls hand_grip
## gesetzt ist). Erneutes Druecken von engage_key (oder Verlassen der Zone)
## laesst wieder los und gibt die Bewegung frei.
##
## KAMERA-EFFEKT BEIM ANGREIFEN (optional, standardmaessig AUS):
## camera_offset_x/camera_offset_y = 0.0 (Default) -> kein Offset-Effekt.
## Ungleich 0 gesetzt (einzeln oder beide zusammen): beim Angreifen faehrt
## die Kamera ueber ground_module.set_camera_offset_override() auf diesen
## Ziel-Offset (z.B. um ein grosses Instrument ganz sichtbar zu machen ODER
## seitlich zu verschieben), beim Loslassen wieder smooth zurueck auf (0, 0)
## bzw. (0, camera_look_down_offset) falls gerade nach unten geschaut wird.
##
## ZUSAETZLICH: camera_zoom_enabled = false (Default) -> kein Zoom-Effekt.
## Aktiviert und camera_zoom_target gesetzt (z.B. Vector2(0.6, 0.6) zum
## Reinzoomen): beim Angreifen faehrt die Kamera ueber
## ground_module.set_camera_zoom_override() auf diesen Zoom, beim Loslassen
## wieder zurueck auf den Zoom-Wert, der VOR dem Angreifen aktiv war (wird
## von groundmovement.gd automatisch gemerkt - unabhaengig vom
## Level-Basiswert). Nutzt dieselbe camera_move_duration/camera_move_curve
## wie der Offset-Effekt, damit beide als EINE gemeinsame Kamerafahrt wirken.
##
## camera_move_duration = 0.0 (Default) -> die Kamerafahrt (Offset UND Zoom)
## nutzt das alte, geschwindigkeitsbasierte Smoothing (camera_look_speed
## bzw. camera_zoom_speed in groundmovement.gd), ohne feste Dauer. Auf eine
## Zeit in Sekunden gesetzt: die Kamerafahrt dauert GENAU so lange (per
## Tween).
##
## camera_move_curve (optional, nur wirksam wenn camera_move_duration > 0):
## eine Curve-Ressource fuer frei editierbare, interpolierte Keyframes
## (im Inspector per Rechtsklick beliebig viele Punkte/Tangenten setzbar).
## Leer lassen fuer eine Standard-Ease-Bewegung. Gilt fuer Offset UND Zoom.
##
## SETUP: Diesen Node (Area2D + CollisionShape2D) beim Stimmschluessel-Ende
## der Saite platzieren, dieses Skript drauf, dann im Inspector "String Node"
## auf den MusicString- oder StringWall-Root-Node ziehen (oder es findet ihn
## automatisch, falls dieser Trigger irgendwo als Kind/Geschwister im
## selben Saiten-Szenenbaum sitzt - siehe _ready() unten).
##
## Funktioniert mit MusicString.gd (hat increase UND decrease) genauso wie
## mit StringWall.gd (hat nur increase - decrease wird dort automatisch per
## has_method() ignoriert).
##
## ARM (optional): "Hand Grip" im Inspector auf einen Marker2D am Griffpunkt
## des Stimmschluessels ziehen. Bei JEDEM erfolgreichen Dreh-Tastendruck
## (links ODER rechts, waehrend angefasst) wird - falls der Player irgendwo
## in seiner eigenen Szene einen Node mit dem Scene Unique Name "%SimpleArm"
## hat (siehe SimpleArm.gd) - dessen reach_and_retract(hand_grip) aufgerufen.
## Ohne %SimpleArm passiert einfach nichts (kein Fehler). Das reine Angreifen
## (engage_key) selbst loest KEINE Armanimation aus.

signal engaged
signal disengaged

@export var string_node: Node
@export var hand_grip: Node2D

@export_group("Bedienung")
## Taste zum Angreifen/Loslassen des Stimmschluessels - blockiert NUR die
## Bewegung, keine Armanimation.
@export var engage_key: Key = KEY_F
## Taste zum Anspannen - wirkt nur, waehrend der Stimmschluessel angefasst
## ist. Loest bei Erfolg die Handgreif-Animation aus.
@export var increase_key: Key = KEY_RIGHT
## Taste zum Lockern - wirkt nur, waehrend der Stimmschluessel angefasst ist.
## Wird ignoriert, falls string_node keine request_tension_decrease()-Methode
## hat (z.B. bei StringWall.gd). Loest bei Erfolg die Handgreif-Animation aus.
@export var decrease_key: Key = KEY_LEFT

@export_group("Kamera - Position")
## X-Ziel-Offset (in Pixeln), den die Kamera beim Angreifen smooth anfaehrt.
## 0.0 (Standard) = kein horizontaler Kamera-Effekt.
@export var camera_offset_x: float = 0.0
## Y-Ziel-Offset (in Pixeln), den die Kamera beim Angreifen smooth anfaehrt.
## 0.0 (Standard) = kein vertikaler Kamera-Effekt.
@export var camera_offset_y: float = 0.0

@export_group("Kamera - Zoom")
## Aktiviert den Zoom-Effekt beim Angreifen. Standard AUS, damit
## camera_zoom_target = Vector2(1,1) nicht versehentlich als "aktiver,
## aber wirkungsloser" Zoom missverstanden wird.
@export var camera_zoom_enabled: bool = false
## Ziel-Zoom, den die Kamera beim Angreifen smooth anfaehrt (nur wirksam,
## wenn camera_zoom_enabled = true). Werte < 1 zoomen NAEHER ran, Werte > 1
## zoomen WEITER raus (Godot-Konvention: kleinerer Zoom = mehr sichtbarer
## Weltausschnitt... genauer: Camera2D.zoom skaliert die View, < 1 zeigt
## MEHR von der Welt, > 1 zeigt WENIGER/zoomt rein - im Zweifel kurz
## ausprobieren, welche Richtung fuer dein Setup "reinzoomen" bedeutet).
@export var camera_zoom_target: Vector2 = Vector2(0.6, 0.6)

@export_group("Kamera - Bewegung")
## Dauer der Kamerafahrt in Sekunden (gilt fuer Offset UND Zoom gemeinsam).
## 0.0 (Standard) = altes, geschwindigkeitsbasiertes Smoothing ohne feste
## Dauer. > 0 = exakt diese Zeit, per Tween (siehe camera_move_curve).
@export var camera_move_duration: float = 0.0
## Optionale Curve-Ressource fuer frei editierbare, interpolierte Keyframes
## der Kamerafahrt (nur wirksam, wenn camera_move_duration > 0). Leer
## lassen fuer eine Standard-Ease-Bewegung. Gilt fuer Offset UND Zoom.
@export var camera_move_curve: Curve

var _player_inside: CharacterBody2D = null
var _is_engaged: bool = false

func _ready() -> void:
	if not string_node:
		string_node = _find_string_ancestor()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _find_string_ancestor() -> Node:
	var n: Node = get_parent()
	while n:
		if n.has_method("request_tension_increase"):
			return n
		n = n.get_parent()
	return null

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_inside = body

func _on_body_exited(body: Node2D) -> void:
	if body == _player_inside:
		if _is_engaged:
			_disengage()
		_player_inside = null

func _unhandled_key_input(event: InputEvent) -> void:
	if not _player_inside or not string_node:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.keycode == engage_key:
		if _is_engaged:
			_disengage()
		else:
			_engage()
		get_viewport().set_input_as_handled()
		return

	if not _is_engaged:
		return

	if event.keycode == increase_key:
		if string_node.request_tension_increase():
			_try_hand_grip()
		get_viewport().set_input_as_handled()
	elif event.keycode == decrease_key:
		if string_node.has_method("request_tension_decrease"):
			if string_node.request_tension_decrease():
				_try_hand_grip()
			get_viewport().set_input_as_handled()

## Bewegungssperre + optionale Kamera-Effekte (Offset UND Zoom) + Signal -
## KEINE Armanimation.
func _engage() -> void:
	_is_engaged = true
	engaged.emit()
	if _player_inside and "movement_locked" in _player_inside:
		_player_inside.movement_locked = true
	_lock_player_movement(true)
	_apply_camera_offset(true)
	_apply_camera_zoom(true)

func _disengage() -> void:
	_is_engaged = false
	disengaged.emit()
	_lock_player_movement(false)
	_apply_camera_offset(false)
	_apply_camera_zoom(false)

## Blockiert bzw. entsperrt die Spielerbewegung ueber das dafuer vorgesehene
## Override-System in groundmovement.gd (set_animation_override /
## clear_animation_override).
func _lock_player_movement(lock: bool) -> void:
	if not _player_inside:
		return
	var ground_module: Node = _player_inside.get("ground_module")
	if not ground_module:
		return
	if lock:
		ground_module.set_animation_override("stand")
	else:
		ground_module.clear_animation_override()

## Setzt bzw. loescht den Kamera-Offset-Override (X+Y) auf ground_module
## (siehe groundmovement.gd), inklusive Dauer/Kurve. Macht nichts, falls
## sowohl camera_offset_x als auch camera_offset_y == 0 sind (Standard aus).
func _apply_camera_offset(engage: bool) -> void:
	if camera_offset_x == 0.0 and camera_offset_y == 0.0:
		return
	if not _player_inside:
		return
	var ground_module: Node = _player_inside.get("ground_module")
	if not ground_module:
		return
	if engage:
		if ground_module.has_method("set_camera_offset_override"):
			ground_module.set_camera_offset_override(Vector2(camera_offset_x, camera_offset_y), camera_move_duration, camera_move_curve)
	else:
		if ground_module.has_method("clear_camera_offset_override"):
			ground_module.clear_camera_offset_override(camera_move_duration, camera_move_curve)

## Setzt bzw. loescht den Kamera-Zoom-Override auf ground_module (siehe
## groundmovement.gd), inklusive Dauer/Kurve. Macht nichts, wenn
## camera_zoom_enabled = false ist (Standard aus).
func _apply_camera_zoom(engage: bool) -> void:
	if not camera_zoom_enabled:
		return
	if not _player_inside:
		return
	var ground_module: Node = _player_inside.get("ground_module")
	if not ground_module:
		return
	if engage:
		if ground_module.has_method("set_camera_zoom_override"):
			ground_module.set_camera_zoom_override(camera_zoom_target, camera_move_duration, camera_move_curve)
	else:
		if ground_module.has_method("clear_camera_zoom_override"):
			ground_module.clear_camera_zoom_override(camera_move_duration, camera_move_curve)

func _try_hand_grip() -> void:
	if not hand_grip or not _player_inside:
		return
	var arm: Node = _player_inside.get_node_or_null("%SimpleArm")
	if arm and arm.has_method("reach_and_retract"):
		arm.reach_and_retract(hand_grip)
