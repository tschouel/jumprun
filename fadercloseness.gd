class_name ClosenessSource
extends Node

## Zentrale Naehe-Berechnung: wie nah liegt der Fader-Wert an einer
## "perfect_position" (0..1)? Stellt das Ergebnis als eigenes Signal bereit,
## damit Farbe, Rauschen, Animations-Scrub (beliebig viele Sprites) und
## alles Weitere, was spaeter dazukommt, sich NICHT mehr jedes selbst um
## perfect_position/distance_range kuemmern muessen - die kennen nur noch
## 0.0 (state_a / unangenehm, so weit weg wie moeglich) bis 1.0 (perfect).
##
## Setup: an einen beliebigen Node haengen, fader zuweisen, perfect_position
## und distance_range einstellen. Alle Effekt-Skripte (Farbe, Noise, Scrub)
## bekommen dann NICHT mehr den Fader direkt, sondern diesen Node hier bei
## ihrem "closeness_source"-Feld.

@export var fader: Fader
## Fader-Wert (0..1), der als "perfekt getroffen" gilt.
@export_range(0.0, 1.0) var perfect_position: float = 0.5
## Wie weit man von perfect_position entfernt sein darf, bis closeness auf 0
## (state_a/unangenehm) faellt. Kleinere Range = praeziser/empfindlicher.
@export_range(0.01, 1.0) var distance_range: float = 0.3

## 0.0 = so weit weg wie moeglich (state_a/unangenehm), 1.0 = genau perfect.
signal closeness_changed(closeness: float)

var closeness: float = 0.0

func _ready() -> void:
	if fader:
		fader.value_changed.connect(_on_fader_value_changed)
		call_deferred("_sync_initial_value")

func _sync_initial_value() -> void:
	if fader:
		_on_fader_value_changed(fader.get_value())

func _on_fader_value_changed(new_value: float) -> void:
	var distance: float = abs(new_value - perfect_position)
	closeness = clamp(1.0 - (distance / distance_range), 0.0, 1.0)
	closeness_changed.emit(closeness)
