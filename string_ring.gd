extends Line2D
class_name StringRing
## Ganz einfache Saite: liegt gerade zwischen start_point und end_point,
## vibriert automatisch mit abklingender Amplitude, sobald der Spieler
## (Gruppe "player") sie beruehrt. Kein Stimmen, kein Fretting, kein
## Reissen - nur dieser eine Effekt. Optional (siehe continuous_vibration
## unten) kann die Saite auch DAUERHAFT, ohne Abklingen, schwingen.
##
## DAUER-VIBRATION (continuous_vibration): Ist dieses Flag gesetzt,
## schwingt die Saite ab _ready() (bzw. sobald das Flag zur Laufzeit auf
## true gesetzt wird) UNUNTERBROCHEN mit konstanter Staerke, statt nach
## einer Beruehrung/pluck() abzuklingen - vibration_decay wird in diesem
## Modus komplett ignoriert. Zentriert ist die Dauerschwingung bei t=0.5
## (Mitte der Saite), es sei denn pluck() wurde zuvor mit einem anderen
## impact_t aufgerufen - dann bleibt dieser Zentrierungspunkt bestehen.
## Gedacht z.B. fuer "Erfolgs-Saiten" (siehe LevelStringDisplay.gd), die
## dauerhaft sichtbar in Bewegung bleiben sollen, statt nach kurzem
## Ausschwingen zur Ruhe zu kommen. touch() durch den Spieler funktioniert
## in diesem Modus weiterhin (zentriert die Schwingung neu auf die
## Beruehrungsstelle), klingt danach aber NICHT ab, sondern bleibt bei
## voller Staerke weiterlaufen.
##
## WELLENLAENGE UNABHAENGIG VON DER SAITENLAENGE:
## Die sichtbare Wellenanzahl haengt NICHT von einer festen Konstante ab,
## sondern von wave_length_px (raeumliche Wellenlaenge in Pixeln) und der
## tatsaechlichen Distanz zwischen start_point/end_point. Dadurch zeigt
## eine doppelt so lange Saite automatisch doppelt so viele Wellenberge,
## statt dieselbe Anzahl ueber die doppelte Laenge gestreckt (und dadurch
## "sinusig"/uebertrieben glatt wirkend) darzustellen - siehe wave_count in
## _update_points().
##
## BERUEHRUNGS-ERKENNUNG: TouchArea ist eine schlanke Area2D mit einer
## einzigen RectangleShape2D, die die Saite selbst als duennes Rechteck
## abdeckt (Breite = touch_thickness). Position, Rotation und Laenge der
## Shape werden JEDEN Frame (in _process, wie auch die Line2D-Punkte selbst)
## aus start_point/end_point neu berechnet - verschiebst du die Punkte zur
## Laufzeit, folgt die Beruehrungszone automatisch mit.
##
## Setup: als Line2D-Node in die Szene, dieses Skript dran.
## 1. start_point/end_point auf zwei Node2D (z.B. Marker2D) ziehen.
## 2. TouchArea (Area2D) + CollisionShape2D (mit einer RectangleShape2D
##    drin, Groesse ist egal - wird ueberschrieben) als Kind, beide als
##    Scene Unique Name (%) markieren.
## 3. Fuer Dauer-Vibration: continuous_vibration im Inspector anhaken (oder
##    zur Laufzeit per Code setzen, z.B. instance.continuous_vibration = true).

@export var start_point: Node2D
@export var end_point: Node2D
@export var segments: int = 40

@export_group("Vibration")
@export var vibration_amplitude: float = 10.0
## Wie SCHNELL die Vibration nach der Beruehrung wieder abklingt (pro
## Sekunde). Groesser = schneller weg, kleiner = laenger sichtbar. Wird
## ignoriert, solange continuous_vibration = true ist.
@export_range(0.1, 10.0, 0.1) var vibration_decay: float = 2.5
@export var vibration_frequency: float = 18.0
## Raeumliche Wellenlaenge in Pixeln - bestimmt, wie viele Wellenberge pro
## Laengeneinheit sichtbar sind, UNABHAENGIG von der Gesamtlaenge der
## Saite (siehe Klassenkommentar oben).
@export var wave_length_px: float = 40.0
## Wenn true: die Saite schwingt DAUERHAFT mit konstanter Staerke, statt
## nach einer Beruehrung/pluck() abzuklingen (siehe Klassenkommentar oben
## zu DAUER-VIBRATION). vibration_decay wird dann ignoriert.
@export var continuous_vibration: bool = false

@export_group("Erkennung")
## Dicke der Beruehrungszone quer zur Saite (in Pixeln).
@export var touch_thickness: float = 20.0

@onready var touch_area: Area2D = %TouchArea
@onready var touch_shape: CollisionShape2D = %TouchArea/CollisionShape2D

var _vibration_time: float = 0.0
var _vibration_strength: float = 0.0
var _vibration_center_t: float = 0.5

func _ready() -> void:
	antialiased = true
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	if touch_area and touch_shape and not (touch_shape.shape is RectangleShape2D):
		touch_shape.shape = RectangleShape2D.new()
	if touch_area:
		touch_area.body_entered.connect(_on_touch_area_body_entered)
	if continuous_vibration:
		_vibration_strength = 1.0
	if start_point and end_point:
		_update_touch_shape()
		_update_points()

func _process(delta: float) -> void:
	if not (start_point and end_point):
		return
	_vibration_time += delta
	if continuous_vibration:
		# Dauerschwingung: Staerke bleibt konstant bei 1.0, kein Abklingen.
		_vibration_strength = 1.0
	else:
		_vibration_strength = max(_vibration_strength - vibration_decay * delta, 0.0)
	_update_touch_shape()
	_update_points()

## Loest eine (bei continuous_vibration=false abklingende, sonst dauerhaft
## bei voller Staerke bleibende) Vibration aus, zentriert um impact_t (0..1
## entlang der Saite). Von aussen aufrufbar, falls du zusaetzlich noch
## manuell zupfen willst.
func pluck(impact_t: float = 0.5) -> void:
	_vibration_strength = 1.0
	_vibration_center_t = clamp(impact_t, 0.02, 0.98)

func _on_touch_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var from: Vector2 = start_point.global_position
	var to: Vector2 = end_point.global_position
	var dir: Vector2 = to - from
	var length: float = dir.length()
	if length <= 0.0:
		return
	var t: float = clamp((body.global_position - from).dot(dir / length) / length, 0.0, 1.0)
	pluck(t)

## Positioniert/dreht/skaliert die TouchArea-Kollisionsform JEDEN FRAME neu,
## sodass sie exakt zwischen start_point und end_point liegt.
func _update_touch_shape() -> void:
	if not touch_area or not touch_shape:
		return
	var from: Vector2 = start_point.global_position
	var to: Vector2 = end_point.global_position
	var dir: Vector2 = to - from
	var length: float = dir.length()
	if length <= 0.0:
		return
	var mid: Vector2 = from.lerp(to, 0.5)
	touch_area.global_position = mid
	touch_area.global_rotation = dir.angle()
	var shape: RectangleShape2D = touch_shape.shape as RectangleShape2D
	if not shape:
		shape = RectangleShape2D.new()
		touch_shape.shape = shape
	shape.size = Vector2(length, touch_thickness)
	touch_shape.position = Vector2.ZERO
	touch_shape.rotation = 0.0

func _update_points() -> void:
	var from: Vector2 = start_point.global_position
	var to: Vector2 = end_point.global_position
	var dir: Vector2 = to - from
	var length: float = dir.length()
	if length <= 0.0:
		return
	var dir_norm: Vector2 = dir / length
	var normal: Vector2 = dir_norm.orthogonal()

	# Wie viele volle Wellenberge ueber die gesamte Saite passen, basierend
	# auf der tatsaechlichen Laenge in Pixeln (statt einer festen Konstante
	# wie zuvor) - siehe Klassenkommentar oben.
	var wave_count: float = length / wave_length_px

	var new_points: PackedVector2Array = PackedVector2Array()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var base: Vector2 = from.lerp(to, t)
		var local_point: Vector2 = to_local(base)
		var edge_fade: float
		if t <= _vibration_center_t:
			var denom_left: float = _vibration_center_t
			edge_fade = sin((t / denom_left) * (PI * 0.5)) if denom_left > 0.0001 else 1.0
		else:
			var denom_right: float = 1.0 - _vibration_center_t
			edge_fade = sin(((1.0 - t) / denom_right) * (PI * 0.5)) if denom_right > 0.0001 else 0.0
		var wave: float = sin(t * TAU * wave_count + _vibration_time * vibration_frequency)
		local_point += normal * wave * edge_fade * vibration_amplitude * _vibration_strength
		new_points.append(local_point)
	points = new_points
