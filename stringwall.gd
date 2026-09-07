extends Node2D
class_name StringWall
## Eine durchhaengende Saite, die als physische Wand funktioniert: solange
## sie intakt ist, blockiert sie den Weg (WallBlock). Ueber einen externen
## TensionTrigger.gd (Area2D beim Stimmschluessel) kann sie bis zu
## max_tension mal nachgespannt werden (request_tension_increase). Ein
## weiterer Versuch, obwohl schon voll gespannt, laesst sie reissen -
## danach wird ihre eigene Wand-Kollision UND (falls gesetzt) ein
## zusaetzlicher, im Inspector waehlbarer externer Collider deaktiviert,
## sodass der Spieler durchgehen kann. Kein Bounce/Trampolin-Verhalten und
## kein Lockern (request_tension_decrease existiert absichtlich nicht) -
## dafuer gibt es MusicString.gd.
##
## WICHTIG zu Positionen: die Kurve wird komplett in GLOBALEN Koordinaten
## berechnet und erst beim Zeichnen/Kollision-Setzen in das lokale
## Koordinatensystem des jeweiligen Ziel-Nodes umgerechnet (to_local) -
## dadurch spielt es keine Rolle, wo StringLine/WallBlock relativ zu
## StringWall im Baum positioniert sind.
##
## SETUP:
## 1. AnchorLeft und AnchorRight (Marker2D) auf die zwei Befestigungspunkte
##    ziehen. AnchorRight = Seite mit dem Stimmschluessel.
## 2. StringLine (Line2D) als Kind, als Scene Unique Name markieren.
## 3. TuningPeg (AnimatedSprite2D) als Kind, als Scene Unique Name
##    markieren. Animation (tuning_peg_animation) ohne Loop.
## 4. WallBlock (StaticBody2D) + CollisionPolygon2D als Kind, beide als
##    Scene Unique Name markieren - das ist die eigentliche Wand-Kollision,
##    die den Weg blockiert, solange die Saite haelt.
## 5. Einen TensionTrigger-Node (eigenes Skript, siehe TensionTrigger.gd)
##    irgendwo beim Stimmschluessel platzieren und "String Node" im
##    Inspector auf diesen StringWall-Node zeigen lassen (oder automatische
##    Erkennung nutzen). Die Lockern-Taste des Triggers bleibt hier einfach
##    wirkungslos, da request_tension_decrease() nicht existiert.
## 6. OPTIONAL, fuer die "Seil reisst"-Optik: StringLineRight (Line2D) als
##    Kind, als Scene Unique Name markieren, Visible im Editor AUS lassen.
## 7. OPTIONAL: external_collider_to_disable im Inspector auf einen
##    beliebigen anderen CollisionShape2D/CollisionPolygon2D in der Szene
##    zeigen lassen (z.B. eine "Gap"-Form wie bei eurem Leiter-System) - der
##    wird beim Reissen ZUSAETZLICH deaktiviert. Leer lassen, wenn nur die
##    eigene WallBlock-Kollision verschwinden soll.

signal tension_changed(new_level: int)
signal wall_broken

@export_group("Spannung")
@export var max_tension: int = 4
@export var start_tension: int = 0
@export var tension_animation_duration: float = 0.5

@export_group("Durchhang (Line2D-Kurve)")
@export var max_sag: float = 70.0
@export var min_sag: float = 8.0
@export var line_segments: int = 24
## "Dicke" der Wand-Kollision um die Kurve herum.
@export var wall_thickness: float = 24.0

@export_group("Stimmschluessel")
@export var tuning_peg_animation: String = "turn"

@export_group("Optik (Line2D)")
@export var smooth_line_rendering: bool = true

@export_group("Reissen")
## Optionaler externer Collider (z.B. eine Gap-CollisionShape2D/Polygon2D
## anderswo im Level), der beim Reissen ZUSAETZLICH zur eigenen
## WallBlock-Kollision deaktiviert wird. Muss eine "disabled"-Property
## besitzen (CollisionShape2D oder CollisionPolygon2D). Leer lassen, wenn
## nicht benoetigt.
@export var external_collider_to_disable: Node
@export var break_rope_segments: int = 14
@export var break_gravity: float = 1400.0
@export var break_damping: float = 0.985
@export var break_snap_strength: float = 60.0
@export var break_time_scale: float = 1.0

@onready var anchor_left: Marker2D = $AnchorLeft
@onready var anchor_right: Marker2D = $AnchorRight
@onready var string_line: Line2D = %StringLine
@onready var wall_block: StaticBody2D = %WallBlock
@onready var wall_collision: CollisionPolygon2D = %WallBlock/CollisionPolygon2D
@onready var tuning_peg: AnimatedSprite2D = %TuningPeg
@onready var string_line_right: Line2D = get_node_or_null("%StringLineRight")

enum PendingAction { NONE, TENSION, BREAK }

var tension_level: int = 0
var is_broken: bool = false
var _is_turning: bool = false
var _pending_action: PendingAction = PendingAction.NONE
var _display_sag: float = 0.0
var _sag_tween: Tween
var _rope_points: PackedVector2Array = PackedVector2Array()
var _rope_prev_points: PackedVector2Array = PackedVector2Array()
var _rope_segment_length: float = 0.0
var _rope_active: bool = false

func _ready() -> void:
	tension_level = clampi(start_tension, 0, max_tension)
	_display_sag = _target_sag()
	if smooth_line_rendering:
		_style_line(string_line)
		_style_line(string_line_right)
	_rebuild_visual_and_collision()
	tuning_peg.animation_finished.connect(_on_tuning_peg_animation_finished)
	if string_line_right:
		string_line_right.visible = false

func _style_line(line: Line2D) -> void:
	if not line:
		return
	line.antialiased = true
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND

## Von einem TensionTrigger.gd aufgerufen, wenn der Spieler in der Zone die
## Anspann-Taste drueckt. Startet die Dreh-Animation. Ist bereits max_tension
## erreicht, reisst die Saite (nach Ende der Animation), statt weiter zu
## spannen. Gibt true zurueck, wenn tatsaechlich eine Animation gestartet
## wurde.
func request_tension_increase() -> bool:
	if is_broken:
		return false
	if _is_turning:
		return false
	_is_turning = true
	if tension_level >= max_tension:
		_pending_action = PendingAction.BREAK
	else:
		_pending_action = PendingAction.TENSION
	tuning_peg.play(tuning_peg_animation)
	return true

func _on_tuning_peg_animation_finished() -> void:
	if tuning_peg.animation != tuning_peg_animation:
		return
	_is_turning = false
	var action: PendingAction = _pending_action
	_pending_action = PendingAction.NONE
	if action == PendingAction.BREAK:
		_break_wall()
	elif action == PendingAction.TENSION:
		tension_level = clampi(tension_level + 1, 0, max_tension)
		tension_changed.emit(tension_level)
		_animate_sag_to(_target_sag())

func _target_sag() -> float:
	var t: float = float(tension_level) / float(max_tension)
	return lerp(max_sag, min_sag, t)

func _sag_shape(t: float) -> float:
	return 4.0 * t * (1.0 - t)

func _curve_point_global(t: float) -> Vector2:
	var base: Vector2 = anchor_left.global_position.lerp(anchor_right.global_position, t)
	base.y += _display_sag * _sag_shape(t)
	return base

func _process(delta: float) -> void:
	if _rope_active:
		_step_rope_simulation(delta)

func _animate_sag_to(target_sag: float, duration: float = tension_animation_duration) -> void:
	if _sag_tween and _sag_tween.is_valid():
		_sag_tween.kill()
	_sag_tween = create_tween()
	_sag_tween.tween_method(_set_display_sag, _display_sag, target_sag, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _set_display_sag(value: float) -> void:
	_display_sag = value
	_rebuild_visual_and_collision()

func _rebuild_visual_and_collision() -> void:
	var top_points: Array[Vector2] = []
	var bottom_points: Array[Vector2] = []
	string_line.clear_points()
	for i in range(line_segments + 1):
		var t: float = float(i) / float(line_segments)
		var p_global: Vector2 = _curve_point_global(t)
		string_line.add_point(string_line.to_local(p_global))
		top_points.append(wall_collision.to_local(p_global + Vector2(0.0, -wall_thickness)))
		bottom_points.append(wall_collision.to_local(p_global + Vector2(0.0, wall_thickness)))
	var bottom_reversed: Array[Vector2] = bottom_points.duplicate()
	bottom_reversed.reverse()
	wall_collision.polygon = PackedVector2Array(top_points + bottom_reversed)

## Deaktiviert die eigene Wand-Kollision sowie (falls gesetzt) den externen
## Collider, spielt danach die "Seil reisst"-Optik ab.
func _break_wall() -> void:
	if is_broken:
		return
	is_broken = true
	wall_collision.set_deferred("disabled", true)
	if external_collider_to_disable:
		external_collider_to_disable.set_deferred("disabled", true)
	wall_broken.emit()

	string_line.visible = false
	if string_line_right:
		string_line_right.visible = true
		_start_rope_simulation()

func _start_rope_simulation() -> void:
	var point_count: int = break_rope_segments + 1
	var last: int = break_rope_segments
	_rope_points = PackedVector2Array()
	_rope_prev_points = PackedVector2Array()
	_rope_points.resize(point_count)
	_rope_prev_points.resize(point_count)

	for i in range(point_count):
		var t: float = float(i) / float(break_rope_segments)
		_rope_points[i] = _curve_point_global(t)

	var total_length: float = 0.0
	for i in range(last):
		total_length += _rope_points[i].distance_to(_rope_points[i + 1])
	_rope_segment_length = total_length / float(last)

	var snap_dir: Vector2 = Vector2(1.0, -0.4).normalized()
	if anchor_left.global_position.x > anchor_right.global_position.x:
		snap_dir.x = -snap_dir.x
	for i in range(point_count):
		var t_from_tip: float = 1.0 - float(i) / float(last)
		var kick: Vector2 = snap_dir * break_snap_strength * t_from_tip
		_rope_prev_points[i] = _rope_points[i] - kick

	_rope_active = true
	_apply_rope_constraints()
	_write_rope_points_to_line()

func _step_rope_simulation(delta: float) -> void:
	var sim_delta: float = delta * break_time_scale
	var last: int = _rope_points.size() - 1
	var max_speed: float = 0.0
	for i in range(_rope_points.size()):
		if i == last:
			_rope_points[i] = anchor_right.global_position
			_rope_prev_points[i] = anchor_right.global_position
			continue
		var current: Vector2 = _rope_points[i]
		var velocity: Vector2 = (current - _rope_prev_points[i]) * break_damping
		var next: Vector2 = current + velocity + Vector2(0.0, break_gravity) * sim_delta * sim_delta
		_rope_prev_points[i] = current
		_rope_points[i] = next
		max_speed = max(max_speed, velocity.length())

	_apply_rope_constraints()
	_write_rope_points_to_line()

	if max_speed < 0.3:
		_rope_active = false

func _write_rope_points_to_line() -> void:
	var local_points: PackedVector2Array = PackedVector2Array()
	local_points.resize(_rope_points.size())
	for i in range(_rope_points.size()):
		local_points[i] = string_line_right.to_local(_rope_points[i])
	string_line_right.points = local_points

func _apply_rope_constraints() -> void:
	var last: int = _rope_points.size() - 1
	for _iteration in range(8):
		for i in range(last):
			var p1: Vector2 = _rope_points[i]
			var p2: Vector2 = _rope_points[i + 1]
			var delta_vec: Vector2 = p2 - p1
			var dist: float = delta_vec.length()
			if dist < 0.0001:
				continue
			var diff: float = (dist - _rope_segment_length) / dist
			var correction: Vector2 = delta_vec * 0.5 * diff
			p1 += correction
			if i + 1 != last:
				p2 -= correction
			_rope_points[i] = p1
			_rope_points[i + 1] = p2
