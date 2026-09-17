class_name BowRotator
extends Node2D

## Rotiert eine ANDERE Node (z.B. einen RhythmicMover-Bogen) im Songtempo -
## komplett eigenstaendiges Parallel-Modul, ruehrt RhythmicMover.gd nicht
## an. Arbeitet bewusst OHNE Tween: target.rotation_degrees wird jeden
## Frame in _process() direkt aus der verstrichenen Zeit neu berechnet
## (siehe fruehere Tween-Probleme in diesem Projekt - Tween.parallel()/
## .chain()/.as_relative() hatten sich hier mehrfach unerwartet verhalten).
##
## STATES-SEQUENZ: states ist eine Liste beliebig vieler BowRotatorState-
## Eintraege (siehe bow_rotator_state.gd) - jeder mit eigener Dauer (Takte +
## Notenwert) und eigenem Rotations-Verhalten (Pendel/Weiterdrehen,
## Richtung, Grad). Sie spielen strikt nacheinander ab, jeder startet exakt
## dort, wo der vorige aufgehoert hat (keine Spruenge), und nach dem
## letzten Eintrag geht's (falls loop = true) wieder von vorne los -
## dadurch laesst sich beliebig genau auf einen Song-Verlauf reagieren,
## z.B. "2 Takte + 3 Viertel mit 20 Grad pendeln, dann 3 Takte + 2
## Sechzehntel still stehen, dann wieder von vorne".
##
## WIEDERHOLUNG INNERHALB EINES STATE (repeat_note_value/repeat_note_count,
## siehe bow_rotator_state.gd): optionale "Unterkategorie" pro state - statt
## einer einzigen grossen Bewegung ueber die GESAMTE Abschnittsdauer kann
## sich die Pendel-/Weiterdrehen-Bewegung in einem kleineren, fortlaufend
## wiederholten Zyklus abspielen, z.B. "4 Takte + 2 Viertel lang JEDE
## Viertel pendeln". Die Gesamtdauer (bars/note_value/note_count) bleibt
## dabei unveraendert die Laenge dieses states in der Sequenz - nur WIE OFT
## sich die Bewegung darin wiederholt, kommt separat dazu.
##
## bpm gilt gemeinsam fuer ALLE states (und fuer die Start-Verzoegerung
## delay_note_value/delay_count) - so bleibt alles synchron zum selben
## Song-Tempo, auch bei BPM-Aenderungen zur Laufzeit (siehe set_bpm()).
##
## Gedacht fuer die 2-3 Boegen, die sich (zusaetzlich zu ihrer normalen
## RhythmicMover-Bewegung) auch noch drehen sollen: BowRotator als
## eigenstaendige Node daneben in die Szene, target auf den Bogen ziehen,
## und dasselbe bpm wie am RhythmicMover einstellen, damit Rotation und
## Hoch-Runter-Bewegung synchron im selben Takt laufen. Fuer die anderen 15
## Boegen, die sich nur bewegen sollen, brauchst du diese Node gar nicht
## erst anzulegen.
##
## delay_note_value + delay_count verzoegern nur den ALLERERSTEN Start der
## Sequenz (vor dem ersten state), nicht in Sekunden angegeben, sondern als
## Notenwerte im bpm-Tempo - genau wie bei RhythmicMover.
##
## Setup:
## 1. Eigene Node2D irgendwo in der Szene anlegen, dieses Skript drauf.
## 2. target im Inspector auf den zu rotierenden Node ziehen (z.B. deinen
##    RhythmicMover-Bogen).
## 3. states im Inspector befuellen (auf die "+"-Schaltflaeche klicken,
##    fuer jeden Abschnitt einen neuen BowRotatorState anlegen und dessen
##    Werte setzen - siehe bow_rotator_state.gd fuer die Details jedes
##    Feldes).
## 4. bpm passend zum target einstellen.

const NOTE_FRACTIONS: Array[float] = [1.0, 0.5, 0.25, 0.125, 0.0625]  # Ganze, Halbe, Viertel, Achtel, Sechzehntel

@export var target: Node2D
@export var states: Array[BowRotatorState] = []
## Nach dem letzten Eintrag in states wieder von vorne beginnen (true,
## Standard) oder nach einmaligem Durchlauf beim letzten state stehen
## bleiben (false).
@export var loop: bool = true

@export_group("Musik-Timing")
@export var bpm: float = 100.0
@export_enum("Ganze", "Halbe", "Viertel", "Achtel", "Sechzehntel") var delay_note_value: int = 2
@export var delay_count: int = 0
@export var autostart: bool = true

var _start_rotation: float = 0.0  # Rotation ganz zu Beginn, vor dem allerersten state - Rueckkehrpunkt fuer stop().
var _segment_start_rotation: float = 0.0  # target's Rotation zu Beginn des GERADE laufenden state.
var _segment_elapsed: float = 0.0
var _state_index: int = 0
var _running: bool = false
var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_begin_sequence)

	if autostart:
		start()

## Startet (bzw. neu-startet) die states-Sequenz ab target's aktueller
## Rotation - falls delay_count > 0 gesetzt ist, erst nach
## _delay_seconds() Verzoegerung.
func start() -> void:
	if not target:
		push_warning("BowRotator: target ist nicht gesetzt.")
		return
	_running = false
	_timer.stop()

	_start_rotation = target.rotation_degrees
	var delay_seconds: float = _delay_seconds()
	if delay_seconds > 0.0:
		_timer.start(delay_seconds)
	else:
		_begin_sequence()

func _begin_sequence() -> void:
	_state_index = 0
	_begin_current_state()

## Merkt sich target's Rotation JETZT als Ausgangspunkt fuer den gerade
## beginnenden state (siehe Klassenkommentar oben zu "keine Spruenge") und
## setzt die verstrichene Zeit fuer diesen Abschnitt zurueck.
func _begin_current_state() -> void:
	_segment_elapsed = 0.0
	_segment_start_rotation = target.rotation_degrees if target else _start_rotation
	_running = states.size() > 0

## Berechnet target.rotation_degrees jeden Frame direkt aus der seit
## _begin_current_state() verstrichenen Zeit - kein Tween. Wechselt
## automatisch zum naechsten state, sobald dessen Dauer abgelaufen ist.
func _process(delta: float) -> void:
	if not _running or not target or states.is_empty():
		return
	var state: BowRotatorState = states[_state_index]
	var duration: float = _state_duration(state)

	_segment_elapsed += delta
	if duration <= 0.0 or _segment_elapsed >= duration:
		_apply_state(state, duration)  # exakt auf den Endwert dieses states springen
		_advance_to_next_state()
		return

	_apply_state(state, _segment_elapsed)

## Wendet den Rotations-Fortschritt (t Sekunden seit Beginn des Abschnitts)
## von state auf target an - siehe bow_rotator_state.gd fuer Pendel vs.
## Weiterdrehen, und fuer die optionale Wiederholung innerhalb des state
## (repeat_note_value/repeat_note_count).
func _apply_state(state: BowRotatorState, t: float) -> void:
	var duration: float = _state_duration(state)
	var signed_degrees: float = state.rotate_degrees if state.direction == 0 else -state.rotate_degrees

	if duration <= 0.0:
		target.rotation_degrees = _segment_start_rotation
		return

	var cycle_duration: float = _repeat_cycle_duration(state)
	if cycle_duration <= 0.0:
		# Keine Wiederholung - eine einzige Bewegung ueber die gesamte
		# Abschnittsdauer (bisheriges Verhalten).
		_apply_motion(state, signed_degrees, t, duration)
		return

	# Wiederholung: t wird in Zyklen von je cycle_duration zerlegt. Am Ende
	# der Abschnittsdauer wird der laufende Zyklus einfach abgeschnitten
	# (siehe bow_rotator_state.gd), nicht bis zu seinem Ende weitergefuehrt.
	var clamped_t: float = clampf(t, 0.0, duration)
	var cycle_index: int = int(floor(clamped_t / cycle_duration))
	var t_in_cycle: float = clamped_t - float(cycle_index) * cycle_duration

	if state.rotation_mode == 0:
		# Pendel: jeder Zyklus ist eine eigene volle Hin-Zurueck-Schwingung -
		# faengt und endet bei envelope 0, dadurch nahtlos zwischen Zyklen.
		var envelope: float = (1.0 - cos(TAU * t_in_cycle / cycle_duration)) * 0.5
		target.rotation_degrees = _segment_start_rotation + signed_degrees * envelope
	else:
		# Weiterdrehen: jeder VOLLE Zyklus dreht kumulativ um signed_degrees
		# weiter (kein Zuruecksspringen) - siehe bow_rotator_state.gd.
		var progress_in_cycle: float = clampf(t_in_cycle / cycle_duration, 0.0, 1.0)
		target.rotation_degrees = _segment_start_rotation + signed_degrees * (float(cycle_index) + progress_in_cycle)

## Eine einzelne Pendel-/Weiterdrehen-Bewegung ueber duration Sekunden
## (ohne Wiederholung) - ausgelagert aus _apply_state(), damit derselbe Code
## sowohl fuer den Fall "keine Wiederholung" als auch fuer den Fall
## "Wiederholung noch nicht aktiv" (cycle_duration <= 0.0) gilt.
func _apply_motion(state: BowRotatorState, signed_degrees: float, t: float, duration: float) -> void:
	if state.rotation_mode == 0:
		var envelope: float = (1.0 - cos(TAU * t / duration)) * 0.5
		target.rotation_degrees = _segment_start_rotation + signed_degrees * envelope
	else:
		var progress: float = clampf(t / duration, 0.0, 1.0)
		target.rotation_degrees = _segment_start_rotation + signed_degrees * progress

## Springt zum naechsten state in der Sequenz - am Ende (falls loop =
## false) bleibt einfach der letzte state aktiv/stehen.
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

## Stoppt die Sequenz (auch einen noch laufenden Delay) und dreht target
## zurueck auf die Ausgangs-Rotation von ganz vor dem ersten state.
func stop() -> void:
	_timer.stop()
	_running = false
	if target:
		target.rotation_degrees = _start_rotation

## Aendert das Tempo zur Laufzeit und startet die Sequenz neu - gleiches
## Verhalten wie RhythmicMover.set_bpm().
func set_bpm(new_bpm: float) -> void:
	bpm = new_bpm
	if _running:
		start()

## Dauer eines einzelnen state in Sekunden, aus bars (volle Takte im 4/4)
## + note_count Notenwerten à note_value, im gemeinsamen bpm-Tempo.
func _state_duration(state: BowRotatorState) -> float:
	var bar_seconds: float = 4.0 * (60.0 / bpm)
	var note_fraction: float = NOTE_FRACTIONS[state.note_value]
	return float(state.bars) * bar_seconds + float(state.note_count) * note_fraction * bar_seconds

## Dauer EINES Wiederhol-Zyklus in Sekunden (repeat_note_count Notenwerte à
## repeat_note_value) - 0.0, falls repeat_note_count <= 0 ist (= keine
## Wiederholung, siehe bow_rotator_state.gd).
func _repeat_cycle_duration(state: BowRotatorState) -> float:
	if state.repeat_note_count <= 0:
		return 0.0
	var note_fraction: float = NOTE_FRACTIONS[state.repeat_note_value]
	return float(state.repeat_note_count) * note_fraction * 4.0 * (60.0 / bpm)

## Verzoegerung bis zum allerersten state in Sekunden, berechnet aus
## delay_count Notenwerten à delay_note_value im aktuellen bpm-Tempo.
func _delay_seconds() -> float:
	var fraction: float = NOTE_FRACTIONS[delay_note_value]
	return float(delay_count) * fraction * 4.0 * (60.0 / bpm)
