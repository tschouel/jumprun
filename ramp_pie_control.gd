extends Control
## Zeichnet einen klassischen "Pie Timer" (sich leerender Kreis) - wird von
## RampTimerUI.gd ueber set_progress() angesteuert. Als Kind-Control mit
## fester Groesse (z.B. 100x100) in die RampTimerUI-Szene einsetzen.

@export var pie_radius: float = 40.0
@export var pie_color: Color = Color(1.0, 1.0, 1.0, 0.85)
@export var pie_background_color: Color = Color(0.0, 0.0, 0.0, 0.35)

var _progress: float = 1.0  ## 1.0 = volle Zeit uebrig, 0.0 = abgelaufen


func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size / 2.0

	# Hintergrund-Kreis (voller Kreis, dunkler) - immer sichtbar als
	# "leere" Referenzflaeche.
	draw_circle(center, pie_radius, pie_background_color)

	if _progress <= 0.0:
		return

	# Der eigentliche "Kuchenstueck"-Sektor, der sich mit sinkendem
	# _progress im Uhrzeigersinn verkleinert - startet oben (-90 Grad).
	var start_angle: float = -PI / 2.0
	var end_angle: float = start_angle + TAU * _progress

	var points := PackedVector2Array()
	points.append(center)
	var segments: int = 32
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle: float = lerp(start_angle, end_angle, t)
		points.append(center + Vector2(cos(angle), sin(angle)) * pie_radius)

	var colors := PackedColorArray()
	colors.resize(points.size())
	colors.fill(pie_color)

	draw_polygon(points, colors)
