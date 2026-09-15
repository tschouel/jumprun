class_name StringPulsePoint
extends Marker2D

## Einzelner Vibrations-Punkt einer VibratingString - ein ganz normaler
## Marker2D (im Editor genau wie bisher platzieren), zusaetzlich mit eigenem
## Anschlag-Delay. delay_note_value + delay_count verschieben NUR den
## Anschlag DIESES einen Punkts (nicht der ganzen Saite) um die angegebene
## Anzahl Notenwerte im Tempo der VibratingString (gleiche Rechnung wie bei
## RhythmicMover/VibratingString) - damit laesst sich z.B. jeder Bogen-
## Treffer auf derselben Saite auf seinen eigenen Zeitpunkt syncen.
##
## Setup: als Kind-Node an der gewuenschten Stelle der Saite platzieren (im
## "Neuer Node hinzufuegen"-Dialog nach "StringPulsePoint" suchen, verhaelt
## sich wie ein Marker2D), im Inspector delay_note_value/delay_count
## einstellen, danach den Node wie gewohnt ins string_points-Array der
## VibratingString ziehen.

@export_enum("Ganze", "Halbe", "Viertel", "Achtel", "Sechzehntel") var delay_note_value: int = 2
@export var delay_count: int = 0
