class_name SlidingObstacleStep
extends Resource

## Anzahl der Notenwerte bis zum nächsten Hindernis (z.B. 5 = "5 Viertel")
@export var beats: float = 1.0

## Notenwert als Nenner: 4 = Viertel, 8 = Achtel, 16 = Sechzehntel, usw.
@export var note_division: int = 4

## Tempo für dieses Segment
@export var bpm: float = 130.0

## Hindernis-Szene, die an diesem Punkt auf dem Pfad platziert wird
@export var obstacle_scene: PackedScene


## Berechnet die Dauer dieses Segments in Sekunden aus beats/note_division/bpm.
## Eine Viertelnote bei bpm dauert (60.0 / bpm) Sekunden; ein Notenwert mit
## Nenner note_division dauert davon (4.0 / note_division) Anteile.
func get_duration_seconds() -> float:
	if bpm <= 0.0 or note_division <= 0:
		return 0.0
	var seconds_per_note: float = (60.0 / bpm) * (4.0 / float(note_division))
	return beats * seconds_per_note
