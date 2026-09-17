@tool
class_name SlidingObstacleStep
extends Resource

enum StepType { OBSTACLE, MARKER }

## Anzahl der Notenwerte bis zum nächsten Hindernis (z.B. 5 = "5 Viertel")
@export var beats: float = 1.0

## Notenwert als Nenner: 4 = Viertel, 8 = Achtel, 16 = Sechzehntel, usw.
@export var note_division: int = 4

## Tempo für dieses Segment
@export var bpm: float = 130.0

## OBSTACLE (Standard): an dieser Stelle wird obstacle_scene ganz normal
## gespawnt (im Editor UND im Spiel), unveraendertes Verhalten. MARKER: es
## wird ueberhaupt nichts gespawnt - obstacle_scene wird komplett ignoriert.
## Stattdessen zeigt der Sequencer NUR im Editor (nie im fertigen Spiel) an
## dieser Stelle einen roten Streifen quer zur Kurve an, rein als visuelle
## Orientierungshilfe. So kannst du dein Musikstueck erstmal komplett
## timingmaessig aufs Level uebertragen und siehst sofort, wo genau was
## hinkommt - bevor du ueberhaupt eine Hindernis-Szene dafuer gebaut hast.
## Sobald du weisst, was an eine Marker-Stelle soll, einfach auf OBSTACLE
## umstellen und obstacle_scene setzen.
@export var step_type: StepType = StepType.OBSTACLE

## Hindernis-Szene, die an diesem Punkt auf dem Pfad platziert wird - wird
## bei step_type = MARKER ignoriert.
@export var obstacle_scene: PackedScene

## Falls aktiviert: das gespawnte Hindernis bleibt unsichtbar (kein Sprite,
## keine Animation zu sehen) - seine Collision/Funktion bleibt aber voll
## erhalten, weil Godots Physik die visible-Eigenschaft komplett ignoriert;
## nur das Zeichnen wird unterdrueckt. Praktisch, wenn du z.B. ein
## unsichtbares Hindernis exakt hinter/auf einem eigenen, unabhaengigen
## AnimatedSprite2D platzieren willst, das rein optisch die Szene traegt,
## waehrend dieses Hindernis nur die Kollision/den Trigger liefert - ohne
## dafuer extra ein eigenes Skript bauen zu muessen.
@export var invisible: bool = false


## Berechnet die Dauer dieses Segments in Sekunden aus beats/note_division/bpm.
## Eine Viertelnote bei bpm dauert (60.0 / bpm) Sekunden; ein Notenwert mit
## Nenner note_division dauert davon (4.0 / note_division) Anteile.
func get_duration_seconds() -> float:
	if bpm <= 0.0 or note_division <= 0:
		return 0.0
	var seconds_per_note: float = (60.0 / bpm) * (4.0 / float(note_division))
	return beats * seconds_per_note
