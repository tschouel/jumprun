extends AnimatedSprite2D
class_name TunerButterfly
## Der drehende Stimmschluessel: laeuft beim Start (start_tuning()) eine
## Weg-Strecke ab (Move From Offset -> Move To Offset, bzw. von
## flight_start_point -> Move To Offset, siehe unten) in Move Duration
## Sekunden und spielt dabei eure 16-Frame-Dreh-Animation ("Loop
## Animation") genau "Loop Count" mal komplett durch. Danach wechselt er
## automatisch zur "Stand Animation" (die Endpose) - und GENAU in dem
## Moment, in dem die startet, wird der "Stand Collider" aktiviert, auf dem
## der Spieler dann stehen kann.
##
## FREI WAEHLBARER EINFLUG-STARTPUNKT (flight_start_point, neu):
## Optional ein beliebiger Node2D (z.B. ein Marker2D, den ihr irgendwo
## ausserhalb des sichtbaren Bereichs platziert, z.B. unterhalb des
## Bildschirms fuer einen "von unten reinfliegenden" Schmetterling). Ist
## flight_start_point gesetzt, wird er als START-Position verwendet (statt
## move_from_offset) - move_to_offset bleibt weiterhin die relative
## Zielposition. flight_start_point liegt in GLOBALEN Koordinaten
## (global_position) und wird beim Start automatisch in die lokale
## Position dieses Nodes umgerechnet - es spielt also keine Rolle, wo der
## Marker im Szenenbaum sitzt. Leer lassen fuer das alte Verhalten
## (move_from_offset relativ zur eigenen Editor-Position).
##
## SETUP:
## 1. Dieses Skript direkt auf euren AnimatedSprite2D-Node packen (also den,
##    der schon die SpriteFrames-Resource mit den Animationen hat).
## 2. In den SpriteFrames zwei Animationen benennen (oder eure vorhandenen
##    Namen unten im Inspector eintragen): eine mit den 16 Dreh-Frames
##    (Standard-Name hier: "spin") und eine kurze/einzelne Animation fuer
##    die Endpose (Standard-Name hier: "stand").
## 3. Move From Offset / Move To Offset: lokale Position RELATIV zur
##    Position, an der ihr den Node im Editor platziert habt (wird
##    ignoriert, falls flight_start_point gesetzt ist - dann gilt dessen
##    globale Position als Start).
## 4. Stand Collider: zieht euren CollisionShape2D- oder CollisionPolygon2D-
##    Node rein, auf dem der Spieler stehen koennen soll. Der sollte im
##    Editor mit angehaktem "Disabled" starten - das Skript aktiviert ihn
##    automatisch, sobald "Stand" beginnt.
## 5. Ausloeser (zwei Wege, auch gleichzeitig nutzbar):
##    a) Trigger Area unten im Inspector auf eine Area2D ziehen.
##    b) Von aussen (z.B. TensionTrigger.gd, CallAndResponse.gd, oder
##       TunerButterflySequenceController.gd) einfach start_tuning()
##       aufrufen.

@export var loop_animation: String = "spin"
@export var stand_animation: String = "stand"

@export_group("Bewegung")
## Startposition relativ zur urspruenglichen (im Editor gesetzten)
## Position - wird IGNORIERT, falls flight_start_point gesetzt ist.
@export var move_from_offset: Vector2 = Vector2.ZERO
## Zielposition relativ zur urspruenglichen Position.
@export var move_to_offset: Vector2 = Vector2.ZERO
## Wie lange die Bewegung von Start zu "Move To" dauert.
@export var move_duration: float = 2.0
## Optional: beliebiger Node2D (z.B. Marker2D), dessen GLOBALE Position als
## Einflug-Startpunkt verwendet wird, statt move_from_offset. Leer lassen
## fuer das alte, offset-basierte Verhalten.
@export var flight_start_point: Node2D

@export_group("Animation")
## Wie oft die Loop-Animation komplett durchlaeuft, bevor auf die
## Stand-Animation gewechselt wird.
@export var loop_count: int = 3

@export_group("Stand-Collider")
## CollisionShape2D ODER CollisionPolygon2D - wird per "disabled"-Property
## (de-)aktiviert, das haben beide Node-Typen. Startet deaktiviert, wird
## aktiviert sobald die Stand-Animation beginnt.
@export var stand_collider: Node2D

@export_group("Ausloeser")
## Optional: Area2D, deren Betreten (durch die Spieler-Gruppe "player")
## automatisch start_tuning() ausloest. Leer lassen, wenn ihr start_tuning()
## lieber selbst von einem anderen Skript aus aufruft.
@export var trigger_area: Area2D
## Falls true, kann die Sequenz durch erneutes Betreten des Triggers nochmal
## ausgeloest werden.
@export var retriggerable: bool = false

var _base_position: Vector2
var _loops_done: int = 0
var _running: bool = false
var _triggered: bool = false

func _ready() -> void:
	_base_position = position
	if stand_collider:
		stand_collider.set("disabled", true)
	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)
	if trigger_area and not trigger_area.body_entered.is_connected(_on_trigger_area_body_entered):
		trigger_area.body_entered.connect(_on_trigger_area_body_entered)
	_reset_visual()

## Erzwingt beim Start des Spiels die "Ruhepose": Frame 0 der Loop-
## Animation UND die Start-Position (flight_start_point falls gesetzt,
## sonst move_from_offset). Dadurch steht/haengt der Schluessel bzw.
## Schmetterling von Anfang an schon dort, wo er "vor dem Start"
## hingehoert.
func _reset_visual() -> void:
	stop()
	if loop_animation != "":
		animation = loop_animation
	frame = 0
	position = _start_position()

## Ermittelt die aktuelle Start-Position: flight_start_point (in lokale
## Koordinaten umgerechnet), falls gesetzt - sonst wie bisher
## _base_position + move_from_offset.
func _start_position() -> Vector2:
	if flight_start_point:
		var parent2d := get_parent() as Node2D
		if parent2d:
			return parent2d.to_local(flight_start_point.global_position)
		return flight_start_point.global_position
	return _base_position + move_from_offset

func _on_trigger_area_body_entered(body: Node2D) -> void:
	if _triggered and not retriggerable:
		return
	if not body.is_in_group("player"):
		return
	var player := body as CharacterBody2D
	if player == null:
		return
	_triggered = true
	start_tuning()

## Startet die ganze Sequenz. Erneuter Aufruf waehrend sie schon laeuft wird
## ignoriert (kein Ueberlappen bei mehrfachem Trigger).
func start_tuning() -> void:
	if _running:
		return
	_running = true
	_loops_done = 0

	position = _start_position()
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", _base_position + move_to_offset, move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if loop_animation != "":
		play(loop_animation)
	else:
		_go_to_stand()

## Reagiert auf JEDES Ende eines Animations-Durchlaufs (bei Godot 4 feuert
## animation_finished auch bei aktivem Loop einmal pro Runde) - so wird
## mitgezaehlt, wie oft "loop_animation" schon durchgelaufen ist.
func _on_animation_finished() -> void:
	if not _running or animation != loop_animation:
		return
	_loops_done += 1
	if _loops_done >= loop_count:
		_go_to_stand()
	else:
		play(loop_animation)

func _go_to_stand() -> void:
	if stand_animation != "":
		play(stand_animation)
	if stand_collider:
		stand_collider.set("disabled", false)
	_running = false
