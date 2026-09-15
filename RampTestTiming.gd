@tool
class_name RampTestTiming
extends Resource
## Definiert, WANN (als Position auf dem Pfad, umgerechnet aus Takten +
## Schlaegen bei einem Tempo) das Ramp-Testfenster beginnt, und WIE LANGE
## es dauert (eigener Notenwert). Basiert auf 4/4-Takt (1 Takt = 4
## Viertel-Schlaege) fuer die Start-Position - das ist die natuerlichste
## Art, "nach 8 Takten und 3 Schlaegen" auszudruecken.

@export_group("Start-Position")
@export var start_bars: int = 8
## Zusaetzliche VIERTEL-Schlaege nach den vollen Takten.
@export var start_beats: float = 3.0
@export var bpm: float = 120.0

@export_group("Fenster-Laenge")
## Wie lange das Testfenster dauert, als Notenwert (analog zu
## SlidingObstacleStep) - bei der NORMALEN (nicht verlangsamten)
## Geschwindigkeit gerechnet.
@export var window_beats: float = 1.0
@export var window_note_division: int = 4


func get_start_time_seconds() -> float:
	if bpm <= 0.0:
		return 0.0
	var quarter_note_seconds: float = 60.0 / bpm
	var total_quarter_beats: float = float(start_bars) * 4.0 + start_beats
	return total_quarter_beats * quarter_note_seconds


func get_window_duration_seconds() -> float:
	if bpm <= 0.0 or window_note_division <= 0:
		return 0.0
	var seconds_per_note: float = (60.0 / bpm) * (4.0 / float(window_note_division))
	return window_beats * seconds_per_note
