extends AnimatedSprite2D
class_name TuningKeySequence
## Der drehende Stimmschluessel: laeuft beim Start (start_tuning()) eine
## Weg-Strecke ab (Move From Offset -> Move To Offset, in Move Duration
## Sekunden) und spielt dabei eure 16-Frame-Dreh-Animation ("Loop
## Animation") genau "Loop Count" mal komplett durch. Danach wechselt er
## automatisch zur "Stand Animation" (die Endpose) - und GENAU in dem
## Moment, in dem die startet, wird der "Stand Collider" aktiviert, auf dem
## der Spieler dann stehen kann.
##
## SETUP:
## 1. Dieses Skript direkt auf euren AnimatedSprite2D-Node packen (also den,
##    der schon die SpriteFrames-Resource mit den Animationen hat).
## 2. In den SpriteFrames zwei Animationen benennen (oder eure vorhandenen
##    Namen unten im Inspector eintragen): eine mit den 16 Dreh-Frames
##    (Standard-Name hier: "spin") und eine kurze/einzelne Animation fuer
##    die Endpose (Standard-Name hier: "stand").
## 3. Move From Offset / Move To Offset: lokale Position RELATIV zur
##    Position, an der ihr den Node im Editor platziert habt. Beispiel:
##    (0,0) -> (0,-40), wenn der Schluessel beim Spannen 40px nach oben
##    wandern soll. Bleibt Move To Offset auf (0,0), bewegt er sich gar
##    nicht - dann macht nur die Dreh-Animation etwas.
## 4. Stand Collider: zieht euren CollisionShape2D- oder CollisionPolygon2D-
##    Node rein, auf dem der Spieler stehen koennen soll. Der sollte im
##    Editor mit angehaktem "Disabled" starten - das Skript aktiviert ihn
##    automatisch, sobald "Stand" beginnt (und schaltet ihn in _ready()
##    vorsichtshalber nochmal explizit aus, falls ihr's vergesst).
## 5. Ausloeser (zwei Wege, auch gleichzeitig nutzbar):
##    a) Trigger Area unten im Inspector auf eine Area2D ziehen (z.B. eine
##       Zone am Boden vor dem Stimmschluessel) - sobald der Spieler die
##       betritt, startet die Sequenz automatisch, kein Extra-Code noetig.
##    b) Von aussen (z.B. aus eurem TensionTrigger.gd beim E-Druck) einfach
##       start_tuning() aufrufen.

@export var loop_animation: String = "spin"
@export var stand_animation: String = "stand"

@export_group("Bewegung")
## Startposition relativ zur urspruenglichen (im Editor gesetzten) Position.
@export var move_from_offset: Vector2 = Vector2.ZERO
## Zielposition relativ zur urspruenglichen Position.
@export var move_to_offset: Vector2 = Vector2.ZERO
## Wie lange die Bewegung von "Move From" zu "Move To" dauert.
@export var move_duration: float = 2.0

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
## ausgeloest werden. Normalerweise AUS lassen: sonst springt der
## Schluessel bei jedem erneuten Betreten wieder zurueck an Move From
## Offset und spult alles nochmal ab, obwohl der Spieler evtl. schon auf
## dem Stand Collider steht.
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
## Animation (egal welche Animation/welcher Frame zuletzt im Editor
## eingestellt war - der wird sonst mit in der Szene gespeichert) UND die
## Position von Move From Offset. Dadurch steht der Schluessel von Anfang
## an schon dort, wo er "vor dem Spannen" hingehoert, statt zunaechst an
## der rohen Editor-Position zu haengen und erst beim Ausloesen dorthin zu
## springen.
func _reset_visual() -> void:
	stop()
	if loop_animation != "":
		animation = loop_animation
	frame = 0
	position = _base_position + move_from_offset

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

	position = _base_position + move_from_offset
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
