class_name VibratingString
extends Node2D

## Saite, die im Songtempo von selbst zu vibrieren anfaengt - kein
## Bogen-Kontakt noetig.
##
## STATES-SEQUENZ (neu) - GENAU GLEICH AUFGEBAUT wie BowRotator (siehe
## bow_rotator.gd): states ist eine Liste beliebig vieler
## VibratingStringState-Eintraege (siehe vibrating_string_state.gd), jeder
## mit eigener Dauer (Takte + Notenwert), eigenem Anschlag-Rhythmus
## (repeat_note_value/repeat_note_count) UND eigenem repeat_predelay
## (Verschiebung des Ausloese-Zeitpunkts, siehe vibrating_string_state.gd)
## fuer genau diesen Abschnitt. Sie spielen strikt nacheinander ab, und nach
## dem letzten Eintrag geht's
## (falls loop = true) wieder von vorne los - dadurch laesst sich der
## Anschlag-Rhythmus im Verlauf des Songs veraendern, z.B. "2 Takte lang
## jede Viertel anschlagen, dann 4 Takte lang KOMPLETTE PAUSE
## (repeat_note_count = 0, siehe vibrating_string_state.gd), dann wieder von
## vorne". Ersetzt das fruehere einzelne, global fixe note_value-Feld.
##
## bpm gilt gemeinsam fuer ALLE states (und fuer die Start-Verzoegerung
## delay_note_value/delay_count) - genau wie bei BowRotator/RhythmicMover.
##
## string_points ist ein Array aus StringPulsePoint-Nodes (ein eigener
## Marker2D-Typ, siehe string_pulse_point.gd) statt normalen Node2D - jeder
## davon hat neben seiner Position (wie ein gewoehnlicher Marker2D) sein
## EIGENES Delay (delay_note_value + delay_count), nicht in Sekunden,
## sondern als Anzahl Notenwerte im bpm-Takt. Dieses Delay wirkt sich NUR
## auf den allerersten states-Eintrag (Index 0, auch bei jedem erneuten
## Loop-Durchlauf) aus - dort sorgt es weiterhin fuer den zeitlichen
## Versatz zwischen den Punkten (z.B. falls mehrere Boegen zu
## unterschiedlichen Zeiten dieselbe Saite treffen). In allen spaeteren
## states schlagen alle string_points synchron zusammen an, jeweils ab dem
## exakten Start dieses states.
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
## Danach states im Inspector befuellen (auf die "+"-Schaltflaeche klicken,
## fuer jeden Abschnitt einen neuen VibratingStringState anlegen und dessen
## Werte setzen - siehe vibrating_string_state.gd fuer die Details jedes
## Feldes).
##
## line_resolution: hat deine Linie im Editor nur 2 Punkte (Anfang/Ende,
## wie eine einfache gerade Saite), gibt es dazwischen keine echten
## Linienpunkte, die ausbeulen koennten - die Vibration waere unsichtbar.
## line_resolution > 0 tastet die Original-Form deshalb automatisch in so
## vielen gleichmaessig verteilten Punkten neu ab (Form/Laenge bleibt
## dabei exakt erhalten), damit ueberall genug Punkte zum Ausbeulen da sind.
## 0 = Original-Punkte unveraendert lassen (nur sinnvoll, wenn deine Linie
## schon von sich aus viele Punkte hat).
##
## EINFLUG: Genau wie bei RhythmicMover/BowRotator kann auch die ganze
## Saite erst von einem Startpunkt zu ihrer im Editor gesetzten Position
## reinfliegen, BEVOR die states-Sequenz beginnt - start_tuning() macht
## beides nacheinander. Startpunkt: entweder flight_start_point (ein
## beliebiger Node2D, z.B. Marker2D, irgendwo ausserhalb des sichtbaren
## Bereichs platziert - GLOBALE Position, wird automatisch in lokale
## Koordinaten umgerechnet) ODER move_from_offset (relativ zur Editor-
## Position, falls kein flight_start_point gesetzt ist). fly_in_note_value +
## fly_in_count bestimmen die Einflugdauer GENAUSO wie delay_note_value/
## delay_count - als Anzahl Notenwerte im gemeinsamen bpm-Tempo, nicht in
## Sekunden (fly_in_count = 0, Standard, => kein Einflug: die Saite springt
## sofort auf ihre Position und startet direkt die states-Sequenz). Da line
## und alle string_points als Kinder beim Reinfliegen mitwandern, bleibt
## ihre Form/Anordnung zueinander die ganze Zeit exakt erhalten - es bewegt
## sich die komplette Saite als Ganzes.
##
## autostart loest jetzt start_tuning() aus (Einflug + states-Sequenz), nicht
## mehr nur die Sequenz direkt, und ist wie beim Bogen standardmaessig AUS -
## gedacht fuer den Einsatz als level_build_target/success_target (z.B. beim
## Gopichand), wo etwas anderes start_tuning() erst nach erfolgreichem
## Abschluss aufruft. Soll eine Saite wirklich ganz von alleine beim Laden
## der Szene lospielen (ohne Erfolgs-Trigger), einfach im Inspector unter
## "Musik-Timing" Autostart wieder anhaken.

const NOTE_FRACTIONS: Array[float] = [1.0, 0.5, 0.25, 0.125, 0.0625]  # Ganze, Halbe, Viertel, Achtel, Sechzehntel

@export_group("Saiten-Punkte")
@export var line: Line2D
@export var string_points: Array[StringPulsePoint] = []
@export var vibration_influence_radius: float = 250.0
@export var line_resolution: int = 40

@export var states: Array[VibratingStringState] = []
## Nach dem letzten Eintrag in states wieder von vorne beginnen (true,
## Standard) oder nach einmaligem Durchlauf beim letzten state stehen
## bleiben (false).
@export var loop: bool = true

@export_group("Musik-Timing")
@export var bpm: float = 100.0
@export_enum("Ganze", "Halbe", "Viertel", "Achtel", "Sechzehntel") var delay_note_value: int = 2
@export var delay_count: int = 0
@export var autostart: bool = false

@export_group("Vibration")
@export var vibration_direction: Vector2 = Vector2.UP
@export var vibration_amplitude: float = 12.0
@export var vibration_frequency: float = 6.0
@export var vibration_damping: float = 3.0
@export var vibration_stop_threshold: float = 0.5

@export_group("Einflug")
## Startposition relativ zur im Editor gesetzten Position - wird IGNORIERT,
## falls flight_start_point gesetzt ist.
@export var move_from_offset: Vector2 = Vector2.ZERO
## Optional: beliebiger Node2D (z.B. Marker2D), dessen GLOBALE Position als
## Einflug-Startpunkt verwendet wird, statt move_from_offset.
@export var flight_start_point: Node2D
@export_enum("Ganze", "Halbe", "Viertel", "Achtel", "Sechzehntel") var fly_in_note_value: int = 2
## Anzahl Notenwerte (siehe fly_in_note_value) fuer die Einflugdauer. 0 =
## kein Einflug (Standard) - die Saite steht direkt an ihrer Editor-Position
## und beginnt sofort mit der states-Sequenz.
@export var fly_in_count: int = 0
@export var fly_in_transition_type: Tween.TransitionType = Tween.TRANS_SINE
@export var fly_in_ease_type: Tween.EaseType = Tween.EASE_IN_OUT

signal plucked(point_index: int)
signal flight_finished

var _rest_points_local: PackedVector2Array = PackedVector2Array()
var _point_weights: Array[PackedFloat32Array] = []  # pro string_points-Eintrag: 0..1 Vibrationsstaerke je Linienpunkt
var _point_vibrating: Array[bool] = []
var _point_time_since_hit: Array[float] = []
var _point_next_pluck_time: Array[float] = []  # Zeit (Sekunden seit Beginn des GERADE laufenden state), zu der Punkt i als naechstes angeschlagen wird - < 0.0 = kein weiterer Anschlag mehr in diesem Abschnitt geplant.
var _home_position: Vector2
var _fly_tween: Tween
var _flying_in: bool = false

var _segment_elapsed: float = 0.0
var _state_index: int = 0
var _running: bool = false
var _timer: Timer

func _ready() -> void:
	_home_position = position
	position = _fly_in_start_position()

	for i in range(string_points.size()):
		_point_vibrating.append(false)
		_point_time_since_hit.append(0.0)

	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_begin_sequence)

	# deferred, damit string_points ihre globale Transform garantiert schon
	# gesetzt haben, egal in welcher Reihenfolge die Nodes im Baum ready()
	# durchlaufen
	call_deferred("_initialize_shape")

	if autostart:
		start_tuning()

func _initialize_shape() -> void:
	rebuild_rest_shape()
	_rebuild_line_visual()

## Ermittelt den Einflug-Startpunkt: flight_start_point (in lokale
## Koordinaten umgerechnet), falls gesetzt - sonst _home_position +
## move_from_offset.
func _fly_in_start_position() -> Vector2:
	if flight_start_point:
		var parent2d := get_parent() as Node2D
		if parent2d:
			return parent2d.to_local(flight_start_point.global_position)
		return flight_start_point.global_position
	return _home_position + move_from_offset

## Wird von aussen aufgerufen (z.B. tuner_butterfly_sequence_controller.gd
## als level_build_target/butterflies-Eintrag, oder call_and_response.gd
## als success_target/final_target). Laesst die Saite - falls fly_in_count >
## 0 - erst zur Editor-Position reinfliegen und startet danach automatisch
## die states-Sequenz (start()). Bei fly_in_count = 0 identisch zu einem
## direkten start()-Aufruf.
func start_tuning() -> void:
	if _flying_in:
		return

	if fly_in_count <= 0:
		position = _home_position
		start()
		return

	_flying_in = true
	if _fly_tween:
		_fly_tween.kill()
	position = _fly_in_start_position()

	_fly_tween = create_tween()
	_fly_tween.tween_property(self, "position", _home_position, _fly_in_duration()).set_trans(fly_in_transition_type).set_ease(fly_in_ease_type)
	_fly_tween.tween_callback(_on_flight_finished)

func _on_flight_finished() -> void:
	_flying_in = false
	flight_finished.emit()
	start()

## Startet (bzw. neu-startet) die states-Sequenz ab dem ersten Eintrag -
## falls delay_count > 0 gesetzt ist, erst nach _delay_seconds()
## Verzoegerung. Loest KEINEN Einflug aus (siehe start_tuning() dafuer) -
## geht davon aus, dass die Saite schon an ihrer gewuenschten Position
## steht.
func start() -> void:
	_running = false
	_timer.stop()

	var delay_seconds: float = _delay_seconds()
	if delay_seconds > 0.0:
		_timer.start(delay_seconds)
	else:
		_begin_sequence()

func _begin_sequence() -> void:
	_state_index = 0
	_begin_current_state()

## Setzt die verstrichene Zeit fuer den gerade beginnenden state zurueck und
## plant fuer jeden string_point den naechsten Anschlag: im allerersten
## state (Index 0) mit dessen eigenem delay_note_value/delay_count-Versatz
## (siehe Klassenkommentar), in jedem spaeteren state synchron ab t=0.
func _begin_current_state() -> void:
	_segment_elapsed = 0.0
	_running = states.size() > 0

	_point_next_pluck_time.clear()
	if not _running:
		return
	var state: VibratingStringState = states[_state_index]
	var duration: float = _state_duration(state)
	if state.repeat_note_count <= 0:
		# Reine Pause - in diesem Abschnitt wird ueberhaupt nicht angeschlagen
		# (siehe vibrating_string_state.gd).
		for i in range(string_points.size()):
			_point_next_pluck_time.append(-1.0)
		return
	for i in range(string_points.size()):
		var offset: float = _delay_seconds_for_point(i) if _state_index == 0 else 0.0
		_point_next_pluck_time.append(offset if offset <= duration else -1.0)

func _process(delta: float) -> void:
	_advance_vibration_envelopes(delta)
	_advance_states(delta)

## Laesst bereits angeschlagene Punkte ausklingen (Envelope-Decay) und
## zeichnet die Saite bei Bedarf neu - unveraendert gegenueber vorher, nur
## aus _process() ausgelagert.
func _advance_vibration_envelopes(delta: float) -> void:
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

## Treibt die states-Sequenz voran: schlaegt faellige string_points an
## (siehe vibrating_string_state.gd fuer repeat_note_value/
## repeat_note_count) und wechselt automatisch zum naechsten state, sobald
## dessen Dauer abgelaufen ist - kein Tween, keine Godot-Timer pro Punkt
## (genau wie BowRotator bewusst OHNE Tween arbeitet).
func _advance_states(delta: float) -> void:
	if not _running or states.is_empty():
		return
	var state: VibratingStringState = states[_state_index]
	var duration: float = _state_duration(state)
	var cycle: float = _repeat_cycle_duration(state)

	_segment_elapsed += delta

	if duration > 0.0:
		for i in range(_point_next_pluck_time.size()):
			var next_time: float = _point_next_pluck_time[i]
			if next_time < 0.0:
				continue
			var trigger_time: float = next_time + state.repeat_predelay
			if _segment_elapsed >= trigger_time and next_time <= duration:
				_pluck_point(i)
				if cycle > 0.0:
					var following: float = next_time + cycle
					_point_next_pluck_time[i] = following if following <= duration else -1.0
				else:
					_point_next_pluck_time[i] = -1.0

	if duration <= 0.0 or _segment_elapsed >= duration:
		_advance_to_next_state()

## Springt zum naechsten state in der Sequenz - am Ende (falls loop =
## false) bleibt einfach der letzte state aktiv/stehen (ohne weitere
## Anschlaege, da dessen Zeitplan schon abgearbeitet ist).
func _advance_to_next_state() -> void:
	_state_index += 1
	if _state_index >= states.size():
		if loop:
			_state_index = 0
		else:
			_state_index = states.size() - 1
			_running = false
			return
	_begin_current_state()

## Stoppt die states-Sequenz (auch einen noch laufenden Delay ODER einen
## noch laufenden Einflug), laesst laufende Vibration normal ausklingen und
## faehrt zurueck auf die Ausgangsposition.
func stop() -> void:
	_timer.stop()
	_running = false
	_point_next_pluck_time.clear()
	if _fly_tween:
		_fly_tween.kill()
	_flying_in = false
	position = _home_position

## Aendert das Tempo zur Laufzeit (z.B. per FMOD-Tempo-Marker) und startet
## die Sequenz neu - gleiches Verhalten wie BowRotator.set_bpm()/
## RhythmicMover.set_bpm().
func set_bpm(new_bpm: float) -> void:
	bpm = new_bpm
	if _running:
		start()

## Oeffentlich aufrufbar, falls die Saite auch unabhaengig vom eigenen
## states-Zeitplan angeregt werden soll (z.B. von aussen per Signal
## getriggert). Ohne Index werden alle Punkte sofort angeschlagen, mit
## index nur der eine (0-basiert, Reihenfolge wie im string_points-Array).
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

## Dauer eines einzelnen state in Sekunden, aus bars (volle Takte im 4/4)
## + note_count Notenwerten à note_value, im gemeinsamen bpm-Tempo.
func _state_duration(state: VibratingStringState) -> float:
	var bar_seconds: float = 4.0 * (60.0 / bpm)
	var note_fraction: float = NOTE_FRACTIONS[state.note_value]
	return float(state.bars) * bar_seconds + float(state.note_count) * note_fraction * bar_seconds

## Dauer EINES Anschlag-Zyklus in Sekunden (repeat_note_count Notenwerte à
## repeat_note_value) - 0.0, falls repeat_note_count <= 0 ist (= reine
## Pause, siehe vibrating_string_state.gd und _begin_current_state()).
func _repeat_cycle_duration(state: VibratingStringState) -> float:
	if state.repeat_note_count <= 0:
		return 0.0
	var note_fraction: float = NOTE_FRACTIONS[state.repeat_note_value]
	return float(state.repeat_note_count) * note_fraction * 4.0 * (60.0 / bpm)

## Verzoegerung bis zum allerersten state in Sekunden, berechnet aus
## delay_count Notenwerten à delay_note_value im aktuellen bpm-Tempo.
func _delay_seconds() -> float:
	var fraction: float = NOTE_FRACTIONS[delay_note_value]
	return float(delay_count) * fraction * 4.0 * (60.0 / bpm)

## Verzoegerung bis zum ersten Anschlag dieses einen Punkts in Sekunden,
## berechnet aus dessen delay_count Notenwerten à delay_note_value im
## gemeinsamen bpm-Tempo (0 = kein Delay fuer diesen Punkt). Wirkt sich nur
## im allerersten state aus (siehe Klassenkommentar oben).
func _delay_seconds_for_point(index: int) -> float:
	var cfg: StringPulsePoint = string_points[index]
	if not cfg:
		return 0.0
	var fraction: float = NOTE_FRACTIONS[cfg.delay_note_value]
	return float(cfg.delay_count) * fraction * 4.0 * (60.0 / bpm)

## Einflugdauer in Sekunden, berechnet aus fly_in_count Notenwerten à
## fly_in_note_value im aktuellen bpm-Tempo - gleiche Rechnung wie
## _delay_seconds().
func _fly_in_duration() -> float:
	var fraction: float = NOTE_FRACTIONS[fly_in_note_value]
	return float(fly_in_count) * fraction * 4.0 * (60.0 / bpm)

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
