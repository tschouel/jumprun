class_name RhythmicMover
extends AnimatableBody2D

## Bewegt diesen AnimatableBody2D im Songtempo hin und her - z.B. ein Bogen,
## der pro Notenwert einmal in move_direction hoch und in der naechsten Note
## wieder zurueck schwingt. bpm + note_value bestimmen zusammen, wie lange
## EINE Richtung (hoch ODER runter) dauert:
##
##   dauer_sekunden = notenwert_bruchteil * 4.0 * (60.0 / bpm)
##
## Beispiel: 100 BPM, Viertelnote -> 0.25 * 4.0 * (60.0/100) = 0.6s pro
## Richtung, also 1.2s fuer eine volle Hoch-Runter-Schwingung. Eine Viertel-
## note ist per Definition immer genau ein Beat, daher kommt bei "Viertel"
## exakt 60.0 / bpm heraus.
##
## Wichtig: Am Node selbst im Inspector "Sync to Physics" aktivieren, damit
## Koerper, die auf dem Bogen stehen, sauber mitgenommen werden (Godot-
## Standardverhalten fuer bewegte AnimatableBody2D/CharacterBody2D-Plattformen).
##
## delay_note_value + delay_count verschieben den Start der ersten Schwingung
## zeitlich - nicht in Sekunden angegeben, sondern als Anzahl Notenwerte im
## aktuellen Tempo (z.B. delay_count=1 bei "Achtel" = eine Achtelnote
## Verzoegerung, bevor der Bogen sich das erste Mal bewegt). So laesst sich
## der Bogen exakt auf eine zugehoerige VibratingString synchronisieren, und
## der Delay bleibt auch bei BPM-Aenderungen musikalisch exakt.
##
## EINFLUG (neu): start_tuning() laesst den Bogen zuerst von einem
## Startpunkt zu seiner im Editor gesetzten Position reinfliegen, BEVOR die
## normale Schwingung beginnt. Startpunkt: entweder flight_start_point (ein
## beliebiger Node2D, z.B. Marker2D, irgendwo ausserhalb des sichtbaren
## Bereichs platziert - GLOBALE Position, wird automatisch in lokale
## Koordinaten umgerechnet) ODER move_from_offset (relativ zur Editor-
## Position, falls kein flight_start_point gesetzt ist). fly_in_note_value +
## fly_in_count bestimmen die Einflugdauer GENAUSO wie delay_note_value/
## delay_count - als Anzahl Notenwerte im gemeinsamen bpm-Tempo, nicht in
## Sekunden (fly_in_count = 0, Standard, => kein Einflug: der Bogen springt
## sofort auf seine Position und beginnt direkt mit der normalen
## Schwingung inkl. deren eigenem delay_note_value/delay_count-Timing).
##
## autostart bezieht sich JETZT auf start_tuning() (Einflug + Schwingung),
## nicht mehr nur auf die Schwingung, und ist standardmaessig AUS - gedacht
## fuer den Einsatz als level_build_target in
## tuner_butterfly_sequence_controller.gd (der start_tuning() automatisch
## erkennt und zur richtigen Zeit aufruft). Nur einschalten, wenn der Bogen
## wirklich sofort beim Laden der Szene von selbst losfliegen/schwingen soll.

const NOTE_FRACTIONS: Array[float] = [1.0, 0.5, 0.25, 0.125, 0.0625]  # Ganze, Halbe, Viertel, Achtel, Sechzehntel

signal cycle_started
signal flight_finished

@export_group("Bewegung")
@export var move_distance_px: float = 50.0
@export var move_direction: Vector2 = Vector2.UP
@export var transition_type: Tween.TransitionType = Tween.TRANS_SINE
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

@export_group("Musik-Timing")
@export var bpm: float = 100.0
@export_enum("Ganze", "Halbe", "Viertel", "Achtel", "Sechzehntel") var note_value: int = 2
@export_enum("Ganze", "Halbe", "Viertel", "Achtel", "Sechzehntel") var delay_note_value: int = 2
@export var delay_count: int = 0
@export var autostart: bool = false

@export_group("Einflug")
## Startposition relativ zur im Editor gesetzten Position - wird IGNORIERT,
## falls flight_start_point gesetzt ist.
@export var move_from_offset: Vector2 = Vector2.ZERO
## Optional: beliebiger Node2D (z.B. Marker2D), dessen GLOBALE Position als
## Einflug-Startpunkt verwendet wird, statt move_from_offset.
@export var flight_start_point: Node2D
@export_enum("Ganze", "Halbe", "Viertel", "Achtel", "Sechzehntel") var fly_in_note_value: int = 2
## Anzahl Notenwerte (siehe fly_in_note_value) fuer die Einflugdauer. 0 =
## kein Einflug (Standard) - der Bogen steht/haengt direkt an seiner
## Editor-Position und beginnt sofort mit der normalen Schwingung.
@export var fly_in_count: int = 0
@export var fly_in_transition_type: Tween.TransitionType = Tween.TRANS_SINE
@export var fly_in_ease_type: Tween.EaseType = Tween.EASE_IN_OUT

var _home_position: Vector2
var _start_position: Vector2
var _tween: Tween
var _fly_tween: Tween
var _timer: Timer
var _flying_in: bool = false

func _ready() -> void:
	_home_position = position
	position = _fly_in_start_position()

	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_begin_cycle)

	if autostart:
		start_tuning()

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
## als success_target/final_target). Laesst den Bogen - falls fly_in_count >
## 0 - erst zur Editor-Position reinfliegen und startet danach automatisch
## die normale Schwingung (start()). Bei fly_in_count = 0 identisch zu einem
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

## Startet (bzw. neu-startet) die Schwingung ab der aktuellen Position - falls
## delay_count > 0 gesetzt ist, erst nach _delay_seconds() Verzoegerung.
## Loest KEINEN Einflug aus (siehe start_tuning() dafuer) - geht davon aus,
## dass der Bogen schon an seiner gewuenschten Ausgangsposition steht.
func start() -> void:
	if _tween:
		_tween.kill()
	_timer.stop()

	_start_position = position
	var delay_seconds: float = _delay_seconds()
	if delay_seconds > 0.0:
		_timer.start(delay_seconds)
	else:
		_begin_cycle()

## Baut den eigentlichen Hoch-Runter-Loop auf - wird direkt von start()
## aufgerufen (kein Delay) oder verzoegert nach Ablauf von _timer.
func _begin_cycle() -> void:
	var beat_duration: float = _note_duration()
	var target: Vector2 = _start_position + move_direction.normalized() * move_distance_px

	_tween = create_tween()
	_tween.set_loops()
	_tween.set_trans(transition_type)
	_tween.set_ease(ease_type)
	_tween.tween_callback(func() -> void: cycle_started.emit())
	_tween.tween_property(self, "position", target, beat_duration)
	_tween.tween_property(self, "position", _start_position, beat_duration)

## Stoppt die Schwingung (auch einen noch laufenden Delay ODER einen noch
## laufenden Einflug) und faehrt zurueck auf die Ausgangsposition.
func stop() -> void:
	_timer.stop()
	if _tween:
		_tween.kill()
	if _fly_tween:
		_fly_tween.kill()
	_flying_in = false
	position = _start_position

## Aendert das Tempo zur Laufzeit (z.B. per FMOD-Tempo-Marker) und startet
## den Zyklus neu - das erzeugt an der Nahtstelle einen kleinen Sprung, ist
## also eher fuer "Songabschnitt wechselt Tempo" gedacht als fuer staendiges
## Nachjustieren waehrend einer Schwingung.
func set_bpm(new_bpm: float) -> void:
	bpm = new_bpm
	if _tween:
		start()

func _note_duration() -> float:
	var fraction: float = NOTE_FRACTIONS[note_value]
	return fraction * 4.0 * (60.0 / bpm)

## Verzoegerung bis zum ersten Schwingungs-Start in Sekunden, berechnet aus
## delay_count Notenwerten à delay_note_value im aktuellen bpm-Tempo - gleiche
## Rechnung wie _note_duration(), nur mit dem eigenen Notenwert und mal
## delay_count (0 = kein Delay).
func _delay_seconds() -> float:
	var fraction: float = NOTE_FRACTIONS[delay_note_value]
	return float(delay_count) * fraction * 4.0 * (60.0 / bpm)

## Einflugdauer in Sekunden, berechnet aus fly_in_count Notenwerten à
## fly_in_note_value im aktuellen bpm-Tempo - gleiche Rechnung wie
## _note_duration()/_delay_seconds().
func _fly_in_duration() -> float:
	var fraction: float = NOTE_FRACTIONS[fly_in_note_value]
	return float(fly_in_count) * fraction * 4.0 * (60.0 / bpm)
