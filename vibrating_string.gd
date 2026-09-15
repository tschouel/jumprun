class_name VibratingString
extends Node2D

## Saite, die im Songtempo von selbst zu vibrieren anfaengt - kein
## Bogen-Kontakt noetig. bpm + note_value bestimmen den gemeinsamen Takt, in
## dem JEDER Punkt angeschlagen wird (gleiche Rechnung wie bei
## RhythmicMover):
##
##   takt_sekunden = notenwert_bruchteil * 4.0 * (60.0 / bpm)
##
## string_points ist ein Array aus StringPulsePoint-Nodes (ein eigener
## Marker2D-Typ, siehe string_pulse_point.gd) statt normalen Node2D - jeder
## davon hat neben seiner Position (wie ein gewoehnlicher Marker2D) sein
## EIGENES Delay (delay_note_value + delay_count), nicht in Sekunden,
## sondern als Anzahl Notenwerte im obigen Takt (z.B. delay_count=1 bei
## "Achtel" = eine Achtelnote Verzoegerung fuer genau diesen Punkt). So kann
## jeder Vibrations-Punkt auf seinen eigenen Bogen-Treffer syncen, auch wenn
## mehrere Boegen zu unterschiedlichen Zeiten dieselbe Saite treffen. Nach
## dem ersten (verzoegerten) Anschlag wiederholt sich jeder Punkt weiter im
## gemeinsamen _note_duration()-Takt.
##
## WICHTIG: line behaelt immer seine volle, von dir im Editor gezeichnete
## Form/Laenge - string_points ersetzen NICHT die Linienpunkte, sondern
## legen nur fest, AN WELCHEN STELLEN die Linie ausbeult ("Vibrations-
## Zentren"). Um jeden Marker herum schwingen die echten Linienpunkte
## senkrecht (vibration_direction) mit, die Staerke faellt mit dem Abstand
## zum Marker ab (vibration_influence_radius) und klingt zeitlich exponentiell
## ab (vibration_damping). Punkte weit weg von jedem Marker bleiben
## praktisch unbewegt. Schwingen mehrere Punkte gleichzeitig, addieren sich
## ihre Ausschlaege.
##
## Setup: line (Line2D) muss seine endgueltige Form/Laenge schon im Editor
## haben. Pro Vibrations-Stelle einen StringPulsePoint-Node als Kind
## anlegen (verhaelt sich wie ein Marker2D - im "Neuer Node hinzufuegen"-
## Dialog nach "StringPulsePoint" suchen), positionieren, im Inspector das
## Delay dieses Punkts einstellen, dann wie gewohnt in string_points ziehen.
##
## line_resolution: hat deine Linie im Editor nur 2 Punkte (Anfang/Ende,
## wie eine einfache gerade Saite), gibt es dazwischen keine echten
## Linienpunkte, die ausbeulen koennten - die Vibration waere unsichtbar.
## line_resolution > 0 tastet die Original-Form deshalb automatisch in so
## vielen gleichmaessig verteilten Punkten neu ab (Form/Laenge bleibt
## dabei exakt erhalten), damit ueberall genug Punkte zum Ausbeulen da sind.
## 0 = Original-Punkte unveraendert lassen (nur sinnvoll, wenn deine Linie
## schon von sich aus viele Punkte hat).

const NOTE_FRACTIONS: Array[float] = [1.0, 0.5, 0.25, 0.125, 0.0625]  # Ganze, Halbe, Viertel, Achtel, Sechzehntel

@export_group("Saiten-Punkte")
@export var line: Line2D
@export var string_points: Array[StringPulsePoint] = []
@export var vibration_influence_radius: float = 250.0
@export var line_resolution: int = 40

@export_group("Musik-Timing")
@export var bpm: float = 100.0
@export_enum("Ganze", "Halbe", "Viertel", "Achtel", "Sechzehntel") var note_value: int = 2
@export var autostart: bool = true

@export_group("Vibration")
@export var vibration_direction: Vector2 = Vector2.UP
@export var vibration_amplitude: float = 12.0
@export var vibration_frequency: float = 6.0
@export var vibration_damping: float = 3.0
@export var vibration_stop_threshold: float = 0.5

signal plucked(point_index: int)

var _rest_points_local: PackedVector2Array = PackedVector2Array()
var _point_weights: Array[PackedFloat32Array] = []  # pro string_points-Eintrag: 0..1 Vibrationsstaerke je Linienpunkt
var _point_vibrating: Array[bool] = []
var _point_time_since_hit: Array[float] = []
var _point_timers: Array[Timer] = []
var _running: bool = false

func _ready() -> void:
	for i in range(string_points.size()):
		var t: Timer = Timer.new()
		t.one_shot = true
		add_child(t)
		t.timeout.connect(_on_point_timer_timeout.bind(i))
		_point_timers.append(t)
		_point_vibrating.append(false)
		_point_time_since_hit.append(0.0)

	# deferred, damit string_points ihre globale Transform garantiert schon
	# gesetzt haben, egal in welcher Reihenfolge die Nodes im Baum ready()
	# durchlaufen
	call_deferred("_initialize_shape")

	if autostart:
		start()

func _initialize_shape() -> void:
	rebuild_rest_shape()
	_rebuild_line_visual()

## Startet (bzw. neu-startet) den Anschlag-Takt fuer alle Punkte - jeder
## Punkt bekommt seinen ersten Anschlag nach seinem eigenen
## _delay_seconds_for_point(), danach geht's fuer alle im gemeinsamen
## _note_duration()-Takt weiter.
func start() -> void:
	_running = true
	for i in range(_point_timers.size()):
		_point_timers[i].stop()
		_point_timers[i].start(maxf(_delay_seconds_for_point(i), 0.0))

## Stoppt den Anschlag-Takt aller Punkte (laufende Vibration klingt noch
## normal aus).
func stop() -> void:
	_running = false
	for t in _point_timers:
		t.stop()

func _on_point_timer_timeout(index: int) -> void:
	_pluck_point(index)
	if _running:
		_point_timers[index].start(_note_duration())

func _process(delta: float) -> void:
	var any_vibrating: bool = false
	for i in range(_point_vibrating.size()):
		if not _point_vibrating[i]:
			continue
		_point_time_since_hit[i] += delta
		var envelope: float = vibration_amplitude * exp(-vibration_damping * _point_time_since_hit[i])
		if envelope < vibration_stop_threshold:
			_point_vibrating[i] = false
		else:
			any_vibrating = true

	# auch noch einmal neu zeichnen, wenn gerade der letzte Punkt zur Ruhe
	# gekommen ist, damit die Saite sauber in die Ruheform zurueckkehrt
	if any_vibrating or _rest_points_local.size() > 0:
		_rebuild_line_visual()

## Oeffentlich aufrufbar, falls die Saite auch unabhaengig vom eigenen Takt
## angeregt werden soll (z.B. von aussen per Signal getriggert). Ohne Index
## werden alle Punkte sofort angeschlagen, mit index nur der eine (0-basiert,
## Reihenfolge wie im string_points-Array).
func pluck(index: int = -1) -> void:
	if index < 0:
		for i in range(string_points.size()):
			_pluck_point(i)
	else:
		_pluck_point(index)

func _pluck_point(index: int) -> void:
	if index < 0 or index >= _point_vibrating.size():
		return
	_point_vibrating[index] = true
	_point_time_since_hit[index] = 0.0
	plucked.emit(index)

## Uebernimmt die volle Linienform von line.points als Ruheform (unveraendert
## - line behaelt seine Laenge) und berechnet je string_points-Eintrag, wie
## stark jeder Linienpunkt durch DIESEN Marker vibrieren soll: 1.0 direkt am
## Marker, faellt mit dem Abstand dazu ab (vibration_influence_radius), 0
## weit weg. Automatisch beim Start aufgerufen - oeffentlich, falls sich
## string_points/line-Form zur Laufzeit aendern sollten.
func rebuild_rest_shape() -> void:
	_rest_points_local.clear()
	_point_weights.clear()
	if not line:
		return

	if line_resolution > 1:
		_rest_points_local = _resample_polyline(line.points, line_resolution)
	else:
		_rest_points_local = line.points.duplicate()

	var radius: float = maxf(vibration_influence_radius, 0.001)
	for cfg in string_points:
		var weights: PackedFloat32Array = PackedFloat32Array()
		if cfg:
			var marker_local: Vector2 = line.to_local(cfg.global_position)
			for base in _rest_points_local:
				var dist: float = base.distance_to(marker_local)
				weights.append(exp(-pow(dist / radius, 2.0)))
		else:
			for i in range(_rest_points_local.size()):
				weights.append(0.0)
		_point_weights.append(weights)

## Zeichnet die Saite neu - im Ruhezustand einfach die Rest-Form (volle
## Original-Laenge). Fuer jeden gerade vibrierenden Punkt wird sein eigener
## Ausschlag (Envelope + Oszillation, gewichtet mit seiner _point_weights)
## draufaddiert - schwingen mehrere Punkte gleichzeitig, ueberlagern sich
## ihre Ausschlaege.
func _rebuild_line_visual() -> void:
	if not line or _rest_points_local.is_empty():
		return

	var points: PackedVector2Array = _rest_points_local.duplicate()
	var dir: Vector2 = vibration_direction.normalized()

	for i in range(_point_vibrating.size()):
		if not _point_vibrating[i]:
			continue
		var t: float = _point_time_since_hit[i]
		var envelope: float = vibration_amplitude * exp(-vibration_damping * t)
		var oscillation: float = cos(TAU * vibration_frequency * t)
		var weights: PackedFloat32Array = _point_weights[i]
		for p in range(points.size()):
			points[p] += dir * envelope * weights[p] * oscillation

	line.points = points

func _note_duration() -> float:
	var fraction: float = NOTE_FRACTIONS[note_value]
	return fraction * 4.0 * (60.0 / bpm)

## Verzoegerung bis zum ersten Anschlag dieses einen Punkts in Sekunden,
## berechnet aus dessen delay_count Notenwerten à delay_note_value im
## gemeinsamen bpm-Tempo (0 = kein Delay fuer diesen Punkt).
func _delay_seconds_for_point(index: int) -> float:
	var cfg: StringPulsePoint = string_points[index]
	if not cfg:
		return 0.0
	var fraction: float = NOTE_FRACTIONS[cfg.delay_note_value]
	return float(cfg.delay_count) * fraction * 4.0 * (60.0 / bpm)

## Tastet eine Polyline (pts) in n gleichmaessig entlang ihrer Bogenlaenge
## verteilten Punkten neu ab - Form und Gesamtlaenge bleiben dabei exakt
## erhalten, es gibt nur mehr (oder weniger) Punkte dazwischen.
func _resample_polyline(pts: PackedVector2Array, n: int) -> PackedVector2Array:
	if pts.size() < 2:
		return pts.duplicate()

	var seg_lengths: PackedFloat32Array = PackedFloat32Array()
	var total: float = 0.0
	for i in range(pts.size() - 1):
		var seg_len: float = pts[i].distance_to(pts[i + 1])
		seg_lengths.append(seg_len)
		total += seg_len

	if total <= 0.0:
		return pts.duplicate()

	var result: PackedVector2Array = PackedVector2Array()
	var seg_index: int = 0
	var seg_start_len: float = 0.0
	for i in range(n):
		var target: float = total * (float(i) / float(n - 1))
		while seg_index < seg_lengths.size() - 1 and seg_start_len + seg_lengths[seg_index] < target:
			seg_start_len += seg_lengths[seg_index]
			seg_index += 1
		var seg_len: float = maxf(seg_lengths[seg_index], 0.0001)
		var t_local: float = clampf((target - seg_start_len) / seg_len, 0.0, 1.0)
		result.append(pts[seg_index].lerp(pts[seg_index + 1], t_local))

	return result
