extends Line2D
class_name GuitarString
## Vereinheitlichte, spielbare Gitarrensaite. Liegt zwischen start_point und
## end_point, kann ueber press_points verkuerzt/gefrettet werden, vibriert
## nach jedem pluck()-Aufruf mit abklingender Amplitude - UND kann
## zusaetzlich ueber einen Stimmschluessel (TuningPeg) in bis zu
## max_tension Stufen gestimmt werden (hoehere Spannung = hoeherer,
## duennerer Ton). Der Spieler kann die Saite ausserdem physisch
## durchqueren, was automatisch einen pluck() an der Durchquerungsstelle
## ausloest - ohne Rueckstoss, die Saite ist frei passierbar.
##
## VERKUERZUNG (press_points): Bis zu mehrere Punkte (z.B. Marker2D), an
## denen die Saite heruntergedrueckt wird, wenn der zugehoerige Index aktiv
## ist (set_pressed_point(index), von aussen aufgerufen, z.B. von einem
## Fret-Controller). Der vibrierende Bereich ist dann start_point bis zum
## aktiven Druckpunkt - der Rest liegt "tot" auf dem Bund, wie bei einer
## echten Gitarre. Ohne aktiven Druckpunkt vibriert die ganze Saite.
##
## SPIELER-DURCHQUERUNG (automatischer Pluck):
## PluckArea (Area2D) ist eine grosszuegige, NICHT-blockierende Trigger-Zone
## um die aktuelle (ggf. gefrettete) Saitenform herum. Waehrend ein Spieler
## sich darin befindet, wird jeden Physik-Frame seine Position relativ zur
## STABILEN (nicht-vibrierenden, aber ggf. press-gebogenen) Saitenform
## geprueft: wechselt das Vorzeichen (er quert die Saite von einer Seite
## zur anderen), wird automatisch pluck() an der Durchquerungsstelle
## ausgeloest. _local_normal(t) berechnet dafuer per finiter Differenz die
## tatsaechliche Normale an der jeweiligen Kurvenstelle - dadurch
## funktioniert die Erkennung auch waehrend die Saite gerade gefrettet/
## gebogen ist.
##
## STIMMSCHLUESSEL / TONHOEHE: Ueber einen externen TensionTrigger.gd
## (Area2D beim Stimmschluessel) kann die Saite bis zu max_tension mal
## nachgespannt (request_tension_increase) oder wieder gelockert werden
## (request_tension_decrease). Wirkt NUR auf die Vibration (Frequenz steigt,
## Amplitude sinkt mit hoeherer Spannung) - kein Durchhang, der sich
## aendert, die Saite bleibt optisch gerade zwischen start_point/end_point
## (abgesehen von Press-Biegung und Vibration). Die Saite kann NICHT
## reissen - keine Reissmechanik in diesem Skript.
##
## Setup: als Line2D-Node in die Szene, dieses Skript dran.
## 1. start_point/end_point auf zwei Node2D (z.B. Marker2D an Sattel/Steg).
## 2. Optional press_points: bis zu mehrere Marker2D, an den Stellen, wo
##    gefrettet werden koennen soll.
## 3. Optional pluck_point: Marker2D, wo die Vibration standardmaessig
##    zentriert ist, wenn pluck() ohne genauen Punkt aufgerufen wird
##    (z.B. von einer externen E-Taste statt einer echten Durchquerung).
## 4. TuningPeg (AnimatedSprite2D) als Kind, als Scene Unique Name (%)
##    markieren. Zwei Animationen ohne Loop noetig: tuning_peg_animation
##    (z.B. "turn") und tuning_peg_max_animation (z.B. "turn_stuck").
## 5. PluckArea (Area2D) + CollisionPolygon2D als Kind, beide als Scene
##    Unique Name markieren - fuer die automatische Durchquerungs-
##    Erkennung. Polygon-Punkte werden automatisch gesetzt.
## 6. Fuer die Spannungssteuerung: einen TensionTrigger-Node irgendwo beim
##    Stimmschluessel platzieren, "String Node" im Inspector auf diesen
##    GuitarString-Node zeigen lassen.
## 7. Fuer manuelles Zupfen per Taste (z.B. E): ein separater, einfacher
##    Controller (wie dein gopichand.gd) ruft pluck() auf diesem Node auf -
##    bleibt bewusst getrennt von diesem Skript, damit Aktivierung/
##    Spielerbewegung/Animationen nicht hier mit reinwuchern.

signal tension_changed(new_level: int)

@export_group("Enden")
@export var start_point: Node2D
@export var end_point: Node2D
@export var segments: int = 40

@export_group("Verkuerzung (Druckpunkte)")
## Punkte, an denen die Saite heruntergedrueckt wird, wenn der zugehoerige
## Index aktiv ist (siehe set_pressed_point). Leer lassen, wenn keine
## Verkuerzung gebraucht wird.
@export var press_points: Array[Node2D] = []
## Wie schnell die Saite zum Druckpunkt hin bzw. wieder zurueck interpoliert.
@export var press_speed: float = 20.0
## Wie weit (in Pixeln senkrecht zur Saite) der Druckpunkt die Saite "durchbiegt".
@export var press_depth: float = 12.0

@export_group("Zupfen & Vibration")
## Marker, wo die Vibration standardmaessig zentriert ist, wenn pluck()
## OHNE expliziten Punkt aufgerufen wird (z.B. von einer externen Taste).
## Leer lassen = Mitte des aktuell vibrierenden Bereichs.
@export var pluck_point: Node2D
## Basis-Amplitude bei Spannung 0.
@export var vibration_amplitude: float = 10.0
## Wie SCHNELL die Vibration nach einem pluck() wieder abklingt (pro
## Sekunde). Groesser = schneller weg, kleiner = laenger sichtbar.
@export_range(0.1, 10.0, 0.1) var vibration_decay: float = 2.5
## Basis-Frequenz bei Spannung 0.
@export var vibration_frequency: float = 18.0

@export_group("Spannung / Tonhoehe")
@export var max_tension: int = 4
@export var start_tension: int = 0
@export var tension_animation_duration: float = 0.5
## Faktor, um wie viel die Vibrationsfrequenz PRO Spannungsstufe steigt.
@export var vibration_frequency_increase_per_tension: float = 0.5
## Faktor, um wie viel die Vibrationsamplitude PRO Spannungsstufe sinkt.
@export var vibration_amplitude_decrease_per_tension: float = 0.15
## Untere Grenze, wie stark die Amplitude maximal schrumpfen darf.
@export_range(0.0, 1.0, 0.01) var vibration_amplitude_min_factor: float = 0.3

@export_group("Stimmschluessel")
@export var tuning_peg_animation: String = "turn"
@export var tuning_peg_max_animation: String = "turn_stuck"

@export_group("Spieler-Durchquerung")
@export var player_pluck_enabled: bool = true
## Groesse der (unsichtbaren, nicht-blockierenden) PluckArea um die Saite
## herum - je hoeher die Fallgeschwindigkeit/World Scale, desto grosszuegiger.
@export var detection_margin: float = 40.0
## Zusaetzliche Toleranz ueber die Saitenenden hinaus (in t-Richtung).
@export var detection_edge_margin: float = 16.0

@export_group("Debug")
@export var debug_prints: bool = false

@onready var tuning_peg: AnimatedSprite2D = %TuningPeg
@onready var pluck_area: Area2D = %PluckArea
@onready var pluck_collision: CollisionPolygon2D = %PluckArea/CollisionPolygon2D

enum PendingAction { NONE, INCREASE, DECREASE, MAX_FEEDBACK }

var tension_level: int = 0
var _is_turning: bool = false
var _pending_action: PendingAction = PendingAction.NONE
var _active_anim_name: String = ""

var _pressed_point: int = -1
var _press_amount: float = 0.0
var _vibration_time: float = 0.0
var _vibration_strength: float = 0.0
var _vibration_center_t: float = 0.5

## Koerper, die aktuell in der PluckArea getrackt werden -> ihr zuletzt
## bekanntes Vorzeichen relativ zur Saite (welche Seite). Grundlage fuer
## die automatische Durchquerungs-Erkennung.
var _tracked_bodies_last_sign: Dictionary = {}

func _ready() -> void:
	# Ohne das hier zeichnet Line2D jede schraege Strecke treppig/pixelig.
	antialiased = true
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	tension_level = clampi(start_tension, 0, max_tension)
	if tuning_peg:
		tuning_peg.animation_finished.connect(_on_tuning_peg_animation_finished)
	if pluck_area:
		pluck_collision.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		pluck_area.body_entered.connect(_on_pluck_area_body_entered)
		pluck_area.body_exited.connect(_on_pluck_area_body_exited)
	if start_point and end_point:
		_update_points()
		_rebuild_pluck_collision()

func _process(delta: float) -> void:
	if not (start_point and end_point):
		return
	_vibration_time += delta
	_vibration_strength = max(_vibration_strength - vibration_decay * delta, 0.0)
	var has_target: bool = _pressed_point >= 0 and _pressed_point < press_points.size() and press_points[_pressed_point] != null
	var target_press: float = 1.0 if has_target else 0.0
	var press_amount_before: float = _press_amount
	_press_amount = move_toward(_press_amount, target_press, press_speed * delta)
	_update_points()
	# Press-Biegung aendert die STABILE Form der Saite - die
	# PluckArea-Kollision muss dann mitwandern (aehnlich wie
	# Spannungsaenderung bei MusicString/StringWall).
	if _press_amount != press_amount_before:
		_rebuild_pluck_collision()

## Setzt, welcher Druckpunkt (Index) die Saite gerade herunterdrueckt UND
## als Vibrationsgrenze gilt. -1 = keiner (ganze Saite vibriert frei).
func set_pressed_point(index: int) -> void:
	_pressed_point = index

## Loest eine abklingende Vibration aus, zentriert um impact_t (0..1
## entlang der Saite). Ohne Argument wird pluck_point genutzt, falls
## gesetzt, sonst die Mitte des aktuell vibrierenden Bereichs. Von aussen
## aufrufbar (Spieler-Durchquerung ODER ein externer Controller wie
## gopichand.gd bei Tastendruck E).
func pluck(impact_t: float = -1.0) -> void:
	_vibration_strength = 1.0
	if impact_t >= 0.0:
		_vibration_center_t = impact_t
	elif pluck_point:
		_vibration_center_t = _project_t(pluck_point)
	else:
		_vibration_center_t = 0.5
	if debug_prints:
		print("[", get_path(), "] pluck() -> center_t=", _vibration_center_t)

## Von einem TensionTrigger.gd aufgerufen, wenn der Spieler in der Zone die
## Anspann-Taste drueckt. Startet NUR die Dreh-Animation - die eigentliche
## Tonhoehen-Aenderung (Frequenz/Amplitude) passiert erst, wenn die
## Animation fertig durchgelaufen ist. Ist bereits max_tension erreicht,
## spielt stattdessen tuning_peg_max_animation ab (reines Feedback).
func request_tension_increase() -> bool:
	if not tuning_peg:
		return false
	if _is_turning:
		return false
	_is_turning = true
	if tension_level >= max_tension:
		_pending_action = PendingAction.MAX_FEEDBACK
		_active_anim_name = tuning_peg_max_animation
		tuning_peg.play(tuning_peg_max_animation)
	else:
		_pending_action = PendingAction.INCREASE
		_active_anim_name = tuning_peg_animation
		tuning_peg.play(tuning_peg_animation)
	return true

## Von einem TensionTrigger.gd aufgerufen, wenn der Spieler in der Zone die
## Lockern-Taste drueckt. Spielt die Dreh-Animation RUECKWAERTS ab. Bei
## Spannung 0 passiert nichts (gibt false zurueck).
func request_tension_decrease() -> bool:
	if not tuning_peg:
		return false
	if _is_turning:
		return false
	if tension_level <= 0:
		return false
	_is_turning = true
	_pending_action = PendingAction.DECREASE
	_active_anim_name = tuning_peg_animation
	tuning_peg.play_backwards(tuning_peg_animation)
	return true

func _on_tuning_peg_animation_finished() -> void:
	if tuning_peg.animation != _active_anim_name:
		return
	_is_turning = false
	var action: PendingAction = _pending_action
	_pending_action = PendingAction.NONE
	if action == PendingAction.INCREASE:
		tension_level = clampi(tension_level + 1, 0, max_tension)
		tension_changed.emit(tension_level)
	elif action == PendingAction.DECREASE:
		tension_level = clampi(tension_level - 1, 0, max_tension)
		tension_changed.emit(tension_level)
	# MAX_FEEDBACK: keine Aenderung, war nur Optik.

## Effektive Vibrationsfrequenz fuer die aktuelle Spannungsstufe - steigt
## mit hoeherer Spannung (hoeherer Ton).
func _effective_vibration_frequency() -> float:
	return vibration_frequency * (1.0 + float(tension_level) * vibration_frequency_increase_per_tension)

## Effektive Vibrationsamplitude fuer die aktuelle Spannungsstufe - sinkt
## mit hoeherer Spannung.
func _effective_vibration_amplitude() -> float:
	var factor: float = max(1.0 - float(tension_level) * vibration_amplitude_decrease_per_tension, vibration_amplitude_min_factor)
	return vibration_amplitude * factor

## Projiziert einen beliebigen Node2D auf die Saitenlinie (0..1, entlang
## der GERADEN start_point->end_point-Linie, unabhaengig von Press-Biegung).
func _project_t(node: Node2D) -> float:
	if not node or not (start_point and end_point):
		return -1.0
	var from: Vector2 = start_point.global_position
	var to: Vector2 = end_point.global_position
	var dir: Vector2 = to - from
	var length: float = dir.length()
	if length <= 0.0:
		return -1.0
	return clamp((node.global_position - from).dot(dir / length) / length, 0.0, 1.0)

## STABILER Punkt auf der Saite bei t (0..1) - reine Press-Biegung, OHNE
## Vibration. Das ist die "physische Wahrheit" fuer die
## Durchquerungs-Erkennung UND die PluckArea-Kollision.
func _stable_point_global(t: float, press_t: float, has_press: bool) -> Vector2:
	var from: Vector2 = start_point.global_position
	var to: Vector2 = end_point.global_position
	var dir: Vector2 = to - from
	var length: float = dir.length()
	if length <= 0.0:
		return from
	var dir_norm: Vector2 = dir / length
	var normal: Vector2 = dir_norm.orthogonal()
	var base: Vector2 = from.lerp(to, t)
	if has_press and _press_amount > 0.0:
		var press_weight: float = _press_weight(t, press_t)
		base += normal * press_depth * press_weight * _press_amount
	return base

## Lokale Normale AN EINEM BESTIMMTEN Punkt t der stabilen (press-gebogenen)
## Saite, per finiter Differenz bestimmt - fuer die Seiten-Erkennung bei der
## Spieler-Durchquerung.
func _local_normal(t: float, press_t: float, has_press: bool) -> Vector2:
	var eps: float = 0.01
	var t0: float = clamp(t - eps, 0.0, 1.0)
	var t1: float = clamp(t + eps, 0.0, 1.0)
	var from: Vector2 = start_point.global_position
	var to: Vector2 = end_point.global_position
	var dir: Vector2 = to - from
	var length: float = dir.length()
	if length <= 0.0 or t0 == t1:
		return dir.orthogonal().normalized() if length > 0.0 else Vector2.DOWN
	var tangent: Vector2 = _stable_point_global(t1, press_t, has_press) - _stable_point_global(t0, press_t, has_press)
	if tangent.length() <= 0.0001:
		return (dir / length).orthogonal()
	return tangent.normalized().orthogonal()

func _press_weight(t: float, press_t: float) -> float:
	if press_t <= 0.0:
		return 1.0 - smoothstep(0.0, 1.0, t)
	elif press_t >= 1.0:
		return smoothstep(0.0, 1.0, t)
	elif t <= press_t:
		return smoothstep(0.0, 1.0, t / press_t)
	else:
		return smoothstep(0.0, 1.0, 1.0 - (t - press_t) / (1.0 - press_t))

## Prueft jeden Physik-Frame ALLE aktuell in der PluckArea getrackten
## Koerper darauf, ob sie die Saite (stabile, press-gebogene Form) von
## einer Seite zur anderen durchquert haben - loest dann automatisch
## pluck() an der Durchquerungsstelle aus.
func _physics_process(_delta: float) -> void:
	if not player_pluck_enabled or not (start_point and end_point):
		return
	var press_target: Node2D = null
	if _pressed_point >= 0 and _pressed_point < press_points.size():
		press_target = press_points[_pressed_point]
	var press_t: float = _project_t(press_target) if press_target else 0.0
	var has_press: bool = press_target != null

	for body in _tracked_bodies_last_sign.keys():
		if not is_instance_valid(body):
			_tracked_bodies_last_sign.erase(body)
			continue
		_check_crossing(body, press_t, has_press)

func _check_crossing(body: Node2D, press_t: float, has_press: bool) -> void:
	var raw_t: float = _project_t_unclamped(body.global_position)
	var margin_t: float = _edge_margin_t()
	if raw_t < -margin_t or raw_t > 1.0 + margin_t:
		return
	var t: float = clamp(raw_t, 0.0, 1.0)
	var stable_pos: Vector2 = _stable_point_global(t, press_t, has_press)
	var normal: Vector2 = _local_normal(t, press_t, has_press)
	var signed_dist: float = (body.global_position - stable_pos).dot(normal)
	var sign_now: float = 1.0 if signed_dist >= 0.0 else -1.0

	var sign_before: float = _tracked_bodies_last_sign.get(body, sign_now)
	_tracked_bodies_last_sign[body] = sign_now

	if sign_before != sign_now:
		pluck(t)

func _project_t_unclamped(global_pos: Vector2) -> float:
	var from: Vector2 = start_point.global_position
	var to: Vector2 = end_point.global_position
	var dir: Vector2 = to - from
	var length: float = dir.length()
	if length <= 0.0:
		return 0.5
	return (global_pos - from).dot(dir / length) / length

func _edge_margin_t() -> float:
	var length: float = (end_point.global_position - start_point.global_position).length()
	return (detection_edge_margin / length) if length > 0.0 else 0.0

func _on_pluck_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var press_target: Node2D = null
	if _pressed_point >= 0 and _pressed_point < press_points.size():
		press_target = press_points[_pressed_point]
	var press_t: float = _project_t(press_target) if press_target else 0.0
	var t: float = clamp(_project_t_unclamped(body.global_position), 0.0, 1.0)
	var stable_pos: Vector2 = _stable_point_global(t, press_t, press_target != null)
	var normal: Vector2 = _local_normal(t, press_t, press_target != null)
	var signed_dist: float = (body.global_position - stable_pos).dot(normal)
	_tracked_bodies_last_sign[body] = 1.0 if signed_dist >= 0.0 else -1.0

func _on_pluck_area_body_exited(body: Node2D) -> void:
	_tracked_bodies_last_sign.erase(body)

## Baut die PluckArea-Kollision (grosszuegige Trigger-Zone) entlang der
## aktuellen STABILEN (press-gebogenen, nicht-vibrierenden) Saitenform neu.
## Wird nur bei Press-Aenderung aufgerufen, NICHT jeden Vibrations-Frame -
## verhindert unnoetiges Neu-Backen der Collision Shape.
func _rebuild_pluck_collision() -> void:
	if not pluck_area:
		return
	var press_target: Node2D = null
	if _pressed_point >= 0 and _pressed_point < press_points.size():
		press_target = press_points[_pressed_point]
	var press_t: float = _project_t(press_target) if press_target else 0.0
	var has_press: bool = press_target != null

	var top_points: Array[Vector2] = []
	var bottom_points: Array[Vector2] = []
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var p: Vector2 = _stable_point_global(t, press_t, has_press)
		var normal: Vector2 = _local_normal(t, press_t, has_press)
		top_points.append(pluck_collision.to_local(p - normal * detection_margin))
		bottom_points.append(pluck_collision.to_local(p + normal * detection_margin))
	var bottom_reversed: Array[Vector2] = bottom_points.duplicate()
	bottom_reversed.reverse()
	pluck_collision.polygon = PackedVector2Array(top_points + bottom_reversed)

func _update_points() -> void:
	var from: Vector2 = start_point.global_position
	var to: Vector2 = end_point.global_position
	var dir: Vector2 = to - from
	var length: float = dir.length()
	if length <= 0.0:
		return
	var dir_norm: Vector2 = dir / length
	var normal: Vector2 = dir_norm.orthogonal()

	var press_target: Node2D = null
	if _pressed_point >= 0 and _pressed_point < press_points.size():
		press_target = press_points[_pressed_point]
	var press_t: float = 0.0
	if press_target:
		press_t = clamp((press_target.global_position - from).dot(dir_norm) / length, 0.0, 1.0)

	# Vibrierender Bereich: start_point (t=0) bis zum aktiven Druckpunkt.
	# Ohne aktiven Druckpunkt vibriert die ganze Saite. _press_amount sorgt
	# fuer einen weichen Uebergang statt einem harten Umschalten.
	var vib_start_t: float = 0.0
	var vib_end_t: float = 1.0
	if press_target:
		vib_end_t = lerp(1.0, press_t, _press_amount)
	vib_end_t = clamp(vib_end_t, vib_start_t + 0.02, 1.0)

	var effective_pluck_t: float = clamp(_vibration_center_t, vib_start_t + 0.001, vib_end_t - 0.001)
	var effective_amplitude: float = _effective_vibration_amplitude()
	var effective_frequency: float = _effective_vibration_frequency()

	var new_points: PackedVector2Array = PackedVector2Array()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var base: Vector2 = from.lerp(to, t)
		var local_point: Vector2 = to_local(base)
		if press_target and _press_amount > 0.0:
			local_point += normal * press_depth * _press_weight(t, press_t) * _press_amount
		if t >= vib_start_t and t <= vib_end_t:
			var edge_fade: float
			if t <= effective_pluck_t:
				var denom_left: float = effective_pluck_t - vib_start_t
				edge_fade = sin(((t - vib_start_t) / denom_left) * (PI * 0.5)) if denom_left > 0.0001 else 1.0
			else:
				var denom_right: float = vib_end_t - effective_pluck_t
				edge_fade = sin(((vib_end_t - t) / denom_right) * (PI * 0.5)) if denom_right > 0.0001 else 0.0
			var wave: float = sin(t * 20.0 + _vibration_time * effective_frequency)
			local_point += normal * wave * edge_fade * effective_amplitude * _vibration_strength
		new_points.append(local_point)
	points = new_points
