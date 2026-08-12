@tool
extends Node2D

@export var total_bars: int = 44
@export var units_per_bar: float = 400.0
@export var beats_per_bar: int = 4
@export var bar_color: Color = Color(1.0, 1.0, 1.0, 0.4) # Helle Linien für Taktanfänge
@export var beat_color: Color = Color(1.0, 1.0, 1.0, 0.15) # Blasse Linien für Beats

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
		
	var level_height: float = 1080.0
	var units_per_beat = units_per_bar / beats_per_bar
	
	for bar in range(total_bars + 1):
		var bar_x = bar * units_per_bar
		# Taktlinie zeichnen (dicker)
		draw_line(Vector2(bar_x, 0), Vector2(bar_x, level_height), bar_color, 2.0)
		
		# Beat-Linien innerhalb des Takts
		if bar < total_bars:
			for beat in range(1, beats_per_bar):
				var beat_x = bar_x + (beat * units_per_beat)
				draw_line(Vector2(beat_x, 0), Vector2(beat_x, level_height), beat_color, 1.0)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
