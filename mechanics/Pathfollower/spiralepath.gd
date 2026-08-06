extends PathFollow2D

@export_group("Rhythmus & Tempo")
@export var bpm: float = 90.0
@export var units_per_bar: float = 1000.0 # Auf Full HD angepasst (1000px pro Takt)
@export var is_moving: bool = true

var forward_speed: float

func _ready() -> void:
	# 4/4-Takt Dauer berechnen
	var bar_duration = (60.0 / bpm) * 4.0
	# Geschwindigkeit in Pixel pro Sekunde
	forward_speed = units_per_bar / bar_duration

func _process(delta: float) -> void:
	if is_moving:
		progress += forward_speed * delta
