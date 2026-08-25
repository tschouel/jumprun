@tool
class_name VibrationLine
extends CPUParticles2D
## Partikel-Linie: PointA/PointB als Marker2D-Kinder positionieren, Textur (.png)
## im Inspector unter "Textur" zuweisen. Ueber `state` das Verhalten waehlen.
## Laeuft dank @tool auch im Editor, damit PointA/PointB beim Ziehen live
## die Emissions-Linie aktualisieren.

enum VibrationState { SHORT = 1, MEDIUM = 2, CONTINUOUS = 3 }

@export_group("Linie")
@export var point_a_path: NodePath = ^"PointA"
@export var point_b_path: NodePath = ^"PointB"
## Wie viele moegliche Spawn-Punkte entlang der Linie erzeugt werden
@export var points_along_line: int = 24

@export_group("Zustand")
## 1 = kurz & niedrig, 2 = etwas laenger & hoeher, 3 = dauerhaftes Feuern
@export var state: VibrationState = VibrationState.SHORT:
	set(value):
		state = value
		if is_inside_tree():
			_apply_state()
## Wenn an, startet der Effekt automatisch beim Erscheinen der Szene (nur im Spiel)
@export var auto_play: bool = true

@export_group("Partikel-Anzahl pro Zustand")
@export var amount_short: int = 14:
	set(value):
		amount_short = value
		if is_inside_tree() and state == VibrationState.SHORT:
			_apply_state()
@export var amount_medium: int = 20:
	set(value):
		amount_medium = value
		if is_inside_tree() and state == VibrationState.MEDIUM:
			_apply_state()
@export var amount_continuous: int = 26:
	set(value):
		amount_continuous = value
		if is_inside_tree() and state == VibrationState.CONTINUOUS:
			_apply_state()

var _point_a: Node2D
var _point_b: Node2D
var _last_a: Vector2 = Vector2.INF
var _last_b: Vector2 = Vector2.INF

func _ready() -> void:
	_point_a = get_node_or_null(point_a_path)
	_point_b = get_node_or_null(point_b_path)
	_update_emission_points()
	_apply_state()
	if Engine.is_editor_hint():
		set_process(true)
		return
	if auto_play:
		play()
	else:
		emitting = false

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if not _point_a or not _point_b:
		return
	# Nur neu berechnen, wenn sich PointA/PointB wirklich bewegt haben -
	# verhindert, dass der Inspector durch staendige Property-Updates
	# blockiert/zappelig wird.
	if _point_a.position != _last_a or _point_b.position != _last_b:
		_last_a = _point_a.position
		_last_b = _point_b.position
		_update_emission_points()

## Berechnet die Spawn-Punkte entlang der Linie A-B in lokalen Koordinaten
func _update_emission_points() -> void:
	if not _point_a or not _point_b:
		_point_a = get_node_or_null(point_a_path)
		_point_b = get_node_or_null(point_b_path)
	if not _point_a or not _point_b:
		return
	var a: Vector2 = _point_a.position
	var b: Vector2 = _point_b.position
	var pts := PackedVector2Array()
	var count: int = max(points_along_line, 2)
	for i in range(count):
		var t: float = float(i) / float(count - 1)
		pts.append(a.lerp(b, t))
	emission_points = pts
	emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS

## Setzt Lebensdauer, Geschwindigkeit, Schwerkraft, Anzahl & Emissionsart
## passend zum Zustand.
func _apply_state() -> void:
	direction = Vector2.UP
	spread = 20.0
	match state:
		VibrationState.SHORT:
			gravity = Vector2(0, 220.0)
			one_shot = true
			explosiveness = 0.8
			lifetime = 1.0
			amount = amount_short
			initial_velocity_min = 60.0
			initial_velocity_max = 100.0
		VibrationState.MEDIUM:
			gravity = Vector2(0, 220.0)
			one_shot = true
			explosiveness = 0.6
			lifetime = 1.6
			amount = amount_medium
			initial_velocity_min = 110.0
			initial_velocity_max = 160.0
		VibrationState.CONTINUOUS:
			# Weniger Schwerkraft + laengere Lebensdauer + mehr Anfangstempo
			# = die Partikel fliegen spuerbar laenger/weiter nach oben.
			gravity = Vector2(0, 90.0)
			one_shot = false
			explosiveness = 0.0
			lifetime = 2.5
			amount = amount_continuous
			initial_velocity_min = 150.0
			initial_velocity_max = 220.0

## Startet (bzw. startet neu) den Effekt mit dem aktuell gesetzten Zustand
func play() -> void:
	if Engine.is_editor_hint():
		return
	_update_emission_points()
	_apply_state()
	restart()

## Wechselt den Zustand und spielt ihn sofort ab (z.B. von aussen aufrufbar)
func play_state(new_state: VibrationState) -> void:
	state = new_state
	play()

## Stoppt die Dauerfeuer-Variante (Zustand 3) manuell
func stop() -> void:
	emitting = false
