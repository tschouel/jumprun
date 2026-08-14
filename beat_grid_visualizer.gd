@tool
extends Node2D

@export_group("Zonen-Referenz")
## Ziehe hier deine LaneZone rein
@export var target_zone: Node2D:
	set(value):
		target_zone = value
		queue_redraw()

@export_group("Takt- & Beat-Einstellungen")
@export var total_bars: int = 44:
	set(value):
		total_bars = max(value, 1)
		queue_redraw()

@export var beats_per_bar: int = 4:
	set(value):
		beats_per_bar = max(value, 1)
		queue_redraw()

## Feste Taktbreite in Pixeln (wird überschrieben, wenn die LaneZone units_per_bar hat)
@export var default_units_per_bar: float = 800.0:
	set(value):
		default_units_per_bar = max(value, 10.0)
		queue_redraw()

@export_group("Optik")
@export var grid_height: float = 2000.0:
	set(value):
		grid_height = value
		queue_redraw()

@export var bar_color: Color = Color(1.0, 0.0, 0.0, 1.0): # 100% deckendes Rot
	set(value):
		bar_color = value
		queue_redraw()

@export var beat_color: Color = Color(0.0, 0.5, 1.0, 0.8): # Blau für Beats
	set(value):
		beat_color = value
		queue_redraw()

func _enter_tree() -> void:
	z_index = 4096 # Maximaler Godot Z-Index (garantiert vor allem)
	z_as_relative = false
	queue_redraw()

func _ready() -> void:
	z_index = 4096
	z_as_relative = false
	queue_redraw()

func _process(_delta: float) -> void:
	# Erzwingt Redraw im Editor und im Spiel
	queue_redraw()

func _get_units_per_bar() -> float:
	if is_instance_valid(target_zone):
		var val = target_zone.get("units_per_bar")
		if val != null and float(val) > 0.0:
			return float(val)
	return default_units_per_bar

func _draw() -> void:
	var upb: float = _get_units_per_bar()
	var bpb: int = max(beats_per_bar, 1)
	var units_per_beat: float = upb / float(bpb)

	# Startpunkt: Wenn Zone verknüpft, nutze deren Position, sonst globale Position des Visualizers
	var start_pos: Vector2 = Vector2.ZERO
	if is_instance_valid(target_zone):
		start_pos = target_zone.global_position - global_position

	# 1. Auffälliges Test-Kreuz am Startpunkt zeichnen (damit man sofort sieht, wo Takt 1 liegt)
	draw_line(start_pos + Vector2(-50, 0), start_pos + Vector2(50, 0), Color.YELLOW, 6.0)
	draw_line(start_pos + Vector2(0, -50), start_pos + Vector2(0, 50), Color.YELLOW, 6.0)

	# 2. Alle Takte und Beats zeichnen
	for bar in range(total_bars + 1):
		var bar_x: float = start_pos.x + (bar * upb)

		# Taktlinie (Rot & Dick)
		draw_line(Vector2(bar_x, -500.0), Vector2(bar_x, grid_height), bar_color, 4.0)

		# Beat-Linien (2, 3, 4)
		if bar < total_bars:
			for beat in range(1, bpb):
				var beat_x: float = bar_x + (beat * units_per_beat)
				draw_line(Vector2(beat_x, -500.0), Vector2(beat_x, grid_height), beat_color, 2.0)
