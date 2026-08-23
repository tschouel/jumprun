extends Node2D
class_name SimpleArm
## Zeichnet eine ECHTE Elipse (spitz zulaufend an beiden Enden, wie eure
## Fuss-Grafik) statt einer Linie mit runden Enden (das war vorher eine
## "Kapsel"-Form, keine richtige Elipse). Die Elipse ist NICHT dauerhaft
## sichtbar, sondern faehrt nur auf Kommando einmalig kurz vom
## Koerpermittelpunkt des Players zu einem Zielpunkt "auffaehrt" (Greif-
## Geste), beruehrt ihn kurz und zieht sich danach wieder ein. Ausgeloest
## per reach_and_retract(target), z.B. von TensionTrigger.gd genau in dem
## Moment, in dem der Spieler E drueckt.
##
## SETUP (nur EIN Schritt): einen Node2D als Kind vom Player anlegen (KEIN
## Line2D mehr noetig - diese Version zeichnet ihre Form selbst ueber
## _draw()), dieses Skript drauf, als Scene Unique Name "%SimpleArm"
## markieren (Rechtsklick -> "Ueber einzigartigen Namen zugreifen").
##
## WICHTIG fuer den Startpunkt: "Body Point" im Inspector auf einen
## Marker2D in der Koerpermitte ziehen. Bleibt das Feld leer, wird die
## Position des Players selbst genommen - die liegt bei den meisten
## Playern (wegen des Collision-Shapes) auf Fusshoehe, wodurch die Elipse
## vom Boden statt vom Koerper aus startet. Also: neuen Marker2D als Kind
## vom Player anlegen, auf Brust-/Koerpermitte schieben, hier reinziehen.

@export var body_point: Node2D  ## Ursprung der Elipse. Leer lassen = Player-Position selbst (siehe Hinweis oben).
## Breite/Dicke der Elipse an ihrer dicksten Stelle (in der Mitte).
@export var ellipse_thickness: float = 16.0
@export var arm_color: Color = Color.BLACK
## Wie viele Punkte die Elipsen-Kontur hat - mehr = runder/glatter.
@export var ellipse_resolution: int = 20

@export_group("Greif-Animation")
## Wie lange das Ausfahren zum Ziel dauert (der "Aufbau").
@export var extend_duration: float = 0.18
## Wie lange kurz am Ziel "gehalten" wird, bevor es sich zurueckzieht.
@export var hold_duration: float = 0.12
## Wie lange das Zurueckziehen dauert.
@export var retract_duration: float = 0.22

var _target_pos: Vector2 = Vector2.ZERO
var _reach_t: float = 0.0  # 0 = eingezogen (unsichtbar), 1 = beruehrt das Ziel
var _tween: Tween

func _ready() -> void:
	visible = false

func _get_origin() -> Node2D:
	return body_point if body_point else get_parent()

## Startet die Greif-Geste: faehrt zum Zielpunkt aus, haelt kurz, zieht sich
## wieder zurueck. Ein erneuter Aufruf waehrend eine Animation noch laeuft
## bricht die alte sauber ab und startet neu (verhindert Ueberlappen bei
## schnellem Mehrfach-Druecken von E).
func reach_and_retract(target: Node2D) -> void:
	if not target:
		return
	_target_pos = target.global_position
	if _tween and _tween.is_valid():
		_tween.kill()

	visible = true
	_set_reach_t(0.0)

	_tween = create_tween()
	_tween.tween_method(_set_reach_t, 0.0, 1.0, extend_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold_duration)
	_tween.tween_method(_set_reach_t, 1.0, 0.0, retract_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void: visible = false)

func _set_reach_t(value: float) -> void:
	_reach_t = value
	queue_redraw()

## Zeichnet die Elipse: von "from" (Koerper) bis zur aktuellen Spitze "tip"
## (Koerper -> Ziel, interpoliert ueber _reach_t). Das Profil (sin(t*PI))
## sorgt dafuer, dass die Form an BEIDEN Enden spitz zulaeuft und in der
## Mitte am dicksten ist - eine echte Elipse statt einer Kapsel-/Stadion-Form.
func _draw() -> void:
	var origin: Node2D = _get_origin()
	if not origin:
		return
	var from_local: Vector2 = to_local(origin.global_position)
	var to_local_pos: Vector2 = to_local(_target_pos)
	var tip: Vector2 = from_local.lerp(to_local_pos, _reach_t)

	var diff: Vector2 = tip - from_local
	var length: float = diff.length()
	if length < 1.0:
		return
	var angle: float = diff.angle()
	var half_thickness: float = ellipse_thickness * 0.5

	# Elipsen-Kontur in lokalem, UNROTIERTEM Raum berechnen (x von 0 bis
	# length entlang der Greifrichtung, y = Breite an dieser Stelle) -
	# danach wird alles um "angle" gedreht und zu "from_local" verschoben.
	var top_edge: PackedVector2Array = PackedVector2Array()
	var bottom_edge: PackedVector2Array = PackedVector2Array()
	for i in range(ellipse_resolution + 1):
		var t: float = float(i) / float(ellipse_resolution)
		var x: float = t * length
		var profile: float = sin(t * PI)  # 0 an beiden Enden, 1 in der Mitte
		top_edge.append(Vector2(x, -half_thickness * profile))
		bottom_edge.append(Vector2((1.0 - t) * length, half_thickness * sin((1.0 - t) * PI)))

	var local_points: PackedVector2Array = top_edge
	local_points.append_array(bottom_edge)

	var final_points: PackedVector2Array = PackedVector2Array()
	for p in local_points:
		final_points.append(p.rotated(angle) + from_local)

	draw_colored_polygon(final_points, arm_color)
