@tool
extends Node2D

@export_group("Notenlinien Layout")
## X-Startposition (fest ab X = 600)
@export var start_x: float = 600.0
## Gesamtlänge der Notenlinien nach rechts
@export var staff_length: float = 2000.0
## Y-Position der mittleren (3.) Notenlinie
@export var center_y: float = 300.0
## Abstand zwischen den 5 Linien
@export var line_spacing: float = 6.0
## Farbe der Notenlinien (Leuchtendes Gelb/Weiss für maximalen Kontrast)
@export var line_color: Color = Color(1.0, 1.0, 0.0, 1.0)
## Liniendicke
@export var line_width: float = 3.0

func _draw() -> void:
	# TEST-MARKER: Zeichnet ein rotes Quadrat direkt bei X=600, Y=center_y
	draw_rect(Rect2(start_x, center_y - 15, 30, 30), Color(1, 0, 0, 1))
	
	# Zeichnet die 5 Linien
	for i in range(5):
		var line_y = center_y + (i - 2) * line_spacing
		var start_p = Vector2(start_x, line_y)
		var end_p = Vector2(start_x + staff_length, line_y)
		draw_line(start_p, end_p, line_color, line_width)

func _process(_delta: float) -> void:
	queue_redraw()
